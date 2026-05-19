# Date handling

> JavaScript + Postgres date semantics traps surfaced by date-only columns, native `<input type="date">`, server-side `CURRENT_DATE` comparisons, and signed-time-delta PostHog events.
>
> Date-only handling (calendar dates, no clock time) is where most of these bite. Date+time handling is its own concern — when you mean an instant, use `timestamptz` and ISO-8601 instants throughout; the traps below are about the date-without-time case.

## Contents

- [Recipe: `'YYYY-MM-DD'` strings end-to-end](#recipe-yyyy-mm-dd-strings-end-to-end)
- [Trap 1: `new Date('2026-02-30')` silently coerces](#trap-1-new-date2026-02-30-silently-coerces)
- [Trap 2: Date comparison vs `CURRENT_DATE` — UTC drift](#trap-2-date-comparison-vs-current_date--utc-drift)
- [Pattern: Signed time-delta in analytics events](#pattern-signed-time-delta-in-analytics-events)
- [Cross-references](#cross-references)

## Recipe: `'YYYY-MM-DD'` strings end-to-end

When a column is calendar-date-only (`date` in Postgres, not `timestamptz`), keep the value as a `'YYYY-MM-DD'` string at EVERY boundary it crosses:

- **Native input** — `<input type="date">` returns `value` as `'YYYY-MM-DD'` regardless of browser locale (the picker UI renders per-locale, but the JS-visible value is always ISO).
- **API body** — JSON serialize as `'YYYY-MM-DD'`. Don't wrap in `new Date(...)` and then serialize; that round-trips through `Date` semantics unnecessarily.
- **Server-side validator** — strict regex `/^\d{4}-\d{2}-\d{2}$/` + `Date.UTC` round-trip-equals-input check (see Trap 1).
- **PostgREST request** — pass the string directly to a `date` column; PostgREST forwards it; Postgres parses it strictly.
- **PostgREST response** — `date` columns come back as `'YYYY-MM-DD'` strings. Don't re-wrap in `Date` for display logic.
- **Comparisons** — string lexicographic comparison is correct because ISO dates are sort-stable. `'2026-05-17' <= todayIso` works.
- **Display** — format from `'YYYY-MM-DD'` via `Date.UTC(y, m-1, d)` so timezone drift can't shift the calendar date (see Trap 2).

Never compare `Date` objects across the date-only boundary. Never compare `'YYYY-MM-DD'` against a `Date` object. Once you cross out of the string, you're in time-of-day-mixed territory.

## Trap 1: `new Date('2026-02-30')` silently coerces

JS's `Date` constructor is permissive. Strings that look like ISO dates but are semantically invalid get silently coerced to the nearest valid date:

```javascript
new Date('2026-02-30'); // → 2026-03-02 (Feb has 28/29 days; overflows to March)
new Date('2026-13-01'); // → 2027-01-01 (month-13 → next year January)
new Date('2025-02-29'); // → 2025-03-01 (not a leap year)
```

A user-PATCH endpoint that takes `{ reminder_date: 'YYYY-MM-DD' }` and runs `new Date(input.reminder_date)` to validate the shape will accept all three above as "valid dates" — but the value that ends up in the database is NOT what the user typed. The bug surfaces later when the user opens the reminder editor and sees a different date than they set.

### The recipe — regex + UTC round-trip

```typescript
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function parseDateOnlyOrNull(
  input: unknown
): ParseResult<string | null> {
  if (input === null) return { ok: true, value: null };
  if (typeof input !== 'string')
    return {
      ok: false,
      field: 'reminder_date',
      reason: 'not a string or null',
    };
  if (!DATE_RE.test(input))
    return { ok: false, field: 'reminder_date', reason: 'not YYYY-MM-DD' };

  // Reject semantically-invalid dates via UTC round-trip
  const [y, m, d] = input.split('-').map(Number);
  const utc = Date.UTC(y, m - 1, d);
  const reconstructed = new Date(utc).toISOString().slice(0, 10);
  if (reconstructed !== input)
    return {
      ok: false,
      field: 'reminder_date',
      reason: 'invalid calendar date',
    };

  return { ok: true, value: input };
}
```

`Date.UTC(2026, 1, 30)` returns the millisecond value for `2026-03-02T00:00:00.000Z`; reconstructing as `'YYYY-MM-DD'` gives `'2026-03-02'`, which doesn't equal the input `'2026-02-30'` — caught.

The reason for `Date.UTC` over `new Date(y, m-1, d)`: `new Date(...)` in local time can shift by one day on the calendar at midnight local on the timezone boundary. `Date.UTC` is timezone-stable.

Home-os instance: `apps/web/app/api/card/[id]/reminder/_lib/parse-reminder-body.ts`.

### When the input ISN'T a calendar date

If the input is meant to be a timestamp (`timestamptz`), validate via ISO-8601 instant parser, not this recipe. `new Date('2026-02-30T10:00:00Z').getTime()` returns NaN-able territory differently; the trap manifests differently. Use a dedicated ISO instant parser (Zod's `z.string().datetime()`, or `Temporal.Instant.from` if available).

## Trap 2: Date comparison vs `CURRENT_DATE` — UTC drift

Postgres `CURRENT_DATE` is **server-timezone-dependent**. Supabase Cloud + the supabase-runner container both run UTC.

On the Node server-side render, `new Date()` returns wall-clock UTC **with hours/minutes/seconds**, so:

```javascript
new Date() >= new Date('2026-05-17');
// LHS includes time-of-day (e.g., 2026-05-17T18:42:17.123Z)
// RHS is 2026-05-17T00:00:00.000Z
// On 2026-05-17 after 00:00 UTC, this returns true — which may be wrong
// if you wanted "today or later" semantics.
```

The comparison is even flakier around midnight UTC — a request hitting at `2026-05-17T23:59:59Z` and a request hitting at `2026-05-18T00:00:01Z` see different "today" values, but a reminder dated `'2026-05-18'` may be "due now" to one request and "tomorrow" to the other.

### The recipe — strip clock time, compare as strings

```typescript
const todayIso = new Date().toISOString().slice(0, 10); // 'YYYY-MM-DD' string
// PostgREST returns date columns as ISO strings already; compare lexicographically.
const isDue =
  card.planned_reminder_date !== null && card.planned_reminder_date <= todayIso;
```

String comparison is correct because ISO dates are sort-stable. Time-of-day is dropped entirely; the "today" boundary is `00:00:00 UTC`, deterministic regardless of when the request hits.

Home-os instance: `apps/web/app/(app)/cards/[id]/page.tsx` derives `isReminderDue` this way.

### The same recipe in `<ReminderEditor>` for `days_out`

```typescript
function daysOut(target: string, today: string): number {
  const [ty, tm, td] = target.split('-').map(Number);
  const [oy, om, od] = today.split('-').map(Number);
  const targetUtc = Date.UTC(ty, tm - 1, td);
  const todayUtc = Date.UTC(oy, om - 1, od);
  return Math.round((targetUtc - todayUtc) / 86400000);
}
```

`Date.UTC` on both sides; subtraction in millis; round to days. NEVER `(new Date(target) - new Date(today)) / 86400000` — local-time DST transitions cause off-by-one errors twice a year.

## Pattern: Signed time-delta in analytics events

When a PostHog event carries a "how far in the future / past" time-delta (`days_out`, `hours_until_X`, `weeks_since_Y`), make the value **signed** — and document that in the event taxonomy.

Home-os `planned_reminder_set` + `planned_reminder_edited` events carry `days_out` as a signed integer:

- `+7` — user set the reminder 7 days in the future. Standard.
- `-3` — user set the reminder 3 days in the past at set-time (legitimate intent — "mark this card as due now"). Real signal.
- `0` — user set the reminder for today.

`Math.abs(days_out)` in any consumer LOSES the sign signal. The sign IS the data. Document this in METRICS.md so consumers know.

Companion pattern: a complementary boolean alongside the signed delta. Home-os `planned_reminder_cleared` carries `had_future_date: boolean` — distinguishes "user regretted setting a future reminder" (true) from "user acknowledged an already-due reminder by clearing it" (false). Together with `days_out`, the consumer can build the user-intent taxonomy.

When NOT to use signed deltas: when the consumer ONLY cares about magnitude (e.g., "average session duration in seconds" — durations are nonnegative by definition). Signed deltas are for cases where direction-of-time-from-now carries semantic information.

## Cross-references

- `kit/docs/guide/migrations.md` — Postgres-side date semantics (column types, `CURRENT_DATE`).
- Home-os `apps/web/app/api/card/[id]/reminder/_lib/parse-reminder-body.ts` — Trap 1 instance.
- Home-os `apps/web/app/(app)/cards/[id]/page.tsx` — Trap 2 instance (`isReminderDue` derivation).
- Home-os `apps/web/app/(app)/cards/[id]/_components/ReminderEditor.tsx` — Trap 2 + signed `days_out` instance.
- Home-os `METRICS.md` — signed `days_out` taxonomy entry.

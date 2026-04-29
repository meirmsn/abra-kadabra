# Metrics

Event taxonomy and feature flags. Updated alongside every new `posthog.capture(...)` or `Sentry.captureException(...)` call site — `kit/scripts/commit-hooks/check-docs-freshness-project.sh` enforces this on pre-commit.

## Events

| Event        | When it fires                                          | Key properties  | Why we care                                                   |
| ------------ | ------------------------------------------------------ | --------------- | ------------------------------------------------------------- |
| <event-name> | <call-site description: which file, which user action> | `{ key: type }` | <one-sentence rationale: what regression or KPI this signals> |

<!--
Authoring rules:
- One row per `posthog.capture(...)` or `Sentry.captureException(...)` call site.
- "When it fires" names the verb (e.g. "successful sign-in", not "auth")
  AND the file (e.g. "Fired from `onAuthStateChange` on `SIGNED_IN` in `apps/web/...`").
- "Key properties" lists the literal property keys + their types.
- "Why we care" is one sentence — what does this number tell us 6 months from now?
-->

## Feature Flags

| Flag        | Controls                  | Default                         |
| ----------- | ------------------------- | ------------------------------- |
| <flag-name> | <what code path it gates> | <true \| false \| variant-name> |

<!--
- One row per flag read from PostHog (or whichever flag provider).
- Default is the value used when the flag service is unreachable.
-->

## Dashboards

<!--
List the canonical dashboards the operator/oncall watches. Each entry:

- **<dashboard-name>**: <URL> — <what it surfaces; when to look at it>
-->

_No dashboards configured yet._

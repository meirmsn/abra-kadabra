-- Template seed: auth fixtures for local dev + CI integration tests.
-- Shape per kit/docs/guide/migrations.md § seed.sql gotrue compatibility.
-- ON CONFLICT DO NOTHING for idempotence (supabase db reset runs this on every reset).
--
-- Two users with deterministic UUIDs so integration tests can reference by ID.
-- supabase-bootstrap.sh (pre-ship preflight) expects both in auth.users.
--   alice: 00000000-0000-0000-0000-000000000001
--   bob:   00000000-0000-0000-0000-000000000002
-- Password for both: password123

INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  email_change, recovery_token, confirmation_token, email_change_token_new,
  raw_app_meta_data, raw_user_meta_data, aud, role,
  created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'alice@test.local',
  crypt('password123', gen_salt('bf')),
  now(),
  '', '', '', '',
  '{"provider":"email","providers":["email"]}',
  '{}',
  'authenticated', 'authenticated',
  now(), now()
), (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'bob@test.local',
  crypt('password123', gen_salt('bf')),
  now(),
  '', '', '', '',
  '{"provider":"email","providers":["email"]}',
  '{}',
  'authenticated', 'authenticated',
  now(), now()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id, user_id, provider, provider_id, identity_data, last_sign_in_at,
  created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000001',
  'email',
  '00000000-0000-0000-0000-000000000001',
  jsonb_build_object('sub', '00000000-0000-0000-0000-000000000001', 'email', 'alice@test.local'),
  now(), now(), now()
), (
  '00000000-0000-0000-0000-000000000012',
  '00000000-0000-0000-0000-000000000002',
  'email',
  '00000000-0000-0000-0000-000000000002',
  jsonb_build_object('sub', '00000000-0000-0000-0000-000000000002', 'email', 'bob@test.local'),
  now(), now(), now()
)
ON CONFLICT (id) DO NOTHING;

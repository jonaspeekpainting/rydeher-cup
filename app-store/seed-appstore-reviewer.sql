-- App Store review account for production Neon
-- Email:    appstore.review@rydeher.cup
-- Password: ReviewCup2026!
--
-- Run once in Neon SQL Editor.

BEGIN;

-- 1) Auth user (bcrypt cost 12, matches the API)
INSERT INTO users (id, email, password_hash)
VALUES (
  'a1111111-1111-4111-8111-111111111111',
  'appstore.review@rydeher.cup',
  '$2b$12$nl9l85ZqOgDX6fStEvMPbOrXfsdhP8Ffs7mEHwlm4gi546gP7xXUC'
)
ON CONFLICT (id) DO UPDATE
SET
  email = EXCLUDED.email,
  password_hash = EXCLUDED.password_hash;

-- 2) Invite (claimed so signup is not required)
INSERT INTO invite_list (email, display_name, is_admin, claimed_at, user_id)
SELECT
  'appstore.review@rydeher.cup',
  'App Store Reviewer',
  false,
  now(),
  'a1111111-1111-4111-8111-111111111111'
WHERE NOT EXISTS (
  SELECT 1 FROM invite_list
  WHERE lower(trim(email)) = 'appstore.review@rydeher.cup'
);

UPDATE invite_list
SET
  display_name = 'App Store Reviewer',
  is_admin = false,
  claimed_at = COALESCE(claimed_at, now()),
  user_id = 'a1111111-1111-4111-8111-111111111111'
WHERE lower(trim(email)) = 'appstore.review@rydeher.cup';

-- 3) Profile (Hookers if that team exists)
INSERT INTO profiles (
  id,
  email,
  display_name,
  is_admin,
  ghin_number,
  handicap_index,
  course_handicap,
  handicap_source,
  handicap_updated_at,
  team_id
)
VALUES (
  'a1111111-1111-4111-8111-111111111111',
  'appstore.review@rydeher.cup',
  'App Store Reviewer',
  false,
  '0000000',
  12.4,
  14,
  'manual',
  now(),
  (SELECT id FROM teams WHERE slug = 'hookers' LIMIT 1)
)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  display_name = EXCLUDED.display_name,
  ghin_number = EXCLUDED.ghin_number,
  handicap_index = EXCLUDED.handicap_index,
  course_handicap = EXCLUDED.course_handicap,
  handicap_source = EXCLUDED.handicap_source,
  handicap_updated_at = EXCLUDED.handicap_updated_at,
  team_id = COALESCE(profiles.team_id, EXCLUDED.team_id);

COMMIT;

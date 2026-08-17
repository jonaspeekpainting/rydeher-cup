-- Upsert all tournament players with real emails + handicaps.
-- Password for each account: lowercase last name + "test"
--   e.g. Will Wilson → wilsontest, Jonas Peek → peektest
--
-- Also normalizes roster spellings (Goodhart / McLennan / Fischer).
-- Run in Neon SQL Editor.

BEGIN;

CREATE TEMP TABLE seed_players (
  id uuid PRIMARY KEY,
  display_name text NOT NULL,
  email text NOT NULL,
  team_slug text NOT NULL CHECK (team_slug IN ('hookers', 'slicers')),
  is_admin boolean NOT NULL DEFAULT false,
  handicap_index numeric(4, 1) NOT NULL,
  password_hash text NOT NULL
);

INSERT INTO seed_players (
  id, display_name, email, team_slug, is_admin, handicap_index, password_hash
) VALUES
  -- Hookers
  (
    '11111111-1111-4111-8111-111111111106',
    'Will Wilson', 'will.wilson468@gmail.com', 'hookers', false, -0.5,
    '$2b$12$Et1PFXORGKgxENKdEYsrd.mcUT438Oud8p6LE9holzVu.SJgoFCpi'
  ),
  (
    '11111111-1111-4111-8111-111111111104',
    'Kyle Jonas', 'kylejonas22@gmail.com', 'hookers', false, 4.4,
    '$2b$12$jPJfPKPXNT1KhQJYWer8TOdaISbG59QwWBe7sEibDwCxOzTxJEFeO'
  ),
  (
    '11111111-1111-4111-8111-111111111108',
    'Jared Weinerman', 'jaredweinerman2@gmail.com', 'hookers', false, 3.2,
    '$2b$12$rUCQ1XVjcHX1.//aCJHzN.9khaEL/nDNgRVjzCdtQFpv2zO.ntjz6'
  ),
  (
    '11111111-1111-4111-8111-111111111107',
    'Cole Smith', 'csmithvols10@gmail.com', 'hookers', false, 4.5,
    '$2b$12$/W6Iq4lUwZDTeUigz176S.CRUVz2CbWfG28rcuSyfHUrxhGXAuOlG'
  ),
  (
    '11111111-1111-4111-8111-111111111105',
    'Spencer Smith', 'spencersmith219@gmail.com', 'hookers', false, 2.9,
    '$2b$12$/W6Iq4lUwZDTeUigz176S.CRUVz2CbWfG28rcuSyfHUrxhGXAuOlG'
  ),
  (
    '11111111-1111-4111-8111-111111111101',
    'Tyler Schmalz', 'tschmalz13@gmail.com', 'hookers', false, 5.0,
    '$2b$12$goya9V2GVbQLb3m1yHlF9u7sF/QDvJyWfppucT9rqtDUVGRKGEUmu'
  ),
  (
    '11111111-1111-4111-8111-111111111102',
    'Jonas Peek', 'jonaspeek@gmail.com', 'hookers', true, 11.1,
    '$2b$12$rJ3lzgFOsjLNL6Dy4TzxG.Bvou3LAc8BhlSas3HZMtkQE/Vy8KSqi'
  ),
  (
    '11111111-1111-4111-8111-111111111110',
    'Cash Goodhart', 'cashgoodhart2@gmail.com', 'hookers', false, 12.5,
    '$2b$12$RJFQCmjtQhGoQPvXafyfUeQ/iy8MvIWdw7QbiBbk9HF/kUq.ZjAlS'
  ),
  (
    '11111111-1111-4111-8111-111111111109',
    'Zach Keller', 'zkelshp@gmail.com', 'hookers', false, 12.7,
    '$2b$12$.Hab1jPfNDddAOLmfbPFPOwxwSHLF7PV.hpGkm6gyx5kipPVArs7K'
  ),
  (
    '11111111-1111-4111-8111-111111111103',
    'Jay Bolton', 'boltonj21@gmail.com', 'hookers', false, 19.7,
    '$2b$12$AV4GztWu00n5sVCr.fwM0OeK.YF1oocy2lPhjrXXj0WI6gYLJfJQm'
  ),
  -- Slicers
  (
    '22222222-2222-4222-8222-222222222205',
    'Wes Bevins', 'wesbevins@gmail.com', 'slicers', false, -0.8,
    '$2b$12$XLhzpfeYJa/GxoEi8qFuBuRIrPhRpoNRmAQxQwX7qckiwznR4jK3u'
  ),
  (
    '22222222-2222-4222-8222-222222222204',
    'Bryan McLennan', 'bryanmclennan561@gmail.com', 'slicers', false, 1.6,
    '$2b$12$ckadrggj1u54tXwyGX/fxOJmWJhJyr/6nF0l.b.x8hHYizya4iTP.'
  ),
  (
    '22222222-2222-4222-8222-222222222203',
    'Mike Fischer', 'mfischergroupllc@gmail.com', 'slicers', false, 4.7,
    '$2b$12$3KW2WGlhMsBIkbvUyovlB.2Gm4Z5iZ4E0.o79BOXtydpEC3h45UsW'
  ),
  (
    '22222222-2222-4222-8222-222222222201',
    'Dylan Schmalz', 'dylanschmalz@gmail.com', 'slicers', false, 5.8,
    '$2b$12$goya9V2GVbQLb3m1yHlF9u7sF/QDvJyWfppucT9rqtDUVGRKGEUmu'
  ),
  (
    '22222222-2222-4222-8222-222222222202',
    'Erik Sarier', 'esarier06@gmail.com', 'slicers', false, 3.0,
    '$2b$12$nKn3mILI86euffDJkMGowO58r2ykz79KmT4fZGnT5Yi9mEO50SvvO'
  ),
  (
    '22222222-2222-4222-8222-222222222207',
    'Trent Gutstein', 'gutsteint@gmail.com', 'slicers', false, 5.6,
    '$2b$12$9QqGo7ic7NzXfhrsuCxQeOHNr..4dxHCOppnu5XM.0NviCUGy7v52'
  ),
  (
    '22222222-2222-4222-8222-222222222206',
    'Henry Kearing', 'henrykearing98@gmail.com', 'slicers', false, 7.1,
    '$2b$12$gs8b17avg/txi2NUZxooxuywSpVphawllcg07.j8cMX0KGp1PH18u'
  ),
  (
    '22222222-2222-4222-8222-222222222208',
    'Aidan Cohane', 'aidancohane@gmail.com', 'slicers', false, 8.5,
    '$2b$12$G7GTNbA4FndzFt594m7pDOCxQRKpIrQqnSgBNDOVTzhB2ebK9W216'
  ),
  (
    '22222222-2222-4222-8222-222222222209',
    'Ben Murtagh', 'benmurtagh3@gmail.com', 'slicers', false, 10.3,
    '$2b$12$eR1wqDm0499WDkJygORMSeJKDcxV0adlhAAb4ptBgMDibmV639G0.'
  ),
  (
    '22222222-2222-4222-8222-222222222210',
    'Chris Regan', 'chrisregan677@gmail.com', 'slicers', false, 15.0,
    '$2b$12$lqwxie6HGkgS.C/mDpWCIuVKIv9jR72uymEhhCL7sQ35Fq9naBVMu'
  );

-- Normalize roster / invite / profile spellings
UPDATE roster_entries SET display_name = 'Cash Goodhart'
WHERE lower(trim(display_name)) IN ('cash goodhart', 'cash goodheart');
UPDATE roster_entries SET display_name = 'Bryan McLennan'
WHERE lower(trim(display_name)) IN ('bryan mclennan', 'bryan mcllenan', 'bryan mcclennan');
UPDATE roster_entries SET display_name = 'Mike Fischer'
WHERE lower(trim(display_name)) IN ('mike fischer', 'mike fisher');

UPDATE invite_list SET display_name = 'Cash Goodhart'
WHERE lower(trim(display_name)) IN ('cash goodhart', 'cash goodheart');
UPDATE invite_list SET display_name = 'Bryan McLennan'
WHERE lower(trim(display_name)) IN ('bryan mclennan', 'bryan mcllenan', 'bryan mcclennan');
UPDATE invite_list SET display_name = 'Mike Fischer'
WHERE lower(trim(display_name)) IN ('mike fischer', 'mike fisher');

UPDATE profiles SET display_name = 'Cash Goodhart'
WHERE lower(trim(display_name)) IN ('cash goodhart', 'cash goodheart');
UPDATE profiles SET display_name = 'Bryan McLennan'
WHERE lower(trim(display_name)) IN ('bryan mclennan', 'bryan mcllenan', 'bryan mcclennan');
UPDATE profiles SET display_name = 'Mike Fischer'
WHERE lower(trim(display_name)) IN ('mike fischer', 'mike fisher');

-- Resolve which user id to use per player: existing roster link → email match → seed id
CREATE TEMP TABLE seed_targets AS
SELECT
  sp.*,
  t.id AS team_id,
  re.id AS roster_id,
  COALESCE(
    re.profile_id,
    (
      SELECT u.id FROM users u
      WHERE lower(trim(u.email)) = lower(trim(sp.email))
      LIMIT 1
    ),
    (
      SELECT p.id FROM profiles p
      WHERE lower(trim(p.display_name)) = lower(trim(sp.display_name))
      LIMIT 1
    ),
    sp.id
  ) AS user_id
FROM seed_players sp
JOIN teams t ON t.slug = sp.team_slug
JOIN roster_entries re
  ON re.team_id = t.id
 AND lower(trim(re.display_name)) = lower(trim(sp.display_name));

-- Free real emails held by leftover seed / wrong accounts, then upsert users
UPDATE users u
SET email = 'old.' || substr(replace(u.id::text, '-', ''), 1, 12) || '.' || u.email
FROM seed_targets st
WHERE lower(trim(u.email)) = lower(trim(st.email))
  AND u.id <> st.user_id;

INSERT INTO users (id, email, password_hash)
SELECT user_id, email, password_hash
FROM seed_targets
ON CONFLICT (id) DO UPDATE
SET
  email = EXCLUDED.email,
  password_hash = EXCLUDED.password_hash;

UPDATE users u
SET
  email = st.email,
  password_hash = st.password_hash
FROM seed_targets st
WHERE u.id = st.user_id;

-- Upsert profiles
INSERT INTO profiles (
  id, email, display_name, is_admin,
  handicap_index, course_handicap,
  handicap_source, handicap_updated_at, team_id
)
SELECT
  user_id,
  email,
  display_name,
  is_admin,
  handicap_index,
  round(handicap_index)::int,
  'manual',
  now(),
  team_id
FROM seed_targets
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  display_name = EXCLUDED.display_name,
  is_admin = EXCLUDED.is_admin,
  handicap_index = EXCLUDED.handicap_index,
  course_handicap = EXCLUDED.course_handicap,
  handicap_source = EXCLUDED.handicap_source,
  handicap_updated_at = EXCLUDED.handicap_updated_at,
  team_id = EXCLUDED.team_id;

-- Invites
INSERT INTO invite_list (
  email, display_name, is_admin, handicap_index, claimed_at, user_id
)
SELECT
  email, display_name, is_admin, handicap_index, now(), user_id
FROM seed_targets
WHERE NOT EXISTS (
  SELECT 1 FROM invite_list i
  WHERE lower(trim(i.email)) = lower(trim(seed_targets.email))
);

UPDATE invite_list i
SET
  display_name = st.display_name,
  is_admin = st.is_admin,
  handicap_index = st.handicap_index,
  claimed_at = COALESCE(i.claimed_at, now()),
  user_id = st.user_id
FROM seed_targets st
WHERE lower(trim(i.email)) = lower(trim(st.email));

-- Also claim any invite that already matches by display name
UPDATE invite_list i
SET
  email = st.email,
  is_admin = st.is_admin,
  handicap_index = st.handicap_index,
  claimed_at = COALESCE(i.claimed_at, now()),
  user_id = st.user_id
FROM seed_targets st
WHERE lower(trim(i.display_name)) = lower(trim(st.display_name))
  AND lower(trim(i.email)) <> lower(trim(st.email))
  AND NOT EXISTS (
    SELECT 1 FROM invite_list x
    WHERE lower(trim(x.email)) = lower(trim(st.email))
  );

-- Link roster
UPDATE roster_entries re
SET
  profile_id = st.user_id,
  email = st.email,
  display_name = st.display_name
FROM seed_targets st
WHERE re.id = st.roster_id;

COMMIT;

-- Password cheat sheet (lastname + "test"):
-- Will Wilson       → wilsontest
-- Kyle Jonas        → jonastest
-- Jared Weinerman   → weinermantest
-- Cole / Spencer    → smithtest
-- Tyler / Dylan     → schmalztest
-- Jonas Peek        → peektest
-- Cash Goodhart     → goodharttest
-- Zach Keller       → kellertest
-- Jay Bolton        → boltontest
-- Wes Bevins        → bevinstest
-- Bryan McLennan    → mclennantest
-- Mike Fischer      → fischertest
-- Erik Sarier       → sariertest
-- Trent Gutstein    → gutsteintest
-- Henry Kearing     → kearingtest
-- Aidan Cohane      → cohanetest
-- Ben Murtagh       → murtaghtest
-- Chris Regan       → regantest
--
-- Sanity:
-- SELECT display_name, email, handicap_index FROM profiles ORDER BY display_name;

-- Ryde-Her Cup MVP: teams, handicaps, courses, sessions, scoring
-- Run after 001_initial_schema.sql

-- ---------------------------------------------------------------------------
-- Teams
-- ---------------------------------------------------------------------------
CREATE TABLE teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE CHECK (slug IN ('hookers', 'slicers')),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO teams (slug, name) VALUES
  ('hookers', 'Hookers'),
  ('slicers', 'Slicers')
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Roster (names before / after signup)
-- ---------------------------------------------------------------------------
CREATE TABLE roster_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  display_name text NOT NULL,
  email text,
  profile_id uuid REFERENCES profiles (id) ON DELETE SET NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX roster_entries_email_unique
  ON roster_entries (lower(trim(email)))
  WHERE email IS NOT NULL;

CREATE INDEX roster_entries_team_idx ON roster_entries (team_id);
CREATE INDEX roster_entries_profile_idx ON roster_entries (profile_id);

-- ---------------------------------------------------------------------------
-- Profiles: GHIN / handicap / team
-- ---------------------------------------------------------------------------
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS ghin_number text,
  ADD COLUMN IF NOT EXISTS handicap_index numeric(4, 1),
  ADD COLUMN IF NOT EXISTS course_handicap int,
  ADD COLUMN IF NOT EXISTS handicap_source text
    CHECK (handicap_source IS NULL OR handicap_source IN ('ghin', 'manual')),
  ADD COLUMN IF NOT EXISTS handicap_updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES teams (id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- Tournament settings
-- ---------------------------------------------------------------------------
ALTER TABLE tournament_settings
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS starts_on date,
  ADD COLUMN IF NOT EXISTS ends_on date;

UPDATE tournament_settings
SET
  event_name = 'Ryde-Her Cup ''26',
  location = 'Boyne, Michigan',
  starts_on = '2026-08-20',
  ends_on = '2026-08-22',
  updated_at = now()
WHERE id = 1;

-- ---------------------------------------------------------------------------
-- Courses (cached from OpenGolfAPI)
-- ---------------------------------------------------------------------------
CREATE TABLE courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id text NOT NULL UNIQUE,
  name text NOT NULL,
  city text,
  state text,
  raw_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE course_tees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES courses (id) ON DELETE CASCADE,
  external_id text,
  name text NOT NULL,
  color text,
  rating numeric(4, 1),
  slope int,
  total_yardage int,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX course_tees_course_idx ON course_tees (course_id);

CREATE TABLE course_holes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES courses (id) ON DELETE CASCADE,
  tee_id uuid REFERENCES course_tees (id) ON DELETE CASCADE,
  hole_number int NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  par int NOT NULL CHECK (par BETWEEN 3 AND 6),
  stroke_index int CHECK (stroke_index BETWEEN 1 AND 18),
  yardage int,
  UNIQUE (course_id, tee_id, hole_number)
);

CREATE INDEX course_holes_course_idx ON course_holes (course_id);

-- ---------------------------------------------------------------------------
-- Sessions (6 rounds)
-- ---------------------------------------------------------------------------
CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  day text NOT NULL CHECK (day IN ('thu', 'fri', 'sat')),
  round_number int NOT NULL CHECK (round_number BETWEEN 1 AND 6),
  session_date date NOT NULL,
  label text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (round_number)
);

INSERT INTO sessions (day, round_number, session_date, label, sort_order) VALUES
  ('thu', 1, '2026-08-20', 'Thursday AM', 1),
  ('thu', 2, '2026-08-20', 'Thursday PM', 2),
  ('fri', 3, '2026-08-21', 'Friday AM', 3),
  ('fri', 4, '2026-08-21', 'Friday PM', 4),
  ('sat', 5, '2026-08-22', 'Saturday AM', 5),
  ('sat', 6, '2026-08-22', 'Saturday PM', 6)
ON CONFLICT (round_number) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Matches (enrich stub table)
-- ---------------------------------------------------------------------------
ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS session_id uuid REFERENCES sessions (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS format text
    CHECK (
      format IS NULL
      OR format IN (
        'best_ball_match',
        'scramble',
        'shamble',
        'singles_match',
        'alternate_shot'
      )
    ),
  ADD COLUMN IF NOT EXISTS course_id uuid REFERENCES courses (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS tee_id uuid REFERENCES course_tees (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS scoring_visibility text NOT NULL DEFAULT 'release_on_complete'
    CHECK (scoring_visibility IN ('live', 'release_on_complete')),
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'setup'
    CHECK (status IN ('setup', 'in_progress', 'complete')),
  ADD COLUMN IF NOT EXISTS playing_handicaps jsonb,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE match_players
  DROP CONSTRAINT IF EXISTS match_players_side_check;

ALTER TABLE match_players
  ADD CONSTRAINT match_players_side_check
  CHECK (side IS NULL OR side IN ('hookers', 'slicers'));

-- ---------------------------------------------------------------------------
-- Hole scores
-- ---------------------------------------------------------------------------
CREATE TABLE hole_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  hole_number int NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  -- Per-player gross (best ball, shamble, singles)
  profile_id uuid REFERENCES profiles (id) ON DELETE CASCADE,
  -- Team ball gross (scramble, alternate shot)
  side text CHECK (side IS NULL OR side IN ('hookers', 'slicers')),
  gross_strokes int NOT NULL CHECK (gross_strokes BETWEEN 1 AND 15),
  updated_by uuid REFERENCES profiles (id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hole_scores_player_or_side CHECK (
    (profile_id IS NOT NULL AND side IS NULL)
    OR (profile_id IS NULL AND side IS NOT NULL)
  )
);

CREATE UNIQUE INDEX hole_scores_player_unique
  ON hole_scores (match_id, hole_number, profile_id)
  WHERE profile_id IS NOT NULL;

CREATE UNIQUE INDEX hole_scores_side_unique
  ON hole_scores (match_id, hole_number, side)
  WHERE side IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Match-play hole outcomes
-- ---------------------------------------------------------------------------
CREATE TABLE match_hole_outcomes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  hole_number int NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  winner_side text CHECK (
    winner_side IS NULL OR winner_side IN ('hookers', 'slicers')
  ),
  -- NULL winner_side means halved
  UNIQUE (match_id, hole_number)
);

-- ---------------------------------------------------------------------------
-- Match results (cup points)
-- ---------------------------------------------------------------------------
CREATE TABLE match_results (
  match_id uuid PRIMARY KEY REFERENCES matches (id) ON DELETE CASCADE,
  hookers_points numeric(2, 1) NOT NULL DEFAULT 0
    CHECK (hookers_points IN (0, 0.5, 1)),
  slicers_points numeric(2, 1) NOT NULL DEFAULT 0
    CHECK (slicers_points IN (0, 0.5, 1)),
  is_provisional boolean NOT NULL DEFAULT false,
  holes_won_hookers int NOT NULL DEFAULT 0,
  holes_won_slicers int NOT NULL DEFAULT 0,
  holes_halved int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT match_results_points_sum CHECK (
    hookers_points + slicers_points = 1
  )
);

-- ---------------------------------------------------------------------------
-- Seed roster (emails filled in later via invites)
-- ---------------------------------------------------------------------------
INSERT INTO roster_entries (team_id, display_name, sort_order)
SELECT t.id, r.display_name, r.sort_order
FROM teams t
JOIN (
  VALUES
    ('hookers', 'Tyler Schmalz', 1),
    ('hookers', 'Jonas Peek', 2),
    ('hookers', 'Jay Bolton', 3),
    ('hookers', 'Kyle Jonas', 4),
    ('hookers', 'Carter Armstrong', 5),
    ('hookers', 'Will Wilson', 6),
    ('hookers', 'Cole Smith', 7),
    ('hookers', 'Jared Weinerman', 8),
    ('hookers', 'Zach Keller', 9),
    ('hookers', 'Cash Goodheart', 10),
    ('slicers', 'Dylan Schmalz', 1),
    ('slicers', 'Erik Sarier', 2),
    ('slicers', 'Mike Fischer', 3),
    ('slicers', 'Bryan McClennan', 4),
    ('slicers', 'Wes Bevins', 5),
    ('slicers', 'Henry Kearing', 6),
    ('slicers', 'Trent Gutstein', 7),
    ('slicers', 'Aidan Cohane', 8),
    ('slicers', 'Ben Murtagh', 9),
    ('slicers', 'Chris Regan', 10)
) AS r(slug, display_name, sort_order) ON r.slug = t.slug
WHERE NOT EXISTS (
  SELECT 1 FROM roster_entries re
  WHERE re.team_id = t.id AND re.display_name = r.display_name
);

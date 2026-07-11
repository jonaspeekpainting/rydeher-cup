-- RyderHer Cup: Neon / Vercel Postgres schema
-- Run once in Neon SQL Editor (linked from your Vercel project Storage tab).

-- ---------------------------------------------------------------------------
-- Users (replaces Supabase auth.users; passwords stored as bcrypt hashes)
-- ---------------------------------------------------------------------------
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX users_email_unique ON users (lower(trim(email)));

-- ---------------------------------------------------------------------------
-- Invite list (pre-provisioned emails before anyone signs up)
-- ---------------------------------------------------------------------------
CREATE TABLE invite_list (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  display_name text NOT NULL,
  is_admin boolean NOT NULL DEFAULT false,
  claimed_at timestamptz,
  user_id uuid REFERENCES users (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX invite_list_email_unique ON invite_list (lower(trim(email)));

CREATE OR REPLACE FUNCTION invite_list_normalize_email()
RETURNS trigger AS $$
BEGIN
  NEW.email := lower(trim(NEW.email));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER invite_list_normalize_email
  BEFORE INSERT OR UPDATE OF email ON invite_list
  FOR EACH ROW
  EXECUTE FUNCTION invite_list_normalize_email();

-- ---------------------------------------------------------------------------
-- Profiles (one row per user; created on signup)
-- ---------------------------------------------------------------------------
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  email text NOT NULL,
  display_name text NOT NULL,
  is_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX profiles_email_idx ON profiles (lower(trim(email)));

-- ---------------------------------------------------------------------------
-- Tournament metadata (optional row for event name, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE tournament_settings (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  event_name text NOT NULL DEFAULT 'RyderHer Cup',
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tournament_settings_singleton CHECK (id = 1)
);

INSERT INTO tournament_settings (id, event_name) VALUES (1, 'RyderHer Cup')
  ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Match stubs (admin-managed later)
-- ---------------------------------------------------------------------------
CREATE TABLE matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label text NOT NULL DEFAULT 'Match',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE match_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
  side text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_id, profile_id)
);

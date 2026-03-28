-- RyderHer Cup: invite list, profiles, tournament metadata, match stubs
-- Run in Supabase SQL Editor or via `supabase db push` after linking the project.

-- ---------------------------------------------------------------------------
-- Invite list (pre-provisioned emails before anyone signs up)
-- ---------------------------------------------------------------------------
CREATE TABLE public.invite_list (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  display_name text NOT NULL,
  is_admin boolean NOT NULL DEFAULT false,
  claimed_at timestamptz,
  auth_user_id uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX invite_list_email_unique ON public.invite_list (lower(trim(email)));

CREATE OR REPLACE FUNCTION public.invite_list_normalize_email()
RETURNS trigger AS $$
BEGIN
  NEW.email := lower(trim(NEW.email));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER invite_list_normalize_email
  BEFORE INSERT OR UPDATE OF email ON public.invite_list
  FOR EACH ROW
  EXECUTE PROCEDURE public.invite_list_normalize_email();

ALTER TABLE public.invite_list ENABLE ROW LEVEL SECURITY;

-- No client access; service role / Edge Functions only
CREATE POLICY "invite_list_no_access"
  ON public.invite_list
  FOR ALL
  USING (false)
  WITH CHECK (false);

-- ---------------------------------------------------------------------------
-- Profiles (one row per auth user; created on signup)
-- ---------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email text NOT NULL,
  display_name text NOT NULL,
  is_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX profiles_email_idx ON public.profiles (lower(trim(email)));

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_authenticated"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "profiles_update_own"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ---------------------------------------------------------------------------
-- Tournament metadata (optional row for event name, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE public.tournament_settings (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  event_name text NOT NULL DEFAULT 'RyderHer Cup',
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tournament_settings_singleton CHECK (id = 1)
);

INSERT INTO public.tournament_settings (id, event_name) VALUES (1, 'RyderHer Cup')
  ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.tournament_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tournament_settings_read_authenticated"
  ON public.tournament_settings
  FOR SELECT
  TO authenticated
  USING (true);

-- ---------------------------------------------------------------------------
-- Match stubs (admin-managed later)
-- ---------------------------------------------------------------------------
CREATE TABLE public.matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  label text NOT NULL DEFAULT 'Match',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.match_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES public.matches (id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  side text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_id, profile_id)
);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "matches_read_authenticated"
  ON public.matches
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "match_players_read_authenticated"
  ON public.match_players
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "matches_write_admins"
  ON public.matches
  FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = true)
  );

CREATE POLICY "match_players_write_admins"
  ON public.match_players
  FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = true)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = true)
  );

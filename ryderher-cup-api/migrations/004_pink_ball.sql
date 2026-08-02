-- Pink ball side game (best ball foursomes only).
-- One carrier per hole for the group; max 3 lost balls per match.

CREATE TABLE IF NOT EXISTS pink_ball_holes (
  match_id uuid NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  hole_number int NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
  carrier_profile_id uuid NOT NULL REFERENCES profiles (id),
  lost boolean NOT NULL DEFAULT false,
  updated_by uuid REFERENCES profiles (id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, hole_number)
);

CREATE INDEX IF NOT EXISTS pink_ball_holes_match_idx
  ON pink_ball_holes (match_id, hole_number);

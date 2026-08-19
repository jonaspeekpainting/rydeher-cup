-- Allow account deletion to cascade pink-ball carrier rows.
-- delete-account.ts also deletes these rows explicitly for hosts that have
-- not applied this migration yet.

ALTER TABLE pink_ball_holes
  DROP CONSTRAINT IF EXISTS pink_ball_holes_carrier_profile_id_fkey;

ALTER TABLE pink_ball_holes
  ADD CONSTRAINT pink_ball_holes_carrier_profile_id_fkey
  FOREIGN KEY (carrier_profile_id) REFERENCES profiles (id) ON DELETE CASCADE;

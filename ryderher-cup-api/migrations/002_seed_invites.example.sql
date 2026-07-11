-- Example: add guests who are allowed to sign up.
-- Edit emails/names, then run in Neon SQL Editor after 001_initial_schema.sql.

INSERT INTO invite_list (email, display_name, is_admin)
VALUES
  ('you@example.com', 'Your Name', true),
  ('friend@example.com', 'Friend Name', false);

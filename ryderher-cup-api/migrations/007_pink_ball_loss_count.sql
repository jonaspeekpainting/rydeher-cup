-- Allow more than one pink ball to be lost on the same hole.

ALTER TABLE pink_ball_holes
  ADD COLUMN IF NOT EXISTS lost_count int NOT NULL DEFAULT 0;

UPDATE pink_ball_holes
SET lost_count = 1
WHERE lost = true AND lost_count = 0;

ALTER TABLE pink_ball_holes
  DROP CONSTRAINT IF EXISTS pink_ball_holes_lost_count_check;

ALTER TABLE pink_ball_holes
  ADD CONSTRAINT pink_ball_holes_lost_count_check
  CHECK (lost_count BETWEEN 0 AND 3);

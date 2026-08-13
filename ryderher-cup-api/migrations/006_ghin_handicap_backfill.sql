-- GHIN lives on the invite so signup does not ask for it.
-- Backfill known 2026 numbers onto invites + existing profiles.

ALTER TABLE invite_list
  ADD COLUMN IF NOT EXISTS ghin_number text,
  ADD COLUMN IF NOT EXISTS handicap_index numeric(4, 1);

UPDATE profiles p
SET
  ghin_number = k.ghin,
  handicap_index = k.idx,
  handicap_source = 'manual',
  handicap_updated_at = now()
FROM (
  VALUES
    ('zach keller', '12969854', 12.9::numeric),
    ('mike fisher', '2715400', 4.4),
    ('mike fischer', '2715400', 4.4),
    ('bryan mcllenan', '225786', 1.6),
    ('bryan mcclennan', '225786', 1.6),
    ('jonas peek', '12301730', 11.4),
    ('spencer smith', '1119955', 5.7),
    ('tyler schmalz', '11520131', 6.5),
    ('henry kearing', '11484161', 7.0),
    ('jared weinerman', '11581180', 4.1),
    ('cash goodheart', '13687128', 12.5),
    ('erik sarier', '11723835', 5.5),
    ('dylan schmalz', '3125430', 5.4),
    ('trent gutstein', '4990734', 7.0),
    ('trent', '4990734', 7.0),
    ('cole smith', '12042625', 5.1),
    ('kyle jonas', '445151', 3.3),
    ('will wilson', '203528', -0.5)
) AS k(name_key, ghin, idx)
WHERE lower(trim(p.display_name)) = k.name_key;

UPDATE invite_list i
SET
  ghin_number = k.ghin,
  handicap_index = k.idx
FROM (
  VALUES
    ('zach keller', '12969854', 12.9::numeric),
    ('mike fisher', '2715400', 4.4),
    ('mike fischer', '2715400', 4.4),
    ('bryan mcllenan', '225786', 1.6),
    ('bryan mcclennan', '225786', 1.6),
    ('jonas peek', '12301730', 11.4),
    ('spencer smith', '1119955', 5.7),
    ('tyler schmalz', '11520131', 6.5),
    ('henry kearing', '11484161', 7.0),
    ('jared weinerman', '11581180', 4.1),
    ('cash goodheart', '13687128', 12.5),
    ('erik sarier', '11723835', 5.5),
    ('dylan schmalz', '3125430', 5.4),
    ('trent gutstein', '4990734', 7.0),
    ('trent', '4990734', 7.0),
    ('cole smith', '12042625', 5.1),
    ('kyle jonas', '445151', 3.3),
    ('will wilson', '203528', -0.5)
) AS k(name_key, ghin, idx)
WHERE lower(trim(i.display_name)) = k.name_key;

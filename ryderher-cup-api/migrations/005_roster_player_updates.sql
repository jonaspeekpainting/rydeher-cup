-- Updated 2026 roster: Spencer replaces Carter; spelling + sort order fixes.

UPDATE roster_entries
SET display_name = 'Spencer Smith', sort_order = 7
WHERE display_name = 'Carter Armstrong';

UPDATE roster_entries SET display_name = 'Mike Fisher' WHERE display_name = 'Mike Fischer';
UPDATE roster_entries SET display_name = 'Bryan Mcllenan' WHERE display_name = 'Bryan McClennan';

UPDATE profiles SET display_name = 'Spencer Smith' WHERE display_name = 'Carter Armstrong';
UPDATE profiles SET display_name = 'Mike Fisher' WHERE display_name = 'Mike Fischer';
UPDATE profiles SET display_name = 'Bryan Mcllenan' WHERE display_name = 'Bryan McClennan';

UPDATE invite_list SET display_name = 'Spencer Smith' WHERE display_name = 'Carter Armstrong';
UPDATE invite_list SET display_name = 'Mike Fisher' WHERE display_name = 'Mike Fischer';
UPDATE invite_list SET display_name = 'Bryan Mcllenan' WHERE display_name = 'Bryan McClennan';

-- Hookers sort order (matches published team sheet)
UPDATE roster_entries SET sort_order = 1 WHERE display_name = 'Tyler Schmalz';
UPDATE roster_entries SET sort_order = 2 WHERE display_name = 'Cole Smith';
UPDATE roster_entries SET sort_order = 3 WHERE display_name = 'Zach Keller';
UPDATE roster_entries SET sort_order = 4 WHERE display_name = 'Kyle Jonas';
UPDATE roster_entries SET sort_order = 5 WHERE display_name = 'Jared Weinerman';
UPDATE roster_entries SET sort_order = 6 WHERE display_name = 'Will Wilson';
UPDATE roster_entries SET sort_order = 7 WHERE display_name = 'Spencer Smith';
UPDATE roster_entries SET sort_order = 8 WHERE display_name = 'Jonas Peek';
UPDATE roster_entries SET sort_order = 9 WHERE display_name = 'Jay Bolton';
UPDATE roster_entries SET sort_order = 10 WHERE display_name = 'Cash Goodheart';

-- Slicers sort order
UPDATE roster_entries SET sort_order = 1 WHERE display_name = 'Dylan Schmalz';
UPDATE roster_entries SET sort_order = 2 WHERE display_name = 'Mike Fisher';
UPDATE roster_entries SET sort_order = 3 WHERE display_name = 'Erik Sarier';
UPDATE roster_entries SET sort_order = 4 WHERE display_name = 'Henry Kearing';
UPDATE roster_entries SET sort_order = 5 WHERE display_name = 'Ben Murtagh';
UPDATE roster_entries SET sort_order = 6 WHERE display_name = 'Aidan Cohane';
UPDATE roster_entries SET sort_order = 7 WHERE display_name = 'Bryan Mcllenan';
UPDATE roster_entries SET sort_order = 8 WHERE display_name = 'Wes Bevins';
UPDATE roster_entries SET sort_order = 9 WHERE display_name = 'Chris Regan';
UPDATE roster_entries SET sort_order = 10 WHERE display_name = 'Trent Gutstein';

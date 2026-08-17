/**
 * Seed local DB with signed-up players, a Boyne course, and sample matches
 * so the iOS app can show a realistic registered-player experience.
 *
 * Password for every seeded account: password123
 *
 * Usage: npx tsx scripts/seed-dev.ts
 */
import pg from "pg";
import bcrypt from "bcryptjs";
import {
  computeMatchPlayResult,
  computePlayingHandicaps,
  netScore,
  strokesOnHole,
  type MatchFormat,
  type PlayerHandicapInput,
  type TeamSlug,
} from "../lib/handicaps";

const connectionString =
  process.env.POSTGRES_URL ??
  process.env.RYDEHER_POSTGRES_URL ??
  process.env.DATABASE_URL ??
  "postgres://rydeher:rydeher@127.0.0.1:5432/rydeher";

const PASSWORD = "password123";

type SeedPlayer = {
  id: string;
  displayName: string;
  email: string;
  team: TeamSlug;
  isAdmin: boolean;
  ghin: string;
  index: number;
  courseHandicap: number;
  /** Leave unsigned so Players tab shows “Not signed up yet”. */
  signedUp?: boolean;
};

const PLAYERS: SeedPlayer[] = [
  {
    id: "11111111-1111-4111-8111-111111111101",
    displayName: "Tyler Schmalz",
    email: "tyler@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "11520131",
    index: 6.5,
    courseHandicap: 7,
  },
  {
    id: "11111111-1111-4111-8111-111111111107",
    displayName: "Cole Smith",
    email: "cole@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "12042625",
    index: 5.1,
    courseHandicap: 5,
  },
  {
    id: "11111111-1111-4111-8111-111111111109",
    displayName: "Zach Keller",
    email: "zach@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "12969854",
    index: 12.9,
    courseHandicap: 14,
  },
  {
    id: "11111111-1111-4111-8111-111111111104",
    displayName: "Kyle Jonas",
    email: "kyle@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "445151",
    index: 3.3,
    courseHandicap: 3,
  },
  {
    id: "11111111-1111-4111-8111-111111111108",
    displayName: "Jared Weinerman",
    email: "jared@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "11581180",
    index: 4.1,
    courseHandicap: 4,
  },
  {
    id: "11111111-1111-4111-8111-111111111106",
    displayName: "Will Wilson",
    email: "will@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "203528",
    index: -0.5,
    courseHandicap: -1,
  },
  {
    id: "11111111-1111-4111-8111-111111111105",
    displayName: "Spencer Smith",
    email: "spencer@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "1119955",
    index: 5.7,
    courseHandicap: 6,
  },
  {
    id: "11111111-1111-4111-8111-111111111102",
    displayName: "Jonas Peek",
    email: "jonas@rydeher.local",
    team: "hookers",
    isAdmin: true,
    ghin: "12301730",
    index: 11.4,
    courseHandicap: 13,
  },
  {
    id: "11111111-1111-4111-8111-111111111103",
    displayName: "Jay Bolton",
    email: "jay@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "1000003",
    index: 19.7,
    courseHandicap: 22,
  },
  {
    id: "11111111-1111-4111-8111-111111111110",
    displayName: "Cash Goodheart",
    email: "cash@rydeher.local",
    team: "hookers",
    isAdmin: false,
    ghin: "13687128",
    index: 12.5,
    courseHandicap: 14,
    signedUp: false,
  },
  {
    id: "22222222-2222-4222-8222-222222222201",
    displayName: "Dylan Schmalz",
    email: "dylan@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "3125430",
    index: 5.4,
    courseHandicap: 6,
  },
  {
    id: "22222222-2222-4222-8222-222222222203",
    displayName: "Mike Fisher",
    email: "mike@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "2715400",
    index: 4.4,
    courseHandicap: 4,
  },
  {
    id: "22222222-2222-4222-8222-222222222202",
    displayName: "Erik Sarier",
    email: "erik@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "11723835",
    index: 5.5,
    courseHandicap: 6,
  },
  {
    id: "22222222-2222-4222-8222-222222222206",
    displayName: "Henry Kearing",
    email: "henry@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "11484161",
    index: 7.0,
    courseHandicap: 7,
  },
  {
    id: "22222222-2222-4222-8222-222222222209",
    displayName: "Ben Murtagh",
    email: "ben@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "2000009",
    index: 10.0,
    courseHandicap: 11,
  },
  {
    id: "22222222-2222-4222-8222-222222222208",
    displayName: "Aidan Cohane",
    email: "aidan@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "2000008",
    index: 12.0,
    courseHandicap: 13,
  },
  {
    id: "22222222-2222-4222-8222-222222222204",
    displayName: "Bryan Mcllenan",
    email: "bryan@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "225786",
    index: 1.6,
    courseHandicap: 1,
  },
  {
    id: "22222222-2222-4222-8222-222222222205",
    displayName: "Wes Bevins",
    email: "wes@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "2000005",
    index: -2.6,
    courseHandicap: -4,
  },
  {
    id: "22222222-2222-4222-8222-222222222210",
    displayName: "Chris Regan",
    email: "chris@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "2000010",
    index: 15.0,
    courseHandicap: 17,
    signedUp: false,
  },
  {
    id: "22222222-2222-4222-8222-222222222207",
    displayName: "Trent Gutstein",
    email: "trent@rydeher.local",
    team: "slicers",
    isAdmin: false,
    ghin: "4990734",
    index: 7.0,
    courseHandicap: 7,
  },
];

const COURSE_ID = "33333333-3333-4333-8333-333333333301";
const TEE_ID = "33333333-3333-4333-8333-333333333302";

const MATCH_IDS = {
  thuAm1: "44444444-4444-4444-8444-444444444401",
  thuAm2: "44444444-4444-4444-8444-444444444402",
  thuPm1: "44444444-4444-4444-8444-444444444403",
  friAmSetup: "44444444-4444-4444-8444-444444444404",
  friAmHidden: "44444444-4444-4444-8444-444444444405",
  friPmJonas: "44444444-4444-4444-8444-444444444406",
  satAm1: "44444444-4444-4444-8444-444444444411",
  satAm2: "44444444-4444-4444-8444-444444444412",
  satPm1: "44444444-4444-4444-8444-444444444407",
  satPm2: "44444444-4444-4444-8444-444444444408",
  satPm3: "44444444-4444-4444-8444-444444444409",
  satPm4: "44444444-4444-4444-8444-444444444410",
};

/** Typical Midwestern resort scorecard pars + stroke indexes. */
const HOLES: Array<{
  hole: number;
  par: number;
  si: number;
  yards: number;
}> = [
  { hole: 1, par: 4, si: 11, yards: 385 },
  { hole: 2, par: 5, si: 3, yards: 520 },
  { hole: 3, par: 3, si: 17, yards: 165 },
  { hole: 4, par: 4, si: 7, yards: 410 },
  { hole: 5, par: 4, si: 13, yards: 370 },
  { hole: 6, par: 5, si: 1, yards: 545 },
  { hole: 7, par: 3, si: 15, yards: 180 },
  { hole: 8, par: 4, si: 5, yards: 425 },
  { hole: 9, par: 4, si: 9, yards: 395 },
  { hole: 10, par: 4, si: 10, yards: 400 },
  { hole: 11, par: 5, si: 2, yards: 535 },
  { hole: 12, par: 3, si: 18, yards: 150 },
  { hole: 13, par: 4, si: 8, yards: 415 },
  { hole: 14, par: 4, si: 14, yards: 360 },
  { hole: 15, par: 5, si: 4, yards: 510 },
  { hole: 16, par: 3, si: 16, yards: 190 },
  { hole: 17, par: 4, si: 6, yards: 430 },
  { hole: 18, par: 4, si: 12, yards: 390 },
];

function player(name: string): SeedPlayer {
  const found = PLAYERS.find((p) => p.displayName === name);
  if (!found) {
    throw new Error(`Unknown player ${name}`);
  }
  return found;
}

async function main() {
  const client = new pg.Client({ connectionString });
  await client.connect();
  const passwordHash = await bcrypt.hash(PASSWORD, 12);

  try {
    await client.query("BEGIN");

    // Wipe tournament runtime data (keep teams / sessions / roster names from migrations)
    await client.query(`
      DELETE FROM match_results;
      DELETE FROM match_hole_outcomes;
      DELETE FROM pink_ball_holes;
      DELETE FROM hole_scores;
      DELETE FROM match_players;
      DELETE FROM matches;
      DELETE FROM course_holes;
      DELETE FROM course_tees;
      DELETE FROM courses;
      UPDATE roster_entries SET profile_id = NULL, email = NULL;
      UPDATE profiles SET team_id = NULL;
      DELETE FROM invite_list;
      DELETE FROM profiles;
      DELETE FROM users;
    `);

    const teams = await client.query<{ id: string; slug: TeamSlug }>(
      `SELECT id, slug FROM teams`,
    );
    const teamId = Object.fromEntries(
      teams.rows.map((t) => [t.slug, t.id]),
    ) as Record<TeamSlug, string>;

    const sessions = await client.query<{ id: string; round_number: number }>(
      `SELECT id, round_number FROM sessions ORDER BY round_number`,
    );
    const sessionByRound = Object.fromEntries(
      sessions.rows.map((s) => [s.round_number, s.id]),
    ) as Record<number, string>;

    // Invites + users/profiles + roster links
    for (const p of PLAYERS) {
      await client.query(
        `INSERT INTO invite_list (email, display_name, is_admin, ghin_number, handicap_index)
         VALUES ($1, $2, $3, $4, $5)`,
        [p.email, p.displayName, p.isAdmin, p.ghin, p.index],
      );

      await client.query(
        `UPDATE roster_entries
         SET email = $1
         WHERE team_id = $2 AND display_name = $3`,
        [p.email, teamId[p.team], p.displayName],
      );

      if (p.signedUp === false) {
        continue;
      }

      await client.query(
        `INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3)`,
        [p.id, p.email, passwordHash],
      );
      await client.query(
        `INSERT INTO profiles (
           id, email, display_name, is_admin,
           ghin_number, handicap_index, course_handicap,
           handicap_source, handicap_updated_at, team_id
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,'manual', now(), $8)`,
        [
          p.id,
          p.email,
          p.displayName,
          p.isAdmin,
          p.ghin,
          p.index,
          p.courseHandicap,
          teamId[p.team],
        ],
      );
      await client.query(
        `UPDATE invite_list
         SET claimed_at = now(), user_id = $1
         WHERE email = $2`,
        [p.id, p.email],
      );
      await client.query(
        `UPDATE roster_entries
         SET profile_id = $1
         WHERE team_id = $2 AND display_name = $3`,
        [p.id, teamId[p.team], p.displayName],
      );
    }

    // Course
    await client.query(
      `INSERT INTO courses (id, external_id, name, city, state, raw_payload)
       VALUES ($1, 'seed-heather', 'The Heather at Boyne Highlands', 'Harbor Springs', 'MI', '{}'::jsonb)`,
      [COURSE_ID],
    );
    await client.query(
      `INSERT INTO course_tees (id, course_id, external_id, name, color, rating, slope, total_yardage)
       VALUES ($1, $2, 'seed-white', 'White', 'White', 71.2, 132, 6685)`,
      [TEE_ID, COURSE_ID],
    );
    for (const h of HOLES) {
      await client.query(
        `INSERT INTO course_holes (course_id, tee_id, hole_number, par, stroke_index, yardage)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [COURSE_ID, TEE_ID, h.hole, h.par, h.si, h.yards],
      );
    }

    // ---- Matches ----
    // 1) Thu AM best ball — complete, Hookers win (live, counts on board)
    await seedBestBallMatch(client, {
      id: MATCH_IDS.thuAm1,
      label: "Match 1 · T. Schmalz / Peek vs D. Schmalz / Sarier",
      sortOrder: 1,
      sessionId: sessionByRound[1]!,
      format: "best_ball_match",
      visibility: "live",
      status: "complete",
      pairings: [
        { name: "Tyler Schmalz", side: "hookers" },
        { name: "Jonas Peek", side: "hookers" },
        { name: "Dylan Schmalz", side: "slicers" },
        { name: "Erik Sarier", side: "slicers" },
      ],
      holesPlayed: 18,
      hookersBias: -0.4,
    });

    // 2) Thu AM best ball — complete, Slicers win
    await seedBestBallMatch(client, {
      id: MATCH_IDS.thuAm2,
      label: "Match 2 · Bolton / Jonas vs Fisher / Mcllenan",
      sortOrder: 2,
      sessionId: sessionByRound[1]!,
      format: "best_ball_match",
      visibility: "live",
      status: "complete",
      pairings: [
        { name: "Jay Bolton", side: "hookers" },
        { name: "Kyle Jonas", side: "hookers" },
        { name: "Mike Fisher", side: "slicers" },
        { name: "Bryan Mcllenan", side: "slicers" },
      ],
      holesPlayed: 18,
      hookersBias: 0.35,
    });

    // 3) Thu PM scramble — in progress, live scores
    await seedTeamBallMatch(client, {
      id: MATCH_IDS.thuPm1,
      label: "Scramble · Armstrong / Wilson vs Bevins / Kearing",
      sortOrder: 3,
      sessionId: sessionByRound[2]!,
      format: "scramble",
      visibility: "live",
      status: "in_progress",
      pairings: [
        { name: "Spencer Smith", side: "hookers" },
        { name: "Will Wilson", side: "hookers" },
        { name: "Wes Bevins", side: "slicers" },
        { name: "Henry Kearing", side: "slicers" },
      ],
      holesPlayed: 9,
      hookersBias: -0.15,
    });

    // 4) Fri AM singles — upcoming setup
    await seedBestBallMatch(client, {
      id: MATCH_IDS.friAmSetup,
      label: "Singles · Smith vs Gutstein",
      sortOrder: 4,
      sessionId: sessionByRound[3]!,
      format: "singles_match",
      visibility: "release_on_complete",
      status: "setup",
      pairings: [
        { name: "Cole Smith", side: "hookers" },
        { name: "Trent Gutstein", side: "slicers" },
      ],
      holesPlayed: 0,
      hookersBias: 0,
    });

    // 5) Fri AM best ball — in progress, release-on-complete (hidden unless participant)
    await seedBestBallMatch(client, {
      id: MATCH_IDS.friAmHidden,
      label: "Match 5 · Weinerman / Keller vs Cohane / Murtagh",
      sortOrder: 5,
      sessionId: sessionByRound[3]!,
      format: "best_ball_match",
      visibility: "release_on_complete",
      status: "in_progress",
      pairings: [
        { name: "Jared Weinerman", side: "hookers" },
        { name: "Zach Keller", side: "hookers" },
        { name: "Aidan Cohane", side: "slicers" },
        { name: "Ben Murtagh", side: "slicers" },
      ],
      holesPlayed: 6,
      hookersBias: 0.1,
    });

    // 6) Fri PM — Jonas in a live match for score-entry testing
    await seedBestBallMatch(client, {
      id: MATCH_IDS.friPmJonas,
      label: "Your match · Peek / Bolton vs Sarier / Fisher",
      sortOrder: 6,
      sessionId: sessionByRound[4]!,
      format: "best_ball_match",
      visibility: "live",
      status: "in_progress",
      pairings: [
        { name: "Jonas Peek", side: "hookers" },
        { name: "Jay Bolton", side: "hookers" },
        { name: "Erik Sarier", side: "slicers" },
        { name: "Mike Fisher", side: "slicers" },
      ],
      holesPlayed: 4,
      hookersBias: -0.2,
    });

    // 7) Sat AM best ball — upcoming (setup). Start these to pick the
    //    first pink-ball player; no scores / pink ball rows yet.
    await seedBestBallMatch(client, {
      id: MATCH_IDS.satAm1,
      label: "Match 1 · Peek / T. Schmalz vs D. Schmalz / Sarier",
      sortOrder: 11,
      sessionId: sessionByRound[5]!,
      format: "best_ball_match",
      visibility: "live",
      status: "setup",
      pairings: [
        { name: "Jonas Peek", side: "hookers" },
        { name: "Tyler Schmalz", side: "hookers" },
        { name: "Dylan Schmalz", side: "slicers" },
        { name: "Erik Sarier", side: "slicers" },
      ],
      holesPlayed: 0,
      hookersBias: 0,
    });
    await seedBestBallMatch(client, {
      id: MATCH_IDS.satAm2,
      label: "Match 2 · Bolton / Jonas vs Fisher / Mcllenan",
      sortOrder: 12,
      sessionId: sessionByRound[5]!,
      format: "best_ball_match",
      visibility: "live",
      status: "setup",
      pairings: [
        { name: "Jay Bolton", side: "hookers" },
        { name: "Kyle Jonas", side: "hookers" },
        { name: "Mike Fisher", side: "slicers" },
        { name: "Bryan Mcllenan", side: "slicers" },
      ],
      holesPlayed: 0,
      hookersBias: 0,
    });

    // 8) Sat PM singles — last round; skins pot applies here only
    await seedBestBallMatch(client, {
      id: MATCH_IDS.satPm1,
      label: "Singles · T. Schmalz vs D. Schmalz",
      sortOrder: 7,
      sessionId: sessionByRound[6]!,
      format: "singles_match",
      visibility: "live",
      status: "in_progress",
      pairings: [
        { name: "Tyler Schmalz", side: "hookers" },
        { name: "Dylan Schmalz", side: "slicers" },
      ],
      holesPlayed: 12,
      hookersBias: -0.2,
    });
    await seedBestBallMatch(client, {
      id: MATCH_IDS.satPm2,
      label: "Singles · Peek vs Sarier",
      sortOrder: 8,
      sessionId: sessionByRound[6]!,
      format: "singles_match",
      visibility: "live",
      status: "in_progress",
      pairings: [
        { name: "Jonas Peek", side: "hookers" },
        { name: "Erik Sarier", side: "slicers" },
      ],
      holesPlayed: 12,
      hookersBias: 0.1,
    });
    await seedBestBallMatch(client, {
      id: MATCH_IDS.satPm3,
      label: "Singles · Bolton vs Fisher",
      sortOrder: 9,
      sessionId: sessionByRound[6]!,
      format: "singles_match",
      visibility: "live",
      status: "in_progress",
      pairings: [
        { name: "Jay Bolton", side: "hookers" },
        { name: "Mike Fisher", side: "slicers" },
      ],
      holesPlayed: 12,
      hookersBias: -0.15,
    });
    await seedBestBallMatch(client, {
      id: MATCH_IDS.satPm4,
      label: "Singles · Jonas vs Mcllenan",
      sortOrder: 10,
      sessionId: sessionByRound[6]!,
      format: "singles_match",
      visibility: "live",
      status: "in_progress",
      pairings: [
        { name: "Kyle Jonas", side: "hookers" },
        { name: "Bryan Mcllenan", side: "slicers" },
      ],
      holesPlayed: 12,
      hookersBias: 0.25,
    });

    // Skins pot ($200): unique low grosses on Saturday PM singles only.
    await applyWholeFieldSkins(client, {
      matchIds: [
        MATCH_IDS.satPm1,
        MATCH_IDS.satPm2,
        MATCH_IDS.satPm3,
        MATCH_IDS.satPm4,
      ],
      awards: [
        { hole: 1, winner: "Tyler Schmalz", gross: 3 },
        { hole: 2, winner: "Dylan Schmalz", gross: 4 },
        { hole: 3, winner: "Jonas Peek", gross: 2 },
        { hole: 4, winner: "Jay Bolton", gross: 3 },
        { hole: 5, winner: "Erik Sarier", gross: 3 },
        { hole: 6, winner: "Mike Fisher", gross: 4 },
        { hole: 7, winner: "Kyle Jonas", gross: 2 },
        { hole: 8, winner: "Bryan Mcllenan", gross: 3 },
        { hole: 9, winner: "Tyler Schmalz", gross: 3 },
        { hole: 10, winner: "Jonas Peek", gross: 3 },
        { hole: 12, winner: "Jay Bolton", gross: 2 },
        // Leave a few holes tied on purpose so the board shows carry-free gaps.
      ],
    });

    // Pink ball demo on Thu AM Match 1 (best ball foursome).
    // Rotation: Tyler → Jonas → Dylan → Erik; mark hole 4 lost.
    const pinkCarriers = [
      "Tyler Schmalz",
      "Jonas Peek",
      "Dylan Schmalz",
      "Erik Sarier",
    ];
    for (let hole = 1; hole <= 12; hole += 1) {
      const carrier = player(pinkCarriers[(hole - 1) % pinkCarriers.length]!);
      const lost = hole === 4 || hole === 9;
      await client.query(
        `INSERT INTO pink_ball_holes (
           match_id, hole_number, carrier_profile_id, lost, lost_count, updated_by
         ) VALUES ($1, $2, $3, $4, $5, $6)`,
        [MATCH_IDS.thuAm1, hole, carrier.id, lost, lost ? 1 : 0, carrier.id],
      );
    }

    await client.query("COMMIT");

    console.log("\nSeed complete.\n");
    console.log("Sign in with any signed-up account:");
    console.log("  email:    jonas@rydeher.local   (admin, Hookers)");
    console.log("  email:    tyler@rydeher.local   (player)");
    console.log("  email:    dylan@rydeher.local   (Slicers)");
    console.log(`  password: ${PASSWORD}`);
    console.log("\nUnsigned roster (shows “Not signed up yet”):");
    console.log("  Cash Goodheart, Chris Regan");
    console.log("\nSkins pot ($200): seeded on Saturday PM singles.");
    console.log("Pink ball demo: seeded on Thu AM Match 1 (lost holes 4 & 9).");
    console.log(
      "Pink ball start flow: Saturday AM best ball (setup) — start Match 1, then pick first pink-ball player.",
    );
    console.log("\nStart API:  npm run dev");
    console.log("App URL:    http://127.0.0.1:3000");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    await client.end();
  }
}

type Pairing = { name: string; side: TeamSlug };

type MatchSeedOpts = {
  id: string;
  label: string;
  sortOrder: number;
  sessionId: string;
  format: MatchFormat;
  visibility: "live" | "release_on_complete";
  status: "setup" | "in_progress" | "complete";
  pairings: Pairing[];
  holesPlayed: number;
  /** Negative favors Hookers nets; positive favors Slicers. */
  hookersBias: number;
};

async function seedBestBallMatch(
  client: pg.Client,
  opts: MatchSeedOpts,
): Promise<void> {
  const players = opts.pairings.map((p) => {
    const row = player(p.name);
    return { ...row, side: p.side };
  });

  const inputs: PlayerHandicapInput[] = players.map((p) => ({
    profileId: p.id,
    side: p.side,
    courseHandicap: p.courseHandicap,
  }));
  const snapshot = computePlayingHandicaps(opts.format, inputs);

  await insertMatchShell(client, opts, snapshot);

  for (const p of players) {
    await client.query(
      `INSERT INTO match_players (match_id, profile_id, side) VALUES ($1, $2, $3)`,
      [opts.id, p.id, p.side],
    );
  }

  if (opts.holesPlayed === 0) {
    return;
  }

  const holeInputs = [];
  for (let h = 1; h <= opts.holesPlayed; h++) {
    const hole = HOLES[h - 1]!;
    const sideNets: Record<TeamSlug, number[]> = {
      hookers: [],
      slicers: [],
    };

    for (const p of players) {
      const ph = snapshot.players.find((x) => x.profileId === p.id)!;
      const strokes = strokesOnHole(ph.relativeStrokes, hole.si);
      // Roughly bogey golf with a team bias
      const base = hole.par + 1;
      const jitter = ((h + p.courseHandicap) % 3) - 1;
      const bias =
        p.side === "hookers" ? opts.hookersBias : -opts.hookersBias;
      const gross = Math.max(
        1,
        Math.min(15, Math.round(base + jitter + bias)),
      );
      await client.query(
        `INSERT INTO hole_scores (match_id, hole_number, profile_id, gross_strokes, updated_by)
         VALUES ($1, $2, $3, $4, $3)`,
        [opts.id, h, p.id, gross],
      );
      sideNets[p.side].push(netScore(gross, strokes));
    }

    const hookersNet = Math.min(...sideNets.hookers);
    const slicersNet = Math.min(...sideNets.slicers);
    holeInputs.push({
      holeNumber: h,
      strokeIndex: hole.si,
      hookersNet,
      slicersNet,
    });

    let winner: TeamSlug | null = null;
    if (hookersNet < slicersNet) winner = "hookers";
    else if (slicersNet < hookersNet) winner = "slicers";

    await client.query(
      `INSERT INTO match_hole_outcomes (match_id, hole_number, winner_side)
       VALUES ($1, $2, $3)`,
      [opts.id, h, winner],
    );
  }

  const standing = computeMatchPlayResult(holeInputs);
  await client.query(
    `INSERT INTO match_results (
       match_id, hookers_points, slicers_points, is_provisional,
       holes_won_hookers, holes_won_slicers, holes_halved
     ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [
      opts.id,
      standing.hookersPoints,
      standing.slicersPoints,
      standing.isProvisional,
      standing.holesWonHookers,
      standing.holesWonSlicers,
      standing.holesHalved,
    ],
  );

  if (standing.isComplete && opts.status === "complete") {
    await client.query(
      `UPDATE matches SET status = 'complete', updated_at = now() WHERE id = $1`,
      [opts.id],
    );
  }
}

async function seedTeamBallMatch(
  client: pg.Client,
  opts: MatchSeedOpts,
): Promise<void> {
  const players = opts.pairings.map((p) => {
    const row = player(p.name);
    return { ...row, side: p.side };
  });

  const inputs: PlayerHandicapInput[] = players.map((p) => ({
    profileId: p.id,
    side: p.side,
    courseHandicap: p.courseHandicap,
  }));
  const snapshot = computePlayingHandicaps(opts.format, inputs);

  await insertMatchShell(client, opts, snapshot);

  for (const p of players) {
    await client.query(
      `INSERT INTO match_players (match_id, profile_id, side) VALUES ($1, $2, $3)`,
      [opts.id, p.id, p.side],
    );
  }

  const holeInputs = [];
  for (let h = 1; h <= opts.holesPlayed; h++) {
    const hole = HOLES[h - 1]!;
    const nets: Partial<Record<TeamSlug, number>> = {};

    for (const side of ["hookers", "slicers"] as TeamSlug[]) {
      const sideSnap = snapshot.sides.find((s) => s.side === side)!;
      const strokes = strokesOnHole(sideSnap.relativeStrokes, hole.si);
      const bias = side === "hookers" ? opts.hookersBias : -opts.hookersBias;
      const gross = Math.max(
        1,
        Math.min(15, Math.round(hole.par + 1 + ((h % 3) - 1) + bias)),
      );
      await client.query(
        `INSERT INTO hole_scores (match_id, hole_number, side, gross_strokes, updated_by)
         VALUES ($1, $2, $3, $4, $5)`,
        [opts.id, h, side, gross, players[0]!.id],
      );
      nets[side] = netScore(gross, strokes);
    }

    holeInputs.push({
      holeNumber: h,
      strokeIndex: hole.si,
      hookersNet: nets.hookers!,
      slicersNet: nets.slicers!,
    });

    let winner: TeamSlug | null = null;
    if (nets.hookers! < nets.slicers!) winner = "hookers";
    else if (nets.slicers! < nets.hookers!) winner = "slicers";

    await client.query(
      `INSERT INTO match_hole_outcomes (match_id, hole_number, winner_side)
       VALUES ($1, $2, $3)`,
      [opts.id, h, winner],
    );
  }

  const standing = computeMatchPlayResult(holeInputs);
  await client.query(
    `INSERT INTO match_results (
       match_id, hookers_points, slicers_points, is_provisional,
       holes_won_hookers, holes_won_slicers, holes_halved
     ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [
      opts.id,
      standing.hookersPoints,
      standing.slicersPoints,
      standing.isProvisional,
      standing.holesWonHookers,
      standing.holesWonSlicers,
      standing.holesHalved,
    ],
  );
}

async function insertMatchShell(
  client: pg.Client,
  opts: MatchSeedOpts,
  snapshot: unknown,
): Promise<void> {
  await client.query(
    `INSERT INTO matches (
       id, label, sort_order, session_id, format, course_id, tee_id,
       scoring_visibility, status, playing_handicaps
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb)`,
    [
      opts.id,
      opts.label,
      opts.sortOrder,
      opts.sessionId,
      opts.format,
      COURSE_ID,
      TEE_ID,
      opts.visibility,
      opts.status,
      JSON.stringify(snapshot),
    ],
  );
}

/**
 * Force unique low grosses across a set of matches (whole field for a session).
 * Recomputes match-play outcomes afterward so cup points stay consistent.
 */
async function applyWholeFieldSkins(
  client: pg.Client,
  opts: {
    matchIds: string[];
    awards: Array<{ hole: number; winner: string; gross: number }>;
  },
): Promise<void> {
  for (const award of opts.awards) {
    const winner = player(award.winner);
    const scores = await client.query<{
      match_id: string;
      profile_id: string;
      gross_strokes: number;
    }>(
      `SELECT match_id, profile_id, gross_strokes
       FROM hole_scores
       WHERE match_id = ANY($1::uuid[])
         AND hole_number = $2
         AND profile_id IS NOT NULL`,
      [opts.matchIds, award.hole],
    );

    for (const row of scores.rows) {
      const nextGross =
        row.profile_id === winner.id
          ? award.gross
          : Math.max(row.gross_strokes, award.gross + 1);
      if (nextGross === row.gross_strokes) {
        continue;
      }
      await client.query(
        `UPDATE hole_scores
         SET gross_strokes = $1, updated_at = now()
         WHERE match_id = $2 AND hole_number = $3 AND profile_id = $4`,
        [nextGross, row.match_id, award.hole, row.profile_id],
      );
    }
  }

  for (const matchId of opts.matchIds) {
    await recomputeSeededMatch(client, matchId);
  }
}

async function recomputeSeededMatch(
  client: pg.Client,
  matchId: string,
): Promise<void> {
  const matchRes = await client.query<{
    format: MatchFormat;
    playing_handicaps: {
      players: Array<{ profileId: string; relativeStrokes: number }>;
    } | null;
    status: string;
  }>(
    `SELECT format, playing_handicaps, status FROM matches WHERE id = $1`,
    [matchId],
  );
  const match = matchRes.rows[0];
  if (!match?.playing_handicaps) {
    return;
  }

  const playersRes = await client.query<{
    profile_id: string;
    side: TeamSlug;
  }>(`SELECT profile_id, side FROM match_players WHERE match_id = $1`, [
    matchId,
  ]);

  const scoresRes = await client.query<{
    hole_number: number;
    profile_id: string;
    gross_strokes: number;
  }>(
    `SELECT hole_number, profile_id, gross_strokes
     FROM hole_scores
     WHERE match_id = $1 AND profile_id IS NOT NULL
     ORDER BY hole_number`,
    [matchId],
  );

  const byHole = new Map<
    number,
    Array<{ profileId: string; side: TeamSlug; gross: number }>
  >();
  for (const row of scoresRes.rows) {
    const mp = playersRes.rows.find((p) => p.profile_id === row.profile_id);
    if (!mp) continue;
    const list = byHole.get(row.hole_number) ?? [];
    list.push({
      profileId: row.profile_id,
      side: mp.side,
      gross: row.gross_strokes,
    });
    byHole.set(row.hole_number, list);
  }

  await client.query(
    `DELETE FROM match_hole_outcomes WHERE match_id = $1`,
    [matchId],
  );
  await client.query(`DELETE FROM match_results WHERE match_id = $1`, [
    matchId,
  ]);

  const holeInputs = [];
  for (const [holeNumber, scores] of [...byHole.entries()].sort(
    (a, b) => a[0] - b[0],
  )) {
    const hole = HOLES[holeNumber - 1]!;
    const sideNets: Record<TeamSlug, number[]> = {
      hookers: [],
      slicers: [],
    };

    for (const score of scores) {
      const ph = match.playing_handicaps.players.find(
        (p) => p.profileId === score.profileId,
      );
      const strokes = strokesOnHole(ph?.relativeStrokes ?? 0, hole.si);
      sideNets[score.side].push(netScore(score.gross, strokes));
    }

    const hookersNet =
      sideNets.hookers.length > 0
        ? Math.min(...sideNets.hookers)
        : Number.POSITIVE_INFINITY;
    const slicersNet =
      sideNets.slicers.length > 0
        ? Math.min(...sideNets.slicers)
        : Number.POSITIVE_INFINITY;

    holeInputs.push({
      holeNumber,
      strokeIndex: hole.si,
      hookersNet,
      slicersNet,
    });

    let winner: TeamSlug | null = null;
    if (hookersNet < slicersNet) winner = "hookers";
    else if (slicersNet < hookersNet) winner = "slicers";

    await client.query(
      `INSERT INTO match_hole_outcomes (match_id, hole_number, winner_side)
       VALUES ($1, $2, $3)`,
      [matchId, holeNumber, winner],
    );
  }

  const standing = computeMatchPlayResult(holeInputs);
  await client.query(
    `INSERT INTO match_results (
       match_id, hookers_points, slicers_points, is_provisional,
       holes_won_hookers, holes_won_slicers, holes_halved
     ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [
      matchId,
      standing.hookersPoints,
      standing.slicersPoints,
      standing.isProvisional,
      standing.holesWonHookers,
      standing.holesWonSlicers,
      standing.holesHalved,
    ],
  );

  if (standing.isComplete && match.status === "complete") {
    await client.query(
      `UPDATE matches SET status = 'complete', updated_at = now() WHERE id = $1`,
      [matchId],
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

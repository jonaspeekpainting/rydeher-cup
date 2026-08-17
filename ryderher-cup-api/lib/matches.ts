import {
  sql,
  type CourseHoleRow,
  type HoleScoreRow,
  type MatchFormat,
  type MatchRow,
  type MatchStatus,
  type ProfileRow,
  type ScoringVisibility,
  type TeamSlug,
} from "./db";
import {
  computeMatchPlayResult,
  computePlayingHandicaps,
  resolveMatchCourseHandicap,
  isMatchPlayFormat,
  isTeamBallFormat,
  netScore,
  strokesOnHole,
  type PlayingHandicapSnapshot,
  type PlayerHandicapInput,
} from "./handicaps";
import { profileResponse } from "./profile";
import {
  computePinkBallScore,
  PINK_BALLS_PER_MATCH,
  type PinkBallScoreSummary,
} from "./pink-ball";

type Snap = PlayingHandicapSnapshot;

export type MatchPlayerView = {
  id: string;
  profile_id: string;
  side: TeamSlug | null;
  profile: ReturnType<typeof profileResponse>;
};

export type HoleScoreView = {
  hole_number: number;
  profile_id: string | null;
  side: TeamSlug | null;
  gross_strokes: number;
  updated_at: string;
};

export type MatchHoleOutcomeView = {
  hole_number: number;
  winner_side: TeamSlug | null;
};

export type MatchResultView = {
  hookers_points: number;
  slicers_points: number;
  is_provisional: boolean;
  holes_won_hookers: number;
  holes_won_slicers: number;
  holes_halved: number;
};

export type MatchCourseHoleView = {
  hole_number: number;
  par: number;
  stroke_index: number | null;
  yardage: number | null;
};

export type MatchCourseView = {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  tee: {
    id: string;
    name: string;
    color: string | null;
    rating: number | null;
    slope: number | null;
  } | null;
  holes: MatchCourseHoleView[];
};

export { PINK_BALLS_PER_MATCH };

export function supportsPinkBall(format: MatchFormat | null | undefined): boolean {
  return format === "best_ball_match";
}

export type PinkBallHoleView = {
  hole_number: number;
  carrier_profile_id: string;
  lost: boolean;
};

export type MatchDetail = {
  id: string;
  label: string;
  sort_order: number;
  created_at: string;
  session_id: string | null;
  format: MatchFormat | null;
  course_id: string | null;
  tee_id: string | null;
  scoring_visibility: ScoringVisibility;
  status: MatchStatus;
  playing_handicaps: Snap | null;
  updated_at: string;
  players: MatchPlayerView[];
  hole_scores: HoleScoreView[] | null;
  hole_outcomes: MatchHoleOutcomeView[] | null;
  result: MatchResultView | null;
  course: MatchCourseView | null;
  can_score: boolean;
  scores_visible: boolean;
  pink_ball_holes: PinkBallHoleView[] | null;
  pink_balls_remaining: number | null;
  pink_balls_lost: number | null;
  pink_ball_score: PinkBallScoreSummary | null;
};

function parseSnapshot(raw: unknown): Snap | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  return raw as Snap;
}

export function scoresVisibleToViewer(options: {
  scoringVisibility: ScoringVisibility;
  status: MatchStatus;
  isParticipant: boolean;
  isAdmin: boolean;
}): boolean {
  if (options.isParticipant || options.isAdmin) {
    return true;
  }
  if (options.status === "complete") {
    return true;
  }
  return options.scoringVisibility === "live";
}

export function pointsCountTowardStandings(options: {
  scoringVisibility: ScoringVisibility;
  status: MatchStatus;
}): boolean {
  if (options.status === "complete") {
    return true;
  }
  return options.scoringVisibility === "live";
}

export async function fetchMatchDetail(
  matchId: string,
  viewer: { sub: string; isAdmin: boolean },
): Promise<MatchDetail | null> {
  const matchResult = await sql<MatchRow>`
    SELECT
      id, label, sort_order, created_at, session_id, format,
      course_id, tee_id, scoring_visibility, status,
      playing_handicaps, updated_at
    FROM matches
    WHERE id = ${matchId}
    LIMIT 1
  `;
  const match = matchResult.rows[0];
  if (!match) {
    return null;
  }

  const players = await fetchMatchPlayers(matchId);
  const isParticipant = players.some(
    (p) => p.profile_id.toLowerCase() === viewer.sub.toLowerCase(),
  );
  const visible = scoresVisibleToViewer({
    scoringVisibility: match.scoring_visibility,
    status: match.status,
    isParticipant,
    isAdmin: viewer.isAdmin,
  });

  let holeScores: HoleScoreView[] | null = null;
  let holeOutcomes: MatchHoleOutcomeView[] | null = null;
  let result: MatchResultView | null = null;
  let pinkBallHoles: PinkBallHoleView[] | null = null;
  let pinkBallsLost: number | null = null;
  let pinkBallsRemaining: number | null = null;
  let pinkBallScore: PinkBallScoreSummary | null = null;

  if (visible) {
    const scores = await sql<HoleScoreRow>`
      SELECT id, match_id, hole_number, profile_id, side, gross_strokes, updated_by, updated_at
      FROM hole_scores
      WHERE match_id = ${matchId}
      ORDER BY hole_number ASC
    `;
    holeScores = scores.rows.map((s) => ({
      hole_number: s.hole_number,
      profile_id: s.profile_id,
      side: s.side,
      gross_strokes: s.gross_strokes,
      updated_at: s.updated_at,
    }));

    const outcomes = await sql<{
      hole_number: number;
      winner_side: TeamSlug | null;
    }>`
      SELECT hole_number, winner_side
      FROM match_hole_outcomes
      WHERE match_id = ${matchId}
      ORDER BY hole_number ASC
    `;
    holeOutcomes = outcomes.rows;

    const resultRow = await sql<{
      hookers_points: string;
      slicers_points: string;
      is_provisional: boolean;
      holes_won_hookers: number;
      holes_won_slicers: number;
      holes_halved: number;
    }>`
      SELECT hookers_points, slicers_points, is_provisional,
             holes_won_hookers, holes_won_slicers, holes_halved
      FROM match_results
      WHERE match_id = ${matchId}
      LIMIT 1
    `;
    if (resultRow.rows[0]) {
      const r = resultRow.rows[0];
      result = {
        hookers_points: Number(r.hookers_points),
        slicers_points: Number(r.slicers_points),
        is_provisional: r.is_provisional,
        holes_won_hookers: r.holes_won_hookers,
        holes_won_slicers: r.holes_won_slicers,
        holes_halved: r.holes_halved,
      };
    }

    if (supportsPinkBall(match.format)) {
      const pinkRows = await sql<{
        hole_number: number;
        carrier_profile_id: string;
        lost: boolean;
      }>`
        SELECT hole_number, carrier_profile_id, lost
        FROM pink_ball_holes
        WHERE match_id = ${matchId}
        ORDER BY hole_number ASC
      `;
      pinkBallHoles = pinkRows.rows.map((row) => ({
        hole_number: row.hole_number,
        carrier_profile_id: row.carrier_profile_id,
        lost: row.lost,
      }));
      pinkBallsLost = pinkBallHoles.filter((h) => h.lost).length;
      pinkBallsRemaining = Math.max(0, PINK_BALLS_PER_MATCH - pinkBallsLost);
    }
  }

  const course = await loadMatchCourse(match.course_id, match.tee_id);

  if (visible && supportsPinkBall(match.format) && pinkBallHoles) {
    const snap = parseSnapshot(match.playing_handicaps);
    pinkBallScore = computePinkBallScore({
      pinkHoles: pinkBallHoles.map((h) => ({
        holeNumber: h.hole_number,
        carrierProfileId: h.carrier_profile_id,
        lost: h.lost,
      })),
      scores: (holeScores ?? [])
        .filter((s) => s.profile_id != null)
        .map((s) => ({
          holeNumber: s.hole_number,
          profileId: s.profile_id!,
          grossStrokes: s.gross_strokes,
        })),
      strokeIndexes: (course?.holes ?? []).map((h) => ({
        holeNumber: h.hole_number,
        strokeIndex: h.stroke_index ?? h.hole_number,
      })),
      players: (snap?.players ?? []).map((p) => ({
        profileId: p.profileId,
        relativeStrokes: p.relativeStrokes,
      })),
    });
    pinkBallsLost = pinkBallScore.balls_lost;
    pinkBallsRemaining = pinkBallScore.balls_remaining;
  }

  return {
    id: match.id,
    label: match.label,
    sort_order: match.sort_order,
    created_at: match.created_at,
    session_id: match.session_id,
    format: match.format,
    course_id: match.course_id,
    tee_id: match.tee_id,
    scoring_visibility: match.scoring_visibility,
    status: match.status,
    playing_handicaps: parseSnapshot(match.playing_handicaps),
    updated_at: match.updated_at,
    players,
    hole_scores: holeScores,
    hole_outcomes: holeOutcomes,
    result,
    course,
    can_score: (isParticipant || viewer.isAdmin) && match.status !== "complete",
    scores_visible: visible,
    pink_ball_holes: pinkBallHoles,
    pink_balls_remaining: pinkBallsRemaining,
    pink_balls_lost: pinkBallsLost,
    pink_ball_score: pinkBallScore,
  };
}

async function fetchMatchPlayers(matchId: string): Promise<MatchPlayerView[]> {
  const rows = await sql<
    ProfileRow & {
      mp_id: string;
      side: TeamSlug | null;
      team_slug: TeamSlug | null;
    }
  >`
    SELECT
      mp.id AS mp_id,
      mp.side,
      p.id, p.email, p.display_name, p.is_admin, p.created_at,
      p.ghin_number, p.handicap_index, p.course_handicap,
      p.handicap_source, p.handicap_updated_at, p.team_id,
      t.slug AS team_slug
    FROM match_players mp
    JOIN profiles p ON p.id = mp.profile_id
    LEFT JOIN teams t ON t.id = p.team_id
    WHERE mp.match_id = ${matchId}
    ORDER BY mp.created_at ASC
  `;

  return rows.rows.map((row) => ({
    id: row.mp_id,
    profile_id: row.id,
    side: row.side,
    profile: profileResponse(row),
  }));
}

export async function listMatchesSummary(viewer: {
  sub: string;
  isAdmin: boolean;
}) {
  const matches = await sql<MatchRow>`
    SELECT
      id, label, sort_order, created_at, session_id, format,
      course_id, tee_id, scoring_visibility, status,
      playing_handicaps, updated_at
    FROM matches
    ORDER BY sort_order ASC, created_at ASC
  `;

  const out = [];
  for (const match of matches.rows) {
    const detail = await fetchMatchDetail(match.id, viewer);
    if (detail) {
      out.push(detail);
    }
  }
  return out;
}

export async function buildPlayingHandicapSnapshot(
  matchId: string,
  format: MatchFormat,
): Promise<Snap> {
  const matchMeta = await sql<{
    course_id: string | null;
    tee_id: string | null;
  }>`
    SELECT course_id, tee_id FROM matches WHERE id = ${matchId} LIMIT 1
  `;
  const courseId = matchMeta.rows[0]?.course_id ?? null;
  const teeId = matchMeta.rows[0]?.tee_id ?? null;

  let slope: number | null = null;
  let rating: number | null = null;
  let coursePar: number | null = null;

  if (teeId) {
    const teeResult = await sql<{
      rating: string | null;
      slope: number | null;
    }>`
      SELECT rating, slope FROM course_tees WHERE id = ${teeId} LIMIT 1
    `;
    const tee = teeResult.rows[0];
    if (tee) {
      slope = tee.slope;
      rating = tee.rating != null ? Number(tee.rating) : null;
    }
  }

  if (courseId) {
    // Prefer holes for the selected tee; fall back to course-level holes.
    if (teeId) {
      const teePar = await sql<{ total_par: string | null }>`
        SELECT COALESCE(SUM(par), 0)::int AS total_par
        FROM course_holes
        WHERE course_id = ${courseId} AND tee_id = ${teeId}
      `;
      const total = Number(teePar.rows[0]?.total_par ?? 0);
      if (total > 0) {
        coursePar = total;
      }
    }
    if (coursePar == null) {
      const courseLevelPar = await sql<{ total_par: string | null }>`
        SELECT COALESCE(SUM(par), 0)::int AS total_par
        FROM course_holes
        WHERE course_id = ${courseId} AND tee_id IS NULL
      `;
      const total = Number(courseLevelPar.rows[0]?.total_par ?? 0);
      coursePar = total > 0 ? total : null;
    }
  }

  const players = await sql<{
    profile_id: string;
    side: TeamSlug;
    course_handicap: number | null;
    handicap_index: string | null;
  }>`
    SELECT mp.profile_id, mp.side, p.course_handicap, p.handicap_index
    FROM match_players mp
    JOIN profiles p ON p.id = mp.profile_id
    WHERE mp.match_id = ${matchId}
      AND mp.side IS NOT NULL
  `;

  const inputs: PlayerHandicapInput[] = players.rows.map((p) => {
    const index =
      p.handicap_index != null && Number.isFinite(Number(p.handicap_index))
        ? Number(p.handicap_index)
        : null;

    return {
      profileId: p.profile_id,
      side: p.side,
      courseHandicap: resolveMatchCourseHandicap({
        handicapIndex: index,
        profileCourseHandicap: p.course_handicap,
        slope,
        rating,
        coursePar,
      }),
    };
  });

  return computePlayingHandicaps(format, inputs);
}

export async function recomputeMatchResult(matchId: string): Promise<void> {
  const matchResult = await sql<MatchRow>`
    SELECT * FROM matches WHERE id = ${matchId} LIMIT 1
  `;
  const match = matchResult.rows[0];
  if (!match?.format) {
    return;
  }

  const format = match.format;
  const snapshot = parseSnapshot(match.playing_handicaps);
  if (!snapshot) {
    return;
  }

  const holes = await loadCourseHoles(match.course_id, match.tee_id);
  const scores = await sql<HoleScoreRow>`
    SELECT * FROM hole_scores WHERE match_id = ${matchId}
  `;

  if (isMatchPlayFormat(format) || format === "shamble") {
    await recomputeMatchPlayLike(match, snapshot, holes, scores.rows, format);
  } else if (isTeamBallFormat(format)) {
    // Scramble / alternate shot — also match play hole-by-hole on team nets
    await recomputeMatchPlayLike(match, snapshot, holes, scores.rows, format);
  }
}

async function loadMatchCourse(
  courseId: string | null,
  teeId: string | null,
): Promise<MatchCourseView | null> {
  if (!courseId) {
    return null;
  }

  const courseResult = await sql<{
    id: string;
    name: string;
    city: string | null;
    state: string | null;
  }>`
    SELECT id, name, city, state FROM courses WHERE id = ${courseId} LIMIT 1
  `;
  const course = courseResult.rows[0];
  if (!course) {
    return null;
  }

  let tee: MatchCourseView["tee"] = null;
  if (teeId) {
    const teeResult = await sql<{
      id: string;
      name: string;
      color: string | null;
      rating: string | null;
      slope: number | null;
    }>`
      SELECT id, name, color, rating, slope
      FROM course_tees WHERE id = ${teeId} LIMIT 1
    `;
    if (teeResult.rows[0]) {
      const t = teeResult.rows[0];
      tee = {
        id: t.id,
        name: t.name,
        color: t.color,
        rating: t.rating != null ? Number(t.rating) : null,
        slope: t.slope,
      };
    }
  }

  const holes = await loadCourseHoles(courseId, teeId);

  return {
    id: course.id,
    name: course.name,
    city: course.city,
    state: course.state,
    tee,
    holes: holes.map((h) => ({
      hole_number: h.hole_number,
      par: h.par,
      stroke_index: h.stroke_index,
      yardage: h.yardage,
    })),
  };
}

async function loadCourseHoles(
  courseId: string | null,
  teeId: string | null,
): Promise<CourseHoleRow[]> {
  if (!courseId) {
    // Default stroke indexes 1..18 if no course
    return Array.from({ length: 18 }, (_, i) => ({
      id: `default-${i + 1}`,
      course_id: "",
      tee_id: null,
      hole_number: i + 1,
      par: 4,
      stroke_index: i + 1,
      yardage: null,
    }));
  }

  if (teeId) {
    const result = await sql<CourseHoleRow>`
      SELECT * FROM course_holes
      WHERE course_id = ${courseId} AND tee_id = ${teeId}
      ORDER BY hole_number ASC
    `;
    if (result.rows.length > 0) {
      return result.rows;
    }
  }

  const fallback = await sql<CourseHoleRow>`
    SELECT * FROM course_holes
    WHERE course_id = ${courseId} AND tee_id IS NULL
    ORDER BY hole_number ASC
  `;
  if (fallback.rows.length > 0) {
    return fallback.rows;
  }

  return Array.from({ length: 18 }, (_, i) => ({
    id: `default-${i + 1}`,
    course_id: courseId,
    tee_id: null,
    hole_number: i + 1,
    par: 4,
    stroke_index: i + 1,
    yardage: null,
  }));
}

function sideNetForHole(
  format: MatchFormat,
  snapshot: Snap,
  side: TeamSlug,
  holeNumber: number,
  strokeIndex: number,
  scores: HoleScoreRow[],
): number | null {
  const sideSnap = snapshot.sides.find((s) => s.side === side);
  const relative = sideSnap?.relativeStrokes ?? 0;

  if (format === "best_ball_match" || format === "shamble") {
    const sidePlayers = snapshot.players.filter((p) => p.side === side);
    const nets: number[] = [];
    for (const player of sidePlayers) {
      const score = scores.find(
        (s) =>
          s.hole_number === holeNumber && s.profile_id === player.profileId,
      );
      if (!score) {
        continue;
      }
      const strokes = strokesOnHole(player.relativeStrokes, strokeIndex);
      nets.push(netScore(score.gross_strokes, strokes));
    }
    if (nets.length === 0) {
      return null;
    }
    return Math.min(...nets);
  }

  if (format === "singles_match") {
    const player = snapshot.players.find((p) => p.side === side);
    if (!player) {
      return null;
    }
    const score = scores.find(
      (s) => s.hole_number === holeNumber && s.profile_id === player.profileId,
    );
    if (!score) {
      return null;
    }
    const strokes = strokesOnHole(player.relativeStrokes, strokeIndex);
    return netScore(score.gross_strokes, strokes);
  }

  // scramble / alternate_shot — team ball
  const score = scores.find(
    (s) => s.hole_number === holeNumber && s.side === side,
  );
  if (!score) {
    return null;
  }
  const strokes = strokesOnHole(relative, strokeIndex);
  return netScore(score.gross_strokes, strokes);
}

async function recomputeMatchPlayLike(
  match: MatchRow,
  snapshot: Snap,
  holes: CourseHoleRow[],
  scores: HoleScoreRow[],
  format: MatchFormat,
): Promise<void> {
  const holeInputs = holes.map((h) => {
    const si = h.stroke_index ?? h.hole_number;
    return {
      holeNumber: h.hole_number,
      strokeIndex: si,
      hookersNet: sideNetForHole(
        format,
        snapshot,
        "hookers",
        h.hole_number,
        si,
        scores,
      ),
      slicersNet: sideNetForHole(
        format,
        snapshot,
        "slicers",
        h.hole_number,
        si,
        scores,
      ),
    };
  });

  // Persist hole outcomes
  for (const hole of holeInputs) {
    if (hole.hookersNet == null || hole.slicersNet == null) {
      continue;
    }
    let winner: TeamSlug | null = null;
    if (hole.hookersNet < hole.slicersNet) {
      winner = "hookers";
    } else if (hole.slicersNet < hole.hookersNet) {
      winner = "slicers";
    }

    await sql`
      INSERT INTO match_hole_outcomes (match_id, hole_number, winner_side)
      VALUES (${match.id}, ${hole.holeNumber}, ${winner})
      ON CONFLICT (match_id, hole_number)
      DO UPDATE SET winner_side = EXCLUDED.winner_side
    `;
  }

  const standing = computeMatchPlayResult(holeInputs);

  if (standing.holesPlayed === 0) {
    await sql`DELETE FROM match_results WHERE match_id = ${match.id}`;
    return;
  }

  const countPoints = pointsCountTowardStandings({
    scoringVisibility: match.scoring_visibility,
    status: standing.isComplete ? "complete" : match.status,
  });

  // Always store result for participants; standings API filters by visibility
  await sql`
    INSERT INTO match_results (
      match_id, hookers_points, slicers_points, is_provisional,
      holes_won_hookers, holes_won_slicers, holes_halved, updated_at
    )
    VALUES (
      ${match.id},
      ${standing.hookersPoints},
      ${standing.slicersPoints},
      ${standing.isProvisional},
      ${standing.holesWonHookers},
      ${standing.holesWonSlicers},
      ${standing.holesHalved},
      now()
    )
    ON CONFLICT (match_id) DO UPDATE SET
      hookers_points = EXCLUDED.hookers_points,
      slicers_points = EXCLUDED.slicers_points,
      is_provisional = EXCLUDED.is_provisional,
      holes_won_hookers = EXCLUDED.holes_won_hookers,
      holes_won_slicers = EXCLUDED.holes_won_slicers,
      holes_halved = EXCLUDED.holes_halved,
      updated_at = now()
  `;

  if (standing.isComplete && match.status !== "complete") {
    await sql`
      UPDATE matches
      SET status = 'complete', updated_at = now()
      WHERE id = ${match.id}
    `;
  } else if (
    standing.holesPlayed > 0 &&
    match.status === "setup" &&
    countPoints
  ) {
    await sql`
      UPDATE matches
      SET status = 'in_progress', updated_at = now()
      WHERE id = ${match.id}
    `;
  }
}

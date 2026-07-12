/**
 * Ryde-Her Cup handicap engine.
 *
 * Rules:
 * - 80% allowance on course handicaps
 * - Best ball / singles: per-player CH × 0.80
 * - Scramble / shamble / alternate shot: 0.80 × (0.35×low + 0.15×high)
 * - Round half-up (.5 and above up)
 * - Everyone strokes off the best (lowest) playing handicap in the field
 */

export type MatchFormat =
  | "best_ball_match"
  | "scramble"
  | "shamble"
  | "singles_match"
  | "alternate_shot";

export type TeamSlug = "hookers" | "slicers";

export type PlayerHandicapInput = {
  profileId: string;
  side: TeamSlug;
  /** Course handicap (already from slope/rating or admin-entered). */
  courseHandicap: number;
};

export type PlayerPlayingHandicap = {
  profileId: string;
  side: TeamSlug;
  courseHandicap: number;
  allowanceStrokes: number;
  relativeStrokes: number;
};

export type SidePlayingHandicap = {
  side: TeamSlug;
  courseHandicaps: number[];
  allowanceStrokes: number;
  relativeStrokes: number;
  profileIds: string[];
};

export type PlayingHandicapSnapshot = {
  format: MatchFormat;
  fieldMinimum: number;
  players: PlayerPlayingHandicap[];
  sides: SidePlayingHandicap[];
};

/** Round half-up for positive numbers (5.2→5, 5.5→6). */
export function roundHalfUp(value: number): number {
  return Math.floor(value + 0.5);
}

export function applyEightyPercent(courseHandicap: number): number {
  return roundHalfUp(courseHandicap * 0.8);
}

/**
 * Standard two-man scramble formula with 80% allowance.
 * (0.35 × lowCH + 0.15 × highCH) × 0.80, then round half-up.
 */
export function scrambleTeamAllowance(
  courseHandicapA: number,
  courseHandicapB: number,
): number {
  const low = Math.min(courseHandicapA, courseHandicapB);
  const high = Math.max(courseHandicapA, courseHandicapB);
  const standard = low * 0.35 + high * 0.15;
  return roundHalfUp(standard * 0.8);
}

export function isTeamBallFormat(format: MatchFormat): boolean {
  return (
    format === "scramble" ||
    format === "shamble" ||
    format === "alternate_shot"
  );
}

export function isMatchPlayFormat(format: MatchFormat): boolean {
  return format === "best_ball_match" || format === "singles_match";
}

/**
 * Net strokes a player (or team) receives on a hole given relative strokes
 * and the hole's stroke index (1 = hardest).
 */
export function strokesOnHole(
  relativeStrokes: number,
  strokeIndex: number,
): number {
  if (relativeStrokes <= 0) {
    return 0;
  }
  if (strokeIndex < 1 || strokeIndex > 18) {
    return 0;
  }
  // Full cycles of 18 + remainder on hardest holes
  const full = Math.floor(relativeStrokes / 18);
  const rem = relativeStrokes % 18;
  return full + (strokeIndex <= rem ? 1 : 0);
}

export function netScore(gross: number, strokesReceived: number): number {
  return gross - strokesReceived;
}

export function computePlayingHandicaps(
  format: MatchFormat,
  players: PlayerHandicapInput[],
): PlayingHandicapSnapshot {
  if (isTeamBallFormat(format) && format !== "shamble") {
    return computeTeamBallSnapshot(format, players);
  }

  if (format === "shamble") {
    // Shamble uses scramble team allowance for the side, but scores per player.
    // Snapshot includes both side allowance and per-player 80% for net best-ball after drive.
    // Per plan: "same as scramble scoring/handicap" for the team formula.
    return computeTeamBallSnapshot(format, players);
  }

  // Per-player formats: best_ball_match, singles_match
  const withAllowance: PlayerPlayingHandicap[] = players.map((p) => ({
    profileId: p.profileId,
    side: p.side,
    courseHandicap: p.courseHandicap,
    allowanceStrokes: applyEightyPercent(p.courseHandicap),
    relativeStrokes: 0,
  }));

  const fieldMinimum =
    withAllowance.length === 0
      ? 0
      : Math.min(...withAllowance.map((p) => p.allowanceStrokes));

  const relativePlayers = withAllowance.map((p) => ({
    ...p,
    relativeStrokes: Math.max(0, p.allowanceStrokes - fieldMinimum),
  }));

  const sides = groupSides(relativePlayers);

  return {
    format,
    fieldMinimum,
    players: relativePlayers,
    sides,
  };
}

function computeTeamBallSnapshot(
  format: MatchFormat,
  players: PlayerHandicapInput[],
): PlayingHandicapSnapshot {
  const bySide = new Map<TeamSlug, PlayerHandicapInput[]>();
  for (const p of players) {
    const list = bySide.get(p.side) ?? [];
    list.push(p);
    bySide.set(p.side, list);
  }

  const sideAllowances: SidePlayingHandicap[] = [];
  for (const side of ["hookers", "slicers"] as TeamSlug[]) {
    const list = bySide.get(side) ?? [];
    if (list.length === 0) {
      continue;
    }
    const chs = list.map((p) => p.courseHandicap);
    let allowance: number;
    if (list.length === 1) {
      allowance = applyEightyPercent(chs[0]!);
    } else {
      allowance = scrambleTeamAllowance(chs[0]!, chs[1]!);
    }
    sideAllowances.push({
      side,
      courseHandicaps: chs,
      allowanceStrokes: allowance,
      relativeStrokes: 0,
      profileIds: list.map((p) => p.profileId),
    });
  }

  const fieldMinimum =
    sideAllowances.length === 0
      ? 0
      : Math.min(...sideAllowances.map((s) => s.allowanceStrokes));

  const relativeSides = sideAllowances.map((s) => ({
    ...s,
    relativeStrokes: Math.max(0, s.allowanceStrokes - fieldMinimum),
  }));

  // Mirror onto players for convenience (each partner shares side relative strokes)
  const playersOut: PlayerPlayingHandicap[] = players.map((p) => {
    const side = relativeSides.find((s) => s.side === p.side);
    return {
      profileId: p.profileId,
      side: p.side,
      courseHandicap: p.courseHandicap,
      allowanceStrokes: side?.allowanceStrokes ?? 0,
      relativeStrokes: side?.relativeStrokes ?? 0,
    };
  });

  return {
    format,
    fieldMinimum,
    players: playersOut,
    sides: relativeSides,
  };
}

function groupSides(players: PlayerPlayingHandicap[]): SidePlayingHandicap[] {
  const map = new Map<TeamSlug, PlayerPlayingHandicap[]>();
  for (const p of players) {
    const list = map.get(p.side) ?? [];
    list.push(p);
    map.set(p.side, list);
  }

  return (["hookers", "slicers"] as TeamSlug[])
    .map((side) => {
      const list = map.get(side) ?? [];
      if (list.length === 0) {
        return null;
      }
      return {
        side,
        courseHandicaps: list.map((p) => p.courseHandicap),
        allowanceStrokes: list.reduce((sum, p) => sum + p.allowanceStrokes, 0),
        relativeStrokes: list.reduce((sum, p) => sum + p.relativeStrokes, 0),
        profileIds: list.map((p) => p.profileId),
      } satisfies SidePlayingHandicap;
    })
    .filter((s): s is SidePlayingHandicap => s != null);
}

/**
 * Course handicap from Handicap Index using USGA formula:
 * CH = Index × (Slope / 113) + (Rating − Par), rounded half-up.
 * If rating/par missing, use Index × Slope/113 only.
 */
export function courseHandicapFromIndex(
  handicapIndex: number,
  slope: number,
  courseRating?: number | null,
  par?: number | null,
): number {
  let raw = handicapIndex * (slope / 113);
  if (
    courseRating != null &&
    par != null &&
    Number.isFinite(courseRating) &&
    Number.isFinite(par)
  ) {
    raw += courseRating - par;
  }
  return roundHalfUp(raw);
}

export type HoleResultInput = {
  holeNumber: number;
  strokeIndex: number;
  /** Net team score for hookers (already computed). */
  hookersNet: number | null;
  slicersNet: number | null;
};

export type MatchPlayStanding = {
  holesWonHookers: number;
  holesWonSlicers: number;
  holesHalved: number;
  holesPlayed: number;
  /** Positive = hookers up, negative = slicers up. */
  holesUp: number;
  hookersPoints: 0 | 0.5 | 1;
  slicersPoints: 0 | 0.5 | 1;
  isComplete: boolean;
  isProvisional: boolean;
};

/**
 * Derive match-play points from hole-by-hole net scores.
 * Completes early when one side is dormie / won (cannot be caught).
 */
export function computeMatchPlayResult(
  holes: HoleResultInput[],
  totalHoles = 18,
): MatchPlayStanding {
  let holesWonHookers = 0;
  let holesWonSlicers = 0;
  let holesHalved = 0;
  let holesPlayed = 0;

  const sorted = [...holes].sort((a, b) => a.holeNumber - b.holeNumber);

  for (const hole of sorted) {
    if (hole.hookersNet == null || hole.slicersNet == null) {
      continue;
    }
    holesPlayed += 1;
    if (hole.hookersNet < hole.slicersNet) {
      holesWonHookers += 1;
    } else if (hole.slicersNet < hole.hookersNet) {
      holesWonSlicers += 1;
    } else {
      holesHalved += 1;
    }
  }

  const holesUp = holesWonHookers - holesWonSlicers;
  const remaining = totalHoles - holesPlayed;
  const decided =
    holesPlayed === totalHoles || Math.abs(holesUp) > remaining;

  let hookersPoints: 0 | 0.5 | 1 = 0.5;
  let slicersPoints: 0 | 0.5 | 1 = 0.5;

  if (decided) {
    if (holesUp > 0) {
      hookersPoints = 1;
      slicersPoints = 0;
    } else if (holesUp < 0) {
      hookersPoints = 0;
      slicersPoints = 1;
    } else {
      hookersPoints = 0.5;
      slicersPoints = 0.5;
    }
  } else if (holesPlayed > 0) {
    // Provisional lean for live scoreboard (not awarded until decided unless live)
    if (holesUp > 0) {
      hookersPoints = 1;
      slicersPoints = 0;
    } else if (holesUp < 0) {
      hookersPoints = 0;
      slicersPoints = 1;
    }
  }

  return {
    holesWonHookers,
    holesWonSlicers,
    holesHalved,
    holesPlayed,
    holesUp,
    hookersPoints,
    slicersPoints,
    isComplete: decided,
    isProvisional: !decided,
  };
}

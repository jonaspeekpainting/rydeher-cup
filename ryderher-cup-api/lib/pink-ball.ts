/**
 * Pink ball side game scoring (best-ball foursomes).
 * Hole score = net of the player carrying the pink ball.
 * After 3 lost balls the group is eliminated; later holes don't count.
 */

import { netScore, strokesOnHole } from "./handicaps";

export const PINK_BALLS_PER_MATCH = 3;

/** First N holes (group size) set the rotation; later holes follow it. */
export function pinkBallRotationLength(playerCount: number): number {
  return Math.max(0, playerCount);
}

/**
 * Ordered carrier ids from holes 1..playerCount.
 * Returns null until every rotation hole has a unique carrier.
 */
export function pinkBallRotationOrder(opts: {
  playerCount: number;
  pinkHoles: Array<{ holeNumber: number; carrierProfileId: string }>;
}): string[] | null {
  const n = pinkBallRotationLength(opts.playerCount);
  if (n === 0) {
    return null;
  }
  const byHole = new Map(
    opts.pinkHoles.map((h) => [
      h.holeNumber,
      h.carrierProfileId.toLowerCase(),
    ]),
  );
  const order: string[] = [];
  const seen = new Set<string>();
  for (let hole = 1; hole <= n; hole += 1) {
    const carrier = byHole.get(hole);
    if (!carrier || seen.has(carrier)) {
      return null;
    }
    seen.add(carrier);
    order.push(carrier);
  }
  return order;
}

/** Who must carry on this hole once the opening rotation is set. */
export function assignedPinkBallCarrier(opts: {
  holeNumber: number;
  playerCount: number;
  pinkHoles: Array<{ holeNumber: number; carrierProfileId: string }>;
}): string | null {
  const n = pinkBallRotationLength(opts.playerCount);
  if (n === 0 || opts.holeNumber < 1) {
    return null;
  }
  if (opts.holeNumber <= n) {
    const existing = opts.pinkHoles.find(
      (h) => h.holeNumber === opts.holeNumber,
    );
    return existing?.carrierProfileId.toLowerCase() ?? null;
  }
  const rotation = pinkBallRotationOrder(opts);
  if (!rotation) {
    return null;
  }
  return rotation[(opts.holeNumber - 1) % n] ?? null;
}

/**
 * Validate a proposed carrier for a hole.
 * Holes 1..N: unique among the opening rotation holes.
 * Holes N+1..18: must match the established rotation.
 */
export function validatePinkBallCarrier(opts: {
  holeNumber: number;
  carrierProfileId: string;
  playerIds: string[];
  pinkHoles: Array<{ holeNumber: number; carrierProfileId: string }>;
}): { ok: true } | { ok: false; error: string } {
  const carrier = opts.carrierProfileId.toLowerCase();
  const players = opts.playerIds.map((id) => id.toLowerCase());
  if (!players.includes(carrier)) {
    return { ok: false, error: "Pink ball carrier must be in this match" };
  }

  const n = pinkBallRotationLength(players.length);
  if (n === 0) {
    return { ok: false, error: "Match has no players for pink ball" };
  }

  if (opts.holeNumber <= n) {
    const usedElsewhere = opts.pinkHoles
      .filter(
        (h) =>
          h.holeNumber !== opts.holeNumber &&
          h.holeNumber >= 1 &&
          h.holeNumber <= n,
      )
      .map((h) => h.carrierProfileId.toLowerCase());
    if (usedElsewhere.includes(carrier)) {
      return {
        ok: false,
        error:
          "That player already has a pink-ball hole in the opening rotation — pick someone remaining",
      };
    }
    return { ok: true };
  }

  const rotation = pinkBallRotationOrder({
    playerCount: n,
    pinkHoles: opts.pinkHoles,
  });
  if (!rotation) {
    return {
      ok: false,
      error: `Set unique pink-ball players on holes 1–${n} before scoring later holes`,
    };
  }
  const expected = rotation[(opts.holeNumber - 1) % n]!;
  if (carrier !== expected) {
    return {
      ok: false,
      error: `Pink ball on hole ${opts.holeNumber} is assigned by the hole 1–${n} rotation`,
    };
  }
  return { ok: true };
}

export type PinkBallHoleInput = {
  holeNumber: number;
  carrierProfileId: string;
  lost: boolean;
};

export type PinkBallScoreInput = {
  holeNumber: number;
  profileId: string;
  grossStrokes: number;
};

export type PinkBallStrokeIndex = {
  holeNumber: number;
  strokeIndex: number;
};

export type PinkBallPlayerRelative = {
  profileId: string;
  relativeStrokes: number;
};

export type PinkBallHoleNet = {
  hole_number: number;
  carrier_profile_id: string;
  lost: boolean;
  gross_strokes: number | null;
  net_strokes: number | null;
  counts: boolean;
};

export type PinkBallScoreSummary = {
  total_net: number | null;
  holes_counted: number;
  balls_lost: number;
  balls_remaining: number;
  eliminated: boolean;
  hole_nets: PinkBallHoleNet[];
};

export type PinkBallMatchStanding = {
  match_id: string;
  match_label: string;
  total_net: number | null;
  holes_counted: number;
  eliminated: boolean;
  rank: number | null;
  is_leader: boolean;
};

/**
 * Rank foursomes for a best-ball session pink-ball competition.
 * Lowest net wins among groups still alive. Eliminated groups are out
 * unless every group in the session is eliminated — then most holes
 * finished, then lowest net.
 */
export function rankPinkBallMatches(
  entries: Array<{
    matchId: string;
    matchLabel: string;
    score: PinkBallScoreSummary;
  }>,
): PinkBallMatchStanding[] {
  const scored = entries.filter((e) => e.score.holes_counted > 0);
  const alive = scored.filter((e) => !e.score.eliminated);
  const allGroupsEliminated =
    scored.length > 0 &&
    scored.length === entries.length &&
    alive.length === 0;

  const sorted = [...entries].sort((a, b) => {
    const aCount = a.score.holes_counted;
    const bCount = b.score.holes_counted;
    if (aCount === 0 && bCount === 0) {
      return a.matchLabel.localeCompare(b.matchLabel);
    }
    if (aCount === 0) return 1;
    if (bCount === 0) return -1;

    if (!allGroupsEliminated) {
      if (a.score.eliminated !== b.score.eliminated) {
        return a.score.eliminated ? 1 : -1;
      }
      if (a.score.eliminated && b.score.eliminated) {
        // Both out while others may still play — keep stable by label.
        return a.matchLabel.localeCompare(b.matchLabel);
      }
    } else if (bCount !== aCount) {
      return bCount - aCount;
    }

    const aNet = a.score.total_net ?? Number.POSITIVE_INFINITY;
    const bNet = b.score.total_net ?? Number.POSITIVE_INFINITY;
    if (aNet !== bNet) {
      return aNet - bNet;
    }
    if (bCount !== aCount) {
      return bCount - aCount;
    }
    return a.matchLabel.localeCompare(b.matchLabel);
  });

  let lastKey: string | null = null;
  let lastRank = 0;
  return sorted.map((entry, index) => {
    const hasScore = entry.score.holes_counted > 0;
    const inContention =
      hasScore && (!entry.score.eliminated || allGroupsEliminated);
    const key = inContention
      ? `${entry.score.eliminated}:${entry.score.total_net}:${entry.score.holes_counted}`
      : null;
    let rank: number | null = null;
    if (inContention) {
      if (key !== lastKey) {
        lastRank = index + 1;
        lastKey = key;
      }
      rank = lastRank;
    }
    return {
      match_id: entry.matchId,
      match_label: entry.matchLabel,
      total_net: entry.score.total_net,
      holes_counted: entry.score.holes_counted,
      eliminated: entry.score.eliminated,
      rank,
      is_leader: rank === 1,
    };
  });
}

/**
 * Sum carrier nets for counted holes. Stops counting after the 3rd lost ball
 * (the hole of the 3rd loss still counts if a score exists).
 */
export function computePinkBallScore(opts: {
  pinkHoles: PinkBallHoleInput[];
  scores: PinkBallScoreInput[];
  strokeIndexes: PinkBallStrokeIndex[];
  players: PinkBallPlayerRelative[];
}): PinkBallScoreSummary {
  const byHolePink = new Map(
    opts.pinkHoles.map((h) => [h.holeNumber, h]),
  );
  const strokeIndexByHole = new Map(
    opts.strokeIndexes.map((h) => [h.holeNumber, h.strokeIndex]),
  );
  const relativeByPlayer = new Map(
    opts.players.map((p) => [
      p.profileId.toLowerCase(),
      p.relativeStrokes,
    ]),
  );

  const scoresByHolePlayer = new Map<string, number>();
  for (const s of opts.scores) {
    scoresByHolePlayer.set(
      `${s.holeNumber}:${s.profileId.toLowerCase()}`,
      s.grossStrokes,
    );
  }

  let lostSoFar = 0;
  let totalNet = 0;
  let holesCounted = 0;
  let hasAnyNet = false;
  const holeNets: PinkBallHoleNet[] = [];

  for (let hole = 1; hole <= 18; hole += 1) {
    const pink = byHolePink.get(hole);
    if (!pink) {
      continue;
    }

    const eliminatedAlready = lostSoFar >= PINK_BALLS_PER_MATCH;
    const carrierId = pink.carrierProfileId.toLowerCase();
    const gross =
      scoresByHolePlayer.get(`${hole}:${carrierId}`) ?? null;
    const relative = relativeByPlayer.get(carrierId) ?? 0;
    const strokeIndex = strokeIndexByHole.get(hole) ?? hole;
    const strokes = strokesOnHole(relative, strokeIndex);
    const net =
      gross != null ? netScore(gross, strokes) : null;
    const counts = !eliminatedAlready && net != null;

    if (counts && net != null) {
      totalNet += net;
      holesCounted += 1;
      hasAnyNet = true;
    }

    holeNets.push({
      hole_number: hole,
      carrier_profile_id: pink.carrierProfileId,
      lost: pink.lost,
      gross_strokes: gross,
      net_strokes: net,
      counts,
    });

    if (!eliminatedAlready && pink.lost) {
      lostSoFar += 1;
    }
  }

  const ballsLost = opts.pinkHoles.filter((h) => h.lost).length;
  const cappedLost = Math.min(ballsLost, PINK_BALLS_PER_MATCH);

  return {
    total_net: hasAnyNet ? totalNet : null,
    holes_counted: holesCounted,
    balls_lost: cappedLost,
    balls_remaining: Math.max(0, PINK_BALLS_PER_MATCH - cappedLost),
    eliminated: cappedLost >= PINK_BALLS_PER_MATCH,
    hole_nets: holeNets,
  };
}

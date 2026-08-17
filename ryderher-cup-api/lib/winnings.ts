/**
 * Cash winnings from match results, pink ball, and Saturday PM singles skins.
 *
 * Match money (each player on a side):
 *   Win  = $50
 *   Push = $25
 *   Lose = $0
 *
 * Pink ball (each best-ball session):
 *   Each player on the winning group (lowest net) = $50
 *
 * Skins (last round singles only):
 *   Pot = $200 split evenly across awarded skins.
 */

export const MATCH_WIN_DOLLARS = 50;
export const MATCH_PUSH_DOLLARS = 25;
export const MATCH_LOSE_DOLLARS = 0;
export const PINK_BALL_WIN_DOLLARS = 50;
export const SKINS_POT_DOLLARS = 200;

export type SidePoints = number;

/** Map a side's match-play points (1 / 0.5 / 0) to cash for each player on that side. */
export function dollarsForSidePoints(points: SidePoints): number {
  if (points >= 1) {
    return MATCH_WIN_DOLLARS;
  }
  if (points >= 0.5) {
    return MATCH_PUSH_DOLLARS;
  }
  return MATCH_LOSE_DOLLARS;
}

export function payoutPerSkin(
  pot: number,
  skinsAwarded: number,
): number | null {
  if (skinsAwarded <= 0) {
    return null;
  }
  return pot / skinsAwarded;
}

export type WinningsSessionMeta = {
  id: string;
  label: string;
  sort_order: number;
};

export type WinningsMatchPlayer = {
  matchId: string;
  sessionId: string | null;
  profileId: string;
  displayName: string;
  teamSlug: string | null;
  side: "hookers" | "slicers" | null;
};

export type WinningsMatchResult = {
  matchId: string;
  sessionId: string | null;
  hookersPoints: number;
  slicersPoints: number;
};

export type SkinsPayoutLeader = {
  profile_id: string;
  display_name: string;
  team_slug: string | null;
  skins: number;
  amount: number;
};

/** Decided pink-ball session winners — every player on a winning group. */
export type PinkBallPayoutWinner = {
  profileId: string;
  displayName: string;
  teamSlug: string | null;
  sessionId: string;
};

export type PlayerSessionWinnings = {
  session_id: string;
  session_label: string;
  match_winnings: number;
  pink_ball_winnings: number;
  skins_winnings: number;
  total_winnings: number;
};

export type PlayerWinnings = {
  profile_id: string;
  display_name: string;
  team_slug: string | null;
  match_winnings: number;
  pink_ball_winnings: number;
  skins_winnings: number;
  total_winnings: number;
  by_session: PlayerSessionWinnings[];
};

export type WinningsStandings = {
  match_win: number;
  match_push: number;
  match_lose: number;
  pink_ball_win: number;
  skins_pot: number;
  players: PlayerWinnings[];
};

type Acc = {
  displayName: string;
  teamSlug: string | null;
  matchBySession: Map<string, number>;
  pinkBallBySession: Map<string, number>;
  skinsBySession: Map<string, number>;
  matchTotal: number;
  pinkBallTotal: number;
  skinsTotal: number;
};

function ensurePlayer(
  map: Map<string, Acc>,
  profileId: string,
  displayName: string,
  teamSlug: string | null,
): Acc {
  const existing = map.get(profileId);
  if (existing) {
    if (!existing.teamSlug && teamSlug) {
      existing.teamSlug = teamSlug;
    }
    return existing;
  }
  const created: Acc = {
    displayName,
    teamSlug,
    matchBySession: new Map(),
    pinkBallBySession: new Map(),
    skinsBySession: new Map(),
    matchTotal: 0,
    pinkBallTotal: 0,
    skinsTotal: 0,
  };
  map.set(profileId, created);
  return created;
}

function addSessionAmount(
  bySession: Map<string, number>,
  sessionId: string,
  amount: number,
): void {
  bySession.set(sessionId, (bySession.get(sessionId) ?? 0) + amount);
}

/**
 * Compute per-player match + pink ball + skins cash, broken down by session.
 * Pass only matches that should count (same gate as cup standings).
 * Pink ball winners should only include decided sessions (all best-ball final).
 * Skins leaders should already be scoped to last-round singles and include amounts.
 */
export function computePlayerWinnings(opts: {
  sessions: WinningsSessionMeta[];
  players: WinningsMatchPlayer[];
  results: WinningsMatchResult[];
  pinkBallWinners: PinkBallPayoutWinner[];
  skinsLeaders: SkinsPayoutLeader[];
  /** Session id that owns the skins pot (last day / last round). */
  skinsSessionId: string | null;
}): WinningsStandings {
  const sessionById = new Map(opts.sessions.map((s) => [s.id, s]));
  const resultsByMatch = new Map(opts.results.map((r) => [r.matchId, r]));
  const tally = new Map<string, Acc>();

  for (const player of opts.players) {
    if (player.side !== "hookers" && player.side !== "slicers") {
      continue;
    }
    const result = resultsByMatch.get(player.matchId);
    if (!result) {
      continue;
    }
    const points =
      player.side === "hookers"
        ? result.hookersPoints
        : result.slicersPoints;
    const dollars = dollarsForSidePoints(points);
    const acc = ensurePlayer(
      tally,
      player.profileId,
      player.displayName,
      player.teamSlug,
    );
    acc.matchTotal += dollars;
    if (player.sessionId && sessionById.has(player.sessionId)) {
      addSessionAmount(acc.matchBySession, player.sessionId, dollars);
    }
  }

  for (const winner of opts.pinkBallWinners) {
    if (!sessionById.has(winner.sessionId)) {
      continue;
    }
    const acc = ensurePlayer(
      tally,
      winner.profileId,
      winner.displayName,
      winner.teamSlug,
    );
    acc.pinkBallTotal += PINK_BALL_WIN_DOLLARS;
    addSessionAmount(
      acc.pinkBallBySession,
      winner.sessionId,
      PINK_BALL_WIN_DOLLARS,
    );
  }

  for (const leader of opts.skinsLeaders) {
    const acc = ensurePlayer(
      tally,
      leader.profile_id,
      leader.display_name,
      leader.team_slug,
    );
    acc.skinsTotal += leader.amount;
    if (opts.skinsSessionId && sessionById.has(opts.skinsSessionId)) {
      addSessionAmount(
        acc.skinsBySession,
        opts.skinsSessionId,
        leader.amount,
      );
    }
  }

  const orderedSessions = [...opts.sessions].sort(
    (a, b) => a.sort_order - b.sort_order,
  );

  const players: PlayerWinnings[] = [...tally.entries()]
    .map(([profileId, row]) => {
      const bySession: PlayerSessionWinnings[] = [];
      for (const session of orderedSessions) {
        const match = row.matchBySession.get(session.id) ?? 0;
        const pinkBall = row.pinkBallBySession.get(session.id) ?? 0;
        const skins = row.skinsBySession.get(session.id) ?? 0;
        if (match === 0 && pinkBall === 0 && skins === 0) {
          continue;
        }
        bySession.push({
          session_id: session.id,
          session_label: session.label,
          match_winnings: match,
          pink_ball_winnings: pinkBall,
          skins_winnings: skins,
          total_winnings: match + pinkBall + skins,
        });
      }

      return {
        profile_id: profileId,
        display_name: row.displayName,
        team_slug: row.teamSlug,
        match_winnings: row.matchTotal,
        pink_ball_winnings: row.pinkBallTotal,
        skins_winnings: row.skinsTotal,
        total_winnings: row.matchTotal + row.pinkBallTotal + row.skinsTotal,
        by_session: bySession,
      };
    })
    .filter((p) => p.total_winnings > 0)
    .sort((a, b) => {
      if (b.total_winnings !== a.total_winnings) {
        return b.total_winnings - a.total_winnings;
      }
      return a.display_name.localeCompare(b.display_name);
    });

  return {
    match_win: MATCH_WIN_DOLLARS,
    match_push: MATCH_PUSH_DOLLARS,
    match_lose: MATCH_LOSE_DOLLARS,
    pink_ball_win: PINK_BALL_WIN_DOLLARS,
    skins_pot: SKINS_POT_DOLLARS,
    players,
  };
}

import { NextRequest } from "next/server";
import { sql, type MatchRow, type SessionRow, type TeamSlug } from "@/lib/db";
import { json } from "@/lib/http";
import type { PlayingHandicapSnapshot } from "@/lib/handicaps";
import {
  pointsCountTowardStandings,
  sideGameScoresVisible,
} from "@/lib/matches";
import {
  computePinkBallScore,
  rankPinkBallMatches,
  type PinkBallMatchStanding,
} from "@/lib/pink-ball";
import { requireAuth } from "@/lib/request-auth";
import {
  computeSkinsStandings,
  type SkinScoreEntry,
} from "@/lib/skins";
import {
  computePlayerWinnings,
  SKINS_POT_DOLLARS,
  type WinningsMatchPlayer,
  type WinningsMatchResult,
} from "@/lib/winnings";

function parseSnapshot(raw: unknown): PlayingHandicapSnapshot | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  return raw as PlayingHandicapSnapshot;
}

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const sessions = await sql<SessionRow>`
    SELECT * FROM sessions ORDER BY sort_order ASC
  `;

  const lastSession =
    sessions.rows.length > 0
      ? sessions.rows.reduce((best, row) =>
          row.sort_order > best.sort_order ? row : best,
        )
      : null;

  const matches = await sql<
    MatchRow & {
      hookers_points: string | null;
      slicers_points: string | null;
      is_provisional: boolean | null;
    }
  >`
    SELECT
      m.*,
      r.hookers_points,
      r.slicers_points,
      r.is_provisional
    FROM matches m
    LEFT JOIN match_results r ON r.match_id = m.id
    ORDER BY m.sort_order ASC, m.created_at ASC
  `;

  const matchPlayers = await sql<{
    match_id: string;
    session_id: string | null;
    profile_id: string;
    display_name: string;
    team_slug: string | null;
    side: TeamSlug | null;
  }>`
    SELECT
      mp.match_id,
      m.session_id,
      mp.profile_id,
      p.display_name,
      t.slug AS team_slug,
      mp.side
    FROM match_players mp
    JOIN matches m ON m.id = mp.match_id
    JOIN profiles p ON p.id = mp.profile_id
    LEFT JOIN teams t ON t.id = p.team_id
  `;

  const skinScoreRows = await sql<{
    session_id: string | null;
    session_label: string | null;
    hole_number: number;
    profile_id: string;
    display_name: string;
    team_slug: string | null;
    gross_strokes: number;
    scoring_visibility: MatchRow["scoring_visibility"];
    status: MatchRow["status"];
  }>`
    SELECT
      m.session_id,
      s.label AS session_label,
      hs.hole_number,
      hs.profile_id,
      p.display_name,
      t.slug AS team_slug,
      hs.gross_strokes,
      m.scoring_visibility,
      m.status
    FROM hole_scores hs
    JOIN matches m ON m.id = hs.match_id
    JOIN profiles p ON p.id = hs.profile_id
    LEFT JOIN teams t ON t.id = p.team_id
    LEFT JOIN sessions s ON s.id = m.session_id
    WHERE hs.profile_id IS NOT NULL
      AND m.format = 'singles_match'
      AND s.id = ${lastSession?.id ?? null}
    ORDER BY s.sort_order ASC NULLS LAST, hs.hole_number ASC
  `;

  const pinkBallRows = await sql<{
    match_id: string;
    hole_number: number;
    carrier_profile_id: string;
    lost_count: number;
  }>`
    SELECT pb.match_id, pb.hole_number, pb.carrier_profile_id, pb.lost_count
    FROM pink_ball_holes pb
    JOIN matches m ON m.id = pb.match_id
    WHERE m.format = 'best_ball_match'
    ORDER BY pb.match_id, pb.hole_number
  `;

  const pinkScoreRows = await sql<{
    match_id: string;
    hole_number: number;
    profile_id: string;
    gross_strokes: number;
  }>`
    SELECT hs.match_id, hs.hole_number, hs.profile_id, hs.gross_strokes
    FROM hole_scores hs
    JOIN matches m ON m.id = hs.match_id
    WHERE m.format = 'best_ball_match'
      AND hs.profile_id IS NOT NULL
  `;

  const courseStrokeRows = await sql<{
    match_id: string;
    hole_number: number;
    stroke_index: number | null;
    par: number | null;
  }>`
    SELECT m.id AS match_id, ch.hole_number, ch.stroke_index, ch.par
    FROM matches m
    JOIN course_holes ch
      ON ch.course_id = m.course_id
     AND ch.tee_id = m.tee_id
    WHERE m.format = 'best_ball_match'
  `;

  const pinkByMatch = new Map<
    string,
    Array<{ holeNumber: number; carrierProfileId: string; lostCount: number }>
  >();
  for (const row of pinkBallRows.rows) {
    const list = pinkByMatch.get(row.match_id) ?? [];
    list.push({
      holeNumber: row.hole_number,
      carrierProfileId: row.carrier_profile_id,
      lostCount: row.lost_count,
    });
    pinkByMatch.set(row.match_id, list);
  }

  const scoresByMatch = new Map<
    string,
    Array<{ holeNumber: number; profileId: string; grossStrokes: number }>
  >();
  for (const row of pinkScoreRows.rows) {
    const list = scoresByMatch.get(row.match_id) ?? [];
    list.push({
      holeNumber: row.hole_number,
      profileId: row.profile_id,
      grossStrokes: row.gross_strokes,
    });
    scoresByMatch.set(row.match_id, list);
  }

  const courseHolesByMatch = new Map<
    string,
    Array<{ holeNumber: number; strokeIndex: number; par: number | null }>
  >();
  for (const row of courseStrokeRows.rows) {
    const list = courseHolesByMatch.get(row.match_id) ?? [];
    list.push({
      holeNumber: row.hole_number,
      strokeIndex: row.stroke_index ?? row.hole_number,
      par: row.par,
    });
    courseHolesByMatch.set(row.match_id, list);
  }

  let hookersTotal = 0;
  let slicersTotal = 0;

  const winningsResults: WinningsMatchResult[] = [];
  const countingMatchIds = new Set<string>();

  const sessionBreakdown = sessions.rows.map((session) => {
    let hookers = 0;
    let slicers = 0;
    const sessionMatches = [];
    const pinkEntries: Array<{
      matchId: string;
      matchLabel: string;
      score: ReturnType<typeof computePinkBallScore>;
    }> = [];

    for (const match of matches.rows) {
      if (match.session_id !== session.id) {
        continue;
      }

      const counts = pointsCountTowardStandings({
        isProvisional: match.is_provisional,
      });

      const hp =
        counts && match.hookers_points != null
          ? Number(match.hookers_points)
          : null;
      const sp =
        counts && match.slicers_points != null
          ? Number(match.slicers_points)
          : null;

      if (hp != null) {
        hookers += hp;
        hookersTotal += hp;
      }
      if (sp != null) {
        slicers += sp;
        slicersTotal += sp;
      }

      if (counts && hp != null && sp != null) {
        countingMatchIds.add(match.id);
        winningsResults.push({
          matchId: match.id,
          sessionId: match.session_id,
          hookersPoints: hp,
          slicersPoints: sp,
        });
      }

      sessionMatches.push({
        id: match.id,
        label: match.label,
        format: match.format,
        status: match.status,
        scoring_visibility: match.scoring_visibility,
        hookers_points: hp,
        slicers_points: sp,
        is_provisional: counts ? Boolean(match.is_provisional) : null,
        counts_toward_standings: counts,
      });

      if (
        match.format === "best_ball_match" &&
        sideGameScoresVisible({
          scoringVisibility: match.scoring_visibility,
          status: match.status,
        })
      ) {
        const snap = parseSnapshot(match.playing_handicaps);
        const score = computePinkBallScore({
          pinkHoles: pinkByMatch.get(match.id) ?? [],
          scores: scoresByMatch.get(match.id) ?? [],
          courseHoles: courseHolesByMatch.get(match.id) ?? [],
          players: (snap?.players ?? []).map((p) => ({
            profileId: p.profileId,
            relativeStrokes: p.relativeStrokes,
          })),
        });
        pinkEntries.push({
          matchId: match.id,
          matchLabel: match.label,
          score,
        });
      }
    }

    const pinkBallStandings: PinkBallMatchStanding[] =
      pinkEntries.length > 0 ? rankPinkBallMatches(pinkEntries) : [];
    const pinkBallLeader =
      pinkBallStandings.find((row) => row.is_leader) ?? null;

    return {
      session: {
        id: session.id,
        day: session.day,
        round_number: session.round_number,
        session_date: session.session_date,
        label: session.label,
        sort_order: session.sort_order,
      },
      hookers_points: hookers,
      slicers_points: slicers,
      matches: sessionMatches,
      pink_ball_standings: pinkBallStandings,
      pink_ball_leader: pinkBallLeader,
    };
  });

  // Matches without a session
  const unassigned = [];
  for (const match of matches.rows) {
    if (match.session_id) {
      continue;
    }
    const counts = pointsCountTowardStandings({
      isProvisional: match.is_provisional,
    });
    const hp =
      counts && match.hookers_points != null
        ? Number(match.hookers_points)
        : null;
    const sp =
      counts && match.slicers_points != null
        ? Number(match.slicers_points)
        : null;
    if (hp != null) {
      hookersTotal += hp;
    }
    if (sp != null) {
      slicersTotal += sp;
    }
    if (counts && hp != null && sp != null) {
      countingMatchIds.add(match.id);
      winningsResults.push({
        matchId: match.id,
        sessionId: match.session_id,
        hookersPoints: hp,
        slicersPoints: sp,
      });
    }
    unassigned.push({
      id: match.id,
      label: match.label,
      format: match.format,
      status: match.status,
      scoring_visibility: match.scoring_visibility,
      hookers_points: hp,
      slicers_points: sp,
      is_provisional: counts ? Boolean(match.is_provisional) : null,
      counts_toward_standings: counts,
    });
  }

  const skinEntries: SkinScoreEntry[] = [];
  for (const row of skinScoreRows.rows) {
    const visible = sideGameScoresVisible({
      scoringVisibility: row.scoring_visibility,
      status: row.status,
    });
    if (!visible) {
      continue;
    }
    skinEntries.push({
      sessionId: row.session_id,
      sessionLabel: row.session_label,
      holeNumber: row.hole_number,
      profileId: row.profile_id,
      displayName: row.display_name,
      teamSlug: row.team_slug,
      grossStrokes: row.gross_strokes,
    });
  }

  const skins = computeSkinsStandings(skinEntries, SKINS_POT_DOLLARS);

  const winningsPlayers: WinningsMatchPlayer[] = matchPlayers.rows
    .filter((row) => countingMatchIds.has(row.match_id))
    .map((row) => ({
      matchId: row.match_id,
      sessionId: row.session_id,
      profileId: row.profile_id,
      displayName: row.display_name,
      teamSlug: row.team_slug,
      side: row.side,
    }));

  const winnings = computePlayerWinnings({
    sessions: sessions.rows.map((s) => ({
      id: s.id,
      label: s.label,
      sort_order: s.sort_order,
    })),
    players: winningsPlayers,
    results: winningsResults,
    skinsLeaders: skins.leaders
      .filter((l) => l.amount != null)
      .map((l) => ({
        profile_id: l.profile_id,
        display_name: l.display_name,
        team_slug: l.team_slug,
        skins: l.skins,
        amount: l.amount!,
      })),
    skinsSessionId: lastSession?.id ?? null,
  });

  return json({
    hookers_points: hookersTotal,
    slicers_points: slicersTotal,
    sessions: sessionBreakdown,
    unassigned_matches: unassigned,
    skins,
    winnings,
  });
}

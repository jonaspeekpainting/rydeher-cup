import { NextRequest } from "next/server";
import { sql, type MatchRow, type SessionRow } from "@/lib/db";
import { json } from "@/lib/http";
import { pointsCountTowardStandings } from "@/lib/matches";
import { requireAuth } from "@/lib/request-auth";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const sessions = await sql<SessionRow>`
    SELECT * FROM sessions ORDER BY sort_order ASC
  `;

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

  let hookersTotal = 0;
  let slicersTotal = 0;

  const sessionBreakdown = sessions.rows.map((session) => {
    let hookers = 0;
    let slicers = 0;
    const sessionMatches = [];

    for (const match of matches.rows) {
      if (match.session_id !== session.id) {
        continue;
      }

      const counts = pointsCountTowardStandings({
        scoringVisibility: match.scoring_visibility,
        status: match.status,
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
    }

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
    };
  });

  // Matches without a session
  const unassigned = [];
  for (const match of matches.rows) {
    if (match.session_id) {
      continue;
    }
    const counts = pointsCountTowardStandings({
      scoringVisibility: match.scoring_visibility,
      status: match.status,
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

  return json({
    hookers_points: hookersTotal,
    slicers_points: slicersTotal,
    sessions: sessionBreakdown,
    unassigned_matches: unassigned,
  });
}

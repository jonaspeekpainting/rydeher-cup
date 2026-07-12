import { NextRequest } from "next/server";
import { sql, type MatchRow, type TeamSlug } from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import { fetchMatchDetail, recomputeMatchResult } from "@/lib/matches";
import { requireAuth } from "@/lib/request-auth";

type RouteContext = { params: Promise<{ id: string; hole: string }> };

type ScoreBody = {
  player_scores?: Array<{ profile_id: string; gross_strokes: number }>;
  side_scores?: Array<{ side: TeamSlug; gross_strokes: number }>;
};

export async function PUT(request: NextRequest, context: RouteContext) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const { id, hole: holeParam } = await context.params;
  const holeNumber = Number(holeParam);
  if (!Number.isInteger(holeNumber) || holeNumber < 1 || holeNumber > 18) {
    return errorResponse("hole must be 1–18", 400);
  }

  const matchResult = await sql<MatchRow>`
    SELECT * FROM matches WHERE id = ${id} LIMIT 1
  `;
  const match = matchResult.rows[0];
  if (!match) {
    return errorResponse("Match not found", 404);
  }
  if (match.status === "complete") {
    return errorResponse("Match is complete; scores are locked", 409);
  }
  if (!match.format) {
    return errorResponse("Match has no format", 400);
  }

  const participants = await sql<{ profile_id: string; side: TeamSlug }>`
    SELECT profile_id, side FROM match_players
    WHERE match_id = ${id} AND side IS NOT NULL
  `;
  const isParticipant = participants.rows.some(
    (p) => p.profile_id === auth.sub,
  );
  if (!isParticipant && !auth.isAdmin) {
    return errorResponse("Only match participants can enter scores", 403);
  }

  let body: ScoreBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const format = match.format;
  const teamBall = format === "scramble" || format === "alternate_shot";

  if (teamBall) {
    if (!body.side_scores?.length) {
      return errorResponse("side_scores required for this format", 400);
    }
    for (const entry of body.side_scores) {
      if (entry.side !== "hookers" && entry.side !== "slicers") {
        return errorResponse("Invalid side", 400);
      }
      if (
        !Number.isInteger(entry.gross_strokes) ||
        entry.gross_strokes < 1 ||
        entry.gross_strokes > 15
      ) {
        return errorResponse("gross_strokes must be 1–15", 400);
      }

      await sql`
        DELETE FROM hole_scores
        WHERE match_id = ${id}
          AND hole_number = ${holeNumber}
          AND side = ${entry.side}
      `;
      await sql`
        INSERT INTO hole_scores (match_id, hole_number, side, gross_strokes, updated_by)
        VALUES (${id}, ${holeNumber}, ${entry.side}, ${entry.gross_strokes}, ${auth.sub})
      `;
    }
  } else {
    if (!body.player_scores?.length) {
      return errorResponse("player_scores required for this format", 400);
    }

    const allowed = new Set(participants.rows.map((p) => p.profile_id));
    for (const entry of body.player_scores) {
      if (!allowed.has(entry.profile_id)) {
        return errorResponse("player is not in this match", 400);
      }
      if (
        !Number.isInteger(entry.gross_strokes) ||
        entry.gross_strokes < 1 ||
        entry.gross_strokes > 15
      ) {
        return errorResponse("gross_strokes must be 1–15", 400);
      }

      await sql`
        DELETE FROM hole_scores
        WHERE match_id = ${id}
          AND hole_number = ${holeNumber}
          AND profile_id = ${entry.profile_id}
      `;
      await sql`
        INSERT INTO hole_scores (match_id, hole_number, profile_id, gross_strokes, updated_by)
        VALUES (${id}, ${holeNumber}, ${entry.profile_id}, ${entry.gross_strokes}, ${auth.sub})
      `;
    }
  }

  if (match.status === "setup") {
    await sql`
      UPDATE matches SET status = 'in_progress', updated_at = now()
      WHERE id = ${id}
    `;
  }

  await recomputeMatchResult(id);
  return json(await fetchMatchDetail(id, auth));
}

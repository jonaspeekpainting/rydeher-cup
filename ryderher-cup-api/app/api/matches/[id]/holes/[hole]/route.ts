import { NextRequest } from "next/server";
import { sql, type MatchRow, type TeamSlug } from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import {
  fetchMatchDetail,
  PINK_BALLS_PER_MATCH,
  recomputeMatchResult,
  supportsPinkBall,
} from "@/lib/matches";
import { validatePinkBallCarrier } from "@/lib/pink-ball";
import { requireAuth } from "@/lib/request-auth";

type RouteContext = { params: Promise<{ id: string; hole: string }> };

type ScoreBody = {
  player_scores?: Array<{ profile_id: string; gross_strokes: number }>;
  side_scores?: Array<{ side: TeamSlug; gross_strokes: number }>;
  pink_ball?: {
    carrier_profile_id: string;
    lost?: boolean;
    lost_count?: number;
  } | null;
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
    (p) => p.profile_id.toLowerCase() === auth.sub.toLowerCase(),
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
  const allowed = new Set(
    participants.rows.map((p) => p.profile_id.toLowerCase()),
  );

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

    for (const entry of body.player_scores) {
      const profileId = String(entry.profile_id ?? "").toLowerCase();
      if (!allowed.has(profileId)) {
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
          AND profile_id = ${profileId}
      `;
      await sql`
        INSERT INTO hole_scores (match_id, hole_number, profile_id, gross_strokes, updated_by)
        VALUES (${id}, ${holeNumber}, ${profileId}, ${entry.gross_strokes}, ${auth.sub})
      `;
    }
  }

  if (body.pink_ball != null) {
    if (!supportsPinkBall(format)) {
      return errorResponse("Pink ball is only tracked on best ball matches", 400);
    }
    const carrierId = String(
      body.pink_ball.carrier_profile_id ?? "",
    ).toLowerCase();
    if (!allowed.has(carrierId)) {
      return errorResponse("Pink ball carrier must be in this match", 400);
    }
    const requestedLostCount =
      body.pink_ball.lost_count ??
      (body.pink_ball.lost ? 1 : 0);
    if (
      !Number.isInteger(requestedLostCount) ||
      requestedLostCount < 0 ||
      requestedLostCount > PINK_BALLS_PER_MATCH
    ) {
      return errorResponse(
        `pink_ball.lost_count must be 0–${PINK_BALLS_PER_MATCH}`,
        400,
      );
    }
    const lostCount = requestedLostCount;

    const existingPink = await sql<{
      hole_number: number;
      carrier_profile_id: string;
    }>`
      SELECT hole_number, carrier_profile_id
      FROM pink_ball_holes
      WHERE match_id = ${id}
    `;
    const validation = validatePinkBallCarrier({
      holeNumber,
      carrierProfileId: carrierId,
      playerIds: [...allowed],
      pinkHoles: existingPink.rows.map((row) => ({
        holeNumber: row.hole_number,
        carrierProfileId: row.carrier_profile_id,
      })),
    });
    if (!validation.ok) {
      return errorResponse(validation.error, 400);
    }

    const existingLost = await sql<{ count: string }>`
      SELECT COALESCE(SUM(lost_count), 0)::text AS count
      FROM pink_ball_holes
      WHERE match_id = ${id}
        AND hole_number <> ${holeNumber}
    `;
    const otherLost = Number(existingLost.rows[0]?.count ?? 0);
    if (otherLost + lostCount > PINK_BALLS_PER_MATCH) {
      return errorResponse(
        `A group can lose at most ${PINK_BALLS_PER_MATCH} pink balls`,
        400,
      );
    }

    await sql`
      INSERT INTO pink_ball_holes (
        match_id, hole_number, carrier_profile_id, lost, lost_count,
        updated_by, updated_at
      ) VALUES (
        ${id}, ${holeNumber}, ${carrierId}, ${lostCount > 0}, ${lostCount},
        ${auth.sub}, now()
      )
      ON CONFLICT (match_id, hole_number) DO UPDATE SET
        carrier_profile_id = EXCLUDED.carrier_profile_id,
        lost = EXCLUDED.lost,
        lost_count = EXCLUDED.lost_count,
        updated_by = EXCLUDED.updated_by,
        updated_at = now()
    `;
  } else if (
    supportsPinkBall(format) &&
    Object.prototype.hasOwnProperty.call(body, "pink_ball") &&
    body.pink_ball === null
  ) {
    await sql`
      DELETE FROM pink_ball_holes
      WHERE match_id = ${id} AND hole_number = ${holeNumber}
    `;
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

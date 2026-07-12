import { NextRequest } from "next/server";
import {
  sql,
  type MatchFormat,
  type MatchRow,
  type ScoringVisibility,
  type TeamSlug,
} from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import {
  buildPlayingHandicapSnapshot,
  fetchMatchDetail,
} from "@/lib/matches";
import { requireAdmin, requireAuth } from "@/lib/request-auth";

type RouteContext = { params: Promise<{ id: string }> };

export async function GET(request: NextRequest, context: RouteContext) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const { id } = await context.params;
  const detail = await fetchMatchDetail(id, auth);
  if (!detail) {
    return errorResponse("Match not found", 404);
  }
  return json(detail);
}

type PatchBody = {
  label?: string;
  sort_order?: number;
  session_id?: string | null;
  format?: MatchFormat;
  course_id?: string | null;
  tee_id?: string | null;
  scoring_visibility?: ScoringVisibility;
  status?: "setup" | "in_progress" | "complete";
  players?: Array<{ profile_id: string; side: TeamSlug }>;
  refresh_handicaps?: boolean;
};

export async function PATCH(request: NextRequest, context: RouteContext) {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) {
    return auth;
  }

  const { id } = await context.params;
  const existing = await sql<MatchRow>`
    SELECT * FROM matches WHERE id = ${id} LIMIT 1
  `;
  if (!existing.rows[0]) {
    return errorResponse("Match not found", 404);
  }

  let body: PatchBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const match = existing.rows[0];
  const label = body.label?.trim() ?? match.label;
  const sortOrder = body.sort_order ?? match.sort_order;
  const sessionId =
    body.session_id !== undefined ? body.session_id : match.session_id;
  const format = body.format !== undefined ? body.format : match.format;
  const courseId =
    body.course_id !== undefined ? body.course_id : match.course_id;
  const teeId = body.tee_id !== undefined ? body.tee_id : match.tee_id;
  const visibility =
    body.scoring_visibility ?? match.scoring_visibility;
  const status = body.status ?? match.status;

  await sql`
    UPDATE matches
    SET
      label = ${label},
      sort_order = ${sortOrder},
      session_id = ${sessionId},
      format = ${format},
      course_id = ${courseId},
      tee_id = ${teeId},
      scoring_visibility = ${visibility},
      status = ${status},
      updated_at = now()
    WHERE id = ${id}
  `;

  if (body.players) {
    await sql`DELETE FROM match_players WHERE match_id = ${id}`;
    for (const player of body.players) {
      if (
        !player.profile_id ||
        (player.side !== "hookers" && player.side !== "slicers")
      ) {
        continue;
      }
      await sql`
        INSERT INTO match_players (match_id, profile_id, side)
        VALUES (${id}, ${player.profile_id}, ${player.side})
      `;
    }
  }

  if ((body.refresh_handicaps || body.players || body.format) && format) {
    const snapshot = await buildPlayingHandicapSnapshot(id, format);
    await sql`
      UPDATE matches
      SET playing_handicaps = ${JSON.stringify(snapshot)}::jsonb,
          updated_at = now()
      WHERE id = ${id}
    `;
  }

  const detail = await fetchMatchDetail(id, auth);
  return json(detail);
}

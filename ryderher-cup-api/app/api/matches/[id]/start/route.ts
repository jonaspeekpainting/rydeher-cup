import { NextRequest } from "next/server";
import { sql, type MatchRow } from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import {
  buildPlayingHandicapSnapshot,
  fetchMatchDetail,
} from "@/lib/matches";
import { requireAdmin } from "@/lib/request-auth";

type RouteContext = { params: Promise<{ id: string }> };

export async function POST(request: NextRequest, context: RouteContext) {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) {
    return auth;
  }

  const { id } = await context.params;
  const existing = await sql<MatchRow>`
    SELECT * FROM matches WHERE id = ${id} LIMIT 1
  `;
  const match = existing.rows[0];
  if (!match) {
    return errorResponse("Match not found", 404);
  }
  if (!match.format) {
    return errorResponse("Match format must be set before starting", 400);
  }

  const snapshot = await buildPlayingHandicapSnapshot(id, match.format);
  await sql`
    UPDATE matches
    SET
      status = 'in_progress',
      playing_handicaps = ${JSON.stringify(snapshot)}::jsonb,
      updated_at = now()
    WHERE id = ${id}
  `;

  return json(await fetchMatchDetail(id, auth));
}

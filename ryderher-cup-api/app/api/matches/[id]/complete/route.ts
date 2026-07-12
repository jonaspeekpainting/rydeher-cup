import { NextRequest } from "next/server";
import { sql, type MatchRow } from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import { fetchMatchDetail, recomputeMatchResult } from "@/lib/matches";
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
  if (!existing.rows[0]) {
    return errorResponse("Match not found", 404);
  }

  await recomputeMatchResult(id);

  await sql`
    UPDATE matches
    SET status = 'complete', updated_at = now()
    WHERE id = ${id}
  `;

  // Ensure result is not provisional after admin complete
  await sql`
    UPDATE match_results
    SET is_provisional = false, updated_at = now()
    WHERE match_id = ${id}
  `;

  return json(await fetchMatchDetail(id, auth));
}

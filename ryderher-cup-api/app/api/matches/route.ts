import { NextRequest } from "next/server";
import type { MatchFormat, ScoringVisibility, TeamSlug } from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import {
  createMatchRecord,
  loadCreatedMatchDetail,
} from "@/lib/match-create";
import { listMatchesSummary } from "@/lib/matches";
import { requireAdmin, requireAuth } from "@/lib/request-auth";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  return json(await listMatchesSummary(auth));
}

type CreateMatchBody = {
  label?: string;
  sort_order?: number;
  session_id?: string | null;
  format?: MatchFormat;
  course_id?: string | null;
  tee_id?: string | null;
  scoring_visibility?: ScoringVisibility;
  players?: Array<{ profile_id: string; side: TeamSlug }>;
};

export async function POST(request: NextRequest) {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) {
    return auth;
  }

  let body: CreateMatchBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const label = body.label?.trim();
  if (!label) {
    return errorResponse("label is required", 400);
  }

  const result = await createMatchRecord({
    label,
    sort_order: body.sort_order,
    session_id: body.session_id,
    format: body.format,
    course_id: body.course_id,
    tee_id: body.tee_id,
    scoring_visibility: body.scoring_visibility,
    players: body.players,
  });

  if (!result.ok) {
    return errorResponse(result.error, result.status);
  }

  const detail = await loadCreatedMatchDetail(result.matchId, auth);
  return json(detail, 201);
}

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
  listMatchesSummary,
} from "@/lib/matches";
import { requireAdmin, requireAuth } from "@/lib/request-auth";

const FORMATS: MatchFormat[] = [
  "best_ball_match",
  "scramble",
  "shamble",
  "singles_match",
  "alternate_shot",
];

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

  if (body.format && !FORMATS.includes(body.format)) {
    return errorResponse("Invalid format", 400);
  }

  const visibility = body.scoring_visibility ?? "release_on_complete";
  if (visibility !== "live" && visibility !== "release_on_complete") {
    return errorResponse("Invalid scoring_visibility", 400);
  }

  const matchResult = await sql<MatchRow>`
    INSERT INTO matches (
      label, sort_order, session_id, format, course_id, tee_id,
      scoring_visibility, status
    )
    VALUES (
      ${label},
      ${body.sort_order ?? 0},
      ${body.session_id ?? null},
      ${body.format ?? null},
      ${body.course_id ?? null},
      ${body.tee_id ?? null},
      ${visibility},
      'setup'
    )
    RETURNING *
  `;

  const match = matchResult.rows[0];
  if (!match) {
    return errorResponse("Could not create match", 500);
  }

  for (const player of body.players ?? []) {
    if (!player.profile_id || !player.side) {
      continue;
    }
    if (player.side !== "hookers" && player.side !== "slicers") {
      await sql`DELETE FROM matches WHERE id = ${match.id}`;
      return errorResponse("side must be hookers or slicers", 400);
    }

    const profileResult = await sql`
      SELECT id FROM profiles WHERE id = ${player.profile_id} LIMIT 1
    `;
    if (profileResult.rows.length === 0) {
      await sql`DELETE FROM matches WHERE id = ${match.id}`;
      return errorResponse("Invalid profile_id in players", 400);
    }

    await sql`
      INSERT INTO match_players (match_id, profile_id, side)
      VALUES (${match.id}, ${player.profile_id}, ${player.side})
    `;
  }

  if (body.format) {
    const snapshot = await buildPlayingHandicapSnapshot(match.id, body.format);
    await sql`
      UPDATE matches
      SET playing_handicaps = ${JSON.stringify(snapshot)}::jsonb,
          updated_at = now()
      WHERE id = ${match.id}
    `;
  }

  const detail = await fetchMatchDetail(match.id, auth);
  return json(detail, 201);
}

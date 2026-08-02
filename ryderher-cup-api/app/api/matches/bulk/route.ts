import { NextRequest } from "next/server";
import { sql, type MatchFormat, type ScoringVisibility, type TeamSlug } from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import {
  MATCH_FORMATS,
  createMatchRecord,
  loadCreatedMatchDetail,
  type MatchPlayerInput,
} from "@/lib/match-create";
import { requireAdmin } from "@/lib/request-auth";

type BulkPairing = {
  label?: string;
  sort_order?: number;
  players?: MatchPlayerInput[];
};

type BulkBody = {
  session_id?: string;
  format?: MatchFormat;
  course_id?: string | null;
  tee_id?: string | null;
  scoring_visibility?: ScoringVisibility;
  matches?: BulkPairing[];
};

export async function POST(request: NextRequest) {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) {
    return auth;
  }

  let body: BulkBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  if (!body.session_id) {
    return errorResponse("session_id is required", 400);
  }

  const sessionCheck = await sql`
    SELECT id FROM sessions WHERE id = ${body.session_id} LIMIT 1
  `;
  if (sessionCheck.rows.length === 0) {
    return errorResponse("Invalid session_id", 400);
  }

  if (!body.format || !MATCH_FORMATS.includes(body.format)) {
    return errorResponse("format is required", 400);
  }

  const visibility = body.scoring_visibility ?? "release_on_complete";
  if (visibility !== "live" && visibility !== "release_on_complete") {
    return errorResponse("Invalid scoring_visibility", 400);
  }

  const pairings = body.matches ?? [];
  if (pairings.length !== 5 && pairings.length !== 10) {
    return errorResponse("matches must contain 5 or 10 pairings", 400);
  }

  const expectedPerSide = body.format === "singles_match" ? 1 : 2;
  const seen = new Set<string>();

  for (let i = 0; i < pairings.length; i += 1) {
    const pairing = pairings[i]!;
    const players = pairing.players ?? [];
    const hookers = players.filter((p) => p.side === "hookers");
    const slicers = players.filter((p) => p.side === "slicers");

    if (
      hookers.length !== expectedPerSide ||
      slicers.length !== expectedPerSide
    ) {
      return errorResponse(
        `Match ${i + 1}: need ${expectedPerSide} Hooker(s) and ${expectedPerSide} Slicer(s)`,
        400,
      );
    }

    for (const player of players) {
      if (player.side !== "hookers" && player.side !== "slicers") {
        return errorResponse(
          `Match ${i + 1}: side must be hookers or slicers`,
          400,
        );
      }
      const key = player.profile_id.toLowerCase();
      if (seen.has(key)) {
        return errorResponse(
          `Match ${i + 1}: player appears in more than one pairing`,
          400,
        );
      }
      seen.add(key);
    }
  }

  const nameById = await loadProfileNames(
    pairings.flatMap((p) => (p.players ?? []).map((pl) => pl.profile_id)),
  );

  const createdIds: string[] = [];

  try {
    for (let i = 0; i < pairings.length; i += 1) {
      const pairing = pairings[i]!;
      const label =
        pairing.label?.trim() ||
        labelFromPlayers(pairing.players ?? [], nameById, i + 1);

      const result = await createMatchRecord({
        label,
        sort_order: pairing.sort_order ?? i + 1,
        session_id: body.session_id,
        format: body.format,
        course_id: body.course_id ?? null,
        tee_id: body.tee_id ?? null,
        scoring_visibility: visibility,
        players: pairing.players,
      });

      if (!result.ok) {
        throw Object.assign(new Error(result.error), {
          status: result.status,
          createdIds,
        });
      }
      createdIds.push(result.matchId);
    }
  } catch (error) {
    for (const id of createdIds) {
      await sql`DELETE FROM matches WHERE id = ${id}`;
    }
    const status =
      error && typeof error === "object" && "status" in error
        ? Number((error as { status: number }).status)
        : 500;
    const message =
      error instanceof Error ? error.message : "Could not create matches";
    return errorResponse(message, Number.isFinite(status) ? status : 500);
  }

  const details = [];
  for (const id of createdIds) {
    const detail = await loadCreatedMatchDetail(id, auth);
    if (detail) {
      details.push(detail);
    }
  }

  return json({ matches: details }, 201);
}

async function loadProfileNames(
  ids: string[],
): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  const unique = [...new Set(ids.filter(Boolean))];
  for (const id of unique) {
    const result = await sql<{ display_name: string }>`
      SELECT display_name FROM profiles WHERE id = ${id} LIMIT 1
    `;
    if (result.rows[0]) {
      map.set(id.toLowerCase(), result.rows[0].display_name);
    }
  }
  return map;
}

function lastName(full: string): string {
  const parts = full.trim().split(/\s+/);
  return parts[parts.length - 1] ?? full;
}

function labelFromPlayers(
  players: MatchPlayerInput[],
  names: Map<string, string>,
  index: number,
): string {
  const sideNames = (side: TeamSlug) =>
    players
      .filter((p) => p.side === side)
      .map((p) => names.get(p.profile_id.toLowerCase()) ?? "TBD")
      .map(lastName);

  const hookers = sideNames("hookers").join(" / ");
  const slicers = sideNames("slicers").join(" / ");
  if (!hookers && !slicers) {
    return `Match ${index}`;
  }
  return `Match ${index} · ${hookers} vs ${slicers}`;
}

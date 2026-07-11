import { NextRequest } from "next/server";
import { sql, type MatchRow, type ProfileRow } from "@/lib/db";
import { profileResponse } from "@/lib/auth";
import { errorResponse, json } from "@/lib/http";
import { requireAdmin, requireAuth } from "@/lib/request-auth";

type MatchPlayerResponse = {
  id: string;
  profile_id: string;
  side: string | null;
  profile: ReturnType<typeof profileResponse>;
};

type MatchResponse = {
  id: string;
  label: string;
  sort_order: number;
  created_at: string;
  players: MatchPlayerResponse[];
};

type CreateMatchBody = {
  label?: string;
  sort_order?: number;
  players?: Array<{ profile_id: string; side?: string | null }>;
};

async function fetchMatches(): Promise<MatchResponse[]> {
  const rows = await sql<
    MatchRow & {
      mp_id: string | null;
      profile_id: string | null;
      side: string | null;
      email: string | null;
      display_name: string | null;
      is_admin: boolean | null;
      profile_created_at: string | null;
    }
  >`
    SELECT
      m.id,
      m.label,
      m.sort_order,
      m.created_at,
      mp.id AS mp_id,
      mp.profile_id,
      mp.side,
      p.email,
      p.display_name,
      p.is_admin,
      p.created_at AS profile_created_at
    FROM matches m
    LEFT JOIN match_players mp ON mp.match_id = m.id
    LEFT JOIN profiles p ON p.id = mp.profile_id
    ORDER BY m.sort_order ASC, m.created_at ASC, mp.created_at ASC
  `;

  const matches = new Map<string, MatchResponse>();

  for (const row of rows.rows) {
    let match = matches.get(row.id);
    if (!match) {
      match = {
        id: row.id,
        label: row.label,
        sort_order: row.sort_order,
        created_at: row.created_at,
        players: [],
      };
      matches.set(row.id, match);
    }

    if (
      row.mp_id &&
      row.profile_id &&
      row.email &&
      row.display_name != null &&
      row.is_admin != null &&
      row.profile_created_at
    ) {
      match.players.push({
        id: row.mp_id,
        profile_id: row.profile_id,
        side: row.side,
        profile: profileResponse({
          id: row.profile_id,
          email: row.email,
          display_name: row.display_name,
          is_admin: row.is_admin,
          created_at: row.profile_created_at,
        }),
      });
    }
  }

  return Array.from(matches.values());
}

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  return json(await fetchMatches());
}

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

  const sortOrder = body.sort_order ?? 0;
  const players = body.players ?? [];

  const matchResult = await sql<MatchRow>`
    INSERT INTO matches (label, sort_order)
    VALUES (${label}, ${sortOrder})
    RETURNING id, label, sort_order, created_at
  `;

  const match = matchResult.rows[0];
  if (!match) {
    return errorResponse("Could not create match", 500);
  }

  for (const player of players) {
    if (!player.profile_id) {
      continue;
    }

    const profileResult = await sql<ProfileRow>`
      SELECT id FROM profiles WHERE id = ${player.profile_id} LIMIT 1
    `;
    if (profileResult.rows.length === 0) {
      await sql`DELETE FROM matches WHERE id = ${match.id}`;
      return errorResponse("Invalid profile_id in players", 400);
    }

    await sql`
      INSERT INTO match_players (match_id, profile_id, side)
      VALUES (${match.id}, ${player.profile_id}, ${player.side ?? null})
    `;
  }

  const matches = await fetchMatches();
  const created = matches.find((item) => item.id === match.id);
  return json(created ?? { ...match, players: [] }, 201);
}

import {
  sql,
  type MatchFormat,
  type MatchRow,
  type ScoringVisibility,
  type TeamSlug,
} from "@/lib/db";
import {
  buildPlayingHandicapSnapshot,
  fetchMatchDetail,
  type MatchDetail,
} from "@/lib/matches";

export const MATCH_FORMATS: MatchFormat[] = [
  "best_ball_match",
  "scramble",
  "shamble",
  "singles_match",
  "alternate_shot",
];

export type MatchPlayerInput = {
  profile_id: string;
  side: TeamSlug;
};

export type CreateMatchInput = {
  label: string;
  sort_order?: number;
  session_id?: string | null;
  format?: MatchFormat | null;
  course_id?: string | null;
  tee_id?: string | null;
  scoring_visibility?: ScoringVisibility;
  players?: MatchPlayerInput[];
};

export type CreateMatchResult =
  | { ok: true; matchId: string }
  | { ok: false; error: string; status: number };

export async function createMatchRecord(
  input: CreateMatchInput,
): Promise<CreateMatchResult> {
  const label = input.label.trim();
  if (!label) {
    return { ok: false, error: "label is required", status: 400 };
  }

  if (input.format && !MATCH_FORMATS.includes(input.format)) {
    return { ok: false, error: "Invalid format", status: 400 };
  }

  const visibility = input.scoring_visibility ?? "release_on_complete";
  if (visibility !== "live" && visibility !== "release_on_complete") {
    return { ok: false, error: "Invalid scoring_visibility", status: 400 };
  }

  const matchResult = await sql<MatchRow>`
    INSERT INTO matches (
      label, sort_order, session_id, format, course_id, tee_id,
      scoring_visibility, status
    )
    VALUES (
      ${label},
      ${input.sort_order ?? 0},
      ${input.session_id ?? null},
      ${input.format ?? null},
      ${input.course_id ?? null},
      ${input.tee_id ?? null},
      ${visibility},
      'setup'
    )
    RETURNING *
  `;

  const match = matchResult.rows[0];
  if (!match) {
    return { ok: false, error: "Could not create match", status: 500 };
  }

  for (const player of input.players ?? []) {
    if (!player.profile_id || !player.side) {
      continue;
    }
    if (player.side !== "hookers" && player.side !== "slicers") {
      await sql`DELETE FROM matches WHERE id = ${match.id}`;
      return {
        ok: false,
        error: "side must be hookers or slicers",
        status: 400,
      };
    }

    const profileResult = await sql`
      SELECT id FROM profiles WHERE id = ${player.profile_id} LIMIT 1
    `;
    if (profileResult.rows.length === 0) {
      await sql`DELETE FROM matches WHERE id = ${match.id}`;
      return {
        ok: false,
        error: "Invalid profile_id in players",
        status: 400,
      };
    }

    await sql`
      INSERT INTO match_players (match_id, profile_id, side)
      VALUES (${match.id}, ${player.profile_id}, ${player.side})
    `;
  }

  if (input.format) {
    const snapshot = await buildPlayingHandicapSnapshot(match.id, input.format);
    await sql`
      UPDATE matches
      SET playing_handicaps = ${JSON.stringify(snapshot)}::jsonb,
          updated_at = now()
      WHERE id = ${match.id}
    `;
  }

  return { ok: true, matchId: match.id };
}

export async function loadCreatedMatchDetail(
  matchId: string,
  viewer: { sub: string; isAdmin: boolean },
): Promise<MatchDetail | null> {
  return fetchMatchDetail(matchId, viewer);
}

import { NextRequest } from "next/server";
import { sql, type TeamSlug } from "@/lib/db";
import { profileResponse } from "@/lib/auth";
import { fetchHandicapIndex } from "@/lib/ghin";
import { errorResponse, json } from "@/lib/http";
import { requireAdmin } from "@/lib/request-auth";
import { loadProfile } from "@/lib/profile-query";

type RouteContext = { params: Promise<{ id: string }> };

type PatchBody = {
  team_slug?: TeamSlug | null;
  ghin_number?: string;
  handicap_index?: number | null;
  course_handicap?: number | null;
};

export async function PATCH(request: NextRequest, context: RouteContext) {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) {
    return auth;
  }

  const { id } = await context.params;
  const current = await loadProfile(id);
  if (!current) {
    return errorResponse("Profile not found", 404);
  }

  let body: PatchBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  if (body.team_slug !== undefined) {
    if (body.team_slug === null) {
      await sql`UPDATE profiles SET team_id = NULL WHERE id = ${id}`;
    } else {
      const team = await sql<{ id: string }>`
        SELECT id FROM teams WHERE slug = ${body.team_slug} LIMIT 1
      `;
      if (!team.rows[0]) {
        return errorResponse("Invalid team_slug", 400);
      }
      await sql`
        UPDATE profiles SET team_id = ${team.rows[0].id} WHERE id = ${id}
      `;
      await sql`
        UPDATE roster_entries
        SET profile_id = ${id}, team_id = ${team.rows[0].id}
        WHERE lower(trim(display_name)) = ${current.display_name.trim().toLowerCase()}
           OR profile_id = ${id}
      `;
    }
  }

  if (body.ghin_number || body.handicap_index != null) {
    const ghin = body.ghin_number?.trim() || current.ghin_number || "";
    if (!ghin) {
      return errorResponse("ghin_number is required", 400);
    }
    try {
      const handicap = await fetchHandicapIndex(ghin, body.handicap_index);
      await sql`
        UPDATE profiles
        SET
          ghin_number = ${handicap.ghinNumber},
          handicap_index = ${handicap.handicapIndex},
          handicap_source = ${handicap.source},
          handicap_updated_at = now()
        WHERE id = ${id}
      `;
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Could not update handicap";
      return errorResponse(message, 400);
    }
  }

  if (body.course_handicap != null) {
    await sql`
      UPDATE profiles SET course_handicap = ${body.course_handicap}
      WHERE id = ${id}
    `;
  }

  const profile = await loadProfile(id);
  return json(profileResponse(profile!));
}

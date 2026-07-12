import { NextRequest } from "next/server";
import { sql } from "@/lib/db";
import { profileResponse } from "@/lib/auth";
import { fetchHandicapIndex } from "@/lib/ghin";
import { errorResponse, json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";
import { loadProfile } from "@/lib/profile-query";

type PatchBody = {
  ghin_number?: string;
  handicap_index?: number | null;
  course_handicap?: number | null;
  refresh_ghin?: boolean;
};

export async function PATCH(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  let body: PatchBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const current = await loadProfile(auth.sub);
  if (!current) {
    return errorResponse("Profile not found", 404);
  }

  const ghinNumber = body.ghin_number?.trim() || current.ghin_number || "";

  if (body.refresh_ghin || body.ghin_number || body.handicap_index != null) {
    if (!ghinNumber) {
      return errorResponse("ghin_number is required", 400);
    }
    try {
      const handicap = await fetchHandicapIndex(ghinNumber, body.handicap_index);
      await sql`
        UPDATE profiles
        SET
          ghin_number = ${handicap.ghinNumber},
          handicap_index = ${handicap.handicapIndex},
          handicap_source = ${handicap.source},
          handicap_updated_at = now()
        WHERE id = ${auth.sub}
      `;
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Could not update handicap";
      return errorResponse(message, 400);
    }
  }

  if (body.course_handicap != null) {
    await sql`
      UPDATE profiles
      SET course_handicap = ${body.course_handicap}
      WHERE id = ${auth.sub}
    `;
  }

  const profile = await loadProfile(auth.sub);
  return json(profileResponse(profile!));
}

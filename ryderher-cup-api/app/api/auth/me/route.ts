import { NextRequest } from "next/server";
import { sql, type ProfileRow } from "@/lib/db";
import { profileResponse } from "@/lib/auth";
import { errorResponse, json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const profileResult = await sql<ProfileRow>`
    SELECT id, email, display_name, is_admin, created_at
    FROM profiles
    WHERE id = ${auth.sub}
    LIMIT 1
  `;

  const profile = profileResult.rows[0];
  if (!profile) {
    return errorResponse("Profile not found", 404);
  }

  return json(profileResponse(profile));
}

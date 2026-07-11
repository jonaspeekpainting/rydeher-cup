import { NextRequest } from "next/server";
import { sql, type ProfileRow } from "@/lib/db";
import { profileResponse } from "@/lib/auth";
import { json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const result = await sql<ProfileRow>`
    SELECT id, email, display_name, is_admin, created_at
    FROM profiles
    ORDER BY display_name ASC
  `;

  return json(result.rows.map(profileResponse));
}

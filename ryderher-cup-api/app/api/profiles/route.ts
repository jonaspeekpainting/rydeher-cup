import { NextRequest } from "next/server";
import { json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";
import { loadAllProfiles } from "@/lib/profile-query";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  return json(await loadAllProfiles());
}

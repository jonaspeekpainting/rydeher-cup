import { NextRequest } from "next/server";
import { profileResponse } from "@/lib/auth";
import { errorResponse, json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";
import { loadProfile } from "@/lib/profile-query";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const profile = await loadProfile(auth.sub);
  if (!profile) {
    return errorResponse("Profile not found", 404);
  }

  return json(profileResponse(profile));
}

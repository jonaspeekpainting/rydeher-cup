import { NextRequest } from "next/server";
import { verifyToken, type AuthClaims } from "./auth";
import { errorResponse } from "./http";

export async function requireAuth(
  request: NextRequest,
): Promise<AuthClaims | Response> {
  const claims = await verifyToken(request.headers.get("authorization"));
  if (!claims) {
    return errorResponse("Unauthorized", 401);
  }
  return claims;
}

export async function requireAdmin(
  request: NextRequest,
): Promise<AuthClaims | Response> {
  const result = await requireAuth(request);
  if (result instanceof Response) {
    return result;
  }
  if (!result.isAdmin) {
    return errorResponse("Forbidden", 403);
  }
  return result;
}

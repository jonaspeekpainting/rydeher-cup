import { NextRequest } from "next/server";
import { deleteAccount } from "@/lib/delete-account";
import { errorResponse, json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";

export async function DELETE(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  try {
    const deleted = await deleteAccount(auth.sub);
    if (!deleted) {
      return errorResponse("Account not found", 404);
    }
    return json({ ok: true });
  } catch (error) {
    console.error(error);
    return errorResponse("Could not delete account", 500);
  }
}

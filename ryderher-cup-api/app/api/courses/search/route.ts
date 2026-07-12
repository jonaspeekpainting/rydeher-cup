import { NextRequest } from "next/server";
import { searchCourses } from "@/lib/opengolf";
import { errorResponse, json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const q = request.nextUrl.searchParams.get("q") ?? "";
  try {
    const results = await searchCourses(q);
    return json(
      results.map((c) => ({
        external_id: String(c.id),
        name: c.name,
        city: c.city ?? null,
        state: c.state ?? null,
      })),
    );
  } catch (error) {
    console.error(error);
    return errorResponse("Course search failed", 502);
  }
}

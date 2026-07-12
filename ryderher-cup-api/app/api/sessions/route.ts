import { NextRequest } from "next/server";
import { sql, type SessionRow } from "@/lib/db";
import { errorResponse, json } from "@/lib/http";
import { requireAdmin, requireAuth } from "@/lib/request-auth";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const result = await sql<SessionRow>`
    SELECT * FROM sessions ORDER BY sort_order ASC, round_number ASC
  `;
  return json(result.rows);
}

type CreateBody = {
  day?: string;
  round_number?: number;
  session_date?: string;
  label?: string;
  sort_order?: number;
};

export async function POST(request: NextRequest) {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) {
    return auth;
  }

  let body: CreateBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  if (!body.day || !body.round_number || !body.session_date || !body.label) {
    return errorResponse(
      "day, round_number, session_date, and label are required",
      400,
    );
  }

  const result = await sql<SessionRow>`
    INSERT INTO sessions (day, round_number, session_date, label, sort_order)
    VALUES (
      ${body.day},
      ${body.round_number},
      ${body.session_date},
      ${body.label},
      ${body.sort_order ?? body.round_number}
    )
    RETURNING *
  `;

  return json(result.rows[0], 201);
}

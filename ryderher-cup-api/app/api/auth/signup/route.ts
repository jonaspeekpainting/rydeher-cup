import { sql, normalizeEmail, type InviteRow } from "@/lib/db";
import {
  hashPassword,
  profileResponse,
  signToken,
  verifyTournamentCode,
} from "@/lib/auth";
import { fetchHandicapIndex } from "@/lib/ghin";
import { errorResponse, json } from "@/lib/http";
import { linkRosterOnSignup, loadProfile } from "@/lib/profile-query";

type SignupBody = {
  email?: string;
  password?: string;
  code?: string;
  ghin_number?: string;
  handicap_index?: number | null;
};

export async function POST(request: Request) {
  let body: SignupBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const emailRaw = body.email;
  const password = body.password;
  const code = body.code?.trim() ?? "";
  const ghinNumber = body.ghin_number?.trim() ?? "";

  if (!emailRaw || !password || !code) {
    return errorResponse("email, password, and code are required", 400);
  }

  if (!ghinNumber) {
    return errorResponse("ghin_number is required", 400);
  }

  const email = normalizeEmail(emailRaw);
  if (password.length < 8) {
    return errorResponse("Password must be at least 8 characters", 400);
  }

  try {
    if (!verifyTournamentCode(code)) {
      return errorResponse("Invalid tournament code", 401);
    }
  } catch (error) {
    console.error(error);
    return errorResponse("Tournament signup is not configured", 500);
  }

  let handicap;
  try {
    handicap = await fetchHandicapIndex(ghinNumber, body.handicap_index);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Could not resolve handicap";
    return errorResponse(message, 400);
  }

  const inviteResult = await sql<InviteRow>`
    SELECT id, display_name, is_admin, claimed_at
    FROM invite_list
    WHERE email = ${email}
    LIMIT 1
  `;

  const invite = inviteResult.rows[0];
  if (!invite) {
    return errorResponse("This email is not on the guest list", 403);
  }

  if (invite.claimed_at) {
    return errorResponse(
      "This invite has already been used. Sign in instead.",
      409,
    );
  }

  const existingUser = await sql`
    SELECT id FROM users WHERE lower(trim(email)) = ${email} LIMIT 1
  `;
  if (existingUser.rows.length > 0) {
    return errorResponse(
      "An account already exists for this email. Sign in instead.",
      409,
    );
  }

  const passwordHash = await hashPassword(password);
  let userId: string | null = null;

  try {
    const userResult = await sql<{ id: string }>`
      INSERT INTO users (email, password_hash)
      VALUES (${email}, ${passwordHash})
      RETURNING id
    `;
    userId = userResult.rows[0]?.id ?? null;
    if (!userId) {
      throw new Error("Could not create user");
    }

    await sql`
      INSERT INTO profiles (
        id, email, display_name, is_admin,
        ghin_number, handicap_index, handicap_source, handicap_updated_at
      )
      VALUES (
        ${userId}, ${email}, ${invite.display_name}, ${invite.is_admin},
        ${handicap.ghinNumber}, ${handicap.handicapIndex}, ${handicap.source}, now()
      )
    `;

    await sql`
      UPDATE invite_list
      SET claimed_at = now(), user_id = ${userId}
      WHERE id = ${invite.id}
    `;

    await linkRosterOnSignup(userId, email, invite.display_name);

    const profile = await loadProfile(userId);
    if (!profile) {
      throw new Error("Could not create profile");
    }

    const token = await signToken(profile);
    return json({ token, profile: profileResponse(profile) });
  } catch (error) {
    console.error(error);
    if (userId) {
      await sql`DELETE FROM profiles WHERE id = ${userId}`;
      await sql`DELETE FROM users WHERE id = ${userId}`;
    }
    return errorResponse("Could not finish signup", 500);
  }
}

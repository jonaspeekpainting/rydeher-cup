import { sql, normalizeEmail, type UserRow } from "@/lib/db";
import { profileResponse, signToken, verifyPassword } from "@/lib/auth";
import { errorResponse, json } from "@/lib/http";
import { loadProfile } from "@/lib/profile-query";

type SigninBody = {
  email?: string;
  password?: string;
};

export async function POST(request: Request) {
  let body: SigninBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const emailRaw = body.email;
  const password = body.password;

  if (!emailRaw || !password) {
    return errorResponse("email and password are required", 400);
  }

  const email = normalizeEmail(emailRaw);

  const userResult = await sql<UserRow>`
    SELECT id, email, password_hash
    FROM users
    WHERE lower(trim(email)) = ${email}
    LIMIT 1
  `;

  const user = userResult.rows[0];
  if (!user) {
    return errorResponse("Invalid email or password", 401);
  }

  const passwordOk = await verifyPassword(password, user.password_hash);
  if (!passwordOk) {
    return errorResponse("Invalid email or password", 401);
  }

  const profile = await loadProfile(user.id);
  if (!profile) {
    return errorResponse("Profile not found", 500);
  }

  const token = await signToken(profile);
  return json({ token, profile: profileResponse(profile) });
}

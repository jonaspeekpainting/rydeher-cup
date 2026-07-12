import bcrypt from "bcryptjs";
import { SignJWT, jwtVerify } from "jose";
import { timingSafeEqual } from "crypto";
import type { ProfileRow } from "./db";
import { profileResponse } from "./profile";

export { profileResponse } from "./profile";

const TOKEN_TTL = "30d";

export type AuthClaims = {
  sub: string;
  email: string;
  isAdmin: boolean;
};

function getJwtSecret(): Uint8Array {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error("JWT_SECRET must be set to at least 32 characters");
  }
  return new TextEncoder().encode(secret);
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(
  password: string,
  passwordHash: string,
): Promise<boolean> {
  return bcrypt.compare(password, passwordHash);
}

export function verifyTournamentCode(code: string): boolean {
  const trimmed = code.trim();
  const hashFromEnv = process.env.TOURNAMENT_CODE_BCRYPT;
  const plainFromEnv = process.env.TOURNAMENT_SIGNUP_CODE;

  if (hashFromEnv) {
    return bcrypt.compareSync(trimmed, hashFromEnv);
  }

  if (plainFromEnv) {
    const a = Buffer.from(plainFromEnv);
    const b = Buffer.from(trimmed);
    if (a.length !== b.length) {
      return false;
    }
    return timingSafeEqual(a, b);
  }

  throw new Error(
    "Set TOURNAMENT_SIGNUP_CODE or TOURNAMENT_CODE_BCRYPT environment variable",
  );
}

export async function signToken(profile: ProfileRow): Promise<string> {
  return new SignJWT({
    email: profile.email,
    isAdmin: profile.is_admin,
  })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(profile.id)
    .setIssuedAt()
    .setExpirationTime(TOKEN_TTL)
    .sign(getJwtSecret());
}

export async function verifyToken(
  authorization: string | null,
): Promise<AuthClaims | null> {
  if (!authorization?.startsWith("Bearer ")) {
    return null;
  }

  const token = authorization.slice("Bearer ".length).trim();
  if (!token) {
    return null;
  }

  try {
    const { payload } = await jwtVerify(token, getJwtSecret());
    if (typeof payload.sub !== "string" || typeof payload.email !== "string") {
      return null;
    }

    return {
      sub: payload.sub,
      email: payload.email,
      isAdmin: payload.isAdmin === true,
    };
  } catch {
    return null;
  }
}

/** @deprecated use profileResponse from profile.ts — kept for call-site compatibility */
export function toProfileResponse(profile: ProfileRow) {
  return profileResponse(profile);
}

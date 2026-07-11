import { sql } from "@vercel/postgres";

export { sql };

export type InviteRow = {
  id: string;
  display_name: string;
  is_admin: boolean;
  claimed_at: string | null;
};

export type ProfileRow = {
  id: string;
  email: string;
  display_name: string;
  is_admin: boolean;
  created_at: string;
};

export type UserRow = {
  id: string;
  email: string;
  password_hash: string;
};

export type MatchRow = {
  id: string;
  label: string;
  sort_order: number;
  created_at: string;
};

export type MatchPlayerRow = {
  id: string;
  match_id: string;
  profile_id: string;
  side: string | null;
  created_at: string;
};

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

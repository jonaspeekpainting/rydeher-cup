import {
  createPool,
  type QueryResult,
  type QueryResultRow,
  type VercelPool,
} from "@vercel/postgres";

type Primitive = string | number | boolean | undefined | null;

let pool: VercelPool | null = null;

function getPool(): VercelPool {
  if (pool) {
    return pool;
  }

  const connectionString =
    process.env.POSTGRES_URL ??
    process.env.RYDEHER_POSTGRES_URL ??
    process.env.DATABASE_URL;

  if (!connectionString) {
    throw new Error(
      "Missing database URL. Set POSTGRES_URL or RYDEHER_POSTGRES_URL.",
    );
  }

  pool = createPool({ connectionString });
  return pool;
}

/** Tagged-template SQL client; uses Neon’s RYDEHER_POSTGRES_URL or POSTGRES_URL. */
export function sql<O extends QueryResultRow>(
  strings: TemplateStringsArray,
  ...values: Primitive[]
): Promise<QueryResult<O>> {
  return getPool().sql<O>(strings, ...values);
}

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

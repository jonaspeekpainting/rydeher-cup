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

export type TeamSlug = "hookers" | "slicers";

export type HandicapSource = "ghin" | "manual";

export type MatchFormat =
  | "best_ball_match"
  | "scramble"
  | "shamble"
  | "singles_match"
  | "alternate_shot";

export type ScoringVisibility = "live" | "release_on_complete";

export type MatchStatus = "setup" | "in_progress" | "complete";

export type SessionDay = "thu" | "fri" | "sat";

export type ProfileRow = {
  id: string;
  email: string;
  display_name: string;
  is_admin: boolean;
  created_at: string;
  ghin_number: string | null;
  handicap_index: string | null;
  course_handicap: number | null;
  handicap_source: HandicapSource | null;
  handicap_updated_at: string | null;
  team_id: string | null;
};

export type UserRow = {
  id: string;
  email: string;
  password_hash: string;
};

export type TeamRow = {
  id: string;
  slug: TeamSlug;
  name: string;
  created_at: string;
};

export type RosterEntryRow = {
  id: string;
  team_id: string;
  display_name: string;
  email: string | null;
  profile_id: string | null;
  sort_order: number;
  created_at: string;
};

export type CourseRow = {
  id: string;
  external_id: string;
  name: string;
  city: string | null;
  state: string | null;
  raw_payload: unknown;
  created_at: string;
  updated_at: string;
};

export type CourseTeeRow = {
  id: string;
  course_id: string;
  external_id: string | null;
  name: string;
  color: string | null;
  rating: string | null;
  slope: number | null;
  total_yardage: number | null;
  created_at: string;
};

export type CourseHoleRow = {
  id: string;
  course_id: string;
  tee_id: string | null;
  hole_number: number;
  par: number;
  stroke_index: number | null;
  yardage: number | null;
};

export type SessionRow = {
  id: string;
  day: SessionDay;
  round_number: number;
  session_date: string;
  label: string;
  sort_order: number;
  created_at: string;
};

export type MatchRow = {
  id: string;
  label: string;
  sort_order: number;
  created_at: string;
  session_id: string | null;
  format: MatchFormat | null;
  course_id: string | null;
  tee_id: string | null;
  scoring_visibility: ScoringVisibility;
  status: MatchStatus;
  playing_handicaps: unknown;
  updated_at: string;
};

export type MatchPlayerRow = {
  id: string;
  match_id: string;
  profile_id: string;
  side: TeamSlug | null;
  created_at: string;
};

export type HoleScoreRow = {
  id: string;
  match_id: string;
  hole_number: number;
  profile_id: string | null;
  side: TeamSlug | null;
  gross_strokes: number;
  updated_by: string | null;
  updated_at: string;
};

export type MatchHoleOutcomeRow = {
  id: string;
  match_id: string;
  hole_number: number;
  winner_side: TeamSlug | null;
};

export type MatchResultRow = {
  match_id: string;
  hookers_points: string;
  slicers_points: string;
  is_provisional: boolean;
  holes_won_hookers: number;
  holes_won_slicers: number;
  holes_halved: number;
  updated_at: string;
};

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

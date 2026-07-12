import type { ProfileRow, TeamSlug } from "./db";

export type ProfileResponse = {
  id: string;
  email: string;
  display_name: string;
  is_admin: boolean;
  ghin_number: string | null;
  handicap_index: number | null;
  course_handicap: number | null;
  handicap_source: string | null;
  handicap_updated_at: string | null;
  team_id: string | null;
  team_slug: TeamSlug | null;
};

export function profileResponse(
  profile: ProfileRow & { team_slug?: TeamSlug | null },
): ProfileResponse {
  return {
    id: profile.id,
    email: profile.email,
    display_name: profile.display_name,
    is_admin: profile.is_admin,
    ghin_number: profile.ghin_number ?? null,
    handicap_index:
      profile.handicap_index != null ? Number(profile.handicap_index) : null,
    course_handicap: profile.course_handicap ?? null,
    handicap_source: profile.handicap_source ?? null,
    handicap_updated_at: profile.handicap_updated_at ?? null,
    team_id: profile.team_id ?? null,
    team_slug: profile.team_slug ?? null,
  };
}

export const PROFILE_SELECT = `
  id, email, display_name, is_admin, created_at,
  ghin_number, handicap_index, course_handicap,
  handicap_source, handicap_updated_at, team_id
`;

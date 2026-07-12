import { sql, type ProfileRow, type TeamSlug } from "./db";
import { profileResponse, type ProfileResponse } from "./profile";

export type ProfileWithTeam = ProfileRow & { team_slug: TeamSlug | null };

export async function loadProfile(
  profileId: string,
): Promise<ProfileWithTeam | null> {
  const result = await sql<ProfileWithTeam>`
    SELECT
      p.id, p.email, p.display_name, p.is_admin, p.created_at,
      p.ghin_number, p.handicap_index, p.course_handicap,
      p.handicap_source, p.handicap_updated_at, p.team_id,
      t.slug AS team_slug
    FROM profiles p
    LEFT JOIN teams t ON t.id = p.team_id
    WHERE p.id = ${profileId}
    LIMIT 1
  `;
  return result.rows[0] ?? null;
}

export async function loadAllProfiles(): Promise<ProfileResponse[]> {
  const result = await sql<ProfileWithTeam>`
    SELECT
      p.id, p.email, p.display_name, p.is_admin, p.created_at,
      p.ghin_number, p.handicap_index, p.course_handicap,
      p.handicap_source, p.handicap_updated_at, p.team_id,
      t.slug AS team_slug
    FROM profiles p
    LEFT JOIN teams t ON t.id = p.team_id
    ORDER BY p.display_name ASC
  `;
  return result.rows.map(profileResponse);
}

export async function linkRosterOnSignup(
  profileId: string,
  email: string,
  displayName: string,
): Promise<void> {
  // Prefer email match on roster
  const byEmail = await sql<{ id: string; team_id: string }>`
    SELECT id, team_id FROM roster_entries
    WHERE email IS NOT NULL AND lower(trim(email)) = ${email}
    LIMIT 1
  `;

  if (byEmail.rows[0]) {
    const entry = byEmail.rows[0];
    await sql`
      UPDATE roster_entries
      SET profile_id = ${profileId}
      WHERE id = ${entry.id}
    `;
    await sql`
      UPDATE profiles SET team_id = ${entry.team_id} WHERE id = ${profileId}
    `;
    return;
  }

  // Fall back to display name match (case-insensitive) if unclaimed
  const byName = await sql<{ id: string; team_id: string }>`
    SELECT id, team_id FROM roster_entries
    WHERE profile_id IS NULL
      AND lower(trim(display_name)) = ${displayName.trim().toLowerCase()}
    LIMIT 1
  `;

  if (byName.rows[0]) {
    const entry = byName.rows[0];
    await sql`
      UPDATE roster_entries
      SET profile_id = ${profileId}, email = ${email}
      WHERE id = ${entry.id}
    `;
    await sql`
      UPDATE profiles SET team_id = ${entry.team_id} WHERE id = ${profileId}
    `;
  }
}

import { NextRequest } from "next/server";
import { sql, type RosterEntryRow, type TeamRow } from "@/lib/db";
import { profileResponse } from "@/lib/auth";
import { json } from "@/lib/http";
import { requireAuth } from "@/lib/request-auth";
import type { ProfileWithTeam } from "@/lib/profile-query";

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const teams = await sql<TeamRow>`
    SELECT * FROM teams ORDER BY slug ASC
  `;

  const out = [];
  for (const team of teams.rows) {
    const roster = await sql<
      RosterEntryRow & {
        profile_email: string | null;
        profile_is_admin: boolean | null;
        profile_ghin: string | null;
        profile_index: string | null;
        profile_ch: number | null;
        profile_source: string | null;
        profile_updated: string | null;
        profile_created: string | null;
      }
    >`
      SELECT
        re.*,
        p.email AS profile_email,
        p.is_admin AS profile_is_admin,
        p.ghin_number AS profile_ghin,
        p.handicap_index AS profile_index,
        p.course_handicap AS profile_ch,
        p.handicap_source AS profile_source,
        p.handicap_updated_at AS profile_updated,
        p.created_at AS profile_created
      FROM roster_entries re
      LEFT JOIN profiles p ON p.id = re.profile_id
      WHERE re.team_id = ${team.id}
      ORDER BY re.sort_order ASC, re.display_name ASC
    `;

    out.push({
      id: team.id,
      slug: team.slug,
      name: team.name,
      roster: roster.rows.map((row) => {
        let profile = null;
        if (row.profile_id && row.profile_email && row.profile_created) {
          const p: ProfileWithTeam = {
            id: row.profile_id,
            email: row.profile_email,
            display_name: row.display_name,
            is_admin: Boolean(row.profile_is_admin),
            created_at: row.profile_created,
            ghin_number: row.profile_ghin,
            handicap_index: row.profile_index,
            course_handicap: row.profile_ch,
            handicap_source: row.profile_source as "ghin" | "manual" | null,
            handicap_updated_at: row.profile_updated,
            team_id: team.id,
            team_slug: team.slug,
          };
          profile = profileResponse(p);
        }
        return {
          id: row.id,
          display_name: row.display_name,
          email: row.email,
          sort_order: row.sort_order,
          profile,
        };
      }),
    });
  }

  return json(out);
}

import { NextRequest } from "next/server";
import {
  sql,
  type CourseHoleRow,
  type CourseRow,
  type CourseTeeRow,
} from "@/lib/db";
import {
  fetchCourse,
  normalizeHolesForTee,
  normalizeTees,
} from "@/lib/opengolf";
import { errorResponse, json } from "@/lib/http";
import { requireAdmin, requireAuth } from "@/lib/request-auth";

type ImportBody = {
  external_id?: string;
};

export async function GET(request: NextRequest) {
  const auth = await requireAuth(request);
  if (auth instanceof Response) {
    return auth;
  }

  const courses = await sql<
    Omit<CourseRow, "raw_payload"> & { raw_payload?: undefined }
  >`
    SELECT id, external_id, name, city, state, created_at, updated_at
    FROM courses
    ORDER BY name ASC
  `;

  const out = [];
  for (const course of courses.rows) {
    const tees = await sql<CourseTeeRow>`
      SELECT * FROM course_tees WHERE course_id = ${course.id} ORDER BY name ASC
    `;
    out.push({ ...course, tees: tees.rows });
  }

  return json(out);
}

export async function POST(request: NextRequest) {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) {
    return auth;
  }

  let body: ImportBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse("Invalid JSON", 400);
  }

  const externalId = body.external_id?.trim();
  if (!externalId) {
    return errorResponse("external_id is required", 400);
  }

  let remote;
  try {
    remote = await fetchCourse(externalId);
  } catch (error) {
    console.error(error);
    return errorResponse("Could not fetch course from OpenGolfAPI", 502);
  }

  const existing = await sql<CourseRow>`
    SELECT * FROM courses WHERE external_id = ${externalId} LIMIT 1
  `;

  let courseId: string;
  if (existing.rows[0]) {
    courseId = existing.rows[0].id;
    await sql`
      UPDATE courses
      SET
        name = ${remote.name},
        city = ${remote.city ?? null},
        state = ${remote.state ?? null},
        raw_payload = ${JSON.stringify(remote)}::jsonb,
        updated_at = now()
      WHERE id = ${courseId}
    `;
    await sql`DELETE FROM course_holes WHERE course_id = ${courseId}`;
    await sql`DELETE FROM course_tees WHERE course_id = ${courseId}`;
  } else {
    const inserted = await sql<CourseRow>`
      INSERT INTO courses (external_id, name, city, state, raw_payload)
      VALUES (
        ${externalId},
        ${remote.name},
        ${remote.city ?? null},
        ${remote.state ?? null},
        ${JSON.stringify(remote)}::jsonb
      )
      RETURNING *
    `;
    courseId = inserted.rows[0]!.id;
  }

  const tees = normalizeTees(remote);
  const teeRows: CourseTeeRow[] = [];

  if (tees.length === 0) {
    const holes = normalizeHolesForTee(remote, {});
    for (const hole of holes) {
      await sql`
        INSERT INTO course_holes (course_id, tee_id, hole_number, par, stroke_index, yardage)
        VALUES (
          ${courseId}, NULL, ${hole.holeNumber}, ${hole.par},
          ${hole.strokeIndex}, ${hole.yardage}
        )
      `;
    }
  } else {
    for (const tee of tees) {
      const teeInsert = await sql<CourseTeeRow>`
        INSERT INTO course_tees (
          course_id, external_id, name, color, rating, slope, total_yardage
        )
        VALUES (
          ${courseId},
          ${tee.id != null ? String(tee.id) : null},
          ${tee.name ?? tee.color ?? "Default"},
          ${tee.color ?? null},
          ${tee.rating ?? null},
          ${tee.slope ?? null},
          ${tee.total_yardage ?? tee.yardage ?? null}
        )
        RETURNING *
      `;
      const teeRow = teeInsert.rows[0]!;
      teeRows.push(teeRow);

      const holes = normalizeHolesForTee(remote, tee);
      for (const hole of holes) {
        await sql`
          INSERT INTO course_holes (course_id, tee_id, hole_number, par, stroke_index, yardage)
          VALUES (
            ${courseId}, ${teeRow.id}, ${hole.holeNumber}, ${hole.par},
            ${hole.strokeIndex}, ${hole.yardage}
          )
        `;
      }
    }
  }

  const course = await sql<CourseRow>`
    SELECT id, external_id, name, city, state, created_at, updated_at
    FROM courses WHERE id = ${courseId} LIMIT 1
  `;
  const allTees =
    teeRows.length > 0
      ? teeRows
      : (
          await sql<CourseTeeRow>`
            SELECT * FROM course_tees WHERE course_id = ${courseId}
          `
        ).rows;
  const holes = await sql<CourseHoleRow>`
    SELECT * FROM course_holes WHERE course_id = ${courseId} ORDER BY hole_number ASC
  `;

  return json({ ...course.rows[0], tees: allTees, holes: holes.rows }, 201);
}

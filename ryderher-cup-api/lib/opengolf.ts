/**
 * OpenGolfAPI client — free US course data, no API key.
 * https://api.opengolfapi.org
 */

const OPEN_GOLF_BASE = "https://api.opengolfapi.org/v1";

export type OpenGolfSearchHit = {
  id: string;
  name: string;
  city?: string;
  state?: string;
  [key: string]: unknown;
};

export type OpenGolfTee = {
  id?: string;
  name?: string;
  color?: string;
  rating?: number;
  slope?: number;
  yardage?: number;
  total_yardage?: number;
  holes?: OpenGolfHole[];
  [key: string]: unknown;
};

export type OpenGolfHole = {
  hole?: number;
  number?: number;
  par?: number;
  handicap?: number;
  stroke_index?: number;
  yardage?: number;
  [key: string]: unknown;
};

export type OpenGolfCourse = {
  id: string;
  name: string;
  city?: string;
  state?: string;
  tees?: OpenGolfTee[];
  holes?: OpenGolfHole[];
  scorecard?: {
    tees?: OpenGolfTee[];
    holes?: OpenGolfHole[];
  };
  [key: string]: unknown;
};

export async function searchCourses(
  query: string,
): Promise<OpenGolfSearchHit[]> {
  const q = query.trim();
  if (!q) {
    return [];
  }

  const url = `${OPEN_GOLF_BASE}/courses/search?q=${encodeURIComponent(q)}`;
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
  });

  if (!response.ok) {
    throw new Error(`Course search failed (${response.status})`);
  }

  const data = (await response.json()) as unknown;
  if (Array.isArray(data)) {
    return data as OpenGolfSearchHit[];
  }
  if (
    data &&
    typeof data === "object" &&
    Array.isArray((data as { courses?: unknown }).courses)
  ) {
    return (data as { courses: OpenGolfSearchHit[] }).courses;
  }
  if (
    data &&
    typeof data === "object" &&
    Array.isArray((data as { results?: unknown }).results)
  ) {
    return (data as { results: OpenGolfSearchHit[] }).results;
  }
  return [];
}

export async function fetchCourse(externalId: string): Promise<OpenGolfCourse> {
  const url = `${OPEN_GOLF_BASE}/courses/${encodeURIComponent(externalId)}`;
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
  });

  if (!response.ok) {
    throw new Error(`Course fetch failed (${response.status})`);
  }

  return (await response.json()) as OpenGolfCourse;
}

export function normalizeTees(course: OpenGolfCourse): OpenGolfTee[] {
  const fromScorecard = course.scorecard?.tees;
  if (Array.isArray(fromScorecard) && fromScorecard.length > 0) {
    return fromScorecard;
  }
  if (Array.isArray(course.tees) && course.tees.length > 0) {
    return course.tees;
  }
  return [];
}

export function normalizeHolesForTee(
  course: OpenGolfCourse,
  tee: OpenGolfTee,
): Array<{
  holeNumber: number;
  par: number;
  strokeIndex: number | null;
  yardage: number | null;
}> {
  const holes =
    (Array.isArray(tee.holes) && tee.holes.length > 0
      ? tee.holes
      : course.scorecard?.holes) ??
    course.holes ??
    [];

  return holes
    .map((h) => {
      const holeNumber = Number(h.hole ?? h.number);
      const par = Number(h.par);
      if (!Number.isFinite(holeNumber) || !Number.isFinite(par)) {
        return null;
      }
      const strokeIndexRaw = h.stroke_index ?? h.handicap;
      const strokeIndex =
        strokeIndexRaw != null && Number.isFinite(Number(strokeIndexRaw))
          ? Number(strokeIndexRaw)
          : null;
      const yardage =
        h.yardage != null && Number.isFinite(Number(h.yardage))
          ? Number(h.yardage)
          : null;
      return { holeNumber, par, strokeIndex, yardage };
    })
    .filter((h): h is NonNullable<typeof h> => h != null)
    .sort((a, b) => a.holeNumber - b.holeNumber);
}

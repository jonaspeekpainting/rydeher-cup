/**
 * OpenGolfAPI client — free US course data, no API key.
 * https://api.opengolfapi.org
 *
 * Real payload shapes (v3):
 * - GET /v1/courses/{id} → holes is a NUMBER, scorecard is an ARRAY of {hole,par}
 * - GET /v1/courses/{id}/tees → { tees: [{ tee_key, tee_name, course_rating, slope, ... }] }
 */

const OPEN_GOLF_BASE = "https://api.opengolfapi.org/v1";

export type OpenGolfSearchHit = {
  id: string;
  name: string;
  city?: string;
  state?: string;
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

export type OpenGolfTee = {
  id?: string;
  tee_key?: string;
  tee_name?: string;
  name?: string;
  tee_color?: string;
  color?: string;
  course_rating?: number;
  rating?: number;
  slope?: number;
  yardage?: number;
  total_yardage?: number;
  gender?: string;
  holes?: OpenGolfHole[];
  [key: string]: unknown;
};

export type OpenGolfCourse = {
  id: string;
  name: string;
  city?: string;
  state?: string;
  /** Hole count (number), NOT an array of holes. */
  holes?: number | OpenGolfHole[];
  /** Often an array of hole objects; sometimes a nested object. */
  scorecard?: OpenGolfHole[] | { tees?: OpenGolfTee[]; holes?: OpenGolfHole[] };
  tees?: OpenGolfTee[];
  [key: string]: unknown;
};

export type NormalizedHole = {
  holeNumber: number;
  par: number;
  strokeIndex: number | null;
  yardage: number | null;
};

export type NormalizedTee = {
  externalId: string | null;
  name: string;
  color: string | null;
  rating: number | null;
  slope: number | null;
  totalYardage: number | null;
};

function asHoleArray(value: unknown): OpenGolfHole[] {
  if (Array.isArray(value)) {
    return value.filter(
      (item): item is OpenGolfHole =>
        item != null && typeof item === "object" && !Array.isArray(item),
    );
  }
  return [];
}

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

export async function fetchCourseTees(
  externalId: string,
): Promise<OpenGolfTee[]> {
  const url = `${OPEN_GOLF_BASE}/courses/${encodeURIComponent(externalId)}/tees`;
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
  });

  if (response.status === 404) {
    return [];
  }

  if (!response.ok) {
    throw new Error(`Course tees fetch failed (${response.status})`);
  }

  const data = (await response.json()) as unknown;
  if (Array.isArray(data)) {
    return data as OpenGolfTee[];
  }
  if (
    data &&
    typeof data === "object" &&
    Array.isArray((data as { tees?: unknown }).tees)
  ) {
    return (data as { tees: OpenGolfTee[] }).tees;
  }
  return [];
}

/** Fetch course detail + tee sets from the separate /tees endpoint. */
export async function fetchCourseWithTees(externalId: string): Promise<{
  course: OpenGolfCourse;
  tees: OpenGolfTee[];
}> {
  const [course, tees] = await Promise.all([
    fetchCourse(externalId),
    fetchCourseTees(externalId),
  ]);
  return { course, tees };
}

export function normalizeTees(
  course: OpenGolfCourse,
  remoteTees: OpenGolfTee[] = [],
): NormalizedTee[] {
  const candidates: OpenGolfTee[] = [];

  if (remoteTees.length > 0) {
    candidates.push(...remoteTees);
  } else if (Array.isArray(course.tees) && course.tees.length > 0) {
    candidates.push(...course.tees);
  } else if (
    course.scorecard &&
    typeof course.scorecard === "object" &&
    !Array.isArray(course.scorecard) &&
    Array.isArray(course.scorecard.tees)
  ) {
    candidates.push(...course.scorecard.tees);
  }

  return candidates.map((tee) => {
    const name =
      tee.tee_name ??
      tee.name ??
      tee.color ??
      tee.tee_color ??
      tee.tee_key ??
      "Default";
    const genderSuffix =
      tee.gender && typeof tee.gender === "string"
        ? ` (${tee.gender})`
        : "";
    return {
      externalId:
        tee.tee_key != null
          ? String(tee.tee_key)
          : tee.id != null
            ? String(tee.id)
            : null,
      name: `${name}${genderSuffix}`,
      color: (tee.tee_color ?? tee.color ?? null) as string | null,
      rating:
        tee.course_rating != null
          ? Number(tee.course_rating)
          : tee.rating != null
            ? Number(tee.rating)
            : null,
      slope: tee.slope != null ? Number(tee.slope) : null,
      totalYardage:
        tee.total_yardage != null
          ? Number(tee.total_yardage)
          : tee.yardage != null
            ? Number(tee.yardage)
            : null,
    };
  });
}

export function extractRawHoles(course: OpenGolfCourse): OpenGolfHole[] {
  // Preferred: scorecard is a hole array (OpenGolf v3)
  if (Array.isArray(course.scorecard)) {
    return asHoleArray(course.scorecard);
  }

  // Nested scorecard.holes
  if (
    course.scorecard &&
    typeof course.scorecard === "object" &&
    Array.isArray(course.scorecard.holes)
  ) {
    return asHoleArray(course.scorecard.holes);
  }

  // Only if holes is actually an array (never the hole-count number)
  if (Array.isArray(course.holes)) {
    return asHoleArray(course.holes);
  }

  return [];
}

export function normalizeHolesForTee(
  course: OpenGolfCourse,
  tee: OpenGolfTee | NormalizedTee | Record<string, unknown> = {},
): NormalizedHole[] {
  const teeHoles = asHoleArray(
    "holes" in tee ? (tee as { holes?: unknown }).holes : undefined,
  );
  const holes = teeHoles.length > 0 ? teeHoles : extractRawHoles(course);

  return holes
    .map((h): NormalizedHole | null => {
      const holeNumber = Number(h.hole ?? h.number);
      const par = Number(h.par);
      if (!Number.isFinite(holeNumber) || !Number.isFinite(par)) {
        return null;
      }
      const strokeIndexRaw = h.stroke_index ?? h.handicap;
      const strokeIndex =
        strokeIndexRaw != null && Number.isFinite(Number(strokeIndexRaw))
          ? Number(strokeIndexRaw)
          : holeNumber; // default SI = hole number when API omits it
      const yardage =
        h.yardage != null && Number.isFinite(Number(h.yardage))
          ? Number(h.yardage)
          : null;
      return { holeNumber, par, strokeIndex, yardage };
    })
    .filter((h): h is NormalizedHole => h != null)
    .sort((a, b) => a.holeNumber - b.holeNumber);
}

import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  extractRawHoles,
  normalizeHolesForTee,
  normalizeTees,
  type OpenGolfCourse,
} from "./opengolf";

describe("OpenGolf payload normalization", () => {
  const alpineLike: OpenGolfCourse = {
    id: "2718acba-f60e-4b4f-bd05-8d7875d376b4",
    name: "Alpine At Boyne Mountain Resort",
    city: "Boyne Falls",
    state: "MI",
    holes: 18,
    scorecard: [
      { hole: 1, par: 4 },
      { hole: 2, par: 4 },
      { hole: 3, par: 3 },
    ],
  };

  it("does not treat holes count as an array", () => {
    const holes = extractRawHoles(alpineLike);
    assert.equal(holes.length, 3);
    assert.equal(holes[0]?.par, 4);
  });

  it("normalizeHolesForTee works when holes is a number", () => {
    const holes = normalizeHolesForTee(alpineLike);
    assert.equal(holes.length, 3);
    assert.equal(holes[0]?.holeNumber, 1);
    assert.equal(holes[0]?.strokeIndex, 1);
  });

  it("normalizeTees maps /tees endpoint fields", () => {
    const tees = normalizeTees(alpineLike, [
      {
        tee_key: "orange-male",
        tee_name: "Orange",
        gender: "Male",
        course_rating: 70.3,
        slope: 131,
        yardage: 6491,
      },
    ]);
    assert.equal(tees.length, 1);
    assert.equal(tees[0]?.name, "Orange (Male)");
    assert.equal(tees[0]?.rating, 70.3);
    assert.equal(tees[0]?.slope, 131);
  });
});

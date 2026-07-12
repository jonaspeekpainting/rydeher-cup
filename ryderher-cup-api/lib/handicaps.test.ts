import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  applyEightyPercent,
  computeMatchPlayResult,
  computePlayingHandicaps,
  courseHandicapFromIndex,
  roundHalfUp,
  scrambleTeamAllowance,
  strokesOnHole,
} from "./handicaps";

describe("roundHalfUp", () => {
  it("rounds 5.2 down and 5.5 up", () => {
    assert.equal(roundHalfUp(5.2), 5);
    assert.equal(roundHalfUp(5.5), 6);
    assert.equal(roundHalfUp(6.5), 7);
  });
});

describe("applyEightyPercent", () => {
  it("applies 80% to course handicaps", () => {
    assert.equal(applyEightyPercent(10), 8);
    assert.equal(applyEightyPercent(20), 16);
  });
});

describe("scrambleTeamAllowance", () => {
  it("matches the plan example (10 and 20 → 5)", () => {
    // (10×0.35)+(20×0.15)=6.5; ×0.80=5.2 → 5
    assert.equal(scrambleTeamAllowance(10, 20), 5);
  });
});

describe("strokesOnHole", () => {
  it("gives strokes on hardest holes first", () => {
    assert.equal(strokesOnHole(3, 1), 1);
    assert.equal(strokesOnHole(3, 2), 1);
    assert.equal(strokesOnHole(3, 3), 1);
    assert.equal(strokesOnHole(3, 4), 0);
  });

  it("handles more than 18 strokes", () => {
    assert.equal(strokesOnHole(19, 1), 2);
    assert.equal(strokesOnHole(19, 18), 1);
  });
});

describe("computePlayingHandicaps best ball", () => {
  it("strokes off the best player in the field", () => {
    const snap = computePlayingHandicaps("best_ball_match", [
      { profileId: "a", side: "hookers", courseHandicap: 10 },
      { profileId: "b", side: "hookers", courseHandicap: 20 },
      { profileId: "c", side: "slicers", courseHandicap: 5 },
      { profileId: "d", side: "slicers", courseHandicap: 15 },
    ]);

    // 80%: 8, 16, 4, 12 → min 4
    assert.equal(snap.fieldMinimum, 4);
    const byId = Object.fromEntries(
      snap.players.map((p) => [p.profileId, p.relativeStrokes]),
    );
    assert.equal(byId.a, 4);
    assert.equal(byId.b, 12);
    assert.equal(byId.c, 0);
    assert.equal(byId.d, 8);
  });
});

describe("computePlayingHandicaps scramble", () => {
  it("uses team formula and field relative", () => {
    const snap = computePlayingHandicaps("scramble", [
      { profileId: "a", side: "hookers", courseHandicap: 10 },
      { profileId: "b", side: "hookers", courseHandicap: 20 },
      { profileId: "c", side: "slicers", courseHandicap: 8 },
      { profileId: "d", side: "slicers", courseHandicap: 12 },
    ]);

    const hookers = snap.sides.find((s) => s.side === "hookers")!;
    const slicers = snap.sides.find((s) => s.side === "slicers")!;
    assert.equal(hookers.allowanceStrokes, 5);
    // slicers: (8×0.35)+(12×0.15)=2.8+1.8=4.6; ×0.8=3.68 → 4
    assert.equal(slicers.allowanceStrokes, 4);
    assert.equal(snap.fieldMinimum, 4);
    assert.equal(hookers.relativeStrokes, 1);
    assert.equal(slicers.relativeStrokes, 0);
  });
});

describe("courseHandicapFromIndex", () => {
  it("uses slope/113", () => {
    // 10.0 × (113/113) = 10
    assert.equal(courseHandicapFromIndex(10, 113), 10);
  });
});

describe("computeMatchPlayResult", () => {
  it("awards the point when one side wins", () => {
    const holes = Array.from({ length: 18 }, (_, i) => ({
      holeNumber: i + 1,
      strokeIndex: i + 1,
      hookersNet: 4,
      slicersNet: 5,
    }));
    const result = computeMatchPlayResult(holes);
    assert.equal(result.hookersPoints, 1);
    assert.equal(result.slicersPoints, 0);
    assert.equal(result.isComplete, true);
    assert.equal(result.isProvisional, false);
  });

  it("detects early dormie win", () => {
    const holes = Array.from({ length: 10 }, (_, i) => ({
      holeNumber: i + 1,
      strokeIndex: i + 1,
      hookersNet: 4,
      slicersNet: 5,
    }));
    // 10 up with 8 remaining → won
    const result = computeMatchPlayResult(holes);
    assert.equal(result.holesUp, 10);
    assert.equal(result.isComplete, true);
    assert.equal(result.hookersPoints, 1);
  });
});

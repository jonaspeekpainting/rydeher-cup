import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { computeSkinsStandings, type SkinScoreEntry } from "./skins";

function entry(
  overrides: Partial<SkinScoreEntry> &
    Pick<SkinScoreEntry, "profileId" | "displayName" | "grossStrokes" | "holeNumber">,
): SkinScoreEntry {
  return {
    sessionId: "session-a",
    sessionLabel: "Thu AM",
    teamSlug: "hookers",
    ...overrides,
  };
}

describe("computeSkinsStandings", () => {
  it("awards a skin for a unique low gross", () => {
    const result = computeSkinsStandings([
      entry({
        profileId: "a",
        displayName: "Alice",
        holeNumber: 1,
        grossStrokes: 3,
      }),
      entry({
        profileId: "b",
        displayName: "Bob",
        holeNumber: 1,
        grossStrokes: 4,
        teamSlug: "slicers",
      }),
      entry({
        profileId: "c",
        displayName: "Cara",
        holeNumber: 1,
        grossStrokes: 5,
      }),
    ]);

    assert.equal(result.holes_awarded, 1);
    assert.equal(result.holes_tied_or_empty, 0);
    assert.equal(result.leaders.length, 1);
    assert.equal(result.leaders[0]!.profile_id, "a");
    assert.equal(result.leaders[0]!.skins, 1);
    assert.equal(result.awards[0]!.gross_strokes, 3);
    assert.equal(result.pot, null);
    assert.equal(result.payout_per_skin, null);
    assert.equal(result.leaders[0]!.amount, null);
  });

  it("splits a pot evenly across awarded skins", () => {
    const result = computeSkinsStandings(
      [
        entry({
          profileId: "a",
          displayName: "Alice",
          holeNumber: 1,
          grossStrokes: 3,
        }),
        entry({
          profileId: "b",
          displayName: "Bob",
          holeNumber: 1,
          grossStrokes: 4,
          teamSlug: "slicers",
        }),
        entry({
          profileId: "a",
          displayName: "Alice",
          holeNumber: 2,
          grossStrokes: 4,
        }),
        entry({
          profileId: "b",
          displayName: "Bob",
          holeNumber: 2,
          grossStrokes: 3,
          teamSlug: "slicers",
        }),
      ],
      200,
    );

    assert.equal(result.holes_awarded, 2);
    assert.equal(result.pot, 200);
    assert.equal(result.payout_per_skin, 100);
    assert.equal(result.leaders[0]!.amount, 100);
    assert.equal(result.awards[0]!.amount, 100);
  });

  it("awards no skin when low score is tied", () => {
    const result = computeSkinsStandings([
      entry({
        profileId: "a",
        displayName: "Alice",
        holeNumber: 2,
        grossStrokes: 4,
      }),
      entry({
        profileId: "b",
        displayName: "Bob",
        holeNumber: 2,
        grossStrokes: 4,
        teamSlug: "slicers",
      }),
      entry({
        profileId: "c",
        displayName: "Cara",
        holeNumber: 2,
        grossStrokes: 5,
      }),
    ]);

    assert.equal(result.holes_awarded, 0);
    assert.equal(result.holes_tied_or_empty, 1);
    assert.deepEqual(result.leaders, []);
  });

  it("scores sessions independently for the same hole number", () => {
    const result = computeSkinsStandings([
      entry({
        sessionId: "thu",
        sessionLabel: "Thu AM",
        profileId: "a",
        displayName: "Alice",
        holeNumber: 1,
        grossStrokes: 3,
      }),
      entry({
        sessionId: "thu",
        sessionLabel: "Thu AM",
        profileId: "b",
        displayName: "Bob",
        holeNumber: 1,
        grossStrokes: 4,
        teamSlug: "slicers",
      }),
      entry({
        sessionId: "fri",
        sessionLabel: "Fri AM",
        profileId: "a",
        displayName: "Alice",
        holeNumber: 1,
        grossStrokes: 5,
      }),
      entry({
        sessionId: "fri",
        sessionLabel: "Fri AM",
        profileId: "b",
        displayName: "Bob",
        holeNumber: 1,
        grossStrokes: 4,
        teamSlug: "slicers",
      }),
    ]);

    assert.equal(result.holes_awarded, 2);
    assert.equal(result.leaders.length, 2);
    assert.equal(result.leaders[0]!.skins, 1);
    assert.equal(result.leaders[1]!.skins, 1);
  });

  it("ranks leaders by skin count then name", () => {
    const result = computeSkinsStandings([
      entry({
        profileId: "b",
        displayName: "Bob",
        holeNumber: 1,
        grossStrokes: 3,
        teamSlug: "slicers",
      }),
      entry({
        profileId: "a",
        displayName: "Alice",
        holeNumber: 1,
        grossStrokes: 4,
      }),
      entry({
        profileId: "b",
        displayName: "Bob",
        holeNumber: 2,
        grossStrokes: 3,
        teamSlug: "slicers",
      }),
      entry({
        profileId: "a",
        displayName: "Alice",
        holeNumber: 2,
        grossStrokes: 5,
      }),
      entry({
        profileId: "a",
        displayName: "Alice",
        holeNumber: 3,
        grossStrokes: 3,
      }),
      entry({
        profileId: "b",
        displayName: "Bob",
        holeNumber: 3,
        grossStrokes: 4,
        teamSlug: "slicers",
      }),
    ]);

    assert.deepEqual(
      result.leaders.map((l) => [l.display_name, l.skins]),
      [
        ["Bob", 2],
        ["Alice", 1],
      ],
    );
  });
});

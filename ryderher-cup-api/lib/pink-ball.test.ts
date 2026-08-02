import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  assignedPinkBallCarrier,
  computePinkBallScore,
  pinkBallRotationOrder,
  rankPinkBallMatches,
  validatePinkBallCarrier,
} from "./pink-ball";

describe("pink ball rotation", () => {
  const pinkHoles = [
    { holeNumber: 1, carrierProfileId: "a" },
    { holeNumber: 2, carrierProfileId: "b" },
    { holeNumber: 3, carrierProfileId: "c" },
    { holeNumber: 4, carrierProfileId: "d" },
  ];

  it("builds rotation from first four holes", () => {
    assert.deepEqual(
      pinkBallRotationOrder({ playerCount: 4, pinkHoles }),
      ["a", "b", "c", "d"],
    );
  });

  it("assigns later holes from the rotation", () => {
    assert.equal(
      assignedPinkBallCarrier({
        holeNumber: 5,
        playerCount: 4,
        pinkHoles,
      }),
      "a",
    );
    assert.equal(
      assignedPinkBallCarrier({
        holeNumber: 8,
        playerCount: 4,
        pinkHoles,
      }),
      "d",
    );
  });

  it("rejects a duplicate in the opening rotation", () => {
    const result = validatePinkBallCarrier({
      holeNumber: 3,
      carrierProfileId: "a",
      playerIds: ["a", "b", "c", "d"],
      pinkHoles,
    });
    assert.equal(result.ok, false);
  });

  it("rejects the wrong carrier after the opening rotation", () => {
    const result = validatePinkBallCarrier({
      holeNumber: 5,
      carrierProfileId: "b",
      playerIds: ["a", "b", "c", "d"],
      pinkHoles,
    });
    assert.equal(result.ok, false);
  });

  it("accepts the rotation carrier on later holes", () => {
    const result = validatePinkBallCarrier({
      holeNumber: 5,
      carrierProfileId: "a",
      playerIds: ["a", "b", "c", "d"],
      pinkHoles,
    });
    assert.equal(result.ok, true);
  });
});

describe("rankPinkBallMatches", () => {
  it("ranks lowest net first among living groups", () => {
    const ranked = rankPinkBallMatches([
      {
        matchId: "m2",
        matchLabel: "Match 2",
        score: {
          total_net: 48,
          holes_counted: 12,
          balls_lost: 1,
          balls_remaining: 2,
          eliminated: false,
          hole_nets: [],
        },
      },
      {
        matchId: "m1",
        matchLabel: "Match 1",
        score: {
          total_net: 44,
          holes_counted: 12,
          balls_lost: 0,
          balls_remaining: 3,
          eliminated: false,
          hole_nets: [],
        },
      },
    ]);
    assert.equal(ranked[0]!.match_id, "m1");
    assert.equal(ranked[0]!.is_leader, true);
    assert.equal(ranked[1]!.rank, 2);
  });

  it("does not crown an eliminated group while others can still play", () => {
    const ranked = rankPinkBallMatches([
      {
        matchId: "m1",
        matchLabel: "Match 1",
        score: {
          total_net: 31,
          holes_counted: 8,
          balls_lost: 3,
          balls_remaining: 0,
          eliminated: true,
          hole_nets: [],
        },
      },
      {
        matchId: "m2",
        matchLabel: "Match 2",
        score: {
          total_net: null,
          holes_counted: 0,
          balls_lost: 0,
          balls_remaining: 3,
          eliminated: false,
          hole_nets: [],
        },
      },
    ]);
    assert.equal(ranked.find((r) => r.match_id === "m1")!.is_leader, false);
    assert.equal(ranked.find((r) => r.match_id === "m1")!.rank, null);
    assert.equal(
      ranked.every((r) => !r.is_leader),
      true,
    );
  });

  it("allows an eliminated winner only when every group is out", () => {
    const ranked = rankPinkBallMatches([
      {
        matchId: "m1",
        matchLabel: "Match 1",
        score: {
          total_net: 40,
          holes_counted: 10,
          balls_lost: 3,
          balls_remaining: 0,
          eliminated: true,
          hole_nets: [],
        },
      },
      {
        matchId: "m2",
        matchLabel: "Match 2",
        score: {
          total_net: 38,
          holes_counted: 9,
          balls_lost: 3,
          balls_remaining: 0,
          eliminated: true,
          hole_nets: [],
        },
      },
    ]);
    // Most holes finished wins when all are eliminated.
    assert.equal(ranked[0]!.match_id, "m1");
    assert.equal(ranked[0]!.is_leader, true);
  });
});

describe("computePinkBallScore", () => {
  const players = [
    { profileId: "a", relativeStrokes: 0 },
    { profileId: "b", relativeStrokes: 2 },
  ];
  const strokeIndexes = [
    { holeNumber: 1, strokeIndex: 1 },
    { holeNumber: 2, strokeIndex: 2 },
    { holeNumber: 3, strokeIndex: 3 },
    { holeNumber: 4, strokeIndex: 4 },
  ];

  it("sums carrier net scores", () => {
    const result = computePinkBallScore({
      players,
      strokeIndexes,
      pinkHoles: [
        { holeNumber: 1, carrierProfileId: "a", lost: false },
        { holeNumber: 2, carrierProfileId: "b", lost: false },
      ],
      scores: [
        { holeNumber: 1, profileId: "a", grossStrokes: 4 },
        { holeNumber: 2, profileId: "b", grossStrokes: 5 },
      ],
    });

    // a: 4 net (0 strokes), b: 5-1=4 on SI 2 (2 relative → strokes on SI 1 and 2)
    assert.equal(result.total_net, 8);
    assert.equal(result.holes_counted, 2);
    assert.equal(result.eliminated, false);
    assert.equal(result.balls_remaining, 3);
  });

  it("stops counting after the third lost ball", () => {
    const result = computePinkBallScore({
      players,
      strokeIndexes,
      pinkHoles: [
        { holeNumber: 1, carrierProfileId: "a", lost: true },
        { holeNumber: 2, carrierProfileId: "a", lost: true },
        { holeNumber: 3, carrierProfileId: "a", lost: true },
        { holeNumber: 4, carrierProfileId: "b", lost: false },
      ],
      scores: [
        { holeNumber: 1, profileId: "a", grossStrokes: 4 },
        { holeNumber: 2, profileId: "a", grossStrokes: 5 },
        { holeNumber: 3, profileId: "a", grossStrokes: 4 },
        { holeNumber: 4, profileId: "b", grossStrokes: 3 },
      ],
    });

    assert.equal(result.eliminated, true);
    assert.equal(result.balls_remaining, 0);
    assert.equal(result.holes_counted, 3);
    assert.equal(result.total_net, 13); // 4+5+4; hole 4 ignored
    assert.equal(result.hole_nets[3]!.counts, false);
  });
});

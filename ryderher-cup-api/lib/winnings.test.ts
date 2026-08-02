import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  computePlayerWinnings,
  dollarsForSidePoints,
  payoutPerSkin,
  MATCH_LOSE_DOLLARS,
  MATCH_PUSH_DOLLARS,
  MATCH_WIN_DOLLARS,
  SKINS_POT_DOLLARS,
} from "./winnings";

describe("dollarsForSidePoints", () => {
  it("maps win / push / lose", () => {
    assert.equal(dollarsForSidePoints(1), MATCH_WIN_DOLLARS);
    assert.equal(dollarsForSidePoints(0.5), MATCH_PUSH_DOLLARS);
    assert.equal(dollarsForSidePoints(0), MATCH_LOSE_DOLLARS);
  });
});

describe("payoutPerSkin", () => {
  it("splits the pot evenly", () => {
    assert.equal(payoutPerSkin(200, 4), 50);
    assert.equal(payoutPerSkin(200, 0), null);
  });
});

describe("computePlayerWinnings", () => {
  const sessions = [
    { id: "thu", label: "Thursday AM", sort_order: 1 },
    { id: "sat", label: "Saturday PM", sort_order: 6 },
  ];

  it("pays each player on a side for match outcomes and skins", () => {
    const result = computePlayerWinnings({
      sessions,
      players: [
        {
          matchId: "m1",
          sessionId: "thu",
          profileId: "alice",
          displayName: "Alice",
          teamSlug: "hookers",
          side: "hookers",
        },
        {
          matchId: "m1",
          sessionId: "thu",
          profileId: "bob",
          displayName: "Bob",
          teamSlug: "hookers",
          side: "hookers",
        },
        {
          matchId: "m1",
          sessionId: "thu",
          profileId: "cara",
          displayName: "Cara",
          teamSlug: "slicers",
          side: "slicers",
        },
        {
          matchId: "m1",
          sessionId: "thu",
          profileId: "dan",
          displayName: "Dan",
          teamSlug: "slicers",
          side: "slicers",
        },
        {
          matchId: "m2",
          sessionId: "sat",
          profileId: "alice",
          displayName: "Alice",
          teamSlug: "hookers",
          side: "hookers",
        },
        {
          matchId: "m2",
          sessionId: "sat",
          profileId: "cara",
          displayName: "Cara",
          teamSlug: "slicers",
          side: "slicers",
        },
      ],
      results: [
        {
          matchId: "m1",
          sessionId: "thu",
          hookersPoints: 1,
          slicersPoints: 0,
        },
        {
          matchId: "m2",
          sessionId: "sat",
          hookersPoints: 0.5,
          slicersPoints: 0.5,
        },
      ],
      skinsLeaders: [
        {
          profile_id: "alice",
          display_name: "Alice",
          team_slug: "hookers",
          skins: 2,
          amount: 100,
        },
        {
          profile_id: "cara",
          display_name: "Cara",
          team_slug: "slicers",
          skins: 2,
          amount: 100,
        },
      ],
      skinsSessionId: "sat",
    });

    assert.equal(result.skins_pot, SKINS_POT_DOLLARS);
    assert.equal(result.players[0]!.profile_id, "alice");
    assert.equal(result.players[0]!.match_winnings, 75); // 50 + 25
    assert.equal(result.players[0]!.skins_winnings, 100);
    assert.equal(result.players[0]!.total_winnings, 175);
    assert.deepEqual(
      result.players[0]!.by_session.map((s) => [
        s.session_label,
        s.match_winnings,
        s.skins_winnings,
        s.total_winnings,
      ]),
      [
        ["Thursday AM", 50, 0, 50],
        ["Saturday PM", 25, 100, 125],
      ],
    );

    const bob = result.players.find((p) => p.profile_id === "bob")!;
    assert.equal(bob.match_winnings, 50);
    assert.equal(bob.skins_winnings, 0);
    assert.equal(bob.total_winnings, 50);

    const cara = result.players.find((p) => p.profile_id === "cara")!;
    assert.equal(cara.match_winnings, 25); // lose Thu + push Sat
    assert.equal(cara.skins_winnings, 100);
    assert.equal(cara.total_winnings, 125);

    assert.equal(
      result.players.find((p) => p.profile_id === "dan"),
      undefined,
      "players with $0 total are omitted",
    );
  });
});

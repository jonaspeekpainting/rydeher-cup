/**
 * Whole-field skins from gross scores only (no handicap).
 * A skin is awarded when exactly one player has the lowest score on a hole.
 * Ties for low → no skin. Side-only (team-ball) scores are ignored.
 *
 * Callers should pass only scores that count (e.g. last-round singles for the cash pot).
 */

import { payoutPerSkin } from "./winnings";

export type SkinScoreEntry = {
  sessionId: string | null;
  sessionLabel: string | null;
  holeNumber: number;
  profileId: string;
  displayName: string;
  teamSlug: string | null;
  grossStrokes: number;
};

export type SkinAward = {
  session_id: string | null;
  session_label: string | null;
  hole_number: number;
  profile_id: string;
  display_name: string;
  team_slug: string | null;
  gross_strokes: number;
  /** Dollar amount for this skin when a pot is applied. */
  amount: number | null;
};

export type SkinLeader = {
  profile_id: string;
  display_name: string;
  team_slug: string | null;
  skins: number;
  /** Dollar amount when a pot is applied (`skins * payout_per_skin`). */
  amount: number | null;
};

export type SkinsStandings = {
  leaders: SkinLeader[];
  awards: SkinAward[];
  holes_awarded: number;
  holes_tied_or_empty: number;
  /** Total skins purse (e.g. $200). Null when pot not applied. */
  pot: number | null;
  /** `$pot / holes_awarded`. Null when no skins awarded or pot not applied. */
  payout_per_skin: number | null;
};

type HoleKey = string;

function holeKey(sessionId: string | null, holeNumber: number): HoleKey {
  return `${sessionId ?? "none"}:${holeNumber}`;
}

/**
 * Compute skins across the field, grouping by session + hole.
 * Pass only scores that should count (e.g. live / complete last-round singles).
 * Optionally attach a cash pot split evenly across awarded skins.
 */
export function computeSkinsStandings(
  entries: SkinScoreEntry[],
  pot: number | null = null,
): SkinsStandings {
  const byHole = new Map<HoleKey, SkinScoreEntry[]>();

  for (const entry of entries) {
    const key = holeKey(entry.sessionId, entry.holeNumber);
    const list = byHole.get(key);
    if (list) {
      list.push(entry);
    } else {
      byHole.set(key, [entry]);
    }
  }

  const awards: SkinAward[] = [];
  let holesTiedOrEmpty = 0;

  for (const scores of byHole.values()) {
    if (scores.length === 0) {
      holesTiedOrEmpty += 1;
      continue;
    }

    let best = scores[0]!.grossStrokes;
    for (const s of scores) {
      if (s.grossStrokes < best) {
        best = s.grossStrokes;
      }
    }

    const winners = scores.filter((s) => s.grossStrokes === best);
    if (winners.length !== 1) {
      holesTiedOrEmpty += 1;
      continue;
    }

    const winner = winners[0]!;
    awards.push({
      session_id: winner.sessionId,
      session_label: winner.sessionLabel,
      hole_number: winner.holeNumber,
      profile_id: winner.profileId,
      display_name: winner.displayName,
      team_slug: winner.teamSlug,
      gross_strokes: winner.grossStrokes,
      amount: null,
    });
  }

  awards.sort((a, b) => {
    const labelA = a.session_label ?? "";
    const labelB = b.session_label ?? "";
    if (labelA !== labelB) {
      return labelA.localeCompare(labelB);
    }
    return a.hole_number - b.hole_number;
  });

  const tally = new Map<
    string,
    { displayName: string; teamSlug: string | null; skins: number }
  >();

  for (const award of awards) {
    const existing = tally.get(award.profile_id);
    if (existing) {
      existing.skins += 1;
    } else {
      tally.set(award.profile_id, {
        displayName: award.display_name,
        teamSlug: award.team_slug,
        skins: 1,
      });
    }
  }

  const perSkin =
    pot != null ? payoutPerSkin(pot, awards.length) : null;

  if (perSkin != null) {
    for (const award of awards) {
      award.amount = perSkin;
    }
  }

  const leaders: SkinLeader[] = [...tally.entries()]
    .map(([profileId, row]) => ({
      profile_id: profileId,
      display_name: row.displayName,
      team_slug: row.teamSlug,
      skins: row.skins,
      amount: perSkin != null ? row.skins * perSkin : null,
    }))
    .sort((a, b) => {
      if (b.skins !== a.skins) {
        return b.skins - a.skins;
      }
      return a.display_name.localeCompare(b.display_name);
    });

  return {
    leaders,
    awards,
    holes_awarded: awards.length,
    holes_tied_or_empty: holesTiedOrEmpty,
    pot,
    payout_per_skin: perSkin,
  };
}

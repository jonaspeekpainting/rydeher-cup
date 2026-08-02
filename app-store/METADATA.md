# App Store Connect — paste-ready metadata

Use these values in **App Information** and **Version** screens. Edit the support email / privacy URL once you host the privacy page.

---

## App Information

| Field | Value |
|-------|--------|
| **Name** | Ryde-Her Cup |
| **Subtitle** (30 chars max) | Tournament scores & matchups |
| **Bundle ID** | `jobsuite.ryderher-cup` |
| **SKU** | `rydeher-cup-2026` |
| **Primary Language** | English (U.S.) |
| **Category (Primary)** | Sports |
| **Category (Secondary)** | Lifestyle (optional) |
| **Content Rights** | No — you do not use third-party content you don’t own rights to |
| **Age Rating** | Complete questionnaire → expect **4+** (no unrestricted web, no gambling UI beyond friendly skins tracking, no mature content) |

### Age Rating questionnaire hints

- Unrestricted web access: **No**
- Gambling / contests: **No** (skins/winnings are informational for your private group, not real-money gambling in-app)
- Violence / horror / mature: **No**
- Contests: choose the option that fits “user-generated / private tournament” if asked — this is not a public betting app

---

## Version 1.0 — What’s New

```
Welcome to Ryde-Her Cup — live cup standings, matchups, hole-by-hole scoring, and skins for the crew.
```

---

## Description (4000 chars max)

```
Ryde-Her Cup is the companion app for the Ryde-Her Cup golf tournament.

Follow Hookers vs Slicers cup standings in real time, see who’s playing whom, and enter scores hole by hole from the course. Admins can set pairings and manage sessions; players get a clean scoreboard, match details, and skins / winnings tracking for the weekend.

Built for the Ryde-Her Cup crew — invite-only signup with your tournament code.

FEATURES
• Live cup scoreboard (Hookers vs Slicers)
• Match ups by session and round
• Hole-by-hole score entry and scorecards
• Skins and player winnings leaderboards
• Player roster and team views
• Optional Face ID / Touch ID lock
• Admin tools for pairings and match control

Access requires an invitation and tournament code from the organizer.
```

---

## Keywords (100 characters max, comma-separated, no spaces after commas preferred)

```
golf,tournament,ryder,cup,scoreboard,matchup,skins,handicap,ghin,scoring,boyne
```

(Character count: 90 — leave room if you tweak.)

---

## Support & Marketing URLs

| Field | Suggested value |
|-------|-----------------|
| **Support URL** | `https://rydeher-cup.vercel.app/support/` (after deploy; replace `YOUR_SUPPORT_EMAIL` in the HTML first) |
| **Marketing URL** | Optional — leave blank |
| **Privacy Policy URL** | `https://rydeher-cup.vercel.app/privacy/` (**required**; replace `YOUR_SUPPORT_EMAIL` before deploy) |

---

## App Review Information

Apple reviewers need to sign in. Create a dedicated invite + account on production before submitting.

| Field | Value |
|-------|--------|
| **Sign-in required?** | Yes |
| **Demo username (email)** | `appstore.review@rydeher.cup` |
| **Demo password** | `ReviewCup2026!` |
| **Notes** | See `REVIEW_NOTES.md` — create user with `seed-appstore-reviewer.sql` |

---

## Pricing

- **Price:** Free
- **Availability:** All countries you care about (or United States only if this is a private crew app — still fine to list US-only)

---

## Copyright

```
© 2026 Ryde-Her Cup
```

(Or use your legal name / LLC if you have one.)

# App Review notes (paste into App Store Connect)

```
Ryde-Her Cup is a private, invite-only golf tournament companion for a small group (Hookers vs Slicers).

SIGN IN
• Use the demo account credentials provided in App Review Information.
• The account is already on the invite list and claimed; no tournament signup code is needed to sign in.

WHAT TO TRY
1. Scoreboard — cup standings (Hookers vs Slicers), sessions, skins / winnings if populated.
2. Match Ups — browse rounds and open a match.
3. Players — roster / teams.
4. Open a match and view hole scores / scorecard.
5. Settings — optional biometric lock (Face ID / Touch ID). Permission string explains unlock only.

NOTES
• Signup is invite-only (email must be on the guest list + tournament code). Please use the provided demo sign-in rather than creating a new account.
• The app requires network access to https://rydeher-cup.vercel.app.
• No in-app purchases, no ads, no user-generated public social feed.
• “Skins” / “winnings” are informational leaderboards for our private group weekend — not real-money gambling or payments inside the app.
```

## Demo credentials (App Review Information)

| Field | Value |
|-------|--------|
| **Email** | `appstore.review@rydeher.cup` |
| **Password** | `ReviewCup2026!` |

SQL to create this user on production: [`seed-appstore-reviewer.sql`](./seed-appstore-reviewer.sql)

1. Run that file in Neon SQL Editor.
2. Sign in once against production to confirm.
3. Paste the email/password into App Store Connect → App Review Information.
4. Optionally pre-load a couple of matches/scores so the scoreboard isn’t empty for reviewers.

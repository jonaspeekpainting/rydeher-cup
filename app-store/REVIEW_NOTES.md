# App Review notes (paste into App Store Connect)

```
Ryde-Her Cup is a private, invite-only golf tournament companion for a small group (Hookers vs Slicers).

SIGN IN
• Use the demo account credentials provided in App Review Information.
• The account is already on the invite list and claimed; no tournament signup code is needed to sign in.

ACCOUNT DELETION (Guideline 5.1.1(v))
The app includes in-app account deletion. It permanently removes the login and profile (not a temporary deactivation).

How to review:
1. Sign in with the demo account.
2. Open Scoreboard → tap the gear (Settings).
3. Scroll to Account → Delete Account.
4. Confirm in the dialog. The account is deleted immediately and you are signed out, then shown “Account deleted.”

After deletion the same demo email is unclaimed. Re-run seed-appstore-reviewer.sql on production if you need the demo login again. You do not need to recreate the account to finish this review.

WHAT TO TRY
1. Scoreboard — cup standings (Hookers vs Slicers), sessions, skins / winnings if populated.
2. Match Ups — browse rounds and open a match.
3. Players — roster / teams.
4. Open a match and view hole scores / scorecard.
5. Settings — optional biometric lock (Face ID / Touch ID). Permission string explains unlock only.
6. Settings → Delete Account — complete deletion flow (see above).

NOTES
• Signup is invite-only (email must be on the guest list + tournament code). Please use the provided demo sign-in rather than creating a new account, unless you are re-testing after deleting the demo account.
• The app requires network access to https://rydeher-cup.vercel.app.
• No in-app purchases, no ads, no user-generated public social feed.
• “Skins” / “winnings” are informational leaderboards for our private group weekend — not real-money gambling or payments inside the app.
```

## Reply to App Review (Resolution Center)

Paste this when you resubmit, and attach the device screen recording in **App Review Information → Notes** (and/or the Resolution Center reply):

```
Account deletion is now available in-app (Guideline 5.1.1(v)).

Demo account: appstore.review@rydeher.cup / ReviewCup2026!

Flow on device:
1. Sign in with the demo account.
2. Scoreboard → gear icon (Settings).
3. Account → Delete Account → confirm.
4. The account is permanently deleted (login + profile removed from our servers). The app signs out and shows “Account deleted.”

This is not a temporary deactivation. No email, phone, or customer-service step is required.

A screen recording of this flow on a physical device is attached in App Review Information.
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

If a reviewer (or you) deletes the demo account while testing, run `seed-appstore-reviewer.sql` again before the next submission.

## Screen recording for App Review

Apple asked for a recording on a **physical device** showing sign-in, navigating to Delete Account, and the full flow through confirmation.

1. Install the new build via TestFlight (or a Release run) on an iPhone.
2. Sign out if needed, then sign in with the demo account.
3. Record (Control Center → Screen Recording, or QuickTime).
4. Gear → Settings → Delete Account → Delete Account in the confirmation dialog.
5. Wait until the “Account deleted” alert appears. Stop recording.
6. Re-seed the demo account (`seed-appstore-reviewer.sql`) so the reviewer still has a login.
7. Upload the recording in App Store Connect → App Review Information → Notes.

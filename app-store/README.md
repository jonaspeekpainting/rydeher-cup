# Ryde-Her Cup → App Store (step by step)

Work top to bottom. Files in this folder (`app-store/`) are paste-ready copy and assets.

---

## 0. What I already prepared for you

| Item | Location |
|------|----------|
| Paste-ready listing copy | [`METADATA.md`](./METADATA.md) |
| Privacy Policy HTML | [`privacy-policy.html`](./privacy-policy.html) + hosted at API `/privacy/` |
| Support page | API `/support/` |
| Reviewer notes | [`REVIEW_NOTES.md`](./REVIEW_NOTES.md) |
| Screenshot guide | [`SCREENSHOTS.md`](./SCREENSHOTS.md) |
| 1024 icon copy | [`app-icon-1024.png`](./app-icon-1024.png) |
| Release builds hit production API | `AppSecrets.swift` (`#if DEBUG` local / `#else` Vercel) |
| Encryption export answer | `ITSAppUsesNonExemptEncryption = NO` in Xcode target |

**You still must:** put a real support email in the privacy/support pages, deploy the API, create a reviewer login, take screenshots, archive & upload in Xcode.

---

## 1. Finish App Store Connect “New App”

If you already started this:

1. **Platforms:** iOS  
2. **Name:** `Ryde-Her Cup`  
3. **Primary Language:** English (U.S.)  
4. **Bundle ID:** `jobsuite.ryderher-cup`  
   - If it’s missing in the dropdown: [Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → App IDs → App → Bundle ID **Explicit** = `jobsuite.ryderher-cup` → capabilities: none required beyond defaults (Sign in with Apple **not** used).  
5. **SKU:** `rydeher-cup-2026`  
6. **User Access:** Full Access (unless you have a team)

---

## 2. Host Privacy + Support URLs (required)

App Store Connect will reject without a working **Privacy Policy URL**.

1. Open `ryderher-cup-api/public/privacy/index.html` and `…/support/index.html`.  
2. Replace **every** `YOUR_SUPPORT_EMAIL` with your real email.  
3. Deploy the API to Vercel (same project as `https://rydeher-cup.vercel.app`).  
4. Confirm in a browser:
   - https://rydeher-cup.vercel.app/privacy/
   - https://rydeher-cup.vercel.app/support/
5. In App Store Connect → **App Information**:
   - Privacy Policy URL → `https://rydeher-cup.vercel.app/privacy/`
   - (Version page) Support URL → `https://rydeher-cup.vercel.app/support/`

Also confirm production env on Vercel: `POSTGRES_URL`, `JWT_SECRET`, `TOURNAMENT_SIGNUP_CODE`, migrations applied.

---

## 3. Fill App Information & Age Rating

In Connect → your app → **App Information** / **Age Ratings**:

- Category: **Sports** (secondary optional: Lifestyle)  
- Copyright: `© 2026 Ryde-Her Cup`  
- Complete the age rating questionnaire (expect **4+**) — see hints in `METADATA.md`  
- Content Rights: you own the branding / don’t use unlicensed third-party content  

---

## 4. Create version 1.0 listing

**Distribution** → iOS version **1.0** (or create if needed):

Paste from [`METADATA.md`](./METADATA.md):

- Subtitle  
- Description  
- Keywords  
- What’s New  
- Support URL  
- Marketing URL (optional)

**App Review Information:** paste from [`REVIEW_NOTES.md`](./REVIEW_NOTES.md) and add demo email/password after you create the account (step 6).

**Pricing:** Free → set availability (US-only is fine for a private crew app).

---

## 5. Screenshots

Follow [`SCREENSHOTS.md`](./SCREENSHOTS.md).

Minimum: one iPhone size set (prefer **6.9"**). Add iPad if you keep universal.

Upload under the 1.0 version → **Previews and Screenshots**.

---

## 6. Production readiness checklist (before archive)

- [ ] Vercel API healthy; sign-in works on a device/TestFlight against production  
- [ ] Privacy & support URLs load over HTTPS  
- [ ] Invite list + tournament code work for real users  
- [ ] **App Review demo account** created and tested (see `REVIEW_NOTES.md`)  
- [ ] Scoreboard not empty for reviewers (seed a few matches if needed)  
- [ ] Xcode **Signing & Capabilities**: Team `A63X8DTK38`, automatically manage signing, Bundle ID matches  
- [ ] Version **1.0** / Build **1** (bump build number for every upload)  
- [ ] Run on a real device once with a **Release** configuration or TestFlight

---

## 7. Archive & upload from Xcode

1. Select scheme **ryderher-cup**, destination **Any iOS Device (arm64)**.  
2. Menu **Product → Archive**.  
3. Organizer → **Distribute App** → **App Store Connect** → Upload.  
4. Wait for processing (email / Connect → TestFlight).  

Optional but smart: enable **TestFlight** internal testing, install on your phone, verify production API + Face ID string, then submit.

---

## 8. Submit for review

In Connect → version 1.0:

1. Select the processed build.  
2. Confirm Export Compliance (should be answered by Info.plist → **No** non-exempt encryption).  
3. Answer Content Rights / Advertising Identifier if asked (**no** tracking ads).  
4. **Add for Review** → **Submit to App Review**.

Typical first review: ~24–48 hours (can vary).

---

## 9. After approval

- App goes **Ready for Sale** (or you can set a manual release date).  
- Share the App Store link with the crew.  
- For every future upload: bump `CURRENT_PROJECT_VERSION` (build), optionally `MARKETING_VERSION`.

---

## Common rejection traps for this app

| Risk | Fix |
|------|-----|
| Reviewer can’t sign up / sign in | Dedicated demo account + clear notes |
| Empty app / “incomplete” | Seed standings & matches on production |
| Privacy URL missing/broken | Deploy `/privacy/` before submit |
| Crash on launch | Release build must use Vercel URL (already wired) |
| “Hookers” team name flagged | Unlikely for sports context; review notes explain private tournament teams |
| Missing Face ID purpose string | Already set in project |

---

## Quick field cheat sheet

```
Name:           Ryde-Her Cup
Bundle ID:      jobsuite.ryderher-cup
SKU:            rydeher-cup-2026
Privacy URL:    https://rydeher-cup.vercel.app/privacy/
Support URL:    https://rydeher-cup.vercel.app/support/
Category:       Sports
Price:          Free
```

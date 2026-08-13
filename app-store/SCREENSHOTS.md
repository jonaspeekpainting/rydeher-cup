# Screenshots & media

App Store Connect requires screenshots for at least one iPhone size. The app is **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`), so iPad screenshots are not required.

## Required sizes (2026)

Capture from Simulator → **File → Save Screen** (or ⌘S), then upload the PNGs.

| Device class | Simulator to pick | Size |
|--------------|-------------------|------|
| **iPhone 6.9"** (required tier) | iPhone 16 Pro Max / 15 Pro Max | **1320 × 2868** or **1290 × 2796** |
| **iPhone 6.5"** (often still accepted) | iPhone 11 Pro Max / Xs Max | **1242 × 2688** |

Portrait is fine — the app is primarily portrait.

## Ready to upload

Folder: [`screenshots/`](./screenshots/)

Your three captures were `470×1024` (Simulator window shots). They’ve been resized to exact App Store sizes:

| Screen | 6.9" (upload these first) | 6.5" (backup) |
|--------|---------------------------|---------------|
| Scoreboard | `scoreboard-iphone-6.9-1320x2868.png` | `scoreboard-iphone-6.5-1284x2778.png` |
| Match Ups | `match-ups-iphone-6.9-1320x2868.png` | `match-ups-iphone-6.5-1284x2778.png` |
| Players | `players-iphone-6.9-1320x2868.png` | `players-iphone-6.5-1284x2778.png` |

In Connect, open the **iPhone 6.9"** screenshot slot and drop the three `*-6.9-*` files in order: Scoreboard → Match Ups → Players.

### iPad 13" (if Connect still asks)

Your project is iPhone-only, but Connect may still require iPad shots until an iPhone-only build is selected. Use these (phone UI letterboxed on iPad canvas):

| Screen | File |
|--------|------|
| Scoreboard | `scoreboard-ipad-13-2064x2752.png` |
| Match Ups | `match-ups-ipad-13-2064x2752.png` |
| Players | `players-ipad-13-2064x2752.png` |

Upload under **iPadOS 13" Display**.

**Sharper next time:** use Simulator **File → Save Screen** on an **iPhone 16 Pro Max** (not macOS ⌘⇧4 on the window). Upscaled shots can look a bit soft.

## Suggested shot list (3–6 screens)

1. **Welcome** — logo + Create account / Sign in (brand-first)
2. **Scoreboard** — Hookers vs Slicers cup standings hero ✅
3. **Match Ups** — session list or live match row ✅
4. **Match detail / scorecard** — hole-by-hole
5. **Players** — roster / teams ✅
6. **Skins or winnings** (if data seeded) — optional 6th

Use a **Release** or TestFlight build against production (or a seeded staging DB) so screens aren’t empty.

## App icon

Already prepared:

- Xcode: `ryderher-cup/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024)
- Copy for upload reference: `app-store/app-icon-1024.png`

App Store pulls the icon from your binary; you don’t upload it separately in Connect anymore for most flows — just ensure the asset catalog icon is clean (no alpha issues; yours is opaque purple).

## Optional: App Preview video

Skip for v1 unless you want one. Not required.

# Screenshots & media

App Store Connect requires screenshots for at least one iPhone size. iPad is recommended because the project targets iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`).

## Required sizes (2026)

Capture from Simulator → **File → Save Screen** (or ⌘S), then upload the PNGs.

| Device class | Simulator to pick | Size |
|--------------|-------------------|------|
| **iPhone 6.9"** (required tier) | iPhone 16 Pro Max / 15 Pro Max | **1320 × 2868** or **1290 × 2796** |
| **iPhone 6.5"** (often still accepted) | iPhone 11 Pro Max / Xs Max | **1242 × 2688** |
| **iPad 13"** (if you keep iPad support) | iPad Pro 13-inch | **2064 × 2752** |

Portrait is fine — the app is primarily portrait.

## Suggested shot list (3–6 screens)

1. **Welcome** — logo + Create account / Sign in (brand-first)
2. **Scoreboard** — Hookers vs Slicers cup standings hero
3. **Match Ups** — session list or live match row
4. **Match detail / scorecard** — hole-by-hole
5. **Players** — roster / teams
6. **Skins or winnings** (if data seeded) — optional 6th

Use a **Release** or TestFlight build against production (or a seeded staging DB) so screens aren’t empty.

## App icon

Already prepared:

- Xcode: `ryderher-cup/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024)
- Copy for upload reference: `app-store/app-icon-1024.png`

App Store pulls the icon from your binary; you don’t upload it separately in Connect anymore for most flows — just ensure the asset catalog icon is clean (no alpha issues; yours is opaque purple).

## Optional: App Preview video

Skip for v1 unless you want one. Not required.

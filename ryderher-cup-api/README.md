# Ryde-Her Cup API

Next.js API for the Ryde-Her Cup iOS app (Neon Postgres + JWT auth).

## Setup

### Local (recommended for app testing)

1. Copy env: `cp .env.example .env.local`
2. Start Postgres + migrate + seed:
   ```bash
   npm install
   npm run db:reset
   npm run dev
   ```
3. Point the iOS app at `http://127.0.0.1:3000` (already set in `AppSecrets.swift` for local).

**Seeded logins** (password `password123` for all):

| Email | Role |
|-------|------|
| `jonas@rydeher.local` | Admin, Hookers (in live matches) |
| `tyler@rydeher.local` | Player, Hookers |
| `dylan@rydeher.local` | Player, Slicers |

Re-seed anytime with `npm run db:seed`. Full wipe: `npm run db:reset`.

### Hosted Neon

1. Set env vars (see `.env.example`):
   - `POSTGRES_URL` / `RYDEHER_POSTGRES_URL`
   - `JWT_SECRET` (32+ chars)
   - `TOURNAMENT_SIGNUP_CODE`
   - Optional: `GHIN_API_BASE_URL` + `GHIN_API_TOKEN` for official handicap lookup

2. Run migrations in Neon SQL Editor, in order:
   - `migrations/001_initial_schema.sql`
   - `migrations/003_tournament_domain.sql`
   - `migrations/004_pink_ball.sql`
   - `migrations/005_roster_player_updates.sql`
   - `migrations/006_ghin_handicap_backfill.sql`
   - `migrations/007_pink_ball_loss_count.sql`
   - `migrations/008_account_deletion_fks.sql`
   - Seed invites from `migrations/002_seed_invites.example.sql`

3. `npm install && npm run dev`

## Scripts

- `npm run dev` — local API
- `npm run db:up` / `db:migrate` / `db:seed` / `db:reset` — local Postgres
- `npm test` — handicap engine unit tests
- `npm run build` — production build

## Main endpoints

| Method | Path | Notes |
|--------|------|--------|
| POST | `/api/auth/signup` | invite + tournament code (GHIN copied from invite if present) |
| POST | `/api/auth/signin` | |
| GET | `/api/auth/me` | |
| DELETE | `/api/auth/account` | permanently delete the signed-in account |
| GET/PATCH | `/api/profiles`, `/api/profiles/me`, `/api/profiles/:id` | |
| GET | `/api/teams` | Hookers / Slicers roster |
| GET | `/api/sessions` | 6 tournament rounds |
| GET/POST | `/api/matches` | list / create one match (admin) |
| POST | `/api/matches/bulk` | create 5 or 10 session pairings at once (admin) |
| GET/PATCH | `/api/matches/:id` | detail with score visibility rules |
| POST | `/api/matches/:id/start` | snapshot handicaps, start |
| POST | `/api/matches/:id/complete` | admin complete |
| PUT | `/api/matches/:id/holes/:n` | participant score entry (+ optional `pink_ball` on best ball) |
| GET | `/api/standings` | cup scoreboard, Saturday PM singles skins ($200 pot), player winnings by round |
| GET | `/api/courses/search` | OpenGolfAPI proxy |
| GET/POST | `/api/courses` | list / import course (admin) |

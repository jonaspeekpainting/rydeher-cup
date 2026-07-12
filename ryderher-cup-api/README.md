# Ryde-Her Cup API

Next.js API for the Ryde-Her Cup iOS app (Neon Postgres + JWT auth).

## Setup

1. Set env vars (see `.env.example`):
   - `POSTGRES_URL` / `RYDEHER_POSTGRES_URL`
   - `JWT_SECRET` (32+ chars)
   - `TOURNAMENT_SIGNUP_CODE`
   - Optional: `GHIN_API_BASE_URL` + `GHIN_API_TOKEN` for official handicap lookup

2. Run migrations in Neon SQL Editor, in order:
   - `migrations/001_initial_schema.sql`
   - `migrations/003_tournament_domain.sql`
   - Seed invites from `migrations/002_seed_invites.example.sql`

3. `npm install && npm run dev`

## Scripts

- `npm run dev` — local API
- `npm test` — handicap engine unit tests
- `npm run build` — production build

## Main endpoints

| Method | Path | Notes |
|--------|------|--------|
| POST | `/api/auth/signup` | invite + code + GHIN (+ manual index fallback) |
| POST | `/api/auth/signin` | |
| GET | `/api/auth/me` | |
| GET/PATCH | `/api/profiles`, `/api/profiles/me`, `/api/profiles/:id` | |
| GET | `/api/teams` | Hookers / Slicers roster |
| GET | `/api/sessions` | 6 tournament rounds |
| GET/POST | `/api/matches` | list / create (admin) |
| GET/PATCH | `/api/matches/:id` | detail with score visibility rules |
| POST | `/api/matches/:id/start` | snapshot handicaps, start |
| POST | `/api/matches/:id/complete` | admin complete |
| PUT | `/api/matches/:id/holes/:n` | participant score entry |
| GET | `/api/standings` | cup scoreboard |
| GET | `/api/courses/search` | OpenGolfAPI proxy |
| GET/POST | `/api/courses` | list / import course (admin) |

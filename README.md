# BrainDuel

A real-time 1v1 quiz battle game built with Flutter and Node.js. Players compete head-to-head answering trivia questions across multiple topics, using special abilities to gain an edge over their opponent.

---

## Features

- **Live 1v1 matchmaking** — instant pairing via Socket.io
- **7-round matches** — 6 standard rounds (10s) + 1 bonus round (15s, 2× multiplier)
- **10 quiz topics** — General Knowledge, History, Geography, Gaming, Music, Technology, TV Series, Football, Tennis, Basketball
- **Bilingual** — Romanian and English question banks (1300+ questions)
- **6 in-game abilities** — 50/50, Time Boost, Sabotage, Double Down, Shield, Reveal
- **Progression system** — XP, coins, levels, win/loss stats
- **Auth** — Google, Apple, and Email/Password sign-in

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart), Riverpod, GoRouter |
| Backend | Node.js, Express, Socket.io |
| Database | Cloud Firestore |
| Auth | Firebase Authentication |
| Deployment | Render.com (backend) |

---

## Project Structure

```
BrainDuel/
├── app/                    # Flutter mobile app
│   └── lib/
│       ├── core/           # Routing, theme, constants, i18n
│       ├── features/       # auth, game, home, leaderboard, profile, shop
│       └── shared/         # Shared models and widgets
├── server/                 # Node.js game server
│   └── src/
│       ├── game/           # Room logic, abilities, scoring
│       ├── matchmaking/    # Player queue and pairing
│       ├── questions/      # Question bank and CRUD service
│       ├── socket/         # Socket.io event handlers
│       ├── routes/         # Admin REST API
│       └── middleware/     # Admin auth
├── firebase/               # Firestore rules and indexes
├── scripts/                # Firebase deployment helpers
└── tests/                  # Integration tests
```

---

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [Flutter](https://flutter.dev/) 3.x
- [Firebase project](https://console.firebase.google.com/) with Firestore and Auth enabled
- Xcode (for iOS builds)

### Server

```bash
cd server
cp .env.example .env   # Fill in your Firebase credentials
npm install
npm run dev            # Starts on http://localhost:3001
```

Set `SKIP_AUTH=true` in `.env` to run without Firebase verification (useful for local testing).

### Flutter App

```bash
cd app
flutter pub get
flutter run            # Run on a connected device or simulator
```

### Firebase (Firestore rules & indexes)

```bash
node scripts/firebase-setup.js
# or manually:
cd firebase && firebase deploy --only firestore
```

---

## Environment Variables

Create `server/.env` from the provided example:

```env
PORT=3001
SKIP_AUTH=true
ADMIN_SECRET=brainduel_admin
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-service-account@...
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
```

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for step-by-step Firebase configuration.

---

## Game Rules

### Scoring

Each round awards up to **20 points**, minus 1 point per second elapsed. Minimum score for a correct answer is **11 points**. Wrong or timed-out answers score 0.

The bonus round (round 7) runs for 15 seconds and doubles all points earned.

**Match rewards:**

| Result | XP | Coins |
|---|---|---|
| Win | 100 | 50 |
| Draw | 50 | 25 |
| Loss | 25 | 10 |

### Abilities

Each ability can be used once per match:

| Ability | Effect |
|---|---|
| 50/50 | Removes 2 incorrect answers |
| Time Boost | Reduces your elapsed time by 4 seconds |
| Sabotage | Adds 3 seconds to opponent's elapsed time (blocked by Shield) |
| Double Down | Doubles points earned this round |
| Shield | Blocks the next Sabotage used against you |
| Reveal | Shows a visual hint toward the correct answer |

---

## Admin API

All endpoints require the `x-admin-secret` header matching `ADMIN_SECRET`.

```
GET  /admin/api/stats                          Server metrics
GET  /admin/api/questions                      List questions (filter: topic, language, difficulty)
GET  /admin/api/questions/:id                  Get single question
POST /admin/api/questions                      Add question
PUT  /admin/api/questions/:id                  Update question
DELETE /admin/api/questions/:id                Delete question
```

Health check (no auth required): `GET /health`

---

## Tests

```bash
cd server
npm test              # Run integration tests
npm run test:verbose  # Verbose output
```

---

## Roadmap

- [x] Phase 1 — Core 1v1 game loop
- [ ] Phase 2 — Ability selection UI, cosmetics shop
- [ ] Phase 3 — Leaderboards, friends, daily challenges
- [ ] Phase 4 — Team modes (2v2, 3v3)
- [ ] Phase 5 — Android and web deployment

---

## License

MIT

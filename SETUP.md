# BrainDuel — Setup Guide

## Project Structure

```
QuizGame/
├── server/     Node.js game server (Socket.io + Express)
└── app/        Flutter mobile app (iOS first, Android later)
```

---

## 1. Server Setup

### Prerequisites
- Node.js 18+ (already installed)

### Run in development mode
```bash
cd server
cp .env.example .env
npm install
npm run dev       # nodemon hot-reload
# or
npm start         # production
```

Server starts on **http://localhost:3001**

The server works out of the box with `SKIP_AUTH=true` (default).  
For production, set up Firebase Admin credentials in `.env`.

---

## 2. Flutter App Setup

### Prerequisites
1. Install Flutter SDK: https://docs.flutter.dev/get-started/install/macos
2. Install Xcode (for iOS)
3. Run `flutter doctor` to verify setup

### Run the app
```bash
cd app
flutter pub get
flutter run             # runs on connected device/simulator
flutter run -d chrome   # runs in browser (for quick testing)
```

---

## 3. Firebase Setup (Required for Auth + Database)

### Create Firebase Project
1. Go to https://console.firebase.google.com
2. Create a new project named "brainduel"
3. Enable these services:

**Authentication:**
- Authentication → Sign-in method → Enable:
  - Apple (requires Apple Developer account)
  - Google
  - Email/Password

**Firestore Database:**
- Firestore Database → Create database → Start in test mode
- Create collection: `users`

### iOS App (Firebase)
1. In Firebase Console → Project Settings → Add app → iOS
2. Bundle ID: `com.brainduel.app`
3. Download `GoogleService-Info.plist`
4. Place it at: `app/ios/Runner/GoogleService-Info.plist`

### Server (Firebase Admin)
1. Project Settings → Service accounts → Generate new private key
2. Download the JSON file
3. Fill in `.env`:
```
FIREBASE_PROJECT_ID=brainduel-xxxxx
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxx@brainduel.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
SKIP_AUTH=false
```

---

## 4. Firestore Data Model

```
users/{uid}
  displayName: string
  email: string
  level: number (starts at 1)
  xp: number (starts at 0)
  coins: number (starts at 100)
  avatarId: string (default: 'default')
  selectedAbilities: array ['fifty_fifty', 'time_boost']
  stats:
    wins: number
    losses: number
    draws: number
    totalGames: number
  createdAt: timestamp
```

---

## 5. Game Flow

```
Player opens app
  → Login (Apple / Google / Email)
  → Home Screen (topic grid + Quick Match)
  → Select topic → Matchmaking screen
  → Server pairs 2 players
  → Game starts (7 rounds)
     Round 1–6: 10 seconds, max 20 pts
     Round 7 (Bonus): 15 seconds, max 40 pts
  → Results screen (XP + coins awarded)
```

---

## 6. Connect App to Local Server

In `app/lib/core/constants/constants.dart`:
```dart
static const String serverUrl = 'http://localhost:3001'; // dev
// static const String serverUrl = 'https://api.brainduel.app'; // prod
```

For iOS Simulator connecting to local server: `localhost` works.  
For physical iPhone: use your Mac's local IP (e.g., `http://192.168.1.x:3001`).

---

## 7. Topics Available

| ID | Romanian | English |
|---|---|---|
| general_knowledge | Cultură Generală | General Knowledge |
| history | Istorie | History |
| geography | Geografie | Geography |
| gaming | Jocuri Video | Video Games |
| music | Muzică | Music |
| technology | Tehnologie | Technology |
| tv_series | Seriale | TV Series |

---

## 8. Abilities

| Ability | Effect |
|---|---|
| `fifty_fifty` | Removes 2 wrong answers |
| `time_boost` | +4 seconds on your timer |
| `sabotage` | -3 seconds from opponent's timer |
| `double_down` | 2× points this round |
| `shield` | Blocks next opponent ability |
| `reveal` | Hint about opponent's choice |

---

## 9. Roadmap

- [ ] Phase 1 (current): 1v1 core game loop
- [ ] Phase 2: Ability selection before match, cosmetics shop
- [ ] Phase 3: Leaderboards, friends, daily challenges
- [ ] Phase 4: Team modes (2v2, 3v3)
- [ ] Phase 5: Android + web (same Flutter codebase)

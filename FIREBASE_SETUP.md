# BrainDuel — Firebase Setup (Pas cu Pas)

## Ce ai nevoie
- Cont Google (pentru Firebase Console)
- Cont Apple Developer ($99/an) — **obligatoriu pentru Sign In with Apple pe iOS**
- Flutter instalat → https://docs.flutter.dev/get-started/install/macos/mobile-ios

---

## Pasul 1 — Creează proiectul Firebase

1. Mergi la **https://console.firebase.google.com**
2. Click **"Add project"**
3. Nume: `brainduel` → Continue
4. Dezactivează Google Analytics (opțional) → Create project

---

## Pasul 2 — Activează Authentication

1. Din meniu stânga: **Build → Authentication**
2. Click **"Get started"**
3. Tab **"Sign-in method"**, activează:

### Email/Password
- Click Email/Password → Enable → Save

### Google
- Click Google → Enable
- Project support email: alege email-ul tău → Save

### Apple (necesită Apple Developer)
- Click Apple → Enable
- Services ID: `com.brainduel.app.signin`
- Apple Team ID: din https://developer.apple.com → Membership → Team ID
- Key ID + Private Key: din Apple Developer → Certificates, Identifiers & Profiles → Keys → Create a new key (enable Sign In with Apple)
- Save

---

## Pasul 3 — Creează Firestore Database

1. Din meniu: **Build → Firestore Database**
2. Click **"Create database"**
3. Alege: **Start in production mode**
4. Location: `europe-west3` (Frankfurt, cel mai aproape de România)
5. Done

---

## Pasul 4 — Înregistrează app-ul iOS

1. **Project Settings** (iconița ⚙️) → **Your apps** → click **iOS** (iconița măr)
2. iOS bundle ID: `com.brainduel.app`
3. App nickname: `BrainDuel iOS`
4. Click **"Register app"**
5. **Descarcă `GoogleService-Info.plist`**
6. Click Next → Next → Continue to console

---

## Pasul 5 — Pune fișierul în proiect

Copiază `GoogleService-Info.plist` în:
```
QuizGame/app/ios/Runner/GoogleService-Info.plist
```

**Important**: Deschide Xcode (`open app/ios/Runner.xcworkspace`) și adaugă fișierul prin Xcode drag & drop în folderul Runner (nu prin Windows Explorer).

---

## Pasul 6 — Completează `firebase_options.dart`

Deschide `app/lib/firebase_options.dart` și completează valorile din **Project Settings → Your apps → iOS app**:

| Câmp în firebase_options.dart | Unde îl găsești în GoogleService-Info.plist |
|---|---|
| `apiKey` | `API_KEY` |
| `appId` | `GOOGLE_APP_ID` |
| `messagingSenderId` | `GCG_SENDER_ID` |
| `projectId` | `PROJECT_ID` |
| `iosClientId` | `CLIENT_ID` |
| `storageBucket` | `STORAGE_BUCKET` |

Exemplu cum arată după completare:
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyAbc123...',
  appId: '1:123456789:ios:abc123def456',
  messagingSenderId: '123456789012',
  projectId: 'brainduel-12345',
  storageBucket: 'brainduel-12345.appspot.com',
  iosClientId: '123456789-abc.apps.googleusercontent.com',
  iosBundleId: 'com.brainduel.app',
);
```

---

## Pasul 7 — Configurează URL scheme pentru Google Sign-In (iOS)

Deschide `app/ios/Runner/Info.plist` și adaugă **înainte de `</dict>`**:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- REVERSED_CLIENT_ID din GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.123456789-abc</string>
    </array>
  </dict>
</array>
```

Înlocuiește `123456789-abc` cu valoarea `REVERSED_CLIENT_ID` din `GoogleService-Info.plist`.

---

## Pasul 8 — Activează Sign In with Apple în Xcode

1. Deschide Xcode: `open app/ios/Runner.xcworkspace`
2. Click pe **Runner** → **Signing & Capabilities**
3. Click **+ Capability** → caută și adaugă **Sign In with Apple**
4. Team: selectează-ți Apple Developer Team

---

## Pasul 9 — Deploy Firestore Rules

```bash
# Login Firebase (o dată)
firebase login

# Deploy rules
cd QuizGame/firebase
firebase use --add    # selectează proiectul brainduel
firebase deploy --only firestore
```

Sau folosește scriptul:
```bash
cd QuizGame
node scripts/firebase-setup.js
```

---

## Pasul 10 — Configurează serverul

Editează `server/.env`:
```env
PORT=3001
SKIP_AUTH=false
FIREBASE_PROJECT_ID=brainduel-12345
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@brainduel-12345.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvA...\n-----END PRIVATE KEY-----\n"
```

Cheia privată o obții din:  
**Firebase Console → Project Settings → Service accounts → Generate new private key**

---

## Pasul 11 — Pornește totul

```bash
# Terminal 1 — Server
cd QuizGame/server
npm run dev

# Terminal 2 — App
cd QuizGame/app
flutter pub get
open ios/Runner.xcworkspace   # setează signing în Xcode
flutter run
```

---

## Verificare rapidă

Dacă totul e setat corect:
1. App pornește fără erori în consolă
2. Login cu Google funcționează
3. Server log arată: `[Firebase] Real token verification active`
4. La primul login, documentul utilizatorului apare în Firestore Console → users

---

## Probleme frecvente

| Eroare | Soluție |
|---|---|
| `GoogleService-Info.plist not found` | Pune fișierul în `ios/Runner/` și adaugă-l în Xcode |
| `CONFIGURATION_NOT_FOUND` în Google Sign-In | Adaugă URL scheme în Info.plist |
| `invalid_client` la Apple Sign-In | Verifică Services ID și Team ID în Firebase Console |
| Server: `Firebase credential error` | Verifică FIREBASE_PRIVATE_KEY — newlines trebuie să fie `\n` literal |
| `MissingPluginException` | Rulează `flutter clean && flutter pub get` |

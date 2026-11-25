# Accounts, guest mode and onboarding

Status: **built; Firebase connected (guest accounts verified on a device)**.
Last updated: 25 Nov 2026.

This records how people start using TYF and when they must sign in. Update
it when a decision changes.

## Decisions

| Topic | Decision |
|---|---|
| Start | Guest first. No account is needed to begin. |
| Trial | **14 days** as a guest |
| During the trial | A sign-in screen appears **once a day** (first open of the day), with **Continue as guest** |
| After 14 days | The sign-in screen **cannot be dismissed**. The app can't be used until the user signs in or creates an account. |
| Sign-in methods | **Google** (one tap, shown first) **and** email + password. Phone OTP may come later. |
| Guest tracking | **Firebase Anonymous Auth**. Each guest gets a real Firebase user ID. |
| Price | Creating an account is free. The trial is about signing in, not about paying. |
| Export after trial | **Yes.** The locked screen has "Export my data (CSV)". |

## Flow

```
First open → Welcome → Name → (anonymous Firebase account created) → App
                                                                │
   Days 1–14: first open each day → Sign-in screen
              [Sign in / Create account]   [Continue as guest · N days left]
                                                                │
   Day 15+:   every open → Sign-in screen (no "Continue as guest")
              "Your free trial has ended. Sign in to keep using TYF —
               all your entries are saved and will be kept."
                                                                │
   Sign in / create account → same user ID, local data uploads → App
```

### 1. First open

- **Welcome:** the logo, "Track every rupee, offline", and **Get started**.
- **Name:** "What should we call you?"
- **Anonymous account:** the app creates a Firebase anonymous account in the
  background (see "How a guest is tracked").
- **Then the calendar.**

### 2. During the trial (days 1–14)

- **When the sign-in screen shows:** on the **first open of each calendar
  day**.
- **What it offers:**
  - Sign in / Create account (email + password)
  - **Continue as guest**, with "N days left in your free trial"
- **Sidebar → Account** shows "Guest · N days left" and a Sign in button.

### 3. After the trial (day 15 onwards)

- **On every open,** the sign-in screen appears, with no "Continue as guest"
  and no back or close button. Android's back button exits the app instead
  of skipping the screen.
- **Message:** friendly, not punishing: "Your 14-day free trial has ended.
  Create a free account to keep using TYF. Your N entries are saved on this
  phone and will be uploaded to your account."
- **Data is never deleted.** Signing in unlocks it all, exactly as it was.
- **"Export my data (CSV)":** a link on this screen. A user who doesn't want
  an account can still take their data, which protects trust.

### 4. Sign in / sign up (one screen)

**Continue with Google** is at the top. It's the quickest: one tap, no
password. Below it, "or use email". With either, the user never chooses
between "log in" and "sign up":

- **Google, new to TYF:** the guest is upgraded in place (same user ID).
- **Google, already has TYF** (e.g. a new phone): signs in to that account;
  this phone's guest data is merged by sync.
- **Cancelling** the Google picker just returns to the screen, no error.

```
[ Email ] → Continue
   ├─ account exists → [ Password ] → Sign in   (+ "Forgot password?")
   └─ new email      → [ Create password ] → Create account
```

- **Password rule:** at least 8 characters, with a show/hide toggle.
- **Forgot password:** Firebase sends a reset email.
- **Email verification:** a link is sent, but it doesn't block anything.
- **Errors:** shown in plain language, never as raw Firebase codes.

### 5. After signing in

- **Guest creates an account:** the anonymous account is **upgraded in
  place** (linked to the email), so the user ID stays the same. All data
  carries over with nothing to migrate.
- **Guest signs in to an existing account** (e.g. a new phone): local guest
  data is merged into that account. UUIDs prevent duplicates, and conflicts
  follow last-write-wins on `updated_at`.
- **Sign out:** asks whether to keep this phone's data or remove it.

## How a guest is tracked (Firebase)

- **Anonymous Auth.** On first open the app calls `signInAnonymously()`.
  Firebase creates a real user with a UID and no email. It appears in the
  console as "Anonymous".
- **Trial start.** It's written once to Firestore at
  `users/{uid}.trialStartedAt`, using the **server** timestamp. Changing the
  phone's date can't extend the trial. The app also keeps a local copy so it
  works offline.
- **Upgrade to a real account.** The app calls
  `linkWithCredential(EmailAuthProvider.credential(email, password))`. The
  same UID becomes an email account.
- **First open offline.** The trial starts from the local clock, and the
  anonymous account is created the next time the phone is online.
- **Reinstalling.** A reinstall creates a new anonymous user, which means a
  new trial. That's accepted, because the account is free and the trial is a
  nudge. (Stricter options exist, such as a device ID check, but they aren't
  worth the privacy cost now.)
- **Cleanup.** Unused anonymous accounts pile up. Firebase can auto-delete
  them after 30 days (this needs the Identity Platform upgrade), or a
  scheduled Cloud Function can do it. Handle this later.

## Firebase setup (owner, ~15 minutes)

1. **Create the project.** Go to console.firebase.google.com → Add project →
   "TYF". Analytics is optional.
2. **Add the Android app.** Package name: `com.jassi.tyf_mobile`.
3. **Turn on sign-in methods.** Go to Build → Authentication → Get started →
   Sign-in method, and enable:
   - **Anonymous**
   - **Email/Password** (leave "Email link" off)
   - **Google** (pick a support email)
3a. **For Google: add the SHA keys.** Project settings → Your apps → the
   Android app → Add fingerprint. Add the debug SHA-1 and SHA-256 (from
   `keytool -list -v -keystore ~/.android/debug.keystore -alias
   androiddebugkey -storepass android`), and later the release ones. Then
   download the new `google-services.json` into `android/app/` (or rerun
   `flutterfire configure`). Without this, Google sign-in fails with
   an error such as `clientConfigurationError` or `canceled`.
4. **Create Firestore.** Go to Build → Firestore Database → Create database,
   in production mode, with the region **asia-south1 (Mumbai)**.
5. **Install the tools on the Mac:**
   ```
   npm install -g firebase-tools        # if not installed
   firebase login
   dart pub global activate flutterfire_cli
   ```
6. **Connect the app.** In `tyf_mobile/`, run `flutterfire configure` and
   pick the TYF project. This creates `lib/firebase_options.dart` and
   `android/app/google-services.json`.
7. **Security rules.** Users may only read and write their own data:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /users/{uid}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```
8. **Later:**
   - Add the **release** SHA-1 and SHA-256 before publishing.
   - Enable App Check before launch.

## Technical notes

- **Packages:** `firebase_core`, `firebase_auth`, `cloud_firestore`,
  `google_sign_in` (v7: `initialize()` then `authenticate()`).
- **Account state:** a Riverpod provider based on `authStateChanges()`. The
  states are: no user → guest (anonymous) → signed in (email).
- **Gate logic:** runs at app start and when the app resumes.
  - Show the sign-in screen if the user is a guest **and** either the trial
    has ended (no dismiss) or it's the first open today (dismissable).
  - `last_prompt_date` is stored in shared preferences.
- **Days left:** `14 − days since trialStartedAt`, using the server value
  once known and the local value until then.

## Build order

1. Firebase setup (owner, see above).
2. Welcome and name screens, anonymous sign-in, and the trial start.
3. The sign-in/sign-up screen, Forgot password, and linking a guest to an
   email.
4. The daily prompt and the after-trial gate. Account and days left go in
   the sidebar.
5. Sync: upload local data to `users/{uid}/…` and download it on a new
   phone.

## What's built (25 Nov 2026)

| Piece | Status | Code |
|---|---|---|
| Welcome and name | Done | `lib/features/account/screens/welcome_screen.dart` |
| Guest state and 14-day trial (on the phone) | Done | `lib/features/account/data/account.dart` |
| Gate: welcome, daily prompt, locked or app; re-checked on resume | Done | `lib/features/account/screens/account_gate.dart` |
| Email-first sign-in screen (daily, locked and from the sidebar) | Done (UI) | `lib/features/account/screens/sign_in_screen.dart` |
| Export my data (CSV) | Done | `lib/features/account/data/csv_export.dart` |
| Sidebar: name, Guest · N days left, Sign in | Done | `lib/app/shell/app_drawer.dart` |
| Firebase Auth (anonymous guest, link to email, reset) | Done. Guest accounts verified on a device (25 Nov). Email sign-up, sign-in and reset are still to be tested on a device. | `lib/features/account/data/firebase_auth_repository.dart` |
| Server trial start (`users/{uid}.trialStartedAt`) | Done, verified in Firestore | `FirebaseAuthRepository.ensureGuest` |
| Google sign-in (link guest, or sign in to existing) | Built; needs SHA keys + new `google-services.json`, then a device test | `FirebaseAuthRepository.signInWithGoogle` |
| Data sync (entries, budgets, categories) | Not started | — |

**Firebase project:** `tyf---track-your-finances`. It's connected for
Android only (`com.jassi.tyf_mobile`). iOS still uses the placeholder bundle
ID and needs `flutterfire configure` once it has a real one.

**Build requirements Firebase added:**

- Android `minSdk` is 24.
- The Kotlin Gradle plugin is 2.3.0, with `jvmTarget` set through the
  `compilerOptions` DSL.

## Open questions

None right now.

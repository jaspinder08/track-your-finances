# Accounts, guest mode and onboarding

Status: **agreed direction, not built yet**. Last updated: 24 Nov 2026.

This records how people start using TYF and when they sign in. Update it
when a decision changes.

## Principles

1. **Use first, sign in later.** TYF is offline-first (SQLite on the phone),
   so nobody needs an account to start tracking.
2. **Never hold data hostage.** Whatever happens to a guest, they can always
   *see* and *export* their own data.
3. **Signing in is free.** The trial nudges people to create an account
   (for backup and sync); it is not a paywall.

## Flow

```
First open → Welcome → Name → Calendar (guest, trial starts)
                                   │
          gentle "Back up your data" prompts during the trial
                                   │
                    Day 30: trial ends → sign-in required to keep adding
                                   │
          Sign in / sign up (email + password) → local data uploads
```

### 1. First open (guest)

- **Welcome:** a single screen with the logo, the line "Track every rupee,
  offline", and a **Get started** button.
- **Name:** "What should we call you?". The sidebar uses it.
- **Then the calendar.** The user is a **guest**, and the trial starts now
  (`trial_started_at` is stored on the phone).

### 2. Guest trial: 30 days

During the trial everything works with no limits.

**Nudges.** These are dismissable and never block anything:

| When | Message |
|---|---|
| After ~10 entries | "Back up your data so you never lose it" card |
| Day 23 | "7 days left in your guest trial" banner |
| Last 3 days | Banner on open with a **Create free account** button |

The banner lives in **Sidebar → Account**. It shows "Guest · N days left" and a
**Sign in / Create account** button.

### 3. After 30 days

**Proposed:** if the user isn't signed in, adding or editing entries opens
the sign-in screen.

Everything else stays available:

- viewing the calendar, reports and budgets,
- exporting data,
- changing settings.

No data is ever deleted because a trial ended.

### 4. Sign in / sign up: email + password (for now)

The same screen handles both sign-in and sign-up, so the user never has to
choose:

```
[ Email ] → Continue
   ├─ account exists → [ Password ] → Sign in   (+ "Forgot password?")
   └─ new email      → [ Create password ] → Create account
```

- **Password rule:** at least 8 characters, with a show/hide toggle. There
  are no special-character rules.
- **Forgot password:** Firebase sends a reset email.
- **Email verification:** a link is sent, but it doesn't block anything.
- **Errors:** shown in plain language ("Wrong password", "No internet, your
  data is safe on this phone"), never as raw Firebase codes.
- **Later:** Continue with Google and Phone OTP can be added on the same
  screen.

### 5. After signing in

- **Same phone:** all local data uploads to the account, so nothing is
  re-entered. Rows already have UUIDs and `sync_status`, so this was planned
  for.
- **New phone:** after signing in, the data downloads.
- **Data on both the phone and the account:** the two are merged, and UUIDs
  prevent duplicates. Conflicts follow last-write-wins on `updated_at`.
- **Sign out:** asks whether to keep this phone's data or remove it (for
  shared phones).

## Technical notes

- **Auth:** Firebase Auth with the Email/Password provider. Sync uses
  Firestore, as in the architecture plan.
- **Trial clock:** stored locally. A user can reset it by reinstalling or
  changing the phone date. That's acceptable, because signing in is free:
  the trial is a nudge, not a lock.
- **Guest state:** kept in shared preferences:
  - `trial_started_at`
  - `user_name`
  - `prompt_dismissed_at`
- **Signed-in state:** comes from Firebase Auth.

## Open questions

- **Trial length:** 30 days, or 14?
- **After the trial:** block new entries (proposed above), or only show a
  sign-in prompt on every open?
- **Future paid plan:** if one comes, is the trial about the account or about
  premium features? This doc currently assumes the account only.

## Setup needed (owner)

1. Create a Firebase project at console.firebase.google.com.
2. Go to Authentication → Sign-in method and turn on **Email/Password**.
3. On the Mac, run `dart pub global activate flutterfire_cli` and then
   `firebase login`.
4. Then run `flutterfire configure` in `tyf_mobile/`, which connects the app.

## Build order

1. Welcome, name, guest state and trial countdown in the sidebar. No Firebase
   is needed.
2. The sign-in/sign-up screen, Forgot password, and the account in the
   sidebar.
3. The after-trial rule.
4. Sync: upload on sign-in, download on a new phone.

# Changelog

Notable changes to Story Sprout on `feature/login-registration`, newest first. Each entry is
one commit: its date, name, and hash. Story Sprout is a pre-release academic prototype, so
there are no version numbers. Work from before 2026-09-10 is not recorded here; see
`git log`.

## Current known limitations

- **Coins can't be earned or spent yet.** Rewards exist, but nothing awards coins, so there
  is no balance and no Redeem button.
- **Reading activity isn't tracked yet** (REQ-6, TC-FB-WB-003). It's coming from the
  reading-module owner's branch.
- **Parent PIN** is still hardcoded to `1234` (`parent_pin_screen.dart`).
- **Not implemented yet:** session expiry / reauthentication (NFR-2, NFR-5) and failed-login
  rate limiting (REQ-4).
- **Apple ID sign-in** (REQ-1) is deferred; it needs iOS config and a paid Apple Developer
  account.
- **Still demo data:** Reading Stats and "Family's Recent Activity" on the parent dashboard.
- **Login is always shown on launch**, even when a Firebase session already exists.

---

## 2026-09-26 — Add rewards system: rewards store, parent manager and child rewards screens

Commit `ff96fe9`

### Added
- **Reward catalog** (first part of CR #2, the Coin System). Parents create rewards with a coin
  cost; children see them.
- **Parent screen:** Rewards Manager lets a parent create, edit, retire and restore rewards.
  Open it from the new **Manage Rewards** card on the parent dashboard.
- **Child screen:** My Rewards lists the active rewards, cheapest first. Open it from the gift
  icon on the child dashboard.
- **`RewardStore`** (`lib/services/rewards_store.dart`) saves to
  `parents/{uid}/rewards/{rewardId}`.
  - Every reward needs a name and a cost from 1 to 10,000 coins.
  - Rewards are retired, never deleted, so past redemptions still point to a real reward.
- **16 tests** in `test/rewards_store_test.dart`.

### Notes
- No Firestore rules change was needed; the existing `parents/{uid}/**` rule already covers
  rewards.

### Verified
- 42 tests pass and `flutter build web` succeeds, checked on a clean checkout.
- On the Android emulator with live Firebase: a parent created a 50-coin reward and it showed
  up on the child's My Rewards screen.

---

## 2026-09-10 — Move child profiles to Firestore with hashed PINs

Commit `d67716f`

### Changed
- **Child profiles are now stored in Firestore** at `parents/{uid}/children/{childId}`, so
  each parent only sees their own children. Before this, they were stored on the device.
- **Child PINs are hashed** (salted SHA-256) and never stored in plaintext.
- **Automatic migration:** profiles stored on the device are moved to Firestore the first
  time the app loads them. It's one-way and skipped if the account already has children.
- **`firestore.rules`** now protects everything under `parents/{uid}`, not just the parent's
  own document.

### Fixed
- The child setup and selector screens no longer spin forever when a save fails; they show
  an error.

### Added
- `crypto` dependency for PIN hashing.

### Notes
- A 4-digit PIN can be guessed in 10,000 tries, so the Firestore rules are the real
  protection. Switching to a slow hash (KDF) is the upgrade path if the PIN needs to be
  stronger.
- **Rules deployed on 2026-09-23:** the owner can read their data, while anonymous and
  cross-parent reads are refused (`403`). This closes TC-FB005 and TC-FB-WB-002.

### Verified
- Tests went from 17 to 26.
- On the Android emulator with live Firebase: register, add children, sign out, enter a
  child PIN, check that parents only see their own data, and run the migration.

---

## 2026-09-10 — Merge remote-tracking branch 'origin/main' into feature/login-registration

Commit `e68bdf6`

### Changed
- **`lib/` reorganized** into `lib/screens/` and `lib/services/` (from `09f6e3b`, a
  teammate's 2026-08-23 commit on `main`). `main.dart` stays at the root.
- Also merged: the README update and `CONTRIBUTIONS.md` (`d3c158d`).

---

## 2026-09-10 — Add child profile management and tests, update login/registration flow

Commit `ffc2087`

### Added
- **Real parent login and registration** with Firebase Auth. Errors show as clear inline
  messages.
- **Registration creates a parent record** in Firestore at `parents/{uid}`. If that write
  fails, the new account is rolled back (TC-FB-WB-001).
- **Sign Out** in Parent Settings now actually signs out of Firebase (TC-FB-WB-004).
- **Child setup screen** runs once after registration. The parent adds 1–6 children, each
  with a name and a 4-digit PIN.
- **Child selector and PIN screens** use the real child profiles and PINs instead of demo
  data.
- **`firestore.rules`**, which only lets a parent access their own data.
- **Test suite:** tests for login, registration, sign-out and the child profile screens.
  They run offline using `firebase_auth_mocks` / `fake_cloud_firestore`.

### Changed
- Registration now leads to child setup instead of straight to the parent dashboard.
- The parent dashboard shows the real child profiles.
- The login, registration and child setup forms scroll so they fit when the phone keyboard
  is open.
- Removed the leftover Flutter counter template from `main.dart` and `widget_test.dart`.

### Fixed
- **Web build was broken.** The EPUB reader passed a `dart:io` `File`, which doesn't work on
  web. It now opens the book from its bytes.
- The login, registration and child setup screens no longer overflow at phone height when
  the keyboard is open.

### Verified
- 17 tests pass and `flutter build web` succeeds.
- On the Android emulator: register → child setup → parent dashboard → sign out → log back
  in → child selector → child PIN.

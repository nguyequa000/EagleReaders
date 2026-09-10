# Changelog

All notable changes to Story Sprout are recorded here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/). The app is a pre-release academic
prototype, so everything lives under **Unreleased**.

## [Unreleased]

### Added

- **Real parent authentication.**
  - `LoginScreen` calls `FirebaseAuth.signInWithEmailAndPassword` with success/failure
    branching, a loading/disabled button, and inline error text mapped from
    `FirebaseAuthException` codes (`invalid-email`, `wrong-password`/`invalid-credential`,
    `user-disabled`, `network-request-failed`, `too-many-requests`).
  - `RegistrationScreen` wraps `createUserWithEmailAndPassword` in `try/catch`, validates
    email + a 6-char minimum password locally, maps error codes (`email-already-in-use`,
    `weak-password`, `invalid-email`, `operation-not-allowed`, `network-request-failed`),
    and writes a `parents/{uid}` Firestore document (`email`, `role: 'parent'`,
    `createdAt`). If the Firestore write fails after the account is created it rolls the
    account back. (Covers TC-FB-WB-001.)
  - `ParentSettingsScreen` "Sign Out" now calls `FirebaseAuth.signOut()` before returning
    to the login screen. (Covers TC-FB-WB-004.)
  - `FirebaseAuth` / `FirebaseFirestore` are injectable via optional constructor params
    (default `.instance`) so widget tests run offline with `firebase_auth_mocks` /
    `fake_cloud_firestore`.
- **Child profiles + per-child PIN.**
  - `lib/child_profiles.dart` — `ChildProfile` model (`id`, `name`, `pin`, `emoji`) and
    `ChildProfileStore`, a local store over a single `shared_preferences` key.
  - `lib/child_setup_screen.dart` — shown once after registration: a "How many children?"
    dropdown (1–6) then a name + 4-digit PIN per child, validated and saved locally before
    the parent reaches the dashboard. Adding at least one child is required.
  - `ChildSelectorScreen` loads and lists the real profiles (with loading and empty
    states); `ChildPinScreen` validates the entered PIN against the selected child's
    stored PIN.
  - `ParentDashboardScreen`'s "Child Profiles" section reflects the stored profiles.
- **`firestore.rules`** (repo root, referenced from `firebase.json`; `.firebaserc` sets the
  default project) — locks `parents/{uid}` to its owner, denies everything else. **Not yet
  deployed.**
- **Test suite** — `test/login_screen_test.dart`, `test/registration_screen_test.dart`,
  `test/sign_out_test.dart`, and `test/child_*_test.dart` (profiles store, setup screen, PIN
  screen, selector). The counter-template `test/widget_test.dart` was deleted.
- **Dependencies** — `shared_preferences`; dev: `firebase_auth_mocks`, `fake_cloud_firestore`,
  `mock_exceptions`.

### Changed

- `RegistrationScreen` now navigates to `ChildSetupScreen` on success (was
  `ParentDashboardScreen`).
- `LoginScreen` / `RegistrationScreen` bodies are wrapped in
  `LayoutBuilder → SingleChildScrollView → ConstrainedBox` so the form still fits with the
  keyboard up and an error line showing.
- `ChildSelectorScreen`, `ParentDashboardScreen`, `ChildPinScreen` reworked to read real
  data instead of the hardcoded Alex/Sam/Mia demo values.
- `main.dart` — removed the leftover `MyHomePage` counter template.
- `CLAUDE.md` and `PROJECT_CONTEXT.md` updated: screen graph, demo/stub state, SRS gap
  status (REQ-1/REQ-2 done; REQ-3 child side done locally), build order, and Android-emulator
  / `flutter build web` verification notes.

### Fixed

- **Web build was broken** by `lib/reading_module_page.dart` passing a `dart:io` `File` to
  `epub_view`, whose `openFile` is typed against `universal_file`'s `File` — a mismatch only
  on web, invisible to `flutter analyze` and the widget tests. The EPUB path now reads
  `file.bytes` and calls `EpubDocument.openData`.
- Child-setup / login / registration screens no longer overflow at phone height when the
  soft keyboard is open (found on the Android emulator).

### Known limitations / not yet done

- **Apple ID sign-in** (REQ-1) — deferred; needs iOS config + a paid Apple Developer account.
- **Parent PIN** is still hardcoded to `1234` in `parent_pin_screen.dart`.
- **Child profiles/PINs are local only** (`shared_preferences`, plaintext, not namespaced per
  parent) — pending migration to a Firestore `parents/{uid}/children` collection. TC-FB001 is
  only partially met.
- **`firestore.rules` is not deployed** — the test database is still in open mode, so
  TC-FB005 / TC-FB-WB-002 (cross-role read blocking) are unenforced server-side.
- **Session expiry / reauthentication** (NFR-2, NFR-5) and **failed-login rate limiting**
  (REQ-4) are not implemented.
- Reading Stats and "Family's Recent Activity" on the parent dashboard are still demo data.
- `main.dart` shows `LoginScreen` unconditionally — an existing Firebase session does not
  skip login.

### Verification

`flutter analyze` clean (4 pre-existing `withOpacity` infos), `flutter test` green (17
tests), `flutter build web` succeeds. Both features were driven end-to-end on the Android
emulator: register → child setup → parent dashboard → sign out → log back in → child selector
→ per-child PIN.

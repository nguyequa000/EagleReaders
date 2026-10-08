# Child-safety / compliance release blockers

Demo can ship on fake data. Release cannot ship until every unchecked item is done.

## Phase A (done)
- [x] A1 PII redaction before text goes to the model
- [x] A2 Self-harm / abuse stop: `SafetyStopException` -> "Let's talk to a grown-up" panel, no retry
- [ ] A3 "Made with AI" label — removed by request; must return before EU release (B14)
- [x] A4 Bad-word filter (swearing, slurs) on story idea + "write what happens" fields

## Phase B (open)
| # | Blocker | Where |
|---|---|---|
| B1 | Migrate `FirebaseAI.googleAI()` -> `FirebaseAI.vertexAI(location: 'us-central1')`; Blaze billing; App Check enforced (Nov 2 2026); confirm model exists on Vertex | `story_generator.dart` |
| B2 | Google's written confirmation that child-directed use is permitted under Cloud terms (gates B1) | - |
| B3 | Verifiable parental consent before any AI call, naming Google as recipient | `child_setup_screen.dart` |
| B4 | Real parent gate replacing `_demoPin` (auth/PIN + rate limiting) | `parent_pin_screen.dart` |
| B5 | Persist + enforce settings (AI toggle as kill switch gating `generateStory`, time limit, reminders) | `parent_settings_screen.dart` |
| B6 | Activity-log privacy: key by child ID, encrypt or Firestore rules, retention/delete | `activity_service.dart` |
| B7 | Disclose quiz path (EPUB text also sent to Gemini) | `story_generator.dart` |
| B8 | Retention schedule for child text, stories, logs | service layer |
| B9 | Remove `firebase_analytics` (Apple Kids bars third-party analytics) | `pubspec.yaml` |
| B10 | Output moderation before display | `Story.fromJson` |
| B11 | Per-child daily generation cap | `story_generator.dart` |
| B12 | Blocked-response handling (partly via `fallbackStory`) | `story_generator.dart` |
| B13 | Keep + test prompt-injection hardening | `story_generator.dart` |
| B14 | AI disclosure on all AI surfaces (story view done; quiz path remains) | UI |

# Status

## Done
- Brief v2 (10 days) adopted; roadmap in `docs/plan/roadmap.md`, screen audit in `docs/design/SCREEN_MAP.md`
- Flutter app: light + dark Ember themes (ThemeExtension palette, `context.hc`), spacing/radii/motion tokens
- Component library in `lib/core/widgets/`: Glass, Aurora, TickDial, PrimaryButton, OutlineAction, TextAction, IconAction, HiredChip, Tag, Segmented, ScoreCorner, NextActionCard
- Readiness formula + 7 unit tests; Home screen with honest empty state; tab shell and routes
- Cloud Functions (TypeScript): `parseResume`, `rewriteBullet`, forced-tool-call helper with zod + one retry, schema tests (5 green), CI workflow

## In progress
- Day 1 remainder: Firebase project wiring, Auth, Functions deploy (all need you, see below)

## Blocked on you
| Item | Command / action |
|---|---|
| Android licences | `flutter doctor --android-licenses` |
| Firebase CLI | `npm i -g firebase-tools` then `firebase login` |
| Firebase project | Create it, enable Blaze, add a ₹500 budget alert, enable Auth (Google + email), Firestore, Storage |
| FlutterFire | `dart pub global activate flutterfire_cli` then `flutterfire configure` in the repo root |
| Debug SHA-1 | `cd android && ./gradlew signingReport`, add to Firebase for Google sign-in |
| Anthropic key | `firebase functions:secrets:set ANTHROPIC_API_KEY` |
| Device | Connect the demo phone (USB debugging) or start an emulator |
| Plugins | `claude plugin marketplace add flutter/agent-plugins`, `claude plugin install dart-flutter@dart-flutter`, `/plugin marketplace add 9evxxx/flutter-skill`, `/plugin install flutter-skill@9evxxx-flutter-skill`, `/plugin marketplace add anthropics/skills` |
| MCP | `claude mcp add mobile -- npx -y @mobilenext/mobile-mcp@latest`, `claude mcp add firebase -- npx -y firebase-tools@latest mcp`, `claude mcp add --transport http vercel https://mcp.vercel.com` |

## Open decisions
- Readiness "time decay": see SCREEN_MAP.md, default is none within 21 days so 62 to 68 holds
- 14 features in the brief have no designed screen (SCREEN_MAP.md); Coach Replay is the priority

## Notes
- Mono label font is JetBrains Mono via google_fonts (Geist Mono is not in the package). Fonts load at runtime; bundle before the demo.
- Functions are typechecked and schema-tested but have never run against the real Claude API (no key yet).

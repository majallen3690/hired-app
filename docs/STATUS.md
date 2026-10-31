# Status

## Done
- Flutter Android project created (`com.hired.hired`), git initialised
- Build brief and design handoff copied into `docs/`

## In progress
- Day 1: theme, readiness formula, dial, Cloud Functions scaffold, resume screens

## Blocked on you
| Item | Command / action |
|---|---|
| Android licences | `flutter doctor --android-licenses` |
| Firebase CLI | `npm i -g firebase-tools` then `firebase login` |
| Firebase project | Create it, enable Blaze, add a ₹500 budget alert, enable Auth (Google + email), Firestore, Storage |
| Anthropic key | `firebase functions:secrets:set ANTHROPIC_API_KEY` |
| Device | Connect the demo phone (USB debugging) or start an emulator |
| Claude Code plugins | `claude plugin marketplace add flutter/agent-plugins`, `claude plugin install dart-flutter@dart-flutter`, `/plugin marketplace add 9evxxx/flutter-skill`, `/plugin install flutter-skill@9evxxx-flutter-skill` |
| MCP | `claude mcp add mobile -- npx -y @mobilenext/mobile-mcp@latest`, `claude mcp add firebase -- npx -y firebase-tools@latest mcp` |

## Notes
- Day 1 so far: theme tokens, readiness formula (7 tests green), tick dial, glass, shell + Home with an honest empty state. Resume screens and Cloud Functions not started.
- Mono label font is JetBrains Mono via google_fonts (Geist Mono is not in the package). Fonts load at runtime; bundle them before the demo.

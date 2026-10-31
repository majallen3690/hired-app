# Day 1 plan: foundation + resume (Hero)

Source of truth: `docs/HIRED_BUILD_PROMPT.md`. Design handoff: `docs/design/` (open the `.dc.html` files, tokens in `hired.css`).

## Environment (checked 2026-10-31)
- Flutter 3.32.5 / Dart 3.8.1, Node 22, Java 21, adb present
- **Blocked on the user:** `flutter doctor --android-licenses` (licence acceptance), Firebase CLI install, Firebase project + Blaze plan + budget alert, `ANTHROPIC_API_KEY` secret, a connected phone or emulator
- Plugins/MCP from section 2 of the brief (`claude plugin ...`, `claude mcp add ...`) are user-run shell commands; listed in `docs/STATUS.md`

## Scope for today
1. Flutter project, feature-first structure, Riverpod + GoRouter, Ember theme from `hired.css` into `lib/core/theme/`
2. `lib/core/scoring/readiness.dart` (pure Dart) + unit tests
3. Shared widgets: tick dial (CustomPainter, 60 ticks in 4 arcs), glass card, tab bar shell
4. Cloud Functions scaffold (TypeScript): `config.ts`, zod schemas, forced-tool-call helper, `parseResume`, `matchResume`, `rewriteBullet`
5. Screens against the design: Home (A01), Resume input (A02), Analysing (A03), Match result (A04), Bullet rewrite (A05)
6. `flutter analyze` clean, tests green, commit

## Rules carried from the brief
- Never fake an AI response. Until Firebase and the Anthropic key exist, the screens call a repository interface and show an honest "backend not connected" state.
- Claude calls use a forced tool call with a strict schema, zod-validated, one retry.
- Tokens live in `lib/core/theme/`, models in `lib/core/config/ai_config.dart` and `functions/src/config.ts`.

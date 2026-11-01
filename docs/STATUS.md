# Status

## Done
- Brief v2 (10 days) adopted; roadmap in `docs/plan/roadmap.md`, screen audit in `docs/design/SCREEN_MAP.md`
- Flutter app: light + dark Ember themes (ThemeExtension palette, `context.hc`), spacing/radii/motion tokens
- Component library in `lib/core/widgets/`: Glass, Aurora, TickDial, PrimaryButton, OutlineAction, TextAction, IconAction, HiredChip, Tag, Segmented, ScoreCorner, NextActionCard
- Readiness formula + 7 unit tests; Home screen with honest empty state; tab shell and routes
- Cloud Functions (TypeScript): `parseResume`, `rewriteBullet`, forced-tool-call helper with zod + one retry, schema tests (5 green), CI workflow

## Done since
- Free-tier pivot (see `docs/DECISIONS.md`): no Blaze, no Anthropic key, no Storage; Functions folder removed
- Firebase connected (`hired-aeb6c`), `firebase_options.dart` generated, Android licences accepted
- Resume flow: input (A02), analysing (A03), result with evidence (A04), bullet rewrite sheet (A05); 13 tests green

## Blocked on you (one click)
- Firebase console > Build > **AI Logic** > Get started > choose **Gemini Developer API**. Without this every AI call returns "not switched on".
- Billing: console > Usage and billing > make sure the plan is **Spark** (you said you only added payment info; if it says Blaze, switch it back)
- Later, for sign-in: Authentication > Sign-in method > enable Google and Anonymous; Firestore > create database

## Not yet verified
- App has not been run on the emulator or against the live Gemini API

# Status

## Done
- Brief v2 (10 days) adopted; roadmap in `docs/plan/roadmap.md`, screen audit in `docs/design/SCREEN_MAP.md`
- Flutter app: light + dark Ember themes (ThemeExtension palette, `context.hc`), spacing/radii/motion tokens
- Component library in `lib/core/widgets/`: Glass, Aurora, TickDial, PrimaryButton, OutlineAction, TextAction, IconAction, HiredChip, Tag, Segmented, ScoreCorner, NextActionCard
- Readiness formula + unit tests; Home screen with honest empty state; tab shell and routes
- Free-tier pivot (see `docs/DECISIONS.md`): Spark plan, no Anthropic key, no Storage, no Cloud Functions
- Firebase connected (`hired-aeb6c`), AI Logic enabled, App Check unenforced, project back on Spark
- Resume flow verified live on the Pixel 7 emulator against Gemini: parse, match %, three component scores,
  matched/missing chips, section notes, evidence popups, bullet rewrite with `[placeholder]` metrics
- Evidence is verified in code (`MatchResult.withVerifiedEvidence`): a line the resume does not contain cannot support a match
- 17 unit tests green, `flutter analyze` clean

## Known behaviour
- Match score varies a few points between runs of the same inputs (38 to 46 seen): Gemini re-extracts the
  requirement list each time. Temperature is 0. A fix if it matters for the demo: cache the result per (resume, JD) hash.
- The sample resume is deliberately thin, so it scores in the 40s. The demo story (62 then 71) needs a stronger
  sample resume or a tailored JD; do not hard-code scores.

## Not yet done
- Rewrite prompt was tightened (no technologies or domains the bullet does not state) but not re-run on the emulator
- Sign-in and Firestore persistence (needs Authentication: Google + Anonymous, and a Firestore database, in the console)
- M7 live interview with Coach Replay, M1/M10 dashboards fed by real data, M6, M5, M8, M9, paywall concept, demo mode, landing page
- Production hardening: App Check with the Play Integrity provider before any public release

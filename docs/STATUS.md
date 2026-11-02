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

## M7 live interview (built, partly verified on the emulator)
- Gemini Live voice interviewer (`gemini-3.1-flash-live-preview`, fallback native-audio 2.5) via `firebase_ai`, free tier, probed over WebSocket first
- Persona grounded in the parsed resume; `logAnswerSignal` and `endInterview` tool calls work (probed)
- Both sides transcribed by Gemini (input/output transcription); fillers, pace and long pauses measured in Dart, typed answers excluded
- Evaluation with a verbatim quote per rating, checked against the transcript (invented quote: dropped, rating capped at 3)
- Session saved on device (JSON + mixed WAV); report screen; Coach Replay with scrubbable marker timeline and synced transcript
- Reliability: one reconnect, quiet standard mode (question by question) if Live cannot connect, typed answers, mic denial handled
- Home shows only measured areas ("readiness 2 of 4"); resume and interview scores persist across restarts
- Verified on the Pixel 7 emulator with typed answers: greeting by name, resume-grounded questions, scoring, report quotes, replay playback
- 51 unit tests green

## M7 verification log (Pixel 7 emulator, typed answers)
- Full five-question run: the interviewer adapts difficulty, asks a final fundamentals question, wraps up on its own
  (`endInterview`), the app scores and opens the report. Score delta vs the previous mock is shown (52, down 18 from 70)
- The evaluator flagged off-topic answers honestly instead of inflating the score
- Compact layout while typing, neutral project chips, pause windows (spoken turns only) and the replay header all verified

## Not yet verified (M7)
- Spoken answers on a real voice (emulator mic): live fillers, pace, measured pauses, echo without earphones
- Company Mode (Search grounding), Hinglish run, eye contact (camera, belongs to M5)
- Sending an answer closes the keyboard; keeping it open between answers would be nicer

## Environment note
- The C: drive hit 2 GB free once and the emulator refused to start; keep 10+ GB free before building. `build/app/intermediates` regenerates on the next build

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

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

## M10 Progress and scorecard (built and verified on the emulator)
- Readiness timeline replayed from real results: every resume match plus each scored mock (interview and speaking), so the chart can never disagree with a report
- Streak (alive through yesterday), seven-day activity dots, counts, best-ever per area, four badges that unlock only from real results
- Range switch (1 week, 1 month, all time), placement-ready line at 75, empty state from the design
- Shareable scorecard: 360x640 card in the dark theme, rendered to a 1080x1920 PNG (checked by pulling the file off the device) and handed to the system share sheet
- 73 unit tests green

## M6 Self-intro (built, see verification below)
- Recorder (`record`, 16 kHz PCM, raw signal) with a 60-tick countdown dial and live level meter; typed fallback
- Gemini transcribes the WAV with fillers kept (probed with a speech sample), then a second call rates clarity, structure, confidence and who/what/why with verbatim quotes
- Measured in Dart: words per minute over the time actually speaking, fillers, longest pause (relative level threshold, so a quiet mic works), volume steadiness; guards for silence, under 5 s, under 20 words and a transcript faster than 300 wpm
- Structure is capped by the who/what/why check; a part whose quote is not in the transcript counts as missing
- Stronger version uses only facts from the transcript, resume or target role, with `[placeholders]`; a number it invents is rejected and retried
- Result compares with the last try (what improved, what slipped); saved on the device with the recording
- A spoken, scored intro sets the speaking score and adds a Progress event; Intros count on Progress is real
- 29 new unit tests plus a widget test of the result screen (it caught a layout crash the emulator showed only as a blank screen)

## M6 verification log (Pixel 7 emulator)
- Typed intro, twice: first 53 (no "why"), second 73 with "▲ 20 since last try", "Clarity up from 3 to 4", "Confidence up from 2 to 4"
- The stronger version reused only facts from the resume (Flutter, Firebase, Brightlabs, the 30% seat-finder figure) and the target role
- When the typed text was cut off mid-sentence (emulator input limit) the scorer said so and marked "why" missing
- Recorder: 60-tick dial counts down, level meter and "speak up" hint react to the mic; a silent recording gives "We could not hear you" and nothing is sent to the AI
- Typed intros leave readiness at 33 (not speaking); Intros on Progress reads 2
- Transcription prompt probed with a Windows speech sample containing "um", "uh", "basically": returned word for word, fillers kept
- Not verified: a real voice (the emulator mic is silent), so live pace, filler and pause numbers and the Delivery card come from unit tests only; test with earphones on a phone

## M8 Application tracker (built, see verification below)
- Six stages (Wishlist, Applied, OA, Interview, Offer, Rejected); list view with stage filters and a board with long-press drag and drop between columns (the board scrolls itself when a card is held at the screen edge)
- Paste a job description and Gemini fills company, role and 5 to 8 skills; `verifyAutofill` drops any company, role or skill the pasted text does not contain, so nothing is shown as read from it when it was guessed
- Follow-up nudge derived from the data: Applied for 5 days with no move; moving stage clears it (notifications come with M9)
- Detail screen: stage chips (also the no-drag way to move), editable company, role, notes and job description, saved as you type
- Cross-links: "Run resume match for this job" pre-fills the job description and runs on the saved parsed resume (no need to pick the PDF again); "Practise interview for this company" pre-fills role and company in the interview setup
- Duplicate role at the same company is flagged; applications kept on the device; list shows nothing until the file is read (no empty-state flash)
- 21 domain unit tests and 8 widget tests, including a real drag between columns

## M8 verification log (Pixel 7 emulator)
- Empty state as designed; pasted a 4-line Razorpay job description: "Fill it in" returned Razorpay, "Software Development Engineer I" and Java, Kotlin, PostgreSQL, Kafka, AWS; saved as Applied and survives a restart
- Five extra applications were written into the emulator's app data as test fixtures (a stale Applied one to get the follow-up nudge); they are not in the repo
- List: urgency order (interview, offer, applied, wishlist, rejected), stage filters with counts, "Follow up with Swiggy, 6 days since you applied"
- Board: real long-press drag moved Google from Wishlist to Applied and it persisted; holding a card at the right edge scrolled the board to Rejected; dropping in the gutter beside a column cancels
- "Practise interview for Razorpay" opened the setup with role and company filled in
- "Run resume match for this job" opened the resume screen with the job description filled in and "Saved resume" selected (no PDF needed); the match ran to a 50% result with matched and missing chips

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

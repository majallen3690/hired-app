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

## M9 Reminders (built, see verification below)
- Rules in Dart (`reminder_rules.dart`): follow-up at 10:00 five calendar days after an application moved to Applied; for an interview or test time set on an application still in play, a note at 8:00 that day and a warm-up mock two hours before
- Only future reminders are scheduled; the full set is rebuilt from the applications on every change, so a moved, edited or removed application cannot leave a stale reminder
- Stable notification ids (FNV-1a, not `String.hashCode`, which changes between runs) so old reminders can always be cancelled
- `flutter_local_notifications` + `timezone` (Asia/Kolkata); exact alarms when the user allows them, otherwise inexact (a little late, never lost); boot receiver restores them after a restart
- Permission is requested the first time a reminder exists (saving an application as Applied, or setting an interview time), not at launch; the detail screen says when notifications are off
- Detail screen: pick interview or test date and time, and see the exact reminders this application will send
- Tapping a notification opens the application, or (warm-up) the interview setup with role and company filled in; also works when the app was closed
- 20 rule tests, 2 widget tests

## M5 Presence check (built, see verification below)
- Camera screen with the designed live guide: dashed oval (amber until the frame is good, then teal), occasion switch (Interview, Client, LinkedIn, Office), up to three live pills (face centred, light on the face, head level) and the occasion hint
- ML Kit face detection on every analysed frame (about 4 a second): face count, position and size, head angles, smile, eyes open; brightness of the face and of the background is measured in Dart from the camera's Y plane, with the frame rotation handled (backlit and too dark/bright are told apart)
- The shutter only sends a photo when exactly one face is in view; with none or several it explains and sends nothing
- Gemini vision rates attire, grooming, background and expression 1 to 5 with a short "seen" line, plus fix suggestions; it is told never to judge faces, bodies, age, gender or looks, and attire is dropped (not invented) when clothes are not in the photo
- Score is computed in Dart and is occasion-weighted: attire and grooming are the model's rating; light and background are half measured brightness and half the model's view of the background; expression is half the model's rating, a quarter measured smile and a quarter measured gaze. Every area shows "Seen" (AI) and "Measured" (phone) separately
- A model that rates an area 5 and also suggests a fix for it is capped at 4 for that area; the three fixes put measured problems first (backlit, dark, too far, looking away), then the model's
- Consent sheet before the first photo is sent; photos stay on the phone; nothing counts until "Save to my score"; an unsaved check and its photo are deleted on retake or leave; a saved one can be deleted and the score steps back
- Gallery photos work too (head angles and expression only; position and brightness are not measured for them)
- Saved checks feed the Presence score on Home and the Progress chart
- 45 new unit tests and 4 widget tests (scored, failed, saved, no clothes)

## M5 verification log (Pixel 7 emulator)
- The emulator has no front camera and its back camera is a test pattern with no faces, so the live guide could only be seen reporting "Move your face into the oval"; the camera permission prompt, live preview and ML Kit analysis loop ran; the shutter with no face showed the explanation and sent nothing
- The consent sheet appeared on first use and gallery picking worked
- A generated cartoon portrait picked from the gallery was detected by ML Kit (smile 78%, eyes open, facing the camera) and Gemini described the navy sweater, collar, hair, plain grey background and smile; the result screen, breakdown and three fixes rendered as designed. It scored 100 in every area, which is what prompted the cap and the prompt calibration above
- After the cap and prompt change the same portrait scored 92 (attire 80, expression 90, grooming and background 100). "Save to my score" first hung on "Saving…": the controller was auto-disposed while the screen awaited it. The same flaw sat in the intro result's "Score it now" retry, which had never been exercised. Both result screens now keep their controller alive, with a regression test; after the fix Save returned to Home showing Presence 92 and readiness 47 (3 of 4)
- Not verified: the live guide with a real face (centring, size, backlight and tilt pills), taking a real photo (`takePicture` after stopping the stream), the front camera, and how generous the model is on real photos. Test on a phone

## M9 verification log (Pixel 7 emulator, Android 15)
- Saving a new application as Applied showed Android's notification permission prompt at that moment (not at launch)
- With exact alarms allowed (`appops` on the emulator), `dumpsys alarm` listed the scheduled notifications at the expected instants: three follow-ups at 7 Nov 10:00 (the three Applied applications, five days after 2 Nov)
- An interview set about two hours ahead fired its warm-up at 22:35:25 IST as scheduled ("Warm up for Zoho, Your interview is at 12:35 am..."); tapping it opened the interview setup with role and company filled in
- Date and time pickers on the detail screen set Thu 5 Nov 3:35 pm: the screen listed "Interview day 8:00 am" and "Warm-up mock 1:35 pm", and `dumpsys alarm` showed exactly those two alarms, replacing the old one
- Not verified: a tap that launches the app from closed (same code path via `getNotificationAppLaunchDetails`, untested), inexact mode (exact was allowed), delivery after a reboot, and behaviour when the user denies the permission beyond the in-screen note

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

## Smoothness pass (built, measured on the emulator)
Goal: the app should feel like one continuous surface. What changed and why:

| Area | Before | Now |
|---|---|---|
| Background | Two lights moved by animating `left`/`top` under a 60px blur, redrawn 60 times a second | Each light is a soft gradient painted once into its own layer; a 10 Hz timer moves the layer. Shared clock, so a screen sliding over another carries the same light. Still under reduced motion; quiet while covered |
| Cards | A live 28px `BackdropFilter` on every card, over a moving background | Plain translucent fill (a blur of a smooth background changes nothing visible). Real blur only on the tab bar and the camera overlays, where something busy passes underneath |
| Tabs | Hard cut; each tab rebuilt and lost scroll and typed text on every visit | `StatefulShellRoute.indexedStack`: tabs keep state, switch instantly, the arriving tab settles in over 240 ms; sliding thumb under the active tab |
| Screens | Platform default | Cupertino slide with parallax and an interruptible edge-swipe back, on every route. Drill-ins use push so closing returns to exactly where you were |
| Touch | Material ripple on release | Press-down scale on touch-down (not release), spring back, released if the finger slides off so scrolling never leaves a card stuck; reduced motion dims instead of moving |
| Entrances | Everything appeared at once | Fade-and-rise stagger (50 ms steps, first 8 items only, once per screen) |
| Controls | Segments and chips snapped | One thumb slides between segments; chips and labels ease colour; haptics on tab, segment, chip and primary actions |
| Waiting | Spinners flashed on 5 ms local reads | Spinner appears only after 280 ms; analysing steps settle into a tick |
| Scrolling | Android clamp with glow | Rubber-band physics everywhere, no glow; forms close the keyboard on drag |
| Startup | White launch window; Google Fonts fetched at runtime; Firebase and notifications awaited before the first frame | Launch window is the app's own ink; fonts bundled in `google_fonts/` with runtime fetching off; Firebase and notifications start behind the first frame and everything that needs them awaits them |

Measured on the Pixel 7 emulator, profile build, app sitting on Home doing nothing (alternating the old and new APK):
- frames drawn in 6 s: 210-216 before, 61 after
- app CPU: 73-76% before, about 10% after (the emulator was busier at that point than at my first run, so read the ratio, not the absolute)
- with reduced motion on, the app draws no frames and uses 0% CPU
- cold start: no measurable change on the emulator (about 4.1 s for both builds in the same conditions); the font and Firebase changes matter most on a fresh, slow or offline phone, which I cannot reproduce here

Not verified:
- Real-phone frame times. The emulator draws on the host GPU, so SurfaceFlinger counted 0 janky frames for the old build too: it cannot show the old jank. The blur and animated-layer fixes are structural, known costs, not something I could see fail here
- Haptics (the emulator has no vibration motor)
- First launch offline with the bundled fonts, and the system back button across the new nested resume stack
- Feel: timing and curves are from the animation reference tables and checked in screenshots, not on a thumb. Worth a few minutes on a real phone


Second polish round (verified on the emulator unless noted):
- score bars fill from empty and the number counts up, with a soft haptic when a score lands (haptic not verifiable here)
- sheets rise on the same long-settle curve; sheets, dialogs and toasts share one theme (toast floats above the tab bar)
- interview and intro-recorder states fade and settle instead of cutting (tests only; not driven end to end on the emulator)
- tracker board: lifted card, drop highlight and haptics on lift and drop; dragging works on the new build
- bug found by the existing board test and fixed: a press-feedback wrapper threw if its card was rebuilt under the finger mid-drag

## Demo mode (built, fixtures generated, verified on the emulator)
- Settings screen (profile, appearance with persisted theme, delete my data, version tap x7 unlocks the demo section)
- Storage root (`AppDir`) lets demo data live in its own folder; a switch restarts every provider; Home and Settings carry a "Demo data" tag
- Seeder, WAV amplitude analysis, authored script, generated recordings, forge harness; sample-JD chips on the resume screen in demo mode
- Fixtures come from running the real pipelines (`assets/demo/fixtures.json`): resume matches 49, 63, 79; sessions 47, 85, 96; two intros
- Verified on the emulator: seven taps unlock, switch on gives Home 77 (3 of 4), Progress climb "62 in 3 weeks", Tracker with 8 applications and a Swiggy follow-up nudge
- Resume v2 was reworded (Docker, Spring Boot, JUnit added) because its first scores (45, 43) fell below v1; scores themselves are never edited
- Known rough edges: Speaking 98 and Interview 96 are high for a student (clean synthetic audio, strong scripted answers); streak shows "No streak yet" because the newest activity is 2 days old
- Not verified: Coach Replay on the synthetic audio, reminders for the two upcoming interviews

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

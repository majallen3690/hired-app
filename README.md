# Hired

**An AI placement-prep coach for college students.** Hired scores how ready you are for a campus placement, shows the
evidence behind every score, and tells you the one thing to do next.

Built with Flutter for a college Mobile App Development project. It runs entirely on free tiers: Gemini through
Firebase AI Logic on the Spark plan, with no paid keys and no backend of its own.

## What it does

Readiness is one number from 0 to 100, made of four parts that are each measured, never guessed:

| Part | Weight | How it is measured |
|---|---|---|
| Resume | 30% | Resume against a job description: keyword, semantic and rubric scores, with the exact resume line behind each match |
| Interview | 35% | A live voice mock interview with an AI interviewer that knows your resume; every rating carries a verbatim quote |
| Communication | 20% | Pace, filler words and long pauses measured in code from your recorded voice (from interviews and the self-intro) |
| Presence | 15% | Optional camera check: live framing guide, then a written breakdown of posture, eye line and framing |

Home only shows the parts you have actually measured ("readiness 2 of 4"), so an empty score never looks like a low one.

Features:

- **Resume match.** Upload a PDF, paste a job description, get a match score, matched and missing skills, section notes
  and bullet rewrites with `[placeholder]` metrics instead of invented numbers.
- **Live mock interview.** Gemini Live voice interviewer, picks questions from your resume, adapts to your answers.
  Falls back to a quiet question-by-question mode if Live cannot connect. Report, then **Coach Replay**: a scrubbable
  recording with filler and pause markers and a synced transcript.
- **Self-intro coach.** Record a 60-second intro; it is transcribed with fillers kept, rated on clarity, structure and
  confidence, checked for who, what and why, and compared with your last try.
- **Presence check.** On-device face guide (ML Kit), then an AI breakdown. Needs consent and can be skipped.
- **Application tracker.** Six stages with list and drag-and-drop board. Paste a job description and it fills company,
  role and skills, but only values that appear in the pasted text. Follow-up nudges and interview reminders.
- **Progress and scorecard.** Readiness timeline replayed from real results, streak, badges that unlock only from real
  results, and a shareable scorecard image.
- **Demo mode.** A hidden toggle (tap the version number in Settings 7 times) that loads a sample student with three
  weeks of history, kept separate from your own data. See [docs/DEMO.md](docs/DEMO.md).

## Honesty rules

- Every score shows its evidence. A quote the AI returns that is not in your transcript or resume is dropped and the
  rating is capped.
- Nothing is faked: if the AI is unavailable, the app says so instead of showing a made-up result.
- Numbers like pace, fillers and pauses are computed in Dart from the audio, not asked of the model.
- Your data stays on your phone. Only what you send for scoring goes to Gemini. "Delete my data" is in Settings.

## Tech

- Flutter 3.47, Dart, Riverpod 3, go_router
- Firebase AI Logic (Gemini 3.5 Flash and Flash-Lite, Gemini Live) on the free Spark plan
- `record`, `just_audio`, `flutter_pcm_sound` for audio; `camera` and Google ML Kit for the presence guide
- `flutter_local_notifications` for reminders
- Local JSON storage on the device; no server

## Run it

```bash
flutter pub get
flutter run
```

Needs a Firebase project with AI Logic enabled (already wired to `hired-aeb6c`; see `lib/firebase_options.dart`).

```bash
flutter analyze
flutter test
```

## Platforms

- **Android:** developed and tested on an emulator. `flutter build apk --release` makes an installable APK.
- **iOS:** set up (bundle id `com.hired.hired`) and built on Codemagic's cloud Macs, then installed with Sideloadly.
  Not yet tested on a device. See [docs/IOS.md](docs/IOS.md).

## Docs

- [docs/STATUS.md](docs/STATUS.md): what is built and how each part was verified
- [docs/DECISIONS.md](docs/DECISIONS.md): why choices were made (free tier, no backend, and so on)
- [docs/DEMO.md](docs/DEMO.md): how demo mode is produced from the real pipelines
- [docs/IOS.md](docs/IOS.md): running on an iPhone without a Mac
- [docs/plan/roadmap.md](docs/plan/roadmap.md): the build plan

## Project layout

```
lib/
  core/       theme, widgets, storage, audio, AI client, routing
  features/   resume, interview, intro, presence, tracker, progress, home, settings, demo
assets/demo/  scripted recordings, resumes, job descriptions for demo mode
tool/demo/    scripts that generate the demo audio
test/         unit and widget tests
```

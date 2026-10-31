# Hired — Claude Code Build Brief (10 days, demo-first)

> Save as `docs/HIRED_BUILD_PROMPT.md`. Put the Claude Design handoff bundle in `docs/design/`.
> Start Claude Code in the repo root and say:
> **"Read docs/HIRED_BUILD_PROMPT.md and everything in docs/design/. Enter plan mode and produce the Day 1 plan, then execute."**

---

## 0. Mission

Build **Hired**, an AI placement-prep Android app, in **10 days**. The goal is a **jaw-dropping, flawless live demo** and a project that looks far beyond a typical mini project. It will not be published to the Play Store.

Priorities, in order:
1. **The demo path is perfect.** Every screen a viewer sees is polished, animated and reliable.
2. **Real technical depth.** On-device ML, real-time voice AI, a grounded evaluation pipeline. Nothing faked.
3. **All 10 modules complete** (they are in the submitted abstract), every one at a high standard.
4. **No store work.** No billing SDK, ads, Play Console, store listing or store compliance.

**Definition of done:**
- Release APK installed and rehearsed on the demo phone
- All 10 modules working with real AI, polished to the design
- Live voice mock interview with **Coach Replay** working end-to-end, every time
- Landing page live on Vercel (the "working link")
- Backup demo video recorded by Day 8
- `docs/`: architecture diagram, DFD Level 0/1/2, demo script, submission checklist

---

## 1. Design handoff = visual source of truth

The design is finished and lives in `docs/design/`. On Day 1:
1. Read the whole handoff bundle.
2. Write `docs/design/SCREEN_MAP.md`: every designed screen → route name → module (M1–M10) → widgets needed.
3. Extract all tokens into `lib/core/theme/` (ColorScheme light + dark, TextTheme, spacing, radii, motion durations/curves). No hardcoded colours or sizes anywhere else.
4. Build a reusable component library in `lib/core/widgets/` matching the design's components *before* building feature screens.
5. Flag in `SCREEN_MAP.md` any module in this brief that has no designed screen, and any designed screen that isn't covered here.

**Rule:** the design wins on visuals and layout; this brief wins on features and behaviour. If they conflict, stop and ask me.

---

## 2. Tooling setup (Day 1)

### Plugins & skills
```bash
# Official Flutter & Dart plugin from the Flutter team
claude plugin marketplace add flutter/agent-plugins
claude plugin install dart-flutter@dart-flutter

# Opinionated Flutter architecture (Riverpod + GoRouter + Freezed, feature-first)
/plugin marketplace add 9evxxx/flutter-skill
/plugin install flutter-skill@9evxxx-flutter-skill

# Anthropic skills: frontend-design for the landing page
/plugin marketplace add anthropics/skills
```
**flutter-skill** is the architecture authority. Don't stack a second Flutter architecture skill on top of it.

### MCP servers
```bash
# See and drive the emulator/phone: screenshots, taps, UI tree. Visual QA after every feature.
claude mcp add mobile -- npx -y @mobilenext/mobile-mcp@latest

# Firebase project, Firestore, Functions from inside Claude Code
claude mcp add firebase -- npx -y firebase-tools@latest mcp

# Vercel for the landing page
claude mcp add --transport http vercel https://mcp.vercel.com
```

### Reference repos (clone into `/tmp/refs/`, study patterns, never copy wholesale)
| Repo | What to take |
|---|---|
| `srbhr/Resume-Matcher` | Resume ↔ JD matching approach: keyword extraction, key terms, vector similarity |
| `k2-fsa/sherpa-onnx` → `flutter-examples/streaming_asr` | On-device streaming speech recognition in Flutter |
| `suesitran/vertexai_demo` (PR #3) + Firebase AI Logic Live API docs | Gemini Live API in Flutter via `firebase_ai`, including tools and Google Search grounding |
| `JCodesMore/ai-website-cloner-template` | Run `/clone-website` on 2–3 top SaaS landing pages to study **structure, spacing and interactions** into `research/`. Then build an **original** Hired landing page. Never ship a clone. |

---

## 3. Architecture

```
Flutter app (Android, Material 3)
├── UI: Riverpod + GoRouter + Freezed, feature-first
├── On-device intelligence
│   ├── sherpa-onnx streaming ASR → live transcript, filler words, words/min, pauses
│   ├── ML Kit face detection → eye contact %, smile, head pose, face-in-frame
│   └── Audio energy analysis → volume steadiness, long silences
├── Firebase AI Logic (firebase_ai)
│   └── Gemini Live API → real-time voice interviewer (+ Google Search grounding, function calling)
└── Firebase
    ├── Auth (Google sign-in + email fallback)
    ├── Firestore + Storage
    └── Cloud Functions (TypeScript)
        ├── Claude API: PDF resume reading, rubric grading, rewrites, structured scoring
        └── Gemini embeddings: semantic similarity for resume match
```

**Why Cloud Functions in a demo build:** the APK and zip go to faculty, so API keys can't be inside them. Functions need the Firebase **Blaze plan**; enable it on Day 1 with a **₹500 budget alert**. Demo usage stays within free quotas.

### Models (config in `lib/core/config/ai_config.dart` and `functions/src/config.ts`)
- Live interviewer: `gemini-3.1-flash-live-preview` (preview), fallback `gemini-2.5-flash-native-audio-preview-12-2025`
- Deep evaluation, interview report, company prep: `claude-sonnet-5-5`
- Fast scoring (presence, intro, rewrites, tracker autofill): `claude-haiku-5-5`
- Embeddings: `gemini-embedding-001`

### Structured outputs
Every Claude call returns JSON via a **forced tool call** with a strict JSON schema, validated with `zod`, retried once on failure. Never parse free text.

### Evaluation must be grounded
Every score or critique the app shows must cite **evidence**: the transcript line, the resume bullet, or the measured metric it is based on. The UI shows that evidence on tap. This is what separates Hired from "ChatGPT says you're 7/10."

---

## 4. Modules

### M7. AI mock interview — THE SHOWPIECE

**Setup:** role, company (free text), company style (Product/Service/Startup), round (HR / Technical / Managerial), difficulty, 5 questions, language (English / **Hinglish**).

**Company Mode:** if a company is entered, a pre-interview step uses Gemini with Google Search grounding to build a short brief: what the company does, its interview style, recent news. The interviewer then asks company-specific questions. Show this brief on the setup screen with sources.

**Live session:**
- Gemini Live via `firebase_ai`, audio in and out. A realistic Indian campus-placement interviewer persona: one question at a time, one follow-up on vague answers, handles interruptions.
- Questions are grounded in the user's **parsed resume, target role and company brief**, so it asks about their actual projects. This is the wow moment.
- **Adaptive difficulty:** the interviewer uses function calling to log a quick score per answer (`logAnswerSignal`) and steps difficulty up or down.
- In parallel, on-device:
  - **sherpa-onnx** live transcript of the candidate → filler-word and pace chips
  - **ML Kit** on the front camera at about 5 fps → eye contact %, smile, face-in-frame
  - Audio energy → volume steadiness, long-silence detection
- Record the session's **audio and front-camera video locally** (user can turn video off).
- Timestamp every metric into a session timeline.

**After session:**
- `evaluateInterview` (Claude Sonnet) receives the transcript (both sides), per-answer timing, the metric timeline and the company brief.
- Per question: STAR completeness, relevance, depth, clarity (1–5 each), each with an **evidence quote**; what was good, what to fix, a model answer outline.
- Overall: score, top 3 fixes, communication and presence scores.

**Coach Replay** (the second wow moment):
- A replay screen with the recorded video/audio and a scrubbable timeline beneath it.
- Coloured markers on the timeline for filler words, long pauses, eye-contact drops and each question boundary.
- Tap a marker to jump playback there and see the coach note for that moment.
- The transcript scrolls in sync with playback, with filler words highlighted.

**Reliability (mandatory):**
- **Turn-based fallback:** if Live fails, switch automatically to TTS question → record answer → ASR. Same evaluation pipeline. A subtle "Standard mode" label, never an error wall.
- Network drop: one reconnect attempt, then end gracefully and still evaluate the partial session.
- Every completed session is saved, so a real past report and replay can be opened instantly on stage.
- Audio focus, permission denial and Bluetooth/wired earphones are all handled.

### M3. Resume ↔ JD match
Function `matchResume`, a hybrid score modelled on Resume-Matcher:
1. **Keyword coverage (35%).** Claude extracts required/preferred skills from the JD; exact + fuzzy matching (normalised, synonyms) against the parsed resume.
2. **Semantic similarity (35%).** Chunk the resume and JD, embed with `gemini-embedding-001`, take max-cosine per JD requirement, then average.
3. **LLM rubric (30%).** Claude grades relevance, impact (metrics) and ATS formatting.

UI: match %, the three component scores (so the number is explainable), matched/missing keyword chips, per-section feedback with evidence, top 5 fixes, and the staged loading state from the design.

**Multi-JD compare:** paste up to 3 JDs and see which role the resume fits best, side by side.

### M4. AI bullet rewriting
- Tap any bullet → 3 rewrites (action verb + metric + impact, tailored to the JD), as an animated before/after.
- Never invent metrics; use placeholders like `[X%]` and tell the user to fill them.
- **Export:** generate a clean, ATS-friendly resume PDF from the improved content (`pdf` package), shareable from the app.

### M1. Dashboard & Readiness Score
- Readiness 0–100 = Resume 30% · Interview 35% · Communication 20% · Presence 15%, latest result per sub-score with gentle time decay.
- Formula in `lib/core/scoring/readiness.dart`, pure Dart, unit-tested.
- "Next best action" card deep-links to the weakest sub-score's module.
- Animated count-up. After a mock interview, returning Home visibly **raises the score**; this is the demo's closing beat.

### M10. Progress & shareable scorecard
- Score-over-time chart, streak, sessions completed, best-ever stats, badges.
- 1080×1920 scorecard rendered from a widget (`RepaintBoundary` → PNG) via `share_plus`.

### M2. Resume parsing
- `file_picker` → Storage → `parseResume` sends the PDF **directly to Claude as a document block**. Returns structured JSON: contact, education, skills[], experience[] with bullets, projects[], certifications.
- Cache by file hash. Show the parsed resume as an editable structured view.

### M6. Self-intro recorder
- 60-second recording, live sherpa-onnx transcript.
- On-device: filler words (um, uh, like, basically, actually, you know, so), words/min, longest pause, volume steadiness.
- `scoreIntro` (Haiku) → clarity, structure (who/what/why), confidence, rewritten stronger intro, with evidence.
- Compare with the previous attempt: show what improved.

### M5. Presence check
- Camera capture → ML Kit on-device checks (face present, centring, tilt, luminance) → `presenceCheck` (Claude Haiku vision).
- Occasions: Interview / Client Meeting / LinkedIn Photo / Office. Score breakdown: Attire, Grooming, Lighting & Background, Expression, plus 3 fixes.
- Live framing guide overlay in the camera view, driven by ML Kit (it tells you to move closer, centre or improve lighting before you shoot).

### M8. Application tracker
- Stages: Wishlist → Applied → OA → Interview → Offer / Rejected. **Kanban with drag-and-drop** plus a list view.
- Paste JD text → Haiku autofills company, role and key requirements.
- One tap from any application: "Run Resume Match for this job" or "Practise interview for this company" (pre-fills Company Mode).

### M9. Reminders
- `flutter_local_notifications` + `timezone` (Asia/Kolkata).
- Follow-up reminder 5 days after Applied with no update; interview-day reminder plus a "do a warm-up mock" nudge 2 h before. Notification taps deep-link into the right screen.

### Pro / pricing (concept only)
Build the designed paywall as a **static concept screen** (pricing shown; button opens a "Coming soon" sheet) for the business-model slide. No billing or ads SDK.

---

## 5. Demo mode
Hidden toggle (tap version number 7× in Settings) that seeds a believable persona:
- Final-year CSE student, target role SDE-1
- 3 past interview sessions (with replays), resume matches and intros, with a rising score history over 3 weeks
- 6–8 applications across stages, 2 upcoming reminders

Seed data must come from **running the real pipelines** on sample inputs and saving the outputs, never hand-typed results. Sample resume and JDs go in `assets/demo/`.

---

## 6. Landing page (the "working link")
- Next.js + Tailwind, built with the frontend-design skill, in `web/`.
- Original design that matches the app's visual system, informed by the `research/` landing-page study.
- Sections: hero with phone mockup, how it works (3 steps), features, Coach Replay highlight, demo video embed, APK download button.
- Deploy to Vercel via the Vercel MCP.

---

## 7. Packages (verify latest stable on pub.dev)
`firebase_core, firebase_auth, google_sign_in, cloud_firestore, firebase_storage, cloud_functions, firebase_ai, flutter_riverpod, riverpod_annotation, go_router, freezed, json_serializable, camera, google_mlkit_face_detection, record, sherpa_onnx, flutter_tts, video_player, just_audio, file_picker, pdf, printing, fl_chart, share_plus, flutter_local_notifications, timezone, lottie`

Functions: `@anthropic-ai/sdk, @google/genai, zod, firebase-admin, firebase-functions`

**Bundle the sherpa-onnx small English streaming model inside the APK.** A bigger APK is fine; a model download failing on stage is not.

---

## 8. Data model (Firestore)
```
users/{uid}                     profile, targetRole, readiness{score, sub{}}
users/{uid}/resumes/{id}        storagePath, hash, parsed{}
users/{uid}/matches/{id}        resumeId, jds[], scores{}, components{}, keywords{}, fixes[]
users/{uid}/interviews/{id}     config{}, companyBrief{}, transcript[], timeline[], markers[], localMediaPath, evaluation{}, score
users/{uid}/intros/{id}         transcript, metrics{}, evaluation{}
users/{uid}/presence/{id}       occasion, metrics{}, evaluation{}
users/{uid}/applications/{id}   company, role, stage, dates{}, notes, linkedMatchId, linkedInterviewIds[]
users/{uid}/scoreHistory/{date} readiness, sub{}
```
Interview video/audio stays **on the device** (path stored only). Security rules: each user reads and writes only their own tree.

---

## 9. Engineering bar
- Feature-first structure per flutter-skill. No business logic in widgets.
- Unit tests: readiness formula, filler-word detector, eye-contact calculator, timeline marker generation, zod schemas. Golden tests for the score ring and scorecard.
- Function tests against the Firebase emulator.
- GitHub Actions: `flutter analyze` → `flutter test` → build release APK artifact.
- Release build signed with a local keystore (gitignored).
- Skip: flavours, Crashlytics, App Check, billing, ads, store assets.

---

## 10. Working rules for Claude Code
1. **Plan mode first** each day. Write `docs/plan/day-N.md`, then execute.
2. Use **subagents in separate git worktrees** for independent modules; merge at end of day.
3. After each feature: run it and use **mobile-mcp** to screenshot and walk the flow. Compare against the design and fix differences before moving on.
4. Commit at every working milestone.
5. **Never fake an AI response or hardcode a result** to make something look done. If blocked, stop and tell me.
6. Keep `docs/STATUS.md` updated: done / in progress / blocked.
7. End every day with a 5-line summary: what works, what's shaky, tomorrow's first task.

---

## 11. 10-day plan

| Day | Focus |
|---|---|
| **1** | Tooling, design audit + `SCREEN_MAP.md`, theme tokens, component library, Firebase (Blaze + budget alert), Auth with SHA-1s, Functions + secrets, CI |
| **2** | M2 parse, M3 match (incl. multi-JD), M4 rewrite + resume PDF export |
| **3** | M7 core: Gemini Live session, interviewer persona, resume-grounded questions, turn-based fallback |
| **4** | M7 on-device layer: sherpa-onnx live ASR, ML Kit eye contact, audio energy, timeline, local recording. **Test on the demo phone.** |
| **5** | M7 evaluation with evidence, report screen, **Coach Replay**, Company Mode, adaptive difficulty, Hinglish |
| **6** | M1 dashboard + readiness, M10 progress + scorecard, M6 intro recorder |
| **7** | M5 presence check with framing guide, M8 Kanban tracker + cross-links, M9 reminders, paywall concept |
| **8** | Demo mode seeding, full bug bash with mobile-mcp, release APK on the demo phone, **record backup demo video** |
| **9** | Landing page on Vercel, polish pass on every demo-path screen, docs (architecture, DFD L0/1/2 in Mermaid, tech stack, `DEMO_SCRIPT.md`) |
| **10** | **Buffer.** Rehearse the demo 3× and fix every stumble, Android Studio screenshots into `docs/submission/`, final LinkedIn video |

If a day slips, take time from Day 10's buffer, never from Day 8's backup video.

---

## 12. Demo script (`docs/DEMO_SCRIPT.md`, target 2 minutes)
1. Dashboard: Readiness **62**, "Next best action: practise interview"
2. Resume match: resume + JD → staged loading → **71%**, missing keywords → tap a bullet → rewrite
3. Tracker: tap the Google application → "Practise interview for this company" → Company Mode brief appears
4. Live interview: the AI asks about **a project from the resume** and a Google-specific question; filler and eye-contact chips update live
5. Report: per-question scores with evidence quotes
6. **Coach Replay:** scrub to a filler-word marker, hear the moment, see the coach note
7. Home: score animates **62 → 68** → share scorecard

**Demo-day checklist:** phone charged, Do Not Disturb on, own mobile hotspot as backup, app pre-opened and signed in, earphones ready, backup video on the laptop.

---

## 13. Submission checklist (`docs/submission/README.md`)
- [ ] `Project.zip` (no build folders, keystore or secrets)
- [ ] Working link: Vercel landing page
- [ ] Release APK
- [ ] PPT content: problem statement, introduction, solution prototype, DFDs, tech stack, features/USP
- [ ] A3 poster (from Claude Design)
- [ ] LinkedIn post: demo video + Android Studio screenshots

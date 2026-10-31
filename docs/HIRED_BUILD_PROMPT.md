# Hired — Claude Code Build Brief (Demo-First)

> Save as `docs/HIRED_BUILD_PROMPT.md`. Start Claude Code in the repo root and say:
> **"Read docs/HIRED_BUILD_PROMPT.md and docs/design/ (the Claude Design handoff). Enter plan mode, produce the Day 1 plan, then execute."**

---

## 0. Mission

Build **Hired**, an AI placement-prep Android app, in **4 days**. The goal is a **flawless, jaw-dropping live demo**, not a Play Store release.

That changes the priorities:
- **Depth on the hero flows beats breadth.** Every screen a viewer sees must be polished; plumbing nobody sees can be simple.
- **Reliability beats scale.** The demo must work on presentation day, on one specific phone, on whatever Wi-Fi the room has.
- **No store or production work.** No billing, no ads, no Play Console, no store listing, no store compliance.

**Definition of done:**
- Release **APK** installed and rehearsed on the demo phone
- All 10 modules exist and work with real AI (they are in the submitted abstract), with the **hero flows** polished to a high standard
- The **live voice mock interview** works end-to-end, every time
- Demo mode makes the app look lived-in for the video and screenshots
- A recorded backup demo video exists by the end of Day 3
- `docs/` contains architecture diagram, DFDs (Level 0, 1, 2), the demo script and the submission checklist

---

## 1. Module tiers

| Tier | Modules | Standard |
|---|---|---|
| **Hero** (the demo story) | M7 Mock interview, M3 Resume match, M4 Bullet rewrite, M1 Dashboard + Readiness Score, M10 Shareable scorecard | Pixel-perfect to the design, animated, every edge case handled, rehearsed |
| **Supporting** | M2 Resume parsing, M6 Self-intro recorder, M5 Presence check | Fully working, clean UI, basic error handling |
| **Light** | M8 Application tracker, M9 Reminders | Simple and correct: local CRUD + notifications, no fancy extras |

If time runs short, cut polish from Light tier first, never from Hero.

---

## 2. Tooling setup (Day 1, first hour)

### Plugins & skills
```bash
# Official Flutter & Dart plugin from the Flutter team
claude plugin marketplace add flutter/agent-plugins
claude plugin install dart-flutter@dart-flutter

# Opinionated Flutter architecture (Riverpod + GoRouter + Freezed, feature-first)
/plugin marketplace add 9evxxx/flutter-skill
/plugin install flutter-skill@9evxxx-flutter-skill
```
Use **flutter-skill** as the architecture authority. Do not stack a second Flutter architecture skill on top of it.

### MCP servers
```bash
# See and drive the emulator/phone: screenshots, taps, UI tree. Visual QA after every feature.
claude mcp add mobile -- npx -y @mobilenext/mobile-mcp@latest

# Firebase project, Firestore, Functions from inside Claude Code
claude mcp add firebase -- npx -y firebase-tools@latest mcp
```

### Reference repos (clone into `/tmp/refs/`, study patterns, don't copy wholesale)
| Repo | What to take from it |
|---|---|
| `srbhr/Resume-Matcher` | Resume ↔ JD matching approach: keyword extraction, key-term extraction, vector similarity. Port the idea to our function. |
| `k2-fsa/sherpa-onnx` → `flutter-examples/streaming_asr` | On-device streaming speech recognition in Flutter, the basis for live filler-word and pace tracking. |
| `suesitran/vertexai_demo` (PR #3) + Firebase AI Logic Live API docs | Gemini Live API in Flutter via `firebase_ai`, the basis for the live interviewer. |

---

## 3. Architecture

```
Flutter app (Android, Material 3)
├── UI: Riverpod + GoRouter + Freezed, feature-first
├── On-device intelligence
│   ├── sherpa-onnx streaming ASR → live transcript, filler words, words/min, pauses
│   └── Google ML Kit face detection → eye-contact %, smile, head pose, face-in-frame
├── Firebase AI Logic (firebase_ai)
│   └── Gemini Live API → real-time voice interviewer (bidirectional audio)
└── Firebase
    ├── Auth (Google sign-in + email fallback)
    ├── Firestore + Storage
    └── Cloud Functions (TypeScript)
        ├── Claude API: PDF resume reading, rubric grading, rewrites, structured scoring
        └── Gemini embeddings: semantic similarity for resume match
```

**Why keep Cloud Functions in a demo build:** the APK and project zip get handed to faculty, so API keys must not be inside them. Functions keep the Claude key server-side, and the backend makes the architecture slide and DFDs stronger.

Cloud Functions require the Firebase **Blaze plan**. Enable it on Day 1 and set a **budget alert** (e.g. ₹500) in Google Cloud Billing. Usage for a demo stays within free quotas.

### Models
Put model names in `lib/core/config/ai_config.dart` and `functions/src/config.ts`. No Remote Config needed.
- Live interviewer: `gemini-3.1-flash-live-preview` (preview), fallback `gemini-2.5-flash-native-audio-preview-12-2025`
- Deep evaluation + interview report: `claude-sonnet-5-5`
- Fast scoring (presence, intro, rewrites, tracker autofill): `claude-haiku-5-5`
- Embeddings: `gemini-embedding-001`

### Structured outputs
Every Claude call returns JSON via a **forced tool call** with a strict JSON schema. Validate with `zod`. Retry once on schema failure. Never parse free text.

---

## 4. Modules (spec)

### M7. AI mock interview — **THE SHOWPIECE** (Hero)
**Setup:** role, company style (Product/Service/Startup), round (HR/Technical/Managerial), difficulty, 5 questions.

**Live session:**
- Gemini Live session via `firebase_ai`, audio in and out. The system instruction makes it a realistic Indian campus-placement interviewer: one question at a time, one follow-up when an answer is vague, handles interruptions.
- Questions are grounded in the user's **parsed resume and target role**, so it asks about their actual projects. This is the "wow" moment in the demo; make sure it lands.
- In parallel, on-device:
  - **sherpa-onnx** transcribes the candidate's mic → live filler-word and pace chips
  - **ML Kit face detection** on the front camera at about 5 fps → eye-contact % (head yaw/pitch thresholds), smile probability, face-in-frame %
- Every metric is timestamped into a session timeline.

**After session:**
- Function `evaluateInterview` (Claude Sonnet) receives the full transcript, per-answer timing and the metric timeline.
- Per question: STAR completeness, relevance, depth, clarity (1–5 each), what was good, what to fix, model answer outline. Overall: score, top 3 fixes, communication and presence scores.
- Report screen: per-question cards, timeline chart (`fl_chart`) of pace and eye contact, "Practice again".
- Animate the report reveal. This is a screen people will screenshot.

**Demo reliability (mandatory):**
- **Turn-based fallback:** if the Live connection fails, switch automatically to TTS question (`flutter_tts`) → record answer → ASR. Same evaluation pipeline. Show a subtle "Standard mode" label, never an error wall.
- Network drop mid-session: try one reconnect, then end gracefully and still evaluate the partial session.
- Every completed session is saved, so a past **real** report can be opened instantly if the live call can't happen on stage.
- Audio focus, mic/camera permission denial and Bluetooth headsets are handled.

### M3. Resume ↔ JD match (Hero)
Function `matchResume`, a hybrid score modelled on Resume-Matcher:
1. **Keyword coverage (35%).** Claude extracts required/preferred skills from the JD; exact + fuzzy matching (normalised, synonyms) against the parsed resume.
2. **Semantic similarity (35%).** Chunk the resume and JD, embed with `gemini-embedding-001`, take max-cosine per JD requirement, then average.
3. **LLM rubric (30%).** Claude grades relevance, impact (metrics) and ATS formatting.

UI: match %, the three component scores (so the number is explainable), matched/missing keyword chips, per-section feedback, top 5 fixes. Use the staged loading state from the design ("Reading your resume… Comparing with JD… Writing fixes…").

### M4. AI bullet rewriting (Hero)
- Tap any bullet → 3 rewrites (action verb + metric + impact, tailored to JD keywords), shown as an animated before/after.
- Never invent metrics; use placeholders like `[X%]` and tell the user to fill them.

### M1. Dashboard & Readiness Score (Hero)
- Readiness 0–100 = Resume 30% · Interview 35% · Communication 20% · Presence 15%, using the latest result per sub-score.
- Formula in `lib/core/scoring/readiness.dart`, pure Dart, unit-tested.
- "Next best action" card: deep-link to the weakest sub-score's module.
- Animated count-up. After a mock interview, returning Home should visibly **raise the score**; this is the demo's closing beat.

### M10. Progress & shareable scorecard (Hero)
- Score-over-time chart, streak, sessions completed.
- 1080×1920 scorecard rendered from a widget (`RepaintBoundary` → PNG), shared via `share_plus`.

### M2. Resume parsing (Supporting)
- `file_picker` → Storage → function `parseResume` sends the PDF **directly to Claude as a document block**. Returns structured JSON: contact, education, skills[], experience[] with bullets, projects[], certifications.
- Cache in Firestore by file hash.

### M6. Self-intro recorder (Supporting)
- 60-second recording with live sherpa-onnx transcript.
- On-device: filler words (um, uh, like, basically, actually, you know, so), words/min, longest pause.
- Function `scoreIntro` (Haiku) → clarity, structure (who/what/why), confidence, rewritten stronger intro.

### M5. Presence check (Supporting)
- Camera capture → ML Kit on-device checks (face present, centring, tilt, luminance) → `presenceCheck` (Claude Haiku vision).
- Occasions: Interview / Client Meeting / LinkedIn Photo / Office. Score breakdown: Attire, Grooming, Lighting & Background, Expression, plus 3 fixes.

### M8. Application tracker (Light)
- Stages: Wishlist → Applied → OA → Interview → Offer / Rejected. List view with stage chips (Kanban only if time allows).
- Paste JD text → Haiku autofills company, role and key requirements.

### M9. Reminders (Light)
- `flutter_local_notifications` + `timezone` (Asia/Kolkata). Follow-up reminder 5 days after Applied; interview-day reminder with a "do a warm-up mock" nudge.

### Pro / pricing (concept only)
Build the Paywall screen from the design as a **static concept screen** (pricing shown, button opens a "Coming soon" sheet). It supports the business-model slide. No billing SDK, no ads SDK.

---

## 5. Demo mode (Hero-level priority)
Hidden toggle (tap version number 7× in Settings) that seeds a believable persona:
- Final-year CSE student, target role SDE-1
- 2–3 past interview sessions, resume matches and intros with a rising score history over 3 weeks
- 6–8 applications across stages, 2 upcoming reminders

Seed data must be generated by **running the real pipelines once** on sample inputs and saving the outputs, not hand-typed fake results. Store the sample resume and JDs in `assets/demo/`.

---

## 6. Packages (verify latest stable on pub.dev)
`firebase_core, firebase_auth, google_sign_in, cloud_firestore, firebase_storage, cloud_functions, firebase_ai, flutter_riverpod, riverpod_annotation, go_router, freezed, json_serializable, camera, google_mlkit_face_detection, record, sherpa_onnx, flutter_tts, file_picker, fl_chart, share_plus, flutter_local_notifications, timezone, lottie`

Functions: `@anthropic-ai/sdk, @google/genai, zod, firebase-admin, firebase-functions`

**Bundle the sherpa-onnx English streaming model inside the APK** (the small zipformer English model). A larger APK is fine; a first-run model download failing on stage is not.

---

## 7. Data model (Firestore)
```
users/{uid}                     profile, targetRole, readiness{score, sub{}}
users/{uid}/resumes/{id}        storagePath, hash, parsed{}
users/{uid}/matches/{id}        resumeId, jd, score, components{}, keywords{}, fixes[]
users/{uid}/interviews/{id}     config{}, transcript[], timeline[], evaluation{}, score
users/{uid}/intros/{id}         transcript, metrics{}, evaluation{}
users/{uid}/presence/{id}       occasion, metrics{}, evaluation{}
users/{uid}/applications/{id}   company, role, stage, dates{}, notes
users/{uid}/scoreHistory/{date} readiness, sub{}
```
Security rules: each user reads and writes only their own tree. Keep it simple.

---

## 8. Engineering bar (demo-scoped)
- Feature-first structure per flutter-skill. No business logic in widgets.
- Unit tests for: readiness formula, filler-word detector, eye-contact calculator, zod schemas. That's enough.
- `flutter analyze` clean.
- Release build signed with a local keystore (gitignored).
- Skip: CI, flavours, Crashlytics, App Check, billing, ads, rules tests, store assets.

---

## 9. Working rules for Claude Code
1. **Plan mode first** each day. Write `docs/plan/day-N.md`, then execute.
2. Use **subagents in separate git worktrees** for independent modules (e.g. Light/Supporting tier in parallel with the interview engine). Merge at end of day.
3. After each feature: run it and use **mobile-mcp** to screenshot and walk the flow. Fix what looks off before moving on.
4. Implement the design from `docs/design/` faithfully. Tokens go into `lib/core/theme/`.
5. Commit at every working milestone.
6. **Never fake an AI response or hardcode a result** to make something look done. If something is blocked, stop and tell me.
7. Keep `docs/STATUS.md` updated: done / in progress / blocked.

---

## 10. 4-day plan

**Day 1 — Foundation + Resume (Hero)**
- Tooling, Flutter project, theme from design handoff
- Firebase (Blaze + budget alert), Auth (add debug + release SHA-1 for Google sign-in), Firestore, Storage, Functions + `ANTHROPIC_API_KEY` secret
- M2 parse, M3 match, M4 rewrite: polished end-to-end

**Day 2 — The showpiece**
- M7 complete: Gemini Live, sherpa-onnx live ASR, ML Kit eye contact, timeline, evaluation, report
- Turn-based fallback + reconnect handling
- Test on the **actual demo phone**, with earphones and without

**Day 3 — Breadth + demo assets**
- M1 dashboard, M10 scorecard, M6 intro, M5 presence, M8 tracker, M9 reminders, Paywall concept
- Demo mode seeding
- Install release APK on the demo phone, run the full demo script, **record the backup demo video**

**Day 4 — Rehearse, polish, document**
- Rehearse the demo 3× end to end; fix every stumble
- Polish pass on Hero screens: animations, loading states, empty/error states
- `docs/`: architecture diagram, DFD Level 0/1/2 (Mermaid), tech stack, module list, `DEMO_SCRIPT.md`
- Capture Android Studio screenshots (project tree, `main.dart`, emulator running, build output) into `docs/submission/`
- Record the final LinkedIn demo video

---

## 11. Demo script (write into `docs/DEMO_SCRIPT.md`, target 90 seconds)
1. Open the app → Dashboard, Readiness Score **62**, "Next best action: practise interview"
2. Resume match: drop resume + JD → staged loading → **71% match**, missing keywords, tap a bullet → rewrite
3. Mock interview: AI interviewer speaks and asks about **a project from the resume**; answer live while filler-word and eye-contact chips update
4. Report reveal: per-question scores, timeline chart, top 3 fixes
5. Back to Home → score animates **62 → 68**
6. Share scorecard → story card

**Demo-day checklist:** phone charged, Do Not Disturb on, own mobile hotspot as Wi-Fi backup, app pre-opened and signed in, earphones ready, backup video on the laptop.

---

## 12. Submission checklist (`docs/submission/README.md`)
- [ ] `Project.zip` (repo without build folders, keystore or secrets)
- [ ] Working link: none required; optionally a GitHub repo link or the demo video link
- [ ] Release APK
- [ ] PPT content: problem statement, introduction, solution prototype, DFDs, tech stack, features/USP
- [ ] A3 poster (from Claude Design)
- [ ] LinkedIn post: demo video + Android Studio screenshots

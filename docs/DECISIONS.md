# Decisions that differ from the brief

The brief assumed paid services. The project must be free, so:

| Brief | Decision | Why |
|---|---|---|
| Claude via Cloud Functions | **Gemini via `firebase_ai` (Gemini Developer API) called from the app** | Cloud Functions need the Blaze plan; Firebase AI Logic on Spark has a free tier and keeps the API key out of the APK |
| Firebase Storage for PDFs | **PDF bytes go straight to Gemini; only parsed JSON is stored** | New Storage buckets require Blaze |
| `gemini-embedding-001` semantic score | **Per-requirement relevance (0 to 1) with evidence, judged by Gemini; score computed in Dart** | Embeddings are not exposed through Firebase AI Logic; the 35/35/30 blend is kept and unit-tested |
| zod validation | **Gemini `responseSchema` + Dart parsing with one retry** | Same guarantee, no server |
| Function emulator tests | Dropped | No functions |
| Demo phone | **Android emulator (Pixel 7, API 35)**, demo from the laptop screen | No Android device available |
| Models | `gemini-3.5-flash` and `gemini-3.5-flash-lite` in `lib/core/config/ai_config.dart` | One place to change if Google retires a model. `gemini-2.5-flash` was already closed to new projects; `gemini-3.8-flash` timed out; `*-latest` aliases hang |
| App Check | **Unenforced for the demo** | Enforcement rejects every call from an app that sends no token. Add the Play Integrity provider before any public release |
| Billing | **Spark only** | A project with billing attached is treated as paid tier with a prepaid balance of zero, so every call returns 429 |

Free-tier limits: Gemini Developer API has per-minute and per-day request caps. Heavy rehearsal can hit them; the app shows a clear "quota used up" message instead of failing silently.

| Brief | Decision | Why |
|---|---|---|
| sherpa-onnx live ASR | **Gemini Live input/output transcription** | Same session, free, no model download; filler and pace maths stay in Dart |
| ML Kit eye contact in the interview | **Deferred to the presence module (M5)** | The emulator has no real camera; no made-up eye-contact number is shown |
| Audio playback via flutter_soloud | **flutter_pcm_sound (live) + just_audio (replay)** | flutter_soloud builds native code on the host and breaks `flutter test` without Visual Studio C++ tools |
| Claude Sonnet `evaluateInterview` | **Gemini `generateContent` with responseSchema** | Free tier; scores computed in Dart, quotes verified against the transcript |

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
| Self-intro live transcript (sherpa-onnx) | **Record 60 s, then transcribe the WAV with Gemini; level meter shown while recording** | A second live session would burn free-tier quota, and on-device speech recognition fights the recorder for the microphone. Fillers are kept verbatim (probed) and counted in Dart |
| Self-intro pause button | **Dropped; restart and stop only** | A paused minute has no meaning for pace; fewer states to get wrong |
| Typed self-intro | **Added, scored on content only** | Works without a microphone; never counts towards the speaking score or the progress chart |
| Tracker JD autofill (Haiku) | **`gemini-3.5-flash-lite` with responseSchema, then checked against the pasted text in Dart** | Free tier; a field the text does not contain is dropped, not trusted |
| Tracker "Practise interview for this company" pre-fills Company Mode | **Pre-fills role and company only** | Company Mode (Search grounding) is not built yet |
| Tracker follow-up "Draft" button | **Banner opens the application; no drafted message** | Reminders and drafting belong with M9 |
| Reminders: follow-up 5 days after Applied; interview-day plus warm-up 2 h before | **Same, with the interview time set by the user on the application** | Nothing in the app knows an interview time unless the user enters it; no calendar access is requested |
| Timezone | **`Asia/Kolkata` set as the notification zone; times of day come from the device clock** | Matches the brief; scheduling uses absolute instants, so a device in another zone still fires at its own 10:00 |
| Exact alarms | **Used only when Android lets the app; otherwise inexact** | `SCHEDULE_EXACT_ALARM` can be refused on Android 14; a slightly late reminder beats none |
| Presence vision (Claude Haiku) | **Gemini vision via `firebase_ai`, with measurements from ML Kit and the camera frame in Dart** | Free tier; only what the phone cannot measure (clothes, grooming, clutter, expression) is the model's, and the result labels which is which |
| Presence: score rests on appearance | **Only things a person can change in a minute; the model is told never to judge faces or bodies; attire is left out when not visible** | Avoids rating people's looks; no score is invented for what cannot be seen |
| Presence photos | **Kept on the phone, consent before the first send, delete any time, unsaved checks auto-deleted** | A face photo is sensitive; Gemini's free tier may use inputs, so the user is told |
| Presence "save to my score" | **Nothing counts until saved** | Matches the design; a bad test photo should not move the score |
| Intro score | **65% content (clarity, structure, confidence from Gemini, quotes verified) + 35% measured delivery** | Delivery is measured, content is judged; a typed intro is content only |

| Brief | Decision | Why |
|---|---|---|
| Glass: backdrop blur 28 on every card | **Plain translucent fill on cards; real blur only on the tab bar and camera overlays** | A blur of a smooth gradient looks identical, and a live blur per card is the costliest thing a phone can draw. Cards on a screen: 4 to 8 |
| Aurora drifts on an 18 s loop | **Same loop, moved by a 10 Hz timer on a pre-painted layer, one shared clock** | The lights travel about 2 px a second; sixty redraws a second made up nearly all the idle cost |
| Material ripple on tap | **Press-down scale on touch-down, no ripple** | Feedback has to start when the finger lands, not when it lifts |
| Tabs as separate routes | **Indexed stack that keeps each tab alive** | Switching was a cold rebuild that dropped scroll position and half-typed input |
| Platform page transitions | **Cupertino slide and edge-swipe back on all platforms** | One interruptible gesture for going back, the same everywhere |
| Fonts via google_fonts at runtime | **Bundled in `google_fonts/`, runtime fetching off** | No network wait or fallback-font swap on first paint |

| Demo data mixed into the user's data | **Separate `demo/` folder; a switch in Settings repoints every store and restarts the providers** | Real results are never touched and come back exactly when demo mode is off |
| Demo scores typed by hand | **Authored inputs only; the app's own pipelines produce every rating, transcript and measurement** (`lib/dev/demo_forge.dart`) | Same rule as the real app: no number without evidence behind it |
| Demo recordings | **Scripted lines spoken by Windows voices, timestamps taken from the audio actually produced** (`tool/demo/`) | Coach Replay plays real audio offline; pauses and fillers are measured, not placed |
| Presence in the demo persona | **Left unmeasured** | It is the one check worth doing live on stage, and Home then points straight at it |

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
| Models | `gemini-2.5-flash` and `-flash-lite` in `lib/core/config/ai_config.dart` | One place to change if Google retires a model |

Free-tier limits: Gemini Developer API has per-minute and per-day request caps. Heavy rehearsal can hit them; the app shows a clear "quota used up" message instead of failing silently.

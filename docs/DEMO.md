# Demo mode

Settings -> tap the version number 7 times -> Demo mode. The persona is Ishita Rao, final-year CSE at PES University,
targeting SDE-1: three mock interviews with replays (19, 10 and 2 days ago), two spoken intros, three resume matches
(20, 11 and 3 days ago, same job, three versions of the resume), eight applications across stages with two upcoming
interviews. Dates are relative to the moment demo mode is switched on. Presence is left unmeasured so it can be done live.
Everything is on screen labelled "Demo data". The user's own data lives in the normal folder and returns when demo mode is off.

## Where the numbers come from
- Authored inputs: `tool/demo/script.json` (what she says), `assets/demo/resumes.json`, `assets/demo/jds/`.
- `python tool/demo/build_audio.py` speaks the script with two Windows voices and writes `assets/demo/audio/*.wav`,
  `sessions.json` and `intros.json` (turn timestamps are the real lengths of the audio).
- `flutter build apk --debug --dart-define=FORGE_DEMO=true`, install, open the app: `lib/dev/demo_forge.dart` runs the real
  pipelines (resume match, interview evaluation, intro transcription and rating, tracker autofill) and measures pauses and
  delivery from the audio. It writes `demo_fixtures.json` to the app's external files folder. It resumes after a rate limit.
- `adb pull /sdcard/Android/data/com.hired.hired/files/demo_fixtures.json assets/demo/fixtures.json`, then rebuild.
- `DemoSeeder` turns fixtures into stored records at switch-on. Scores, communication and the Home numbers are computed
  from them by the app's normal code.

## Status
Fixtures are NOT generated yet: Gemini currently answers every request with "Firebase App Check token is invalid"
(App Check enforcement is on for Firebase AI Logic). Until fixtures exist, switching demo mode on shows
"Could not set up the demo data" and changes nothing.

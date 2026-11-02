/// Completes when Firebase is ready. `main` starts it and draws the first frame without waiting, so the app
/// opens at once; anything that talks to Gemini awaits this first, and by the time a user has tapped through to
/// an AI feature it has long since finished.
Future<void> firebaseReady = Future<void>.value();

# Running Hired on an iPhone (free, no Mac)

Flutter needs a Mac to build for iOS, so the build happens on Codemagic's cloud Macs (free tier). The result is an
unsigned `.ipa`; Sideloadly on Windows signs it with a free Apple ID and installs it over USB.

Limits of the free route: the install expires after **7 days** (re-install the same way), and it has not been run on an
iPhone yet, so treat the first launch as a test.

## Already done in the repo

- `ios/` platform added (bundle id `com.hired.hired`, iOS 15.5+ for ML Kit face detection).
- iOS app registered in the Firebase project `hired-aeb6c`; its options are in `lib/firebase_options.dart`.
- `Info.plist` has the microphone, camera and photo-library strings; reminders ask for notification permission when a
  reminder first matters, as on Android.
- `codemagic.yaml` builds `Hired-unsigned.ipa`.

## Steps

1. Put the project in a private GitHub repo (Codemagic builds from a repo).
2. codemagic.io, sign in with GitHub, add the repo, pick the `ios-unsigned` workflow, Start build. About 10 to 15 minutes.
3. Download `Hired-unsigned.ipa` from the build's artifacts.
4. On Windows, install iTunes and iCloud from apple.com (not the Microsoft Store versions) and Sideloadly.
5. Plug in the iPhone, trust the computer, drag the `.ipa` into Sideloadly, enter your Apple ID, Start.
6. On the phone: Settings, General, VAT & Device Management, trust your Apple ID. Turn on Developer Mode if asked
   (Settings, Privacy & Security).
7. Open Hired, tap the version number in Settings 7 times, switch Demo mode on.

## Likely first-run problems

- A plugin that behaves differently on iOS (ML Kit face guide, `flutter_pcm_sound`, `record`, haptics). Send the
  Codemagic log or what you see and it gets fixed.
- Gemini calls need App Check to stay unenforced for the iOS app too (it is project-wide).

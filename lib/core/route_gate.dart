const _splash = '/splash';
const _onboarding = '/onboarding';
const _signIn = '/sign-in';
const _profile = '/profile-setup';

bool _under(String location, String root) => location == root || location.startsWith('$root/');

/// Where the router should send someone, or null to let them stay. First launch: slides, then sign-in, then the app.
/// Demo mode skips all of it so a demo never stops at a login screen.
String? gateRedirect({
  required String location,
  required bool demo,
  required bool onboarded,
  required bool authed,
}) {
  final onEntry = _under(location, _splash) || _under(location, _onboarding) || _under(location, _signIn);
  if (demo) return onEntry ? '/home' : null;
  if (_under(location, _splash)) return null;
  if (!onboarded) return _under(location, _onboarding) ? null : _onboarding;
  if (!authed) return _under(location, _signIn) || _under(location, _onboarding) ? null : _signIn;
  // Signed in: the entry screens lead nowhere, but profile setup is reached from them and from Settings.
  if (onEntry) return '/home';
  if (_under(location, _profile)) return null;
  return null;
}

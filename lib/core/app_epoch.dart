import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Bumped to throw every provider away and start again, which is how the app moves between real and demo data:
/// each store reads its folder afresh instead of needing to be told.
final appEpoch = ValueNotifier<int>(0);

/// Back to Home with every provider rebuilt from disk.
void restartApp(GoRouter router) {
  router.go('/home');
  appEpoch.value++;
}

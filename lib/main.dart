import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: HiredApp()));
}

class HiredApp extends StatelessWidget {
  const HiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Hired',
      debugShowCheckedModeBanner: false,
      theme: buildHiredTheme(),
      routerConfig: router,
    );
  }
}

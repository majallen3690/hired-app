import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/theme/app_theme.dart';
import 'package:hired/features/intro/data/intro_store.dart';
import 'package:hired/features/intro/domain/intro_models.dart';
import 'package:hired/features/intro/ui/intro_result_screen.dart';

const _json = '''
{"id":"intro-1","startedAt":"2026-11-02T15:57:19.396766Z","durationMs":0,"mode":"typed",
"transcript":"Hi I am Ishita a final year computer science student at PES University. Um I built a campus attendance app.",
"target":"SDE","delivery":null,
"evaluation":{"headline":"Clear intro needing stronger role alignment",
"clarity":{"score":3,"evidence":"I built a campus attendance app"},
"structure":{"score":3,"evidence":"Hi I am Ishita"},
"confidence":{"score":2,"evidence":null},
"who":{"covered":true,"evidence":"Hi I am Ishita","note":"Mentioned name."},
"what":{"covered":true,"evidence":"I built a campus attendance app","note":"Built an app."},
"why":{"covered":false,"evidence":null,"note":"No reason given."},
"good":"Clear identity.","fix":"Add why.","stronger":"Hi, I am Ishita. I built [X] things."},
"audioFile":null,"failed":null}
''';

void main() {
  testWidgets('the result screen renders a scored typed intro', (tester) async {
    final record = IntroRecord.fromJson(jsonDecode(_json) as Map<String, dynamic>);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        introProvider('intro-1').overrideWith((ref) async => record),
        introsProvider.overrideWith((ref) async => [record]),
      ],
      child: MaterialApp(
        theme: buildHiredTheme(Brightness.dark),
        home: const IntroResultScreen(id: 'intro-1'),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Intro score'), findsOneWidget);
    expect(find.text('Who, what, why'.toUpperCase()), findsOneWidget);
  });
}

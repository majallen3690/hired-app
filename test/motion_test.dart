import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/motion/motion.dart';
import 'package:hired/core/theme/app_theme.dart';
import 'package:hired/core/widgets/controls.dart';
import 'package:hired/core/widgets/glass.dart';

Widget host(Widget child, {bool reduce = false}) => MaterialApp(
      theme: buildHiredTheme(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: Center(child: child)),
      ),
    );

double scaleOf(WidgetTester tester) => tester
    .widget<Transform>(find.descendant(of: find.byType(PressScale), matching: find.byType(Transform)))
    .transform
    .entry(0, 0);

void main() {
  group('PressScale', () {
    testWidgets('shrinks the moment a finger lands and springs back on release', (tester) async {
      await tester.pumpWidget(host(const PressScale(child: SizedBox(width: 120, height: 60))));
      expect(scaleOf(tester), 1.0);

      final g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(scaleOf(tester), closeTo(0.97, 0.005));

      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scaleOf(tester), 1.0);
    });

    testWidgets('lets go when the finger slides away, so scrolling never leaves it pressed', (tester) async {
      await tester.pumpWidget(host(const PressScale(child: SizedBox(width: 120, height: 60))));
      final g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(scaleOf(tester), lessThan(0.99));

      await g.moveBy(const Offset(0, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scaleOf(tester), 1.0);
      await g.up();
    });

    testWidgets('survives being removed while a finger is still down on it', (tester) async {
      await tester.pumpWidget(host(const PressScale(child: SizedBox(width: 120, height: 60))));
      final g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      await tester.pumpWidget(host(const SizedBox()));
      await g.moveBy(const Offset(0, 60));
      await g.up();
      expect(tester.takeException(), isNull);
    });

    testWidgets('does nothing while disabled', (tester) async {
      await tester.pumpWidget(host(const PressScale(enabled: false, child: SizedBox(width: 120, height: 60))));
      final g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(scaleOf(tester), 1.0);
      await g.up();
    });

    testWidgets('under reduced motion it dims instead of moving', (tester) async {
      await tester.pumpWidget(host(const PressScale(child: SizedBox(width: 120, height: 60)), reduce: true));
      final g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final opacity = tester.widget<Opacity>(find.descendant(of: find.byType(PressScale), matching: find.byType(Opacity)));
      expect(opacity.opacity, lessThan(0.9));
      expect(find.descendant(of: find.byType(PressScale), matching: find.byType(Transform)), findsNothing);
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Reveal', () {
    double opacityOf(WidgetTester tester) =>
        tester.widget<FadeTransition>(find.descendant(of: find.byType(Reveal), matching: find.byType(FadeTransition))).opacity.value;

    testWidgets('fades in from nothing and settles fully visible', (tester) async {
      await tester.pumpWidget(host(const Reveal(child: Text('hello'))));
      expect(opacityOf(tester), 0.0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacityOf(tester), inExclusiveRange(0.0, 1.0));
      await tester.pump(const Duration(seconds: 1));
      // Done: the wrapper steps out of the tree entirely.
      expect(find.descendant(of: find.byType(Reveal), matching: find.byType(FadeTransition)), findsNothing);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('later items start later, so a column cascades', (tester) async {
      await tester.pumpWidget(host(const Column(children: [
        Reveal(index: 0, child: Text('first')),
        Reveal(index: 3, child: Text('fourth')),
      ])));
      double op(String text) => tester
          .widget<FadeTransition>(find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)).first)
          .opacity
          .value;
      await tester.pump(const Duration(milliseconds: 120));
      expect(op('first'), greaterThan(0));
      // The fourth item has 150 ms to wait out first, so it is still invisible at 120 ms.
      expect(op('fourth'), 0.0);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('items past the cap appear at once instead of making a long list wait', (tester) async {
      await tester.pumpWidget(host(const Reveal(index: Reveal.maxStaggered, child: Text('far down'))));
      expect(find.descendant(of: find.byType(Reveal), matching: find.byType(FadeTransition)), findsNothing);
      expect(find.text('far down'), findsOneWidget);
    });

    testWidgets('under reduced motion it fades without moving', (tester) async {
      await tester.pumpWidget(host(const Reveal(child: Text('calm')), reduce: true));
      await tester.pump(const Duration(milliseconds: 40));
      final move = tester.widget<Transform>(find.descendant(of: find.byType(Reveal), matching: find.byType(Transform)));
      expect(move.transform.getTranslation().y, 0.0);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('revealed() staggers real children and leaves bare spacers alone', (tester) async {
      final out = <Widget>[const Text('a'), const SizedBox(height: 12), const Text('b')].revealed();
      expect(out.whereType<Reveal>().map((r) => r.index), [0, 1]);
      expect(out[1], isA<SizedBox>());
    });
  });

  group('DelayedSpinner', () {
    testWidgets('stays out of sight through a quick load, then appears for a real wait', (tester) async {
      await tester.pumpWidget(host(const DelayedSpinner()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      // Leave the tree before the spinner's own animation can outlive the test.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a load that ends first never shows it at all', (tester) async {
      await tester.pumpWidget(host(const DelayedSpinner()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Segmented', () {
    testWidgets('one thumb slides to the chosen option and the choice is reported once', (tester) async {
      var value = 'a';
      await tester.pumpWidget(host(StatefulBuilder(
        builder: (context, set) => Segmented<String>(
          options: const {'a': 'Dark', 'b': 'Light', 'c': 'System'},
          value: value,
          onChanged: (v) => set(() => value = v),
        ),
      )));
      await tester.tap(find.text('System'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(value, 'c');
      expect(tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment, Alignment.centerRight);
    });
  });

  group('Aurora', () {
    double drift(WidgetTester tester) => tester
        .widgetList<Transform>(find.descendant(of: find.byType(Aurora), matching: find.byType(Transform)))
        .first
        .transform
        .getTranslation()
        .y;

    testWidgets('drifts slowly, and without a per-frame ticker keeping the screen redrawing', (tester) async {
      await tester.pumpWidget(host(const SizedBox(width: 300, height: 300, child: Aurora(child: SizedBox()))));
      final before = drift(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(drift(tester), isNot(before));
      // Between its ten-a-second updates nothing is asking for a frame; a vsync ticker would be.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('holds still, and asks for no frames at all, under reduced motion', (tester) async {
      await tester.pumpWidget(host(const SizedBox(width: 300, height: 300, child: Aurora(child: SizedBox())), reduce: true));
      final before = drift(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(drift(tester), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('AnimatedBar', () {
    double fill(WidgetTester tester) => tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value!;

    testWidgets('fills from empty the first time and glides to a new value', (tester) async {
      Widget bar(double v) =>
          host(SizedBox(width: 200, child: AnimatedBar(value: v, color: Colors.green, backgroundColor: Colors.grey)));
      await tester.pumpWidget(bar(0.8));
      expect(fill(tester), 0.0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(fill(tester), inExclusiveRange(0.0, 0.8));
      await tester.pump(const Duration(seconds: 1));
      expect(fill(tester), closeTo(0.8, 0.001));

      await tester.pumpWidget(bar(0.3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fill(tester), inExclusiveRange(0.3, 0.8));
      await tester.pump(const Duration(seconds: 1));
      expect(fill(tester), closeTo(0.3, 0.001));
    });

    testWidgets('is already full under reduced motion', (tester) async {
      await tester.pumpWidget(host(
        SizedBox(width: 200, child: AnimatedBar(value: 0.6, color: Colors.green, backgroundColor: Colors.grey)),
        reduce: true,
      ));
      expect(fill(tester), closeTo(0.6, 0.001));
    });
  });

  group('PhaseSwitcher', () {
    testWidgets('fades between states, keeps the screen full-size, and drops the old one when done', (tester) async {
      Widget at(String phase) => host(SizedBox(
            width: 300,
            height: 500,
            child: PhaseSwitcher(phase: phase, child: Column(children: [Text('state $phase'), const Spacer()])),
          ));
      await tester.pumpWidget(at('a'));
      await tester.pumpWidget(at('b'));
      await tester.pump(const Duration(milliseconds: 100));
      // Both are on screen mid-change.
      expect(find.text('state a'), findsOneWidget);
      expect(find.text('state b'), findsOneWidget);
      // Tight constraints survive: the Spacer would throw if the child were given unbounded height.
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('state a'), findsNothing);
      expect(find.text('state b'), findsOneWidget);
    });

    testWidgets('does not animate when the state has not changed', (tester) async {
      Widget at(String label) => host(SizedBox(
            width: 300,
            height: 500,
            child: PhaseSwitcher(phase: 'live', child: Text(label)),
          ));
      await tester.pumpWidget(at('one'));
      await tester.pumpWidget(at('two'));
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsOneWidget);
    });
  });
}


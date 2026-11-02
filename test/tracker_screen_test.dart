import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hired/core/theme/app_theme.dart';
import 'package:hired/features/tracker/data/application_store.dart';
import 'package:hired/features/tracker/domain/application_models.dart';
import 'package:hired/features/tracker/ui/add_application_screen.dart';
import 'package:hired/features/tracker/ui/application_detail_screen.dart';
import 'package:hired/features/tracker/ui/tracker_screen.dart';

class _Fake extends ApplicationsNotifier {
  _Fake(this.items);
  final List<JobApplication> items;

  @override
  Future<List<JobApplication>> build() async => items;
}

JobApplication app(String company, Stage stage, {int daysAgo = 0, String jd = ''}) {
  final at = DateTime.now().subtract(Duration(days: daysAgo));
  return JobApplication(
    id: company,
    company: company,
    role: 'SDE-1',
    stage: stage,
    createdAt: at,
    stageChangedAt: at,
    jd: jd,
    skills: const ['Java', 'Kafka'],
  );
}

Widget host(List<JobApplication> items, Widget child) => ProviderScope(
      overrides: [applicationsProvider.overrideWith(() => _Fake(items))],
      child: MaterialApp(theme: buildHiredTheme(Brightness.dark), home: Scaffold(body: child)),
    );

void main() {
  final apps = [
    app('Zoho', Stage.interview),
    app('Swiggy', Stage.applied, daysAgo: 6),
    app('Google', Stage.wishlist),
    app('PhonePe', Stage.rejected, daysAgo: 2),
  ];

  testWidgets('the list shows every company, the stage filters and a follow-up nudge', (tester) async {
    await tester.pumpWidget(host(apps, const TrackerScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('4 companies'), findsOneWidget);
    for (final name in ['Zoho', 'Swiggy', 'Google', 'PhonePe']) {
      expect(find.text(name), findsWidgets);
    }
    expect(find.text('Follow up with Swiggy'), findsOneWidget);
    expect(find.text('6 days since you applied'), findsOneWidget);
  });

  testWidgets('a stage filter narrows the list', (tester) async {
    await tester.pumpWidget(host(apps, const TrackerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interview 1'));
    await tester.pumpAndSettle();
    expect(find.text('Zoho'), findsOneWidget);
    expect(find.text('PhonePe'), findsNothing);
  });

  testWidgets('the board has a column for every stage', (tester) async {
    await tester.pumpWidget(host(apps, const TrackerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);
    // The board scrolls sideways, so only the columns on screen are built.
    expect(find.text('Google'), findsOneWidget);
  });

  testWidgets('dragging a card to another column moves it', (tester) async {
    final container = ProviderContainer(overrides: [applicationsProvider.overrideWith(() => _Fake(apps))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildHiredTheme(Brightness.dark), home: const Scaffold(body: TrackerScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();

    final card = find.text('Google');
    final target = find.text('OA');
    final drag = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveTo(tester.getCenter(target) + const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 100));
    await drag.up();
    await tester.pumpAndSettle();

    final moved = container.read(applicationsProvider).value!.firstWhere((a) => a.company == 'Google');
    expect(moved.stage, Stage.oa);
  });

  testWidgets('with nothing tracked the empty state invites a first application', (tester) async {
    await tester.pumpWidget(host(const [], const TrackerScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Paste a job description'), findsOneWidget);
    expect(find.text('Add it manually'), findsOneWidget);
  });

  testWidgets('the detail screen offers both cross-links; the match needs a job description', (tester) async {
    await tester.pumpWidget(host([app('Zoho', Stage.interview)], const ApplicationDetailScreen(id: 'Zoho')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Run resume match for this job'), findsOneWidget);
    expect(find.text('Practise interview for Zoho'), findsOneWidget);
    expect(find.text('Add the job description below to run a match.'), findsOneWidget);
  });

  testWidgets('a saved job description enables the match', (tester) async {
    final jd = 'We are hiring a backend engineer. ' * 4;
    await tester.pumpWidget(host([app('Zoho', Stage.interview, jd: jd)], const ApplicationDetailScreen(id: 'Zoho')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Add the job description below to run a match.'), findsNothing);
  });

  testWidgets('the add screen needs a company before it can save', (tester) async {
    // A tall screen, so the whole lazily built form is on screen.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const [], const AddApplicationScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'For example Razorpay').first, 'Razorpay');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hired/features/tracker/domain/application_models.dart';
import 'package:hired/features/tracker/domain/reminder_rules.dart';

DateTime d(int day, [int hour = 12, int minute = 0]) => DateTime(2026, 11, day, hour, minute);

JobApplication app(
  String id,
  Stage stage, {
  DateTime? changed,
  DateTime? interviewAt,
  String company = 'Zoho',
  String role = 'MTS',
}) =>
    JobApplication(
      id: id,
      company: company,
      role: role,
      stage: stage,
      createdAt: changed ?? d(1),
      stageChangedAt: changed ?? d(1),
      interviewAt: interviewAt,
    );

void main() {
  group('follow-up', () {
    test('arrives at 10:00, five days after applying', () {
      final r = buildReminders([app('a', Stage.applied, changed: d(2, 21, 30))], d(3));
      expect(r.length, 1);
      expect(r.single.kind, ReminderKind.followUp);
      expect(r.single.at, d(7, 10));
      expect(r.single.title, 'Follow up with Zoho');
      expect(r.single.payload, 'app:a');
    });

    test('counts calendar days, so applying late at night does not shorten the wait', () {
      final late = buildReminders([app('a', Stage.applied, changed: d(2, 23, 59))], d(3)).single;
      final early = buildReminders([app('b', Stage.applied, changed: d(2, 0, 1))], d(3)).single;
      expect(late.at, early.at);
    });

    test('works across a month boundary', () {
      final r = buildReminders([app('a', Stage.applied, changed: DateTime(2026, 10, 29, 9))], DateTime(2026, 10, 30)).single;
      expect(r.at, DateTime(2026, 11, 3, 10));
    });

    test('nothing is scheduled once the moment has passed; the in-app banner covers it', () {
      expect(buildReminders([app('a', Stage.applied, changed: d(1))], d(20)), isEmpty);
    });

    test('only for applications you are waiting on', () {
      for (final s in [Stage.wishlist, Stage.oa, Stage.interview, Stage.offer, Stage.rejected]) {
        expect(buildReminders([app('a', s, changed: d(2))], d(3)).where((r) => r.kind == ReminderKind.followUp), isEmpty,
            reason: s.name);
      }
    });

    test('moving on to the next stage removes it', () {
      final waiting = app('a', Stage.applied, changed: d(2));
      expect(buildReminders([waiting], d(3)), isNotEmpty);
      expect(buildReminders([waiting.copyWith(stage: Stage.oa)], d(3)), isEmpty);
    });
  });

  group('interview', () {
    test('a note at 8:00 that day and a warm-up two hours before', () {
      final r = buildReminders([app('a', Stage.interview, interviewAt: d(5, 10, 30))], d(3));
      expect(r.map((x) => x.kind), [ReminderKind.interviewDay, ReminderKind.warmUp]);
      expect(r[0].at, d(5, 8));
      expect(r[1].at, d(5, 8, 30));
      expect(r[0].title, 'Interview today: Zoho');
      expect(r[0].body, 'MTS · at 10:30 am');
      expect(r[1].payload, 'warmup:a');
      expect(r[1].body, contains('10:30 am'));
    });

    test('an interview already under way or past gets nothing', () {
      expect(buildReminders([app('a', Stage.interview, interviewAt: d(5, 10))], d(5, 10, 1)), isEmpty);
    });

    test('less than two hours out and past the morning, nothing is left to schedule', () {
      final r = buildReminders([app('a', Stage.interview, interviewAt: d(5, 10))], d(5, 9));
      expect(r, isEmpty);
    });

    test('a morning interview still gets its warm-up before the morning note', () {
      final r = buildReminders([app('a', Stage.interview, interviewAt: d(5, 9))], d(3));
      expect(r.map((x) => x.kind), [ReminderKind.warmUp, ReminderKind.interviewDay]);
      expect(r.first.at, d(5, 7));
    });

    test('an interview at 7:30 has no 8:00 note, which would come after it', () {
      final r = buildReminders([app('a', Stage.interview, interviewAt: d(5, 7, 30))], d(3));
      expect(r.map((x) => x.kind), [ReminderKind.warmUp]);
    });

    test('applications that are over get no interview reminders', () {
      for (final s in [Stage.offer, Stage.rejected, Stage.wishlist]) {
        expect(buildReminders([app('a', s, interviewAt: d(9, 10))], d(3)), isEmpty, reason: s.name);
      }
    });

    test('an online test set on an application still at OA counts too', () {
      final r = buildReminders([app('a', Stage.oa, interviewAt: d(9, 15))], d(3));
      expect(r.length, 2);
    });

    test('a missing role leaves the body clean', () {
      final r = buildReminders([app('a', Stage.interview, role: '', interviewAt: d(5, 10))], d(3));
      expect(r.first.body, 'at 10:00 am');
    });
  });

  group('the whole list', () {
    test('is soonest first across applications', () {
      final r = buildReminders([
        app('late', Stage.applied, changed: d(10)),
        app('soon', Stage.interview, interviewAt: d(5, 14)),
      ], d(3));
      final times = r.map((x) => x.at).toList();
      expect([...times]..sort(), times);
    });

    test('ids are stable, distinct per kind and fit a 32-bit notification id', () {
      expect(reminderId('app-123', ReminderKind.warmUp), reminderId('app-123', ReminderKind.warmUp));
      final ids = {for (final k in ReminderKind.values) reminderId('app-123', k)};
      expect(ids.length, ReminderKind.values.length);
      expect(reminderId('app-1793636811603286', ReminderKind.followUp), lessThan(1 << 31));
      expect(reminderId('a', ReminderKind.followUp), isNot(reminderId('b', ReminderKind.followUp)));
    });

    test('no applications, no reminders', () {
      expect(buildReminders(const [], d(3)), isEmpty);
    });
  });

  group('labels', () {
    test('clock and date read naturally', () {
      expect(clockLabel(d(5, 0, 5)), '12:05 am');
      expect(clockLabel(d(5, 12)), '12:00 pm');
      expect(clockLabel(d(5, 15, 45)), '3:45 pm');
      expect(dateTimeLabel(d(3, 10, 30)), 'Tue 3 Nov, 10:30 am');
    });
  });

  group('saving the interview time', () {
    test('survives a JSON round trip and can be cleared', () {
      final a = app('a', Stage.interview, interviewAt: d(5, 10, 30));
      final back = JobApplication.fromJson(a.toJson());
      expect(back.interviewAt!.isAtSameMomentAs(d(5, 10, 30)), isTrue);
      expect(a.copyWith(clearInterviewAt: true).interviewAt, isNull);
    });

    test('an older saved file with no interview time still loads', () {
      final j = app('a', Stage.applied).toJson()..remove('interviewAt');
      expect(JobApplication.fromJson(j).interviewAt, isNull);
    });
  });
}

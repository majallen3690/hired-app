import 'application_models.dart';
import 'tracker_logic.dart';

enum ReminderKind { followUp, interviewDay, warmUp }

extension ReminderKindLabel on ReminderKind {
  String get label => switch (this) {
        ReminderKind.followUp => 'Follow-up',
        ReminderKind.interviewDay => 'Interview day',
        ReminderKind.warmUp => 'Warm-up mock',
      };
}

/// What time of day each reminder arrives.
const followUpHour = 10;
const interviewDayHour = 8;

/// The warm-up nudge comes this long before the interview.
const warmUpLead = Duration(hours: 2);

class Reminder {
  const Reminder({
    required this.id,
    required this.appId,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String appId;
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// Tells the app where a tap should go: `app:<id>` opens the application, `warmup:<id>` opens a mock interview.
  final String payload;
}

/// A stable 30-bit notification id for one application and kind. Dart's `String.hashCode` changes between runs, so
/// this uses FNV-1a: the same application must always map to the same id, or old reminders could never be cancelled.
int reminderId(String appId, ReminderKind kind) {
  var h = 0x811c9dc5;
  for (final unit in appId.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return ((h & 0x0FFFFFFF) << 2) | kind.index;
}

String clockLabel(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Mon 3 Nov, 10:30 am"
String dateTimeLabel(DateTime t) {
  final l = t.toLocal();
  return '${_weekdays[l.weekday - 1]} ${l.day} ${_months[l.month - 1]}, ${clockLabel(l)}';
}

/// Every reminder that is still in the future, soonest first. Rebuilt from the applications each time, so a moved or
/// removed application can never leave a stale reminder behind.
///
/// - Applied: a follow-up at 10:00, five days after it moved to Applied.
/// - An interview or test time set on an application still in play: a note at 8:00 that day and a warm-up mock two
///   hours before.
List<Reminder> buildReminders(List<JobApplication> apps, DateTime now) {
  final out = <Reminder>[];
  for (final a in apps) {
    Reminder make(ReminderKind kind, DateTime at, String title, String body, String payload) => Reminder(
          id: reminderId(a.id, kind),
          appId: a.id,
          kind: kind,
          at: at,
          title: title,
          body: body,
          payload: payload,
        );

    if (a.stage == Stage.applied) {
      final base = a.stageChangedAt.toLocal();
      final at = DateTime(base.year, base.month, base.day + followUpAfterDays, followUpHour);
      if (at.isAfter(now)) {
        out.add(make(
          ReminderKind.followUp,
          at,
          'Follow up with ${a.company}',
          'It has been $followUpAfterDays days since you applied. A short, polite note keeps you in view.',
          'app:${a.id}',
        ));
      }
    }

    final interview = a.interviewAt?.toLocal();
    final live = a.stage == Stage.applied || a.stage == Stage.oa || a.stage == Stage.interview;
    if (interview != null && live) {
      final detail = a.role.isEmpty ? 'at ${clockLabel(interview)}' : '${a.role} · at ${clockLabel(interview)}';

      final morning = DateTime(interview.year, interview.month, interview.day, interviewDayHour);
      if (morning.isAfter(now) && morning.isBefore(interview)) {
        out.add(make(ReminderKind.interviewDay, morning, 'Interview today: ${a.company}', detail, 'app:${a.id}'));
      }

      final warmUp = interview.subtract(warmUpLead);
      if (warmUp.isAfter(now)) {
        out.add(make(
          ReminderKind.warmUp,
          warmUp,
          'Warm up for ${a.company}',
          'Your interview is at ${clockLabel(interview)}. A 10-minute mock now keeps you sharp.',
          'warmup:${a.id}',
        ));
      }
    }
  }
  out.sort((x, y) => x.at.compareTo(y.at));
  return out;
}

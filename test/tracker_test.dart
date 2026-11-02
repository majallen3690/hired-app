import 'package:flutter_test/flutter_test.dart';
import 'package:hired/features/tracker/domain/application_models.dart';
import 'package:hired/features/tracker/domain/tracker_logic.dart';

DateTime d(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);

JobApplication app(String company, Stage stage, DateTime changed, {String role = 'SDE-1', String id = ''}) =>
    JobApplication(
      id: id.isEmpty ? company : id,
      company: company,
      role: role,
      stage: stage,
      createdAt: changed,
      stageChangedAt: changed,
    );

const jd = '''
Razorpay is hiring a Software Development Engineer I for the Payments Platform team.
You will build services in Java and Kotlin, work with PostgreSQL and Kafka, and ship on AWS.
''';

void main() {
  group('days and labels', () {
    test('counts calendar days, not 24 hour blocks', () {
      expect(daysBetween(DateTime(2026, 11, 1, 23, 59), DateTime(2026, 11, 2, 0, 1)), 1);
      expect(daysBetween(DateTime(2026, 11, 2, 8), DateTime(2026, 11, 2, 22)), 0);
    });

    test('is right across a month boundary', () {
      expect(daysBetween(DateTime(2026, 10, 30), DateTime(2026, 11, 2)), 3);
    });

    test('reads naturally', () {
      final now = d(20);
      expect(agoLabel(d(20, 8), now), 'today');
      expect(agoLabel(d(19), now), 'yesterday');
      expect(agoLabel(d(15), now), '5 days ago');
      expect(agoLabel(d(1), now), '3 weeks ago');
    });

    test('the line under a company says what happened and when', () {
      final now = d(20);
      expect(whenLabel(app('A', Stage.applied, d(15)), now), 'Applied 5 days ago');
      expect(whenLabel(app('A', Stage.wishlist, d(20)), now), 'Saved today');
      expect(whenLabel(app('A', Stage.rejected, d(19)), now), 'Closed yesterday');
    });

    test('the tile letter handles blanks', () {
      expect(companyInitial('  zoho'), 'Z');
      expect(companyInitial(''), '?');
    });
  });

  group('moving between stages', () {
    test('a move restarts the clock for that stage', () {
      final a = app('Zoho', Stage.applied, d(1));
      final moved = moveTo(a, Stage.oa, d(9));
      expect(moved.stage, Stage.oa);
      expect(moved.stageChangedAt, d(9));
      expect(moved.createdAt, d(1));
    });

    test('dropping on the same stage changes nothing', () {
      final a = app('Zoho', Stage.applied, d(1));
      expect(identical(moveTo(a, Stage.applied, d(9)), a), isTrue);
    });
  });

  group('lists', () {
    final apps = [
      app('Google', Stage.wishlist, d(10)),
      app('PhonePe', Stage.rejected, d(11)),
      app('Zoho', Stage.interview, d(12)),
      app('Swiggy', Stage.applied, d(5)),
      app('Freshworks', Stage.applied, d(8)),
    ];

    test('counts every stage, including empty ones', () {
      final c = stageCounts(apps);
      expect(c[Stage.applied], 2);
      expect(c[Stage.offer], 0);
      expect(c.length, Stage.values.length);
    });

    test('a column shows the newest move first', () {
      expect(inStage(apps, Stage.applied).map((a) => a.company), ['Freshworks', 'Swiggy']);
    });

    test('the list puts live interviews first and rejections last', () {
      final order = byUrgency(apps).map((a) => a.company).toList();
      expect(order.first, 'Zoho');
      expect(order.last, 'PhonePe');
      expect(order.indexOf('Freshworks'), lessThan(order.indexOf('Swiggy')));
    });
  });

  group('follow-ups', () {
    test('suggested once five days have passed since applying, longest wait first', () {
      final apps = [
        app('Freshworks', Stage.applied, d(14)),
        app('Swiggy', Stage.applied, d(10)),
        app('New', Stage.applied, d(16)),
      ];
      expect(followUps(apps, d(19)).map((a) => a.company), ['Swiggy', 'Freshworks']);
    });

    test('only applications you are waiting on', () {
      final apps = [
        app('A', Stage.wishlist, d(1)),
        app('B', Stage.interview, d(1)),
        app('C', Stage.rejected, d(1)),
      ];
      expect(followUps(apps, d(20)), isEmpty);
    });

    test('moving to a new stage clears it', () {
      final waiting = app('Swiggy', Stage.applied, d(1));
      expect(followUps([moveTo(waiting, Stage.oa, d(19))], d(20)), isEmpty);
    });
  });

  group('duplicates', () {
    test('same company and role is a duplicate however it is typed', () {
      final apps = [app('Razorpay', Stage.applied, d(1), role: 'SDE-1, Payments')];
      expect(isDuplicate(apps, ' razorpay ', 'sde 1 payments'), isTrue);
      expect(isDuplicate(apps, 'Razorpay', 'Backend Engineer'), isFalse);
    });
  });

  group('autofill is checked against the pasted text', () {
    test('keeps what the description says', () {
      final r = verifyAutofill(
        jd,
        const Autofill(
          company: 'Razorpay',
          role: 'Software Development Engineer I',
          skills: ['Java', 'Kotlin', 'PostgreSQL', 'Kafka', 'AWS'],
        ),
      );
      expect(r.company, 'Razorpay');
      expect(r.role, 'Software Development Engineer I');
      expect(r.skills, ['Java', 'Kotlin', 'PostgreSQL', 'Kafka', 'AWS']);
    });

    test('drops a company, role or skill the text never mentions', () {
      final r = verifyAutofill(
        jd,
        const Autofill(company: 'Stripe', role: 'Chief Marketing Officer', skills: ['Java', 'Rust', 'Kubernetes']),
      );
      expect(r.company, '');
      expect(r.role, '');
      expect(r.skills, ['Java']);
    });

    test('a role worded a little differently still passes', () {
      final r = verifyAutofill(jd, const Autofill(company: 'Razorpay', role: 'Software Engineer I', skills: []));
      expect(r.role, 'Software Engineer I');
    });

    test('skills are deduplicated, trimmed, short and capped', () {
      final many = 'a1 b2 c3 d4 e5 f6 g7 h8 i9 j10 ';
      final r = verifyAutofill(
        '$jd $many',
        Autofill(
          company: '',
          role: '',
          skills: ['java', ' Java ', 'JAVA', 'a1', 'b2', 'c3', 'd4', 'e5', 'f6', 'g7', 'h8', 'i9', 'j10'],
        ),
      );
      expect(r.skills.length, maxSkills);
      expect(r.skills.where((s) => s.toLowerCase() == 'java').length, 1);
    });

    test('a skill that is only part of a longer word is still found, but a blank one is not', () {
      final r = verifyAutofill(jd, const Autofill(company: '', role: '', skills: ['', '  ', 'Postgre']));
      expect(r.skills, ['Postgre']);
    });
  });

  group('saving', () {
    test('an application survives a JSON round trip', () {
      final a = JobApplication(
        id: 'x',
        company: 'Zoho',
        role: 'MTS',
        stage: Stage.oa,
        createdAt: d(1),
        stageChangedAt: d(3),
        jd: jd,
        skills: const ['Java'],
        notes: 'Referral from Asha',
      );
      final back = JobApplication.fromJson(a.toJson());
      expect(back.stage, Stage.oa);
      expect(back.skills, ['Java']);
      expect(back.notes, 'Referral from Asha');
      expect(back.stageChangedAt.isAtSameMomentAs(d(3)), isTrue);
    });

    test('an unknown stage in a saved file falls back to the wishlist', () {
      final j = app('Zoho', Stage.applied, d(1)).toJson()..['stage'] = 'ghosted';
      expect(JobApplication.fromJson(j).stage, Stage.wishlist);
    });
  });
}

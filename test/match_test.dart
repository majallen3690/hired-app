import 'package:flutter_test/flutter_test.dart';
import 'package:hired/features/resume/domain/match_models.dart';

Requirement r(String s, {bool req = true, bool hit = true, double rel = 1}) =>
    Requirement(skill: s, required: req, matched: hit, relevance: rel);

void main() {
  test('required skills count double in keyword coverage', () {
    final m = MatchResult(
      role: 'SDE-1',
      requirements: [r('Java'), r('Kafka', hit: false), r('Docker', req: false)],
      rubric: const Rubric(relevance: 80, impact: 60, ats: 70),
      sections: const [],
      fixes: const [],
    );
    // hit = 2 + 1, total = 2 + 2 + 1
    expect(m.keywordScore, 60);
    expect(m.matchedSkills.length, 2);
    expect(m.missingSkills.single.skill, 'Kafka');
  });

  test('overall blends 35/35/30', () {
    final m = MatchResult(
      role: 'x',
      requirements: [r('a', rel: 0.8), r('b', hit: false, rel: 0.6)],
      rubric: const Rubric(relevance: 90, impact: 60, ats: 90),
      sections: const [],
      fixes: const [],
    );
    expect(m.keywordScore, 50);
    expect(m.semanticScore, 70);
    expect(m.rubricScore, 80);
    expect(m.overall, (0.35 * 50 + 0.35 * 70 + 0.30 * 80).round());
  });

  test('empty requirements score zero instead of dividing by zero', () {
    const m = MatchResult(
      role: 'x', requirements: [], rubric: Rubric(relevance: 0, impact: 0, ats: 0), sections: [], fixes: []);
    expect(m.keywordScore, 0);
    expect(m.semanticScore, 0);
  });

  group('withVerifiedEvidence', () {
    const resume = 'Built a mobile app for marking class attendance\nWrote SQL queries for monthly reports';
    MatchResult withEvidence(String? ev, {bool hit = true}) => MatchResult(
          role: 'x',
          requirements: [Requirement(skill: 'SQL', required: true, matched: hit, relevance: 0.9, evidence: ev)],
          rubric: const Rubric(relevance: 50, impact: 50, ats: 50),
          sections: [SectionFeedback(section: 'Experience', note: 'n', evidence: ev)],
          fixes: const [],
        );

    test('keeps a line that is really in the resume, ignoring case and bullets', () {
      final m = withEvidence('- wrote SQL queries for monthly reports').withVerifiedEvidence(resume);
      expect(m.requirements.single.matched, isTrue);
      expect(m.requirements.single.evidence, isNotNull);
    });

    test('tolerates a line re-joined from list items', () {
      final m = withEvidence('Wrote SQL queries, for monthly reports').withVerifiedEvidence(
          'Wrote SQL queries for monthly reports\nBuilt an app');
      expect(m.requirements.single.matched, isTrue);
    });

    test('a matched requirement with invented evidence becomes missing', () {
      final m = withEvidence('Designed Kafka pipelines at scale').withVerifiedEvidence(resume);
      expect(m.requirements.single.matched, isFalse);
      expect(m.requirements.single.evidence, isNull);
      expect(m.requirements.single.relevance, lessThanOrEqualTo(0.3));
      expect(m.sections.single.evidence, isNull);
    });

    test('a matched requirement with no evidence becomes missing', () {
      expect(withEvidence(null).withVerifiedEvidence(resume).requirements.single.matched, isFalse);
    });
  });

  group('inventsNumbers', () {
    test('keeps numbers from the original', () {
      expect(inventsNumbers('Cut load time by 40%', 'Reduced load time by 40% for [N users]'), isFalse);
    });
    test('allows bracket placeholders', () {
      expect(inventsNumbers('Built an app', 'Built an app used by [X] students, saving [Y%]'), isFalse);
    });
    test('flags a made-up metric', () {
      expect(inventsNumbers('Built an app', 'Built an app serving 500 students'), isTrue);
    });
  });
}

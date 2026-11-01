class Requirement {
  const Requirement({
    required this.skill,
    required this.required,
    required this.matched,
    required this.relevance,
    this.evidence,
  });

  final String skill;
  final bool required;
  final bool matched;

  /// 0 to 1: how well the resume as a whole answers this requirement, even if the exact word is absent.
  final double relevance;

  /// A verbatim line from the resume that supports the judgement, or null when there is none.
  final String? evidence;

  factory Requirement.fromJson(Map<String, dynamic> j) => Requirement(
        skill: j['skill'] as String,
        required: j['required'] as bool,
        matched: j['matched'] as bool,
        relevance: ((j['relevance'] as num).toDouble()).clamp(0, 1).toDouble(),
        evidence: j['evidence'] as String?,
      );
}

class SectionFeedback {
  const SectionFeedback({required this.section, required this.note, this.evidence});
  final String section;
  final String note;
  final String? evidence;

  factory SectionFeedback.fromJson(Map<String, dynamic> j) =>
      SectionFeedback(section: j['section'] as String, note: j['note'] as String, evidence: j['evidence'] as String?);
}

class Rubric {
  const Rubric({required this.relevance, required this.impact, required this.ats});
  final int relevance;
  final int impact;
  final int ats;

  factory Rubric.fromJson(Map<String, dynamic> j) => Rubric(
        relevance: (j['relevance'] as num).round().clamp(0, 100),
        impact: (j['impact'] as num).round().clamp(0, 100),
        ats: (j['ats'] as num).round().clamp(0, 100),
      );
}

/// Hybrid match, modelled on Resume-Matcher: keyword coverage 35%, semantic fit 35%, LLM rubric 30%.
/// The model only supplies per-requirement judgements and evidence; every number is computed here.
class MatchResult {
  const MatchResult({
    required this.role,
    required this.requirements,
    required this.rubric,
    required this.sections,
    required this.fixes,
  });

  final String role;
  final List<Requirement> requirements;
  final Rubric rubric;
  final List<SectionFeedback> sections;
  final List<String> fixes;

  static const keywordWeight = 0.35;
  static const semanticWeight = 0.35;
  static const rubricWeight = 0.30;

  /// Required skills count double.
  int get keywordScore {
    if (requirements.isEmpty) return 0;
    var total = 0.0, hit = 0.0;
    for (final r in requirements) {
      final w = r.required ? 2.0 : 1.0;
      total += w;
      if (r.matched) hit += w;
    }
    return (100 * hit / total).round();
  }

  int get semanticScore {
    if (requirements.isEmpty) return 0;
    final mean = requirements.fold<double>(0, (s, r) => s + r.relevance) / requirements.length;
    return (100 * mean).round();
  }

  int get rubricScore => ((rubric.relevance + rubric.impact + rubric.ats) / 3).round();

  int get overall =>
      (keywordWeight * keywordScore + semanticWeight * semanticScore + rubricWeight * rubricScore).round();

  /// Drops any evidence line that is not actually in the resume. A requirement the model marked matched
  /// without real evidence becomes missing, so no score ever rests on a line the candidate did not write.
  MatchResult withVerifiedEvidence(String resumeText) {
    final haystack = _norm(resumeText);
    final words = haystack.split(' ').toSet();
    // A line counts when it is a substring, or when nearly every word of it is in the resume: the model
    // may join a skills list differently, but a made-up line always brings words the resume never used.
    String? check(String? line) {
      if (line == null) return null;
      final n = _norm(line);
      if (n.isEmpty) return null;
      if (haystack.contains(n)) return line;
      final ws = n.split(' ');
      return ws.where(words.contains).length / ws.length >= 0.85 ? line : null;
    }

    return MatchResult(
      role: role,
      requirements: [
        for (final r in requirements)
          () {
            final ev = check(r.evidence);
            return Requirement(
              skill: r.skill,
              required: r.required,
              matched: r.matched && ev != null,
              relevance: ev == null && r.matched ? r.relevance.clamp(0, 0.3).toDouble() : r.relevance,
              evidence: ev,
            );
          }(),
      ],
      rubric: rubric,
      sections: [for (final s in sections) SectionFeedback(section: s.section, note: s.note, evidence: check(s.evidence))],
      fixes: fixes,
    );
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9%+#./ ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  List<Requirement> get matchedSkills => requirements.where((r) => r.matched).toList();
  List<Requirement> get missingSkills => requirements.where((r) => !r.matched).toList();

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        role: j['role'] as String,
        requirements: [for (final r in j['requirements'] as List) Requirement.fromJson(r as Map<String, dynamic>)],
        rubric: Rubric.fromJson(j['rubric'] as Map<String, dynamic>),
        sections: [for (final s in j['sections'] as List) SectionFeedback.fromJson(s as Map<String, dynamic>)],
        fixes: [for (final f in j['fixes'] as List) f as String],
      );
}

class Rewrite {
  const Rewrite({required this.text, required this.placeholders});
  final String text;
  final List<String> placeholders;

  factory Rewrite.fromJson(Map<String, dynamic> j) =>
      Rewrite(text: j['text'] as String, placeholders: [for (final p in j['placeholders'] as List) p as String]);
}

/// A rewrite must not contain a number that was not in the original bullet or inside a [placeholder].
bool inventsNumbers(String original, String rewrite) {
  final number = RegExp(r'\d+(?:\.\d+)?');
  final known = number.allMatches(original).map((m) => m.group(0)).toSet();
  final stripped = rewrite.replaceAll(RegExp(r'\[[^\]]*\]'), '');
  return number.allMatches(stripped).any((m) => !known.contains(m.group(0)));
}

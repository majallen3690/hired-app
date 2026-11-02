enum Stage { wishlist, applied, oa, interview, offer, rejected }

extension StageLabel on Stage {
  String get label => switch (this) {
        Stage.wishlist => 'Wishlist',
        Stage.applied => 'Applied',
        Stage.oa => 'OA',
        Stage.interview => 'Interview',
        Stage.offer => 'Offer',
        Stage.rejected => 'Rejected',
      };
}

class JobApplication {
  const JobApplication({
    required this.id,
    required this.company,
    required this.role,
    required this.stage,
    required this.createdAt,
    required this.stageChangedAt,
    this.jd = '',
    this.skills = const [],
    this.notes = '',
    this.interviewAt,
  });

  final String id;
  final String company;
  final String role;
  final Stage stage;
  final DateTime createdAt;

  /// When it moved into the current stage; the follow-up reminder counts from here.
  final DateTime stageChangedAt;
  final String jd;
  final List<String> skills;
  final String notes;

  /// When the interview or online test is, if the user has set it. Drives the interview-day and warm-up reminders.
  final DateTime? interviewAt;

  JobApplication copyWith({
    String? company,
    String? role,
    Stage? stage,
    DateTime? stageChangedAt,
    String? jd,
    List<String>? skills,
    String? notes,
    DateTime? interviewAt,
    bool clearInterviewAt = false,
  }) =>
      JobApplication(
        id: id,
        company: company ?? this.company,
        role: role ?? this.role,
        stage: stage ?? this.stage,
        createdAt: createdAt,
        stageChangedAt: stageChangedAt ?? this.stageChangedAt,
        jd: jd ?? this.jd,
        skills: skills ?? this.skills,
        notes: notes ?? this.notes,
        interviewAt: clearInterviewAt ? null : (interviewAt ?? this.interviewAt),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company': company,
        'role': role,
        'stage': stage.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'stageChangedAt': stageChangedAt.toUtc().toIso8601String(),
        'jd': jd,
        'skills': skills,
        'notes': notes,
        'interviewAt': interviewAt?.toUtc().toIso8601String(),
      };

  factory JobApplication.fromJson(Map<String, dynamic> j) => JobApplication(
        id: j['id'] as String,
        company: j['company'] as String,
        role: (j['role'] as String?) ?? '',
        stage: Stage.values.firstWhere((s) => s.name == j['stage'], orElse: () => Stage.wishlist),
        createdAt: DateTime.parse(j['createdAt'] as String),
        stageChangedAt: DateTime.parse(j['stageChangedAt'] as String),
        jd: (j['jd'] as String?) ?? '',
        skills: [for (final s in (j['skills'] as List? ?? const [])) s as String],
        notes: (j['notes'] as String?) ?? '',
        interviewAt: j['interviewAt'] == null ? null : DateTime.parse(j['interviewAt'] as String),
      );
}

/// What the model read out of a pasted job description. Anything not actually in the text is dropped by
/// [verifyAutofill] before the user sees it.
class Autofill {
  const Autofill({required this.company, required this.role, required this.skills});
  final String company;
  final String role;
  final List<String> skills;
}

import 'presence_models.dart';
import 'presence_scoring.dart';

/// One presence check. The photo lives in a file next to this record, on the device only.
class PresenceRecord {
  const PresenceRecord({
    required this.id,
    required this.at,
    required this.occasion,
    required this.photoFile,
    required this.frame,
    this.evaluation,
    this.failed,
    this.saved = false,
  });

  final String id;
  final DateTime at;
  final Occasion occasion;
  final String photoFile;
  final FaceFrame frame;
  final PresenceEvaluation? evaluation;

  /// Set when the model could not be reached, so the result can offer a retry instead of nothing.
  final String? failed;

  /// A check only counts towards the score once the user chooses to save it.
  final bool saved;

  PresenceResult? get result => evaluation == null ? null : scorePresence(occasion, frame, evaluation!);
  int? get score => result?.score;
  bool get countsTowardsScore => saved && score != null;

  PresenceRecord copyWith({PresenceEvaluation? evaluation, String? failed, bool clearFailed = false, bool? saved}) =>
      PresenceRecord(
        id: id,
        at: at,
        occasion: occasion,
        photoFile: photoFile,
        frame: frame,
        evaluation: evaluation ?? this.evaluation,
        failed: clearFailed ? null : (failed ?? this.failed),
        saved: saved ?? this.saved,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toUtc().toIso8601String(),
        'occasion': occasion.name,
        'photoFile': photoFile,
        'frame': frame.toJson(),
        'evaluation': evaluation?.toJson(),
        'failed': failed,
        'saved': saved,
      };

  factory PresenceRecord.fromJson(Map<String, dynamic> j) => PresenceRecord(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        occasion: Occasion.values.firstWhere((o) => o.name == j['occasion'], orElse: () => Occasion.interview),
        photoFile: j['photoFile'] as String,
        frame: FaceFrame.fromJson(j['frame'] as Map<String, dynamic>),
        evaluation: j['evaluation'] == null ? null : PresenceEvaluation.fromJson(j['evaluation'] as Map<String, dynamic>),
        failed: j['failed'] as String?,
        saved: (j['saved'] as bool?) ?? false,
      );
}

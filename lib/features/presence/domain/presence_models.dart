/// What the photo is for. It changes the guidance and how the four areas are weighed.
enum Occasion { interview, client, linkedin, office }

extension OccasionInfo on Occasion {
  String get label => switch (this) {
        Occasion.interview => 'Interview',
        Occasion.client => 'Client',
        Occasion.linkedin => 'LinkedIn',
        Occasion.office => 'Office',
      };

  String get title => switch (this) {
        Occasion.interview => 'Interview look',
        Occasion.client => 'Client meeting',
        Occasion.linkedin => 'LinkedIn photo',
        Occasion.office => 'Office day',
      };

  String get hint => switch (this) {
        Occasion.interview => 'Interview look: we check attire, grooming, light and expression',
        Occasion.client => 'Client meeting: smart casual is fine, light matters most',
        Occasion.linkedin => 'LinkedIn photo: shoulders up, plain background, real smile',
        Occasion.office => 'Office day: neat and comfortable, we check the basics',
      };

  String get readyLabel => switch (this) {
        Occasion.interview => 'Interview ready',
        Occasion.client => 'Client ready',
        Occasion.linkedin => 'Profile ready',
        Occasion.office => 'Office ready',
      };

  /// How much each area counts, by occasion. Each row sums to 1.
  Map<PresencePart, double> get weights => switch (this) {
        Occasion.interview => {
            PresencePart.attire: 0.30,
            PresencePart.grooming: 0.20,
            PresencePart.lighting: 0.30,
            PresencePart.expression: 0.20,
          },
        Occasion.client => {
            PresencePart.attire: 0.20,
            PresencePart.grooming: 0.20,
            PresencePart.lighting: 0.35,
            PresencePart.expression: 0.25,
          },
        Occasion.linkedin => {
            PresencePart.attire: 0.15,
            PresencePart.grooming: 0.20,
            PresencePart.lighting: 0.30,
            PresencePart.expression: 0.35,
          },
        Occasion.office => {
            PresencePart.attire: 0.25,
            PresencePart.grooming: 0.25,
            PresencePart.lighting: 0.25,
            PresencePart.expression: 0.25,
          },
      };
}

enum PresencePart { attire, grooming, lighting, expression }

extension PresencePartInfo on PresencePart {
  String get label => switch (this) {
        PresencePart.attire => 'Attire',
        PresencePart.grooming => 'Grooming',
        PresencePart.lighting => 'Light and background',
        PresencePart.expression => 'Expression',
      };
}

/// A box in the upright picture, each side as a fraction of its width or height.
class Box {
  const Box({required this.left, required this.top, required this.right, required this.bottom});
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get width => right - left;
  double get height => bottom - top;

  /// An empty box contains nothing, not even its own corner.
  bool contains(double x, double y) => width > 0 && height > 0 && x >= left && x <= right && y >= top && y <= bottom;

  Map<String, dynamic> toJson() => {'l': left, 't': top, 'r': right, 'b': bottom};

  factory Box.fromJson(Map<String, dynamic> j) => Box(
        left: (j['l'] as num).toDouble(),
        top: (j['t'] as num).toDouble(),
        right: (j['r'] as num).toDouble(),
        bottom: (j['b'] as num).toDouble(),
      );
}

/// Everything measured on the phone about one camera frame. Any value may be missing: a photo picked from the gallery
/// has no usable face position, so those fields stay null and the checks that need them are skipped, never guessed.
class FaceFrame {
  const FaceFrame({
    required this.faceCount,
    this.box,
    this.rollDeg,
    this.yawDeg,
    this.pitchDeg,
    this.smile,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.lumaFace,
    this.lumaBackground,
  });

  final int faceCount;
  final Box? box;
  final double? rollDeg;
  final double? yawDeg;
  final double? pitchDeg;

  /// 0 to 1, from ML Kit.
  final double? smile;
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Average brightness, 0 (black) to 1 (white), over the face and over everything else.
  final double? lumaFace;
  final double? lumaBackground;

  bool get hasOneFace => faceCount == 1;

  double? get eyesOpen {
    final a = leftEyeOpen, b = rightEyeOpen;
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return (a + b) / 2;
  }

  Map<String, dynamic> toJson() => {
        'faceCount': faceCount,
        'box': box?.toJson(),
        'roll': rollDeg,
        'yaw': yawDeg,
        'pitch': pitchDeg,
        'smile': smile,
        'leftEye': leftEyeOpen,
        'rightEye': rightEyeOpen,
        'lumaFace': lumaFace,
        'lumaBackground': lumaBackground,
      };

  factory FaceFrame.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return FaceFrame(
      faceCount: j['faceCount'] as int,
      box: j['box'] == null ? null : Box.fromJson(j['box'] as Map<String, dynamic>),
      rollDeg: d('roll'),
      yawDeg: d('yaw'),
      pitchDeg: d('pitch'),
      smile: d('smile'),
      leftEyeOpen: d('leftEye'),
      rightEyeOpen: d('rightEye'),
      lumaFace: d('lumaFace'),
      lumaBackground: d('lumaBackground'),
    );
  }
}

enum FixArea { lighting, background, attire, grooming, expression, framing }

class Fix {
  const Fix({required this.area, required this.text});
  final FixArea area;
  final String text;

  Map<String, dynamic> toJson() => {'area': area.name, 'text': text};

  factory Fix.fromJson(Map<String, dynamic> j) => Fix(
        area: FixArea.values.firstWhere((a) => a.name == j['area'], orElse: () => FixArea.framing),
        text: j['text'] as String,
      );
}

/// A 1 to 5 rating plus what the model saw that justifies it.
class Rated {
  const Rated({required this.rating, required this.observation});
  final int rating;
  final String observation;

  Map<String, dynamic> toJson() => {'rating': rating, 'observation': observation};

  factory Rated.fromJson(Map<String, dynamic> j) => Rated(
        rating: ((j['rating'] as num).round()).clamp(1, 5),
        observation: (j['observation'] as String?) ?? '',
      );
}

/// The model's reading of the photo. It rates only things a person can change in a minute.
class PresenceEvaluation {
  const PresenceEvaluation({
    required this.attire,
    required this.grooming,
    required this.background,
    required this.expression,
    required this.fixes,
  });

  /// Null when the photo does not show clothes (a tight face crop), so attire is left out rather than invented.
  final Rated? attire;
  final Rated grooming;
  final Rated background;
  final Rated expression;
  final List<Fix> fixes;

  Map<String, dynamic> toJson() => {
        'attire': attire?.toJson(),
        'grooming': grooming.toJson(),
        'background': background.toJson(),
        'expression': expression.toJson(),
        'fixes': [for (final f in fixes) f.toJson()],
      };

  factory PresenceEvaluation.fromJson(Map<String, dynamic> j) => PresenceEvaluation(
        attire: j['attire'] == null ? null : Rated.fromJson(j['attire'] as Map<String, dynamic>),
        grooming: Rated.fromJson(j['grooming'] as Map<String, dynamic>),
        background: Rated.fromJson(j['background'] as Map<String, dynamic>),
        expression: Rated.fromJson(j['expression'] as Map<String, dynamic>),
        fixes: [for (final f in (j['fixes'] as List? ?? const [])) Fix.fromJson(f as Map<String, dynamic>)],
      );
}

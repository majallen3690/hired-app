import 'dart:typed_data';

import 'presence_models.dart';

enum CheckKind { framing, light, pose }

class Check {
  const Check(this.kind, {required this.ok, required this.message});
  final CheckKind kind;
  final bool ok;
  final String message;
}

/// Where the middle of the face should sit, as a fraction of the picture height. The guide oval sits a little above
/// the middle so there is room for shoulders below it.
const targetCenterY = 0.40;
const centreTolerance = 0.14;

/// Face height as a fraction of the picture height. A LinkedIn photo is framed tighter.
({double min, double max}) faceSizeRange(Occasion o) =>
    o == Occasion.linkedin ? (min: 0.34, max: 0.62) : (min: 0.26, max: 0.52);

const maxRollDeg = 10.0;
const maxYawDeg = 15.0;
const maxPitchDeg = 15.0;
const darkBelow = 0.28;
const brightAbove = 0.86;

/// The face is this much darker than what is behind it before it counts as backlit.
const backlitRatio = 0.65;

/// The live guide: up to three checks, most important first. With no face there is only one thing to say.
List<Check> framingChecks(FaceFrame? f, Occasion o) {
  if (f == null || f.faceCount == 0 || f.box == null) {
    return const [Check(CheckKind.framing, ok: false, message: 'Move your face into the oval')];
  }
  if (f.faceCount > 1) {
    return const [Check(CheckKind.framing, ok: false, message: 'Only one person in the frame')];
  }

  final box = f.box!;
  final size = faceSizeRange(o);
  Check framing;
  if (box.height < size.min) {
    framing = const Check(CheckKind.framing, ok: false, message: 'Move a little closer');
  } else if (box.height > size.max) {
    framing = const Check(CheckKind.framing, ok: false, message: 'Move back a little');
  } else if ((box.centerX - 0.5).abs() > centreTolerance || (box.centerY - targetCenterY).abs() > centreTolerance) {
    framing = const Check(CheckKind.framing, ok: false, message: 'Centre your face in the oval');
  } else {
    framing = const Check(CheckKind.framing, ok: true, message: 'Face centred');
  }

  final checks = [framing];

  final face = f.lumaFace;
  if (face != null) {
    final back = f.lumaBackground;
    if (back != null && back > 0.4 && face < back * backlitRatio) {
      checks.add(const Check(CheckKind.light, ok: false, message: 'Light is behind you. Face a window or lamp'));
    } else if (face < darkBelow) {
      checks.add(const Check(CheckKind.light, ok: false, message: 'Too dark. Face a light'));
    } else if (face > brightAbove) {
      checks.add(const Check(CheckKind.light, ok: false, message: 'Too bright. Move away from the light'));
    } else {
      checks.add(const Check(CheckKind.light, ok: true, message: 'Good light on your face'));
    }
  }

  final roll = f.rollDeg, yaw = f.yawDeg, pitch = f.pitchDeg;
  if (roll != null && roll.abs() > maxRollDeg) {
    checks.add(Check(CheckKind.pose, ok: false, message: 'Level your head (${roll.abs().round()}° off)'));
  } else if (yaw != null && yaw.abs() > maxYawDeg) {
    checks.add(const Check(CheckKind.pose, ok: false, message: 'Look straight at the camera'));
  } else if (pitch != null && pitch.abs() > maxPitchDeg) {
    checks.add(const Check(CheckKind.pose, ok: false, message: 'Keep your chin level'));
  } else if (roll != null || yaw != null) {
    checks.add(const Check(CheckKind.pose, ok: true, message: 'Head level, eyes on the camera'));
  }
  return checks;
}

/// Ready to shoot when every check passes. Fewer than the full set (no brightness reading yet) is not ready.
bool readyToShoot(List<Check> checks) => checks.length >= 2 && checks.every((c) => c.ok);

/// A frame is only a good moment if it stays good for a moment: this stops the shutter hint flickering on and off.
class StableReady {
  StableReady({this.hold = const Duration(milliseconds: 700)});
  final Duration hold;
  DateTime? _since;

  bool update(bool ok, DateTime now) {
    if (!ok) {
      _since = null;
      return false;
    }
    _since ??= now;
    return now.difference(_since!) >= hold;
  }
}

/// Maps a point of the camera's raw frame (each coordinate 0 to 1) to the upright picture. The raw frame is stored
/// turned, and [rotation] is the clockwise turn that makes it upright.
({double x, double y}) rawToUpright(double nx, double ny, int rotation) => switch (rotation % 360) {
      90 => (x: 1 - ny, y: nx),
      180 => (x: 1 - nx, y: 1 - ny),
      270 => (x: ny, y: 1 - nx),
      _ => (x: nx, y: ny),
    };

/// Average brightness of the face and of everything around it, read from the Y (brightness) plane of a camera frame.
/// Samples a sparse grid, so it is cheap enough to run on every analysed frame. Null when [box] covers nothing.
({double face, double background})? lumaSplit({
  required Uint8List yPlane,
  required int width,
  required int height,
  required int rowStride,
  required int rotation,
  required Box box,
  int step = 6,
}) {
  var faceSum = 0, faceN = 0, backSum = 0, backN = 0;
  for (var ry = 0; ry < height; ry += step) {
    final row = ry * rowStride;
    for (var rx = 0; rx < width; rx += step) {
      final i = row + rx;
      if (i >= yPlane.length) continue;
      // Work out where this raw pixel lands in the upright picture, to see whether it is inside the face.
      final up = rawToUpright(rx / width, ry / height, rotation);
      if (box.contains(up.x, up.y)) {
        faceSum += yPlane[i];
        faceN++;
      } else {
        backSum += yPlane[i];
        backN++;
      }
    }
  }
  if (faceN == 0 || backN == 0) return null;
  return (face: faceSum / faceN / 255, background: backSum / backN / 255);
}

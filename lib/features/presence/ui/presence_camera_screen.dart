import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../../interview/ui/interview_widgets.dart' show Orb;
import '../domain/framing.dart';
import '../domain/presence_models.dart';
import '../presence_controller.dart';

/// The most a gallery photo may weigh before it is refused; it is sent inline to the model.
const _maxPhotoBytes = 12 * 1024 * 1024;

/// How often a camera frame is analysed. Faster only drains the battery; the guide does not need it.
const _analyseEvery = Duration(milliseconds: 250);

const _oval = (widthFraction: 0.55, aspect: 1.28);

class PresenceCameraScreen extends ConsumerStatefulWidget {
  const PresenceCameraScreen({super.key});

  @override
  ConsumerState<PresenceCameraScreen> createState() => _State();
}

class _State extends ConsumerState<PresenceCameraScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  List<CameraDescription> _cameras = const [];
  var _index = 0;
  var _choseDefault = false;
  String? _cameraError;
  var _starting = true;

  var _occasion = Occasion.interview;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast, minFaceSize: 0.2),
  );
  var _busy = false;
  var _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  FaceFrame? _frame;
  var _checks = const <Check>[];
  final _stable = StableReady();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be let go when the app is not in front, and reopened when it returns.
    if (state == AppLifecycleState.inactive) {
      final c = _cam;
      _cam = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _cam == null && !_starting) {
      _start();
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _cameraError = null;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _cameraError = 'No camera was found on this device. You can still choose a photo from your gallery.';
          _starting = false;
        });
        return;
      }
      if (!_choseDefault) {
        final front = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _index = front < 0 ? 0 : front;
        _choseDefault = true;
      }
      await _open(_cameras[_index]);
    } on CameraException catch (e) {
      _failCamera(e);
    }
  }

  void _failCamera(CameraException e) {
    if (!mounted) return;
    setState(() {
      _cameraError = e.code.contains('Denied')
          ? 'Camera access is off. Allow it in Android settings, or choose a photo from your gallery.'
          : 'The camera could not start. You can still choose a photo from your gallery.';
      _starting = false;
    });
  }

  Future<void> _open(CameraDescription d) async {
    final old = _cam;
    _cam = null;
    await old?.dispose();
    final c = CameraController(d, ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await c.startImageStream(_onFrame);
    } on CameraException catch (e) {
      await c.dispose();
      _failCamera(e);
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      _cam = c;
      _starting = false;
      _frame = null;
      _checks = const [];
      _ready = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    setState(() => _starting = true);
    try {
      await _open(_cameras[_index]);
    } on CameraException catch (e) {
      _failCamera(e);
    }
  }

  /// The turn, in degrees, that makes a raw camera frame upright. The screen is locked to portrait.
  InputImageRotation? _rotation(CameraDescription d) => InputImageRotationValue.fromRawValue(
        d.lensDirection == CameraLensDirection.front ? d.sensorOrientation % 360 : (d.sensorOrientation + 360) % 360,
      );

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (_busy || now.difference(_lastRun) < _analyseEvery) return;
    _busy = true;
    _lastRun = now;
    _analyse(image).whenComplete(() => _busy = false);
  }

  Future<void> _analyse(CameraImage image) async {
    final cam = _cam;
    if (cam == null || image.format.group != ImageFormatGroup.nv21 || image.planes.isEmpty) return;
    final rotation = _rotation(cam.description);
    if (rotation == null) return;
    final plane = image.planes.first;
    try {
      final faces = await _detector.processImage(InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: ui.Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      ));
      final frame = _toFrame(faces, image, rotation);
      final checks = framingChecks(frame, _occasion);
      if (!mounted) return;
      // A message such as "we could not see your face" has done its job once exactly one face is back in view.
      if (frame.faceCount == 1 && ref.read(presenceControllerProvider).notice != null) {
        ref.read(presenceControllerProvider.notifier).clearNotice();
      }
      setState(() {
        _frame = frame;
        _checks = checks;
        _ready = _stable.update(readyToShoot(checks), DateTime.now());
      });
    } catch (e) {
      debugPrint('Face analysis skipped: $e');
    }
  }

  FaceFrame _toFrame(List<Face> faces, CameraImage image, InputImageRotation rotation) {
    if (faces.isEmpty) return const FaceFrame(faceCount: 0);
    final face = faces.reduce((a, b) => a.boundingBox.height >= b.boundingBox.height ? a : b);
    final turned = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
    final uw = (turned ? image.height : image.width).toDouble();
    final uh = (turned ? image.width : image.height).toDouble();
    final bb = face.boundingBox;
    final box = Box(
      left: (bb.left / uw).clamp(0.0, 1.0),
      top: (bb.top / uh).clamp(0.0, 1.0),
      right: (bb.right / uw).clamp(0.0, 1.0),
      bottom: (bb.bottom / uh).clamp(0.0, 1.0),
    );
    final plane = image.planes.first;
    final luma = lumaSplit(
      yPlane: plane.bytes,
      width: image.width,
      height: image.height,
      rowStride: plane.bytesPerRow,
      rotation: rotation.rawValue,
      box: box,
    );
    return FaceFrame(
      faceCount: faces.length,
      box: box,
      rollDeg: face.headEulerAngleZ,
      yawDeg: face.headEulerAngleY,
      pitchDeg: face.headEulerAngleX,
      smile: face.smilingProbability,
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      lumaFace: luma?.face,
      lumaBackground: luma?.background,
    );
  }

  Future<bool> _consent() async {
    final ctl = ref.read(presenceControllerProvider.notifier);
    if (await ctl.hasConsent()) return true;
    if (!mounted) return false;
    final c = context.hc;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: c.ink2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(HiredRadii.card))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            HiredSpace.screen, HiredSpace.screen, HiredSpace.screen, HiredSpace.screen + MediaQuery.viewPaddingOf(sheet).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Before your first photo'),
          const SizedBox(height: HiredSpace.sm),
          Text('Send this photo for analysis?', style: HiredText.h2.copyWith(color: c.text)),
          const SizedBox(height: HiredSpace.md),
          Text(
            'Hired sends the photo you take to Google\'s Gemini AI to read your attire, grooming, background and expression. '
            'Your face position and the light on it are measured on this phone.',
            style: HiredText.body.copyWith(color: c.text2),
          ),
          const SizedBox(height: HiredSpace.sm),
          Text(
            'Photos are kept only on this phone, and you can delete any of them. We rate things you can change in a minute, '
            'never your face or looks.',
            style: HiredText.body.copyWith(color: c.text2),
          ),
          const SizedBox(height: HiredSpace.xl),
          PrimaryButton(label: 'Send photo', onPressed: () => Navigator.pop(sheet, true)),
          const SizedBox(height: HiredSpace.sm),
          Center(child: TextAction(label: 'Not now', onPressed: () => Navigator.pop(sheet, false))),
        ]),
      ),
    );
    if (ok == true) {
      await ctl.grantConsent();
      return true;
    }
    return false;
  }

  Future<void> _capture() async {
    final cam = _cam;
    final ctl = ref.read(presenceControllerProvider.notifier);
    if (cam == null || !cam.value.isInitialized || cam.value.isTakingPicture) return;
    final frame = _frame;
    if (frame == null || frame.faceCount == 0) {
      ctl.notice('We could not see your face. Move into the oval and try again.');
      return;
    }
    if (frame.faceCount > 1) {
      ctl.notice('There is more than one person in the frame. Only you should be in the picture.');
      return;
    }
    if (!await _consent()) return;
    try {
      await cam.stopImageStream();
      final shot = await cam.takePicture();
      final bytes = await shot.readAsBytes();
      await ctl.analyse(jpeg: bytes, occasion: _occasion, frame: frame);
    } on CameraException {
      ctl.notice('The photo could not be taken. Try again.');
    }
  }

  Future<void> _gallery() async {
    final ctl = ref.read(presenceControllerProvider.notifier);
    if (!await _consent()) return;
    final res = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = res?.files.single;
    final bytes = file?.bytes;
    final path = file?.path;
    if (bytes == null || path == null) return;
    if (bytes.length > _maxPhotoBytes) {
      ctl.notice('That photo is too large. Pick one under 12 MB.');
      return;
    }
    final faces = await _detector.processImage(InputImage.fromFilePath(path));
    if (faces.isEmpty) {
      ctl.notice('We could not find a face in that photo.');
      return;
    }
    if (faces.length > 1) {
      ctl.notice('That photo has more than one person in it. Pick one of just you.');
      return;
    }
    final f = faces.first;
    // A gallery photo has no live frame, so where the face sits and how bright it is are not measured; only the head
    // angles and expression ML Kit reads from the picture are.
    await ctl.analyse(
      jpeg: bytes,
      occasion: _occasion,
      frame: FaceFrame(
        faceCount: 1,
        rollDeg: f.headEulerAngleZ,
        yawDeg: f.headEulerAngleY,
        pitchDeg: f.headEulerAngleX,
        smile: f.smilingProbability,
        leftEyeOpen: f.leftEyeOpenProbability,
        rightEyeOpen: f.rightEyeOpenProbability,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final s = ref.watch(presenceControllerProvider);
    ref.listen(presenceControllerProvider, (prev, next) {
      if (next.resultId != null && next.resultId != prev?.resultId) {
        context.pushReplacement('/presence/result/${next.resultId}');
      }
    });
    final analysing = s.phase == PresencePhase.analysing;
    final cam = _cam;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0A08),
      body: Stack(fit: StackFit.expand, children: [
        if (cam != null && cam.value.isInitialized) _preview(cam),
        if (cam != null) CustomPaint(painter: _OvalGuide(color: _ready ? c.signal : c.warn.withValues(alpha: 0.9))),
        if (cam == null) _noCamera(c),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(HiredSpace.sm, HiredSpace.sm, HiredSpace.screen, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), tooltip: 'Close', onPressed: () => context.go('/home')),
                const Expanded(
                  child: Center(
                    child: Text('Presence check', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 48),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(HiredSpace.lg, HiredSpace.sm, HiredSpace.lg, 0),
              child: Segmented<Occasion>(
                options: {for (final o in Occasion.values) o: o.label},
                value: _occasion,
                onChanged: (o) => setState(() {
                  _occasion = o;
                  final f = _frame;
                  if (f != null) _checks = framingChecks(f, o);
                }),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: HiredSpace.lg, bottom: HiredSpace.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (s.notice != null) _pill(c, Icons.info_outline_rounded, c.warn, s.notice!, wide: true),
                  if (s.notice == null && cam != null) ...[
                    for (final ch in _checks)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _pill(c, ch.ok ? Icons.check_circle_rounded : Icons.error_rounded, ch.ok ? c.ok : c.warn, ch.message),
                      ),
                    if (_checks.isEmpty) _pill(c, Icons.face_retouching_natural_rounded, c.text2, 'Looking for your face…'),
                  ],
                ]),
              ),
            ),
            _dock(c, analysing),
          ]),
        ),
        if (analysing)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.72),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Orb(interviewerSpeaking: false, level: 0, busy: true, size: 190),
                const SizedBox(height: HiredSpace.lg),
                Text('Reading your photo', style: HiredText.h2.copyWith(color: Colors.white)),
                const SizedBox(height: HiredSpace.xs),
                Text('Attire, grooming, background and expression', style: HiredText.small.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _preview(CameraController cam) {
    final size = cam.value.previewSize;
    if (size == null) return const SizedBox.shrink();
    // The preview is reported landscape; the screen is portrait, so width and height swap, and it is cropped to fill.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: size.height, height: size.width, child: CameraPreview(cam)),
      ),
    );
  }

  Widget _noCamera(HiredPalette c) => Padding(
        padding: const EdgeInsets.all(HiredSpace.xxl),
        child: Center(
          child: _starting
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.no_photography_rounded, size: 44, color: c.text2),
                  const SizedBox(height: HiredSpace.lg),
                  Text(_cameraError ?? 'The camera is not available.',
                      textAlign: TextAlign.center, style: HiredText.body.copyWith(color: Colors.white)),
                  const SizedBox(height: HiredSpace.lg),
                  OutlineAction(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _start),
                ]),
        ),
      );

  Widget _pill(HiredPalette c, IconData icon, Color color, String text, {bool wide = false}) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 330 : 300),
        child: Glass(
          radius: 17,
          blur: 18,
          padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: HiredText.small.copyWith(color: c.text, fontWeight: FontWeight.w600))),
          ]),
        ),
      );

  Widget _dock(HiredPalette c, bool analysing) => Glass(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_ready ? 'Looking good. Hold still and take the photo.' : _occasion.hint,
              textAlign: TextAlign.center, style: HiredText.small.copyWith(color: c.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: HiredSpace.md),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton.outlined(
              onPressed: analysing ? null : _gallery,
              tooltip: 'Choose from gallery',
              icon: Icon(Icons.photo_library_outlined, color: c.text2),
              style: IconButton.styleFrom(minimumSize: const Size(52, 52), side: BorderSide(color: c.hair)),
            ),
            Semantics(
              button: true,
              label: 'Take photo',
              child: GestureDetector(
                onTap: analysing ? null : _capture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _ready ? c.signal : const Color(0xFFF7F1EC), width: 4),
                  ),
                  child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: _ready ? c.signal : const Color(0xFFF7F1EC))),
                ),
              ),
            ),
            IconButton.outlined(
              onPressed: analysing || _cameras.length < 2 ? null : _switchCamera,
              tooltip: 'Switch camera',
              icon: Icon(Icons.cameraswitch_outlined, color: c.text2),
              style: IconButton.styleFrom(minimumSize: const Size(52, 52), side: BorderSide(color: c.hair)),
            ),
          ]),
        ]),
      );
}

/// A dimmed screen with an oval cut out for the face. Dashed; the colour says whether the frame is good.
class _OvalGuide extends CustomPainter {
  _OvalGuide({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * _oval.widthFraction;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height * targetCenterY), width: w, height: w * _oval.aspect);
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addOval(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = const Color(0xFF070504).withValues(alpha: 0.38));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color
      ..strokeCap = StrokeCap.round;
    final oval = Path()..addOval(rect);
    for (final metric in oval.computeMetrics()) {
      const dash = 10.0, gap = 7.0;
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_OvalGuide old) => old.color != color;
}

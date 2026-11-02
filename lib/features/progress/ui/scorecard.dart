import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/scoring/readiness.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/tick_dial.dart';
import '../../home/scores_provider.dart';
import '../domain/progress_models.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(DateTime t) {
  final l = t.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

/// The 1080 by 1920 share image, drawn at 360 by 640 logical pixels. It always uses the dark palette, so the picture
/// looks the same whichever theme the sharer is using.
class Scorecard extends StatelessWidget {
  const Scorecard({
    super.key,
    required this.summary,
    required this.measured,
    required this.firstName,
    required this.date,
  });

  static const logicalSize = Size(360, 640);

  final ProgressSummary summary;
  final MeasuredScores measured;
  final String? firstName;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildHiredTheme(Brightness.dark),
      child: Builder(
        builder: (context) {
          final c = context.hc;
          final scores = measured.toScores();
          final readiness =
              summary.current ??
              (measured.isEmpty ? null : readinessScore(scores));
          const labels = {
            SubScore.resume: 'Resume',
            SubScore.interview: 'Interview',
            SubScore.communication: 'Speaking',
            SubScore.presence: 'Presence',
          };
          return SizedBox.fromSize(
            size: logicalSize,
            child: DecoratedBox(
              decoration: BoxDecoration(color: c.ink),
              child: Stack(
                children: [
                  Positioned(
                    top: 120,
                    left: 20,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.ember.withValues(alpha: 0.30),
                            c.ember.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HIRED',
                          style: HiredText.label.copyWith(
                            color: c.ember,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          firstName == null
                              ? 'My placement readiness'
                              : "$firstName's placement readiness",
                          style: HiredText.h2.copyWith(color: c.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shortDate(date),
                          style: HiredText.small.copyWith(color: c.text3),
                        ),
                        const Spacer(),
                        Center(
                          child: TickDial(
                            size: 232,
                            values: [
                              for (final k in SubScore.values)
                                (measured[k] ?? 0).toDouble(),
                            ],
                            focus: null,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  readiness == null ? '–' : '$readiness',
                                  style: HiredText.num(
                                    76,
                                  ).copyWith(color: c.text),
                                ),
                                Text(
                                  'readiness',
                                  style: HiredText.italic.copyWith(
                                    color: c.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (summary.delta != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              '${summary.delta! >= 0 ? '▲' : '▼'} ${summary.delta!.abs()} ${spanLabel(date.difference(summary.since!).inDays)}',
                              style: HiredText.small.copyWith(
                                color: summary.delta! >= 0 ? c.ok : c.bad,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        for (final k in SubScore.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 92,
                                  child: Text(
                                    labels[k]!,
                                    style: HiredText.body.copyWith(
                                      color: c.text2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: (measured[k] ?? 0) / 100,
                                      minHeight: 5,
                                      backgroundColor: c.track,
                                      color: measured[k] == null
                                          ? c.track
                                          : c.band(measured[k]!),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    measured[k] == null
                                        ? '–'
                                        : '${measured[k]}',
                                    textAlign: TextAlign.end,
                                    style: HiredText.body.copyWith(
                                      color: c.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            _stat(c, '${summary.streak}', 'day streak'),
                            _stat(c, '${summary.mocks}', 'mocks'),
                            _stat(
                              c,
                              summary.bestReadiness == null
                                  ? '–'
                                  : '${summary.bestReadiness}',
                              'best',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stat(HiredPalette c, String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: HiredText.num(30).copyWith(color: c.text)),
        Text(label, style: HiredText.tiny.copyWith(color: c.text3)),
      ],
    ),
  );
}

/// Renders the card to a 1080 by 1920 PNG and opens the system share sheet. Returns an error message, or null.
Future<String?> shareScorecard(
  GlobalKey boundaryKey, {
  required int? readiness,
}) async {
  try {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return 'The scorecard is not ready yet.';
    final image = await boundary.toImage(
      pixelRatio: 1080 / boundary.size.width,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return 'Could not draw the scorecard.';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/hired_scorecard.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: readiness == null
            ? 'Practising for placements with Hired.'
            : 'My placement readiness is $readiness on Hired.',
      ),
    );
    return null;
  } catch (e) {
    return 'Sharing did not work. Try again.';
  }
}

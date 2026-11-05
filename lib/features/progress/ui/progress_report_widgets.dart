import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/scoring/readiness.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../domain/progress_report.dart';

IconData areaIcon(SubScore s) => switch (s) {
      SubScore.resume => Icons.description_rounded,
      SubScore.interview => Icons.mic_rounded,
      SubScore.communication => Icons.record_voice_over_rounded,
      SubScore.presence => Icons.photo_camera_rounded,
    };

/// The four areas as one shape: the closer the filled shape gets to the dashed ring, the closer to placement-ready.
class AreaRadar extends StatelessWidget {
  const AreaRadar({super.key, required this.report});
  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : HiredMotion.scoreReveal,
      curve: HiredMotion.easeOutExpo,
      builder: (_, t, __) => RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
          tickBorderData: BorderSide(color: c.hair),
          gridBorderData: BorderSide(color: c.hair),
          radarBorderData: BorderSide(color: c.hair),
          radarBackgroundColor: Colors.transparent,
          titlePositionPercentageOffset: 0.16,
          titleTextStyle: HiredText.small.copyWith(color: c.text2, fontSize: 12),
          getTitle: (i, _) => RadarChartTitle(text: report.areas[i].label),
          dataSets: [
            // Invisible: pins the scale to 0 to 100 so a lone score does not stretch to fill the chart.
            RadarDataSet(
              dataEntries: const [RadarEntry(value: 100), RadarEntry(value: 0), RadarEntry(value: 100), RadarEntry(value: 0)],
              fillColor: Colors.transparent,
              borderColor: Colors.transparent,
              borderWidth: 0,
              entryRadius: 0,
            ),
            // The placement-ready ring, drawn first so the shape sits over it.
            RadarDataSet(
              dataEntries: [for (final _ in report.areas) RadarEntry(value: readyThreshold.toDouble())],
              fillColor: Colors.transparent,
              borderColor: c.ok.withValues(alpha: 0.55),
              borderWidth: 1.2,
              entryRadius: 0,
            ),
            RadarDataSet(
              dataEntries: [for (final a in report.areas) RadarEntry(value: (a.latest ?? 0) * t)],
              fillColor: c.ember.withValues(alpha: 0.28),
              borderColor: c.ember,
              borderWidth: 2.4,
              entryRadius: 3.2,
            ),
          ],
          isMinValueAtCenter: true,
          radarTouchData: RadarTouchData(enabled: false),
        ),
        duration: Duration.zero,
      ),
    );
  }
}

/// One area: where it started, where it is, and how it moved.
class AreaRow extends StatelessWidget {
  const AreaRow({super.key, required this.area});
  final AreaReport area;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final v = area.latest;
    final d = area.delta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HiredSpace.sm),
      child: Column(
        children: [
          Row(
            children: [
              Icon(areaIcon(area.area), size: 18, color: v == null ? c.text3 : c.text2),
              const SizedBox(width: HiredSpace.sm),
              Expanded(child: Text(area.label, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w500))),
              if (d != null && d != 0) ...[
                Tag('${d > 0 ? '▲' : '▼'} ${d.abs()}', tone: d > 0 ? TagTone.ok : TagTone.bad),
                const SizedBox(width: HiredSpace.sm),
              ],
              Text(v == null ? '–' : '$v', style: HiredText.body.copyWith(color: v == null ? c.text3 : c.text, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBar(value: (v ?? 0) / 100, color: v == null ? c.track : c.band(v), backgroundColor: c.track, minHeight: 5),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              v == null
                  ? 'Not measured yet'
                  : area.count == 1
                      ? 'Measured once'
                      : 'From ${area.first} over ${area.count} results',
              style: HiredText.tiny.copyWith(color: c.text3),
            ),
          ),
        ],
      ),
    );
  }
}

/// The single most useful thing the data says: where the biggest gain is, in the same points as the score.
class FocusCard extends StatelessWidget {
  const FocusCard({super.key, required this.report});
  final ProgressReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final focus = report.focus;
    final lift = report.liftToReady(focus.area);
    final mover = report.biggestMover;
    final ready = (report.readiness ?? 0) >= readyThreshold;
    final headline = ready ? 'You are over the placement-ready line' : 'Focus on ${focus.label.toLowerCase()}';
    final detail = ready
        ? (focus.measured
            ? 'Keep every area above $readyThreshold and keep practising so it stays that way.'
            : '${focus.label} has not been measured yet. Measuring it could lift you further.')
        : focus.measured
            ? '${focus.label} is at ${focus.latest}. Getting it to $readyThreshold adds about $lift to your readiness.'
            : '${focus.label} has not been measured yet, so it counts as zero. Measuring it once adds the most.';
    return Glass(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.ember.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(HiredRadii.tile)),
            child: Icon(ready ? Icons.verified_rounded : Icons.flag_rounded, color: c.ember, size: 22),
          ),
          const SizedBox(width: HiredSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail, style: HiredText.small.copyWith(color: c.text2)),
                if (mover != null) ...[
                  const SizedBox(height: HiredSpace.sm),
                  Text('Biggest climb so far: ${mover.label.toLowerCase()}, up ${mover.delta}.',
                      style: HiredText.tiny.copyWith(color: c.ok)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Measured results per day as small bars; the last bar is today.
class ActivityBars extends StatelessWidget {
  const ActivityBars({super.key, required this.counts});
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final top = counts.fold<int>(1, (m, v) => v > m ? v : m);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < counts.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduce ? 1 : 0, end: 1),
                  duration: reduce ? Duration.zero : Duration(milliseconds: 500 + i * 30),
                  curve: HiredMotion.easeOutExpo,
                  builder: (_, t, __) {
                    final n = counts[i];
                    return Container(
                      height: 6 + (n / top) * 58 * t,
                      decoration: BoxDecoration(
                        color: n == 0 ? c.track : (i == counts.length - 1 ? c.ember : c.ember.withValues(alpha: 0.6)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/scoring/readiness.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../../home/scores_provider.dart';
import '../../interview/ui/interview_widgets.dart' show MetricTile;
import '../../intro/data/intro_store.dart';
import '../../resume/resume_flow.dart';
import '../data/progress_providers.dart';
import '../domain/progress_models.dart';
import 'scorecard.dart';
import '../../../core/motion/motion.dart';

enum _Range { week, month, all }

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _State();
}

class _State extends ConsumerState<ProgressScreen> {
  var _range = _Range.all;

  String? _firstName() {
    final name = ref.read(resumeFlowProvider).resume?['name'];
    if (name is! String || name.trim().isEmpty) return null;
    return name.trim().split(RegExp(r'\s+')).first;
  }

  void _openScorecard(ProgressSummary summary) {
    final key = GlobalKey();
    final measured = ref.read(latestScoresProvider);
    final name = _firstName();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      sheetAnimationStyle: hiredSheetMotion,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.hc.ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HiredRadii.card),
        ),
      ),
      builder: (sheet) {
        final c = sheet.hc;
        String? error;
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                HiredSpace.screen,
                HiredSpace.lg,
                HiredSpace.screen,
                HiredSpace.lg + MediaQuery.viewPaddingOf(sheet).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            Scorecard.logicalSize.width /
                            Scorecard.logicalSize.height,
                        child: FittedBox(
                          child: RepaintBoundary(
                            key: key,
                            child: Scorecard(
                              summary: summary,
                              measured: measured,
                              firstName: name,
                              date: DateTime.now(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: HiredSpace.lg),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: HiredSpace.sm),
                      child: Text(
                        error!,
                        style: HiredText.small.copyWith(color: c.bad),
                      ),
                    ),
                  PrimaryButton(
                    label: 'Share my scorecard',
                    icon: Icons.ios_share_rounded,
                    onPressed: () async {
                      final err = await shareScorecard(
                        key,
                        readiness: summary.current,
                      );
                      if (err != null) setSheet(() => error = err);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final summary = ref.watch(progressProvider);
    final events = ref.watch(scoreEventsProvider);

    if (summary.isEmpty) return _empty(c);

    final now = DateTime.now();
    final span = summary.since == null
        ? 0
        : now.difference(summary.since!).inDays;
    final delta = summary.delta;
    final last7 = activityLast7(events.map((e) => e.at), now);
    final cutoff = switch (_range) {
      _Range.week => now.subtract(const Duration(days: 7)),
      _Range.month => now.subtract(const Duration(days: 30)),
      _Range.all => DateTime.fromMillisecondsSinceEpoch(0),
    };
    final visible = summary.points.where((p) => p.at.isAfter(cutoff)).toList();

    return SafeArea(
      child: RevealListView(
        padding: const EdgeInsets.fromLTRB(
          HiredSpace.screen,
          HiredSpace.md,
          HiredSpace.screen,
          120,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Since ${shortDate(summary.since!)}',
                      style: HiredText.small.copyWith(color: c.text3),
                    ),
                    const SizedBox(height: HiredSpace.xs),
                    Text(
                      'Progress',
                      style: HiredText.h1.copyWith(color: c.text),
                    ),
                  ],
                ),
              ),
              IconAction(
                icon: Icons.ios_share_rounded,
                label: 'Share scorecard',
                onPressed: () => _openScorecard(summary),
              ),
            ],
          ),
          const SizedBox(height: HiredSpace.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${summary.current}',
                style: HiredText.num(84).copyWith(color: c.text),
              ),
              const SizedBox(width: HiredSpace.md),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: delta == null
                    ? Text(
                        'readiness',
                        style: HiredText.italic.copyWith(color: c.text3),
                      )
                    : Tag(
                        '${delta >= 0 ? '▲' : '▼'} ${delta.abs()} ${spanLabel(span)}',
                        tone: delta >= 0 ? TagTone.ok : TagTone.bad,
                      ),
              ),
            ],
          ),
          const SizedBox(height: HiredSpace.lg),
          Segmented<_Range>(
            options: const {
              _Range.week: '1 week',
              _Range.month: '1 month',
              _Range.all: 'All time',
            },
            value: _range,
            onChanged: (v) => setState(() => _range = v),
          ),
          const SizedBox(height: HiredSpace.lg),
          Glass(
            padding: const EdgeInsets.fromLTRB(
              HiredSpace.md,
              HiredSpace.lg,
              HiredSpace.lg,
              HiredSpace.md,
            ),
            child: SizedBox(height: 190, child: _chart(c, visible)),
          ),
          const SizedBox(height: HiredSpace.lg),
          Glass(
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: summary.streak > 0 ? c.ember : c.text3,
                  size: 26,
                ),
                const SizedBox(width: HiredSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.streak == 0
                            ? 'No streak yet'
                            : '${summary.streak}-day streak',
                        style: HiredText.body.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        summary.streak == 0
                            ? 'Practise today to start one'
                            : 'Best: ${dayCount(summary.bestStreak)}',
                        style: HiredText.tiny.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: _dayDot(
                      c,
                      last7[i],
                      now.subtract(Duration(days: 6 - i)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: HiredSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MetricTile(label: 'Mocks', value: '${summary.mocks}'),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Resume matches',
                  value: '${summary.resumeMatches}',
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Intros',
                  value:
                      '${(ref.watch(introsProvider).asData?.value ?? const []).where((i) => i.score != null).length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: HiredSpace.xl),
          const SectionLabel('Best ever'),
          const SizedBox(height: HiredSpace.sm),
          Glass(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Readiness',
                    value: _n(summary.bestReadiness),
                  ),
                ),
                Expanded(
                  child: MetricTile(
                    label: 'Interview',
                    value: _n(summary.bestInterview),
                  ),
                ),
                Expanded(
                  child: MetricTile(
                    label: 'Resume',
                    value: _n(summary.bestResume),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HiredSpace.xl),
          const SectionLabel('Badges'),
          const SizedBox(height: HiredSpace.sm),
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - HiredSpace.md) / 2;
              return Wrap(
                spacing: HiredSpace.md,
                runSpacing: HiredSpace.md,
                children: [
                  for (final b in summary.badges)
                    SizedBox(width: w, child: _badge(c, b)),
                ],
              );
            },
          ),
          const SizedBox(height: HiredSpace.xxl),
          PrimaryButton(
            label: 'Share my scorecard',
            icon: Icons.ios_share_rounded,
            onPressed: () => _openScorecard(summary),
          ),
        ],
      ),
    );
  }

  String _n(int? v) => v == null ? '–' : '$v';

  Widget _dayDot(HiredPalette c, bool active, DateTime day) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? c.ember : c.track,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          letters[day.weekday - 1],
          style: HiredText.tiny.copyWith(color: c.text3, fontSize: 9),
        ),
      ],
    );
  }

  Widget _badge(HiredPalette c, Achievement b) {
    final icon = switch (b.kind) {
      BadgeKind.firstMock => Icons.mic_rounded,
      BadgeKind.resume70 => Icons.description_rounded,
      BadgeKind.streak7 => Icons.local_fire_department_rounded,
      BadgeKind.ready75 => Icons.verified_rounded,
    };
    final tone = b.earned ? c.ember : c.text3;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Glass(
        padding: const EdgeInsets.all(HiredSpace.md),
        child: Row(
          children: [
            Icon(b.earned ? icon : Icons.lock_rounded, color: tone, size: 22),
            const SizedBox(width: HiredSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.label,
                    style: HiredText.small.copyWith(
                      color: b.earned ? c.text : c.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!b.earned)
                    Text(
                      b.hint,
                      maxLines: 2,
                      style: HiredText.tiny.copyWith(
                        color: c.text3,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chart(HiredPalette c, List<ReadinessPoint> pts) {
    if (pts.isEmpty) {
      return Center(
        child: Text(
          'No sessions in this range',
          style: HiredText.body.copyWith(color: c.text3),
        ),
      );
    }
    if (pts.length == 1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.ember),
            ),
            const SizedBox(height: HiredSpace.md),
            Text(
              'Your line starts here. One more session draws it.',
              style: HiredText.small.copyWith(color: c.text3),
            ),
          ],
        ),
      );
    }
    final first = pts.first.at;
    final spots = [
      for (final p in pts)
        FlSpot(p.at.difference(first).inMinutes / 1440.0, p.value.toDouble()),
    ];
    final lo = pts.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final hi = pts.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minY = (((lo - 10) / 10).floor() * 10).clamp(0, 70).toDouble();
    final maxY = (((hi + 5) / 10).ceil() * 10).clamp(80, 100).toDouble();
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: spots.last.x,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.hair, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 20,
              getTitlesWidget: (v, _) => Text(
                '${v.round()}',
                style: HiredText.tiny.copyWith(color: c.text3),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: spots.last.x == 0 ? 1 : spots.last.x,
              getTitlesWidget: (v, meta) {
                final isEnd = v >= meta.max - 0.001;
                final label = isEnd
                    ? 'Latest'
                    : shortDate(
                        first,
                      ).substring(0, shortDate(first).length - 5);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style: HiredText.tiny.copyWith(color: c.text3),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: readyThreshold.toDouble(),
              color: c.ok.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                style: HiredText.tiny.copyWith(color: c.ok),
                labelResolver: (_) => 'Placement-ready $readyThreshold',
              ),
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  '${t.y.round()}',
                  HiredText.small.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: c.ember,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                radius: i == spots.length - 1 ? 5 : 3,
                color: c.ember,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.ember.withValues(alpha: 0.28),
                  c.ember.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(HiredPalette c) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        HiredSpace.screen,
        HiredSpace.md,
        HiredSpace.screen,
        120,
      ),
      children: [
        Text(
          'No sessions yet',
          style: HiredText.small.copyWith(color: c.text3),
        ),
        const SizedBox(height: HiredSpace.xs),
        Text('Progress', style: HiredText.h1.copyWith(color: c.text)),
        const SizedBox(height: 56),
        Center(
          child: Text('--', style: HiredText.num(84).copyWith(color: c.text3)),
        ),
        Center(
          child: Text(
            'Readiness',
            style: HiredText.italic.copyWith(color: c.text3),
          ),
        ),
        const SizedBox(height: 56),
        Text(
          'Your chart starts with one session',
          style: HiredText.h2.copyWith(color: c.text),
        ),
        const SizedBox(height: HiredSpace.sm),
        Text(
          'A 10-minute mock gives you a real score and a line that climbs from here.',
          style: HiredText.body.copyWith(color: c.text2),
        ),
        const SizedBox(height: HiredSpace.xxl),
        PrimaryButton(
          label: 'Take your first mock',
          icon: Icons.mic_rounded,
          onPressed: () => context.go('/interview'),
        ),
        const SizedBox(height: HiredSpace.md),
        Center(
          child: TextAction(
            label: 'Or match your resume first',
            onPressed: () => context.go('/resume'),
          ),
        ),
      ],
    ),
  );
}

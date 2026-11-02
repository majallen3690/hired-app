import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/glass.dart';
import '../domain/application_models.dart';
import '../domain/tracker_logic.dart';

Color stageColor(HiredPalette c, Stage s) => switch (s) {
      Stage.wishlist => c.text2,
      Stage.applied => c.text,
      Stage.oa => c.warn,
      Stage.interview => c.signal,
      Stage.offer => c.ok,
      Stage.rejected => c.bad,
    };

class StageTag extends StatelessWidget {
  const StageTag(this.stage, {super.key});
  final Stage stage;

  @override
  Widget build(BuildContext context) {
    final color = stageColor(context.hc, stage);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(HiredRadii.tag)),
      child: Text(stage.label, style: HiredText.label.copyWith(color: color, letterSpacing: 0.2)),
    );
  }
}

/// The company's first letter on a quiet tile, as in the design.
class CompanyTile extends StatelessWidget {
  const CompanyTile(this.company, {super.key, this.size = 42});
  final String company;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(size / 3)),
      child: Text(companyInitial(company), style: HiredText.num(size * 0.42).copyWith(color: c.text)),
    );
  }
}

/// One application as a row in the list.
class ApplicationRow extends StatelessWidget {
  const ApplicationRow({super.key, required this.app, required this.now, required this.onTap});
  final JobApplication app;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Glass(
      radius: 16,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(children: [
        CompanyTile(app.company),
        const SizedBox(width: HiredSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.company, maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
            Text(
              app.role.isEmpty ? whenLabel(app, now) : '${app.role} · ${whenLabel(app, now)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HiredText.small.copyWith(color: c.text2),
            ),
          ]),
        ),
        const SizedBox(width: HiredSpace.sm),
        StageTag(app.stage),
      ]),
    );
  }
}

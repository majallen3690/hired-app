import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'controls.dart';
import 'glass.dart';

/// A sub-score figure that sits in the corner beside its own dial arc.
class ScoreCorner extends StatelessWidget {
  const ScoreCorner({
    super.key,
    required this.label,
    required this.value,
    required this.alignment,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final int? value;
  final Alignment alignment;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final v = value;
    final tone = highlight && v != null ? c.band(v) : null;
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          label: '$label ${v ?? 'not scored yet'}',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: alignment.x > 0 ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(v == null ? '–' : '$v', style: HiredText.num(30).copyWith(color: tone ?? c.text)),
              Text(
                label,
                style: HiredText.tiny.copyWith(
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                  color: tone ?? c.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass card with the single recommended next step and an ember arrow tile.
class NextActionCard extends StatelessWidget {
  const NextActionCard({
    super.key,
    required this.kicker,
    required this.lead,
    required this.emphasis,
    required this.note,
    required this.onTap,
  });

  final String kicker;
  final String lead;
  final String emphasis;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Glass(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(kicker),
                const SizedBox(height: 5),
                Text.rich(TextSpan(style: HiredText.lead.copyWith(color: c.text), children: [
                  TextSpan(text: '$lead '),
                  TextSpan(text: emphasis, style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                ])),
                const SizedBox(height: 5),
                Text(note, style: HiredText.small.copyWith(color: c.text3)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.ember, borderRadius: BorderRadius.circular(HiredRadii.button)),
            child: Icon(Icons.arrow_forward_rounded, color: c.onEmber),
          ),
        ],
      ),
    );
  }
}

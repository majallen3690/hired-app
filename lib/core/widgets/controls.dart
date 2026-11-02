import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The one filled action on a screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final press = onPressed;
    return PressScale(
      enabled: press != null,
      scale: 0.98,
      child: FilledButton(
        onPressed: press == null
            ? null
            : () {
                Haptics.tap();
                press();
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (icon != null) ...[const SizedBox(width: HiredSpace.sm), Icon(icon, size: 20)],
          ],
        ),
      ),
    );
  }
}

/// Secondary action: outline only.
class OutlineAction extends StatelessWidget {
  const OutlineAction({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final press = onPressed;
    return PressScale(
      enabled: press != null,
      scale: 0.98,
      child: OutlinedButton(
        onPressed: press == null
            ? null
            : () {
                Haptics.select();
                press();
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: HiredSpace.sm)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Tertiary action: text only.
class TextAction extends StatelessWidget {
  const TextAction({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PressScale(
        enabled: onPressed != null,
        scale: 0.96,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(foregroundColor: context.hc.text2),
          child: Text(label, style: HiredText.body.copyWith(fontWeight: FontWeight.w500)),
        ),
      );
}

/// Bare icon button, no bubble.
class IconAction extends StatelessWidget {
  const IconAction({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PressScale(
        enabled: onPressed != null,
        scale: 0.9,
        child: IconButton(
          onPressed: onPressed,
          tooltip: label,
          icon: Icon(icon, color: context.hc.text2),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiredRadii.chip)),
          ),
        ),
      );
}

/// Filter or selector chip. [selected] fills it with the text colour.
class HiredChip extends StatelessWidget {
  const HiredChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final radius = BorderRadius.circular(HiredRadii.chip);
    final fg = selected ? c.ink : c.text2;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: PressScale(
        enabled: onTap != null,
        scale: 0.95,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  if (!selected) Haptics.select();
                  onTap!();
                },
          child: AnimatedContainer(
            duration: HiredMotion.quick,
            curve: HiredMotion.easeOut,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? c.text : Colors.transparent,
              borderRadius: radius,
              border: Border.all(color: selected ? Colors.transparent : c.hair),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                AnimatedDefaultTextStyle(
                  duration: HiredMotion.quick,
                  curve: HiredMotion.easeOut,
                  style: HiredText.body.copyWith(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum TagTone { ok, warn, bad, ember, signal }

/// Small status tag. Colour is never the only signal: always pass a label.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = TagTone.ember});
  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final color = switch (tone) {
      TagTone.ok => c.ok,
      TagTone.warn => c.warn,
      TagTone.bad => c.bad,
      TagTone.ember => c.ember,
      TagTone.signal => c.signal,
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(HiredRadii.tag),
      ),
      child: Text(label, style: HiredText.label.copyWith(color: color, letterSpacing: 0.2)),
    );
  }
}

/// Segmented control, e.g. Dark / Light / System or the three rewrite options. The selection is one thumb that
/// slides between options rather than each option lighting up on its own.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final keys = options.keys.toList();
    final n = keys.length;
    final at = keys.indexOf(value).clamp(0, n - 1);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.track,
        borderRadius: BorderRadius.circular(HiredRadii.button),
      ),
      child: SizedBox(
        height: 38,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: HiredMotion.tab,
              curve: HiredMotion.drawer,
              alignment: Alignment(n < 2 ? 0 : -1 + 2 * at / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.selected, borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
            Row(
              children: [
                for (final e in options.entries)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: e.key == value,
                      child: GestureDetector(
                        onTap: () {
                          if (e.key != value) Haptics.select();
                          onChanged(e.key);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: HiredMotion.quick,
                            curve: HiredMotion.easeOut,
                            style: HiredText.body.copyWith(
                              fontSize: 14,
                              fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                              color: e.key == value ? c.text : c.text3,
                            ),
                            child: Text(e.value),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Uppercase mono micro label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: HiredText.label.copyWith(color: context.hc.text3));
}

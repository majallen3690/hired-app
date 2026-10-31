import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The one filled action on a screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (icon != null) ...[const SizedBox(width: HiredSpace.sm), Icon(icon, size: 20)],
          ],
        ),
      );
}

/// Secondary action: outline only.
class OutlineAction extends StatelessWidget {
  const OutlineAction({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: HiredSpace.sm)],
            Text(label),
          ],
        ),
      );
}

/// Tertiary action: text only.
class TextAction extends StatelessWidget {
  const TextAction({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: context.hc.text2),
        child: Text(label, style: HiredText.body.copyWith(fontWeight: FontWeight.w500)),
      );
}

/// Bare icon button, no bubble.
class IconAction extends StatelessWidget {
  const IconAction({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon, color: context.hc.text2),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HiredRadii.chip)),
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
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? c.text : Colors.transparent,
        borderRadius: BorderRadius.circular(HiredRadii.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HiredRadii.chip),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HiredRadii.chip),
              border: selected ? null : Border.all(color: c.hair),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: selected ? c.ink : c.text2), const SizedBox(width: 6)],
                Text(
                  label,
                  style: HiredText.body.copyWith(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? c.ink : c.text2,
                  ),
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

/// Segmented control, e.g. Dark / Light / System or the three rewrite options.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.track,
        borderRadius: BorderRadius.circular(HiredRadii.button),
      ),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: e.key == value,
                child: GestureDetector(
                  onTap: () => onChanged(e.key),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == value ? c.selected : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      e.value,
                      style: HiredText.body.copyWith(
                        fontSize: 14,
                        fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                        color: e.key == value ? c.text : c.text3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The one text field style: filled glass, a hairline, an ember ring when focused, an optional label above.
class HiredField extends StatelessWidget {
  const HiredField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboard,
    this.action,
    this.onSubmitted,
    this.onChanged,
    this.autofill,
    this.error,
    this.capitalize = TextCapitalization.none,
    this.enabled = true,
    this.focusNode,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofill;
  final String? error;
  final TextCapitalization capitalize;
  final bool enabled;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    OutlineInputBorder border(Color color, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(HiredRadii.button),
          borderSide: BorderSide(color: color, width: w),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: HiredText.small.copyWith(color: c.text2, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboard,
          textInputAction: action,
          textCapitalization: capitalize,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autofillHints: autofill,
          inputFormatters: inputFormatters,
          autocorrect: !obscure && keyboard != TextInputType.emailAddress,
          enableSuggestions: !obscure,
          style: HiredText.body.copyWith(color: c.text),
          cursorColor: c.ember,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: HiredText.body.copyWith(color: c.text3),
            filled: true,
            fillColor: c.glassBottom,
            prefixIcon: icon == null ? null : Icon(icon, color: c.text3, size: 20),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: HiredSpace.lg, vertical: 16),
            border: border(error == null ? c.hair : c.bad),
            enabledBorder: border(error == null ? c.hair : c.bad),
            focusedBorder: border(error == null ? c.ember : c.bad, 1.5),
            disabledBorder: border(c.hair),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.error_outline_rounded, size: 14, color: c.bad),
            const SizedBox(width: 6),
            Expanded(child: Text(error!, style: HiredText.tiny.copyWith(color: c.bad))),
          ]),
        ],
      ],
    );
  }
}

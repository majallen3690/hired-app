import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/structured.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../domain/match_models.dart';
import '../resume_flow.dart';

void showRewriteSheet(BuildContext context, {required String bullet}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.hc.ink2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(HiredRadii.card))),
    builder: (_) => _RewriteSheet(bullet: bullet),
  );
}

class _RewriteSheet extends ConsumerStatefulWidget {
  const _RewriteSheet({required this.bullet});
  final String bullet;

  @override
  ConsumerState<_RewriteSheet> createState() => _RewriteSheetState();
}

class _RewriteSheetState extends ConsumerState<_RewriteSheet> {
  List<Rewrite>? _rewrites;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _rewrites = null;
      _error = null;
    });
    try {
      final r = await ref.read(resumeFlowProvider.notifier).rewrite(widget.bullet);
      if (mounted) setState(() => _rewrites = r);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Bracket placeholders are highlighted so they cannot be mistaken for real numbers.
  List<InlineSpan> _spans(String text, HiredPalette c) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp(r'\[[^\]]*\]').allMatches(text)) {
      out.add(TextSpan(text: text.substring(last, m.start)));
      out.add(TextSpan(
        text: m.group(0),
        style: TextStyle(color: c.warn, fontWeight: FontWeight.w600, backgroundColor: c.warn.withValues(alpha: 0.12)),
      ));
      last = m.end;
    }
    out.add(TextSpan(text: text.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final rewrites = _rewrites;
    return Padding(
      padding: EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.screen, HiredSpace.screen,
          HiredSpace.screen + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionLabel('Before'),
        const SizedBox(height: 6),
        Text(widget.bullet, style: HiredText.body.copyWith(color: c.text3, decoration: TextDecoration.lineThrough)),
        const SizedBox(height: HiredSpace.xl),
        if (_error != null) ...[
          Text(_error!, style: HiredText.body.copyWith(color: c.bad)),
          const SizedBox(height: HiredSpace.lg),
          OutlineAction(label: 'Try again', onPressed: _load),
        ] else if (rewrites == null) ...[
          Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.ember)),
            const SizedBox(width: HiredSpace.md),
            Text('Writing three versions', style: HiredText.body.copyWith(color: c.text2)),
          ]),
          const SizedBox(height: HiredSpace.xl),
        ] else ...[
          Segmented<int>(options: {for (var i = 0; i < rewrites.length; i++) i: 'Option ${i + 1}'}, value: _tab, onChanged: (v) => setState(() => _tab = v)),
          const SizedBox(height: HiredSpace.lg),
          const SectionLabel('After'),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text.rich(
              TextSpan(style: HiredText.lead.copyWith(color: c.text), children: _spans(rewrites[_tab].text, c)),
              key: ValueKey(_tab),
            ),
          ),
          if (rewrites[_tab].placeholders.isNotEmpty) ...[
            const SizedBox(height: HiredSpace.md),
            Text('Fill in the highlighted values with your real numbers. We never invent them.',
                style: HiredText.small.copyWith(color: c.text3)),
          ],
          const SizedBox(height: HiredSpace.xl),
          PrimaryButton(
            label: 'Copy',
            icon: Icons.copy_rounded,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rewrites[_tab].text));
              Navigator.of(context).pop();
            },
          ),
        ],
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/glass.dart';
import '../data/application_store.dart';
import '../domain/application_models.dart';
import '../domain/tracker_logic.dart';
import 'kanban_board.dart';
import 'tracker_widgets.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/skeleton.dart';

enum _View { list, board }

class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});

  @override
  ConsumerState<TrackerScreen> createState() => _State();
}

class _State extends ConsumerState<TrackerScreen> {
  var _view = _View.list;
  Stage? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final async = ref.watch(applicationsProvider);
    return SafeArea(
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.xxl, HiredSpace.screen, 0), child: SkeletonCards(count: 5)),
        error: (e, _) => Center(child: Text('Could not open your applications.', style: HiredText.body.copyWith(color: c.text2))),
        data: (apps) => apps.isEmpty ? _empty(c) : _content(c, apps),
      ),
    );
  }

  Widget _content(HiredPalette c, List<JobApplication> apps) {
    final now = DateTime.now();
    final counts = stageCounts(apps);
    final due = followUps(apps, now);
    final shown = byUrgency(_filter == null ? apps : apps.where((a) => a.stage == _filter).toList());
    final listView = _view == _View.list;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, 0),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${apps.length} ${apps.length == 1 ? 'company' : 'companies'}', style: HiredText.small.copyWith(color: c.text3)),
                Text('Applications', style: HiredText.h1.copyWith(color: c.text)),
              ]),
            ),
            Semantics(
              button: true,
              label: 'Add application',
              child: GestureDetector(
                onTap: () => context.push('/tracker/add'),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: c.ember, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.add_rounded, color: c.onEmber, size: 26),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: HiredSpace.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HiredSpace.screen),
          child: Segmented<_View>(
            options: const {_View.list: 'List', _View.board: 'Board'},
            value: _view,
            onChanged: (v) => setState(() => _view = v),
          ),
        ),
        const SizedBox(height: HiredSpace.md),
        if (listView) ...[
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: HiredSpace.screen),
              children: [
                _chip('All', apps.length, _filter == null, () => setState(() => _filter = null)),
                for (final s in Stage.values) _chip(s.label, counts[s]!, _filter == s, () => setState(() => _filter = s)),
              ],
            ),
          ),
          const SizedBox(height: HiredSpace.md),
        ],
        if (due.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(HiredSpace.screen, 0, HiredSpace.screen, HiredSpace.md),
            child: _followUp(c, due, now),
          ),
        Expanded(
          child: listView
              ? (shown.isEmpty
                  ? Center(child: Text('Nothing in ${_filter!.label} yet.', style: HiredText.body.copyWith(color: c.text3)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(HiredSpace.screen, 0, HiredSpace.screen, 120),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: HiredSpace.sm),
                      itemBuilder: (context, i) => Reveal(
                        index: i,
                        child: ApplicationRow(
                          app: shown[i],
                          now: now,
                          onTap: () => context.push('/tracker/${shown[i].id}'),
                        ),
                      ),
                    ))
              : KanbanBoard(
                  apps: apps,
                  onMove: (id, stage) => ref.read(applicationsProvider.notifier).move(id, stage),
                  onOpen: (id) => context.push('/tracker/$id'),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, int count, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: HiredChip(label: '$label $count', selected: selected, onTap: onTap),
      );

  Widget _followUp(HiredPalette c, List<JobApplication> due, DateTime now) {
    final first = due.first;
    final days = daysBetween(first.stageChangedAt, now);
    final more = due.length - 1;
    return Glass(
      onTap: () => context.push('/tracker/${first.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.warn.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(Icons.notifications_active_rounded, color: c.warn, size: 22),
        ),
        const SizedBox(width: HiredSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(more == 0 ? 'Follow up with ${first.company}' : 'Follow up with ${first.company} and $more more',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
            Text('$days days since you applied', style: HiredText.small.copyWith(color: c.text2)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: c.text2),
      ]),
    );
  }

  Widget _empty(HiredPalette c) => RevealListView(
        padding: const EdgeInsets.fromLTRB(HiredSpace.screen, HiredSpace.md, HiredSpace.screen, 120),
        children: [
          Text('Nothing tracked yet', style: HiredText.small.copyWith(color: c.text3)),
          Text('Applications', style: HiredText.h1.copyWith(color: c.text)),
          const SizedBox(height: 36),
          Center(
            child: Glass(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 210,
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: c.ember, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.work_rounded, color: c.onEmber, size: 22),
                  ),
                  const SizedBox(width: HiredSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Your first company', style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
                      Text('Applied · today', style: HiredText.small.copyWith(color: c.text2)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text.rich(
            TextSpan(style: HiredText.h1.copyWith(color: c.text), children: [
              const TextSpan(text: 'No applications '),
              TextSpan(text: 'yet', style: HiredText.h1Em),
            ]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HiredSpace.sm),
          Text(
            'Paste a job description and Hired fills in the company, role and key skills. You will see when it is time to follow up.',
            textAlign: TextAlign.center,
            style: HiredText.body.copyWith(color: c.text2),
          ),
          const SizedBox(height: HiredSpace.xl),
          PrimaryButton(label: 'Paste a job description', icon: Icons.content_paste_rounded, onPressed: () => context.push('/tracker/add')),
          const SizedBox(height: HiredSpace.sm),
          Center(child: TextAction(label: 'Add it manually', onPressed: () => context.push('/tracker/add?manual=1'))),
        ],
      );
}

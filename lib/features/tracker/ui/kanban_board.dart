import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../domain/application_models.dart';
import '../domain/tracker_logic.dart';
import 'tracker_widgets.dart';
import '../../../core/motion/motion.dart';

const _columnWidth = 262.0;
const _edge = 64.0;

/// One column per stage. Long-press a card, drag it to another column, drop. The board scrolls sideways by itself
/// when a card is held near either edge.
class KanbanBoard extends StatefulWidget {
  const KanbanBoard({super.key, required this.apps, required this.onMove, required this.onOpen});

  final List<JobApplication> apps;
  final void Function(String id, Stage stage) onMove;
  final void Function(String id) onOpen;

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  final _scroll = ScrollController();
  Timer? _autoScroll;
  double _dragX = -1;

  @override
  void dispose() {
    _autoScroll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients || _dragX < 0) return;
      final width = MediaQuery.sizeOf(context).width;
      var step = 0.0;
      if (_dragX < _edge) step = -10;
      if (_dragX > width - _edge) step = 10;
      if (step != 0) {
        _scroll.jumpTo((_scroll.offset + step).clamp(0.0, _scroll.position.maxScrollExtent));
      }
    });
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
    _dragX = -1;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(HiredSpace.screen, 0, HiredSpace.screen, 110),
      itemCount: Stage.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: HiredSpace.md),
      itemBuilder: (context, i) {
        final stage = Stage.values[i];
        return _Column(
          stage: stage,
          apps: inStage(widget.apps, stage),
          now: now,
          onDrop: (id) => widget.onMove(id, stage),
          onOpen: widget.onOpen,
          onDragStart: _startAutoScroll,
          onDragMove: (x) => _dragX = x,
          onDragEnd: _stopAutoScroll,
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.stage,
    required this.apps,
    required this.now,
    required this.onDrop,
    required this.onOpen,
    required this.onDragStart,
    required this.onDragMove,
    required this.onDragEnd,
  });

  final Stage stage;
  final List<JobApplication> apps;
  final DateTime now;
  final void Function(String id) onDrop;
  final void Function(String id) onOpen;
  final VoidCallback onDragStart;
  final void Function(double x) onDragMove;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final color = stageColor(c, stage);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) {
        Haptics.select();
        onDrop(d.data);
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: _columnWidth,
          padding: const EdgeInsets.all(HiredSpace.sm),
          decoration: BoxDecoration(
            color: hovering ? color.withValues(alpha: 0.10) : c.glassBottom,
            borderRadius: BorderRadius.circular(HiredRadii.card),
            border: Border.all(color: hovering ? color : c.hair, width: hovering ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: HiredSpace.sm),
                  Expanded(child: Text(stage.label, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600))),
                  Text('${apps.length}', style: HiredText.small.copyWith(color: c.text3)),
                ]),
              ),
              Expanded(
                child: apps.isEmpty
                    ? Center(
                        child: Text(hovering ? 'Drop here' : 'Nothing here',
                            style: HiredText.small.copyWith(color: hovering ? color : c.text3)),
                      )
                    : ListView.separated(
                        itemCount: apps.length,
                        separatorBuilder: (_, __) => const SizedBox(height: HiredSpace.sm),
                        itemBuilder: (context, i) => _Card(
                          app: apps[i],
                          now: now,
                          onTap: () => onOpen(apps[i].id),
                          onDragStart: onDragStart,
                          onDragMove: onDragMove,
                          onDragEnd: onDragEnd,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.app,
    required this.now,
    required this.onTap,
    required this.onDragStart,
    required this.onDragMove,
    required this.onDragEnd,
  });

  final JobApplication app;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final void Function(double x) onDragMove;
  final VoidCallback onDragEnd;

  Widget _body(BuildContext context, {bool lifted = false}) {
    final c = context.hc;
    return Material(
      color: lifted ? c.ink2 : c.ink2.withValues(alpha: 0.7),
      elevation: lifted ? 8 : 0,
      borderRadius: BorderRadius.circular(HiredRadii.tile),
      child: Container(
        width: _columnWidth - HiredSpace.sm * 2,
        padding: const EdgeInsets.all(HiredSpace.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HiredRadii.tile),
          border: Border.all(color: lifted ? c.ember : c.hair),
        ),
        child: Row(children: [
          CompanyTile(app.company, size: 36),
          const SizedBox(width: HiredSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.company, maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.body.copyWith(color: c.text, fontWeight: FontWeight.w600)),
              if (app.role.isNotEmpty)
                Text(app.role, maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.small.copyWith(color: c.text2)),
              Text(whenLabel(app, now), maxLines: 1, overflow: TextOverflow.ellipsis, style: HiredText.tiny.copyWith(color: c.text3)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<String>(
      data: app.id,
      feedback: _body(context, lifted: true),
      childWhenDragging: Opacity(opacity: 0.3, child: _body(context)),
      onDragStarted: () {
        Haptics.tap();
        onDragStart();
      },
      onDragUpdate: (d) => onDragMove(d.globalPosition.dx),
      onDragEnd: (_) => onDragEnd(),
      onDraggableCanceled: (_, __) => onDragEnd(),
      child: PressScale(child: GestureDetector(onTap: onTap, child: _body(context))),
    );
  }
}

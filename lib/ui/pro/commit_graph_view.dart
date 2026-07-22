import 'package:flutter/material.dart';

import '../../models/git_models.dart';
import '../../theme/app_theme.dart';

class CommitGraphView extends StatelessWidget {
  const CommitGraphView({
    super.key,
    required this.nodes,
    required this.selectedHash,
    required this.onSelect,
    this.onSecondarySelect,
  });

  final List<GraphNode> nodes;
  final String? selectedHash;
  final ValueChanged<GitCommit> onSelect;
  final void Function(GitCommit commit, Offset globalPosition)? onSecondarySelect;

  static const double rowHeight = 46;
  static const double laneWidth = 18;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const Center(
        child: Text('No commits', style: TextStyle(color: AppTheme.proMuted)),
      );
    }

    final laneCount = nodes.first.laneCount.clamp(1, 12);
    final graphWidth = laneCount * laneWidth + 20.0;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ListView.builder(
        itemCount: nodes.length,
        itemExtent: rowHeight,
        itemBuilder: (context, index) {
          final node = nodes[index];
          final selected = node.commit.hash == selectedHash;
          final next = index + 1 < nodes.length ? nodes[index + 1] : null;

          return Material(
            color: selected ? AppTheme.proAccent.withValues(alpha: 0.14) : Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(node.commit),
              onSecondaryTapDown: onSecondarySelect == null
                  ? null
                  : (details) {
                      onSelect(node.commit);
                      onSecondarySelect!(node.commit, details.globalPosition);
                    },
              hoverColor: AppTheme.proAccent.withValues(alpha: 0.06),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.proBorderSoft.withValues(alpha: 0.6)),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: graphWidth,
                      height: rowHeight,
                      child: CustomPaint(
                        painter: _GraphPainter(
                          node: node,
                          next: next,
                          rowHeight: rowHeight,
                          laneWidth: laneWidth,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: _CommitMeta(commit: node.commit, selected: selected),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CommitMeta extends StatelessWidget {
  const _CommitMeta({required this.commit, required this.selected});

  final GitCommit commit;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (commit.refs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      for (final ref in commit.refs.take(4))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: ref.contains('origin')
                                ? AppTheme.proAccent2.withValues(alpha: 0.2)
                                : AppTheme.proAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: ref.contains('origin') ? AppTheme.proAccent2 : AppTheme.proAccent,
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            ref,
                            style: TextStyle(
                              fontSize: 10,
                              color: ref.contains('origin') ? AppTheme.proAccent2 : AppTheme.proAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Text(
                commit.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.proText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            commit.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.proMuted, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 88,
          child: Text(
            commit.date,
            style: const TextStyle(color: AppTheme.proMuted, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            commit.shortHash,
            style: const TextStyle(
              color: AppTheme.proWarn,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.node,
    required this.next,
    required this.rowHeight,
    required this.laneWidth,
  });

  final GraphNode node;
  final GraphNode? next;
  final double rowHeight;
  final double laneWidth;

  Color _color(int lane) => AppTheme.graphColors[lane % AppTheme.graphColors.length];

  Offset _point(int lane, double y) => Offset(14 + lane * laneWidth, y);

  @override
  void paint(Canvas canvas, Size size) {
    final midY = rowHeight / 2;

    for (final conn in node.connections) {
      final paint = Paint()
        ..color = _color(conn.isMerge ? conn.toLane : conn.fromLane)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final from = _point(conn.fromLane, midY);
      final to = _point(conn.toLane, rowHeight);

      if (conn.fromLane == conn.toLane) {
        canvas.drawLine(from, Offset(from.dx, rowHeight), paint);
      } else {
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(from.dx, from.dy + 12, to.dx, midY + 8, to.dx, rowHeight);
        canvas.drawPath(path, paint);
      }
    }

    // Incoming from previous is implied by previous row's connections.
    // Draw vertical stubs for active lanes toward next.
    if (next != null) {
      for (final lane in node.activeLanes) {
        if (lane == node.lane) continue;
        final paint = Paint()
          ..color = _color(lane).withValues(alpha: 0.55)
          ..strokeWidth = 2;
        final x = _point(lane, 0).dx;
        canvas.drawLine(Offset(x, 0), Offset(x, rowHeight), paint);
      }
    }

    final nodePaint = Paint()..color = _color(node.lane);
    final center = _point(node.lane, midY);
    canvas.drawCircle(center, node.commit.isMerge ? 6 : 5, nodePaint);
    canvas.drawCircle(
      center,
      node.commit.isMerge ? 6 : 5,
      Paint()
        ..color = AppTheme.proBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    if (node.commit.isMerge) {
      canvas.drawCircle(center, 2.5, Paint()..color = AppTheme.proBg);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.node != node || oldDelegate.next != next;
  }
}

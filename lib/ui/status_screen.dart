import 'package:flutter/material.dart';

import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';
import 'widgets/common.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.controller});

  final RepoController controller;

  @override
  Widget build(BuildContext context) {
    final staged = controller.changes.where((c) => c.staged).toList();
    final unstaged = controller.changes.where((c) => !c.staged).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'وضعیت',
          subtitle: controller.changes.isEmpty
              ? 'پوشه کاری تمیز است'
              : '${controller.changes.length} تغییر',
          actions: [
            OutlinedButton(
              onPressed: controller.busy ? null : controller.unstageAll,
              child: const Text('Unstage'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: controller.busy ? null : controller.stageAll,
              child: const Text('Stage همه'),
            ),
          ],
        ),
        Expanded(
          child: controller.changes.isEmpty
              ? const EmptyHint(
                  icon: Icons.check_circle_outline,
                  message: 'تغییری برای نمایش نیست',
                )
              : ListView(
                  children: [
                    _Group(
                      title: 'آماده‌ی کامیت (staged)',
                      color: AppTheme.leaf,
                      children: staged
                          .map(
                            (c) => ListTile(
                              dense: true,
                              leading: Text(c.statusCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                              title: Text(c.path, textDirection: TextDirection.ltr),
                              trailing: Text(c.label),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    _Group(
                      title: 'تغییرات / پیگیری‌نشده',
                      color: AppTheme.amber,
                      children: unstaged
                          .map(
                            (c) => ListTile(
                              dense: true,
                              leading: Text(c.statusCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                              title: Text(c.path, textDirection: TextDirection.ltr),
                              trailing: Text(c.label),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.color,
    required this.children,
  });

  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              '$title (${children.length})',
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ),
          if (children.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('خالی'),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

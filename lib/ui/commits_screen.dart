import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';
import 'widgets/common.dart';

class CommitsScreen extends StatelessWidget {
  const CommitsScreen({super.key, required this.controller});

  final RepoController controller;

  @override
  Widget build(BuildContext context) {
    final commits = controller.commits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'تاریخچه',
          subtitle: commits.isEmpty ? 'هنوز کامیتی نیست' : '${commits.length} کامیت اخیر',
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: controller.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Expanded(
          child: commits.isEmpty
              ? const EmptyHint(icon: Icons.history, message: 'کامیتی برای نمایش نیست')
              : SoftPanel(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: commits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final commit = commits[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.leaf.withValues(alpha: 0.12),
                          foregroundColor: AppTheme.leaf,
                          child: Text(
                            commit.shortHash.substring(0, 2).toUpperCase(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(commit.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${commit.shortHash} · ${commit.author} · ${commit.date}',
                          textDirection: TextDirection.ltr,
                        ),
                        trailing: IconButton(
                          tooltip: 'کپی هش',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: commit.hash));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('هش کپی شد')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

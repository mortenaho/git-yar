import 'package:flutter/material.dart';

import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';
import 'widgets/common.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.controller});

  final RepoController controller;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _messageController = TextEditingController();
  bool _suggesting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    setState(() => _suggesting = true);
    try {
      final message = await widget.controller.suggestCommitMessage();
      _messageController.text = message;
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _commit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پیام کامیت را وارد کنید')),
      );
      return;
    }
    await widget.controller.stageAll();
    await widget.controller.commit(message);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final repo = c.repo;

    return ListView(
      children: [
        const SectionHeader(
          title: 'دستیار گیت',
          subtitle: 'کارهای پرتکرار را با یک کلیک انجام بده',
        ),
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                repo?.name ?? '',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                repo?.path ?? '',
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.moss),
              ),
              if (repo?.currentBranch != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'برنچ فعلی: ${repo!.currentBranch}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.leaf),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('همگام‌سازی', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: c.busy ? null : c.fetch,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Fetch'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: c.busy ? null : c.pull,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Pull'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: c.busy ? null : () => c.push(),
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Push'),
                  ),
                  OutlinedButton.icon(
                    onPressed: c.busy ? null : () => c.push(setUpstream: true),
                    icon: const Icon(Icons.link),
                    label: const Text('Push -u'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('کامیت سریع', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('اول همه تغییرات stage می‌شوند، بعد کامیت ثبت می‌شود.'),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'پیام کامیت',
                  hintText: 'feat: ...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: c.busy || _suggesting ? null : _suggest,
                      icon: _suggesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('پیشنهاد پیام'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: c.busy ? null : _commit,
                      icon: const Icon(Icons.commit),
                      label: const Text('Stage + Commit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Stash', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: c.busy ? null : () => c.stash(),
                      child: const Text('Stash'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: c.busy ? null : c.stashPop,
                      child: const Text('Stash Pop'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (c.lastLog != null) ...[
          const SizedBox(height: 16),
          SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('خروجی آخر', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SelectableText(
                  c.lastLog!,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

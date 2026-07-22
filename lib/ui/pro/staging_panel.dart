import 'package:flutter/material.dart';

import '../../models/git_models.dart';
import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';

class StagingPanel extends StatefulWidget {
  const StagingPanel({super.key, required this.controller});

  final RepoController controller;

  @override
  State<StagingPanel> createState() => _StagingPanelState();
}

class _StagingPanelState extends State<StagingPanel> {
  final _message = TextEditingController();
  bool _suggesting = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: 'Unstaged Files',
            count: c.unstaged.length,
            actionLabel: 'Stage all',
            onAction: c.unstaged.isEmpty || c.busy ? null : c.stageAll,
          ),
          Expanded(
            flex: 2,
            child: _FileList(
              files: c.unstaged,
              selected: c.selectedFile,
              onSelect: c.selectFile,
              trailingBuilder: (f) => IconButton(
                tooltip: 'Stage',
                icon: const Icon(Icons.keyboard_arrow_up, size: 18, color: AppTheme.proAccent),
                onPressed: c.busy ? null : () => c.stageFile(f.path),
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.proBorder),
          _Header(
            title: 'Staged Files',
            count: c.staged.length,
            actionLabel: 'Unstage all',
            onAction: c.staged.isEmpty || c.busy ? null : c.unstageAll,
          ),
          Expanded(
            flex: 2,
            child: _FileList(
              files: c.staged,
              selected: c.selectedFile,
              onSelect: c.selectFile,
              trailingBuilder: (f) => IconButton(
                tooltip: 'Unstage',
                icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.proWarn),
                onPressed: c.busy ? null : () => c.unstageFile(f.path),
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.proBorder),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _message,
                  minLines: 2,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: AppTheme.proText),
                  decoration: const InputDecoration(
                    hintText: 'Commit message',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: c.busy || _suggesting
                            ? null
                            : () async {
                                setState(() => _suggesting = true);
                                final msg = await c.suggestCommitMessage();
                                _message.text = msg;
                                setState(() => _suggesting = false);
                              },
                        child: Text(_suggesting ? '…' : 'Suggest'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: c.busy || c.staged.isEmpty
                            ? null
                            : () async {
                                final msg = _message.text.trim();
                                if (msg.isEmpty) return;
                                await c.commit(msg);
                                _message.clear();
                              },
                        child: Text('Commit (${c.staged.length})'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.count,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final int count;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.proPanelAlt,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.proMuted,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    required this.files,
    required this.selected,
    required this.onSelect,
    required this.trailingBuilder,
  });

  final List<GitFileChange> files;
  final GitFileChange? selected;
  final ValueChanged<GitFileChange> onSelect;
  final Widget Function(GitFileChange) trailingBuilder;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(
        child: Text('No files', style: TextStyle(color: AppTheme.proMuted, fontSize: 12)),
      );
    }
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final f = files[index];
        final isSelected = selected?.path == f.path && selected?.staged == f.staged;
        return Material(
          color: isSelected ? AppTheme.proAccent.withValues(alpha: 0.12) : Colors.transparent,
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            onTap: () => onSelect(f),
            leading: Text(
              f.statusCode,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: _statusColor(f.statusCode),
                fontFamily: 'monospace',
              ),
            ),
            title: Text(
              f.path,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.proText),
            ),
            trailing: trailingBuilder(f),
          ),
        );
      },
    );
  }

  Color _statusColor(String code) {
    switch (code) {
      case 'A':
      case '?':
        return AppTheme.proGreen;
      case 'D':
        return AppTheme.proDanger;
      case 'M':
        return AppTheme.proWarn;
      default:
        return AppTheme.proAccent2;
    }
  }
}

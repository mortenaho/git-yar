import 'package:flutter/material.dart';

import '../../models/git_models.dart';
import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';

class BranchSidebar extends StatefulWidget {
  const BranchSidebar({super.key, required this.controller});

  final RepoController controller;

  @override
  State<BranchSidebar> createState() => _BranchSidebarState();
}

class _BranchSidebarState extends State<BranchSidebar> {
  bool _localOpen = true;
  bool _remoteOpen = true;
  bool _stashOpen = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.folder_special_outlined, size: 16, color: AppTheme.proAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.repo?.name ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.proText),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.proBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _Section(
                  title: 'LOCAL',
                  open: _localOpen,
                  onToggle: () => setState(() => _localOpen = !_localOpen),
                  count: c.localBranches.length,
                  child: _localOpen
                      ? Column(
                          children: [
                            for (final b in c.localBranches)
                              _BranchTile(
                                branch: b,
                                onTap: () => c.checkout(b.name),
                                onDelete: b.isCurrent ? null : () => c.deleteBranch(b.name),
                              ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                _Section(
                  title: 'REMOTE',
                  open: _remoteOpen,
                  onToggle: () => setState(() => _remoteOpen = !_remoteOpen),
                  count: c.remoteBranches.length,
                  child: _remoteOpen
                      ? Column(
                          children: [
                            for (final b in c.remoteBranches)
                              _BranchTile(
                                branch: b,
                                onTap: () => c.checkout(b.name),
                              ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                _Section(
                  title: 'STASHES',
                  open: _stashOpen,
                  onToggle: () => setState(() => _stashOpen = !_stashOpen),
                  count: c.stashes.length,
                  child: _stashOpen
                      ? Column(
                          children: [
                            if (c.stashes.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Empty', style: TextStyle(color: AppTheme.proMuted, fontSize: 12)),
                                ),
                              ),
                            for (final s in c.stashes)
                              ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: const Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.proWarn),
                                title: Text(
                                  s.message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.proText),
                                ),
                                subtitle: Text(s.ref, style: const TextStyle(fontSize: 10, color: AppTheme.proMuted)),
                                onTap: () => c.applyStash(s.ref),
                              ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              onPressed: c.busy
                  ? null
                  : () async {
                      final name = await _askBranchName(context);
                      if (name != null && name.isNotEmpty) {
                        await c.createBranch(name);
                      }
                    },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Branch'),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askBranchName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.proPanel,
        title: const Text('New branch'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'feature/awesome'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.count,
    required this.child,
  });

  final String title;
  final bool open;
  final VoidCallback onToggle;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(open ? Icons.expand_more : Icons.chevron_right, size: 16, color: AppTheme.proMuted),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppTheme.proMuted,
                  ),
                ),
                const Spacer(),
                Text('$count', style: const TextStyle(fontSize: 11, color: AppTheme.proMuted)),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({
    required this.branch,
    required this.onTap,
    this.onDelete,
  });

  final GitBranch branch;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      selected: branch.isCurrent,
      selectedTileColor: AppTheme.proAccent.withValues(alpha: 0.1),
      leading: Icon(
        branch.isRemote ? Icons.cloud_outlined : Icons.commit,
        size: 16,
        color: branch.isCurrent ? AppTheme.proAccent : AppTheme.proMuted,
      ),
      title: Text(
        branch.name,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: branch.isCurrent ? FontWeight.w800 : FontWeight.w500,
          color: AppTheme.proText,
        ),
      ),
      subtitle: (branch.ahead > 0 || branch.behind > 0)
          ? Text(
              [
                if (branch.ahead > 0) '↑${branch.ahead}',
                if (branch.behind > 0) '↓${branch.behind}',
              ].join(' '),
              style: const TextStyle(fontSize: 10, color: AppTheme.proMuted),
            )
          : null,
      trailing: onDelete == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 14, color: AppTheme.proMuted),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
      onTap: branch.isCurrent ? null : onTap,
    );
  }
}

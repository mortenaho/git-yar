import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';
import 'branch_sidebar.dart';
import 'code_editor/code_pane.dart';
import 'commit_graph_view.dart';
import 'conflict_resolver.dart';
import 'git_dialogs.dart';
import 'reports_panel.dart';
import 'staging_panel.dart';

class ProWorkspace extends StatefulWidget {
  const ProWorkspace({
    super.key,
    required this.controller,
  });

  final RepoController controller;

  @override
  State<ProWorkspace> createState() => _ProWorkspaceState();
}

class _ProWorkspaceState extends State<ProWorkspace> {
  double _rightWidth = 440;
  double _bottomHeight = 240;
  bool _showStaging = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final error = widget.controller.error;
    if (error != null && error.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      widget.controller.error = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (!c.busy) c.refresh();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppTheme.proBg,
          body: Column(
            children: [
              _ProChrome(
                controller: c,
                showStaging: _showStaging,
                onToggleStaging: () => setState(() => _showStaging = !_showStaging),
              ),
              if (c.hasConflictState) _ConflictBanner(controller: c),
              if (c.loading || c.busy)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppTheme.proAccent,
                  backgroundColor: AppTheme.proBorderSoft,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      _GlassPane(
                        width: 248,
                        child: BranchSidebar(controller: c),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _GlassPane(
                                      child: Column(
                                        children: [
                                          const _GraphHeader(),
                                          Expanded(
                                            child: CommitGraphView(
                                              nodes: c.graph,
                                              selectedHash: c.selectedCommit?.hash,
                                              onSelect: c.selectCommit,
                                              onSecondarySelect: (commit, pos) {
                                                showCommitContextMenu(
                                                  context: context,
                                                  globalPosition: pos,
                                                  controller: c,
                                                  commit: commit,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (wide) ...[
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: _rightWidth,
                                      child: Stack(
                                        children: [
                                          _GlassPane(
                                            child: CodePane(controller: c),
                                          ),
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.translucent,
                                              onHorizontalDragUpdate: (d) {
                                                setState(() {
                                                  _rightWidth = (_rightWidth - d.delta.dx).clamp(320, 720);
                                                });
                                              },
                                              child: const MouseRegion(
                                                cursor: SystemMouseCursors.resizeColumn,
                                                child: SizedBox(width: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_showStaging) ...[
                              const SizedBox(height: 8),
                              MouseRegion(
                                cursor: SystemMouseCursors.resizeRow,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onVerticalDragUpdate: (d) {
                                    setState(() {
                                      _bottomHeight = (_bottomHeight - d.delta.dy).clamp(160, 440);
                                    });
                                  },
                                  child: Center(
                                    child: Container(
                                      width: 42,
                                      height: 4,
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.proBorder,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: _bottomHeight,
                                child: wide
                                    ? _GlassPane(child: StagingPanel(controller: c))
                                    : Row(
                                        children: [
                                          Expanded(child: _GlassPane(child: StagingPanel(controller: c))),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _GlassPane(
                                              child: CodePane(controller: c),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPane extends StatelessWidget {
  const _GlassPane({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final pane = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.proPanel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.proBorder.withValues(alpha: 0.9)),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
    if (width == null) return pane;
    return SizedBox(width: width, child: pane);
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.controller});

  final RepoController controller;

  @override
  Widget build(BuildContext context) {
    final rebasing = controller.isRebasing;
    final count = controller.conflicts.length;
    return Container(
      width: double.infinity,
      color: AppTheme.proWarn.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.proWarn, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count > 0
                  ? '${rebasing ? "Rebase" : controller.isMerging ? "Merge" : "Conflict"} · $count unresolved file${count == 1 ? "" : "s"}'
                  : rebasing
                      ? 'Rebase in progress — conflicts resolved, continue when ready'
                      : 'Merge in progress — conflicts resolved, commit when ready',
              style: const TextStyle(color: AppTheme.proWarn, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (count > 0)
            FilledButton(
              onPressed: () => showConflictResolver(context, controller),
              child: const Text('Resolve conflicts'),
            ),
          const SizedBox(width: 8),
          if (rebasing) ...[
            TextButton(
              onPressed: controller.busy || count > 0 ? null : controller.rebaseContinue,
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: controller.busy ? null : controller.rebaseAbort,
              child: const Text('Abort', style: TextStyle(color: AppTheme.proDanger)),
            ),
          ] else if (controller.isMerging) ...[
            TextButton(
              onPressed: controller.busy ? null : controller.mergeAbort,
              child: const Text('Abort merge', style: TextStyle(color: AppTheme.proDanger)),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraphHeader extends StatelessWidget {
  const _GraphHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: AppTheme.proPanelAlt,
        border: Border(bottom: BorderSide(color: AppTheme.proBorderSoft)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Text(
            'COMMIT GRAPH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppTheme.proMuted,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Right-click for actions',
            style: TextStyle(fontSize: 11, color: AppTheme.proMuted),
          ),
          Spacer(),
          SizedBox(width: 110, child: Text('Author', style: TextStyle(fontSize: 11, color: AppTheme.proMuted))),
          SizedBox(width: 88, child: Text('Date', style: TextStyle(fontSize: 11, color: AppTheme.proMuted))),
          SizedBox(width: 72, child: Text('Hash', style: TextStyle(fontSize: 11, color: AppTheme.proMuted))),
          SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ProChrome extends StatelessWidget {
  const _ProChrome({
    required this.controller,
    required this.onToggleStaging,
    required this.showStaging,
  });

  final RepoController controller;
  final VoidCallback onToggleStaging;
  final bool showStaging;

  @override
  Widget build(BuildContext context) {
    final branch = controller.repo?.currentBranch ?? 'DETACHED';
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.proPanel,
        border: Border(bottom: BorderSide(color: AppTheme.proBorderSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.proAccent.withValues(alpha: 0.22),
                  AppTheme.proAccent2.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.proAccent.withValues(alpha: 0.35)),
            ),
            child: const Row(
              children: [
                Text('Git Yar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.proText)),
                SizedBox(width: 8),
                Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.proAccent, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ActionGroup(
            children: [
              _IconAction(icon: Icons.cloud_download_outlined, label: 'Fetch', onPressed: controller.busy ? null : controller.fetch),
              _IconAction(
                icon: Icons.download_rounded,
                label: 'Pull',
                onPressed: controller.busy ? null : () => controller.pull(),
                menu: {
                  'Pull (merge)': () => controller.pull(),
                  'Pull (rebase)': () => controller.pull(rebase: true),
                },
              ),
              _IconAction(
                icon: Icons.upload_rounded,
                label: 'Push',
                onPressed: controller.busy ? null : () => controller.push(),
                menu: {
                  'Push': () => controller.push(),
                  'Push -u': () => controller.push(setUpstream: true),
                  'Force-with-lease': () => confirmDestructive(
                        context,
                        title: 'Force push?',
                        body: 'Uses --force-with-lease. Remote commits may be overwritten.',
                        confirmLabel: 'Force push',
                        onConfirm: () => controller.push(forceWithLease: true),
                      ),
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          _ActionGroup(
            children: [
              _IconAction(
                icon: Icons.merge_type_rounded,
                label: 'Merge',
                onPressed: controller.busy ? null : () => showMergeDialog(context, controller),
              ),
              _IconAction(
                icon: Icons.linear_scale_rounded,
                label: 'Rebase',
                onPressed: controller.busy ? null : () => showRebaseDialog(context, controller),
              ),
              _IconAction(
                icon: Icons.playlist_add_check_rounded,
                label: 'Cherry',
                onPressed: controller.busy || controller.selectedCommit == null
                    ? null
                    : () => controller.cherryPick(controller.selectedCommit!.hash),
              ),
              _IconAction(
                icon: Icons.restart_alt_rounded,
                label: 'Reset',
                onPressed: controller.busy || controller.selectedCommit == null
                    ? null
                    : () => showResetDialog(context, controller, target: controller.selectedCommit!.hash),
              ),
            ],
          ),
          const SizedBox(width: 8),
          _ActionGroup(
            children: [
              _IconAction(icon: Icons.inventory_2_outlined, label: 'Stash', onPressed: controller.busy ? null : () => controller.stash()),
              _IconAction(icon: Icons.unarchive_outlined, label: 'Pop', onPressed: controller.busy ? null : controller.stashPop),
              _IconAction(icon: Icons.refresh_rounded, label: 'Refresh', onPressed: controller.busy ? null : controller.refresh),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.proBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.proBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_tree_rounded, size: 14, color: AppTheme.proAccent),
                const SizedBox(width: 8),
                Text(
                  branch,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.proText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Professional reports',
            onPressed: () => showReportsPopup(context, controller),
            icon: const Icon(Icons.analytics_outlined, color: AppTheme.proAccent),
          ),
          IconButton(
            tooltip: 'Code workspace fullscreen',
            onPressed: () => showCodeWorkspacePopup(context, controller),
            icon: const Icon(Icons.open_in_full_rounded, color: AppTheme.proAccent),
          ),
          IconButton(
            tooltip: showStaging ? 'Hide staging' : 'Show staging',
            onPressed: onToggleStaging,
            icon: Icon(showStaging ? Icons.vertical_split : Icons.vertical_split_outlined, color: AppTheme.proMuted),
          ),
          IconButton(
            tooltip: 'Close repository',
            onPressed: controller.closeRepo,
            icon: const Icon(Icons.logout_rounded, color: AppTheme.proMuted),
          ),
        ],
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.proBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.proBorderSoft),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.menu,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Map<String, VoidCallback>? menu;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.proText,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        minimumSize: const Size(0, 36),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (menu != null) ...[
            const SizedBox(width: 2),
          ],
        ],
      ),
    );

    if (menu == null) return button;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        PopupMenuButton<String>(
          tooltip: '$label options',
          enabled: onPressed != null,
          onSelected: (key) => menu![key]?.call(),
          itemBuilder: (context) => [
            for (final entry in menu!.entries) PopupMenuItem(value: entry.key, child: Text(entry.key)),
          ],
          child: const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.proMuted),
          ),
        ),
      ],
    );
  }
}

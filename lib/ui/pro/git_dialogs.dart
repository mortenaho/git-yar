import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/git_models.dart';
import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';

Future<void> showMergeDialog(BuildContext context, RepoController controller) async {
  final branches = [
    ...controller.localBranches.map((b) => b.name),
    ...controller.remoteBranches.map((b) => b.name),
  ].where((n) => n != controller.repo?.currentBranch).toList();

  if (branches.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No branches to merge')));
    return;
  }

  var selected = branches.first;
  var mode = 'default'; // default | no-ff | ff-only

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Merge'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Into ${controller.repo?.currentBranch ?? "HEAD"}',
                    style: const TextStyle(color: AppTheme.proMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    dropdownColor: AppTheme.proElevated,
                    decoration: const InputDecoration(labelText: 'Source branch'),
                    items: [
                      for (final b in branches)
                        DropdownMenuItem(
                          value: b,
                          child: Text(b, textDirection: TextDirection.ltr),
                        ),
                    ],
                    onChanged: (v) => setState(() => selected = v ?? selected),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Default'),
                        selected: mode == 'default',
                        onSelected: (_) => setState(() => mode = 'default'),
                      ),
                      ChoiceChip(
                        label: const Text('--no-ff'),
                        selected: mode == 'no-ff',
                        onSelected: (_) => setState(() => mode = 'no-ff'),
                      ),
                      ChoiceChip(
                        label: const Text('--ff-only'),
                        selected: mode == 'ff-only',
                        onSelected: (_) => setState(() => mode = 'ff-only'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Merge')),
            ],
          );
        },
      );
    },
  );

  if (ok == true) {
    await controller.merge(
      selected,
      noFf: mode == 'no-ff',
      ffOnly: mode == 'ff-only',
    );
  }
}

Future<void> showRebaseDialog(BuildContext context, RepoController controller) async {
  final branches = [
    ...controller.localBranches.map((b) => b.name),
    ...controller.remoteBranches.map((b) => b.name),
  ].where((n) => n != controller.repo?.currentBranch).toList();

  if (branches.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No branches to rebase onto')));
    return;
  }

  var selected = branches.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rebase'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rebase ${controller.repo?.currentBranch ?? "HEAD"} onto…',
                    style: const TextStyle(color: AppTheme.proMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    dropdownColor: AppTheme.proElevated,
                    decoration: const InputDecoration(labelText: 'Onto'),
                    items: [
                      for (final b in branches)
                        DropdownMenuItem(
                          value: b,
                          child: Text(b, textDirection: TextDirection.ltr),
                        ),
                    ],
                    onChanged: (v) => setState(() => selected = v ?? selected),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rebase')),
            ],
          );
        },
      );
    },
  );

  if (ok == true) await controller.rebase(selected);
}

Future<void> showResetDialog(
  BuildContext context,
  RepoController controller, {
  required String target,
}) async {
  var mode = 'mixed';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Reset'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Target: $target', textDirection: TextDirection.ltr, style: const TextStyle(color: AppTheme.proMuted)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Soft'),
                        selected: mode == 'soft',
                        onSelected: (_) => setState(() => mode = 'soft'),
                      ),
                      ChoiceChip(
                        label: const Text('Mixed'),
                        selected: mode == 'mixed',
                        onSelected: (_) => setState(() => mode = 'mixed'),
                      ),
                      ChoiceChip(
                        label: const Text('Hard'),
                        selected: mode == 'hard',
                        onSelected: (_) => setState(() => mode = 'hard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    switch (mode) {
                      'soft' => 'Keeps index and worktree.',
                      'hard' => 'Discards all local changes.',
                      _ => 'Keeps worktree, resets index.',
                    },
                    style: TextStyle(
                      color: mode == 'hard' ? AppTheme.proDanger : AppTheme.proMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                style: mode == 'hard'
                    ? FilledButton.styleFrom(backgroundColor: AppTheme.proDanger)
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          );
        },
      );
    },
  );

  if (ok == true) await controller.resetTo(target, mode: mode);
}

Future<void> showTagDialog(
  BuildContext context,
  RepoController controller, {
  String? commit,
}) async {
  final nameCtrl = TextEditingController();
  final msgCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create tag'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'Tag name', hintText: 'v1.0.0'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'Message (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
      ],
    ),
  );
  if (ok == true && nameCtrl.text.trim().isNotEmpty) {
    await controller.createTag(
      nameCtrl.text.trim(),
      message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
      commit: commit,
    );
  }
}

Future<void> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required Future<void> Function() onConfirm,
  String confirmLabel = 'Continue',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.proDanger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (ok == true) await onConfirm();
}

void showCommitContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required RepoController controller,
  required GitCommit commit,
}) {
  final box = Overlay.of(context).context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(globalPosition, globalPosition),
    Offset.zero & box.size,
  );

  showMenu<String>(
    context: context,
    position: position,
    items: [
      PopupMenuItem(value: 'checkout', child: Text('Checkout ${commit.shortHash}')),
      const PopupMenuItem(value: 'cherry', child: Text('Cherry-pick')),
      const PopupMenuItem(value: 'branch', child: Text('Create branch here…')),
      const PopupMenuItem(value: 'tag', child: Text('Create tag…')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'reset', child: Text('Reset to here…')),
      const PopupMenuItem(
        value: 'copy',
        child: Text('Copy hash'),
      ),
    ],
  ).then((value) async {
    if (value == null) return;
    switch (value) {
      case 'checkout':
        await controller.checkout(commit.hash);
      case 'cherry':
        await controller.cherryPick(commit.hash);
      case 'branch':
        final name = await _askText(context, title: 'Branch name', hint: 'feature/from-commit');
        if (name != null && name.isNotEmpty) {
          await controller.createBranchAt(name, commit.hash);
        }
      case 'tag':
        await showTagDialog(context, controller, commit: commit.hash);
      case 'reset':
        await showResetDialog(context, controller, target: commit.hash);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: commit.hash));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hash copied')),
          );
        }
    }
  });
}

Future<String?> _askText(BuildContext context, {required String title, String? hint}) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

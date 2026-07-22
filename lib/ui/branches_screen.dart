import 'package:flutter/material.dart';

import '../../models/git_models.dart';
import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';
import 'widgets/common.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key, required this.controller});

  final RepoController controller;

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  String _query = '';
  bool _showRemote = true;

  Future<void> _createBranch() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('برنچ جدید'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'نام برنچ',
              hintText: 'feature/login',
            ),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
            FilledButton(
              onPressed: () => Navigator.pop(context, nameController.text.trim()),
              child: const Text('ساخت و سوییچ'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await widget.controller.createBranch(name);
  }

  Future<void> _confirmDelete(GitBranch branch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف برنچ'),
        content: Text('برنچ «${branch.name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.deleteBranch(branch.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final filtered = c.branches.where((b) {
      if (!_showRemote && b.isRemote) return false;
      if (_query.isEmpty) return true;
      return b.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final localCount = c.branches.where((b) => !b.isRemote).length;
    final remoteCount = c.branches.where((b) => b.isRemote).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'برنچ‌ها',
          subtitle: '$localCount محلی · $remoteCount ریموت',
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: c.busy ? null : c.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            FilledButton.tonalIcon(
              onPressed: c.busy ? null : _createBranch,
              icon: const Icon(Icons.add),
              label: const Text('برنچ جدید'),
            ),
          ],
        ),
        SoftPanel(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'جستجوی برنچ…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('ریموت'),
                selected: _showRemote,
                onSelected: (v) => setState(() => _showRemote = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyHint(icon: Icons.account_tree_outlined, message: 'برنچی پیدا نشد')
              : SoftPanel(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final branch = filtered[index];
                      return ListTile(
                        leading: Icon(
                          branch.isCurrent
                              ? Icons.check_circle
                              : branch.isRemote
                                  ? Icons.cloud_outlined
                                  : Icons.commit,
                          color: branch.isCurrent ? AppTheme.leaf : AppTheme.moss,
                        ),
                        title: Text(
                          branch.name,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontWeight: branch.isCurrent ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (branch.isCurrent) 'فعلی',
                            if (branch.isRemote) 'ریموت',
                            if (branch.upstream != null) '↑ ${branch.upstream}',
                            if (branch.ahead > 0) 'ahead ${branch.ahead}',
                            if (branch.behind > 0) 'behind ${branch.behind}',
                          ].join(' · '),
                          textDirection: TextDirection.ltr,
                        ),
                        trailing: branch.isRemote
                            ? TextButton(
                                onPressed: c.busy ? null : () => c.checkout(branch.name),
                                child: const Text('checkout'),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!branch.isCurrent)
                                    TextButton(
                                      onPressed: c.busy ? null : () => c.checkout(branch.name),
                                      child: const Text('سوییچ'),
                                    ),
                                  if (!branch.isCurrent)
                                    IconButton(
                                      tooltip: 'حذف',
                                      onPressed: c.busy ? null : () => _confirmDelete(branch),
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                                    ),
                                ],
                              ),
                        onTap: branch.isCurrent || c.busy ? null : () => c.checkout(branch.name),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

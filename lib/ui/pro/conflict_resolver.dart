import 'package:flutter/material.dart';

import '../../services/conflict_parser.dart';
import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';
import 'code_editor/code_editor_view.dart';
import 'code_editor/syntax_highlighter.dart';

class ConflictResolverPanel extends StatefulWidget {
  const ConflictResolverPanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final RepoController controller;
  final VoidCallback onClose;

  @override
  State<ConflictResolverPanel> createState() => _ConflictResolverPanelState();
}

class _ConflictResolverPanelState extends State<ConflictResolverPanel> {
  String? _selectedPath;
  ConflictDocument? _doc;
  String? _raw;
  bool _loading = false;
  bool _editMode = false;
  final _manualCtrl = TextEditingController();

  RepoController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final paths = c.conflicts.map((e) => e.path).toSet();
    if (_selectedPath != null && !paths.contains(_selectedPath)) {
      _selectedPath = null;
      _doc = null;
      _raw = null;
    }
    setState(() {});
    if (_selectedPath == null) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (c.conflicts.isEmpty) return;
    final path = _selectedPath ?? c.conflicts.first.path;
    await _load(path);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _selectedPath = path;
      _editMode = false;
    });
    try {
      final raw = await c.readConflictFile(path);
      final doc = ConflictDocument.parse(raw);
      _manualCtrl.text = raw;
      setState(() {
        _raw = raw;
        _doc = doc;
      });
    } catch (e) {
      setState(() {
        _raw = null;
        _doc = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setHunkChoice(int index, ConflictChoice choice) {
    final doc = _doc;
    if (doc == null) return;
    var hunkIndex = 0;
    final next = <ConflictSegment>[];
    for (final segment in doc.segments) {
      if (segment is ConflictHunk) {
        if (hunkIndex == index) {
          next.add(
            ConflictHunk(
              ours: segment.ours,
              theirs: segment.theirs,
              base: segment.base,
              choice: choice,
              manualText: segment.manualText,
            ),
          );
        } else {
          next.add(segment);
        }
        hunkIndex++;
      } else {
        next.add(segment);
      }
    }
    setState(() => _doc = ConflictDocument(segments: next));
  }

  Future<void> _applyHunkResolution() async {
    final path = _selectedPath;
    final doc = _doc;
    if (path == null || doc == null) return;
    if (!doc.allResolved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resolve all conflict hunks first')),
      );
      return;
    }
    await c.saveResolvedFile(path, doc.toFileContent());
  }

  Future<void> _saveManual() async {
    final path = _selectedPath;
    if (path == null) return;
    final text = _manualCtrl.text;
    if (text.contains('<<<<<<<') || text.contains('>>>>>>>')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove conflict markers before saving')),
      );
      return;
    }
    await c.saveResolvedFile(path, text);
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = c.conflicts;

    return Material(
      color: AppTheme.proPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            count: conflicts.length,
            onClose: widget.onClose,
            busy: c.busy,
            onContinue: c.isRebasing
                ? c.rebaseContinue
                : c.isMerging
                    ? () async {
                        // After merge conflicts resolved, user commits normally.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Conflicts cleared — commit the merge when ready')),
                        );
                      }
                    : null,
          ),
          const Divider(height: 1, color: AppTheme.proBorder),
          Expanded(
            child: conflicts.isEmpty
                ? const Center(
                    child: Text('No unresolved conflicts', style: TextStyle(color: AppTheme.proMuted)),
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 260,
                        child: ListView.builder(
                          itemCount: conflicts.length,
                          itemBuilder: (context, index) {
                            final file = conflicts[index];
                            final selected = file.path == _selectedPath;
                            return ListTile(
                              selected: selected,
                              selectedTileColor: AppTheme.proAccent.withValues(alpha: 0.12),
                              leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.proWarn, size: 18),
                              title: Text(
                                file.path,
                                textDirection: TextDirection.ltr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppTheme.proText),
                              ),
                              subtitle: Text(file.label, style: const TextStyle(fontSize: 11, color: AppTheme.proMuted)),
                              onTap: () => _load(file.path),
                            );
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1, color: AppTheme.proBorder),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator(color: AppTheme.proAccent))
                            : _selectedPath == null
                                ? const Center(child: Text('Select a conflicted file', style: TextStyle(color: AppTheme.proMuted)))
                                : Column(
                                    children: [
                                      _FileToolbar(
                                        path: _selectedPath!,
                                        editMode: _editMode,
                                        hunkCount: _doc?.conflictCount ?? 0,
                                        allResolved: _doc?.allResolved ?? false,
                                        busy: c.busy,
                                        onToggleEdit: () => setState(() {
                                          _editMode = !_editMode;
                                          if (_editMode && _doc != null) {
                                            _manualCtrl.text = _raw ?? _doc!.toFileContent();
                                          }
                                        }),
                                        onOurs: () => c.resolveConflictOurs(_selectedPath!),
                                        onTheirs: () => c.resolveConflictTheirs(_selectedPath!),
                                        onApplyHunks: _applyHunkResolution,
                                        onSaveManual: _saveManual,
                                        onMarkResolved: () => c.markConflictResolved(_selectedPath!),
                                      ),
                                      const Divider(height: 1, color: AppTheme.proBorder),
                                      Expanded(
                                        child: _editMode
                                            ? CodeEditorView(
                                                key: ValueKey('conflict-$_selectedPath'),
                                                text: _manualCtrl.text,
                                                language: SyntaxHighlighter.detectLanguage(_selectedPath),
                                                readOnly: false,
                                                onChanged: (v) => _manualCtrl.text = v,
                                              )
                                            : _HunkList(
                                                doc: _doc,
                                                onChoice: _setHunkChoice,
                                              ),
                                      ),
                                    ],
                                  ),
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
    required this.count,
    required this.onClose,
    required this.busy,
    required this.onContinue,
  });

  final int count;
  final VoidCallback onClose;
  final bool busy;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppTheme.proWarn.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.merge_type_rounded, color: AppTheme.proWarn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count > 0
                  ? 'Conflict Resolver · $count file${count == 1 ? '' : 's'}'
                  : 'Conflict Resolver · all clear',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.proText),
            ),
          ),
          if (onContinue != null) ...[
            FilledButton.tonal(
              onPressed: busy || count > 0 ? null : onContinue,
              child: const Text('Continue rebase'),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: AppTheme.proMuted)),
        ],
      ),
    );
  }
}

class _FileToolbar extends StatelessWidget {
  const _FileToolbar({
    required this.path,
    required this.editMode,
    required this.hunkCount,
    required this.allResolved,
    required this.busy,
    required this.onToggleEdit,
    required this.onOurs,
    required this.onTheirs,
    required this.onApplyHunks,
    required this.onSaveManual,
    required this.onMarkResolved,
  });

  final String path;
  final bool editMode;
  final int hunkCount;
  final bool allResolved;
  final bool busy;
  final VoidCallback onToggleEdit;
  final VoidCallback onOurs;
  final VoidCallback onTheirs;
  final VoidCallback onApplyHunks;
  final VoidCallback onSaveManual;
  final VoidCallback onMarkResolved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            path,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppTheme.proAccent2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: busy ? null : onOurs,
                child: const Text('Accept Current (ours)'),
              ),
              FilledButton.tonal(
                onPressed: busy ? null : onTheirs,
                child: const Text('Accept Incoming (theirs)'),
              ),
              OutlinedButton(
                onPressed: busy ? null : onToggleEdit,
                child: Text(editMode ? 'Hunk view' : 'Manual edit'),
              ),
              if (editMode)
                FilledButton(
                  onPressed: busy ? null : onSaveManual,
                  child: const Text('Save & Mark Resolved'),
                )
              else
                FilledButton(
                  onPressed: busy
                      ? null
                      : hunkCount == 0
                          ? onMarkResolved
                          : (allResolved ? onApplyHunks : null),
                  child: Text(hunkCount == 0 ? 'Mark Resolved' : 'Apply hunks & Resolve'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HunkList extends StatelessWidget {
  const _HunkList({
    required this.doc,
    required this.onChoice,
  });

  final ConflictDocument? doc;
  final void Function(int index, ConflictChoice choice) onChoice;

  @override
  Widget build(BuildContext context) {
    if (doc == null) {
      return const Center(child: Text('Could not load file', style: TextStyle(color: AppTheme.proMuted)));
    }
    if (!doc!.hasConflicts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No conflict markers in this file.\nUse Accept ours/theirs or Mark as resolved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.proMuted),
          ),
        ),
      );
    }

    final hunks = doc!.segments.whereType<ConflictHunk>().toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: hunks.length,
      itemBuilder: (context, index) {
        final hunk = hunks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.proBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hunk.isResolved ? AppTheme.proAccent.withValues(alpha: 0.5) : AppTheme.proWarn.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Text(
                      'Conflict ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.proText),
                    ),
                    const Spacer(),
                    Text(
                      hunk.isResolved ? 'Resolved' : 'Unresolved',
                      style: TextStyle(
                        color: hunk.isResolved ? AppTheme.proAccent : AppTheme.proWarn,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Ours'),
                      selected: hunk.choice == ConflictChoice.ours,
                      onSelected: (_) => onChoice(index, ConflictChoice.ours),
                    ),
                    ChoiceChip(
                      label: const Text('Theirs'),
                      selected: hunk.choice == ConflictChoice.theirs,
                      onSelected: (_) => onChoice(index, ConflictChoice.theirs),
                    ),
                    ChoiceChip(
                      label: const Text('Both'),
                      selected: hunk.choice == ConflictChoice.both,
                      onSelected: (_) => onChoice(index, ConflictChoice.both),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Side(title: 'Current (ours)', color: AppTheme.proAccent2, body: hunk.ours),
              _Side(title: 'Incoming (theirs)', color: AppTheme.proPurple, body: hunk.theirs),
              if (hunk.base != null) _Side(title: 'Base', color: AppTheme.proMuted, body: hunk.base!),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.title, required this.color, required this.body});

  final String title;
  final Color color;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 6),
          SelectableText(
            body.isEmpty ? '(empty)' : body,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
              color: body.isEmpty ? AppTheme.proMuted : AppTheme.proText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen dialog entry point.
Future<void> showConflictResolver(BuildContext context, RepoController controller) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Conflict Resolver',
    barrierColor: Colors.black54,
    pageBuilder: (context, anim, secondary) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConflictResolverPanel(
                  controller: controller,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

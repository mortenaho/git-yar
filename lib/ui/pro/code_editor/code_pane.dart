import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../state/repo_controller.dart';
import '../../../theme/app_theme.dart';
import 'code_editor_view.dart';
import 'diff_code_view.dart';
import 'syntax_highlighter.dart';

enum CodePaneTab { diff, editor }

/// Opens the code workspace in a near-fullscreen popup.
Future<void> showCodeWorkspacePopup(
  BuildContext context,
  RepoController controller, {
  CodePaneTab initialTab = CodePaneTab.diff,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close code workspace',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim, secondary) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600, maxHeight: 1000),
              child: Material(
                color: Colors.transparent,
                elevation: 24,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.proBorder),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: CodePane(
                    controller: controller,
                    fullscreen: true,
                    initialTab: initialTab,
                    onCloseFullscreen: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Diff / Editor pane with a file list for commits and working-tree changes.
class CodePane extends StatefulWidget {
  const CodePane({
    super.key,
    required this.controller,
    this.compactTitle,
    this.fullscreen = false,
    this.initialTab = CodePaneTab.diff,
    this.onCloseFullscreen,
  });

  final RepoController controller;
  final String? compactTitle;
  final bool fullscreen;
  final CodePaneTab initialTab;
  final VoidCallback? onCloseFullscreen;

  @override
  State<CodePane> createState() => _CodePaneState();
}

class _CodePaneState extends State<CodePane> {
  late CodePaneTab _tab;
  String? _draft;
  bool _dirty = false;
  String _filter = '';

  RepoController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    c.addListener(_onCtrl);
  }

  @override
  void dispose() {
    c.removeListener(_onCtrl);
    super.dispose();
  }

  void _onCtrl() {
    if (!mounted) return;
    final path = c.editorPath;
    if (!_dirty) {
      _draft = c.editorText;
    } else if (path != null && path != c.editorPath) {
      _dirty = false;
      _draft = c.editorText;
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (c.editorReadOnly) return;
    final path = c.selectedFile?.path ?? c.editorPath;
    if (path == null || _draft == null) return;
    await c.saveEditorFile(path, _draft!);
    setState(() => _dirty = false);
  }

  List<_FileEntry> get _entries {
    final q = _filter.trim().toLowerCase();
    final items = <_FileEntry>[];

    if (c.selectedCommit != null && c.commitFiles.isNotEmpty) {
      for (final f in c.commitFiles) {
        if (q.isNotEmpty && !f.path.toLowerCase().contains(q)) continue;
        items.add(
          _FileEntry(
            path: f.path,
            status: f.status,
            subtitle: f.label,
            selected: c.selectedCommitFile?.path == f.path,
            onTap: () async {
              setState(() {
                _tab = CodePaneTab.diff;
                _dirty = false;
              });
              await c.selectCommitFile(f);
              _draft = c.editorText;
            },
          ),
        );
      }
      return items;
    }

    // Working tree changes
    for (final f in [...c.unstaged, ...c.staged]) {
      if (q.isNotEmpty && !f.path.toLowerCase().contains(q)) continue;
      final selected = c.selectedFile?.path == f.path && c.selectedFile?.staged == f.staged;
      items.add(
        _FileEntry(
          path: f.path,
          status: f.statusCode,
          subtitle: '${f.label}${f.staged ? ' · staged' : ''}',
          selected: selected,
          onTap: () async {
            setState(() {
              _tab = CodePaneTab.diff;
              _dirty = false;
            });
            await c.selectFile(f);
            _draft = c.editorText;
          },
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final path = c.selectedCommitFile?.path ?? c.selectedFile?.path ?? c.editorPath;
    final language = SyntaxHighlighter.detectLanguage(path);
    final title = path ??
        (c.selectedCommit != null ? 'Commit · ${c.selectedCommit!.shortHash}' : 'No file selected');

    final canEdit = path != null && c.editorText != null;
    final canSave = canEdit && !c.editorReadOnly && _dirty && !c.busy;
    final entries = _entries;
    final listTitle = c.selectedCommit != null ? 'Commit files' : 'Changed files';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (canSave) _save();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (widget.fullscreen) widget.onCloseFullscreen?.call();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true): () {
          if (!widget.fullscreen) {
            showCodeWorkspacePopup(context, c, initialTab: _tab);
          }
        },
      },
      child: Focus(
        autofocus: widget.fullscreen,
        child: ColoredBox(
          color: SyntaxTheme.proDark.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Chrome(
                title: title,
                language: language,
                tab: _tab,
                dirty: _dirty,
                canEdit: canEdit,
                readOnly: c.editorReadOnly,
                loading: c.loadingDiff || c.loadingEditor,
                fullscreen: widget.fullscreen,
                onExpand: widget.fullscreen
                    ? null
                    : () => showCodeWorkspacePopup(context, c, initialTab: _tab),
                onClose: widget.onCloseFullscreen,
                onTab: (t) async {
                  setState(() => _tab = t);
                  if (t == CodePaneTab.editor &&
                      c.selectedFile != null &&
                      !c.editorReadOnly &&
                      c.editorText == null) {
                    await c.loadEditorFile(c.selectedFile!.path);
                    _draft = c.editorText;
                    setState(() {});
                  }
                },
                onSave: canSave ? _save : null,
                onReload: c.selectedFile == null || c.busy || c.editorReadOnly
                    ? null
                    : () async {
                        await c.loadEditorFile(c.selectedFile!.path);
                        _draft = c.editorText;
                        _dirty = false;
                        setState(() {});
                      },
              ),
              if (c.loadingDiff || c.loadingEditor)
                const LinearProgressIndicator(minHeight: 2, color: AppTheme.proAccent),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: widget.fullscreen ? 280 : 220,
                      child: _FileListPanel(
                        title: listTitle,
                        count: entries.length,
                        filter: _filter,
                        onFilter: (v) => setState(() => _filter = v),
                        entries: entries,
                      ),
                    ),
                    Container(width: 1, color: AppTheme.proBorderSoft),
                    Expanded(child: _buildBody(language, canEdit)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CodeLanguage language, bool canEdit) {
    if (_tab == CodePaneTab.editor && canEdit) {
      final text = _draft ?? c.editorText ?? '';
      return CodeEditorView(
        key: ValueKey('editor-${c.editorPath}-${c.editorReadOnly}-$language'),
        text: text,
        language: language,
        readOnly: c.editorReadOnly,
        fileName: c.editorPath,
        onChanged: c.editorReadOnly
            ? null
            : (v) {
                _draft = v;
                final dirty = v != (c.editorText ?? '');
                if (dirty != _dirty) setState(() => _dirty = dirty);
              },
      );
    }

    final diff = c.diffText;
    if (diff == null || diff.isEmpty) {
      return const Center(
        child: Text(
          'Select a file to view changes',
          style: TextStyle(color: AppTheme.proMuted),
        ),
      );
    }

    return DiffCodeView(
      key: ValueKey('diff-${pathKey()}-${c.selectedCommit?.hash}'),
      diffText: diff,
      language: language,
    );
  }

  String pathKey() =>
      c.selectedCommitFile?.path ?? c.selectedFile?.path ?? c.editorPath ?? 'none';
}

class _FileEntry {
  const _FileEntry({
    required this.path,
    required this.status,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String path;
  final String status;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
}

class _FileListPanel extends StatelessWidget {
  const _FileListPanel({
    required this.title,
    required this.count,
    required this.filter,
    required this.onFilter,
    required this.entries,
  });

  final String title;
  final int count;
  final String filter;
  final ValueChanged<String> onFilter;
  final List<_FileEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.proPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Text(
              '$title ($count)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppTheme.proMuted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              onChanged: onFilter,
              style: const TextStyle(fontSize: 12, color: AppTheme.proText),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Filter files…',
                prefixIcon: Icon(Icons.search, size: 16),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.proBorderSoft),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No files',
                        style: TextStyle(color: AppTheme.proMuted, fontSize: 12),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      return Material(
                        color: e.selected ? AppTheme.proAccent.withValues(alpha: 0.12) : Colors.transparent,
                        child: InkWell(
                          onTap: e.onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 16,
                                  child: Text(
                                    e.status,
                                    style: TextStyle(
                                      fontFamily: 'SourceCodePro',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _statusColor(e.status),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.path,
                                        textDirection: TextDirection.ltr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: e.selected ? FontWeight.w700 : FontWeight.w500,
                                          color: AppTheme.proText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e.subtitle,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.proMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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
      case 'R':
      case 'C':
        return AppTheme.proAccent2;
      default:
        return AppTheme.proMuted;
    }
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.title,
    required this.language,
    required this.tab,
    required this.dirty,
    required this.canEdit,
    required this.readOnly,
    required this.loading,
    required this.fullscreen,
    required this.onTab,
    required this.onSave,
    required this.onReload,
    this.onExpand,
    this.onClose,
  });

  final String title;
  final CodeLanguage language;
  final CodePaneTab tab;
  final bool dirty;
  final bool canEdit;
  final bool readOnly;
  final bool loading;
  final bool fullscreen;
  final ValueChanged<CodePaneTab> onTab;
  final VoidCallback? onSave;
  final VoidCallback? onReload;
  final VoidCallback? onExpand;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: fullscreen ? 48 : 42,
      decoration: BoxDecoration(
        color: AppTheme.proPanelAlt,
        border: const Border(bottom: BorderSide(color: AppTheme.proBorderSoft)),
        gradient: fullscreen
            ? LinearGradient(
                colors: [
                  AppTheme.proAccent.withValues(alpha: 0.08),
                  AppTheme.proPanelAlt,
                ],
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (fullscreen) ...[
            const Icon(Icons.code_rounded, size: 16, color: AppTheme.proAccent),
            const SizedBox(width: 8),
            const Text(
              'Code Workspace',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.proText),
            ),
            const SizedBox(width: 12),
          ],
          _TabChip(
            label: 'Diff',
            icon: Icons.difference_outlined,
            selected: tab == CodePaneTab.diff,
            onTap: () => onTab(CodePaneTab.diff),
          ),
          const SizedBox(width: 4),
          _TabChip(
            label: dirty ? 'Editor •' : (readOnly ? 'Editor (read-only)' : 'Editor'),
            icon: Icons.code_rounded,
            selected: tab == CodePaneTab.editor,
            enabled: canEdit,
            onTap: canEdit ? () => onTab(CodePaneTab.editor) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              textDirection: TextDirection.ltr,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'SourceCodePro',
                fontSize: 12,
                color: AppTheme.proMuted,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.proBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.proBorder),
            ),
            child: Text(
              SyntaxHighlighter.languageLabel(language),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.proAccent2),
            ),
          ),
          if (onReload != null)
            IconButton(
              tooltip: 'Reload file',
              onPressed: loading ? null : onReload,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.proMuted),
            ),
          if (onSave != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Save', style: TextStyle(fontSize: 12)),
              ),
            ),
          if (onExpand != null)
            IconButton(
              tooltip: 'Open fullscreen (Ctrl+Shift+F)',
              onPressed: onExpand,
              icon: const Icon(Icons.open_in_full_rounded, size: 18, color: AppTheme.proAccent),
            ),
          if (onClose != null)
            IconButton(
              tooltip: 'Close (Esc)',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.proMuted),
            ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    return Material(
      color: active ? AppTheme.proBg : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? AppTheme.proAccent : AppTheme.proMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? AppTheme.proText : AppTheme.proMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

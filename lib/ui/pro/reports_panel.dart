import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/report_models.dart';
import '../../services/git_service.dart';
import '../../services/report_service.dart';
import '../../state/repo_controller.dart';
import '../../theme/app_theme.dart';

Future<void> showReportsPopup(BuildContext context, RepoController controller) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close reports',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim, secondary) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 860),
              child: Material(
                color: AppTheme.proPanel,
                elevation: 24,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ReportsPanel(controller: controller),
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

class ReportsPanel extends StatefulWidget {
  const ReportsPanel({super.key, required this.controller});

  final RepoController controller;

  @override
  State<ReportsPanel> createState() => _ReportsPanelState();
}

class _ReportsPanelState extends State<ReportsPanel> {
  RepoReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = widget.controller;
    final repo = c.repo;
    if (repo == null) {
      setState(() {
        _loading = false;
        _error = 'No repository open';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ReportService(GitService(repoPath: repo.path));
      final report = await service.build(
        repo: repo,
        branches: c.branches,
        changes: c.changes,
        conflicts: c.conflicts,
        stashes: c.stashes,
        commits: c.commits,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _copyMarkdown() async {
    final report = _report;
    if (report == null) return;
    await Clipboard.setData(ClipboardData(text: report.toMarkdown()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied as Markdown')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.proAccent.withValues(alpha: 0.12),
                AppTheme.proPanelAlt,
              ],
            ),
            border: const Border(bottom: BorderSide(color: AppTheme.proBorderSoft)),
          ),
          child: Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.proAccent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Professional Reports',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.proText),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.proMuted),
              ),
              IconButton(
                tooltip: 'Copy Markdown',
                onPressed: _report == null ? null : _copyMarkdown,
                icon: const Icon(Icons.copy_all_rounded, color: AppTheme.proMuted),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: AppTheme.proMuted),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2, color: AppTheme.proAccent),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.proAccent))
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.proDanger)))
                  : _ReportBody(report: _report!),
        ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final RepoReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(report: report),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(label: 'Commits', value: '${report.totalCommitsApprox}', icon: Icons.commit),
            _MetricCard(label: 'Local branches', value: '${report.localBranches}', icon: Icons.account_tree),
            _MetricCard(label: 'Remote branches', value: '${report.remoteBranches}', icon: Icons.cloud_outlined),
            _MetricCard(label: 'Changed files', value: '${report.changedFiles}', icon: Icons.difference_outlined),
            _MetricCard(label: 'Conflicts', value: '${report.conflictFiles}', icon: Icons.warning_amber_rounded, warn: report.conflictFiles > 0),
            _MetricCard(label: 'Stashes', value: '${report.stashCount}', icon: Icons.inventory_2_outlined),
            if (report.ahead > 0 || report.behind > 0)
              _MetricCard(
                label: 'Ahead / Behind',
                value: '${report.ahead} / ${report.behind}',
                icon: Icons.swap_vert_rounded,
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Activity · last 30 days'),
        const SizedBox(height: 8),
        _ActivityChart(activity: report.activity, maxValue: report.maxDailyCommits),
        const SizedBox(height: 6),
        Text(
          '${report.activityTotal} commits in the selected window',
          style: const TextStyle(color: AppTheme.proMuted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ListCard(
                title: 'Top contributors',
                children: [
                  for (final c in report.contributors.take(10))
                    _BarRow(
                      label: c.name,
                      valueLabel: '${c.commits}',
                      ratio: report.contributors.isEmpty
                          ? 0
                          : c.commits / report.contributors.first.commits.clamp(1, 999999),
                      color: AppTheme.proAccent,
                    ),
                  if (report.contributors.isEmpty)
                    const Text('No contributor data', style: TextStyle(color: AppTheme.proMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ListCard(
                title: 'Hot files',
                children: [
                  for (final f in report.hotFiles.take(10))
                    _BarRow(
                      label: f.path,
                      valueLabel: '${f.changes}',
                      ratio: report.hotFiles.isEmpty
                          ? 0
                          : f.changes / report.hotFiles.first.changes.clamp(1, 999999),
                      color: AppTheme.proAccent2,
                      mono: true,
                    ),
                  if (report.hotFiles.isEmpty)
                    const Text('No file churn data', style: TextStyle(color: AppTheme.proMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ListCard(
                title: 'Languages / extensions',
                children: [
                  for (final e in report.extensions)
                    _BarRow(
                      label: e.extension,
                      valueLabel: '${e.files}',
                      ratio: report.extensions.isEmpty
                          ? 0
                          : e.files / report.extensions.first.files.clamp(1, 999999),
                      color: AppTheme.proWarn,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ListCard(
                title: 'Recent commits',
                children: [
                  for (final s in report.recentSubjects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        s,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'SourceCodePro',
                          fontSize: 12,
                          color: AppTheme.proText,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.report});

  final RepoReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.proBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.proElevated,
            AppTheme.proBg,
            AppTheme.proAccent.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.repoName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.proText),
          ),
          const SizedBox(height: 6),
          Text(
            report.repoPath,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'SourceCodePro', fontSize: 12, color: AppTheme.proMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(icon: Icons.account_tree, label: report.currentBranch ?? 'DETACHED'),
              if (report.remoteUrl != null) _Chip(icon: Icons.cloud_outlined, label: report.remoteUrl!),
              _Chip(
                icon: Icons.schedule,
                label: 'Generated ${report.generatedAt.toLocal()}'.split('.').first,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.proBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.proBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.proAccent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 12, color: AppTheme.proText),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.warn = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final accent = warn ? AppTheme.proWarn : AppTheme.proAccent;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.proBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.proBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: accent),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.proMuted)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: AppTheme.proMuted,
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.activity, required this.maxValue});

  final List<DayActivity> activity;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.proBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.proBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in activity)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Tooltip(
                  message: '${day.day}: ${day.commits}',
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: (day.commits / maxValue).clamp(0.04, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppTheme.proAccent.withValues(alpha: 0.35),
                              AppTheme.proAccent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.proBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.proBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.proText),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.valueLabel,
    required this.ratio,
    required this.color,
    this.mono = false,
  });

  final String label;
  final String valueLabel;
  final double ratio;
  final Color color;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.proText,
                    fontFamily: mono ? 'SourceCodePro' : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(valueLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 5,
              color: color,
              backgroundColor: AppTheme.proBorderSoft,
            ),
          ),
        ],
      ),
    );
  }
}

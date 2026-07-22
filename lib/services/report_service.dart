import '../models/git_models.dart';
import '../models/report_models.dart';
import 'git_service.dart';

class ReportService {
  ReportService(this._git);

  final GitService _git;

  Future<RepoReport> build({
    required GitRepoInfo repo,
    required List<GitBranch> branches,
    required List<GitFileChange> changes,
    required List<GitConflictFile> conflicts,
    required List<GitStash> stashes,
    required List<GitCommit> commits,
  }) async {
    final local = branches.where((b) => !b.isRemote).length;
    final remote = branches.where((b) => b.isRemote).length;
    final staged = changes.where((c) => c.staged).length;
    final unstaged = changes.where((c) => !c.staged).length;
    final current = branches.where((b) => b.isCurrent).toList();
    final ahead = current.isEmpty ? 0 : current.first.ahead;
    final behind = current.isEmpty ? 0 : current.first.behind;

    final contributors = await _contributors();
    final activity = await _activity(days: 30);
    final hotFiles = await _hotFiles(limit: 20);
    final extensions = _extensionsFrom(hotFiles, changes);
    final revCount = await _approxCommitCount();

    return RepoReport(
      generatedAt: DateTime.now(),
      repoName: repo.name,
      repoPath: repo.path,
      currentBranch: repo.currentBranch,
      remoteUrl: repo.remoteUrl,
      totalCommitsApprox: revCount > 0 ? revCount : commits.length,
      localBranches: local,
      remoteBranches: remote,
      changedFiles: changes.map((e) => e.path).toSet().length,
      stagedFiles: staged,
      unstagedFiles: unstaged,
      conflictFiles: conflicts.length,
      stashCount: stashes.length,
      contributors: contributors,
      activity: activity,
      hotFiles: hotFiles,
      extensions: extensions,
      recentSubjects: commits.take(15).map((c) => '${c.shortHash}  ${c.message}').toList(),
      ahead: ahead,
      behind: behind,
    );
  }

  Future<int> _approxCommitCount() async {
    final result = await _git.run(['rev-list', '--count', 'HEAD']);
    if (!result.ok) return 0;
    return int.tryParse(result.stdout.trim()) ?? 0;
  }

  Future<List<ContributorStat>> _contributors() async {
    final result = await _git.run(['shortlog', '-sn', '--all', '--no-merges']);
    if (!result.ok || result.stdout.trim().isEmpty) {
      // Fallback without --all
      final fallback = await _git.run(['shortlog', '-sn', 'HEAD']);
      return _parseShortlog(fallback.stdout);
    }
    return _parseShortlog(result.stdout);
  }

  List<ContributorStat> _parseShortlog(String stdout) {
    final list = <ContributorStat>[];
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(\d+)\s+(.*)$').firstMatch(trimmed);
      if (match == null) continue;
      list.add(
        ContributorStat(
          commits: int.parse(match.group(1)!),
          name: match.group(2)!.trim(),
        ),
      );
    }
    return list;
  }

  Future<List<DayActivity>> _activity({int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final sinceStr =
        '${since.year.toString().padLeft(4, '0')}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    final result = await _git.run([
      'log',
      '--since=$sinceStr',
      '--pretty=format:%ad',
      '--date=short',
      '--all',
    ]);
    final counts = <String, int>{};
    for (var i = 0; i < days; i++) {
      final d = DateTime.now().subtract(Duration(days: days - 1 - i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      counts[key] = 0;
    }
    if (result.ok) {
      for (final line in result.stdout.split('\n')) {
        final day = line.trim();
        if (day.isEmpty) continue;
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }
    final keys = counts.keys.toList()..sort();
    return [for (final k in keys) DayActivity(day: k, commits: counts[k] ?? 0)];
  }

  Future<List<FileChurn>> _hotFiles({int limit = 20}) async {
    final result = await _git.run([
      'log',
      '--pretty=format:',
      '--name-only',
      '--all',
      '-n',
      '300',
    ]);
    if (!result.ok) return [];
    final counts = <String, int>{};
    for (final line in result.stdout.split('\n')) {
      final path = line.trim();
      if (path.isEmpty) continue;
      counts[path] = (counts[path] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in entries.take(limit)) FileChurn(path: e.key, changes: e.value),
    ];
  }

  List<ExtensionStat> _extensionsFrom(List<FileChurn> hot, List<GitFileChange> changes) {
    final counts = <String, int>{};
    void add(String path) {
      final name = path.split('/').last;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '(none)';
      counts[ext] = (counts[ext] ?? 0) + 1;
    }

    for (final f in hot) {
      add(f.path);
    }
    for (final c in changes) {
      add(c.path);
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in entries.take(12)) ExtensionStat(extension: e.key, files: e.value),
    ];
  }
}

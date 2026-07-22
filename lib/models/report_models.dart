class ContributorStat {
  const ContributorStat({
    required this.name,
    required this.commits,
  });

  final String name;
  final int commits;
}

class DayActivity {
  const DayActivity({
    required this.day,
    required this.commits,
  });

  final String day; // YYYY-MM-DD
  final int commits;
}

class FileChurn {
  const FileChurn({
    required this.path,
    required this.changes,
  });

  final String path;
  final int changes;
}

class ExtensionStat {
  const ExtensionStat({
    required this.extension,
    required this.files,
  });

  final String extension;
  final int files;
}

class RepoReport {
  const RepoReport({
    required this.generatedAt,
    required this.repoName,
    required this.repoPath,
    required this.currentBranch,
    required this.remoteUrl,
    required this.totalCommitsApprox,
    required this.localBranches,
    required this.remoteBranches,
    required this.changedFiles,
    required this.stagedFiles,
    required this.unstagedFiles,
    required this.conflictFiles,
    required this.stashCount,
    required this.contributors,
    required this.activity,
    required this.hotFiles,
    required this.extensions,
    required this.recentSubjects,
    this.ahead = 0,
    this.behind = 0,
  });

  final DateTime generatedAt;
  final String repoName;
  final String repoPath;
  final String? currentBranch;
  final String? remoteUrl;
  final int totalCommitsApprox;
  final int localBranches;
  final int remoteBranches;
  final int changedFiles;
  final int stagedFiles;
  final int unstagedFiles;
  final int conflictFiles;
  final int stashCount;
  final List<ContributorStat> contributors;
  final List<DayActivity> activity;
  final List<FileChurn> hotFiles;
  final List<ExtensionStat> extensions;
  final List<String> recentSubjects;
  final int ahead;
  final int behind;

  int get activityTotal => activity.fold(0, (a, b) => a + b.commits);

  int get maxDailyCommits {
    if (activity.isEmpty) return 1;
    return activity.map((e) => e.commits).reduce((a, b) => a > b ? a : b).clamp(1, 999999);
  }

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# Git Yar Report');
    buf.writeln();
    buf.writeln('- **Repository:** `$repoName`');
    buf.writeln('- **Path:** `$repoPath`');
    buf.writeln('- **Branch:** `${currentBranch ?? "DETACHED"}`');
    if (remoteUrl != null) buf.writeln('- **Remote:** `$remoteUrl`');
    buf.writeln('- **Generated:** ${generatedAt.toIso8601String()}');
    buf.writeln();
    buf.writeln('## Snapshot');
    buf.writeln('| Metric | Value |');
    buf.writeln('| --- | ---: |');
    buf.writeln('| Commits (sampled) | $totalCommitsApprox |');
    buf.writeln('| Local branches | $localBranches |');
    buf.writeln('| Remote branches | $remoteBranches |');
    buf.writeln('| Changed files | $changedFiles |');
    buf.writeln('| Staged | $stagedFiles |');
    buf.writeln('| Unstaged | $unstagedFiles |');
    buf.writeln('| Conflicts | $conflictFiles |');
    buf.writeln('| Stashes | $stashCount |');
    if (ahead > 0 || behind > 0) {
      buf.writeln('| Ahead / Behind | $ahead / $behind |');
    }
    buf.writeln();
    buf.writeln('## Top contributors');
    for (final c in contributors.take(15)) {
      buf.writeln('- **${c.name}** — ${c.commits} commits');
    }
    buf.writeln();
    buf.writeln('## Hot files');
    for (final f in hotFiles.take(15)) {
      buf.writeln('- `${f.path}` — ${f.changes} touches');
    }
    buf.writeln();
    buf.writeln('## Recent commits');
    for (final s in recentSubjects.take(12)) {
      buf.writeln('- $s');
    }
    return buf.toString();
  }
}

class GitBranch {
  const GitBranch({
    required this.name,
    required this.isCurrent,
    required this.isRemote,
    this.upstream,
    this.ahead = 0,
    this.behind = 0,
  });

  final String name;
  final bool isCurrent;
  final bool isRemote;
  final String? upstream;
  final int ahead;
  final int behind;

  String get shortName {
    if (name.startsWith('remotes/')) {
      final parts = name.split('/');
      if (parts.length >= 3) {
        return parts.sublist(2).join('/');
      }
    }
    return name;
  }
}

class GitFileChange {
  const GitFileChange({
    required this.path,
    required this.statusCode,
    required this.staged,
    this.unmerged = false,
    this.xy,
  });

  final String path;
  final String statusCode;
  final bool staged;
  final bool unmerged;
  /// Porcelain XY pair when unmerged (e.g. UU, AU).
  final String? xy;

  String get label {
    if (unmerged) {
      return switch (xy) {
        'UU' => 'Both modified',
        'AA' => 'Both added',
        'DD' => 'Both deleted',
        'AU' => 'Added by us',
        'UA' => 'Added by them',
        'DU' => 'Deleted by us',
        'UD' => 'Deleted by them',
        _ => 'Conflict',
      };
    }
    switch (statusCode.trim()) {
      case 'M':
        return 'Modified';
      case 'A':
        return 'Added';
      case 'D':
        return 'Deleted';
      case 'R':
        return 'Renamed';
      case 'C':
        return 'Copied';
      case 'U':
        return 'Conflict';
      case '?':
        return 'Untracked';
      case '!':
        return 'Ignored';
      default:
        return statusCode;
    }
  }
}

class GitConflictFile {
  const GitConflictFile({
    required this.path,
    required this.xy,
  });

  final String path;
  final String xy;

  String get label => GitFileChange(path: path, statusCode: 'U', staged: false, unmerged: true, xy: xy).label;
}

class GitCommit {
  const GitCommit({
    required this.hash,
    required this.shortHash,
    required this.author,
    required this.date,
    required this.message,
    this.parents = const [],
    this.refs = const [],
  });

  final String hash;
  final String shortHash;
  final String author;
  final String date;
  final String message;
  final List<String> parents;
  final List<String> refs;

  bool get isMerge => parents.length > 1;
}

class GitStash {
  const GitStash({
    required this.ref,
    required this.message,
  });

  final String ref;
  final String message;
}

class GitCommitFile {
  const GitCommitFile({
    required this.path,
    required this.status,
    this.oldPath,
  });

  final String path;
  final String status; // M, A, D, R, C, …
  final String? oldPath;

  String get label {
    return switch (status) {
      'M' => 'Modified',
      'A' => 'Added',
      'D' => 'Deleted',
      'R' => 'Renamed',
      'C' => 'Copied',
      'T' => 'Type change',
      'U' => 'Unmerged',
      _ => status,
    };
  }
}

class GitRepoInfo {
  const GitRepoInfo({
    required this.path,
    required this.name,
    this.currentBranch,
    this.remoteUrl,
  });

  final String path;
  final String name;
  final String? currentBranch;
  final String? remoteUrl;
}

class GitCommandResult {
  const GitCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;

  String get output {
    final out = stdout.trim();
    final err = stderr.trim();
    if (out.isNotEmpty && err.isNotEmpty) return '$out\n$err';
    if (out.isNotEmpty) return out;
    return err;
  }
}

/// One rendered row in the commit graph.
class GraphNode {
  const GraphNode({
    required this.commit,
    required this.lane,
    required this.laneCount,
    required this.activeLanes,
    required this.connections,
  });

  final GitCommit commit;
  final int lane;
  final int laneCount;
  final List<int> activeLanes;
  final List<GraphConnection> connections;
}

class GraphConnection {
  const GraphConnection({
    required this.fromLane,
    required this.toLane,
    required this.isMerge,
  });

  final int fromLane;
  final int toLane;
  final bool isMerge;
}

import 'dart:io';

import '../models/git_models.dart';

class GitException implements Exception {
  GitException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GitService {
  GitService({String? repoPath}) : _repoPath = repoPath;

  String? _repoPath;

  String? get repoPath => _repoPath;

  set repoPath(String? value) => _repoPath = value;

  Future<bool> isGitRepo(String path) async {
    final result = await _run(['rev-parse', '--is-inside-work-tree'], cwd: path);
    return result.ok && result.stdout.trim() == 'true';
  }

  /// Suggest a folder name from a clone URL (`…/repo.git` → `repo`).
  static String suggestCloneFolderName(String url) {
    var s = url.trim();
    if (s.isEmpty) return 'repo';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.toLowerCase().endsWith('.git')) {
      s = s.substring(0, s.length - 4);
    }
    final slash = s.lastIndexOf('/');
    final colon = s.lastIndexOf(':');
    final cut = slash > colon ? slash : colon;
    final name = cut >= 0 && cut < s.length - 1 ? s.substring(cut + 1) : s;
    final cleaned = name.replaceAll(RegExp(r'[^\w.\-]+'), '-').replaceAll(RegExp(r'-+'), '-');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return 'repo';
    return cleaned;
  }

  /// Clone [url] into [destination] (full path). Parent folder must exist.
  Future<GitCommandResult> clone(String url, String destination) async {
    final uri = url.trim();
    final dest = destination.trim();
    if (uri.isEmpty) throw GitException('Repository URL is required.');
    if (dest.isEmpty) throw GitException('Destination path is required.');

    final destDir = Directory(dest);
    final parent = destDir.parent;
    if (!await parent.exists()) {
      throw GitException('Parent folder does not exist: ${parent.path}');
    }
    if (await destDir.exists()) {
      final empty = await destDir.list(followLinks: false).isEmpty;
      if (!empty) {
        throw GitException('Destination already exists and is not empty: $dest');
      }
    }

    try {
      final result = await Process.run(
        'git',
        ['clone', uri, dest],
        workingDirectory: parent.path,
        environment: {
          ...Platform.environment,
          'LANG': 'C',
          'GIT_TERMINAL_PROMPT': '0',
        },
      );
      return GitCommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (e) {
      throw GitException('Unable to run git: ${e.message}');
    }
  }

  Future<GitRepoInfo> loadRepoInfo() async {
    final path = _requirePath();
    final segments = path.split(RegExp(r'[/\\]')).where((e) => e.isNotEmpty);
    final name = segments.isEmpty ? path : segments.last;
    final branch = await currentBranch();
    final remote = await _run(['remote', 'get-url', 'origin']);
    return GitRepoInfo(
      path: path,
      name: name,
      currentBranch: branch,
      remoteUrl: remote.ok ? remote.stdout.trim() : null,
    );
  }

  Future<String?> currentBranch() async {
    final result = await _run(['branch', '--show-current']);
    if (!result.ok) return null;
    final name = result.stdout.trim();
    return name.isEmpty ? null : name;
  }

  Future<List<GitBranch>> listBranches() async {
    final local = await _run(['branch', '-vv', '--no-color']);
    final remote = await _run(['branch', '-r', '--no-color']);
    if (!local.ok) {
      throw GitException(local.output.isEmpty ? 'خواندن برنچ‌ها ناموفق بود' : local.output);
    }

    final branches = <GitBranch>[];

    for (final line in local.stdout.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) continue;
      final isCurrent = trimmed.trimLeft().startsWith('*');
      final body = trimmed.replaceFirst(RegExp(r'^\*?\s+'), '');
      final nameMatch = RegExp(r'^(\S+)').firstMatch(body);
      if (nameMatch == null) continue;
      final name = nameMatch.group(1)!;
      if (name.contains('HEAD')) continue;

      String? upstream;
      var ahead = 0;
      var behind = 0;
      final tracking = RegExp(r'\[([^\]]+)\]').firstMatch(body);
      if (tracking != null) {
        final trackBody = tracking.group(1)!;
        final pieces = trackBody.split(':');
        upstream = pieces.first.trim();
        if (pieces.length > 1) {
          final meta = pieces.sublist(1).join(':');
          ahead = int.tryParse(RegExp(r'ahead (\d+)').firstMatch(meta)?.group(1) ?? '') ?? 0;
          behind = int.tryParse(RegExp(r'behind (\d+)').firstMatch(meta)?.group(1) ?? '') ?? 0;
        }
      }

      branches.add(
        GitBranch(
          name: name,
          isCurrent: isCurrent,
          isRemote: false,
          upstream: upstream,
          ahead: ahead,
          behind: behind,
        ),
      );
    }

    if (remote.ok) {
      for (final line in remote.stdout.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.contains('->')) continue;
        branches.add(
          GitBranch(
            name: trimmed,
            isCurrent: false,
            isRemote: true,
          ),
        );
      }
    }

    branches.sort((a, b) {
      if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
      if (a.isRemote != b.isRemote) return a.isRemote ? 1 : -1;
      return a.name.compareTo(b.name);
    });
    return branches;
  }

  Future<List<GitFileChange>> status() async {
    final result = await _run(['status', '--porcelain']);
    if (!result.ok) {
      throw GitException(result.output.isEmpty ? 'خواندن وضعیت ناموفق بود' : result.output);
    }

    const unmerged = {'DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU'};
    final changes = <GitFileChange>[];
    for (final line in result.stdout.split('\n')) {
      if (line.length < 4) continue;
      final x = line[0];
      final y = line[1];
      final xy = '$x$y';
      var path = line.substring(3).trim();
      if (path.contains(' -> ')) {
        path = path.split(' -> ').last;
      }

      if (unmerged.contains(xy)) {
        changes.add(
          GitFileChange(
            path: path,
            statusCode: 'U',
            staged: false,
            unmerged: true,
            xy: xy,
          ),
        );
        continue;
      }

      if (x != ' ' && x != '?') {
        changes.add(GitFileChange(path: path, statusCode: x, staged: true));
      }
      if (y != ' ' && y != '!') {
        changes.add(
          GitFileChange(
            path: path,
            statusCode: y == '?' ? '?' : y,
            staged: false,
          ),
        );
      }
    }
    return changes;
  }

  Future<List<GitConflictFile>> listConflicts() async {
    final result = await _run(['status', '--porcelain']);
    if (!result.ok) return [];
    const unmerged = {'DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU'};
    final files = <GitConflictFile>[];
    final seen = <String>{};
    for (final line in result.stdout.split('\n')) {
      if (line.length < 4) continue;
      final xy = line.substring(0, 2);
      if (!unmerged.contains(xy)) continue;
      var path = line.substring(3).trim();
      if (path.contains(' -> ')) path = path.split(' -> ').last;
      if (seen.add(path)) {
        files.add(GitConflictFile(path: path, xy: xy));
      }
    }
    return files;
  }

  Future<String> readWorkingFile(String path) async {
    final file = File('${_requirePath()}${Platform.pathSeparator}$path');
    if (!await file.exists()) {
      throw GitException('File not found: $path');
    }
    return file.readAsString();
  }

  Future<void> writeWorkingFile(String path, String content) async {
    final file = File('${_requirePath()}${Platform.pathSeparator}$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<GitCommandResult> checkoutOurs(String path) => _run(['checkout', '--ours', '--', path]);

  Future<GitCommandResult> checkoutTheirs(String path) => _run(['checkout', '--theirs', '--', path]);

  Future<GitCommandResult> markResolved(String path) => _run(['add', '--', path]);

  Future<GitCommandResult> resolveWithOurs(String path) async {
    final checkout = await checkoutOurs(path);
    if (!checkout.ok) return checkout;
    return markResolved(path);
  }

  Future<GitCommandResult> resolveWithTheirs(String path) async {
    final checkout = await checkoutTheirs(path);
    if (!checkout.ok) return checkout;
    return markResolved(path);
  }

  Future<List<GitCommit>> recentCommits({int limit = 80}) async {
    final result = await _run([
      'log',
      '-n',
      '$limit',
      '--pretty=format:%H%x1f%h%x1f%P%x1f%an%x1f%ad%x1f%s%x1f%D',
      '--date=short',
    ]);
    if (!result.ok) {
      if (result.stderr.contains('does not have any commits')) return [];
      throw GitException(result.output.isEmpty ? 'خواندن کامیت‌ها ناموفق بود' : result.output);
    }

    final commits = <GitCommit>[];
    for (final line in result.stdout.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\x1f');
      if (parts.length < 6) continue;
      final parents = parts[2].trim().isEmpty ? <String>[] : parts[2].trim().split(' ');
      final refs = _parseRefs(parts.length > 6 ? parts[6] : '');
      commits.add(
        GitCommit(
          hash: parts[0],
          shortHash: parts[1],
          parents: parents,
          author: parts[3],
          date: parts[4],
          message: parts[5],
          refs: refs,
        ),
      );
    }
    return commits;
  }

  List<String> _parseRefs(String deco) {
    if (deco.trim().isEmpty) return [];
    return deco
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) {
          if (e.startsWith('HEAD -> ')) return e.substring(8);
          if (e == 'HEAD') return 'HEAD';
          if (e.startsWith('tag: ')) return e.substring(5);
          return e;
        })
        .toList();
  }

  Future<List<GitStash>> listStashes() async {
    final result = await _run(['stash', 'list', '--pretty=format:%gd%x1f%gs']);
    if (!result.ok || result.stdout.trim().isEmpty) return [];
    final items = <GitStash>[];
    for (final line in result.stdout.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\x1f');
      if (parts.isEmpty) continue;
      items.add(GitStash(ref: parts[0], message: parts.length > 1 ? parts[1] : parts[0]));
    }
    return items;
  }

  Future<String> diffFile(String path, {required bool staged}) async {
    final args = staged ? ['diff', '--cached', '--', path] : ['diff', '--', path];
    final result = await _run(args);
    if (!result.ok && result.stdout.isEmpty) {
      // Untracked: show as full file add
      if (!staged) {
        final show = await _run(['show', ':$path']);
        if (!show.ok) {
          try {
            final file = File('${_requirePath()}${Platform.pathSeparator}$path');
            if (await file.exists()) {
              final content = await file.readAsString();
              return content.split('\n').map((l) => '+$l').join('\n');
            }
          } catch (_) {}
        }
      }
      return result.output;
    }
    if (result.stdout.trim().isEmpty && !staged) {
      try {
        final file = File('${_requirePath()}${Platform.pathSeparator}$path');
        if (await file.exists()) {
          final tracked = await _run(['ls-files', '--', path]);
          if (tracked.stdout.trim().isEmpty) {
            final content = await file.readAsString();
            return content.split('\n').take(400).map((l) => '+$l').join('\n');
          }
        }
      } catch (_) {}
    }
    return result.stdout;
  }

  Future<String> showCommit(String hash) async {
    final result = await _run([
      'show',
      '--stat',
      '--format=commit %H%nAuthor: %an <%ae>%nDate:   %ad%n%n    %s%n',
      '--date=iso',
      hash,
    ]);
    if (!result.ok) throw GitException(result.output);
    final patch = await _run(['show', '--format=', '-p', hash]);
    final body = StringBuffer(result.stdout);
    if (patch.ok && patch.stdout.trim().isNotEmpty) {
      body.writeln();
      final lines = patch.stdout.split('\n');
      if (lines.length > 800) {
        body.write(lines.take(800).join('\n'));
        body.writeln('\n… (diff truncated)');
      } else {
        body.write(patch.stdout);
      }
    }
    return body.toString();
  }

  Future<List<GitCommitFile>> listCommitFiles(String hash) async {
    final result = await _run(['diff-tree', '--no-commit-id', '--name-status', '-r', hash]);
    if (!result.ok) {
      // Fallback for root commits
      final fallback = await _run(['show', '--name-status', '--pretty=format:', hash]);
      if (!fallback.ok) {
        throw GitException(result.output.isEmpty ? 'Failed to list commit files' : result.output);
      }
      return _parseNameStatus(fallback.stdout);
    }
    return _parseNameStatus(result.stdout);
  }

  List<GitCommitFile> _parseNameStatus(String stdout) {
    final files = <GitCommitFile>[];
    for (final line in stdout.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.trim().isEmpty) continue;
      final parts = trimmed.split('\t');
      if (parts.isEmpty) continue;
      final statusRaw = parts.first.trim();
      if (statusRaw.isEmpty) continue;
      final status = statusRaw[0];
      if (parts.length >= 3 && (status == 'R' || status == 'C')) {
        files.add(GitCommitFile(path: parts[2], status: status, oldPath: parts[1]));
      } else if (parts.length >= 2) {
        files.add(GitCommitFile(path: parts[1], status: status));
      }
    }
    return files;
  }

  Future<String> showCommitFileDiff(String hash, String path) async {
    final result = await _run(['show', '--format=', '-p', hash, '--', path]);
    if (!result.ok && result.stdout.trim().isEmpty) {
      throw GitException(result.output.isEmpty ? 'Failed to load file diff' : result.output);
    }
    if (result.stdout.trim().isEmpty) return '(no diff for $path)';
    return result.stdout;
  }

  Future<String> showFileAtRevision(String revision, String path) async {
    final result = await _run(['show', '$revision:$path']);
    if (!result.ok) {
      throw GitException(result.output.isEmpty ? 'File not found at revision' : result.output);
    }
    return result.stdout;
  }

  Future<GitCommandResult> checkout(String branch) {
    if (branch.startsWith('origin/')) {
      final localName = branch.substring('origin/'.length);
      return _run(['checkout', '-B', localName, '--track', branch]);
    }
    return _run(['checkout', branch]);
  }

  Future<GitCommandResult> createBranch(String name, {bool checkout = true}) {
    if (checkout) return _run(['checkout', '-b', name]);
    return _run(['branch', name]);
  }

  Future<GitCommandResult> createBranchAt(String name, String commit) {
    return _run(['checkout', '-b', name, commit]);
  }

  Future<GitCommandResult> deleteBranch(String name, {bool force = false}) {
    return _run(['branch', force ? '-D' : '-d', name]);
  }

  Future<GitCommandResult> fetch() => _run(['fetch', '--all', '--prune']);

  Future<GitCommandResult> pull({bool rebase = false}) {
    if (rebase) return _run(['pull', '--rebase', '--autostash']);
    return _run(['pull', '--no-rebase', '--autostash']);
  }

  Future<GitCommandResult> push({bool setUpstream = false, bool forceWithLease = false}) {
    if (setUpstream) return _run(['push', '-u', 'origin', 'HEAD']);
    if (forceWithLease) return _run(['push', '--force-with-lease']);
    return _run(['push']);
  }

  Future<GitCommandResult> merge(String ref, {bool noFf = false, bool ffOnly = false}) {
    final args = <String>['merge'];
    if (ffOnly) {
      args.add('--ff-only');
    } else if (noFf) {
      args.add('--no-ff');
    }
    args.add(ref);
    return _run(args);
  }

  Future<GitCommandResult> rebase(String onto, {bool interactive = false}) {
    // Interactive rebase is not supported in GUI process mode.
    return _run(['rebase', onto]);
  }

  Future<GitCommandResult> rebaseAbort() => _run(['rebase', '--abort']);

  Future<GitCommandResult> rebaseContinue() => _run(['rebase', '--continue']);

  Future<GitCommandResult> mergeAbort() => _run(['merge', '--abort']);

  Future<GitCommandResult> cherryPick(String hash) => _run(['cherry-pick', hash]);

  Future<GitCommandResult> cherryPickAbort() => _run(['cherry-pick', '--abort']);

  Future<GitCommandResult> resetTo(String ref, {String mode = 'mixed'}) {
    final flag = switch (mode) {
      'soft' => '--soft',
      'hard' => '--hard',
      _ => '--mixed',
    };
    return _run(['reset', flag, ref]);
  }

  Future<GitCommandResult> createTag(String name, {String? message, String? commit}) {
    final args = <String>['tag'];
    if (message != null && message.trim().isNotEmpty) {
      args.addAll(['-a', name, '-m', message.trim()]);
    } else {
      args.add(name);
    }
    if (commit != null && commit.isNotEmpty) args.add(commit);
    return _run(args);
  }

  Future<bool> isRebasing() async {
    final merge = await _run(['rev-parse', '--git-path', 'rebase-merge']);
    final apply = await _run(['rev-parse', '--git-path', 'rebase-apply']);
    if (merge.ok && Directory(merge.stdout.trim()).existsSync()) return true;
    if (apply.ok && Directory(apply.stdout.trim()).existsSync()) return true;
    return false;
  }

  Future<bool> isMerging() async {
    final result = await _run(['rev-parse', '-q', '--verify', 'MERGE_HEAD']);
    return result.ok;
  }

  Future<GitCommandResult> stageAll() => _run(['add', '-A']);

  Future<GitCommandResult> unstageAll() => _run(['reset']);

  Future<GitCommandResult> stageFile(String path) => _run(['add', '--', path]);

  Future<GitCommandResult> unstageFile(String path) => _run(['reset', 'HEAD', '--', path]);

  Future<GitCommandResult> discardFile(String path) => _run(['checkout', '--', path]);

  Future<GitCommandResult> commit(String message) => _run(['commit', '-m', message]);

  Future<GitCommandResult> stash({String? message}) {
    if (message == null || message.trim().isEmpty) return _run(['stash', 'push', '-u']);
    return _run(['stash', 'push', '-u', '-m', message.trim()]);
  }

  Future<GitCommandResult> stashPop() => _run(['stash', 'pop']);

  Future<GitCommandResult> applyStash(String ref) => _run(['stash', 'apply', ref]);

  Future<String> suggestCommitMessage() async {
    final changes = await status();
    if (changes.isEmpty) return 'chore: no changes';

    final staged = changes.where((c) => c.staged).toList();
    final relevant = staged.isNotEmpty ? staged : changes;
    final paths = relevant.map((c) => c.path).toList();
    final sample = paths.take(3).join(', ');
    final more = paths.length > 3 ? ' (+${paths.length - 3})' : '';

    final hasNew = relevant.any((c) => c.statusCode == 'A' || c.statusCode == '?');
    final hasDelete = relevant.any((c) => c.statusCode == 'D');
    final hasFixHint = paths.any(
      (p) => p.toLowerCase().contains('fix') || p.toLowerCase().contains('bug'),
    );

    if (hasFixHint) return 'fix: $sample$more';
    if (hasNew && !hasDelete) return 'feat: $sample$more';
    if (hasDelete && !hasNew) return 'chore: remove $sample$more';
    return 'chore: update $sample$more';
  }

  Future<GitCommandResult> run(List<String> args, {String? cwd}) => _run(args, cwd: cwd);

  Future<GitCommandResult> _run(List<String> args, {String? cwd}) async {
    final workingDir = cwd ?? _repoPath;
    if (workingDir == null || workingDir.isEmpty) {
      throw GitException('مسیر مخزن تنظیم نشده است');
    }

    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: workingDir,
        environment: {
          ...Platform.environment,
          'LANG': 'C',
          'GIT_TERMINAL_PROMPT': '0',
        },
      );
      return GitCommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (e) {
      throw GitException('اجرای git ممکن نیست: ${e.message}');
    }
  }

  String _requirePath() {
    final path = _repoPath;
    if (path == null || path.isEmpty) {
      throw GitException('مسیر مخزن تنظیم نشده است');
    }
    return path;
  }
}

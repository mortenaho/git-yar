import 'package:flutter/foundation.dart';

import '../models/git_models.dart';
import '../services/commit_graph.dart';
import '../services/git_service.dart';

class RepoController extends ChangeNotifier {
  RepoController({GitService? git}) : _git = git ?? GitService();

  final GitService _git;

  GitRepoInfo? repo;
  List<GitBranch> branches = [];
  List<GitFileChange> changes = [];
  List<GitCommit> commits = [];
  List<GitStash> stashes = [];
  List<GraphNode> graph = [];
  List<GitConflictFile> conflicts = [];
  List<GitCommitFile> commitFiles = [];
  GitCommitFile? selectedCommitFile;

  GitCommit? selectedCommit;
  GitFileChange? selectedFile;
  String? diffText;
  bool loadingDiff = false;
  bool showConflictResolver = false;

  String? editorText;
  String? editorPath;
  bool loadingEditor = false;
  bool editorReadOnly = false;

  String? lastLog;
  String? error;
  bool loading = false;
  bool busy = false;
  bool isRebasing = false;
  bool isMerging = false;

  bool get hasRepo => repo != null;
  bool get hasConflictState => isRebasing || isMerging || conflicts.isNotEmpty;
  bool get hasUnresolvedConflicts => conflicts.isNotEmpty;

  void openConflictResolver() {
    showConflictResolver = true;
    notifyListeners();
  }

  void closeConflictResolver() {
    showConflictResolver = false;
    notifyListeners();
  }

  List<GitFileChange> get staged => changes.where((c) => c.staged).toList();
  List<GitFileChange> get unstaged => changes.where((c) => !c.staged).toList();
  List<GitBranch> get localBranches => branches.where((b) => !b.isRemote).toList();
  List<GitBranch> get remoteBranches => branches.where((b) => b.isRemote).toList();

  Future<bool> openRepo(String path) async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final ok = await _git.isGitRepo(path);
      if (!ok) {
        error = 'This folder is not a valid Git repository.';
        repo = null;
        return false;
      }
      _git.repoPath = path;
      await refresh();
      return true;
    } on GitException catch (e) {
      error = e.message;
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_git.repoPath == null) return;
    error = null;
    loading = true;
    notifyListeners();
    try {
      repo = await _git.loadRepoInfo();
      branches = await _git.listBranches();
      changes = await _git.status();
      conflicts = await _git.listConflicts();
      commits = await _git.recentCommits();
      stashes = await _git.listStashes();
      graph = CommitGraphBuilder.build(commits);
      isRebasing = await _git.isRebasing();
      isMerging = await _git.isMerging();
      if (conflicts.isEmpty) {
        showConflictResolver = false;
      }

      if (selectedCommit != null) {
        final match = commits.where((c) => c.hash == selectedCommit!.hash);
        selectedCommit = match.isEmpty ? null : match.first;
      }
      if (selectedCommit == null && commits.isNotEmpty) {
        selectedCommit = commits.first;
      }

      if (selectedFile != null) {
        final match = changes.where((c) => c.path == selectedFile!.path && c.staged == selectedFile!.staged);
        selectedFile = match.isEmpty ? null : match.first;
        if (selectedFile != null) {
          await _loadFileDiff(selectedFile!);
        } else {
          diffText = selectedCommit != null ? await _git.showCommit(selectedCommit!.hash) : null;
        }
      } else if (selectedCommit != null) {
        diffText = await _git.showCommit(selectedCommit!.hash);
      }
    } on GitException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectCommit(GitCommit commit) async {
    selectedCommit = commit;
    selectedFile = null;
    selectedCommitFile = null;
    commitFiles = [];
    editorText = null;
    editorPath = null;
    editorReadOnly = false;
    loadingDiff = true;
    notifyListeners();
    try {
      commitFiles = await _git.listCommitFiles(commit.hash);
      if (commitFiles.isNotEmpty) {
        await _selectCommitFileInternal(commitFiles.first);
      } else {
        diffText = await _git.showCommit(commit.hash);
      }
    } on GitException catch (e) {
      error = e.message;
      diffText = e.message;
    } finally {
      loadingDiff = false;
      notifyListeners();
    }
  }

  Future<void> selectCommitFile(GitCommitFile file) async {
    loadingDiff = true;
    selectedFile = null;
    notifyListeners();
    try {
      await _selectCommitFileInternal(file);
    } on GitException catch (e) {
      error = e.message;
      diffText = e.message;
    } finally {
      loadingDiff = false;
      notifyListeners();
    }
  }

  Future<void> _selectCommitFileInternal(GitCommitFile file) async {
    selectedCommitFile = file;
    final commit = selectedCommit;
    if (commit == null) return;
    diffText = await _git.showCommitFileDiff(commit.hash, file.path);
    editorReadOnly = true;
    if (file.status == 'D') {
      editorText = '// File deleted in this commit\n';
      editorPath = file.path;
    } else {
      try {
        editorText = await _git.showFileAtRevision(commit.hash, file.path);
        editorPath = file.path;
      } on GitException {
        editorText = '// Unable to read file at this revision\n';
        editorPath = file.path;
      }
    }
  }

  Future<void> selectFile(GitFileChange file) async {
    selectedFile = file;
    selectedCommitFile = null;
    editorReadOnly = false;
    loadingDiff = true;
    notifyListeners();
    await _loadFileDiff(file);
    loadingDiff = false;
    notifyListeners();
    await loadEditorFile(file.path);
  }

  Future<void> loadEditorFile(String path) async {
    loadingEditor = true;
    editorReadOnly = false;
    notifyListeners();
    try {
      editorText = await _git.readWorkingFile(path);
      editorPath = path;
    } on GitException catch (e) {
      editorText = '// Unable to open file\n// $e\n';
      editorPath = path;
    } finally {
      loadingEditor = false;
      notifyListeners();
    }
  }

  Future<void> saveEditorFile(String path, String content) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _git.writeWorkingFile(path, content);
      editorText = content;
      editorPath = path;
      lastLog = 'Saved $path';
      // Refresh status/diff without dropping editor buffer.
      changes = await _git.status();
      conflicts = await _git.listConflicts();
      if (selectedFile != null) {
        await _loadFileDiff(selectedFile!);
      }
    } on GitException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadFileDiff(GitFileChange file) async {
    try {
      diffText = await _git.diffFile(file.path, staged: file.staged);
      if (diffText == null || diffText!.trim().isEmpty) {
        diffText = '(no diff)';
      }
    } on GitException catch (e) {
      diffText = e.message;
    }
  }

  Future<void> _runAction(Future<GitCommandResult> Function() action, {String? success}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      lastLog = result.output.isEmpty ? (success ?? 'Done') : result.output;
      if (!result.ok) {
        error = result.output.isEmpty ? 'عملیات ناموفق بود' : result.output;
      }
      await refresh();
    } on GitException catch (e) {
      error = e.message;
      notifyListeners();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> checkout(String branch) => _runAction(() => _git.checkout(branch), success: 'Checked out $branch');

  Future<void> createBranch(String name) => _runAction(() => _git.createBranch(name), success: 'Created $name');

  Future<void> createBranchAt(String name, String commit) =>
      _runAction(() => _git.createBranchAt(name, commit), success: 'Created $name at $commit');

  Future<void> deleteBranch(String name) => _runAction(() => _git.deleteBranch(name), success: 'Deleted $name');

  Future<void> fetch() => _runAction(_git.fetch, success: 'Fetched');

  Future<void> pull({bool rebase = false}) =>
      _runAction(() => _git.pull(rebase: rebase), success: rebase ? 'Pulled (rebase)' : 'Pulled');

  Future<void> push({bool setUpstream = false, bool forceWithLease = false}) => _runAction(
        () => _git.push(setUpstream: setUpstream, forceWithLease: forceWithLease),
        success: forceWithLease ? 'Force-pushed (lease)' : 'Pushed',
      );

  Future<void> merge(String ref, {bool noFf = false, bool ffOnly = false}) => _runAction(
        () => _git.merge(ref, noFf: noFf, ffOnly: ffOnly),
        success: 'Merged $ref',
      );

  Future<void> rebase(String onto) => _runAction(() => _git.rebase(onto), success: 'Rebased onto $onto');

  Future<void> rebaseAbort() => _runAction(_git.rebaseAbort, success: 'Rebase aborted');

  Future<void> rebaseContinue() => _runAction(_git.rebaseContinue, success: 'Rebase continued');

  Future<void> mergeAbort() => _runAction(_git.mergeAbort, success: 'Merge aborted');

  Future<void> cherryPick(String hash) => _runAction(() => _git.cherryPick(hash), success: 'Cherry-picked $hash');

  Future<void> cherryPickAbort() => _runAction(_git.cherryPickAbort, success: 'Cherry-pick aborted');

  Future<void> resetTo(String ref, {String mode = 'mixed'}) =>
      _runAction(() => _git.resetTo(ref, mode: mode), success: 'Reset ($mode) to $ref');

  Future<void> createTag(String name, {String? message, String? commit}) => _runAction(
        () => _git.createTag(name, message: message, commit: commit),
        success: 'Tagged $name',
      );

  Future<void> stageAll() => _runAction(_git.stageAll, success: 'Staged all');

  Future<void> unstageAll() => _runAction(_git.unstageAll, success: 'Unstaged all');

  Future<void> stageFile(String path) => _runAction(() => _git.stageFile(path), success: 'Staged $path');

  Future<void> unstageFile(String path) => _runAction(() => _git.unstageFile(path), success: 'Unstaged $path');

  Future<void> discardFile(String path) => _runAction(() => _git.discardFile(path), success: 'Discarded $path');

  Future<void> commit(String message) => _runAction(() => _git.commit(message), success: 'Committed');

  Future<void> stash([String? message]) => _runAction(() => _git.stash(message: message), success: 'Stashed');

  Future<void> stashPop() => _runAction(_git.stashPop, success: 'Stash popped');

  Future<void> applyStash(String ref) => _runAction(() => _git.applyStash(ref), success: 'Stash applied');

  Future<String> readConflictFile(String path) => _git.readWorkingFile(path);

  Future<void> resolveConflictOurs(String path) =>
      _runAction(() => _git.resolveWithOurs(path), success: 'Resolved with ours: $path');

  Future<void> resolveConflictTheirs(String path) =>
      _runAction(() => _git.resolveWithTheirs(path), success: 'Resolved with theirs: $path');

  Future<void> saveResolvedFile(String path, String content, {bool markResolved = true}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _git.writeWorkingFile(path, content);
      if (markResolved) {
        final result = await _git.markResolved(path);
        lastLog = result.output.isEmpty ? 'Marked resolved: $path' : result.output;
        if (!result.ok) {
          error = result.output;
        }
      }
      await refresh();
    } on GitException catch (e) {
      error = e.message;
      notifyListeners();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> markConflictResolved(String path) =>
      _runAction(() => _git.markResolved(path), success: 'Marked resolved: $path');

  Future<String> suggestCommitMessage() => _git.suggestCommitMessage();

  void closeRepo() {
    _git.repoPath = null;
    repo = null;
    branches = [];
    changes = [];
    commits = [];
    stashes = [];
    graph = [];
    conflicts = [];
    commitFiles = [];
    selectedCommit = null;
    selectedCommitFile = null;
    selectedFile = null;
    diffText = null;
    editorText = null;
    editorPath = null;
    editorReadOnly = false;
    lastLog = null;
    error = null;
    showConflictResolver = false;
    notifyListeners();
  }
}

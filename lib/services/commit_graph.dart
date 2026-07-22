import '../models/git_models.dart';

/// Assigns lanes for a GitKraken-style commit graph.
class CommitGraphBuilder {
  static List<GraphNode> build(List<GitCommit> commits) {
    if (commits.isEmpty) return [];

    final nodes = <GraphNode>[];
    // Active lane tips: commit hash expected next in that lane (or null = free)
    final active = <String?>[];

    for (var row = 0; row < commits.length; row++) {
      final commit = commits[row];
      final connections = <GraphConnection>[];

      var lane = active.indexOf(commit.hash);
      if (lane < 0) {
        lane = active.indexWhere((h) => h == null);
        if (lane < 0) {
          lane = active.length;
          active.add(commit.hash);
        } else {
          active[lane] = commit.hash;
        }
      }

      // Continuations for other active tips into next row
      final continuing = <int>[];
      for (var i = 0; i < active.length; i++) {
        final tip = active[i];
        if (tip == null || tip == commit.hash) continue;
        // Will still be active next row unless closed later
        continuing.add(i);
      }

      active[lane] = null;

      final parents = commit.parents;
      if (parents.isNotEmpty) {
        // First parent continues on same lane when possible
        final first = parents.first;
        final existingFirst = active.indexOf(first);
        if (existingFirst >= 0 && existingFirst != lane) {
          connections.add(GraphConnection(fromLane: lane, toLane: existingFirst, isMerge: false));
        } else {
          active[lane] = first;
          connections.add(GraphConnection(fromLane: lane, toLane: lane, isMerge: false));
        }

        for (var p = 1; p < parents.length; p++) {
          final parent = parents[p];
          var parentLane = active.indexOf(parent);
          if (parentLane < 0) {
            parentLane = active.indexWhere((h) => h == null);
            if (parentLane < 0) {
              parentLane = active.length;
              active.add(parent);
            } else {
              active[parentLane] = parent;
            }
          }
          connections.add(GraphConnection(fromLane: lane, toLane: parentLane, isMerge: true));
        }
      }

      // Pass-through connections for other active lanes
      for (final i in continuing) {
        if (i == lane) continue;
        connections.add(GraphConnection(fromLane: i, toLane: i, isMerge: false));
      }

      final occupied = <int>{lane};
      for (var i = 0; i < active.length; i++) {
        if (active[i] != null) occupied.add(i);
      }
      for (final c in connections) {
        occupied.add(c.fromLane);
        occupied.add(c.toLane);
      }

      nodes.add(
        GraphNode(
          commit: commit,
          lane: lane,
          laneCount: occupied.isEmpty ? 1 : (occupied.reduce((a, b) => a > b ? a : b) + 1),
          activeLanes: occupied.toList()..sort(),
          connections: connections,
        ),
      );

      // Trim trailing nulls
      while (active.isNotEmpty && active.last == null) {
        active.removeLast();
      }
    }

    // Normalize laneCount to max across nearby rows for stable width
    var maxLanes = 1;
    for (final n in nodes) {
      if (n.laneCount > maxLanes) maxLanes = n.laneCount;
    }
    return [
      for (final n in nodes)
        GraphNode(
          commit: n.commit,
          lane: n.lane,
          laneCount: maxLanes,
          activeLanes: n.activeLanes,
          connections: n.connections,
        ),
    ];
  }
}

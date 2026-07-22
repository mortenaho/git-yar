/// Parses git conflict markers into editable segments.
class ConflictDocument {
  ConflictDocument({required this.segments});

  final List<ConflictSegment> segments;

  bool get hasConflicts => segments.any((s) => s is ConflictHunk);

  int get conflictCount => segments.whereType<ConflictHunk>().length;

  bool get allResolved =>
      segments.whereType<ConflictHunk>().every((h) => h.isResolved);

  String toFileContent() {
    final parts = <String>[];
    for (final segment in segments) {
      parts.add(segment.resolvedText);
    }
    return parts.join('\n');
  }

  static ConflictDocument parse(String content) {
    final lines = content.split('\n');
    // Preserve trailing newline semantics loosely; work line-based.
    final segments = <ConflictSegment>[];
    final plain = <String>[];

    void flushPlain() {
      if (plain.isEmpty) return;
      segments.add(PlainSegment(plain.join('\n')));
      plain.clear();
    }

    var i = 0;
    while (i < lines.length) {
      if (lines[i].startsWith('<<<<<<<')) {
        flushPlain();
        i++;
        final ours = <String>[];
        while (i < lines.length &&
            !lines[i].startsWith('=======') &&
            !lines[i].startsWith('|||||||')) {
          ours.add(lines[i]);
          i++;
        }
        final base = <String>[];
        if (i < lines.length && lines[i].startsWith('|||||||')) {
          i++;
          while (i < lines.length && !lines[i].startsWith('=======')) {
            base.add(lines[i]);
            i++;
          }
        }
        if (i < lines.length && lines[i].startsWith('=======')) i++;
        final theirs = <String>[];
        while (i < lines.length && !lines[i].startsWith('>>>>>>>')) {
          theirs.add(lines[i]);
          i++;
        }
        if (i < lines.length && lines[i].startsWith('>>>>>>>')) i++;

        segments.add(
          ConflictHunk(
            ours: ours.join('\n'),
            theirs: theirs.join('\n'),
            base: base.isEmpty ? null : base.join('\n'),
          ),
        );
      } else {
        plain.add(lines[i]);
        i++;
      }
    }
    flushPlain();
    return ConflictDocument(segments: segments);
  }
}

sealed class ConflictSegment {
  String get resolvedText;
}

class PlainSegment extends ConflictSegment {
  PlainSegment(this.text);
  final String text;

  @override
  String get resolvedText => text;
}

enum ConflictChoice { unresolved, ours, theirs, both, manual }

class ConflictHunk extends ConflictSegment {
  ConflictHunk({
    required this.ours,
    required this.theirs,
    this.base,
    this.choice = ConflictChoice.unresolved,
    String? manualText,
  }) : manualText = manualText ?? '';

  final String ours;
  final String theirs;
  final String? base;
  ConflictChoice choice;
  String manualText;

  bool get isResolved => choice != ConflictChoice.unresolved;

  @override
  String get resolvedText {
    switch (choice) {
      case ConflictChoice.ours:
        return ours;
      case ConflictChoice.theirs:
        return theirs;
      case ConflictChoice.both:
        if (ours.isEmpty) return theirs;
        if (theirs.isEmpty) return ours;
        return '$ours\n$theirs';
      case ConflictChoice.manual:
        return manualText;
      case ConflictChoice.unresolved:
        final buffer = StringBuffer('<<<<<<< ours\n');
        buffer.writeln(ours);
        if (base != null) {
          buffer.writeln('||||||| base');
          buffer.writeln(base);
        }
        buffer.writeln('=======');
        buffer.writeln(theirs);
        buffer.write('>>>>>>> theirs');
        return buffer.toString();
    }
  }
}

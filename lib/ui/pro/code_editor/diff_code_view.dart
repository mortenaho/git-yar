import 'package:flutter/material.dart';

import 'syntax_highlighter.dart';

enum DiffLineKind { context, added, removed, meta, hunk }

class DiffLine {
  const DiffLine({
    required this.text,
    required this.kind,
    this.oldNo,
    this.newNo,
  });

  final String text;
  final DiffLineKind kind;
  final int? oldNo;
  final int? newNo;
}

class DiffCodeView extends StatelessWidget {
  const DiffCodeView({
    super.key,
    required this.diffText,
    this.language = CodeLanguage.plain,
  });

  final String diffText;
  final CodeLanguage language;

  static List<DiffLine> parse(String raw) {
    final lines = <DiffLine>[];
    var oldNo = 0;
    var newNo = 0;

    for (final line in raw.split('\n')) {
      if (line.startsWith('@@')) {
        final m = RegExp(r'@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@').firstMatch(line);
        if (m != null) {
          oldNo = int.parse(m.group(1)!);
          newNo = int.parse(m.group(2)!);
        }
        lines.add(DiffLine(text: line, kind: DiffLineKind.hunk));
        continue;
      }
      if (line.startsWith('+++') ||
          line.startsWith('---') ||
          line.startsWith('diff ') ||
          line.startsWith('index ') ||
          line.startsWith('commit ') ||
          line.startsWith('Author:') ||
          line.startsWith('Date:') ||
          line.startsWith('new file') ||
          line.startsWith('deleted file')) {
        lines.add(DiffLine(text: line, kind: DiffLineKind.meta));
        continue;
      }
      if (line.startsWith('+')) {
        lines.add(DiffLine(text: line, kind: DiffLineKind.added, newNo: newNo));
        newNo++;
      } else if (line.startsWith('-')) {
        lines.add(DiffLine(text: line, kind: DiffLineKind.removed, oldNo: oldNo));
        oldNo++;
      } else if (line.startsWith(r'\') || line == '(no diff)') {
        lines.add(DiffLine(text: line, kind: DiffLineKind.meta));
      } else {
        // context line may start with space
        final body = line.startsWith(' ') ? line : ' $line';
        lines.add(DiffLine(text: body, kind: DiffLineKind.context, oldNo: oldNo, newNo: newNo));
        oldNo++;
        newNo++;
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = SyntaxTheme.proDark;
    final lines = parse(diffText);

    if (lines.isEmpty) {
      return ColoredBox(
        color: theme.background,
        child: const Center(
          child: Text('No diff', style: TextStyle(color: Color(0xFF66718A))),
        ),
      );
    }

    return ColoredBox(
      color: theme.background,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final bg = switch (line.kind) {
            DiffLineKind.added => theme.added,
            DiffLineKind.removed => theme.removed,
            DiffLineKind.hunk => theme.hunk,
            DiffLineKind.meta => const Color(0x14FFFFFF),
            DiffLineKind.context => null,
          };

          final prefixColor = switch (line.kind) {
            DiffLineKind.added => const Color(0xFF5FE08A),
            DiffLineKind.removed => const Color(0xFFFF6B7A),
            DiffLineKind.hunk => const Color(0xFF5B8CFF),
            DiffLineKind.meta => theme.gutter,
            DiffLineKind.context => theme.gutter,
          };

          // Strip diff prefix for syntax highlight of code body
          String codeBody = line.text;
          String prefix = ' ';
          if (line.kind == DiffLineKind.added && line.text.startsWith('+')) {
            prefix = '+';
            codeBody = line.text.substring(1);
          } else if (line.kind == DiffLineKind.removed && line.text.startsWith('-')) {
            prefix = '-';
            codeBody = line.text.substring(1);
          } else if (line.text.startsWith(' ')) {
            prefix = ' ';
            codeBody = line.text.substring(1);
          }

          final isCode = line.kind == DiffLineKind.added ||
              line.kind == DiffLineKind.removed ||
              line.kind == DiffLineKind.context;

          return ColoredBox(
            color: bg ?? Colors.transparent,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GutterCell(value: line.oldNo, theme: theme),
                  _GutterCell(value: line.newNo, theme: theme),
                  Container(
                    width: 22,
                    alignment: Alignment.center,
                    color: theme.gutterBg,
                    child: Text(
                      prefix,
                      style: TextStyle(
                        fontFamily: 'SourceCodePro',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: prefixColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                      child: isCode
                          ? Text.rich(
                              SyntaxHighlighter.highlight(
                                codeBody.isEmpty ? ' ' : codeBody,
                                language: language,
                                theme: theme,
                                baseStyle: const TextStyle(fontSize: 13, height: 1.45),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              line.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'SourceCodePro',
                                fontSize: 12,
                                height: 1.45,
                                color: prefixColor,
                                fontWeight: line.kind == DiffLineKind.hunk ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GutterCell extends StatelessWidget {
  const _GutterCell({required this.value, required this.theme});

  final int? value;
  final SyntaxTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 8),
      color: theme.gutterBg,
      child: Text(
        value?.toString() ?? '',
        style: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 11,
          color: theme.gutter,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

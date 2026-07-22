import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class DiffView extends StatelessWidget {
  const DiffView({
    super.key,
    required this.text,
    required this.loading,
    this.title,
  });

  final String? text;
  final bool loading;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppTheme.proPanelAlt,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              title ?? 'Diff / Commit',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.proMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2, color: AppTheme.proAccent),
          Expanded(
            child: text == null || text!.isEmpty
                ? const Center(
                    child: Text('Select a commit or file', style: TextStyle(color: AppTheme.proMuted)),
                  )
                : Directionality(
                    textDirection: TextDirection.ltr,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText.rich(
                        TextSpan(children: _spans(text!)),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.45,
                          color: AppTheme.proText,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _spans(String raw) {
    final lines = raw.split('\n');
    final spans = <InlineSpan>[];
    for (final line in lines) {
      Color color = AppTheme.proText;
      if (line.startsWith('+') && !line.startsWith('+++')) {
        color = AppTheme.proGreen;
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        color = AppTheme.proDanger;
      } else if (line.startsWith('@@')) {
        color = AppTheme.proAccent2;
      } else if (line.startsWith('diff ') || line.startsWith('index ') || line.startsWith('commit ')) {
        color = AppTheme.proMuted;
      } else if (line.startsWith('Author:') || line.startsWith('Date:')) {
        color = AppTheme.proWarn;
      }
      spans.add(TextSpan(text: '$line\n', style: TextStyle(color: color)));
    }
    return spans;
  }
}

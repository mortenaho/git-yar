import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'syntax_highlighter.dart';

class HighlightEditingController extends TextEditingController {
  HighlightEditingController({
    String? text,
    required this.language,
    this.theme = SyntaxTheme.proDark,
  }) : super(text: text);

  CodeLanguage language;
  SyntaxTheme theme;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return SyntaxHighlighter.highlight(
      text,
      language: language,
      theme: theme,
      baseStyle: style,
    );
  }
}

class CodeEditorView extends StatefulWidget {
  const CodeEditorView({
    super.key,
    required this.text,
    required this.language,
    this.readOnly = false,
    this.onChanged,
    this.fileName,
  });

  final String text;
  final CodeLanguage language;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final String? fileName;

  @override
  State<CodeEditorView> createState() => _CodeEditorViewState();
}

class _CodeEditorViewState extends State<CodeEditorView> {
  static const double lineHeight = 20.15;
  static const double fontSize = 13;

  late HighlightEditingController _controller;
  late final ScrollController _scroll;
  late final ScrollController _gutterScroll;
  int _cursorLine = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = HighlightEditingController(text: widget.text, language: widget.language);
    _scroll = ScrollController()..addListener(_syncGutter);
    _gutterScroll = ScrollController();
    _controller.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant CodeEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.language = widget.language;
    if (widget.text != _controller.text && widget.text != oldWidget.text) {
      final sel = _controller.selection;
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(
          offset: sel.baseOffset.clamp(0, widget.text.length),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _scroll.removeListener(_syncGutter);
    _controller.dispose();
    _scroll.dispose();
    _gutterScroll.dispose();
    super.dispose();
  }

  void _handleChange() {
    final offset = _controller.selection.baseOffset;
    if (offset >= 0) {
      final safe = offset.clamp(0, _controller.text.length);
      _cursorLine = '\n'.allMatches(_controller.text.substring(0, safe)).length;
    }
    widget.onChanged?.call(_controller.text);
    setState(() {});
  }

  void _syncGutter() {
    if (_syncing || !_gutterScroll.hasClients) return;
    _syncing = true;
    final target = _scroll.offset.clamp(0.0, _gutterScroll.position.maxScrollExtent);
    if ((_gutterScroll.offset - target).abs() > 0.5) {
      _gutterScroll.jumpTo(target);
    }
    _syncing = false;
  }

  int get _lineCount {
    if (_controller.text.isEmpty) return 1;
    return '\n'.allMatches(_controller.text).length + 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = SyntaxTheme.proDark;
    final lines = _lineCount;
    final gutterWidth = 30.0 + (lines.toString().length * 8.5);

    final editor = widget.readOnly
        ? SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 24),
            child: SelectableText.rich(
              SyntaxHighlighter.highlight(
                _controller.text,
                language: widget.language,
                theme: theme,
                baseStyle: const TextStyle(fontSize: fontSize, height: lineHeight / fontSize),
              ),
            ),
          )
        : TextField(
            controller: _controller,
            scrollController: _scroll,
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            cursorColor: const Color(0xFF3DDC97),
            cursorWidth: 2,
            style: TextStyle(
              fontFamily: 'SourceCodePro',
              fontSize: fontSize,
              height: lineHeight / fontSize,
              color: theme.foreground,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(14, 12, 16, 24),
              isCollapsed: false,
            ),
          );

    return ColoredBox(
      color: theme.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: gutterWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.gutterBg,
                border: Border(right: BorderSide(color: theme.gutter.withValues(alpha: 0.28))),
              ),
              child: ListView.builder(
                controller: _gutterScroll,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                itemCount: lines,
                itemExtent: lineHeight,
                itemBuilder: (context, index) {
                  final active = !widget.readOnly && index == _cursorLine;
                  return Container(
                    color: active ? theme.currentLine : null,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontFamily: 'SourceCodePro',
                        fontSize: 12,
                        height: lineHeight / 12,
                        color: active ? const Color(0xFF3DDC97) : theme.gutter,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
                  _controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controller.text.length,
                  );
                },
              },
              child: editor,
            ),
          ),
        ],
      ),
    );
  }
}

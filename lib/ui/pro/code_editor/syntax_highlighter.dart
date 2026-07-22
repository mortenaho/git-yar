import 'package:flutter/material.dart';

enum CodeLanguage {
  dart,
  javascript,
  typescript,
  python,
  json,
  yaml,
  html,
  css,
  markdown,
  shell,
  rust,
  go,
  java,
  kotlin,
  csharp,
  sql,
  xml,
  plain,
}

class SyntaxTheme {
  const SyntaxTheme({
    required this.background,
    required this.foreground,
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.function,
    required this.type,
    required this.punctuation,
    required this.gutter,
    required this.gutterBg,
    required this.selection,
    required this.currentLine,
    required this.added,
    required this.removed,
    required this.hunk,
  });

  final Color background;
  final Color foreground;
  final Color keyword;
  final Color string;
  final Color comment;
  final Color number;
  final Color function;
  final Color type;
  final Color punctuation;
  final Color gutter;
  final Color gutterBg;
  final Color selection;
  final Color currentLine;
  final Color added;
  final Color removed;
  final Color hunk;

  static const proDark = SyntaxTheme(
    background: Color(0xFF0E1117),
    foreground: Color(0xFFD7DCE5),
    keyword: Color(0xFFC792EA),
    string: Color(0xFFC3E88D),
    comment: Color(0xFF66718A),
    number: Color(0xFFF78C6C),
    function: Color(0xFF82AAFF),
    type: Color(0xFFFFCB6B),
    punctuation: Color(0xFF89DDFF),
    gutter: Color(0xFF5C677A),
    gutterBg: Color(0xFF0B0D12),
    selection: Color(0x334EC9B0),
    currentLine: Color(0x14FFFFFF),
    added: Color(0x223DDC97),
    removed: Color(0x22FF6B7A),
    hunk: Color(0x225B8CFF),
  );
}

class SyntaxHighlighter {
  static CodeLanguage detectLanguage(String? path) {
    if (path == null || path.isEmpty) return CodeLanguage.plain;
    final lower = path.toLowerCase();
    final ext = lower.contains('.') ? lower.split('.').last : lower;
    return switch (ext) {
      'dart' => CodeLanguage.dart,
      'js' || 'mjs' || 'cjs' => CodeLanguage.javascript,
      'ts' || 'tsx' => CodeLanguage.typescript,
      'py' => CodeLanguage.python,
      'json' => CodeLanguage.json,
      'yaml' || 'yml' => CodeLanguage.yaml,
      'html' || 'htm' => CodeLanguage.html,
      'css' || 'scss' => CodeLanguage.css,
      'md' || 'markdown' => CodeLanguage.markdown,
      'sh' || 'bash' || 'zsh' => CodeLanguage.shell,
      'rs' => CodeLanguage.rust,
      'go' => CodeLanguage.go,
      'java' => CodeLanguage.java,
      'kt' || 'kts' => CodeLanguage.kotlin,
      'cs' => CodeLanguage.csharp,
      'sql' => CodeLanguage.sql,
      'xml' || 'svg' => CodeLanguage.xml,
      _ => CodeLanguage.plain,
    };
  }

  static String languageLabel(CodeLanguage lang) => switch (lang) {
        CodeLanguage.dart => 'Dart',
        CodeLanguage.javascript => 'JavaScript',
        CodeLanguage.typescript => 'TypeScript',
        CodeLanguage.python => 'Python',
        CodeLanguage.json => 'JSON',
        CodeLanguage.yaml => 'YAML',
        CodeLanguage.html => 'HTML',
        CodeLanguage.css => 'CSS',
        CodeLanguage.markdown => 'Markdown',
        CodeLanguage.shell => 'Shell',
        CodeLanguage.rust => 'Rust',
        CodeLanguage.go => 'Go',
        CodeLanguage.java => 'Java',
        CodeLanguage.kotlin => 'Kotlin',
        CodeLanguage.csharp => 'C#',
        CodeLanguage.sql => 'SQL',
        CodeLanguage.xml => 'XML',
        CodeLanguage.plain => 'Plain Text',
      };

  static Set<String> _keywords(CodeLanguage lang) {
    const common = {
      'if', 'else', 'for', 'while', 'return', 'switch', 'case', 'break', 'try', 'catch',
      'finally', 'throw', 'new', 'class', 'const', 'var', 'let', 'true', 'false', 'null',
      'void', 'import', 'export', 'from', 'as', 'in', 'of', 'this', 'super', 'static',
      'public', 'private', 'protected', 'async', 'await', 'yield', 'default',
    };
    return switch (lang) {
      CodeLanguage.dart => {
          ...common,
          'final', 'late', 'required', 'typedef', 'enum', 'mixin', 'extension',
          'with', 'implements', 'extends', 'abstract', 'factory', 'get', 'set',
          'part', 'library', 'show', 'hide', 'covariant', 'dynamic',
        },
      CodeLanguage.javascript || CodeLanguage.typescript => {
          ...common,
          'function', 'typeof', 'instanceof', 'undefined', 'interface', 'type',
          'implements', 'extends', 'readonly', 'namespace', 'declare', 'module',
        },
      CodeLanguage.python => {
          'def', 'class', 'if', 'elif', 'else', 'for', 'while', 'return', 'import',
          'from', 'as', 'try', 'except', 'finally', 'with', 'lambda', 'yield',
          'True', 'False', 'None', 'and', 'or', 'not', 'in', 'is', 'pass', 'raise',
          'global', 'nonlocal', 'async', 'await',
        },
      CodeLanguage.rust => {
          'fn', 'let', 'mut', 'struct', 'enum', 'impl', 'trait', 'pub', 'use', 'mod',
          'match', 'if', 'else', 'loop', 'while', 'for', 'in', 'return', 'async',
          'await', 'crate', 'self', 'super', 'where', 'type', 'const', 'static',
        },
      CodeLanguage.go => {
          'func', 'package', 'import', 'var', 'const', 'type', 'struct', 'interface',
          'map', 'chan', 'go', 'defer', 'if', 'else', 'for', 'range', 'return',
          'switch', 'case', 'select', 'true', 'false', 'nil',
        },
      CodeLanguage.java || CodeLanguage.kotlin || CodeLanguage.csharp => {
          ...common,
          'package', 'namespace', 'using', 'fun', 'val', 'object', 'data',
          'override', 'interface', 'enum', 'sealed', 'record',
        },
      CodeLanguage.sql => {
          'select', 'from', 'where', 'insert', 'update', 'delete', 'create', 'table',
          'join', 'left', 'right', 'inner', 'outer', 'on', 'and', 'or', 'not', 'null',
          'as', 'order', 'by', 'group', 'having', 'limit', 'values', 'into', 'set',
        },
      CodeLanguage.shell => {
          'if', 'then', 'fi', 'else', 'elif', 'for', 'do', 'done', 'while', 'case',
          'esac', 'function', 'return', 'export', 'local', 'echo', 'cd', 'exit',
        },
      _ => common,
    };
  }

  static TextSpan highlight(
    String source, {
    required CodeLanguage language,
    SyntaxTheme theme = SyntaxTheme.proDark,
    TextStyle? baseStyle,
  }) {
    final style = (baseStyle ?? const TextStyle()).copyWith(
      fontFamily: 'SourceCodePro',
      fontSize: baseStyle?.fontSize ?? 13,
      height: baseStyle?.height ?? 1.55,
      color: theme.foreground,
    );

    if (language == CodeLanguage.plain || source.isEmpty) {
      return TextSpan(text: source, style: style);
    }

    final keywords = _keywords(language);
    final spans = <InlineSpan>[];
    var i = 0;
    final n = source.length;

    TextStyle paint(Color c, {FontWeight? w}) => style.copyWith(color: c, fontWeight: w);

    while (i < n) {
      final ch = source[i];

      // Comments
      if (ch == '/' && i + 1 < n && source[i + 1] == '/') {
        final start = i;
        i += 2;
        while (i < n && source[i] != '\n') {
          i++;
        }
        spans.add(TextSpan(text: source.substring(start, i), style: paint(theme.comment)));
        continue;
      }
      if (ch == '/' && i + 1 < n && source[i + 1] == '*') {
        final start = i;
        i += 2;
        while (i + 1 < n && !(source[i] == '*' && source[i + 1] == '/')) {
          i++;
        }
        i = (i + 2).clamp(0, n);
        spans.add(TextSpan(text: source.substring(start, i), style: paint(theme.comment)));
        continue;
      }
      if (ch == '#' && language != CodeLanguage.html && language != CodeLanguage.css) {
        final start = i;
        while (i < n && source[i] != '\n') {
          i++;
        }
        spans.add(TextSpan(text: source.substring(start, i), style: paint(theme.comment)));
        continue;
      }

      // Strings
      if (ch == '"' || ch == "'") {
        final quote = ch;
        final start = i;
        i++;
        while (i < n) {
          if (source[i] == '\\' && i + 1 < n) {
            i += 2;
            continue;
          }
          if (source[i] == quote) {
            i++;
            break;
          }
          if (source[i] == '\n') break;
          i++;
        }
        spans.add(TextSpan(text: source.substring(start, i), style: paint(theme.string)));
        continue;
      }

      // Numbers
      if (_isDigit(ch) || (ch == '.' && i + 1 < n && _isDigit(source[i + 1]))) {
        final start = i;
        i++;
        while (i < n && (_isDigit(source[i]) || source[i] == '.' || source[i] == '_' || source[i] == 'x' || source[i] == 'X')) {
          i++;
        }
        spans.add(TextSpan(text: source.substring(start, i), style: paint(theme.number)));
        continue;
      }

      // Words
      if (_isIdentStart(ch)) {
        final start = i;
        i++;
        while (i < n && _isIdentPart(source[i])) {
          i++;
        }
        final word = source.substring(start, i);
        Color color = theme.foreground;
        FontWeight? weight;
        if (keywords.contains(word)) {
          color = theme.keyword;
          weight = FontWeight.w600;
        } else if (word.isNotEmpty && word[0].toUpperCase() == word[0] && word[0].toLowerCase() != word[0]) {
          color = theme.type;
        } else {
          var j = i;
          while (j < n && (source[j] == ' ' || source[j] == '\t')) {
            j++;
          }
          if (j < n && source[j] == '(') color = theme.function;
        }
        spans.add(TextSpan(text: word, style: paint(color, w: weight)));
        continue;
      }

      // Punctuation / whitespace chunk
      final start = i;
      i++;
      while (i < n && !_isIdentStart(source[i]) && !_isDigit(source[i]) && source[i] != '"' && source[i] != "'" && source[i] != '/' && source[i] != '#') {
        // keep single punct as one for color, but group whitespace
        if (source[i] == ' ' || source[i] == '\t' || source[i] == '\n') {
          if (source[start] == ' ' || source[start] == '\t' || source[start] == '\n') {
            i++;
            continue;
          }
          break;
        }
        break;
      }
      final token = source.substring(start, i);
      final isWs = token.trim().isEmpty;
      spans.add(TextSpan(text: token, style: isWs ? style : paint(theme.punctuation)));
    }

    return TextSpan(children: spans, style: style);
  }

  static bool _isDigit(String ch) => ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;

  static bool _isIdentStart(String ch) =>
      (ch.compareTo('a') >= 0 && ch.compareTo('z') <= 0) ||
      (ch.compareTo('A') >= 0 && ch.compareTo('Z') <= 0) ||
      ch == '_';

  static bool _isIdentPart(String ch) => _isIdentStart(ch) || _isDigit(ch);
}

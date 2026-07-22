import 'dart:io';

/// Native folder picker using desktop dialogs (no pub packages).
class FolderPicker {
  static Future<String?> pickDirectory({String? title}) async {
    final dialogTitle = title ?? 'انتخاب پوشه مخزن گیت';

    if (Platform.isLinux) {
      final kdialog = await _tryRun('kdialog', ['--getexistingdirectory', Directory.current.path, '--title', dialogTitle]);
      if (kdialog != null) return kdialog;

      final zenity = await _tryRun('zenity', [
        '--file-selection',
        '--directory',
        '--title=$dialogTitle',
      ]);
      if (zenity != null) return zenity;
    }

    if (Platform.isMacOS) {
      final script =
          'POSIX path of (choose folder with prompt "$dialogTitle")';
      final result = await _tryRun('osascript', ['-e', script]);
      if (result != null) return result.replaceAll(RegExp(r'/$'), '');
    }

    if (Platform.isWindows) {
      final ps = '''
Add-Type -AssemblyName System.Windows.Forms
\$d = New-Object System.Windows.Forms.FolderBrowserDialog
\$d.Description = '$dialogTitle'
if (\$d.ShowDialog() -eq 'OK') { Write-Output \$d.SelectedPath }
''';
      return _tryRun('powershell', ['-NoProfile', '-Command', ps]);
    }

    return null;
  }

  static Future<String?> _tryRun(String executable, List<String> args) async {
    try {
      final result = await Process.run(executable, args);
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString().trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }
}

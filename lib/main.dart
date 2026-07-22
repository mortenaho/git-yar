import 'package:flutter/material.dart';

import 'state/repo_controller.dart';
import 'theme/app_theme.dart';
import 'ui/pro/pro_workspace.dart';
import 'ui/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GitYarApp());
}

class GitYarApp extends StatefulWidget {
  const GitYarApp({super.key});

  @override
  State<GitYarApp> createState() => _GitYarAppState();
}

class _GitYarAppState extends State<GitYarApp> {
  late final RepoController _controller = RepoController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasRepo = _controller.hasRepo;

    return MaterialApp(
      title: 'Git Yar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.pro(),
      darkTheme: AppTheme.pro(),
      themeMode: ThemeMode.dark,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: hasRepo
          ? ProWorkspace(controller: _controller)
          : WelcomeScreen(controller: _controller),
    );
  }
}

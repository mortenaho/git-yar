import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/folder_picker.dart';
import '../state/repo_controller.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.controller});

  final RepoController controller;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  final _pathController = TextEditingController();
  final _pathFocus = FocusNode();
  bool _opening = false;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocus.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final path = await FolderPicker.pickDirectory(title: 'Select Git repository');
    if (path != null) {
      _pathController.text = path;
      setState(() {});
    }
  }

  Future<void> _open() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a repository path')),
      );
      _pathFocus.requestFocus();
      return;
    }
    setState(() => _opening = true);
    final ok = await widget.controller.openRepo(path);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.error ?? 'Failed to open repository')),
      );
    }
  }

  Animation<double> _fade(double begin, double end) {
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: AppTheme.proBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _ProAtmosphere()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 56 : 22,
                vertical: wide ? 36 : 24,
              ),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 6, child: _BrandBlock(fade: _fade(0.0, 0.55))),
                        const SizedBox(width: 40),
                        Expanded(
                          flex: 5,
                          child: FadeTransition(
                            opacity: _fade(0.25, 0.85),
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.06, 0),
                                end: Offset.zero,
                              ).animate(_fade(0.25, 0.85)),
                              child: _OpenPanel(
                                pathController: _pathController,
                                pathFocus: _pathFocus,
                                opening: _opening,
                                onBrowse: _browse,
                                onOpen: _open,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _BrandBlock(fade: _fade(0.0, 0.55))),
                        FadeTransition(
                          opacity: _fade(0.2, 0.9),
                          child: _OpenPanel(
                            pathController: _pathController,
                            pathFocus: _pathFocus,
                            opening: _opening,
                            onBrowse: _browse,
                            onOpen: _open,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.fade});

  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(fade),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Git Yar',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontFamily: 'Vazirmatn',
                        fontWeight: FontWeight.w900,
                        fontSize: 72,
                        height: 0.95,
                        letterSpacing: -2.5,
                        color: AppTheme.proText,
                      ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 56,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [AppTheme.proAccent, AppTheme.proAccent2],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'See every branch. Ship every change.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.proText.withValues(alpha: 0.92),
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Open a local repository to explore the commit graph, review diffs, resolve conflicts, and run reports.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.proMuted,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenPanel extends StatelessWidget {
  const _OpenPanel({
    required this.pathController,
    required this.pathFocus,
    required this.opening,
    required this.onBrowse,
    required this.onOpen,
  });

  final TextEditingController pathController;
  final FocusNode pathFocus;
  final bool opening;
  final VoidCallback onBrowse;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.proPanel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.proBorder.withValues(alpha: 0.95)),
            boxShadow: AppTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Open repository',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.proText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a local Git folder to continue.',
                  style: TextStyle(fontSize: 13, color: AppTheme.proMuted, height: 1.4),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: pathController,
                  focusNode: pathFocus,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: 'SourceCodePro',
                    fontSize: 13,
                    color: AppTheme.proText,
                  ),
                  decoration: InputDecoration(
                    hintText: '/home/user/Projects/my-repo',
                    hintStyle: TextStyle(
                      fontFamily: 'SourceCodePro',
                      color: AppTheme.proMuted.withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(Icons.folder_open_rounded, color: AppTheme.proAccent),
                    filled: true,
                    fillColor: AppTheme.proBg,
                  ),
                  onSubmitted: (_) => onOpen(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: opening ? null : onBrowse,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: AppTheme.proBorder),
                          foregroundColor: AppTheme.proText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Browse'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: opening ? null : onOpen,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppTheme.proAccent,
                          foregroundColor: const Color(0xFF06140F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: opening
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06140F)),
                              )
                            : const Text(
                                'Open',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Requires Git on PATH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.proMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProAtmosphere extends StatefulWidget {
  const _ProAtmosphere();

  @override
  State<_ProAtmosphere> createState() => _ProAtmosphereState();
}

class _ProAtmosphereState extends State<_ProAtmosphere> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 0.2, -1),
              end: Alignment(1, 1 - t * 0.15),
              colors: [
                AppTheme.proBg,
                Color.lerp(const Color(0xFF10151F), const Color(0xFF0D1A16), t)!,
                Color.lerp(const Color(0xFF0F1420), const Color(0xFF121A28), 1 - t)!,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Soft accent glows
              Positioned(
                left: -80,
                top: -40,
                child: _Glow(
                  size: 320,
                  color: AppTheme.proAccent.withValues(alpha: 0.10 + t * 0.04),
                ),
              ),
              Positioned(
                right: -60,
                bottom: -20,
                child: _Glow(
                  size: 280,
                  color: AppTheme.proAccent2.withValues(alpha: 0.10 + (1 - t) * 0.04),
                ),
              ),
              CustomPaint(
                painter: _GraphPainter(progress: t),
                child: const SizedBox.expand(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = AppTheme.graphColors;
    final shift = progress * 18;

    void branch({
      required double x0,
      required double y0,
      required double x1,
      required double y1,
      required Color color,
      double width = 2,
    }) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(x0, y0)
        ..cubicTo(
          x0 + (x1 - x0) * 0.35,
          y0 + shift * 0.2,
          x0 + (x1 - x0) * 0.65,
          y1 - shift * 0.15,
          x1,
          y1,
        );
      canvas.drawPath(path, paint);
      canvas.drawCircle(
        Offset(x1, y1),
        4.5,
        Paint()..color = color.withValues(alpha: 0.45),
      );
    }

    final baseX = size.width * 0.58;
    final baseY = size.height * 0.18;

    branch(
      x0: baseX,
      y0: baseY,
      x1: size.width * 0.78,
      y1: size.height * 0.42 + math.sin(progress * math.pi) * 8,
      color: colors[0],
      width: 2.4,
    );
    branch(
      x0: baseX,
      y0: baseY + 36,
      x1: size.width * 0.92,
      y1: size.height * 0.58,
      color: colors[1],
    );
    branch(
      x0: baseX + 10,
      y0: baseY + 72,
      x1: size.width * 0.86,
      y1: size.height * 0.74,
      color: colors[2],
      width: 1.8,
    );
    branch(
      x0: baseX - 8,
      y0: baseY + 110,
      x1: size.width * 0.7,
      y1: size.height * 0.88,
      color: colors[3],
      width: 1.6,
    );

    // Trunk
    final trunk = Paint()
      ..color = AppTheme.proAccent.withValues(alpha: 0.18)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(baseX, baseY - 10), Offset(baseX, size.height * 0.92), trunk);
    for (var i = 0; i < 6; i++) {
      final y = baseY + i * 48.0;
      canvas.drawCircle(
        Offset(baseX, y),
        5,
        Paint()..color = AppTheme.proAccent.withValues(alpha: 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => oldDelegate.progress != progress;
}

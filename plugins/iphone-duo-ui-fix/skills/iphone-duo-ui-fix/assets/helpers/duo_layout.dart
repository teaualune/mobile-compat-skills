import 'package:flutter/material.dart';

/// Confines [child] to a phone-width column on wide windows (iPhone Duo inner
/// display, iPad) while [background] — or the theme surface colour — fills the
/// whole window. On narrow windows it is a no-op.
///
/// Apply app-wide in `MaterialApp.builder` (every screen centered) or per
/// screen (adaptive screens stay full-width). Keep `SafeArea` inside the
/// column; let [background] ignore safe areas so it reaches the edges.
class DuoLayout extends StatelessWidget {
  const DuoLayout({
    super.key,
    required this.child,
    this.maxContentWidth = 480,
    this.background,
  });

  final Widget child;

  /// 466 is the outer display's width; 430–480 is the usual range.
  final double maxContentWidth;

  /// Non-interactive layer painted edge to edge: a gradient, an image with
  /// BoxFit.cover, or a plain ColoredBox. Must not contain buttons.
  final Widget? background;

  /// Material "medium" and up — where bottom bars become rails.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth <= maxContentWidth) return child;
      return Stack(
        fit: StackFit.expand,
        children: [
          background ?? ColoredBox(color: Theme.of(context).colorScheme.surface),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        ],
      );
    });
  }
}

// Notes:
// - A Scaffold inside the column paints its own backgroundColor over the column
//   area only. If the screen has a gradient/image, move it into `background:` and
//   make the inner Scaffold transparent (backgroundColor: Colors.transparent).
// - When applied in MaterialApp.builder, wrap `child` only, not the Navigator.

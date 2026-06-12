import 'package:flutter/material.dart';

/// A settings icon that rotates 360 degrees when pressed.
class AnimatedSettingsIcon extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const AnimatedSettingsIcon({
    super.key,
    this.onTap,
    this.color,
    this.size = 24.0,
  });

  @override
  State<AnimatedSettingsIcon> createState() => _AnimatedSettingsIconState();
}

class _AnimatedSettingsIconState extends State<AnimatedSettingsIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    _controller.forward(from: 0.0);
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onTap!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = widget.color ?? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A));

    return GestureDetector(
      onTap: _play,
      behavior: HitTestBehavior.opaque,
      child: RotationTransition(
        turns: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.settings_outlined,
            color: resolvedColor,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

/// A logout icon where the left bracket door closes over the arrow when tapped.
class AnimatedLogoutIcon extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const AnimatedLogoutIcon({
    super.key,
    this.onTap,
    this.color,
    this.size = 24.0,
  });

  @override
  State<AnimatedLogoutIcon> createState() => _AnimatedLogoutIconState();
}

class _AnimatedLogoutIconState extends State<AnimatedLogoutIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bracketOffsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bracketOffsetAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 6.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    _controller.forward(from: 0.0);
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onTap!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = widget.color ?? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A));

    return GestureDetector(
      onTap: _play,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedBuilder(
          animation: _bracketOffsetAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _LogoutIconPainter(
                color: resolvedColor,
                bracketOffset: _bracketOffsetAnimation.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LogoutIconPainter extends CustomPainter {
  final Color color;
  final double bracketOffset;

  _LogoutIconPainter({required this.color, required this.bracketOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double w = size.width;
    final double h = size.height;

    // Draw bracket [ translating to the right
    final double bx = (w * 0.15) + bracketOffset;
    final double bxEnd = bx + (w * 0.25);
    final double byTop = h * 0.15;
    final double byBottom = h * 0.85;

    // Vertical line
    canvas.drawLine(Offset(bx, byTop), Offset(bx, byBottom), paint);
    // Top line
    canvas.drawLine(Offset(bx, byTop), Offset(bxEnd, byTop), paint);
    // Bottom line
    canvas.drawLine(Offset(bx, byBottom), Offset(bxEnd, byBottom), paint);

    // Draw arrow pointing right
    final double axStart = w * 0.35;
    final double axEnd = w * 0.85;
    final double ayMid = h * 0.5;

    // Arrow line
    canvas.drawLine(Offset(axStart, ayMid), Offset(axEnd, ayMid), paint);
    // Arrow head
    canvas.drawLine(Offset(axEnd, ayMid), Offset(axEnd - w * 0.2, ayMid - h * 0.2), paint);
    // Arrow head bottom
    canvas.drawLine(Offset(axEnd, ayMid), Offset(axEnd - w * 0.2, ayMid + h * 0.2), paint);
  }

  @override
  bool shouldRepaint(covariant _LogoutIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.bracketOffset != bracketOffset;
  }
}

/// A followers icon where the two people bounce up/down staggered on tap.
class AnimatedFollowersIcon extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const AnimatedFollowersIcon({
    super.key,
    this.onTap,
    this.color,
    this.size = 24.0,
  });

  @override
  State<AnimatedFollowersIcon> createState() => _AnimatedFollowersIconState();
}

class _AnimatedFollowersIconState extends State<AnimatedFollowersIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _person1Y;
  late Animation<double> _person2Y;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Person 1 bounces up and down from t=0.0 to t=0.7
    _person1Y = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -6.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.linear),
      ),
    );

    // Person 2 bounces up and down from t=0.3 to t=1.0
    _person2Y = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -6.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.linear),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    _controller.forward(from: 0.0);
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onTap!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = widget.color ?? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A));

    return GestureDetector(
      onTap: _play,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SizedBox(
              width: widget.size + 8,
              height: widget.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Transform.translate(
                      offset: Offset(0, _person1Y.value),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: resolvedColor,
                        size: widget.size * 0.9,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Transform.translate(
                      offset: Offset(0, _person2Y.value),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: resolvedColor,
                        size: widget.size * 0.9,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A node-link share icon that folds in and expands out elastically.
class AnimatedShareIcon extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const AnimatedShareIcon({
    super.key,
    this.onTap,
    this.color,
    this.size = 24.0,
  });

  @override
  State<AnimatedShareIcon> createState() => _AnimatedShareIconState();
}

class _AnimatedShareIconState extends State<AnimatedShareIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _collapseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _collapseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.1).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    _controller.forward(from: 0.0);
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onTap!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = widget.color ?? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A));

    return GestureDetector(
      onTap: _play,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedBuilder(
          animation: _collapseAnimation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _ShareIconPainter(
                color: resolvedColor,
                progress: _collapseAnimation.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShareIconPainter extends CustomPainter {
  final Color color;
  final double progress; // 1.0 is fully expanded, 0.0 is fully collapsed

  _ShareIconPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Scale factor to make the share icon match standard icon sizes
    final double scale = 0.72;
    final double sw = w * scale;
    final double sh = h * scale;
    final double dx = (w - sw) / 2.0;
    final double dy = (h - sh) / 2.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Center node position (left side)
    final Offset center = Offset(dx + sw * 0.25, dy + sh * 0.5);

    // Top-right node position
    final Offset top = Offset(
      center.dx + (sw * 0.5) * progress,
      center.dy - (sh * 0.3) * progress,
    );

    // Bottom-right node position
    final Offset bottom = Offset(
      center.dx + (sw * 0.5) * progress,
      center.dy + (sh * 0.3) * progress,
    );

    // Draw connecting lines
    canvas.drawLine(center, top, paint);
    canvas.drawLine(center, bottom, paint);

    // Draw nodes
    final double radius = sw * 0.12;
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(top, radius, fillPaint);
    canvas.drawCircle(bottom, radius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ShareIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

/// A star icon that pops up and bounces down with scaling.
class AnimatedStarIcon extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final bool isFilled;

  const AnimatedStarIcon({
    super.key,
    this.onTap,
    this.color,
    this.size = 24.0,
    this.isFilled = false,
  });

  @override
  State<AnimatedStarIcon> createState() => _AnimatedStarIconState();
}

class _AnimatedStarIconState extends State<AnimatedStarIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _translateY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -8.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -8.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60.0,
      ),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    _controller.forward(from: 0.0);
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onTap!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = widget.color ?? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A));

    return GestureDetector(
      onTap: _play,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _translateY.value),
              child: Transform.scale(
                scale: _scale.value,
                child: Icon(
                  widget.isFilled ? Icons.star : Icons.star_border,
                  color: resolvedColor,
                  size: widget.size,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A pencil icon that wiggles from side to side using its tip as anchor.
class AnimatedPencilIcon extends StatefulWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const AnimatedPencilIcon({
    super.key,
    this.onTap,
    this.color,
    this.size = 24.0,
  });

  @override
  State<AnimatedPencilIcon> createState() => _AnimatedPencilIconState();
}

class _AnimatedPencilIconState extends State<AnimatedPencilIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _angleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _angleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.25).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.25, end: 0.25).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.25, end: -0.15).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    _controller.forward(from: 0.0);
    if (widget.onTap != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onTap!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedColor = widget.color ?? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A));

    return GestureDetector(
      onTap: _play,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedBuilder(
          animation: _angleAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _angleAnimation.value,
              alignment: Alignment.bottomLeft,
              child: Icon(
                Icons.edit_outlined,
                color: resolvedColor,
                size: widget.size,
              ),
            );
          },
        ),
      ),
    );
  }
}

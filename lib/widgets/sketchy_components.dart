import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom painter that draws a sketchy, hand-drawn border.
/// It draws two overlapping paths for each side of the rectangle,
/// adding slight wavy deviations and overshooting the corners.
class SketchyBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double overshoot;
  final double maxDeviation;
  final double borderRadius;

  SketchyBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.overshoot = 4.0,
    this.maxDeviation = 1.5,
    this.borderRadius = 12.0,
  });

  // A simple deterministic pseudo-random helper based on inputs
  double _getOffset(double length, int seed, double maxVal) {
    // Deterministic value between -maxVal and +maxVal
    final double hash = math.sin(length * 12.9898 + seed * 78.233) * 43758.5453;
    return (hash - hash.floor()) * 2.0 * maxVal - maxVal;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Define the four corners
    const tl = Offset(0, 0);
    final tr = Offset(w, 0);
    final br = Offset(w, h);
    final bl = Offset(0, h);

    // Draw sketchy line for each side
    _drawSketchyLine(canvas, tl, tr, paint, 1, w);
    _drawSketchyLine(canvas, tr, br, paint, 2, h);
    _drawSketchyLine(canvas, br, bl, paint, 3, w);
    _drawSketchyLine(canvas, bl, tl, paint, 4, h);
  }

  void _drawSketchyLine(Canvas canvas, Offset start, Offset end, Paint paint, int sideSeed, double length) {
    final dir = end - start;
    final dist = dir.distance;
    if (dist == 0) return;

    final unitDir = dir / dist;
    final normal = Offset(-unitDir.dy, unitDir.dx);

    // We draw two strokes for the hand-drawn overlap effect
    for (int stroke = 0; stroke < 2; stroke++) {
      final seed1 = sideSeed * 10 + stroke * 3;
      final seed2 = sideSeed * 20 + stroke * 7;
      final seed3 = sideSeed * 30 + stroke * 11;

      // Calculate overshoots and deviations
      final startOvershoot = overshoot + _getOffset(length, seed1, 2.0);
      final endOvershoot = overshoot + _getOffset(length, seed2, 2.0);
      final dev = maxDeviation + _getOffset(length, seed3, maxDeviation * 0.5);

      final lineStart = start - unitDir * startOvershoot;
      final lineEnd = end + unitDir * endOvershoot;

      // Draw a curve with a midpoint offset
      final midPoint = (lineStart + lineEnd) / 2.0;
      final controlOffset = normal * _getOffset(length, seed3 + 5, dev);
      final controlPoint = midPoint + controlOffset;

      final path = Path()
        ..moveTo(lineStart.dx, lineStart.dy)
        ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, lineEnd.dx, lineEnd.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SketchyBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.overshoot != overshoot ||
        oldDelegate.maxDeviation != maxDeviation ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// A container that applies a sketchy hand-drawn border and flat shadow.
class SketchyContainer extends StatelessWidget {
  final Widget child;
  final Color? fillColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double padding;
  final double? width;
  final double? height;
  final double shadowOffset;
  final Color shadowColor;
  final bool showShadow;
  final Clip clipBehavior;

  const SketchyContainer({
    super.key,
    required this.child,
    this.fillColor,
    this.borderColor = const Color(0xFF2D2B2A),
    this.borderWidth = 1.8,
    this.borderRadius = 12.0,
    this.padding = 16.0,
    this.width,
    this.height,
    this.shadowOffset = 4.0,
    this.shadowColor = const Color(0xFF2D2B2A),
    this.showShadow = true,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = fillColor ?? theme.cardTheme.color ?? Colors.white;
    final isDark = theme.brightness == Brightness.dark;
    
    final resolvedBorderColor = borderColor == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : borderColor;
        
    final resolvedShadowColor = shadowColor == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : shadowColor;

    Widget container = Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );

    // Overlay sketchy border and add flat shadow if requested
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Deterministic Flat Shadow
        if (showShadow)
          Positioned(
            left: shadowOffset,
            top: shadowOffset,
            right: -shadowOffset,
            bottom: -shadowOffset,
            child: Container(
              decoration: BoxDecoration(
                color: resolvedShadowColor,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
        
        // Main Container Card
        container,

        // Custom Sketchy Border Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SketchyBorderPainter(
                color: resolvedBorderColor,
                strokeWidth: borderWidth,
                borderRadius: borderRadius,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A button styled with a clean flat outline and solid shadow.
class SketchyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color? fillColor;
  final Color textColor;
  final Color borderColor;
  final double borderRadius;
  final double height;
  final bool showShadow;

  const SketchyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fillColor,
    this.textColor = const Color(0xFF2D2B2A),
    this.borderColor = const Color(0xFF2D2B2A),
    this.borderRadius = 12.0,
    this.height = 56.0,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final resolvedBorderColor = borderColor == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : borderColor;
        
    final resolvedTextColor = textColor == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : textColor;

    final bg = fillColor ?? (isDark ? theme.cardTheme.color ?? const Color(0xFF2E2A29) : Colors.white);
    final isEnabled = onPressed != null;

    return ScaleOnTap(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Flat blocked shadow
          if (showShadow && isEnabled)
            Positioned(
              left: 3.0,
              top: 3.0,
              right: -3.0,
              bottom: -3.0,
              child: Container(
                decoration: BoxDecoration(
                  color: resolvedBorderColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
            ),
          
          // Clean Button Card
          Container(
            height: height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: resolvedBorderColor, width: 1.5),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      IconTheme(
                        data: IconThemeData(color: resolvedTextColor),
                        child: icon!,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: resolvedTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A square icon button with a clean border (e.g. Back Arrow).
class SketchyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color color;
  final Color borderColor;
  final double borderRadius;

  const SketchyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48.0,
    this.color = const Color(0xFF2D2B2A),
    this.borderColor = const Color(0xFF2D2B2A),
    this.borderRadius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final resolvedBorderColor = borderColor == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : borderColor;
        
    final resolvedIconColor = color == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : color;

    final bg = isDark ? theme.cardTheme.color ?? const Color(0xFF2E2A29) : Colors.white;

    return ScaleOnTap(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Flat Shadow
          Positioned(
            left: 2.5,
            top: 2.5,
            right: -2.5,
            bottom: -2.5,
            child: Container(
              decoration: BoxDecoration(
                color: resolvedBorderColor,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
          
          // Button Card
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: resolvedBorderColor, width: 1.5),
            ),
            child: Center(
              child: Icon(
                icon,
                color: resolvedIconColor,
                size: size * 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A standard Back Button styled sketchily.
class SketchyBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const SketchyBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SketchyIconButton(
      icon: Icons.arrow_back,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      size: 44.0,
    );
  }
}

/// A custom Radio-style selection item card.
class SketchyRadioButton extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;
  final Color borderColor;

  const SketchyRadioButton({
    super.key,
    required this.selected,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onTap,
    this.selectedColor = const Color(0xFFFFF1DC),
    this.unselectedColor = Colors.white,
    this.borderColor = const Color(0xFF2D2B2A),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final resolvedBorderColor = borderColor == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : borderColor;

    final bgSelected = selectedColor == const Color(0xFFFFF1DC)
        ? (isDark ? theme.primaryColor.withOpacity(0.2) : const Color(0xFFFFF1DC))
        : selectedColor;
        
    final bgUnselected = unselectedColor == Colors.white
        ? (isDark ? theme.cardTheme.color ?? const Color(0xFF2E2A29) : Colors.white)
        : unselectedColor;

    return ScaleOnTap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Flat block shadow if selected
          if (selected)
            Positioned(
              left: 2.0,
              top: 2.0,
              right: -2.0,
              bottom: -2.0,
              child: Container(
                decoration: BoxDecoration(
                  color: resolvedBorderColor,
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          
          // Main Option Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: selected ? bgSelected : bgUnselected,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: selected ? resolvedBorderColor : resolvedBorderColor.withOpacity(0.2),
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Custom radio circle
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? theme.primaryColor : resolvedBorderColor.withOpacity(0.3),
                      width: 2.0,
                    ),
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primaryColor,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A)).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A Form TextField wrapped in a SketchyContainer.
class SketchyTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const SketchyTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final textColor = isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A);
    final hintColor = isDark ? const Color(0xFFEFEBE9).withOpacity(0.5) : const Color(0xFF2D2B2A).withOpacity(0.5);
    final borderColor = isDark ? const Color(0xFFEFEBE9).withOpacity(0.35) : const Color(0xFF2D2B2A).withOpacity(0.35);
    final bg = isDark ? theme.cardTheme.color ?? const Color(0xFF2E2A29) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            onChanged: onChanged,
            validator: validator,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: hintColor),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ],
    );
  }
}

/// An image or picture frame with double sketchy borders.
class SketchyImageFrame extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final Color borderColor;
  final double shadowOffset;

  const SketchyImageFrame({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.borderWidth = 1.8,
    this.borderColor = const Color(0xFF2D2B2A),
    this.shadowOffset = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final resolvedBorderColor = borderColor == const Color(0xFF2D2B2A)
        ? (isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A))
        : borderColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Inner sketchy outline offset slightly to make a beautiful double outline
        Positioned(
          left: -2,
          top: -2,
          right: -2,
          bottom: -2,
          child: IgnorePointer(
            child: CustomPaint(
              painter: SketchyBorderPainter(
                color: resolvedBorderColor.withOpacity(0.4),
                strokeWidth: borderWidth * 0.8,
                borderRadius: borderRadius,
                overshoot: 2.0,
                maxDeviation: 1.0,
              ),
            ),
          ),
        ),

        // Main Image/Widget framed
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: child,
        ),

        // Outer sketchy outline overlay
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SketchyBorderPainter(
                color: resolvedBorderColor,
                strokeWidth: borderWidth,
                borderRadius: borderRadius,
                overshoot: 5.0,
                maxDeviation: 2.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A wrapper widget that scales its child down slightly when pressed.
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const ScaleOnTap({super.key, required this.child, this.onTap});

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null || _isAnimating) return;
    setState(() {
      _isAnimating = true;
    });

    // Animate to pressed state
    await _controller.forward();

    // Hold the pressed state for 200ms
    await Future.delayed(const Duration(milliseconds: 200));

    // Animate back to original scale
    if (mounted) {
      await _controller.reverse();
    }

    if (mounted) {
      setState(() {
        _isAnimating = false;
      });
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: isEnabled && !_isAnimating ? (_) => _controller.forward() : null,
      onTapCancel: isEnabled && !_isAnimating ? () => _controller.reverse() : null,
      onTap: isEnabled && !_isAnimating ? _handleTap : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// A custom PageRoute that applies a premium scale and fade transition.
class SketchyPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SketchyPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              ),
            );
            final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeIn,
              ),
            );
            return FadeTransition(
              opacity: opacityAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

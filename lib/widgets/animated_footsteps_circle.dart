import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AnimatedFootstepsCircle extends StatefulWidget {
  final double size;
  final bool showCircle;

  const AnimatedFootstepsCircle({
    super.key,
    this.size = 120,
    this.showCircle = true,
  });

  @override
  State<AnimatedFootstepsCircle> createState() =>
      _AnimatedFootstepsCircleState();
}

class _AnimatedFootstepsCircleState extends State<AnimatedFootstepsCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _leftFootAnimation;
  late Animation<double> _rightFootAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _leftFootAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    ));

    _rightFootAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.2), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final footstepColor = theme.primaryColor;

    final footstepsStack = Stack(
      children: [
        FadeTransition(
          opacity: _leftFootAnimation,
          child: SvgPicture.asset(
            'assets/images/logo_left_foot.svg',
            colorFilter: ColorFilter.mode(footstepColor, BlendMode.srcIn),
          ),
        ),
        FadeTransition(
          opacity: _rightFootAnimation,
          child: SvgPicture.asset(
            'assets/images/logo_right_foot.svg',
            colorFilter: ColorFilter.mode(footstepColor, BlendMode.srcIn),
          ),
        ),
      ],
    );

    if (!widget.showCircle) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: footstepsStack,
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.cardTheme.color
            : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFFEFEBE9).withOpacity(0.15)
              : theme.primaryColor.withOpacity(0.15),
          width: 2,
        ),
      ),
      padding: EdgeInsets.all(widget.size * 0.15),
      child: footstepsStack,
    );
  }
}

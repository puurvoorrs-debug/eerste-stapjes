import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../providers/locale_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
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
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)));

    _rightFootAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.2), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 200,
                child: Stack(
                  children: <Widget>[
                    FadeTransition(
                      opacity: _leftFootAnimation,
                      child: SvgPicture.asset(
                        'assets/images/logo_left_foot.svg',
                        height: 200,
                        colorFilter: ColorFilter.mode(theme.primaryColor, BlendMode.srcIn),
                      ),
                    ),
                    FadeTransition(
                      opacity: _rightFootAnimation,
                      child: SvgPicture.asset(
                        'assets/images/logo_right_foot.svg',
                        height: 200,
                        colorFilter: ColorFilter.mode(theme.primaryColor, BlendMode.srcIn),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('Eerste stapjes', 'First steps'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  fontFamily: 'Pacifico',
                  color: theme.primaryColor
                  ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('Elke dag een stapje verder.', 'Small steps, everyday.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                icon: Image.asset('assets/google_logo.png', height: 24.0),
                label: Text(context.tr('Login met Google', 'Login with Google'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  try {
                    await authService.signInWithGoogle();
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text(context.tr('Fout bij inloggen: $e', 'Error signing in: $e'))),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../providers/locale_provider.dart';
import '../widgets/sketchy_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large Brand Logo in Orange
                SvgPicture.asset(
                  'assets/images/Eerste stapjes - Logo nieuw oranje.svg',
                  height: 120,
                  colorFilter: const ColorFilter.mode(Color(0xFFF38B4B), BlendMode.srcIn),
                ),
                const SizedBox(height: 48),

                SketchyContainer(
                  fillColor: Colors.white,
                  borderColor: const Color(0xFF2D2B2A),
                  borderRadius: 16.0,
                  padding: 24.0,
                  showShadow: false,
                  shadowOffset: 5.0,
                  child: Column(
                    children: [
                      Text(
                        context.tr(
                          'Log in of maak een account aan om door te gaan',
                          'Log in or create an account to continue',
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D2B2A),
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (_isSigningIn)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(),
                        )
                      else
                        // Sketchy Google Login Button
                        SketchyButton(
                          label: context.tr('Doorgaan met Google', 'Continue with Google'),
                          fillColor: Colors.white,
                          borderColor: const Color(0xFF2D2B2A),
                          textColor: const Color(0xFF2D2B2A),
                          icon: Image.asset('assets/google_logo.png', height: 24.0),
                          onPressed: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            setState(() => _isSigningIn = true);
                            try {
                              await authService.signInWithGoogle();
                            } catch (e) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.tr(
                                        'Fout bij inloggen: $e',
                                        'Error signing in: $e',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isSigningIn = false);
                              }
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Bottom Terms of Service text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    context.tr(
                      'Door door te gaan, ga je akkoord met onze algemene voorwaarden en privacybeleid',
                      'By continuing, you agree to our terms of service and privacy policy',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF2D2B2A).withOpacity(0.6),
                      height: 1.5,
                    ),
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

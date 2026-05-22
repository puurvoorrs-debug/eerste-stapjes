import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/profile_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Achtergrondbericht afgehandeld: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Background handler zo vroeg mogelijk registreren
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await initializeDateFormatting('nl_NL', null);

  final pushNotificationService = PushNotificationService(navigatorKey);

  runApp(MyApp(navigatorKey: navigatorKey));

  // initialize() MOET na runApp() zodat navigatorKey.currentState niet null is
  // wanneer getInitialMessage() de navigatie probeert uit te voeren bij een
  // koude app-start via een push-notificatie.
  await pushNotificationService.initialize();
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Eerste stapjes',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final user = authSnapshot.data!;
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            FirebaseFirestore.instance
                .collection('profiles')
                .where(Filter.or(
                  Filter('ownerId', isEqualTo: user.uid),
                  Filter('followers', arrayContains: user.uid),
                ))
                .limit(1)
                .get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (snapshot.hasData) {
              final userDoc = snapshot.data![0] as DocumentSnapshot;
              final profilesQuery = snapshot.data![1] as QuerySnapshot;

              final data = userDoc.data() as Map<String, dynamic>?;
              final onboardingCompleted = data != null && data['onboardingCompleted'] == true;
              final hasProfiles = profilesQuery.docs.isNotEmpty;

              if (onboardingCompleted || hasProfiles) {
                return const ProfileSelectionScreen();
              }
            }
            return const OnboardingScreen();
          },
        );
      },
    );
  }
}

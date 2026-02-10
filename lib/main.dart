import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_account_screen.dart'; // Import het nieuwe scherm
import 'providers/theme_provider.dart';
import 'providers/profile_provider.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('nl_NL', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            title: 'Moment-Opname',
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          // Gebruiker is ingelogd, check nu of hun profiel bestaat
          return UserProfileCheck(user: snapshot.data!);
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// Nieuwe widget om het gebruikersprofiel te checken
class UserProfileCheck extends StatelessWidget {
  final User user;
  const UserProfileCheck({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        // Terwijl we wachten op de data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Als de snapshot data heeft en het document bestaat, ga naar het profielselectiescherm
        if (snapshot.hasData && snapshot.data!.exists) {
          return const ProfileSelectionScreen();
        } else {
          // Anders, ga naar het scherm om een account aan te maken
          return const CreateAccountScreen();
        }
      },
    );
  }
}

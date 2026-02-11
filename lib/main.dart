import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_account_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/profile_provider.dart';
import 'theme.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

// Initialize notifications
Future<void> initNotifications() async {
  final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  // Request permissions
  NotificationSettings settings = await firebaseMessaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  // Get FCM token and save it to Firestore
  final String? token = await firebaseMessaging.getToken();
  print("Firebase Messaging Token: $token");

  // Save the token to the user's document in Firestore when the user is logged in
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null && token != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  });


  // Initialize flutter_local_notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Create a high importance channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {

      final int id = notification.hashCode;
      final String? title = notification.title;
      final String? body = notification.body;

      final NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
        ),
      );

      if (title != null && body != null) {
        flutterLocalNotificationsPlugin.show(
          id,
          title,
          body,
          notificationDetails,
        );
      }
    }
  });

  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initNotifications(); // Initialize notifications
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

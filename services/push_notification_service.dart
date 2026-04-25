import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/daily_entry_detail_screen.dart';

class PushNotificationService {
  final GlobalKey<NavigatorState> navigatorKey;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  PushNotificationService(this.navigatorKey);

  Future<void> initialize() async {
    await _requestPermissions();
    await _setupForegroundNotifications();

    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message, appWasClosed: true);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    await saveTokenForCurrentUser();
  }

  void _handleMessage(RemoteMessage message, {bool appWasClosed = false}) {
    developer.log(
        'Bericht afgehandeld (app gesloten: $appWasClosed): ${message.data}');

    final type = message.data['type'];
    final entryId = message.data['entryId'];
    final ownerId = message.data['ownerId'];

    if (entryId != null && ownerId != null) {
      // Wacht tot de eerste frame is getekend voordat we navigeren
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DailyEntryDetailScreen(
              entryId: entryId,
              ownerId: ownerId,
            ),
          ),
        );
      });
    }
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    developer
        .log('Gebruiker heeft toestemming verleend: ${settings.authorizationStatus}');
  }

  Future<void> _setupForegroundNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'Hoge Prioriteit Notificaties', // titel
      description: 'Dit kanaal wordt gebruikt voor belangrijke notificaties.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const InitializationSettings initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Hier kunnen we de payload van de lokale notificatie afhandelen indien nodig
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Bericht ontvangen terwijl de app op de voorgrond is!');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data.toString(), // Stuur de data mee als payload
        );
      }
    });
  }

  Future<void> saveTokenForCurrentUser() async {
    String? token = await _fcm.getToken();
    developer.log("FCM Token: $token");

    if (token == null) return;

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        developer.log("FCM token opslaan voor gebruiker: ${user.uid}");
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    });
  }
}

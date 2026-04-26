import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/profile.dart';
import '../screens/daily_entry_detail_screen.dart';
import '../screens/followers_screen.dart';

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

    _handleMessageData(message.data);
  }

  void _handleMessageData(Map<String, dynamic> data) {
    final type = data['type'];
    final profileId = data['profileId'] as String?;
    final entryId = data['entryId'] as String?;

    // Volgverzoek notificatie → ga naar de FollowersScreen van het profiel
    if (type == 'follow_request' && profileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('profiles')
              .doc(profileId)
              .get();
          if (doc.exists) {
            final profile = Profile.fromMap(
                doc.data() as Map<String, dynamic>, doc.id);
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => FollowersScreen(profile: profile),
              ),
            );
          }
        } catch (e) {
          developer.log('Fout bij navigeren naar FollowersScreen: $e');
        }
      });
      return;
    }

    // Foto/reactie/like notificatie → ga naar DailyEntryDetailScreen
    if (entryId != null && profileId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DailyEntryDetailScreen(
              entryId: entryId,
              profileId: profileId,
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
      if (response.payload != null) {
        try {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          _handleMessageData(data);
        } catch (e) {
          developer.log('Fout bij het parsen van notificatie payload: $e');
        }
      }
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
          payload: jsonEncode(message.data), // Stuur de data mee als JSON payload
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

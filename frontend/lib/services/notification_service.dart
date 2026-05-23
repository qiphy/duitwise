import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../supabase_service.dart';
import '../screens/quest_screen.dart'; 

// Top-level background message handler execution block (Must be top-level static)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message target ID: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Store a global navigator reference to deep-link straight to your video quests
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> initializeNotificationPipeline(BuildContext context, GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;

    // 1. Request OS permission gates (Crucial for iOS & Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted push notification routing clearance.');
    }

    // 2. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Setup Local Foreground Notifications configurations Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'duitwise_high_importance_channel', 
      'High Importance Missions',
      description: 'Used for dynamic real-time chore alerts and payout milestones.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    // 🛠️ FIXED HERE: Changed 'settings:' to 'initializationSettings:'
    await _localNotifications.initialize(settings: initSettings);

    // 4. Stream Listener Layer: Handle alerts when the app is active in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id, 
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
            ),
          ),
        );
      }
    });

    // ⚡ Handle tap interaction when the app is alive in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationPayloadRouting(message.data);
    });

    // ⚡ Handle tap interaction when the app was completely dead/terminated
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationPayloadRouting(initialMessage.data);
      });
    }

    // 5. Synchronize unique hardware token right up to your Supabase vault records
    await uploadDevicePushToken();
  }

  // 🛠️ DETERMINISTIC ROUTE INTERCEPTOR
  void _handleNotificationPayloadRouting(Map<String, dynamic> data) {
    debugPrint("Parsing Push Payload Metadata parameters: $data");

    if (data['click_action'] == 'launch_quest') {
      final currentContext = navigatorKey?.currentContext;
      if (currentContext != null) {
        
        Future.microtask(() {
          showInteractiveQuestPopup(
            currentContext,
            onQuestCompleted: () {
              debugPrint("Video Quest completed via push interaction path.");
            },
          );
        });

      }
    }
  }

  Future<void> uploadDevicePushToken() async {
    final String? userId = supabaseService.currentUserId;
    if (userId == null) return;

    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('🚀 MY_TEST_FCM_TOKEN: $token');

        await supabaseService.client.from('user_tokens').upsert({
          'user_id': userId,
          'fcm_token': token,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'fcm_token');
        debugPrint('FCM Token synchronized to Supabase successfully.');
      }
    } catch (e) {
      debugPrint('Push pipeline sync failure context metric tracking error: $e');
    }
  }
}
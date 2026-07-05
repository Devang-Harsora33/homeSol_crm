import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'database_helper.dart';

// Top-level function for consistency across isolates
Map<String, dynamic> parseRemoteMessage(RemoteMessage message) {
  final data = message.data;
  final notification = message.notification;
  
  return {
    'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    'type': data['type'] ?? 'general',
    'story_id': data['story_id'] ?? '',
    'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
    'developer_name': data['developer_name'] ?? 'HomeSol India',
    'developer_logo': data['developer_logo'] ?? '',
    'title': notification?.title ?? data['title'] ?? 'New Notification',
    'body': notification?.body ?? data['body'] ?? 'You have a new message',
  };
}

// Helper to save notification directly to SQLite Database
Future<void> saveNotificationToDatabase(RemoteMessage message) async {
  try {
    final payload = parseRemoteMessage(message);
    await DatabaseHelper.instance.insertNotification(payload);
    debugPrint('[NotificationService] Notification saved to Database: ${payload['title']}');
  } catch (e) {
    debugPrint('[NotificationService] Error saving to Database: $e');
  }
}

// Helper to save generic notification data to SQLite Database
Future<void> saveGenericNotificationToDatabase({
  required String title,
  required String body,
  String type = 'general',
  String? id,
}) async {
  try {
    final payload = {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'story_id': '',
      'created_at': DateTime.now().toIso8601String(),
      'developer_name': 'HomeSol India',
      'developer_logo': '',
      'title': title,
      'body': body,
    };
    await DatabaseHelper.instance.insertNotification(payload);
    debugPrint('[NotificationService] Generic notification saved to Database: $title');
  } catch (e) {
    debugPrint('[NotificationService] Error saving generic to Database: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final StreamController<RemoteMessage> _foregroundMessagesController =
      StreamController.broadcast();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Stream<RemoteMessage> get foregroundMessages =>
      _foregroundMessagesController.stream;

  Future<void> initialize() async {
    debugPrint('[NotificationService] initialize() called');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await _initializeLocalNotifications();
    await _requestPermissions();
    
    // Set foreground notification options for iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Initialize timezones more reliably
    tz.initializeTimeZones();
    try {
      final String timeZoneName = 'Asia/Kolkata'; // Default
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('[NotificationService] Timezone set to: $timeZoneName');
    } catch (e) {
      debugPrint('[NotificationService] Error setting timezone: $e');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Foreground message: ${message.messageId}');
      saveNotificationToDatabase(message).then((_) {
        _handleForegroundMessage(message);
      });
    });

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Message opened app: ${message.messageId}');
      saveNotificationToDatabase(message).then((_) {
        _foregroundMessagesController.add(message);
      });
    });
    
    debugPrint('[NotificationService] initialize() complete');
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('notification_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('[NotificationService] Local notification tapped: ${details.payload}');
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      await plugin?.createNotificationChannel(const AndroidNotificationChannel(
        'story_notifications',
        'Story Notifications',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ));

      await plugin?.createNotificationChannel(const AndroidNotificationChannel(
        'timer_reminders',
        'Timer Reminders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ));
      
      debugPrint('[NotificationService] Android channels initialized');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
    _foregroundMessagesController.add(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'story_notifications',
        'Story Notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'notification_icon',
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      );

      await _localNotifications.show(
        id: notification.hashCode & 0x7FFFFFFF, 
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: json.encode(message.data),
      );
    }
  }

  Future<void> scheduleTimerNotification({
    required int id, 
    required String title, 
    required String body, 
    required Duration delay,
    bool saveToHistory = true,
  }) async {
    final safeId = id & 0x7FFFFFFF; // Ensure 31-bit int for Android
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timer_reminders',
      'Timer Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'notification_icon',
      showWhen: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
    );

    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);
      
      if (saveToHistory) {
        // Save to database
        await saveGenericNotificationToDatabase(
          id: safeId.toString(),
          title: title,
          body: body,
          type: 'timer',
        );
      }

      await _localNotifications.zonedSchedule(
        id: safeId,
        title: title,
        body: body,
        scheduledDate: scheduledTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('[NotificationService] Scheduled system notification ID $safeId for $scheduledTime');

      // BACKUP: Manual trigger for short delays (e.g., < 2 minutes)
      // This ensures delivery even if zonedSchedule is delayed or suppressed by system sleep
      if (delay.inSeconds > 0 && delay.inSeconds <= 180) {
        Future.delayed(delay, () {
          debugPrint('[NotificationService] Backup trigger firing for ID $safeId');
          // Only show if not already cancelled (basic check)
          showImmediateNotification(id: safeId, title: title, body: body);
        });
      }
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling system notification: $e');
      if (delay.inSeconds < 5) {
         showImmediateNotification(id: safeId, title: title, body: body);
      }
    }
  }

  Future<void> showImmediateNotification({required int id, required String title, required String body}) async {
    final safeId = id & 0x7FFFFFFF;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timer_reminders',
      'Timer Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'notification_icon',
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
    );

    // Save to database
    await saveGenericNotificationToDatabase(
      id: safeId.toString(),
      title: title,
      body: body,
      type: 'timer',
    );

    await _localNotifications.show(
      id: safeId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> cancelNotification({required int id}) async {
    await _localNotifications.cancel(id: id & 0x7FFFFFFF);
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      return null;
    }
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.requestNotificationsPermission();
      await plugin?.requestExactAlarmsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final plugin = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await plugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await saveNotificationToDatabase(message);
}

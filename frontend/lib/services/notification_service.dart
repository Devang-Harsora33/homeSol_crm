import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

    await _requestPermissions();
    await _initializeLocalNotifications();
    tz.initializeTimeZones();
    debugPrint('[NotificationService] initialize() complete');

    // Handle foreground messages (when app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Handle background messages (when app is in background/closed)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _foregroundMessagesController.add(message);
    });
  }

  Future<void> _initializeLocalNotifications() async {
    debugPrint('[NotificationService] _initializeLocalNotifications() called');
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    final bool? result = await _localNotifications.initialize(
      settings: initializationSettings,
    );
    debugPrint('[NotificationService] _initializeLocalNotifications() result=$result');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification when app is in foreground
    _showLocalNotification(message);
    _foregroundMessagesController.add(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'story_notifications',
            'Story Notifications',
            channelDescription: 'Notifications for new stories from developers',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            icon: 'ic_homesol_notification', // HomeSol logo as small icon
            largeIcon: const DrawableResourceAndroidBitmap('@drawable/logo'),
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: platformChannelSpecifics,
        payload: data.toString(),
      );
    }
  }

  Future<void> scheduleTimerNotification(int id, String title, String body, Duration delay) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'timer_reminders',
      'Timer Reminders',
      channelDescription: 'Notifications for ongoing meeting timers',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: 'ic_homesol_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/logo'),
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    debugPrint('[NotificationService] scheduleTimerNotification called: id=$id, delay=${delay.inSeconds}s');
    try {
      final scheduledTime = tz.TZDateTime.now(tz.UTC).add(delay);
      debugPrint('[NotificationService] Scheduling at UTC: $scheduledTime');
      await _localNotifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTime,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('[NotificationService] Notification scheduled successfully! id=$id');
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] ERROR scheduling notification: $e');
      debugPrint('[NotificationService] StackTrace: $stackTrace');
    }
  }

  Future<void> showImmediateNotification(int id, String title, String body) async {
    debugPrint('[NotificationService] showImmediateNotification called: id=$id');
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'timer_reminders',
        'Timer Reminders',
        channelDescription: 'Notifications for ongoing meeting timers',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_homesol_notification',
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      debugPrint('[NotificationService] showImmediateNotification delivered! id=$id');
    } catch (e) {
      debugPrint('[NotificationService] ERROR showing immediate notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id: id);
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  // Handle your backend's notification payload structure
  Map<String, dynamic> parseNotificationPayload(RemoteMessage message) {
    final data = message.data;
    return {
      'type': data['type'] ?? 'story',
      'story_id': data['story_id'] ?? '',
      'created_at': data['created_at'] ?? '',
      'developer_name': data['developer_name'] ?? 'Developer',
      'developer_logo': data['developer_logo'] ?? '',
      'title': message.notification?.title ?? 'New Story',
      'body': message.notification?.body ?? 'A new story has been uploaded',
    };
  }

  void dispose() {
    _foregroundMessagesController.close();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

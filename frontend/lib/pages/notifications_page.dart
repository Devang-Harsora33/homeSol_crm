import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../components/notification_card.dart';
import '../../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Map<String, dynamic>> _notifications = [];
  late StreamSubscription<RemoteMessage> _notificationSubscription;
  static const String _notificationsKey = 'saved_notifications';

  @override
  void initState() {
    super.initState();
    _loadSavedNotifications();
    _setupNotificationListener();
    _checkForInitialMessage();
  }

  Future<void> _checkForInitialMessage() async {
    // Check if app was opened from a notification
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      final payload = NotificationService.instance.parseNotificationPayload(
        initialMessage,
      );
      setState(() {
        _notifications.insert(0, payload);
      });
      await _saveNotifications();
    }
  }

  Future<void> _loadSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedNotifications = prefs.getString(_notificationsKey);
      if (savedNotifications != null) {
        final List<dynamic> decoded = json.decode(savedNotifications);
        setState(() {
          _notifications.clear();
          _notifications.addAll(decoded.cast<Map<String, dynamic>>());
        });
      }
    } catch (e) {
      print('Error loading saved notifications: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationsKey, json.encode(_notifications));
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  void _setupNotificationListener() {
    _notificationSubscription = NotificationService.instance.foregroundMessages
        .listen((RemoteMessage message) {
          final payload = NotificationService.instance.parseNotificationPayload(
            message,
          );
          setState(() {
            _notifications.insert(0, payload);
          });
          _saveNotifications(); // Save to persistent storage
        });
  }

  @override
  void dispose() {
    _notificationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () async {
                setState(() {
                  _notifications.clear();
                });
                await _saveNotifications(); // Clear from storage too
              },
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You\'ll see new story notifications here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return NotificationCard(
                  title: notification['title'] ?? 'New Story',
                  body: notification['body'] ?? 'A new story has been uploaded',
                  developerName: notification['developer_name'] ?? 'Developer',
                  developerLogo: notification['developer_logo'],
                  createdAt:
                      notification['created_at'] ??
                      DateTime.now().toIso8601String(),
                  onTap: () {
                    // Navigate to story detail or developer page
                    _handleNotificationTap(notification);
                  },
                );
              },
            ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Handle notification tap - navigate to relevant page
    final storyId = notification['story_id'];
    final developerName = notification['developer_name'];

    if (storyId != null && storyId.isNotEmpty) {
      // Navigate to story detail
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening story: $storyId'),
          backgroundColor: const Color(0xFFddbe6c),
        ),
      );
    } else {
      // Navigate to developer page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening developer: $developerName'),
          backgroundColor: const Color(0xFFddbe6c),
        ),
      );
    }
  }
}

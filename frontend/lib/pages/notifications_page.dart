import 'package:flutter/material.dart';
import '../../services/notification_manager.dart';
import '../../components/notification_card.dart';
import '../../utils/custom_snackbar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Force a fresh load from storage
    NotificationManager.instance.refresh();
    // Mark all as read when entering the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationManager.instance.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await NotificationManager.instance.refresh();
        },
        child: AnimatedBuilder(
          animation: NotificationManager.instance,
          builder: (context, _) {
            final notifications = NotificationManager.instance.notifications;
            
            if (notifications.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  _buildEmptyState(context),
                ],
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key('notification_${notification['id']}_${notification['created_at']}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    NotificationManager.instance.removeNotification(index);
                  },
                  child: NotificationCard(
                    title: notification['title'] ?? 'New Notification',
                    body: notification['body'] ?? '',
                    developerName: notification['developer_name'] ?? 'HomeSol',
                    developerLogo: notification['developer_logo'],
                    createdAt: notification['created_at'] ?? DateTime.now().toIso8601String(),
                    onTap: () => _handleNotificationTap(context, notification),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any new notifications.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              NotificationManager.instance.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) {
    final storyId = notification['story_id'];
    final developerName = notification['developer_name'];

    if (storyId != null && storyId.isNotEmpty) {
       CustomSnackBar.show(context, message: 'Opening story details...', isError: false, title: 'Notice');
    } else {
       CustomSnackBar.show(context, message: 'Opening developer: $developerName', isError: false, title: 'Notice');
    }
  }
}

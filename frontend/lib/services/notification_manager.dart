import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'database_helper.dart';
import 'databases/lead_database.dart';
import 'databases/site_visit_database.dart';
import 'databases/follow_up_database.dart';
import 'databases/sourcing_database.dart';
import 'package:intl/intl.dart';

class NotificationManager extends ChangeNotifier with WidgetsBindingObserver {
  NotificationManager._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final NotificationManager instance = NotificationManager._();

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  Future<void> refresh() async {
    debugPrint('[NotificationManager] Refreshing from Database...');
    await _loadFromDatabase();
    checkMilestones(); // Also check milestones on refresh
  }

  Future<void> initialize() async {
    debugPrint('[NotificationManager] Initializing...');
    await _loadFromDatabase();
    
    // Listen for new foreground/tapped messages
    NotificationService.instance.foregroundMessages.listen((RemoteMessage message) {
      debugPrint('[NotificationManager] Message received in stream: ${message.messageId}');
      // Data is already saved to DB by NotificationService, just reload
      _loadFromDatabase();
      checkMilestones(); // Check if this new activity completed a milestone
    });

    // Check for neglected leads (retention nudge)
    checkNeglectedLeads();

    // Schedule daily morning briefing
    scheduleMorningBriefing();

    // Check for weekly milestones
    checkMilestones();
    
    debugPrint('[NotificationManager] Ready. Unread count: $_unreadCount');
  }

  Future<void> checkMilestones() async {
    try {
      final now = DateTime.now();
      // Find start of current week (Monday)
      final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final monday = DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day);
      
      // We use year and week number for the key
      final String weekKey = '${now.year}_${_getWeekNumber(now)}';
      
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Check Site Visit Milestone (10)
      final visitMilestoneKey = 'milestone_visit_10_$weekKey';
      if (!(prefs.getBool(visitMilestoneKey) ?? false)) {
        final siteVisits = await SiteVisitDatabase.getAllSiteVisits();
        final weeklyCompletedVisits = siteVisits.where((v) {
          if (v.status != 'Visit Done' && v.status != 'Revisit Done') return false;
          final modified = DateTime.tryParse(v.modified ?? '');
          return modified != null && modified.isAfter(monday);
        }).length;

        if (weeklyCompletedVisits >= 10) {
          NotificationService.instance.showImmediateNotification(
            id: 888,
            title: 'Milestone Reached! 🏆',
            body: 'Great job! That\'s your 10th site visit this week. Keep up the momentum! 🚀',
          );
          await prefs.setBool(visitMilestoneKey, true);
          await _loadFromDatabase(); // History updated by showImmediateNotification
        }
      }

      // 2. Check Sourcing Milestone (5)
      final sourcingMilestoneKey = 'milestone_sourcing_5_$weekKey';
      if (!(prefs.getBool(sourcingMilestoneKey) ?? false)) {
        final sourcingRecords = await SourcingDatabase().getAllSourcing();
        final weeklySourcingMeetings = sourcingRecords.where((s) {
          final data = json.decode(s['data']);
          final modifiedStr = data['modified']?.toString();
          if (modifiedStr == null) return false;
          final modified = DateTime.tryParse(modifiedStr.replaceAll(' ', 'T'));
          return modified != null && modified.isAfter(monday);
        }).length;

        if (weeklySourcingMeetings >= 5) {
          NotificationService.instance.showImmediateNotification(
            id: 889,
            title: 'Sourcing Milestone! 🌟',
            body: 'Excellent! You\'ve completed 5 sourcing meetings this week. Outstanding effort! 🚀',
          );
          await prefs.setBool(sourcingMilestoneKey, true);
          await _loadFromDatabase(); // History updated by showImmediateNotification
        }
      }
    } catch (e) {
      debugPrint('[NotificationManager] Error checking milestones: $e');
    }
  }

  // ISO 8601 week number
  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Future<void> scheduleMorningBriefing() async {
    try {
      final now = DateTime.now();
      
      // Determine target date for briefing
      DateTime briefingDate = now;
      if (now.hour >= 9) {
        briefingDate = now.add(const Duration(days: 1));
      }
      
      final triggerTime = DateTime(briefingDate.year, briefingDate.month, briefingDate.day, 9, 0, 0);
      final delay = triggerTime.difference(now);

      final dateStr = DateFormat('yyyy-MM-dd').format(briefingDate);
      
      final siteVisits = await SiteVisitDatabase.getAllSiteVisits();
      final todayVisits = siteVisits.where((v) => 
        v.status == 'Scheduled' && 
        (v.visitScheduledDatetime?.startsWith(dateStr) ?? false)
      ).length;

      final followUps = await FollowUpDatabase.getAllFollowUps();
      final todayFollowUps = followUps.where((f) => 
        f.status == 'Open' && 
        (f.nextFollowUp?.startsWith(dateStr) ?? false)
      ).length;

      if (todayVisits > 0 || todayFollowUps > 0) {
        final String briefingDay = briefingDate.day == now.day ? 'today' : 'tomorrow';
        
        NotificationService.instance.scheduleTimerNotification(
          id: 999,
          title: 'Morning Briefing ☕',
          body: 'Good morning! You have $todayVisits Site Visits and $todayFollowUps Follow-ups scheduled for $briefingDay.',
          delay: delay,
          saveToHistory: false,
        );
        debugPrint('[NotificationManager] Morning briefing scheduled for $triggerTime');
      }
    } catch (e) {
      debugPrint('[NotificationManager] Error scheduling briefing: $e');
    }
  }

  Future<void> checkNeglectedLeads() async {
    try {
      final List<Map<String, dynamic>> rawLeads = await LeadDatabase().getAllLeads();
      final now = DateTime.now();
      int nudgeCount = 0;

      for (final rawLead in rawLeads) {
        final leadJson = json.decode(rawLead['data']);
        final status = leadJson['status']?.toString() ?? '';
        
        if (status.toLowerCase() == 'open' || status.toLowerCase() == 'lead') {
          final modifiedStr = leadJson['modified']?.toString();
          if (modifiedStr != null) {
            final modified = DateTime.parse(modifiedStr.replaceAll(' ', 'T'));
            final difference = now.difference(modified);

            if (difference.inHours >= 48) {
              final leadName = leadJson['lead_name'] ?? leadJson['name'] ?? 'Unknown Lead';
              final leadId = leadJson['name'] ?? 'unknown';
              
              NotificationService.instance.scheduleTimerNotification(
                id: leadId.hashCode & 0x7FFFFFFF,
                title: 'Neglected Lead Nudge',
                body: 'Lead $leadName hasn\'t been contacted in 2 days. Don\'t let it go cold!',
                delay: const Duration(hours: 1),
                saveToHistory: true,
              );
              nudgeCount++;
              if (nudgeCount >= 5) break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationManager] Error checking neglected leads: $e');
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      _notifications = await DatabaseHelper.instance.getNotifications();
      _unreadCount = await DatabaseHelper.instance.getUnreadCount();
      debugPrint('[NotificationManager] Loaded ${_notifications.length} from DB. Unread: $_unreadCount');
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationManager] Error loading from DB: $e');
    }
  }

  Future<void> markAllAsRead() async {
    await DatabaseHelper.instance.markAllAsRead();
    await _loadFromDatabase();
  }

  Future<void> clearAll() async {
    await DatabaseHelper.instance.clearAll();
    await _loadFromDatabase();
  }

  Future<void> removeNotification(int index) async {
    if (index >= 0 && index < _notifications.length) {
      final id = _notifications[index]['id'];
      await DatabaseHelper.instance.deleteNotification(id);
      await _loadFromDatabase();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:meta/meta.dart';

class AnalyticsService {
  static AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  @visibleForTesting
  static set instance(AnalyticsService mock) => _instance = mock;

  late FirebaseAnalytics _analytics;
  late FirebaseAnalyticsObserver _observer;

  AnalyticsService._internal();

  void initialize(FirebaseAnalytics analytics) {
    _analytics = analytics;
    _observer = FirebaseAnalyticsObserver(analytics: analytics);
  }

  FirebaseAnalyticsObserver get observer => _observer;

  // Screen tracking
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  // User properties
  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // Custom events for HomeSol app
  Future<void> logPropertyView(String propertyId, String propertyName) async {
    await _analytics.logEvent(
      name: 'property_view',
      parameters: {'property_id': propertyId, 'property_name': propertyName},
    );
  }

  Future<void> logPropertySearch(String searchTerm, int resultsCount) async {
    await _analytics.logEvent(
      name: 'property_search',
      parameters: {'search_term': searchTerm, 'results_count': resultsCount},
    );
  }

  Future<void> logEnquirySubmitted(
    String propertyId,
    String enquiryType,
  ) async {
    await _analytics.logEvent(
      name: 'enquiry_submitted',
      parameters: {'property_id': propertyId, 'enquiry_type': enquiryType},
    );
  }

  Future<void> logDeveloperView(
    String developerId,
    String developerName,
  ) async {
    await _analytics.logEvent(
      name: 'developer_view',
      parameters: {
        'developer_id': developerId,
        'developer_name': developerName,
      },
    );
  }

  Future<void> logProjectView(String projectId, String projectName) async {
    await _analytics.logEvent(
      name: 'project_view',
      parameters: {'project_id': projectId, 'project_name': projectName},
    );
  }

  Future<void> logNotificationOpened(
    String notificationId,
    String notificationType,
  ) async {
    await _analytics.logEvent(
      name: 'notification_opened',
      parameters: {
        'notification_id': notificationId,
        'notification_type': notificationType,
      },
    );
  }

  Future<void> logShareProperty(String propertyId, String shareMethod) async {
    await _analytics.logEvent(
      name: 'share_property',
      parameters: {'property_id': propertyId, 'share_method': shareMethod},
    );
  }

  Future<void> logLocationPermissionRequested() async {
    await _analytics.logEvent(name: 'location_permission_requested');
  }

  Future<void> logLocationPermissionGranted() async {
    await _analytics.logEvent(name: 'location_permission_granted');
  }

  Future<void> logLocationPermissionDenied() async {
    await _analytics.logEvent(name: 'location_permission_denied');
  }

  Future<void> logImagePickerUsed(String source) async {
    await _analytics.logEvent(
      name: 'image_picker_used',
      parameters: {
        'source': source, // 'camera' or 'gallery'
      },
    );
  }

  Future<void> logThemeChanged(String themeMode) async {
    await _analytics.logEvent(
      name: 'theme_changed',
      parameters: {
        'theme_mode': themeMode, // 'light', 'dark', or 'system'
      },
    );
  }

  Future<void> logAppOpened() async {
    await _analytics.logEvent(name: 'app_opened');
  }

  Future<void> logAppBackgrounded() async {
    await _analytics.logEvent(name: 'app_backgrounded');
  }

  // Generic event logging
  Future<void> logCustomEvent(
    String eventName,
    Map<String, Object> parameters,
  ) async {
    await _analytics.logEvent(name: eventName, parameters: parameters);
  }
}


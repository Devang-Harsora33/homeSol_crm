import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

class TrackingService {
  static Future<TrackingStatus> requestTrackingPermission() async {
    if (!Platform.isIOS) return TrackingStatus.notSupported;

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      
      if (status == TrackingStatus.notDetermined) {
        // Show the tracking permission dialog
        return await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return status;
    } catch (e) {
      debugPrint('Error requesting tracking permission: $e');
      return TrackingStatus.notSupported;
    }
  }

  static Future<String> getAdvertisingIdentifier() async {
    if (!Platform.isIOS) return '';
    try {
      return await AppTrackingTransparency.getAdvertisingIdentifier();
    } catch (e) {
      debugPrint('Error getting advertising identifier: $e');
      return '';
    }
  }
}

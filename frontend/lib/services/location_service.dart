import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  static const String _disclosureAcceptedKey = 'background_location_disclosure_accepted';

  Position? _currentPosition;
  bool _isLocationEnabled = false;

  Position? get currentPosition => _currentPosition;
  bool get isLocationEnabled => _isLocationEnabled;

  /// Check if prominent disclosure has been accepted
  Future<bool> isDisclosureAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_disclosureAcceptedKey) ?? false;
  }

  /// Save prominent disclosure acceptance status
  Future<void> setDisclosureAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disclosureAcceptedKey, accepted);
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('Error checking location service: $e');
      return false;
    }
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location service is enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location service is disabled');
        return null;
      }

      // Check permissions
      final permission = await requestLocationPermission();
      if (!permission) {
        print('Location permission denied');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _isLocationEnabled = true;
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      _isLocationEnabled = false;
      return null;
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  /// Calculate distance from current location to target coordinates
  double? calculateDistanceFromCurrent(double targetLat, double targetLon) {
    if (_currentPosition == null) return null;

    return calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLat,
      targetLon,
    );
  }

  /// Get distance in a human-readable format
  String getDistanceString(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()}m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceInKm.round()}km';
    }
  }

  /// Check if location is within specified range
  bool isWithinRange(double targetLat, double targetLon, double rangeInKm) {
    final distance = calculateDistanceFromCurrent(targetLat, targetLon);
    return distance != null && distance <= rangeInKm;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Start listening to location updates
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  /// Stop location updates
  void stopLocationUpdates() {
    // Stream will automatically stop when disposed
  }
}

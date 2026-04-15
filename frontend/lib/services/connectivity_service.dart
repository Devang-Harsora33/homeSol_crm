import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ConnectivityService {
  static String get baseUrl => AuthService.baseUrl;

  static final Connectivity _connectivity = Connectivity();
  
  // Stream controller to broadcast connectivity changes
  static final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  static Stream<bool> get connectivityStream => _connectivityController.stream;

  static bool _isOnline = true;
  static bool get isOnline => _isOnline;

  /// Initialize the connectivity service
  static void initialize() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
    
    // Initial check
    checkConnectivity();
  }

  static Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    // If any of the results is not 'none', we might be online
    bool mightBeOnline = results.any((result) => result != ConnectivityResult.none);
    
    if (mightBeOnline) {
      // Double check by trying to reach the server
      _isOnline = await testConnectivity();
    } else {
      _isOnline = false;
    }
    
    _connectivityController.add(_isOnline);
    print('Connectivity changed: $_isOnline');
  }

  /// Manually check connectivity
  static Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(results);
    return _isOnline;
  }

  /// Test basic connectivity to the server
  static Future<bool> testConnectivity() async {
    try {
      // Try a simple endpoint
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 3));

      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed connectivity information
  static Future<Map<String, dynamic>> getConnectivityInfo() async {
    final results = await _connectivity.checkConnectivity();
    final serverReachable = await testConnectivity();

    return {
      'connectivity_results': results.map((r) => r.toString()).toList(),
      'server_reachable': serverReachable,
      'server_url': baseUrl,
      'is_online': serverReachable,
    };
  }
}

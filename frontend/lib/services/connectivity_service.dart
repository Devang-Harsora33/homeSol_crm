import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ConnectivityService {
  static String get baseUrl => AuthService.baseUrl;

  static final Connectivity _connectivity = Connectivity();
  
  static final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  static Stream<bool> get connectivityStream => _connectivityController.stream;

  static bool _isOnline = true;
  static bool get isOnline => _isOnline;
  
  static DateTime? _lastCheckTime;
  static bool _isChecking = false;

  /// Initialize the connectivity service
  static void initialize() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      print('Connectivity: Status changed detected by OS.');
      _updateConnectionStatus(results);
    });
    
    // Initial check
    checkConnectivity();
    
    // Periodic background check every 30 seconds to ensure state hasn't drifted
    // Using a shorter interval for better responsiveness
    Timer.periodic(const Duration(seconds: 30), (_) => checkConnectivity());
  }

  static Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      bool localInterfaceUp = results.any((result) => result != ConnectivityResult.none);
      
      bool currentOnlineState;
      if (!localInterfaceUp) {
        currentOnlineState = false;
      } else {
        // If we have a local connection, verify actual internet access
        currentOnlineState = await testConnectivity();
      }
      
      // Debouncing: If we are about to report OFFLINE, double check after a short delay
      // to avoid flickering during network handovers (e.g. WiFi to LTE)
      if (_isOnline && !currentOnlineState) {
        await Future.delayed(const Duration(milliseconds: 1500));
        currentOnlineState = await testConnectivity();
      }

      if (_isOnline != currentOnlineState) {
        _isOnline = currentOnlineState;
        _connectivityController.add(_isOnline);
        print('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      }
    } finally {
      _isChecking = false;
      _lastCheckTime = DateTime.now();
    }
  }

  /// Manually check connectivity
  static Future<bool> checkConnectivity() async {
    // Throttling: Don't check more than once every 1 second unless state is offline
    if (_lastCheckTime != null && 
        DateTime.now().difference(_lastCheckTime!).inSeconds < 1 && 
        _isOnline) {
      return _isOnline;
    }

    final results = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(results);
    return _isOnline;
  }

  /// Test actual internet access using multiple strategies
  static Future<bool> testConnectivity() async {
    try {
      // Direct IP check - Most reliable for confirming internet access
      // We skip general DNS lookup (google.com) as it can be slow or fail on restricted networks
      // even when IP routing is functional.
      
      bool hasInternet = false;
      
      // Strategy 1: Google Public DNS IP
      try {
        final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 3));
        await socket.close();
        hasInternet = true;
      } catch (_) {
        // Strategy 2: Cloudflare DNS IP
        try {
          final socket = await Socket.connect('1.1.1.1', 53, timeout: const Duration(seconds: 3));
          await socket.close();
          hasInternet = true;
        } catch (_) {}
      }

      if (!hasInternet) {
        print('Connectivity: IP ping checks failed.');
        return false;
      }

      // We check if our ERP is reachable, but we don't necessarily mark as "OFFLINE" 
      // if it's down but general internet is up.
      _verifyServerAccess(); 

      return true;
    } catch (e) {
      print('Connectivity test unexpected error: $e');
      return false;
    }
  }

  /// Verifies if the ERP server is reachable.
  /// This is used for internal logging/state and doesn't affect 'isOnline' immediately
  /// to avoid confusing the user with "No Internet" messages.
  static Future<bool> _verifyServerAccess() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 4));
      
      bool reachable = response.statusCode < 500;
      if (!reachable) {
        print('Connectivity: ERP Server responded with error ${response.statusCode}');
      }
      return reachable;
    } catch (e) {
      print('Connectivity: ERP Server unreachable: $e');
      return false;
    }
  }

  /// Get detailed connectivity information for debugging
  static Future<Map<String, dynamic>> getConnectivityInfo() async {
    final results = await _connectivity.checkConnectivity();
    final hasInternet = await testConnectivity();
    final serverReachable = await _verifyServerAccess();

    return {
      'connectivity_results': results.map((r) => r.toString()).toList(),
      'has_general_internet': hasInternet,
      'server_reachable': serverReachable,
      'server_url': baseUrl,
      'is_online_state': _isOnline,
    };
  }
}

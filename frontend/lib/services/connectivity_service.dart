import 'package:http/http.dart' as http;

class ConnectivityService {
  // static const String baseUrl = 'http://192.168.29.220:8000';
  // static const String baseUrl = 'http://10.0.2.2:8002';
  static const String baseUrl = 'https://erp.homesolindia.com';

  /// Test basic connectivity to the server
  static Future<bool> testConnectivity() async {
    try {
      print('Testing connectivity to: $baseUrl');

      // Try multiple endpoints to test connectivity
      final endpoints = [
        '/',
        '/api/resource/',
        '/api/resource/Story/',
        '/api/resource/Property Projects/',
        '/api/resource/Developer/',
      ];

      for (final endpoint in endpoints) {
        try {
          print('Testing endpoint: $baseUrl$endpoint');
          final response = await http
              .get(Uri.parse('$baseUrl$endpoint'))
              .timeout(const Duration(seconds: 5));

          print('Connectivity test for $endpoint: ${response.statusCode}');
          print('Response headers: ${response.headers}');
          if (response.statusCode < 500) {
            print('✅ Successfully connected to $endpoint');
            return true; // Any successful response means we can reach the server
          }
        } catch (e) {
          print('❌ Connectivity test failed for $endpoint: $e');
          print('Error type: ${e.runtimeType}');
          if (e.toString().contains('SocketException')) {
            print('🔌 Socket exception - likely network connectivity issue');
          } else if (e.toString().contains('TimeoutException')) {
            print('⏰ Timeout exception - server might be slow or unreachable');
          }
        }
      }

      return false; // All endpoints failed
    } catch (e) {
      print('Connectivity test failed: $e');
      return false;
    }
  }

  /// Test specific API endpoint connectivity
  static Future<bool> testApiEndpoint(String endpoint) async {
    try {
      final url = '$baseUrl$endpoint';
      print('Testing API endpoint: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      print('API endpoint test response: ${response.statusCode}');
      return response.statusCode < 500;
    } catch (e) {
      print('API endpoint test failed: $e');
      return false;
    }
  }

  /// Get detailed connectivity information
  static Future<Map<String, dynamic>> getConnectivityInfo() async {
    final basicConnectivity = await testConnectivity();
    final storiesEndpoint = await testApiEndpoint('/api/resource/Story/');
    final projectsEndpoint = await testApiEndpoint(
      '/api/resource/Property Projects/',
    );
    final developersEndpoint = await testApiEndpoint(
      '/api/resource/Developer/',
    );

    return {
      'server_reachable': basicConnectivity,
      'stories_endpoint': storiesEndpoint,
      'projects_endpoint': projectsEndpoint,
      'developers_endpoint': developersEndpoint,
      'server_url': baseUrl,
    };
  }
}

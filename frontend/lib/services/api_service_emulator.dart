import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import '../models/developer.dart';
import '../models/lead.dart';
import 'auth_service.dart';

class ApiServiceEmulator {
  // Use AuthService baseUrl for Android emulator
  static String get baseUrl => '${AuthService.baseUrl}/api/resource';

  /// Private helper method to get headers with authentication
  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  // Fetch all projects
  static Future<List<Project>> fetchProjects() async {
    try {
      print(
        '🔍 [EMULATOR] Fetching projects from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_all_projects',
      );
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.get_all_projects',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      print('✅ [EMULATOR] Projects response status: ${response.statusCode}');
      print('📄 [EMULATOR] Projects response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData =
            responseData['message'] ?? responseData['data'] ?? [];
        print('📊 [EMULATOR] Projects JSON data: $jsonData');
        return jsonData.map((json) => Project.fromJson(json)).toList();
      } else {
        print('❌ [EMULATOR] Projects error: ${response.statusCode}');
        return [];
      }
    } on http.ClientException catch (e) {
      print('❌ [EMULATOR] ClientException caught: $e');
      return [];
    } on FormatException catch (e) {
      print('❌ [EMULATOR] FormatException caught: $e');
      return [];
    } catch (e) {
      print('❌ [EMULATOR] General exception caught: $e');
      return [];
    }
  }

  // Fetch a single project by ID
  static Future<Project?> fetchProject(String id) async {
    try {
      print(
        '🔍 [EMULATOR] Fetching project from: $baseUrl/Property Projects/$id',
      );
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/Property Projects/$id'), headers: headers)
          .timeout(const Duration(seconds: 15));

      print('✅ [EMULATOR] Project response status: ${response.statusCode}');
      print('📄 [EMULATOR] Project response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> jsonData = responseData['data'];
        print('📊 [EMULATOR] Project JSON data: $jsonData');
        return Project.fromJson(jsonData);
      } else {
        print('❌ [EMULATOR] Project error: ${response.statusCode}');
        return null;
      }
    } on http.ClientException catch (e) {
      print('❌ [EMULATOR] ClientException caught: $e');
      return null;
    } on FormatException catch (e) {
      print('❌ [EMULATOR] FormatException caught: $e');
      return null;
    } catch (e) {
      print('❌ [EMULATOR] General exception caught: $e');
      return null;
    }
  }

  // Fetch all developers
  static Future<List<Developer>> fetchDevelopers() async {
    try {
      print('🔍 [EMULATOR] Fetching developers from: $baseUrl/Developer/');
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/Developer/'), headers: headers)
          .timeout(const Duration(seconds: 15));

      print('✅ [EMULATOR] Developers response status: ${response.statusCode}');
      print('📄 [EMULATOR] Developers response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['data'];
        print('📊 [EMULATOR] Developers JSON data: $jsonData');
        return jsonData.map((json) => Developer.fromJson(json)).toList();
      } else {
        print('❌ [EMULATOR] Developers error: ${response.statusCode}');
        return [];
      }
    } on http.ClientException catch (e) {
      print('❌ [EMULATOR] ClientException caught: $e');
      return [];
    } on FormatException catch (e) {
      print('❌ [EMULATOR] FormatException caught: $e');
      return [];
    } catch (e) {
      print('❌ [EMULATOR] General exception caught: $e');
      return [];
    }
  }

  // Fetch a single developer by ID
  static Future<Developer?> fetchDeveloperById(String developerId) async {
    try {
      print('🔍 [EMULATOR] Fetching developer by ID: $developerId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/resource/Developer/$developerId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      print(
        '✅ [EMULATOR] Developer by ID response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('📊 [EMULATOR] Developer by ID JSON data: $jsonData');
        return Developer.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        print('❌ [EMULATOR] Developer not found with ID: $developerId');
        return null;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      print('❌ [EMULATOR] ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e) {
      print('❌ [EMULATOR] FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e) {
      print('❌ [EMULATOR] General exception caught: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timeout: Server is taking too long to respond',
        );
      }
      throw Exception('Error fetching developer by ID: $e');
    }
  }

  // Create a new lead
  static Future<Lead> createLead(Lead lead) async {
    try {
      print('🔍 [EMULATOR] Creating lead: ${lead.toJson()}');
      final response = await http
          .post(
            Uri.parse('$baseUrl/leads/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(lead.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      print('✅ [EMULATOR] Create lead response status: ${response.statusCode}');
      print('📄 [EMULATOR] Create lead response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        print('📊 [EMULATOR] Created lead JSON data: $jsonData');
        return Lead.fromJson(jsonData);
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      print('❌ [EMULATOR] ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e) {
      print('❌ [EMULATOR] FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e) {
      print('❌ [EMULATOR] General exception caught: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timeout: Server is taking too long to respond',
        );
      }
      throw Exception('Error creating lead: $e');
    }
  }

  // Fetch leads for a specific broker
  static Future<List<Lead>> fetchBrokerLeads(String brokerId) async {
    try {
      print('🔍 [EMULATOR] Fetching leads for broker: $brokerId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/leads/broker/$brokerId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      print(
        '✅ [EMULATOR] Broker leads response status: ${response.statusCode}',
      );
      print('📄 [EMULATOR] Broker leads response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('📊 [EMULATOR] Broker leads JSON data: $jsonData');
        return jsonData.map((json) => Lead.fromJson(json)).toList();
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      print('❌ [EMULATOR] ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e) {
      print('❌ [EMULATOR] FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e) {
      print('❌ [EMULATOR] General exception caught: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timeout: Server is taking too long to respond',
        );
      }
      throw Exception('Error fetching broker leads: $e');
    }
  }

}
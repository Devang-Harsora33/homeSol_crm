import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/property_parking.dart';
import '../../auth_service.dart';
import 'package:Homesol/services/connectivity_service.dart';

class PropertyParkingService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final cookie = await AuthService.getCookie();
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  static Future<List<PropertyParking>> fetchPropertyParkings(String projectId) async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final trimmedProjectId = projectId.trim();
      final headers = await _getHeaders();
      final filters = jsonEncode([["project", "=", trimmedProjectId]]);
      final fields = jsonEncode([
        "name", 
        "project", 
        "parking_number", 
        "level", 
        "parking_type", 
        "parking_status", 
        "linked_unit", 
        "modified_by"
      ]);
      
      final encodedFilters = Uri.encodeComponent(filters);
      final encodedFields = Uri.encodeComponent(fields);
      final url = Uri.parse('$baseUrl/api/resource/Property%20Parking?filters=$encodedFilters&fields=$encodedFields&limit_page_length=1000');
      
      print('🔍 Fetching parking for project: "$trimmedProjectId"');
      print('🌐 URL: $url');
      
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['data'] ?? [];
        print('✅ Fetched ${jsonData.length} parking units for project $trimmedProjectId');
        return jsonData.map((json) => PropertyParking.fromJson(json)).toList();
      } else {
        print('❌ Parking API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Exception fetching parking: $e');
    }
    return [];
  }

  static Future<bool> updateParkingStatus(String parkingId, String status) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Property%20Parking/$parkingId');
      final response = await http.put(
        url, 
        headers: headers, 
        body: jsonEncode({'parking_status': status})
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> linkUnitToParking(String parkingId, String unitId) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Property%20Parking/$parkingId');
      final response = await http.put(
        url, 
        headers: headers, 
        body: jsonEncode({'linked_unit': unitId})
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }
}

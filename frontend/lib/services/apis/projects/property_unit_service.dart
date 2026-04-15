import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/property_unit.dart';
import '../../auth_service.dart';
import 'package:Homesol/services/connectivity_service.dart';

class PropertyUnitService {
  static String get baseUrl => AuthService.baseUrl;

  static const String apiKey = 'YOUR_API_KEY';
  static const String apiSecret = 'YOUR_API_SECRET';

  static Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey != 'YOUR_API_KEY' && apiSecret != 'YOUR_API_SECRET') {
      headers['Authorization'] = 'token $apiKey:$apiSecret';
    } else {
      final cookie = await AuthService.getCookie();
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    }
    return headers;
  }

  static Future<List<PropertyUnit>> fetchPropertyUnits(String projectId) async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      final filters = jsonEncode([["project", "=", projectId]]);
      final fields = jsonEncode(["name", "floor_number", "flat_no", "configuration", "carpet_area", "unit_status", "client_name", "modified_by"]);
      final url = Uri.parse('$baseUrl/api/resource/Property Unit?filters=$filters&fields=$fields&limit_page_length=500');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['data'] ?? [];
        return jsonData.map((json) => PropertyUnit.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> updatePropertyUnitStatus(String unitId, String status) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Property Unit/$unitId');
      final response = await http.put(url, headers: headers, body: jsonEncode({'unit_status': status})).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> linkLeadToUnit(String unitId, String leadId) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Property Unit/$unitId');
      final response = await http.put(url, headers: headers, body: jsonEncode({'client_name': leadId})).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }
}

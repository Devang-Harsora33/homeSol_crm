import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/cp_campaign.dart';
import '../../auth_service.dart';
import 'package:Homesol/services/connectivity_service.dart';

class CPCampaignService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final cookie = await AuthService.getCookie();
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  static Future<List<CPCampaign>> fetchCPCampaigns({String? channelPartner}) async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      String filters = "";
      if (channelPartner != null) {
        filters = "&filters=${Uri.encodeComponent(jsonEncode([["channel_partner", "=", channelPartner]]))}";
      }
      
      final fields = Uri.encodeComponent(jsonEncode([
        "name", 
        "channel_partner", 
        "project", 
        "campaign_type", 
        "start_date", 
        "status"
      ]));
      
      final url = Uri.parse('$baseUrl/api/resource/CP%20Campaign?fields=$fields$filters&limit_page_length=1000');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['data'] ?? [];
        return jsonData.map((json) => CPCampaign.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching CP Campaigns: $e');
    }
    return [];
  }

  static Future<CPCampaign?> fetchCPCampaign(String id) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/CP%20Campaign/${Uri.encodeComponent(id)}');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return CPCampaign.fromJson(responseData['data']);
      }
    } catch (e) {
      print('Error fetching CP Campaign $id: $e');
    }
    return null;
  }

  static Future<CPCampaign?> createCPCampaign(Map<String, dynamic> data) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/CP%20Campaign');
      final response = await http.post(
        url, 
        headers: headers, 
        body: jsonEncode(data)
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return CPCampaign.fromJson(responseData['data']);
      } else {
        print('Error creating CP Campaign: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception creating CP Campaign: $e');
    }
    return null;
  }
  static Future<CPCampaign?> updateCPCampaign(String id, Map<String, dynamic> data) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/CP%20Campaign/${Uri.encodeComponent(id)}');
      final response = await http.put(
        url, 
        headers: headers, 
        body: jsonEncode(data)
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return CPCampaign.fromJson(responseData['data']);
      } else {
        print('Error updating CP Campaign: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception updating CP Campaign: $e');
    }
    return null;
  }
}

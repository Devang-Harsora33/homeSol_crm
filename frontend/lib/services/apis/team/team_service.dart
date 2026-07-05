import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth_service.dart';
import '../../connectivity_service.dart';
import '../../../models/team_attendance.dart';
import '../../../models/team_checkin.dart';

class TeamService {
  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  static Future<List<TeamAttendance>> fetchTeamAttendances({int days = 7}) async {
    if (!ConnectivityService.isOnline) {
      return [];
    }

    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_team_attendances');
      final body = jsonEncode({"days": days});

      final response = await http.post(url, headers: headers, body: body);

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => TeamAttendance.fromJson(json)).toList();
      } else {
        print('❌ Error fetching team attendances: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching team attendances: $e');
      return [];
    }
  }

  static Future<List<TeamCheckin>> fetchTeamCheckins({int days = 30}) async {
    if (!ConnectivityService.isOnline) {
      return [];
    }

    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_team_checkins');
      final body = jsonEncode({"days": days});

      final response = await http.post(url, headers: headers, body: body);

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => TeamCheckin.fromJson(json)).toList();
      } else {
        print('❌ Error fetching team checkins: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching team checkins: $e');
      return [];
    }
  }
}

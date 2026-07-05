import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth_service.dart';
import '../../../models/admin/admin_stats.dart';

class AdminService {
  static Future<List<AdminUserActivity>> fetchUserActivityStats({String? targetUser, int days = 7}) async {
    try {
      final cookie = await AuthService.getCookie();
      var urlStr = '${AuthService.baseUrl}/api/method/homesol_app.api.get_users_activity_stats?days=$days';
      if (targetUser != null && targetUser.isNotEmpty) {
        urlStr += '&target_user=$targetUser';
      }
      final url = Uri.parse(urlStr);

      final response = await http.get(
        url,
        headers: {
          'Cookie': cookie ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> records = data['message'] ?? [];
        return records.map((e) => AdminUserActivity.fromJson(e)).toList();
      } else {
        print('Error fetching user activity stats: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch activity stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user activity stats: $e');
      throw Exception('Failed to connect to server: $e');
    }
  }
}

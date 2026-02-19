import 'dart:convert';
import 'package:Homesol/models/attendance_record.dart';
import 'package:Homesol/models/leave_application.dart';
import 'package:Homesol/models/leave_balance.dart';
import 'package:Homesol/models/salary_breakdown.dart';
import 'package:Homesol/models/salary_slip.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:http/http.dart' as http;





class WorkforceService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  static Future<Map<String, dynamic>> markAttendance(
    String type,
    double lat,
    double long,
    String deviceId,
    String deviceType, {
    String? remark,
  }) async {
    try {
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.employee_checkin',
      );
      final headers = await _getHeaders();

      final body = {
        "log_type": type,
        "latitude": lat.toString(),
        "longitude": long.toString(),
        "device_id": deviceId,
        "device_type": deviceType,
      };

      if (remark != null && remark.isNotEmpty) {
        body['custom_notes'] = remark;
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Successfully marked attendance'};
      } else {
        print("Check-in Failed: ${response.body}");
        return {'success': false, 'message': "Check-in Failed: ${response.body}"};
      }
    } catch (e) {
      print("Error: $e");
      return {'success': false, 'message': "Error: $e"};
    }
  }

  // Fetch leave balances
  static Future<List<LeaveBalance>> fetchLeaveBalances() async {
    try {
      print(
        'Fetching leave balances from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_my_leave_balance',
      );
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.get_my_leave_balance',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Leave balances response status: ${response.statusCode}');
      print('Leave balances response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('message')) {
          final Map<String, dynamic> message = responseData['message'];
          final List<dynamic> jsonData = message['leaves'] ?? [];
          print('Leave balances JSON data: $jsonData');
          return jsonData.map((json) => LeaveBalance.fromJson(json)).toList();
        } else {
          print('❌ Leave balances error: "message" key not found in response.');
          return [];
        }
      } else {
        print(
          '❌ Leave balances error: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return [];
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return [];
    } catch (e) {
      print('❌ General exception caught: $e');
      return [];
    }
  }

  // Fetch leave applications
  static Future<List<LeaveApplication>> fetchLeaveApplications() async {
    try {
      print(
        'Fetching leave applications from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_my_leave_applications',
      );
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.get_my_leave_applications',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Leave applications response status: ${response.statusCode}');
      print('Leave applications response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('message')) {
          final Map<String, dynamic> message = responseData['message'];
          final List<dynamic> jsonData = message['data'] ?? [];
          print('Leave applications JSON data: $jsonData');
          return jsonData.map((json) => LeaveApplication.fromJson(json)).toList();
        } else {
          print('❌ Leave applications error: "message" key not found in response.');
          return [];
        }
      } else {
        print(
          '❌ Leave applications error: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return [];
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return [];
    } catch (e) {
      print('❌ General exception caught: $e');
      return [];
    }
  }

  // Apply for leave
  static Future<String?> applyLeave({
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    required bool isHalfDay,
  }) async {
    try {
      print('Applying for leave...');
      final headers = await _getHeaders();
      final body = {
        'leave_type': leaveType,
        'from_date': fromDate,
        'to_date': toDate,
        'reason': reason,
        'is_half_day': isHalfDay ? 1 : 0,
      };
      final response = await http
          .post(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.apply_leave_by_employee',
            ),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      print('Apply leave response status: ${response.statusCode}');
      print('Apply leave response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('message') &&
            responseData['message'] is Map<String, dynamic>) {
          final Map<String, dynamic> message = responseData['message'];
          if (message.containsKey('status') && message['status'] == 'error') {
            return message['message']?.toString();
          } else if (message.containsKey('status') && message['status'] == 'success') {
            return null; // Success, no error message
          }
        }
        return 'Unknown response format from server.';
      } else {
        return 'Failed to apply for leave. Status: ${response.statusCode} - ${response.body}';
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return 'Network error: $e';
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return 'Invalid response format from server: $e';
    } catch (e) {
      print('❌ General exception caught: $e');
      return 'An unexpected error occurred: $e';
    }
  }

  static Future<List<String>> fetchLeaveTypes() async {
    try {
      print(
          'Fetching leave types from: ${AuthService.baseUrl}/api/resource/Leave Type?fields=["name"]');
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
                '${AuthService.baseUrl}/api/resource/Leave Type?fields=["name"]'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Leave types response status: ${response.statusCode}');
      print('Leave types response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> jsonData = responseData['data'];
          return jsonData.map((e) => e['name'].toString()).toList();
        } else {
          print('❌ Leave types error: "data" key not found or not a list in response.');
          return [];
        }
      } else {
        print(
            '❌ Leave types error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return [];
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return [];
    } catch (e) {
      print('❌ General exception caught: $e');
      return [];
    }
  }

  // Fetch salary slips
  static Future<List<SalarySlip>> getSalarySlips() async {
    try {
      print(
        'Fetching salary slips from: ${AuthService.baseUrl}/api/method/homesol_app.api.hrms.get_my_salary_slips',
      );
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.hrms.get_my_salary_slips',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Salary slips response status: ${response.statusCode}');
      print('Salary slips response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> message = responseData['message'];
        final List<dynamic> jsonData = message['data'] ?? [];
        return jsonData.map((json) => SalarySlip.fromJson(json)).toList();
      } else {
        print('❌ Salary slips error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ General exception caught: $e');
      return [];
    }
  }

  // Fetch salary breakdown
  static Future<SalaryBreakdown> getSalaryBreakdown(String salarySlipId) async {
    try {
      print(
        'Fetching salary breakdown from: ${AuthService.baseUrl}/api/method/homesol_app.api.hrms.get_salary_breakdown',
      );
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.hrms.get_salary_breakdown',
            ),
            headers: headers,
            body: json.encode({'salary_slip_id': salarySlipId}),
          )
          .timeout(const Duration(seconds: 30));

      print('Salary breakdown response status: ${response.statusCode}');
      print('Salary breakdown response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> message = responseData['message'];
        return SalaryBreakdown.fromJson(message);
      } else {
        print('❌ Salary breakdown error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load salary breakdown');
      }
    } catch (e) {
      print('❌ General exception caught: $e');
      throw Exception('Error fetching salary breakdown: $e');
    }
  }

  // Download salary slip
  static Future<String> downloadSalarySlip(String salarySlipId) async {
    try {
      print(
        'Downloading salary slip from: ${AuthService.baseUrl}/api/method/homesol_app.api.hrms.download_salary_slip',
      );
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.hrms.download_salary_slip',
            ),
            headers: headers,
            body: json.encode({'salary_slip_id': salarySlipId}),
          )
          .timeout(const Duration(seconds: 30));

      print('Download salary slip response status: ${response.statusCode}');
      print('Download salary slip response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> message = responseData['message'];
        String relativeUrl = message['pdf_url'];
        return '${AuthService.baseUrl}$relativeUrl';
      } else {
        print('❌ Download salary slip error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to get PDF URL');
      }
    } catch (e) {
      print('❌ General exception caught: $e');
      throw Exception('Error downloading salary slip: $e');
    }
  }

  // Fetch attendance history for a specific month and year
  static Future<List<AttendanceRecord>> getAttendanceHistory(
      int month, int year) async {
    try {
      print(
        'Fetching attendance history from: ${AuthService.baseUrl}/api/method/homesol_app.api.hrms.get_my_attendance_history',
      );
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.hrms.get_my_attendance_history',
            ),
            headers: headers,
            body: json.encode({'month': month, 'year': year}),
          )
          .timeout(const Duration(seconds: 30));

      print('Attendance history response status: ${response.statusCode}');
      print('Attendance history response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> message = responseData['message'];
        final List<dynamic> jsonData = message['data'] ?? [];
        return jsonData.map((json) => AttendanceRecord.fromJson(json)).toList();
      } else {
        print('❌ Attendance history error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ General exception caught: $e');
      return [];
    }
  }


}
import 'dart:convert';
import 'package:Homesol/models/attendance_record.dart';
import 'package:Homesol/models/leave_application.dart';
import 'package:Homesol/models/leave_balance.dart';
import 'package:Homesol/models/salary_breakdown.dart';
import 'package:Homesol/models/salary_slip.dart';
import 'package:http/http.dart' as http;
import '../../auth_service.dart';
import 'package:Homesol/services/connectivity_service.dart';

class WorkforceService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  static Future<String?> _getEmployeeId() async {
    final profile = await AuthService.getMyProfile();
    if (profile == null) return null;
    // In Frappe, 'name' is the primary identifier (e.g., EMP-00001)
    // We prioritize 'name' but fallback to 'employee' if 'name' is somehow empty
    return profile.name.isNotEmpty ? profile.name : profile.employee;
  }

  // --- ATTENDANCE ---

  static Future<List<AttendanceRecord>> getAttendanceHistory(int month, int year) async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final employeeId = await _getEmployeeId();
      if (employeeId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_attendance_history?employee=$employeeId&month=$month&year=$year'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => AttendanceRecord.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ getAttendanceHistory error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> markAttendance(
    String logType,
    double latitude,
    double longitude,
    String deviceId,
    String deviceType, {
    String? remark,
  }) async {
    if (!ConnectivityService.isOnline) {
      return {'success': false, 'message': 'No internet connection'};
    }
    try {
      final employeeId = await _getEmployeeId();
      print('WorkforceService: markAttendance - employeeId: $employeeId, logType: $logType');
      if (employeeId == null || employeeId.isEmpty) {
        return {'success': false, 'message': 'User profile or Employee ID not found'};
      }

      final headers = await _getHeaders();
      final body = jsonEncode({
        'employee': employeeId,
        'log_type': logType,
        'latitude': latitude,
        'longitude': longitude,
        'device_id': deviceId,
        'device_type': deviceType,
        if (remark != null) 'remark': remark,
      });
      
      print('WorkforceService: markAttendance - Request body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/api/method/homesol_app.api.mark_attendance'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 20));

      print('WorkforceService: markAttendance - Response status: ${response.statusCode}');
      print('WorkforceService: markAttendance - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return {'success': true, 'message': responseData['message'] ?? 'Attendance marked successfully'};
      } else {
        Map<String, dynamic> responseData = {};
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          print('WorkforceService: Error decoding error response: $e');
        }
        return {'success': false, 'message': responseData['message'] ?? 'Failed to mark attendance (Status: ${response.statusCode})'};
      }
    } catch (e) {
      print('WorkforceService: markAttendance error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // --- LEAVES ---

  static Future<List<String>> fetchLeaveTypes() async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_leave_types'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('❌ fetchLeaveTypes error: $e');
    }
    return [];
  }

  static Future<List<LeaveBalance>> fetchLeaveBalances([String? employeeId]) async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final empId = employeeId ?? await _getEmployeeId();
      if (empId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_leave_balances?employee=$empId'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => LeaveBalance.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ fetchLeaveBalances error: $e');
    }
    return [];
  }

  static Future<List<LeaveApplication>> fetchLeaveApplications([String? employeeId]) async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final empId = employeeId ?? await _getEmployeeId();
      if (empId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_leave_applications?employee=$empId'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => LeaveApplication.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ fetchLeaveApplications error: $e');
    }
    return [];
  }

  static Future<String?> applyLeave({
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    required bool isHalfDay,
  }) async {
    if (!ConnectivityService.isOnline) return 'No internet connection';
    try {
      final employeeId = await _getEmployeeId();
      if (employeeId == null) return 'User profile not found';

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/method/homesol_app.api.apply_leave'),
        headers: headers,
        body: jsonEncode({
          'employee': employeeId,
          'leave_type': leaveType,
          'from_date': fromDate,
          'to_date': toDate,
          'reason': reason,
          'is_half_day': isHalfDay ? 1 : 0,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['message'] ?? 'Failed to apply leave';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // --- PAYROLL ---

  static Future<List<SalarySlip>> getSalarySlips() async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final employeeId = await _getEmployeeId();
      if (employeeId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_salary_slips?employee=$employeeId'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => SalarySlip.fromJson(json)).toList();
      }
    } catch (e) {
      print('❌ getSalarySlips error: $e');
    }
    return [];
  }

  static Future<SalaryBreakdown> getSalaryBreakdown(String salarySlipId) async {
    if (!ConnectivityService.isOnline) throw 'No internet connection';
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_salary_breakdown?salary_slip=$salarySlipId'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> jsonData = responseData['message'] ?? {};
        return SalaryBreakdown.fromJson(jsonData);
      } else {
        throw 'Failed to fetch salary breakdown';
      }
    } catch (e) {
      throw 'Error: $e';
    }
  }

  static Future<String> downloadSalarySlip(String salarySlipId) async {
    // This should return the URL to the PDF
    // In Frappe, this might be a custom method or a standard print format URL
    return '$baseUrl/api/method/homesol_app.api.download_salary_slip?salary_slip=$salarySlipId';
  }

  // Keep old methods for backward compatibility if needed, but updated to use internal employee lookup
  static Future<List<AttendanceRecord>> fetchAttendanceHistory(String employeeId) async {
    return getAttendanceHistory(DateTime.now().month, DateTime.now().year);
  }

  static Future<SalaryBreakdown?> fetchSalaryBreakdown(String employeeId) async {
    // This one is tricky as the new one takes salarySlipId. 
    // For compatibility, we'll just return null or try to find the latest slip.
    return null;
  }
  
  static Future<List<SalarySlip>> fetchSalarySlips(String employeeId) async {
    return getSalarySlips();
  }
}

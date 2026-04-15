import 'dart:convert';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/workforces/workforce.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_service.dart';
import 'apis/user/user_service.dart';
import 'location_service.dart';
import '../models/sales_team.dart';
import '../models/user_profile.dart';
import 'package:geolocator/geolocator.dart';

import 'package:Homesol/services/databases/shift_database.dart';

import 'connectivity_service.dart';

class ShiftService {
  static Future<List<dynamic>> getShiftTypes() async {
    // Check if we are online before trying to fetch from API
    if (!ConnectivityService.isOnline) {
      print('Offline: Loading shift types from local database');
      return await ShiftDatabase().getShiftTypes();
    }

    try {
      final cookie = await AuthService.getCookie();
      final response = await http.get(
        Uri.parse(
          '${AuthService.baseUrl}/api/method/homesol_app.api.get_shift_types',
        ),
        headers: {'Cookie': cookie ?? ''},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> shiftTypes = jsonDecode(response.body)['message'];
        // Save to cache
        await ShiftDatabase().saveShiftTypes(shiftTypes);
        return shiftTypes;
      } else {
        print('Failed to load shift types from server: ${response.statusCode}');
        // Fallback to cache
        return await ShiftDatabase().getShiftTypes();
      }
    } catch (e) {
      print('Error fetching shift types, falling back to cache: $e');
      return await ShiftDatabase().getShiftTypes();
    }
  }

  static Future<Map<String, dynamic>> checkIn(
    String deviceId,
    String deviceType, {
    String? remark,
  }) async {
    return _performCheck('IN', deviceId, deviceType, remark: remark);
  }

  static Future<Map<String, dynamic>> checkOut(
    String deviceId,
    String deviceType, {
    String? remark,
  }) async {
    return _performCheck('OUT', deviceId, deviceType, remark: remark);
  }

  static Future<Map<String, dynamic>> _performCheck(
    String logType,
    String deviceId,
    String deviceType, {
    String? remark,
  }) async {
    try {
      // Get user profile
      final UserProfile? userProfile = await UserService.fetchUserProfile();
      if (userProfile == null) {
        print('User profile not found');
        return {'success': false, 'message': 'User profile not found'};
      }

      // Get sales teams
      final List<SalesTeam> salesTeams = await ApiService.fetchSalesTeams();
      if (salesTeams.isEmpty) {
        print('No sales teams found');
        return {'success': false, 'message': 'No sales teams found'};
      }

      // Get current location
      final Position? currentPosition =
          await LocationService.instance.getCurrentLocation();
      if (currentPosition == null) {
        print('Could not get current location');
        return {'success': false, 'message': 'Could not get current location'};
      }
      print(
        'Current Location: ${currentPosition.latitude}, ${currentPosition.longitude}',
      );

      // Find user's projects
      List<String> userProjects = [];
      for (var team in salesTeams) {
        for (var member in team.members) {
          if (member.employee == userProfile.name) {
            for (var project in team.projects) {
              userProjects.add(project.projects);
            }
          }
        }
      }

      if (userProjects.isEmpty) {
        print('User is not assigned to any projects');
        return {
          'success': false,
          'message': 'User is not assigned to any projects'
        };
      }

      // Check if user is within range of any assigned project
      for (var projectId in userProjects) {
        final project = await ProjectService.fetchProject(projectId);
        if (project != null && project.location != null) {
          final locationData = json.decode(project.location!);
          final coordinates =
              locationData['features'][0]['geometry']['coordinates'];
          final double projectLat = coordinates[1];
          final double projectLng = coordinates[0];
          print('Project $projectId Location: $projectLat, $projectLng');

          final distance = LocationService.instance.calculateDistance(
            currentPosition.latitude,
            currentPosition.longitude,
            projectLat,
            projectLng,
          );
          print('Distance to Project $projectId: $distance km');

          if (distance <= 0.35) {
            // 350 meters
            return WorkforceService.markAttendance(
              logType,
              currentPosition.latitude,
              currentPosition.longitude,
              deviceId,
              deviceType,
              remark: remark,
            );
          }
        }
      }

      print('User is not within range of any assigned project');
      return {
        'success': false,
        'message':
            'You are not within the 350-meter radius of any assigned project.'
      };
    } catch (e) {
      print('Error during check-$logType: $e');
      return {'success': false, 'message': 'Error during check-$logType: $e'};
    }
  }
}

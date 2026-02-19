import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/profile.dart'; 
import '../models/sales_team.dart' hide Project;
import 'auth_service.dart';
import 'databases/sales_team_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl => '${AuthService.baseUrl}/api/resource';
  static const String _lastSyncTimestampKey = "last_sync_timestamp_sales_teams";

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  // Helper to fetch all sales team names from server for deletion comparison
  static Future<List<String>> fetchSalesTeamNamesFromServer() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_all_sales_team',
      );

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toList();
      } else {
        print('❌ Error fetching all sales team names from server: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching all sales team names from server: $e');
      return [];
    }
  }

  // Sync sales teams from API and store in local database
  static Future<List<SalesTeam>> syncSalesTeams({bool forceRefresh = false}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastSyncTimestamp =
        prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";

    print('Last sync timestamp for sales teams: $lastSyncTimestamp');

    try {
      print(
        'Syncing sales teams from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_all_sales_team',
      );
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.get_all_sales_team',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Sales teams sync response status: ${response.statusCode}');
      print('Sales teams sync response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        List<SalesTeam> salesTeams = [];
        DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp + 'Z');

        final SalesTeamDatabase teamDb = SalesTeamDatabase();

        // --- Deletion Handling Start ---
        // Step 1: Get all local Sales Team IDs
        final List<Map<String, dynamic>> localTeamsRaw = await teamDb.getAllSalesTeams();
        final Set<String> localTeamNames = localTeamsRaw.map((t) => t['name'].toString()).toSet();

        // Step 2: Get all active server Sales Team IDs
        final List<String> serverTeamNamesList = await fetchSalesTeamNamesFromServer();
        final Set<String> serverTeamNames = serverTeamNamesList.toSet();

        // Step 3: Identify sales teams to delete locally
        final List<String> teamsToDelete = localTeamNames
            .where((name) => !serverTeamNames.contains(name))
            .toList();

        // Step 4: Delete identified sales teams from local database
        for (final teamName in teamsToDelete) {
          await teamDb.deleteSalesTeam(teamName);
          print('Deleted local sales team: $teamName (no longer on server)');
        }
        // --- Deletion Handling End ---

        if (jsonData.isEmpty) {
          print('No new sales teams to sync.');
          // Return existing teams from database (after potential deletions)
          final List<Map<String, dynamic>> rawTeams = await teamDb.getAllSalesTeams();
          return rawTeams.map((data) {
            final teamJson = json.decode(data['data']);
            return SalesTeam.fromJson(teamJson);
          }).toList();
        }

        for (var teamJson in jsonData) {
          SalesTeam salesTeam = SalesTeam.fromJson(teamJson);
          List<Member> updatedMembers = [];

          for (var member in salesTeam.members) {
            // Only fetch employee details if userId is missing and employee ID is present
            if (member.userId == null && member.employee.isNotEmpty) {
              Profile? employeeProfile = await fetchEmployeeDetails(
                member.employee,
              );
              if (employeeProfile != null) {
                // Create a new Member with the userId
                updatedMembers.add(
                  Member(
                    name: member.name,
                    owner: member.owner,
                    creation: member.creation,
                    modified: member.modified,
                    modifiedBy: member.modifiedBy,
                    docstatus: member.docstatus,
                    idx: member.idx,
                    employee: member.employee,
                    employeeName: member.employeeName,
                    userId: employeeProfile.userId,
                    role: member.role,
                    parent: member.parent,
                    parentfield: member.parentfield,
                    parenttype: member.parenttype,
                    doctype: member.doctype,
                  ),
                );
              } else {
                updatedMembers.add(member);
              }
            } else {
              updatedMembers.add(member);
            }
          }

          // Reconstruct SalesTeam with updated members
          final updatedTeam = SalesTeam(
            name: salesTeam.name,
            owner: salesTeam.owner,
            creation: salesTeam.creation,
            modified: salesTeam.modified,
            modifiedBy: salesTeam.modifiedBy,
            docstatus: salesTeam.docstatus,
            idx: salesTeam.idx,
            teamName: salesTeam.teamName,
            description: salesTeam.description,
            doctype: salesTeam.doctype,
            projects: salesTeam.projects,
            members: updatedMembers,
          );

          salesTeams.add(updatedTeam);

          // Track latest modified date
          if (updatedTeam.modified.isAfter(latestModifiedDate)) {
            latestModifiedDate = updatedTeam.modified;
          }

          // Store in local database
          final Map<String, dynamic> teamMap = updatedTeam.toJson();
          final SalesTeamDatabase teamDb = SalesTeamDatabase();
          await teamDb.upsertSalesTeam(teamMap);
        }

        // Save the new latest modified timestamp
        String formattedTimestamp = latestModifiedDate.toIso8601String();
        formattedTimestamp = formattedTimestamp.replaceAll('T', ' ').replaceAll('Z', '');
        List<String> parts = formattedTimestamp.split('.');
        if (parts.length > 1) {
          String microseconds = parts[1];
          if (microseconds.length < 6) {
            microseconds = microseconds.padRight(6, '0');
          } else if (microseconds.length > 6) {
            microseconds = microseconds.substring(0, 6);
          }
          formattedTimestamp = '${parts[0]}.$microseconds';
        } else {
          formattedTimestamp = '$formattedTimestamp.000000';
        }
        final String newLastSyncTimestamp = formattedTimestamp;
        await prefs.setString(_lastSyncTimestampKey, newLastSyncTimestamp);
        print('Sales teams synced successfully. New last sync timestamp: $newLastSyncTimestamp');

        return salesTeams;
      } else {
        print('❌ Sales teams error: ${response.statusCode} - ${response.body}');
        // Return existing teams from database on error
        final SalesTeamDatabase teamDb = SalesTeamDatabase();
        final List<Map<String, dynamic>> rawTeams =
            await teamDb.getAllSalesTeams();
        return rawTeams.map((data) {
          final teamJson = json.decode(data['data']);
          return SalesTeam.fromJson(teamJson);
        }).toList();
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      // Return existing teams from database on error
      final SalesTeamDatabase teamDb = SalesTeamDatabase();
      final List<Map<String, dynamic>> rawTeams =
          await teamDb.getAllSalesTeams();
      return rawTeams.map((data) {
        final teamJson = json.decode(data['data']);
        return SalesTeam.fromJson(teamJson);
      }).toList();
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      // Return existing teams from database on error
      final SalesTeamDatabase teamDb = SalesTeamDatabase();
      final List<Map<String, dynamic>> rawTeams =
          await teamDb.getAllSalesTeams();
      return rawTeams.map((data) {
        final teamJson = json.decode(data['data']);
        return SalesTeam.fromJson(teamJson);
      }).toList();
    } catch (e) {
      print('❌ General exception caught: $e');
      // Return existing teams from database on error
      final SalesTeamDatabase teamDb = SalesTeamDatabase();
      final List<Map<String, dynamic>> rawTeams =
          await teamDb.getAllSalesTeams();
      return rawTeams.map((data) {
        final teamJson = json.decode(data['data']);
        return SalesTeam.fromJson(teamJson);
      }).toList();
    }
  }

  // Fetch all sales teams from local database
  static Future<List<SalesTeam>> fetchSalesTeams({bool forceRefresh = false}) async {
    try {
      // First, attempt to sync from API if needed
      if (forceRefresh) {
        return await syncSalesTeams(forceRefresh: true);
      }

      // Load sales teams from local database
      final SalesTeamDatabase teamDb = SalesTeamDatabase();
      final List<Map<String, dynamic>> rawTeams =
          await teamDb.getAllSalesTeams();

      if (rawTeams.isEmpty) {
        print('No sales teams in local database, syncing from API...');
        return await syncSalesTeams();
      }

      final teams = rawTeams.map((data) {
        final teamJson = json.decode(data['data']);
        return SalesTeam.fromJson(teamJson);
      }).toList();

      print('Loaded ${teams.length} sales teams from local database');
      return teams;
    } catch (e) {
      print('❌ Error fetching sales teams: $e');
      return [];
    }
  }

  static Future<String?> uploadFile({
    required String filename,
    required String filedata, // Base64 encoded string
    int isPrivate = 0,
    String folder = "Home",
    required String doctype,
    required String docname,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AuthService.baseUrl}/api/method/upload_file');
      final body = jsonEncode({
        "file_name": filename,
        "file_url": filedata, // Assuming filedata is a base64 string or URL
        "is_private": isPrivate,
        "folder": folder,
        "doctype": doctype,
        "docname": docname,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['message']['file_url'];
      } else {
        print('Upload file failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  static Future<Profile?> fetchEmployeeDetails(String employeeId) async {
    try {
      final headers = await _getHeaders();
      print(
        'Fetching employee details for: $employeeId from $baseUrl/Employee/$employeeId',
      );
      final response = await http.get(
        Uri.parse(
          '$baseUrl/Employee/$employeeId',
        ), // Correct endpoint for Employee doctype
        headers: headers,
      );

      print('Employee details response status: ${response.statusCode}');
      print('Employee details response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Profile employeeProfile = Profile.fromJson(responseData['data']);
        print('Extracted userId for $employeeId: ${employeeProfile.userId}');
        return employeeProfile;
      } else {
        print(
          'Error fetching employee details: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Exception fetching employee details: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateBroker(
    String brokerId,
    Map<String, dynamic> updateBody,
  ) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse(
        '${AuthService.baseUrl}/api/resource/Broker/$brokerId',
      );

      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(updateBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return {'success': true, 'data': responseData['data']};
      } else {
        print(
          'Update Broker failed: ${response.statusCode} - ${response.body}',
        );
        return {
          'success': false,
          'message': 'Failed to update broker: ${response.body}',
        };
      }
    } catch (e) {
      print('Error updating Broker: $e');
      return {'success': false, 'message': 'Error updating broker: $e'};
    }
  }

  // Fetch leads for the current user using the new API
  // static Future<List<Lead>> fetchMyLeads() async {
  //   try {
  //     final userData = await AuthService.getUserData();
  //     if (userData == null || userData['email'] == null) {
  //       print('❌ [EMULATOR] User not logged in, cannot fetch leads.');
  //       return [];
  //     }
  //     final ownerEmail = userData['email'];

  //     final filters = jsonEncode([
  //       ['lead_owner', '=', ownerEmail]
  //     ]);
  //     final fields = jsonEncode(['*']);

  //     final uri = Uri.parse(
  //       '${AuthService.baseUrl}/api/resource/Lead?filters=$filters&fields=$fields',
  //     );

  //     print('🔍 [EMULATOR] Fetching my leads from: $uri');

  //     final headers = await _getHeaders();
  //     final response = await http.get(uri, headers: headers)
  //         .timeout(const Duration(seconds: 15));

  //     print('✅ [EMULATOR] My leads response status: ${response.statusCode}');
  //     print('📄 [EMULATOR] My leads response body: ${response.body}');

  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> responseData = json.decode(response.body);
  //       final List<dynamic> jsonData = responseData['data'];

  //       print('📊 [EMULATOR] My leads JSON data: $jsonData');
  //       return jsonData.map((json) => Lead.fromJson(json)).toList();
  //     } else {
  //       print(
  //         '❌ [EMULATOR] My leads error: ${response.statusCode} - ${response.body}',
  //       );
  //       return [];
  //     }
  //   } on http.ClientException catch (e) {
  //     print('❌ [EMULATOR] ClientException caught: $e');
  //     return [];
  //   } on FormatException catch (e) {
  //     print('❌ [EMULATOR] FormatException caught: $e');
  //     return [];
  //   } catch (e) {
  //     print('❌ [EMULATOR] General exception caught: $e');
  //     if (e.toString().contains('TimeoutException')) {
  //       print('⏰ Timeout exception - server might be slow or unreachable');
  //     }
  //     return [];
  //   }
  // }
}

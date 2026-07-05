import 'dart:convert';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/project_database.dart';
import 'package:Homesol/services/image_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Homesol/utils/error_logger.dart';

import '../../connectivity_service.dart';

class ProjectService {
  static String get baseUrl => AuthService.baseUrl;
  static List<Project>? _projectsCache;
  static DateTime? _projectsLastFetch;
  static List<Map<String, dynamic>>? _apiProjectsCache;
  static DateTime? _apiProjectsLastFetch;
    static const String _lastSyncTimestampKey = "last_sync_timestamp_projects";

  static http.Client? _testClient;
  static http.Client get _httpClient => _testClient ?? http.Client();

  static SharedPreferences? _testSharedPreferences;
  static Future<SharedPreferences> get _sharedPreferences async => _testSharedPreferences ?? await SharedPreferences.getInstance();

  static ProjectDatabase? _testProjectDatabase;
  static ProjectDatabase get _projectDatabase => _testProjectDatabase ?? ProjectDatabase();

  static void setTestMocks({
    http.Client? client,
    SharedPreferences? sharedPreferences,
    ProjectDatabase? projectDatabase,
  }) {
    _testClient = client;
    _testSharedPreferences = sharedPreferences;
    _testProjectDatabase = projectDatabase;
  }

  static void clearTestMocks() {
    _testClient = null;
    _testSharedPreferences = null;
    _testProjectDatabase = null;
  }

  static void clearCache() {
    _projectsCache = null;
    _projectsLastFetch = null;
    _apiProjectsCache = null;
    _apiProjectsLastFetch = null;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  /// Cache gallery images for a project
  static Future<void> _cacheProjectGalleryImages(Map<String, dynamic> projectJson) async {
    try {
      final galleryImages = projectJson['gallery_images'] as List<dynamic>?;
      if (galleryImages != null && galleryImages.isNotEmpty) {
        print('Caching ${galleryImages.length} gallery images for project: ${projectJson['name']}');

        final cachedImagePaths = <String>[];

        for (var imageItem in galleryImages) {
          if (imageItem is Map<String, dynamic>) {
            final imageUrl = imageItem['images'] as String?;
            if (imageUrl != null && imageUrl.isNotEmpty) {
              final cachedPath = await ImageCacheManager.downloadAndCacheImage(imageUrl);
              if (cachedPath != null) {
                cachedImagePaths.add(cachedPath);
              }
            }
          }
        }
        // Store cached paths in the project data for later retrieval
        projectJson['_cached_gallery_image_paths'] = cachedImagePaths;
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: '_cacheProjectGalleryImages',
        message: 'Project: ${projectJson['name']} | Error: $e',
        stackTrace: stack.toString(),
      );
      print('Error caching project gallery images: $e');
    }
  }

  // Helper to fetch all project names from server for deletion comparison
  static Future<List<String>> fetchProjectNamesFromServer() async {
    // Check if we are online before trying to fetch from API
    if (!ConnectivityService.isOnline) {
      return [];
    }

    try {
      final headers = await _getHeaders();
      final response = await _httpClient.get(
        Uri.parse(
          '${AuthService.baseUrl}/api/resource/Property Projects?fields=["name"]',
        ),
        headers: headers,
      );

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          return items.map((item) => item['name'].toString()).toList();
        }
      }
      return [];
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'fetchProjectNamesFromServer',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error fetching project names from server: $e');
      return [];
    }
  }

  // Sync projects from API and store in local database
  static Future<List<Project>> syncProjects({bool forceRefresh = false}) async {
    // Check if we are online before trying to fetch from API
    if (!ConnectivityService.isOnline) {
      print('Offline: Loading projects from local database');
      final ProjectDatabase projectDatabase = _projectDatabase;
      final List<Map<String, dynamic>> rawProjects =
          await projectDatabase.getAllProjects();
      return rawProjects.map((data) {
        final projectJson = json.decode(data['data']);
        return Project.fromJson(projectJson);
      }).toList();
    }

    final SharedPreferences prefs = await _sharedPreferences;
    String lastSyncTimestamp =
        prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";

    print('Last sync timestamp for projects: $lastSyncTimestamp');

    // Encode the filter to be URL-safe
    final String filters = Uri.encodeQueryComponent(
      json.encode([
        ["modified", ">", lastSyncTimestamp]
      ]),
    );

    final Uri uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_all_projects?filters=$filters');
    print('Requesting URL: $uri');

    try {
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> message = responseBody['message'] ?? [];

        final ProjectDatabase projectDatabase = _projectDatabase;

        // Step 1: Get all local Project IDs
        final List<Map<String, dynamic>> localProjectsRaw = await projectDatabase.getAllProjects();
        final Set<String> localProjectNames = localProjectsRaw.map((e) => e['name'].toString()).toSet();

        // Step 2: Get all active server Project IDs
        final List<String> serverProjectNamesList = await fetchProjectNamesFromServer();
        final Set<String> serverProjectNames = serverProjectNamesList.toSet();

        // Step 3: Identify projects to delete locally
        final List<String> projectsToDelete = localProjectNames
            .where((name) => !serverProjectNames.contains(name))
            .toList();

        // Step 4: Delete identified projects from local database
        for (final projectName in projectsToDelete) {
          await projectDatabase.deleteProject(projectName);
          print('Deleted local project: $projectName (no longer on server)');
        }

        if (message.isEmpty) {
          print('No new projects to sync.');
          // Return existing projects from database (after potential deletions)
          final List<Map<String, dynamic>> rawProjects =
              await projectDatabase.getAllProjects();
          return rawProjects.map((data) {
            final projectJson = json.decode(data['data']);
            return Project.fromJson(projectJson);
          }).toList();
        }

        DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp + 'Z');

        for (var projectJson in message) {
          // Ensure projectJson is a Map<String, dynamic>
          if (projectJson is Map<String, dynamic>) {
            // Cache gallery images for this project
            await _cacheProjectGalleryImages(projectJson);

            await projectDatabase.upsertProject(projectJson);

            final currentProjectModified =
                DateTime.parse(projectJson['modified'] + 'Z');
            if (currentProjectModified.isAfter(latestModifiedDate)) {
              latestModifiedDate = currentProjectModified;
            }
          }
        }

        // Save the new latest modified timestamp
        // Frappe timestamps can have microseconds, so we need to format correctly
        String formattedTimestamp = latestModifiedDate.toIso8601String();
        // Remove 'T' and 'Z'
        formattedTimestamp = formattedTimestamp.replaceAll('T', ' ').replaceAll('Z', '');
        // Ensure 6 digits for microseconds, padding with zeros if necessary
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
          // No microseconds part, add .000000
          formattedTimestamp = '$formattedTimestamp.000000';
        }
        final String newLastSyncTimestamp = formattedTimestamp;
        await prefs.setString(_lastSyncTimestampKey, newLastSyncTimestamp);
        print('Projects synced successfully. New last sync timestamp: $newLastSyncTimestamp');

        // Return synced projects
        final List<Map<String, dynamic>> syncedProjects =
            await projectDatabase.getAllProjects();
        return syncedProjects.map((data) {
          final projectJson = json.decode(data['data']);
          return Project.fromJson(projectJson);
        }).toList();
      } else {
        print('Failed to load projects: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Return existing projects from database on error
        final ProjectDatabase projectDatabase = _projectDatabase;
        final List<Map<String, dynamic>> rawProjects =
            await projectDatabase.getAllProjects();
        return rawProjects.map((data) {
          final projectJson = json.decode(data['data']);
          return Project.fromJson(projectJson);
        }).toList();
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'syncProjects',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error during project sync: $e');
      // Return existing projects from database on error
      final ProjectDatabase projectDatabase = _projectDatabase;
      final List<Map<String, dynamic>> rawProjects =
          await projectDatabase.getAllProjects();
      return rawProjects.map((data) {
        final projectJson = json.decode(data['data']);
        return Project.fromJson(projectJson);
      }).toList();
    }
  }

  // Fetch all projects from local database
  static Future<List<Project>> fetchProjects({bool forceRefresh = false}) async {
    try {
      // First, attempt to sync from API if needed
      if (forceRefresh) {
        return await syncProjects(forceRefresh: true);
      }

      // Load projects from local database
      final ProjectDatabase projectDatabase = _projectDatabase;
      final List<Map<String, dynamic>> rawProjects =
          await projectDatabase.getAllProjects();

      if (rawProjects.isEmpty) {
        print('No projects in local database, syncing from API...');
        return await syncProjects();
      }

      final projects = rawProjects.map((data) {
        final projectJson = json.decode(data['data']);
        return Project.fromJson(projectJson);
      }).toList();

      _projectsCache = projects;
      _projectsLastFetch = DateTime.now();
      print('Loaded ${projects.length} projects from local database');
      return projects;
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'fetchProjects (local)',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('❌ General exception caught while fetching projects: $e');
      return [];
    }
  }

  // Fetch a single project by ID
  static Future<Project?> fetchProject(String id) async {
    try {
      print('Fetching project from: $baseUrl/Property Projects/$id');
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/resource/Property Projects/$id'), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return null;

      print('Project response status: ${response.statusCode}');
      print('Project response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> jsonData = responseData['data'];
        print('Project JSON data: $jsonData');
        return Project.fromJson(jsonData);
      } else {
        print('❌ Project error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on http.ClientException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'fetchProject',
        message: 'ClientException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ ClientException caught: $e');
      return null;
    } on FormatException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'fetchProject',
        message: 'FormatException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ FormatException caught: $e');
      return null;
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'fetchProject',
        message: 'GeneralException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ General exception caught: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchProjectLocations() async {
    try {
      final headers = await _getHeaders();
      final response = await _httpClient.get(
        Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_all_project_locations'),
        headers: headers,
      );

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] is List) {
          return List<Map<String, dynamic>>.from(data['message']);
        }
      }
      return [];
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'fetchProjectLocations',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error fetching project locations: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchApiProjects({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _apiProjectsCache != null &&
        _apiProjectsLastFetch != null &&
        now.difference(_apiProjectsLastFetch!).inMinutes < 5) {
      print('Returning cached API projects');
      return _apiProjectsCache!;
    }

    try {
      final headers = await _getHeaders();
      final response = await _httpClient.get(
        Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_all_projects'),
        headers: headers,
      );

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] is List) {
          final List<dynamic> items = data['message'];
          final projects = items.map((item) {
            return {
              'id': item['name'].toString(),
              'name': item['project_name']?.toString() ?? item['name'].toString(), // Use project_name for display name
            };
          }).where((p) {
            final name = p['name']?.toString().toLowerCase().trim() ?? '';
            final id = p['id']?.toString().toLowerCase().trim() ?? '';
            if (name == 'bhavin steel' || name == 'parinee i' || id == 'bhavin steel' || id == 'parinee i') return false;
            return true;
          }).toList();
          _apiProjectsCache = projects;
          _apiProjectsLastFetch = now;
          return projects;
        }
        return [];
      }
      return [];
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'fetchApiProjects',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error fetching API projects: $e');
      return [];
    }
  }

  static Future<bool> incrementCampaignLeads(
      String projectId, String campaignId, int currentLeads) async {
    try {
      print('🚀 [API] Incrementing leads for campaign: $campaignId');
      final headers = await AuthService.getHeaders();
      
      // Use pathSegments to ensure proper encoding of all parts of the URL
      final baseUrlUri = Uri.parse(AuthService.baseUrl);
      final url = baseUrlUri.replace(
        pathSegments: [
          ...baseUrlUri.pathSegments.where((s) => s.isNotEmpty),
          'api',
          'resource',
          'Property Project Campaign',
          campaignId,
        ],
      );

      print('🔗 [API] Increment URL: $url');
      print('📝 [API] Payload: {"leads_generated": ${currentLeads + 1}}');

      final response = await http
          .put(
            url,
            headers: headers,
            body: jsonEncode({
              'leads_generated': currentLeads + 1,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (AuthService.checkResponse(response)) return false;

      print('📥 [API] Increment Response Status: ${response.statusCode}');
      print('📄 [API] Increment Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ [API] Campaign leads incremented successfully');
        return true;
      } else {
        print(
            '❌ [API] Failed to increment campaign leads: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'ProjectService',
        action: 'incrementCampaignLeads',
        message: 'Project: $projectId | Campaign: $campaignId | Error: $e',
        stackTrace: stack.toString(),
      );
      print('⚠️ [API] Exception incrementing campaign leads: $e');
      return false;
    }
  }
}


import 'dart:convert';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/project_database.dart';
import 'package:Homesol/services/image_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProjectService {
  static String get baseUrl => AuthService.baseUrl;
  static List<Project>? _projectsCache;
  static DateTime? _projectsLastFetch;
  static List<Map<String, String>>? _apiProjectsCache;
  static DateTime? _apiProjectsLastFetch;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_projects";

  // Test mocks
  static http.Client? _testClient;
  static AuthService? _testAuthService;
  static SharedPreferences? _testSharedPreferences;
  static ProjectDatabase? _testProjectDatabase;
  static ImageCacheManager? _testImageCacheManager;

  // Static setters for test mocks
  static void setTestMocks({
    http.Client? client,
    AuthService? authService,
    SharedPreferences? sharedPreferences,
    ProjectDatabase? projectDatabase,
    ImageCacheManager? imageCacheManager,
  }) {
    _testClient = client;
    _testAuthService = authService;
    _testSharedPreferences = sharedPreferences;
    _testProjectDatabase = projectDatabase;
    _testImageCacheManager = imageCacheManager;
  }

  static void clearTestMocks() {
    _testClient = null;
    _testAuthService = null;
    _testSharedPreferences = null;
    _testProjectDatabase = null;
    _testImageCacheManager = null;
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
                                                    }              }
            }
            // Store cached paths in the project data for later retrieval
            projectJson['_cached_gallery_image_paths'] = cachedImagePaths;
          }
        } catch (e) {
          print('Error caching project gallery images: $e');
        }
      }
  // Helper to fetch all project names from server for deletion comparison
  static Future<List<String>> fetchProjectNamesFromServer() async {
    try {
      final headers = await _getHeaders();
      final response = await (_testClient ?? http.Client()).get(
        Uri.parse(
          '${AuthService.baseUrl}/api/resource/Property Projects?fields=["name"]',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          return items.map((item) => item['name'].toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching project names from server: $e');
      return [];
    }
  }

  // Sync projects from API and store in local database
  static Future<List<Project>> syncProjects({bool forceRefresh = false}) async {
    final SharedPreferences prefs = _testSharedPreferences ?? await SharedPreferences.getInstance();
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
      final response = await (_testClient ?? http.Client())
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> message = responseBody['message'] ?? [];

        final ProjectDatabase projectDatabase = _testProjectDatabase ?? ProjectDatabase();

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
        final ProjectDatabase projectDatabase = _testProjectDatabase ?? ProjectDatabase();
        final List<Map<String, dynamic>> rawProjects =
            await projectDatabase.getAllProjects();
        return rawProjects.map((data) {
          final projectJson = json.decode(data['data']);
          return Project.fromJson(projectJson);
        }).toList();
      }
    } catch (e) {
      print('Error during project sync: $e');
      // Return existing projects from database on error
      final ProjectDatabase projectDatabase = _testProjectDatabase ?? ProjectDatabase();
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
      final ProjectDatabase projectDatabase = _testProjectDatabase ?? ProjectDatabase();
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
    } catch (e) {
      print('❌ General exception caught while fetching projects: $e');
      return [];
    }
  }

  // Fetch a single project by ID
  static Future<Project?> fetchProject(String id) async {
    try {
      print('Fetching project from: $baseUrl/Property Projects/$id');
      final headers = await _getHeaders();
      final response = await (_testClient ?? http.Client())
          .get(Uri.parse('$baseUrl/api/resource/Property Projects/$id'), headers: headers)
          .timeout(const Duration(seconds: 30));

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
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return null;
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return null;
    } catch (e) {
      print('❌ General exception caught: $e');
      return null;
    }
  }


  static Future<List<Map<String, String>>> fetchApiProjects({bool forceRefresh = false}) async {
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
      final response = await (_testClient ?? http.Client()).get(
        Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_all_projects'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] is List) {
          final List<dynamic> items = data['message'];
          final projects = items.map((item) {
            return {
              'id': item['name'].toString(),
              'name': item['project_name']?.toString() ?? item['name'].toString(), // Use project_name for display name
            };
          }).toList();
          _apiProjectsCache = projects;
          _apiProjectsLastFetch = now;
          return projects;
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Error fetching API projects: $e');
      return [];
    }
  }


}
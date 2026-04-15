import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/app_asset.dart';
import '../../auth_service.dart';
import '../../databases/asset_database.dart';

import '../../connectivity_service.dart';

class AssetService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<List<AppAsset>> fetchAppAssets({bool forceRefresh = false}) async {
    // Try to load from local DB first if not forcing refresh
    if (!forceRefresh) {
      final localAssets = await AssetDatabase().getAssets();
      if (localAssets.isNotEmpty) {
        print('Loaded ${localAssets.length} assets from local database');
        return localAssets;
      }
    }

    // Check if we are online before trying to fetch from API
    if (!ConnectivityService.isOnline) {
      print('Offline: Loading assets from local database');
      return await AssetDatabase().getAssets();
    }

    try {
      final cookie = await AuthService.getCookie();
      final headers = {'Cookie': cookie ?? ''};
      final uri = Uri.parse('$baseUrl/api/method/homesol_app.api.get_app_assets');

      print('Fetching app assets from: $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> message = responseData['message'] ?? [];
        
        final List<AppAsset> assets = message.map((json) => AppAsset.fromJson(json)).toList();

        // Clear and update local DB
        await AssetDatabase().deleteAllAssets();
        for (var asset in assets) {
          await AssetDatabase().upsertAsset(asset);
        }

        return assets;
      } else {
        print('Failed to load assets: ${response.statusCode} - ${response.body}');
        return await AssetDatabase().getAssets();
      }
    } catch (e) {
      print('Error fetching app assets: $e');
      return await AssetDatabase().getAssets();
    }
  }

  static List<AppAsset> filterBanners(List<AppAsset> assets) {
    return assets.where((asset) => asset.assetCategory == 'Banner').toList();
  }
}

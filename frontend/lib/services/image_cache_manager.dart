import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:Homesol/services/connectivity_service.dart';
import 'package:Homesol/services/auth_service.dart';

class ImageCacheManager {
  static String _buildFullUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '${AuthService.baseUrl}$url';
  }

  static String _getFileName(String url) {
    // Use a hash of the full URL to ensure uniqueness and avoid invalid characters
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    final extension = path.extension(Uri.parse(url).path);
    return '${digest.toString()}$extension';
  }

  static Future<String?> downloadAndCacheImage(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    
    final fullUrl = _buildFullUrl(imageUrl);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getFileName(fullUrl);
      final cacheDir = Directory(path.join(directory.path, 'cached_images'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      final localPath = path.join(cacheDir.path, fileName);
      final file = File(localPath);

      if (await file.exists()) {
        return localPath;
      }

      if (!ConnectivityService.isOnline) return null;

      final cookie = await AuthService.getCookie();
      final headers = <String, String>{};
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final response = await http.get(Uri.parse(fullUrl), headers: headers).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return localPath;
      } else {
        print('Failed to download image: ${response.statusCode} - $fullUrl');
      }
    } catch (e) {
      print('Error downloading image $imageUrl: $e');
    }
    return null;
  }

  static Future<String?> getCachedImagePath(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    final fullUrl = _buildFullUrl(imageUrl);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getFileName(fullUrl);
      final localPath = path.join(directory.path, 'cached_images', fileName);
      if (await File(localPath).exists()) return localPath;
    } catch (_) {}
    return null;
  }
}

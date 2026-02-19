import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class ImageCacheManager {
  static const String _cacheDirectoryName = 'image_cache';

  /// Get the cache directory for images
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirectoryName');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Generate a safe filename from URL
  static String _getFilenameFromUrl(String url) {
    final hash = md5.convert(url.toString().codeUnits).toString();
    final ext = url.contains('.') ? url.split('.').last.split('?').first : 'jpg';
    return '$hash.$ext';
  }

  /// Download and cache an image, returning the local path
  static Future<String?> downloadAndCacheImage(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    try {
      final cacheDir = await _getCacheDirectory();
      final filename = _getFilenameFromUrl(imageUrl);
      final file = File('${cacheDir.path}/$filename');

      // Return cached file if it exists
      if (await file.exists()) {
        print('Image already cached: ${file.path}');
        return file.path;
      }

      // Download the image
      print('Downloading image from: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('Image cached at: ${file.path}');
        return file.path;
      } else {
        print('Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error caching image: $e');
      return null;
    }
  }

  /// Download and cache multiple images, returning local paths
  static Future<List<String>> downloadAndCacheMultipleImages(List<String> imageUrls) async {
    final cachedPaths = <String>[];
    
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        final cachedPath = await downloadAndCacheImage(url);
        if (cachedPath != null) {
          cachedPaths.add(cachedPath);
        }
      }
    }
    
    return cachedPaths;
  }

  /// Clear all cached images
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('Image cache cleared');
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get cached image file
  static Future<File?> getCachedImage(String imageUrl) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final filename = _getFilenameFromUrl(imageUrl);
      final file = File('${cacheDir.path}/$filename');
      
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting cached image: $e');
      return null;
    }
  }
}

// lib/utils.dart
import 'services/auth_service.dart'; // Assuming AuthService defines baseUrl

String buildImageUrl(String? imagePath) {
  if (imagePath == null || imagePath.isEmpty) {
    return ''; // Or a placeholder image URL
  }
  // Check if the imagePath is already a full URL
  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    return imagePath;
  }
  return '${AuthService.baseUrl}$imagePath';
}
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

String stripHtml(String htmlString) {
  if (htmlString.isEmpty) return htmlString;
  
  // Basic HTML tag removal
  RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  String stripped = htmlString.replaceAll(exp, '');
  
  // Basic entity decoding (e.g., &amp; to &)
  stripped = stripped
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
      
  return stripped.trim();
}
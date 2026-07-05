import 'package:flutter/material.dart';
import '../utils.dart';
import 'package:intl/intl.dart';

class NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final String developerName;
  final String? developerLogo;
  final String createdAt;
  final VoidCallback? onTap;

  const NotificationCard({
    super.key,
    required this.title,
    required this.body,
    required this.developerName,
    this.developerLogo,
    required this.createdAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon / Logo Section
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFddbe6c).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: developerLogo != null && developerLogo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            buildImageUrl(developerLogo!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.notifications_active_outlined, color: Color(0xFFddbe6c)),
                          ),
                        )
                      : const Icon(Icons.notifications_active_outlined, color: Color(0xFFddbe6c)),
                ),
                const SizedBox(width: 16),
                // Content Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onSurface.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onSurface.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: onSurface.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 12,
                                  color: onSurface.withOpacity(0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  developerName,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: onSurface.withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String createdAt) {
    try {
      final date = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return DateFormat('dd MMM').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}

import 'package:flutter/material.dart';
import '../utils.dart';

class StoriesComponent extends StatefulWidget {
  final Function(int)? onStoryTap;
  final List<Map<String, dynamic>> stories;

  const StoriesComponent({super.key, this.onStoryTap, required this.stories});

  @override
  State<StoriesComponent> createState() => _StoriesComponentState();
}

class _StoriesComponentState extends State<StoriesComponent> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.stories.length,
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              return Container(
                margin: const EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Story Circle
                    GestureDetector(
                      onTap: () => _openStoryViewer(index),
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: story['hasStory'] && !story['isViewed']
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFddbe6c),
                                    Color(0xFFFF8E53),
                                    Color(0xFFddbe6c),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: story['hasStory'] && !story['isViewed']
                              ? null
                              : Colors.transparent,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.cardColor,
                            border: Border.all(
                              color: story['hasStory'] && !story['isViewed']
                                  ? theme.colorScheme.onSurface.withOpacity(0.1)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: Image.network(
                                    buildImageUrl(story['image']),
                                    width: 65,
                                    height: 65,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Text(
                                        '🏠',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: story['hasStory'] && !story['isViewed']
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Add story icon
                              if (story['isAddStory'])
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.cardColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.black54,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              // Story indicator
                              if (story['hasStory'] &&
                                  !story['isViewed'] &&
                                  !story['isAddStory'])
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFddbe6c),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.cardColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              // Viewed indicator (checkmark)
                              if (story['hasStory'] &&
                                  story['isViewed'] &&
                                  !story['isAddStory'])
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Username and story count
                    Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 70),
                          child: Text(
                            story['username'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.9,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openStoryViewer(int index) {
    if (widget.onStoryTap != null) {
      widget.onStoryTap!(index);
    }
  }

  void _showAddStoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add to Your Story',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFddbe6c).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.add_a_photo,
                  color: Color(0xFFddbe6c),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share your moments with the community!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Handle add story logic here
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFddbe6c),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add Story',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

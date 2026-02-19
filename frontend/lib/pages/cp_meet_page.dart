import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils.dart';

class CPMeetPage extends StatefulWidget {
  const CPMeetPage({super.key});

  @override
  State<CPMeetPage> createState() => _CPMeetPageState();
}

class _CPMeetPageState extends State<CPMeetPage> {
  List<Story> meetSchedules = [];
  bool isLoading = true;
  String? errorMessage;
  bool isRegistering = false;
  bool isRegistered = false;
  String? currentBrokerId;

  @override
  void initState() {
    super.initState();
    _getCurrentBrokerId();
    _fetchMeetSchedules();
  }

  Future<void> _getCurrentBrokerId() async {
    try {
      final userData = await AuthService.getUserData();
      setState(() {
        currentBrokerId = userData?['broker_id']?.toString();
      });
    } catch (e) {
      print('Error getting current broker ID: $e');
    }
  }

  Future<void> _fetchMeetSchedules() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final schedules = await ApiService.fetchMeetScheduleStories();
      print('🔍 Fetched ${schedules.length} meet schedules');
      if (schedules.isNotEmpty) {
        final firstSchedule = schedules.first;
        print('🔍 First schedule details:');
        print('  - ID: ${firstSchedule.id}');
        print('  - Content: ${firstSchedule.content}');
        print('  - Images: ${firstSchedule.images}');
        print('  - Venue: ${firstSchedule.venue}');
        print('  - Description: ${firstSchedule.description}');
        print('  - Scheduled Time: ${firstSchedule.scheduledTime}');
        print('  - Registered Brokers: ${firstSchedule.registeredBrokers}');
      }
      setState(() {
        meetSchedules = schedules;
        isLoading = false;
        // Check if current broker is already registered
        if (schedules.isNotEmpty && currentBrokerId != null) {
          final registeredBrokers = schedules.first.registeredBrokers ?? [];
          isRegistered = registeredBrokers.contains(currentBrokerId);
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _registerForMeet(Story meetSchedule) async {
    if (currentBrokerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to register for the meet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isRegistering = true;
    });

    try {
      final success = await ApiService.registerBrokerForMeet(
        storyId: meetSchedule.id,
        brokerId: currentBrokerId!,
      );

      if (success) {
        setState(() {
          isRegistered = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully registered for the meet!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        // Refresh the meet schedules to get updated registration data
        _fetchMeetSchedules();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to register: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isRegistering = false;
      });
    }
  }

  Future<void> _unregisterFromMeet(Story meetSchedule) async {
    if (currentBrokerId == null) return;

    setState(() {
      isRegistering = true;
    });

    try {
      final success = await ApiService.unregisterBrokerFromMeet(
        storyId: meetSchedule.id,
        brokerId: currentBrokerId!,
      );

      if (success) {
        setState(() {
          isRegistered = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully unregistered from the meet'),
            backgroundColor: Colors.orange,
          ),
        );
        // Refresh the meet schedules to get updated registration data
        _fetchMeetSchedules();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unregister: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isRegistering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Channel Partner Meet',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load meet schedules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchMeetSchedules,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (meetSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No meet schedules available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for upcoming events',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchMeetSchedules,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Display all meet schedules in card format
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming Meets',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: meetSchedules.length,
              itemBuilder: (context, index) {
                final meetSchedule = meetSchedules[index];
                return _MeetScheduleCard(
                  meetSchedule: meetSchedule,
                  theme: theme,
                  onTap: () => _navigateToMeetDetail(context, meetSchedule),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMeetDetail(BuildContext context, Story meetSchedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MeetDetailPage(meetSchedule: meetSchedule),
      ),
    );
  }

  String _formatDate(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return 'TBA';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${weekdays[dateTime.weekday - 1]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (e) {
      return 'TBA';
    }
  }

  String _formatTime(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return 'TBA';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$displayHour:$minute $period';
    } catch (e) {
      return 'TBA';
    }
  }
}

class _HeroCard extends StatelessWidget {
  final ThemeData theme;
  final Story meetSchedule;

  const _HeroCard({required this.theme, required this.meetSchedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          if ((meetSchedule.images != null &&
                  meetSchedule.images!.isNotEmpty) ||
              meetSchedule.content.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Container(
                height: 200,
                width: double.infinity,
                child: Builder(
                  builder: (context) {
                                        final imageUrl =
                                            (meetSchedule.images != null &&
                                                    meetSchedule.images!.isNotEmpty)
                                                ? buildImageUrl(meetSchedule.images!.first)
                                                : meetSchedule.content;
                                        print('🖼️ Using image URL: $imageUrl');                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) {
                        print('🖼️ Loading image: $url');
                        return Container(
                          height: 200,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Loading image...',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorWidget: (context, url, error) {
                        print(
                          '❌ CachedNetworkImage error: $error for URL: $url',
                        );
                        print('🔄 Falling back to Image.network');
                        return Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                          : null,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Loading image...',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ Image.network also failed: $error');
                            return Container(
                              height: 200,
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 50,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'URL: ${url.length > 50 ? url.substring(0, 50) + '...' : url}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            )
          else
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 50,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No image available',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          // Content section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.12),
                  theme.colorScheme.secondary.withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CP Meet ${_getYearFromSchedule(meetSchedule.scheduledTime)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  meetSchedule.description ??
                      'Join fellow partners for insights, launches and rewards.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getYearFromSchedule(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return '2025';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      return dateTime.year.toString();
    } catch (e) {
      return '2025';
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final ThemeData theme;
  final Story meetSchedule;

  const _ActionButtons({required this.theme, required this.meetSchedule});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleRegisterAction(context),
            icon: _getRegisterIcon(context),
            label: Text(_getRegisterText(context)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRegisterButtonColor(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleShareAction(context),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              side: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleRegisterAction(BuildContext context) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    final detailState = context.findAncestorStateOfType<_MeetDetailPageState>();

    if (detailState != null) {
      if (detailState.isRegistered) {
        detailState._unregisterFromMeet();
      } else {
        detailState._registerForMeet();
      }
    } else if (state != null) {
      if (state.isRegistered) {
        state._unregisterFromMeet(meetSchedule);
      } else {
        state._registerForMeet(meetSchedule);
      }
    }
  }

  void _handleShareAction(BuildContext context) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _getRegisterIcon(BuildContext context) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    final detailState = context.findAncestorStateOfType<_MeetDetailPageState>();

    if (detailState != null) {
      if (detailState.isRegistering) {
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      }

      if (detailState.isRegistered) {
        return const Icon(Icons.check_circle_rounded);
      }
    } else if (state != null) {
      if (state.isRegistering) {
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      }

      if (state.isRegistered) {
        return const Icon(Icons.check_circle_rounded);
      }
    }

    return const Icon(Icons.event_seat_rounded);
  }

  String _getRegisterText(BuildContext context) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    final detailState = context.findAncestorStateOfType<_MeetDetailPageState>();

    if (detailState != null) {
      if (detailState.isRegistering) {
        return 'Processing...';
      }

      if (detailState.isRegistered) {
        return 'Registered';
      }
    } else if (state != null) {
      if (state.isRegistering) {
        return 'Processing...';
      }

      if (state.isRegistered) {
        return 'Registered';
      }
    }

    return 'Register';
  }

  Color _getRegisterButtonColor(BuildContext context) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    final detailState = context.findAncestorStateOfType<_MeetDetailPageState>();

    if (detailState != null) {
      if (detailState.isRegistered) {
        return theme.colorScheme.primary;
      }
    } else if (state != null) {
      if (state.isRegistered) {
        return theme.colorScheme.primary;
      }
    }

    return theme.colorScheme.primary;
  }
}

class _AboutSection extends StatelessWidget {
  final ThemeData theme;
  final Story meetSchedule;

  const _AboutSection({required this.theme, required this.meetSchedule});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About the Meet',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meetSchedule.description ??
                'HomeSol Channel Partner Meet brings together our broker community to share insights, discover upcoming projects and unlock exclusive partner benefits.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.85),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetScheduleCard extends StatelessWidget {
  final Story meetSchedule;
  final ThemeData theme;
  final VoidCallback onTap;

  const _MeetScheduleCard({
    required this.meetSchedule,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            if ((meetSchedule.images != null &&
                    meetSchedule.images!.isNotEmpty) ||
                meetSchedule.content.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      final imageUrl =
                          (meetSchedule.images != null &&
                              meetSchedule.images!.isNotEmpty)
                          ? buildImageUrl(meetSchedule.images!.first)
                          : meetSchedule.content;
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 150,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.image,
                            size: 40,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CP Meet ${_getYearFromSchedule(meetSchedule.scheduledTime)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(meetSchedule.scheduledTime),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(meetSchedule.scheduledTime),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meetSchedule.venue ?? 'TBA',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    meetSchedule.description ?? 'Join us for an exciting meet!',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _handleCardRegisterAction(context, meetSchedule),
                          icon: _getCardRegisterIcon(context, meetSchedule),
                          label: Text(
                            _getCardRegisterText(context, meetSchedule),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getCardRegisterButtonColor(
                              context,
                              meetSchedule,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleCardShareAction(context),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            side: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
    );
  }

  String _getYearFromSchedule(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return '2025';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      return dateTime.year.toString();
    } catch (e) {
      return '2025';
    }
  }

  String _formatDate(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return 'TBA';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${weekdays[dateTime.weekday - 1]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (e) {
      return 'TBA';
    }
  }

  String _formatTime(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return 'TBA';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$displayHour:$minute $period';
    } catch (e) {
      return 'TBA';
    }
  }

  void _handleCardRegisterAction(BuildContext context, Story meetSchedule) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    if (state != null) {
      if (state.isRegistered) {
        state._unregisterFromMeet(meetSchedule);
      } else {
        state._registerForMeet(meetSchedule);
      }
    }
  }

  void _handleCardShareAction(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _getCardRegisterIcon(BuildContext context, Story meetSchedule) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    if (state == null) return const Icon(Icons.event_seat_rounded, size: 16);

    // Check if this specific meet schedule is being processed
    final isProcessingThisMeet =
        state.isRegistering &&
        state.meetSchedules.isNotEmpty &&
        state.meetSchedules.first.id == meetSchedule.id;

    // Check if this specific meet schedule is registered
    final isRegisteredForThisMeet =
        state.currentBrokerId != null &&
        (meetSchedule.registeredBrokers?.contains(state.currentBrokerId) ??
            false);

    if (isProcessingThisMeet) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (isRegisteredForThisMeet) {
      return const Icon(Icons.check_circle_rounded, size: 16);
    }

    return const Icon(Icons.event_seat_rounded, size: 16);
  }

  String _getCardRegisterText(BuildContext context, Story meetSchedule) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    if (state == null) return 'Register';

    // Check if this specific meet schedule is being processed
    final isProcessingThisMeet =
        state.isRegistering &&
        state.meetSchedules.isNotEmpty &&
        state.meetSchedules.first.id == meetSchedule.id;

    // Check if this specific meet schedule is registered
    final isRegisteredForThisMeet =
        state.currentBrokerId != null &&
        (meetSchedule.registeredBrokers?.contains(state.currentBrokerId) ??
            false);

    if (isProcessingThisMeet) {
      return 'Processing...';
    }

    if (isRegisteredForThisMeet) {
      return 'Registered';
    }

    return 'Register';
  }

  Color _getCardRegisterButtonColor(BuildContext context, Story meetSchedule) {
    final state = context.findAncestorStateOfType<_CPMeetPageState>();
    if (state == null) return theme.colorScheme.primary;

    // Check if this specific meet schedule is registered
    final isRegisteredForThisMeet =
        state.currentBrokerId != null &&
        (meetSchedule.registeredBrokers?.contains(state.currentBrokerId) ??
            false);

    if (isRegisteredForThisMeet) {
      return theme.colorScheme.primary;
    }

    return theme.colorScheme.primary;
  }
}

class _MeetDetailPage extends StatefulWidget {
  final Story meetSchedule;

  const _MeetDetailPage({required this.meetSchedule});

  @override
  State<_MeetDetailPage> createState() => _MeetDetailPageState();
}

class _MeetDetailPageState extends State<_MeetDetailPage> {
  bool isRegistering = false;
  bool isRegistered = false;
  String? currentBrokerId;

  @override
  void initState() {
    super.initState();
    _getCurrentBrokerId();
    _checkRegistrationStatus();
  }

  Future<void> _getCurrentBrokerId() async {
    try {
      final userData = await AuthService.getUserData();
      setState(() {
        currentBrokerId = userData?['broker_id']?.toString();
      });
    } catch (e) {
      print('Error getting current broker ID: $e');
    }
  }

  void _checkRegistrationStatus() {
    if (currentBrokerId != null) {
      final registeredBrokers = widget.meetSchedule.registeredBrokers ?? [];
      setState(() {
        isRegistered = registeredBrokers.contains(currentBrokerId);
      });
    }
  }

  Future<void> _registerForMeet() async {
    if (currentBrokerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to register for the meet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isRegistering = true;
    });

    try {
      final success = await ApiService.registerBrokerForMeet(
        storyId: widget.meetSchedule.id,
        brokerId: currentBrokerId!,
      );

      if (success) {
        setState(() {
          isRegistered = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully registered for the meet!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to register: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isRegistering = false;
      });
    }
  }

  Future<void> _unregisterFromMeet() async {
    if (currentBrokerId == null) return;

    setState(() {
      isRegistering = true;
    });

    try {
      final success = await ApiService.unregisterBrokerFromMeet(
        storyId: widget.meetSchedule.id,
        brokerId: currentBrokerId!,
      );

      if (success) {
        setState(() {
          isRegistered = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully unregistered from the meet'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unregister: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isRegistering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Channel Partner Meet',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroCard(theme: theme, meetSchedule: widget.meetSchedule),
              const SizedBox(height: 16),
              _InfoTile(
                icon: Icons.calendar_today_rounded,
                title: 'Date',
                subtitle: _formatDate(widget.meetSchedule.scheduledTime),
              ),
              _InfoTile(
                icon: Icons.access_time_rounded,
                title: 'Time',
                subtitle: _formatTime(widget.meetSchedule.scheduledTime),
              ),
              _InfoTile(
                icon: Icons.place_rounded,
                title: 'Venue',
                subtitle: widget.meetSchedule.venue ?? 'TBA',
              ),
              _InfoTile(
                icon: Icons.event_available_rounded,
                title: 'Description',
                subtitle:
                    widget.meetSchedule.description ??
                    'Join us for an exciting meet!',
              ),
              const SizedBox(height: 8),
              _ActionButtons(theme: theme, meetSchedule: widget.meetSchedule),
              const SizedBox(height: 20),
              _AboutSection(theme: theme, meetSchedule: widget.meetSchedule),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return 'TBA';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${weekdays[dateTime.weekday - 1]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (e) {
      return 'TBA';
    }
  }

  String _formatTime(String? scheduledTime) {
    if (scheduledTime == null || scheduledTime.isEmpty) return 'TBA';

    try {
      final dateTime = DateTime.parse(scheduledTime);
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$displayHour:$minute $period';
    } catch (e) {
      return 'TBA';
    }
  }
}

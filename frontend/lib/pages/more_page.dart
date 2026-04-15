import 'package:flutter/material.dart';
import 'dart:io';
import '../services/auth_service.dart';
import 'broker_profile_page.dart';
import '../models/profile.dart';
import '../utils.dart';
import 'ticket_page.dart';
import 'developers_page.dart' as dev_page;
import 'dashboard_page.dart';
import 'leave_page.dart';
import 'payroll/salary_slips_page.dart';
import 'channel_partner/channel_partner_list_page.dart';
import 'sourcing/sourcing_list_page.dart';
import '../services/apis/leads/lead_service.dart'; // Import LeadService
import '../services/apis/sourcing/sourcing_service.dart'; // Import SourcingService

class MorePage extends StatelessWidget {
  final Function(int)? onNavigateToTab;
  final String? designation;

  const MorePage({super.key, this.onNavigateToTab, this.designation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigateCallback = onNavigateToTab;
    // final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(theme: theme),
            Expanded(
              child: Builder(
                builder: (context) {
                  final dest = (designation ?? '').trim().toLowerCase();
                  final isDeveloper = dest == 'property developer';

                  if (isDeveloper) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _MoreTile(
                          icon: Icons.support_agent,
                          title: 'Raise Ticket',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TicketsListPage(),
                              ),
                            );
                          },
                        ),
                        _MoreTile(
                          icon: Icons.bookmark_border,
                          title: 'BookMarks',
                          onTap: null,
                        ),
                        _MoreTile(
                          icon: Icons.public,
                          title: 'HomeSol Networking',
                          onTap: null,
                        ),
                        _MoreTile(
                          icon: Icons.call,
                          title: 'Call Dashboard',
                          onTap: null,
                        ),
                        _MoreTile(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          onTap: null,
                        ),
                        _MoreTile(
                          icon: Icons.newspaper,
                          title: 'News & Article',
                          onTap: null,
                        ),
                        const SizedBox(height: 16),
                        _buildClearCacheTile(context),
                        const SizedBox(height: 16),
                        _LogoutButton(theme: theme),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      _MoreTile(
                        icon: Icons.home_work_outlined,
                        title: 'HomeSol Launch - Projects',
                        onTap: () {
                          if (navigateCallback != null) {
                            // Set the search query for HomeSol
                            dev_page.DevelopersPage.setSearchQuery('HomeSol');
                            
                            int devIndex = 2;
                            final dest = (designation ?? '').trim().toLowerCase();
                            if (dest == 'sales and sourcing' || dest == 'sales & sourcing') {
                              devIndex = 3;
                            }
                            
                            navigateCallback(
                              devIndex,
                            ); // Navigate to developers tab
                          } else {
                            // Fallback to push navigation if callback not provided
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const dev_page.DevelopersPage(
                                  initialSearchQuery: 'HomeSol',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _MoreTile(
                        icon: Icons.group_add_outlined,
                        title: 'Channel Partners',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ChannelPartnerListPage(),
                            ),
                          );
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final dest = (designation ?? '').trim().toLowerCase();
                          if (dest == 'sales and sourcing' || dest == 'sales & sourcing' || dest == 'sourcing') {
                            // Show nothing here as it's already in main tabs or we want to hide it
                            return const SizedBox.shrink();
                          } else if (dest != 'sales representative') {
                            return _MoreTile(
                              icon: Icons.source_outlined,
                              title: 'Sourcing',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SourcingListPage(showAddButton: true),
                                  ),
                                );
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      _MoreTile(
                        icon: Icons.wallet,
                        title: 'Payroll',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SalarySlipsPage()),
                          );
                        },
                      ),
                      _MoreTile(
                        icon: Icons.time_to_leave_outlined,
                        title: 'Leave Management',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LeaveScreen()),
                          );
                        },
                      ),
                      _MoreTile(
                        icon: Icons.support_agent,
                        title: 'Raise Ticket',
                        // onTap: null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TicketsListPage(),
                            ),
                          );
                        },
                      ),
                      _MoreTile(
                        icon: Icons.bookmark_border,
                        title: 'BookMarks',
                        onTap: null,
                        // onTap: () {
                        //   Navigator.of(context).push(
                        //     MaterialPageRoute(builder: (_) => const BookmarkPage()),
                        //   );
                        // },
                      ),
                      _MoreTile(
                        icon: Icons.quiz_outlined,
                        title: 'Dashboard',
                        onTap: null,
                        // onTap: () {
                        //   Navigator.of(context).push(
                        //     MaterialPageRoute(
                        //       builder: (_) => const BrokerDashboardPage(),
                        //     ),
                        //   );
                        // },
                      ),
                      _MoreTile(
                        icon: Icons.public,
                        title: 'HomeSol Networking',
                        // trailing: const Icon(Icons.keyboard_arrow_down),
                        onTap: null,
                      ),
                      _MoreTile(
                        icon: Icons.call,
                        title: 'Call Dashboard',
                        onTap: null,
                      ),

                      // _MoreTile(
                      //   icon: Icons.group_add_outlined,
                      //   title: 'Refer Home Buying Clients',
                      //   onTap: () {},
                      // ),
                      _MoreTile(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: null,
                      ),
                      _MoreTile(
                        icon: Icons.newspaper,
                        title: 'News & Article',
                        onTap: null,
                      ),
                      const SizedBox(height: 16),
                      _buildClearCacheTile(context),
                      const SizedBox(height: 16),
                      _LogoutButton(theme: theme),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearCacheTile(BuildContext context) {
    return _MoreTile(
      icon: Icons.cleaning_services,
      title: 'Clear Local Cache',
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clear Local Cache',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This will remove all locally synced data. You will need to re-sync from the server.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                8,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Clear Data',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (confirmed == true) {
          try {
            await LeadService.clearAllCaches();
            await SourcingService.clearAllCaches();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Local cache cleared successfully! App restarting...',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
              // Trigger a full app restart to re-fetch all data
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to clear cache: $e'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      },
    );
  }
}

class _Header extends StatefulWidget {
  final ThemeData theme;

  const _Header({required this.theme});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  Profile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.getMyProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Removed unused _initialsFromName after switching to avatar image/icon

  double _completionPercent(Profile? profile) {
    if (profile == null) return 0.0;
    // String-like fields must be non-empty strings
    final stringFields = <String Function(Profile)>[
      (p) => p.firstName,
      (p) => p.employeeName,
      (p) => p.jobTitle,
      (p) => p.designation,
      (p) => p.department,
      (p) => p.company,
      (p) => p.userId,
      (p) => p.cellNumber ?? '',
      (p) => p.personalEmail ?? '',
      (p) => p.companyEmail ?? '',
    ];

    int filled = 0;

    for (final getter in stringFields) {
      final value = getter(profile);
      if (value.trim().isNotEmpty) filled++;
    }

    final total = stringFields.length;
    if (total == 0) return 0.0;
    return filled / total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final name = _profile != null ? _profile!.employeeName : null;
    final company = _profile != null ? _profile!.company : null;
    final imagePath = _profile != null ? _profile!.image : null;
    ImageProvider<Object>? provider;
    if (imagePath != null && imagePath.isNotEmpty) {
      final fullImageUrl = buildImageUrl(imagePath);
      if (fullImageUrl.startsWith('http://') ||
          fullImageUrl.startsWith('https://')) {
        provider = NetworkImage(fullImageUrl);
      } else if (File(fullImageUrl).existsSync()) {
        provider = FileImage(File(fullImageUrl));
      }
    }
    final progress = _completionPercent(_profile);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.onSurface.withOpacity(0.06),
            theme.colorScheme.onSurface.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                backgroundImage: provider,
                child: provider == null
                    ? Icon(Icons.person, color: theme.colorScheme.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loading ? 'Loading…' : (name ?? 'Your Name'),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company ?? 'Company name',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}% of profile is completed.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BrokerProfilePage(
                            theme: theme,
                            profile: _profile,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary.withOpacity(0.8),
                foregroundColor: theme.colorScheme.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: const Text('Manage Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _MoreTile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onTap == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDisabled ? theme.cardColor.withOpacity(0.5) : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDisabled
              ? theme.colorScheme.outline.withOpacity(0.1)
              : theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: isDisabled
              ? theme.colorScheme.onSurface.withOpacity(0.4)
              : theme.colorScheme.onSurface,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDisabled
                ? theme.colorScheme.onSurface.withOpacity(0.4)
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDisabled
              ? theme.colorScheme.onSurface.withOpacity(0.4)
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final ThemeData theme;

  const _LogoutButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        await AuthService.logout();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.errorContainer,
        foregroundColor: theme.colorScheme.onErrorContainer,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
    );
  }
}

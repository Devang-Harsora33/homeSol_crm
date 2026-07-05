import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
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
import 'sourcing/sourcing_main_page.dart';
import 'stats/team_lead_stats_page.dart';
import '../services/apis/leads/lead_service.dart'; // Import LeadService
import '../services/apis/sourcing/sourcing_service.dart'; // Import SourcingService
import 'auth/login_page.dart';
import 'package:Homesol/pages/dashboard_page.dart';
import 'admin/lead_transfer_list_page.dart';
import 'admin/team_lead_dashboard_page.dart';
import '../services/api_service.dart';
import '../models/sales_team.dart';
import 'finance/construction_finance_list_page.dart';

class MorePage extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final String? designation;
  final String? developerId;

  const MorePage({super.key, this.onNavigateToTab, this.designation, this.developerId});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool _isTeamLead = false;

  @override
  void initState() {
    super.initState();
    _checkTeamLeadStatus();
  }

  Future<void> _checkTeamLeadStatus() async {
    // 1. Check basic designation first
    final dest = (widget.designation ?? '').trim().toLowerCase();
    if (dest == 'team lead') {
      if (mounted) setState(() => _isTeamLead = true);
      return;
    }

    // 2. If not in designation, check SalesTeam assignments
    try {
      final profile = await AuthService.getMyProfile();
      final userData = await AuthService.getUserData();
      final currentUserEmail = userData?['email'];
      final currentUserName = profile?.employeeName;
      
      if (currentUserEmail == null && currentUserName == null) return;

      final List<SalesTeam> teams = await ApiService.fetchSalesTeams();
      bool foundLeadRole = false;

      for (final team in teams) {
        for (final member in team.members) {
          final isCurrentUser = member.employee == currentUserEmail || 
                                member.userId == currentUserEmail || 
                                (currentUserName != null && member.employeeName?.toLowerCase() == currentUserName.toLowerCase());
                                
          if (isCurrentUser && member.role == 'Team Lead') {
            foundLeadRole = true;
            break;
          }
        }
        if (foundLeadRole) break;
      }

      if (mounted && foundLeadRole) {
        setState(() => _isTeamLead = true);
      }
    } catch (e) {
      print('Error checking SalesTeam role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigateCallback = widget.onNavigateToTab;
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
                  final dest = (widget.designation ?? '').trim().toLowerCase();
                  final isDeveloper = dest == 'property developer';

                  if (isDeveloper) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _MoreTile(
                          icon: Icons.account_balance,
                          title: 'Construction Finance Dashboard',
                          onTap: () {
                            if (widget.developerId != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ConstructionFinanceListPage(
                                    developerId: widget.developerId!,
                                  ),
                                ),
                              );
                            } else {
                              CustomSnackBar.show(context, message: 'Developer ID not found', isError: true);
                            }
                          },
                        ),
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
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          'HomeSol Nexus v1.0.5(44)',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.25),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
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
                            final dest = (widget.designation ?? '').trim().toLowerCase();
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
                      if (dest != 'lead caller')
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
                          final dest = (widget.designation ?? '').trim().toLowerCase();
                          if (dest == 'sales and sourcing' || dest == 'sales & sourcing' || dest == 'sourcing' || dest == 'lead caller') {
                            // Show nothing here as it's already in main tabs or we want to hide it
                            return const SizedBox.shrink();
                          } else if (dest != 'sales representative') {
                            return _MoreTile(
                              icon: Icons.source_outlined,
                              title: 'Sourcing',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SourcingMainPage(),
                                  ),
                                );
                              },
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      if (dest != 'lead caller')
                        _MoreTile(
                          icon: Icons.wallet,
                          title: 'Payroll',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SalarySlipsPage()),
                            );
                          },
                        ),
                      if (dest != 'lead caller')
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
                       if (_isTeamLead)
                        _MoreTile(
                          icon: Icons.bar_chart_rounded,
                          title: 'Performance Stats',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TeamLeadStatsPage(),
                              ),
                            );
                          },
                        ),
                       if (_isTeamLead)
                        _MoreTile(
                          icon: Icons.move_up,
                          title: 'Lead Transfer Tool',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LeadTransferListPage(),
                              ),
                            );
                          },
                        ),
                      if (_isTeamLead)
                        _MoreTile(
                          icon: Icons.fact_check_outlined,
                          title: 'Attendance Desk',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TeamLeadDashboardPage(),
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
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          'HomeSol Nexus v1.0.5(44)',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.25),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
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
              CustomSnackBar.show(context, message: 'Local cache cleared successfully! App restarting...', duration: const Duration(seconds: 2));
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

  String _initialsFromName(String? name) {
    if (name == null || name.trim().isEmpty) return 'P';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 24, 
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFF675D40).withOpacity(0.1),
                  backgroundImage: provider,
                  child: provider == null
                      ? Text(
                          _initialsFromName(name),
                          style: const TextStyle(
                            color: Color(0xFF675D40),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loading ? 'Loading…' : (name ?? 'Your Name'),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company ?? 'Homesol',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile Completion',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF675D40)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
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
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Manage Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  void _showLogoutDialog(BuildContext parentContext) {
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 10),
              Text('Sign Out', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          content: Text(
            'Are you sure you want to end your session?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.logout();
                if (parentContext.mounted) {
                  Navigator.of(parentContext).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF7E5E3),
                foregroundColor: const Color(0xFFC62828), // Dark Red text
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showLogoutDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF7E5E3),
        foregroundColor: const Color(0xFFC62828), // Dark Red
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

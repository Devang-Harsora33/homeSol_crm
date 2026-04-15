import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:Homesol/models/user_profile.dart';
import 'package:Homesol/models/profile.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/apis/user/user_service.dart';
import '../main_navigation.dart';

// Pages
import 'package:Homesol/pages/crm_page.dart';
import 'package:Homesol/pages/ticket_page.dart';
import 'package:Homesol/pages/payroll/salary_slips_page.dart';
import 'package:Homesol/pages/attendance/attendance_history_page.dart';
import 'package:Homesol/pages/broker_profile_page.dart';
import 'package:Homesol/pages/developers_page.dart';
import 'package:Homesol/pages/channel_partner/channel_partner_list_page.dart';
import 'package:Homesol/pages/sourcing/sourcing_list_page.dart';
import '../pages/auth/login_page.dart';
import 'package:Homesol/pages/leave_page.dart';

class Sidebar extends StatefulWidget {
  final VoidCallback onClose;
  final bool isOpen;
  final String? developerId;
  final String? designation;

  const Sidebar({
    super.key,
    required this.onClose,
    required this.isOpen,
    this.developerId,
    this.designation,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isLoggedIn = false;
  UserProfile? _userProfile;
  Profile? _profile;

  // UI Constants
  final Color _darkBg = const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400), 
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    if (widget.isOpen) {
      _animationController.forward();
    }

    _checkAuthStatus();
  }

  @override
  void didUpdateWidget(Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _animationController.forward();
        _checkAuthStatus();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        final userProfile = await UserService.fetchUserProfile();
        final profile = await AuthService.getMyProfile();
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _userProfile = userProfile;
            _profile = profile;
          });
        }
      } else {
        if (mounted) _resetAuth();
      }
    } catch (e) {
      if (mounted) _resetAuth();
    }
  }

  void _resetAuth() {
    setState(() {
      _isLoggedIn = false;
      _userProfile = null;
      _profile = null;
    });
  }

  void _navigateToPage(BuildContext context, Widget page) {
    widget.onClose(); 
    Navigator.of(context, rootNavigator: false).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? _darkBg.withOpacity(0.95) : Colors.white.withOpacity(0.98);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (_animationController.value == 0 && !widget.isOpen) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            if (widget.isOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),

            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.82,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(10, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildModernHeader(isDark, theme),
                      
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            if (_isLoggedIn) ...[
                              _buildSectionHeader('Management', isDark),
                              if (!(_profile?.designation?.toLowerCase().contains('sourcing') ?? false))
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.briefcase,
                                  title: 'CRM',
                                  subtitle: 'Leads & Clients',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(
                                    context,
                                    CRMPage(
                                      developerId: widget.developerId,
                                    ),
                                  ),
                                ),
                              if (_profile?.designation?.toLowerCase().contains('sourcing') ?? false)
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.magnifyingGlassPlus,
                                  title: 'Sourcing',
                                  subtitle: 'Manage Sources',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(context, SourcingListPage(showAddButton: true)),
                                ),
                              _buildModernMenuItem(
                                icon: FontAwesomeIcons.building,
                                title: 'Projects',
                                subtitle: 'Explore Portfolio',
                                isDark: isDark,
                                onTap: () => _navigateToPage(
                                  context,
                                  DevelopersPage(
                                    developerId: widget.developerId,
                                    designation: widget.designation,
                                  ),
                                ),
                              ),
                              _buildModernMenuItem(
                                icon: FontAwesomeIcons.city,
                                title: 'Developers',
                                isDark: isDark,
                                onTap: () => _navigateToPage(
                                  context,
                                  DevelopersPage(
                                    developerId: widget.developerId,
                                    designation: widget.designation,
                                  ),
                                ),
                              ),
                              if (!(_profile?.designation?.toLowerCase().contains('sourcing') ?? false))
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.mapLocationDot,
                                  title: 'Site Visits',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(
                                    context,
                                    CRMPage(
                                      developerId: widget.developerId,
                                    ),
                                  ),
                                ),
                              if (_profile?.designation?.toLowerCase() != 'property developer')
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.handshake,
                                  title: 'Channel Partners',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(context, const ChannelPartnerListPage()),
                                ),

                              if (_profile?.designation?.toLowerCase() != 'property developer') ...[
                                _buildSectionHeader('HR & Payroll', isDark),
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.calendarCheck,
                                  title: 'Attendance',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(context, AttendanceHistoryPage()),
                                ),
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.personWalkingArrowRight,
                                  title: 'Leave Application',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(context, const LeaveScreen()),
                                ),
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.fileInvoiceDollar,
                                  title: 'Salary Slips',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(context, SalarySlipsPage()),
                                ),
                              ],
                            ],

                            _buildSectionHeader('Preferences', isDark),
                            AnimatedBuilder(
                              animation: ThemeService.instance,
                              builder: (context, _) {
                                final isDarkMode = ThemeService.instance.themeMode == ThemeMode.dark;
                                return _buildModernMenuItem(
                                  icon: isDarkMode ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
                                  title: 'Appearance',
                                  subtitle: isDarkMode ? 'Dark Mode' : 'Light Mode',
                                  isDark: isDark,
                                  trailing: Switch.adaptive(
                                    value: isDarkMode,
                                    activeColor: theme.colorScheme.primary,
                                    onChanged: (_) async => await ThemeService.instance.toggle(),
                                  ),
                                  onTap: () async => await ThemeService.instance.toggle(),
                                );
                              },
                            ),

                            _buildSectionHeader('Account & Support', isDark),
                            if (_isLoggedIn) ...[
                              _buildModernMenuItem(
                                icon: FontAwesomeIcons.userPen,
                                title: 'My Profile',
                                isDark: isDark,
                                onTap: () => _navigateToPage(
                                  context, 
                                  BrokerProfilePage(theme: theme, profile: _profile)
                                ),
                              ),
                            ] else ...[
                              _buildModernMenuItem(
                                icon: FontAwesomeIcons.circleInfo,
                                title: 'About HomeSol',
                                isDark: isDark,
                                onTap: () {},
                              ),
                            ],
                            
                            _buildModernMenuItem(
                              icon: FontAwesomeIcons.headset,
                              title: 'Help & Support',
                              isDark: isDark,
                              onTap: () => _navigateToPage(context, TicketsListPage()), 
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildAuthButton(context, isDark, theme),
                            ),
                        

                            const SizedBox(height: 30),
                            Center(
                              child: Text(
                                'v1.0.0',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernHeader(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [theme.colorScheme.surface, theme.colorScheme.surface]
            : [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: _isLoggedIn
                  ? Text(
                      _userProfile?.initials ?? 'DH',
                      style: TextStyle(
                        color: isDark ? Colors.white : theme.colorScheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : FaIcon(FontAwesomeIcons.user, color: isDark ? Colors.white : theme.colorScheme.primary, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoggedIn ? (_userProfile?.fullName ?? 'User') : 'Welcome Guest',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoggedIn ? (_userProfile?.email ?? 'devang@homesol.in') : 'Sign in to sync data',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildModernMenuItem({
    required dynamic icon,
    required String title,
    String? subtitle,
    required bool isDark,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final color = isDark ? Colors.white : const Color(0xFF2C3E50);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: FaIcon(icon, color: color.withOpacity(0.7), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: color.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing 
                else FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: color.withOpacity(0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton(BuildContext context, bool isDark, ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: () {
        if (_isLoggedIn) {
          _showLogoutDialog(context);
        } else {
          _navigateToPage(context, const LoginPage());
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isLoggedIn 
            ? (isDark ? Colors.red.withOpacity(0.1) : Colors.red.withOpacity(0.1))
            : theme.colorScheme.primary,
        foregroundColor: _isLoggedIn ? Colors.red : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: _isLoggedIn ? 0 : 4,
      ),
      icon: FaIcon(_isLoggedIn ? FontAwesomeIcons.rightFromBracket : FontAwesomeIcons.rightToBracket, size: 18),
      label: Text(
        _isLoggedIn ? 'Log Out' : 'Sign In / Register',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const MainNavigation()),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

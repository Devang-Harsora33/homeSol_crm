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
import 'package:Homesol/pages/sourcing/sourcing_main_page.dart';
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
    final bgColor = isDark ? _darkBg : const Color(0xFFF5F5F7);
    
    final String designationStr = _profile?.designation?.toLowerCase() ?? '';
    final bool showCRM = designationStr != 'sourcing';
    final bool showSourcing = designationStr != 'sales representative';
    final bool isDeveloper = designationStr == 'property developer';

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
                              if (showCRM)
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
                              if (showSourcing)
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.magnifyingGlassPlus,
                                  title: 'Sourcing',
                                  subtitle: 'Manage Sources',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(context, SourcingMainPage(developerId: widget.developerId)),
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
                              // if (showCRM)
                              //   _buildModernMenuItem(
                              //     icon: FontAwesomeIcons.mapLocationDot,
                              //     title: 'Site Visits',
                              //     isDark: isDark,
                              //     onTap: () => _navigateToPage(
                              //       context,
                              //       CRMPage(
                              //         developerId: widget.developerId,
                              //       ),
                              //     ),
                              //   ),
                              if (!isDeveloper)
                                _buildModernMenuItem(
                                  icon: FontAwesomeIcons.handshake,
                                  title: 'Channel Partners',
                                  isDark: isDark,
                                  onTap: () => _navigateToPage(context, const ChannelPartnerListPage()),
                                ),

                              if (!isDeveloper) ...[
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: _buildAuthButton(context, isDark, theme),
                              ),
                            ),
                        

                            const SizedBox(height: 30),
                            Center(
                              child: Text(
                                'HomeSol Nexus v1.0.5(44)',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.25),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 90),
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
    const kAccent = Color(0xFF675D40);
    const matteBlack = Color(0xFF1A1A1A);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kAccent.withOpacity(0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? Colors.grey[800] : kAccent.withOpacity(0.1),
              child: _isLoggedIn
                  ? Text(
                      _userProfile?.initials ?? 'DH',
                      style: TextStyle(
                        color: kAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const FaIcon(FontAwesomeIcons.user, color: kAccent, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoggedIn ? (_userProfile?.fullName ?? 'User') : 'Welcome Guest',
                  style: TextStyle(
                    color: isDark ? Colors.white : matteBlack,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoggedIn ? (_userProfile?.email ?? 'devang@homesol.in') : 'Sign in to sync data',
                  style: TextStyle(
                    color: (isDark ? Colors.white : matteBlack).withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: FaIcon(FontAwesomeIcons.xmark, color: isDark ? Colors.white : matteBlack, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
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
    const matteBlack = Color(0xFF1A1A1A);
    final color = isDark ? Colors.white : matteBlack;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2))
        ]
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(icon, color: color.withOpacity(0.8), size: 16),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: color.withOpacity(0.5),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
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
    const matteBlack = Color(0xFF1A1A1A);

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
            ? (isDark ? Colors.red.shade900.withOpacity(0.3) : const Color(0xFFF7E5E3))
            : matteBlack,
        foregroundColor: _isLoggedIn ? const Color(0xFFC62828) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      icon: FaIcon(_isLoggedIn ? FontAwesomeIcons.rightFromBracket : FontAwesomeIcons.rightToBracket, size: 16),
      label: Text(
        _isLoggedIn ? 'Sign Out' : 'Sign In',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showLogoutDialog(BuildContext parentContext) {
    final theme = Theme.of(parentContext);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.orange, size: 20),
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
}

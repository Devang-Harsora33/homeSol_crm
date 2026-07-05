import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'models/sales_team.dart';
import 'models/profile.dart';
import 'pages/developers_page.dart';
import 'pages/home_page.dart';
import 'pages/crm_page.dart';
import 'pages/more_page.dart';
import 'pages/attendance/attendance_history_page.dart';
import 'pages/sourcing/sourcing_main_page.dart';
import 'components/curved_navigation_bar.dart';
import 'pages/admin/team_lead_dashboard_page.dart';
import 'pages/admin/admin_stats_page.dart';
import 'services/analytics_service.dart';
import 'services/api_service.dart';
import 'services/apis/user/user_service.dart';
import 'services/auth_service.dart';
import 'services/shift_service.dart';
import 'services/apis/workforces/workforce.dart';
import 'pages/loader_video_screen.dart';
import 'models/project.dart';
import 'models/developer.dart';
import 'models/app_asset.dart';
import 'pages/auth/login_page.dart'; // Import LoginPage
import 'components/auth_wrapper.dart'; // Import AuthWrapper
import 'services/apis/assets/asset_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late List<Widget> _pages;
  bool _isInitializing = true;
  String? _errorMessage;

  // Data state for the whole app
  List<Project> _projects = [];
  List<Developer> _developers = [];
  List<AppAsset> _appAssets = [];
  String? _employeeId;
  String? _designation;
  String? _developerId;
  
  // Minimal data needed for initializing HomePage
  String _initialAttendanceStatus = 'OUT';
  DateTime? _initialLastPunchTime;
  Map<String, dynamic>? _userShift;

  bool _isLoadingData = true; // Start with loading state for initial fetch

  @override
  void initState() {
    super.initState();
    // Initialize pages with default/empty data first
    _pages = _buildPages(); 
    // Start the actual data fetching
    _refreshData();
  }
  
  void _handleSkipLoader() {
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Widget> _buildPages() {
    final List<Widget> pages = [
      HomePage(
        onNavigateToTab: setCurrentIndex,
        projects: _projects,
        developers: _developers,
        appAssets: _appAssets,
        onRefresh: _refreshData,
        employeeId: _employeeId,
        designation: _designation,
        developerId: _developerId,
        initialAttendanceStatus: _initialAttendanceStatus,
        initialLastPunchTime: _initialLastPunchTime,
        userShift: _userShift,
        isLoadingData: _isLoadingData,
      ),
    ];

    final dest = (_designation ?? '').trim().toLowerCase();

    if (dest == 'admin') {
      pages.add(const DevelopersPage());
      pages.add(const AdminStatsPage());
    } else if (dest == 'property developer') {
      // Show leads (CRM) and sourcing for this developer
      pages.add(CRMPage(developerId: _developerId));
      pages.add(SourcingMainPage(developerId: _developerId));
      pages.add(DevelopersPage(
        developerId: _developerId,
        designation: _designation,
      ));
    } else {
      if (dest == 'sourcing') {
        pages.add(const SourcingMainPage());
      } else if (dest == 'sales and sourcing' || dest == 'sales & sourcing') {
        pages.add(const CRMPage());
        pages.add(const SourcingMainPage());
      } else {
        // Default / Sales Representative
        pages.add(const CRMPage());
      }
      pages.add(const DevelopersPage());
    }

    if (dest != 'property developer' && dest != 'lead caller' && dest != 'admin') {
      pages.add(AttendanceHistoryPage());
    }

    pages.add(MorePage(
      onNavigateToTab: setCurrentIndex,
      designation: _designation, 
      developerId: _developerId,
    ));

    return pages;
  }

  Future<void> _refreshData() async {
    // Only set isLoadingData to true if it's not the initial initialization
    // The initial initialization shows the LoaderVideoScreen, so no need for skeleton
    if (!_isInitializing) {
      setState(() {
        _isLoadingData = true;
        _pages = _buildPages(); // Rebuild pages to show skeletons
      });
    }
    
    final stopwatch = Stopwatch()..start();
    try {
      // Fetch all data in parallel with catchError to handle network failures
      final results = await Future.wait([
        ProjectService.syncProjects(forceRefresh: true).catchError((e) {
          print('Error during project sync: $e');
          return ProjectService.fetchProjects(); // Fallback to local DB
        }),
        DeveloperService.syncDevelopers(forceRefresh: true).catchError((e) {
          print('Error during developer sync: $e');
          return DeveloperService.fetchDevelopers(); // Fallback to local DB
        }),
        UserService.syncUserProfile(forceRefresh: true).catchError((e) {
          print('Error during user profile sync: $e');
          return UserService.fetchUserProfile(); // Fallback to local DB
        }),
        ShiftService.getShiftTypes().catchError((e) {
          print('Error during shift types fetch: $e');
          return <dynamic>[]; // ShiftService.getShiftTypes already handles internal cache
        }),
        ApiService.syncSalesTeams(forceRefresh: true).catchError((e) {
          print('Error during sales team sync: $e');
          return ApiService.fetchSalesTeams(); // Fallback to local DB
        }),
        AuthService.getMyProfile().catchError((e) {
          print('Error fetching full profile: $e');
          return null;
        }),
        AssetService.fetchAppAssets(forceRefresh: true).catchError((e) {
          print('Error during app assets sync: $e');
          return AssetService.fetchAppAssets(); // Fallback to local DB
        }),
      ]);

      // Process results into local variables
      final rawProjects = results[0] as List<Project>;
      final rawDevelopers = results[1] as List<Developer>;
      // Deduplicate projects and developers by ID
      final projects = {for (var p in rawProjects) p.id: p}.values.toList();
      final developers = {for (var d in rawDevelopers) d.id: d}.values.toList();
      final profile = results[2] as dynamic;
      final shifts = results[3] as List<dynamic>;
      final salesTeams = results[4] as List<SalesTeam>;
      final fullProfile = results.length > 5 ? results[5] as Profile? : null;
      final assets = results.length > 6 ? results[6] as List<AppAsset> : <AppAsset>[];

      final Map<String, Project> filteredProjectsMap = {};
      String? employeeId = profile?.name;
      String? designation = (fullProfile?.designation ?? '').trim();
      String? developerId;

      if (designation.toLowerCase() == 'property developer' && fullProfile != null) {
        for (final dev in developers) {
          if (dev.username == fullProfile.userId) {
            developerId = dev.id;
            for (final devProj in dev.projectsList) {
              try {
                final p = projects.firstWhere((element) => element.id == devProj.project);
                filteredProjectsMap[p.id] = p;
              } catch (_) {}
            }
            break;
          }
        }
      } else if (employeeId != null) {
        for (var team in salesTeams) {
          for (var member in team.members) {
            if (member.employee == employeeId) {
              for (var teamProject in team.projects) {
                try {
                  Project foundProject = projects.firstWhere(
                    (p) => p.id == teamProject.projects,
                  );
                  filteredProjectsMap[foundProject.id] = foundProject;
                } catch (e) {
                  print('Error finding project: ${teamProject.projects}. It might not be synced correctly.');
                }
              }
            }
          }
        }
      }

      List<Project> filteredProjects = filteredProjectsMap.values.toList();

      Map<String, dynamic>? userShift;
      if (profile != null) {
        final defaultShiftName = profile.defaultShift;
        userShift = shifts.firstWhere(
            (s) => s['name'] == defaultShiftName,
            orElse: () => shifts.firstWhere(
                (s) => s['name'] == 'Default', orElse: () => null));
      }

      String attendanceStatus = 'OUT';
      DateTime? lastPunchTime;
      if (employeeId != null && designation.toLowerCase() != 'property developer' && designation.toLowerCase() != 'lead caller') {
        try {
          final cookie = await AuthService.getCookie();
          final realEmployeeId = await WorkforceService.getTrueEmployeeId();
              
          final logUrl = Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_team_checkins?days=0');
          var logRes = await http.get(logUrl, headers: {'Cookie': cookie ?? ''}).timeout(const Duration(seconds: 5));

          if (logRes.statusCode == 200) {
            var logData = jsonDecode(logRes.body);
            final checkins = logData['message'] as List?;
            
            if (checkins != null && checkins.isNotEmpty) {
              String currentDeviceId = '';
              try {
                final deviceInfo = DeviceInfoPlugin();
                if (Platform.isAndroid) {
                  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
                  currentDeviceId = androidInfo.id;
                } else if (Platform.isIOS) {
                  IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
                  currentDeviceId = iosInfo.identifierForVendor ?? '';
                }
              } catch (_) {}
              
              // Find the check-in for this specific employee
              final myCheckins = checkins.where((log) => 
                (log['owner'] != null && fullProfile?.userId != null && fullProfile!.userId.isNotEmpty && log['owner'] == fullProfile.userId) ||
                (log['employee'] != null && log['employee'] == fullProfile?.name) ||
                (log['employee'] != null && log['employee'] == realEmployeeId) ||
                (log['employee'] != null && log['employee'] == employeeId) ||
                (log['employee_name'] != null && fullProfile?.employeeName != null && log['employee_name'] == fullProfile?.employeeName) ||
                (log['employee_name'] != null && fullProfile?.firstName != null && fullProfile!.firstName.isNotEmpty && 
                 log['employee_name'].toString().toLowerCase().contains(fullProfile.firstName.toLowerCase()) &&
                 (fullProfile.lastName == null || fullProfile.lastName!.isEmpty || log['employee_name'].toString().toLowerCase().contains(fullProfile.lastName!.toLowerCase()))) ||
                (currentDeviceId.isNotEmpty && log['device_id'] == currentDeviceId)
              ).toList();
              
              if (myCheckins.isNotEmpty) {
                // Sort by time descending to get the latest
                myCheckins.sort((a, b) => b['time'].toString().compareTo(a['time'].toString()));
                
                final lastLog = myCheckins.first;
                final lastLogTime = lastLog['time'] != null ? DateTime.parse(lastLog['time']) : null;
                
                bool isToday = false;
                if (lastLogTime != null) {
                  final now = DateTime.now();
                  if (lastLogTime.year == now.year &&
                      lastLogTime.month == now.month &&
                      lastLogTime.day == now.day) {
                    isToday = true;
                  }
                }

                if (isToday) {
                  attendanceStatus = lastLog['log_type'] ?? 'OUT';
                  lastPunchTime = lastLogTime;
                }
              }
            }
          }
        } catch (e) {
          print('Error fetching last attendance log: $e');
          // Keep default OUT status if offline
        }
      }

      // Update the state for MainNavigation and rebuild pages with fetched data
      setState(() {
        if (designation.toLowerCase() == 'property developer') {
           _projects = filteredProjects; // Could be empty, which is correct if no projects are assigned
           _developers = developers.where((d) => d.id == developerId).toList();
        } else {
           _projects = filteredProjects.isNotEmpty ? filteredProjects : projects;
           _developers = developers;
        }
        _employeeId = employeeId;
        _designation = designation;
        _developerId = developerId;
        _appAssets = assets;
        
        // Set the initial values for HomePage
        _userShift = userShift;
        _initialAttendanceStatus = attendanceStatus;
        _initialLastPunchTime = lastPunchTime;

        // Rebuild the pages list with the new data
        _pages = _buildPages();
      });

    } catch (e) {
      print("Initialization failed: $e");
      if (mounted) {
        setState(() => _errorMessage = "Failed to load page data: $e");
      }
    } finally {
      if (mounted) {
        // After all data is loaded, navigate or update state
        _navigateAfterLoading();
      }
    }
  }

  void _navigateAfterLoading() async {
    final loggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    // Set _isLoadingData to false to show the actual UI
    setState(() {
      _isLoadingData = false; // Reset loading flag
      _pages = _buildPages(); // Rebuild pages one last time after data is loaded
    });

    // If not logged in, navigate to login page
    if (!loggedIn) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
    // Else, AuthWrapper will handle MainNavigation display
  }

  void setCurrentIndex(int index) {
    setState(() => _currentIndex = index);
    
    final dest = (_designation ?? '').trim().toLowerCase();

    final List<String> pageNames = ['home'];
    if (dest == 'admin') {
      pageNames.addAll(['developers', 'stats']);
    } else if (dest == 'property developer' && _developerId != null) {
      pageNames.addAll(['crm', 'sourcing']);
    } else if (dest == 'sourcing') {
      pageNames.add('sourcing');
    } else if (dest == 'sales and sourcing' || dest == 'sales & sourcing') {
      pageNames.addAll(['crm', 'sourcing']);
    } else {
      pageNames.add('crm');
    }
    
    if (dest != 'admin') {
      pageNames.add('developers');
      if (dest != 'property developer' && dest != 'lead caller') {
        pageNames.add('attendance');
      }
    }
    pageNames.add('more');

    if (index < pageNames.length) {
      AnalyticsService.instance.logScreenView(pageNames[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return LoaderVideoScreen(onSkip: _handleSkipLoader);
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
              ElevatedButton(onPressed: _refreshData, child: const Text('Retry'))
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBarColor = isDark ? Colors.white : Colors.black;
    final navButtonColor = isDark ? Colors.white : Colors.black;
    final selectedIconColor = isDark ? Colors.black : Colors.white;
    final unselectedIconColor = isDark ? Colors.black87 : Colors.white70;

    final dest = (_designation ?? '').trim().toLowerCase();

    final List<IconData> icons = [Icons.home];
    if (dest == 'admin') {
      icons.addAll([Icons.apartment, Icons.bar_chart]);
    } else if (dest == 'property developer' && _developerId != null) {
      icons.addAll([Icons.timeline, Icons.source_outlined]);
    } else if (dest == 'sourcing') {
      icons.add(Icons.source_outlined);
    } else if (dest == 'sales and sourcing' || dest == 'sales & sourcing') {
      icons.addAll([Icons.timeline, Icons.source_outlined]);
    } else {
      icons.add(Icons.timeline);
    }
    if (dest != 'admin') {
      icons.add(Icons.apartment);
      if (dest != 'property developer' && dest != 'lead caller') {
        icons.add(Icons.calendar_today);
      }
    }
    icons.add(Icons.more_horiz);

    int safeIndex = _currentIndex;
    if (safeIndex >= icons.length) {
      safeIndex = icons.length - 1;
    }
    if (safeIndex < 0) safeIndex = 0;

    final items = List<Widget>.generate(icons.length, (i) {
      final selected = i == safeIndex;
      return Icon(icons[i], size: 24, color: selected ? selectedIconColor : unselectedIconColor);
    });

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      extendBody: true, // Required for curved nav bar to look correct
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: safeIndex, children: _pages),
      bottomNavigationBar: Offstage(
        offstage: isKeyboardOpen,
        child: CurvedNavigationBar(
          key: ValueKey(icons.length),
          index: safeIndex,
          items: items,
          onTap: setCurrentIndex,
          backgroundColor: Colors.transparent,
          color: navBarColor,
          buttonBackgroundColor: navButtonColor,
        ),
      ),
    );
  }
}
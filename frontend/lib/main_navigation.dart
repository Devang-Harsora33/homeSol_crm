import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/sales_team.dart';
import 'models/profile.dart';
import 'pages/developers_page.dart';
import 'pages/home_page.dart';
import 'pages/crm_page.dart';
import 'pages/more_page.dart';
import 'pages/attendance/attendance_history_page.dart';
import 'pages/sourcing/sourcing_main_page.dart';
import 'components/curved_navigation_bar.dart';
import 'services/analytics_service.dart';
import 'services/api_service.dart';
import 'services/apis/user/user_service.dart';
import 'services/auth_service.dart';
import 'services/shift_service.dart';
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

  bool _isLoadingData = false; // New flag for loading state

  // Completer to signal that the user has chosen to skip the loader
  final Completer<void> _skipCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    // Initialize pages with default/empty data first
    _pages = _buildPages(); 
    // Start the actual data fetching
    _refreshData();
  }
  
  @override
  void dispose() {
    // If the completer is not completed, ensure it's completed on dispose
    // to prevent any lingering futures from keeping the widget alive.
    if (!_skipCompleter.isCompleted) {
      _skipCompleter.completeError('MainNavigation disposed before skip or min duration');
    }
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

    if (dest == 'property developer') {
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

    if (dest != 'property developer') {
      pages.add(AttendanceHistoryPage());
    }

    pages.add(MorePage(
      onNavigateToTab: setCurrentIndex,
      designation: _designation, // Pass designation to MorePage
    ));

    return pages;
  }

  // Handler for when the user clicks the "Skip" button on the loader
  void _handleSkipLoader() {
    if (!_skipCompleter.isCompleted) {
      _skipCompleter.complete();
    }
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
      final projects = results[0] as List<Project>;
      final developers = results[1] as List<Developer>;
      final profile = results[2] as dynamic;
      final shifts = results[3] as List<dynamic>;
      final salesTeams = results[4] as List<SalesTeam>;
      final fullProfile = results.length > 5 ? results[5] as Profile? : null;
      final assets = results.length > 6 ? results[6] as List<AppAsset> : <AppAsset>[];

      List<Project> filteredProjects = [];
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
                filteredProjects.add(p);
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
                  filteredProjects.add(foundProject);
                } catch (e) {
                  print('Error finding project: ${teamProject.projects}. It might not be synced correctly.');
                }
              }
            }
          }
        }
      }

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
      if (employeeId != null && designation.toLowerCase() != 'property developer') {
        try {
          final cookie = await AuthService.getCookie();
          final filters = jsonEncode([
            ['employee', '=', employeeId]
          ]);
          final logUrl = Uri.parse(
              '${AuthService.baseUrl}/api/resource/Employee Checkin?filters=$filters&order_by=time desc&limit=1');
          final logRes = await http.get(logUrl, headers: {'Cookie': cookie ?? ''}).timeout(const Duration(seconds: 5));

          if (logRes.statusCode == 200) {
            final logData = jsonDecode(logRes.body);
            if (logData['data'] != null && logData['data'].isNotEmpty) {
              final lastLog = logData['data'][0];
              attendanceStatus = lastLog['log_type'] ?? 'OUT';
              lastPunchTime =
                  lastLog['time'] != null ? DateTime.parse(lastLog['time']) : null;
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
      stopwatch.stop();
      final elapsed = stopwatch.elapsed;
      const minDuration = Duration(seconds: 6); // Minimum display duration for loader

      // Wait until either the minDuration has passed OR the user clicks skip
      if (_isInitializing) {
        if (elapsed < minDuration) {
          await Future.any([
            Future.delayed(minDuration - elapsed),
            _skipCompleter.future, // Wait for skip signal
          ]);
        }
        // If the skip completer was used, ensure it's completed
        if (!_skipCompleter.isCompleted) {
          _skipCompleter.complete();
        }
      }
      
      if (mounted) {
        // After all data is loaded and min duration/skip is handled, navigate
        _navigateAfterLoading();
      }
    }
  }

  void _navigateAfterLoading() async {
    final loggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    // Set _isInitializing to false to show the actual UI
    setState(() {
      _isInitializing = false;
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
    if (dest == 'property developer' && _developerId != null) {
      pageNames.addAll(['crm', 'sourcing']);
    } else if (dest == 'sourcing') {
      pageNames.add('sourcing');
    } else if (dest == 'sales and sourcing' || dest == 'sales & sourcing') {
      pageNames.addAll(['crm', 'sourcing']);
    } else {
      pageNames.add('crm');
    }
    
    pageNames.add('developers');
    if (dest != 'property developer') {
      pageNames.add('attendance');
    }
    pageNames.add('more');

    if (index < pageNames.length) {
      AnalyticsService.instance.logScreenView(pageNames[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      // Pass the skip handler to the LoaderVideoScreen
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
    if (dest == 'property developer' && _developerId != null) {
      icons.addAll([Icons.timeline, Icons.source_outlined]);
    } else if (dest == 'sourcing') {
      icons.add(Icons.source_outlined);
    } else if (dest == 'sales and sourcing' || dest == 'sales & sourcing') {
      icons.addAll([Icons.timeline, Icons.source_outlined]);
    } else {
      icons.add(Icons.timeline);
    }
    icons.add(Icons.apartment);
    if (dest != 'property developer') {
      icons.add(Icons.calendar_today);
    }
    icons.add(Icons.more_horiz);

    final items = List<Widget>.generate(icons.length, (i) {
      final selected = i == _currentIndex;
      return Icon(icons[i], size: 24, color: selected ? selectedIconColor : unselectedIconColor);
    });

    return Scaffold(
      extendBody: true, // <-- THIS IS THE MAGIC LINE! It lets the body go under the nav bar.
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        items: items,
        onTap: setCurrentIndex,
        backgroundColor: Colors.transparent,
        color: navBarColor,
        buttonBackgroundColor: navButtonColor,
      ),
    );
  }
}
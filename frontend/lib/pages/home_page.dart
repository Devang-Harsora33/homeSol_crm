import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../components/sidebar.dart';
import '../components/property_cards_component.dart';
import '../models/project.dart';
import '../models/developer.dart';
import '../models/app_asset.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/shift_service.dart';
import '../services/apis/workforces/workforce.dart';
import '../services/notification_manager.dart';
import 'notifications_page.dart';
import 'finance/construction_finance_form_page.dart';

class HomePage extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final List<Project> projects;
  final List<Developer> developers;
  final List<AppAsset> appAssets;
  final Future<void> Function() onRefresh;
  final String? employeeId;
  final String? designation;
  final String? developerId;
  final String initialAttendanceStatus;
  final DateTime? initialLastPunchTime;
  final Map<String, dynamic>? userShift;
  final bool isLoadingData; // New parameter

  const HomePage({
    super.key,
    this.onNavigateToTab,
    required this.projects,
    required this.developers,
    required this.appAssets,
    required this.onRefresh,
    this.employeeId,
    this.designation,
    this.developerId,
    required this.initialAttendanceStatus,
    this.initialLastPunchTime,
    this.userShift,
    this.isLoadingData = false, // Default to false
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSidebarOpen = false;

  // State moved from MainNavigation
  String _attendanceStatus = 'OUT'; // Default status
  DateTime? _lastPunchTime; // Can remain nullable, but not late
  late Map<String, dynamic>? _userShift;
  bool _isCheckInButtonEnabled = false;
  bool _isCheckOutButtonEnabled = false;
  bool _isAttendanceLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('home_page');

    // Initialize shift data from widget properties
    _userShift = widget.userShift;
    _attendanceStatus = widget.initialAttendanceStatus;
    if (widget.initialLastPunchTime != null) {
      _lastPunchTime = widget.initialLastPunchTime;
    }

    final initialButtonStates = _calculateButtonStates(
      _userShift,
      _attendanceStatus,
    );
    _isCheckInButtonEnabled = initialButtonStates['checkIn']!;
    _isCheckOutButtonEnabled = initialButtonStates['checkOut']!;

    // Load cached status first so UI doesn't blink
    _loadCachedAttendanceStatus();

    // Fetch and set the initial attendance status from the backend
    _fetchAndSetInitialAttendanceStatus();

    // Start the timer to periodically update button states
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Recalculate button states periodically, but don't re-fetch attendance status
      final newButtonStates = _calculateButtonStates(
        _userShift,
        _attendanceStatus,
      );
      if (newButtonStates['checkIn'] != _isCheckInButtonEnabled ||
          newButtonStates['checkOut'] != _isCheckOutButtonEnabled) {
        setState(() {
          _isCheckInButtonEnabled = newButtonStates['checkIn']!;
          _isCheckOutButtonEnabled = newButtonStates['checkOut']!;
        });
      }
    });
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userShift != oldWidget.userShift) {
      _userShift = widget.userShift;
      final buttonStates = _calculateButtonStates(
        _userShift,
        _attendanceStatus,
      );
      setState(() {
        _isCheckInButtonEnabled = buttonStates['checkIn']!;
        _isCheckOutButtonEnabled = buttonStates['checkOut']!;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- Start of SharedPreferences Cache logic ---
  Future<void> _loadCachedAttendanceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStatus = prefs.getString('cached_attendance_status');
    final cachedTime = prefs.getString('cached_last_punch_time');

    if (cachedStatus != null && mounted) {
      // Only use cache if the initial status from navigation was the default 'OUT'
      // This prevents old cache from overriding a fresh 'IN' status fetched during app startup
      if (widget.initialAttendanceStatus == 'OUT') {
        setState(() {
          _attendanceStatus = cachedStatus;
          if (cachedTime != null) {
            _lastPunchTime = DateTime.tryParse(cachedTime);
          }
          final buttonStates = _calculateButtonStates(
            _userShift,
            _attendanceStatus,
          );
          _isCheckInButtonEnabled = buttonStates['checkIn']!;
          _isCheckOutButtonEnabled = buttonStates['checkOut']!;
        });
      }
    }
  }

  Future<void> _cacheAttendanceStatus(String status, DateTime? time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_attendance_status', status);
    if (time != null) {
      await prefs.setString('cached_last_punch_time', time.toIso8601String());
    } else {
      await prefs.remove('cached_last_punch_time');
    }
  }
  // --- End of SharedPreferences Cache logic ---

  // --- Start of new method to fetch initial attendance status ---
  Future<void> _fetchAndSetInitialAttendanceStatus() async {
    if (widget.employeeId == null ||
        (widget.designation?.toLowerCase() ?? '') == 'property developer' ||
        (widget.designation?.toLowerCase() ?? '') == 'lead caller')
      return;

    // We can just rely on the same robust logic in _refreshAttendanceStatus
    // which now checks specifically for today's logs.
    await _refreshAttendanceStatus();
  }
  // --- End of new method to fetch initial attendance status ---

  void _toggleSidebar() {
    setState(() => _isSidebarOpen = !_isSidebarOpen);
  }

  void _closeSidebar() {
    setState(() => _isSidebarOpen = false);
  }

  // --- Start of logic moved from MainNavigation ---

  Map<String, bool> _calculateButtonStates(
    Map<String, dynamic>? userShift,
    String attendanceStatus,
  ) {
    if (userShift == null) {
      return {'checkIn': false, 'checkOut': false};
    }
    final now = DateTime.now();
    final startTime = _parseTime(userShift['start_time']);
    final endTime = _parseTime(userShift['end_time']);
    if (startTime == null || endTime == null) {
      return {'checkIn': false, 'checkOut': false};
    }
    DateTime effectiveEndTime = endTime;
    if (endTime.isBefore(startTime)) {
      effectiveEndTime = endTime.add(const Duration(days: 1));
    }
    final isCurrentlyCheckedIn = attendanceStatus == 'IN';
    final newCheckInState =
        !isCurrentlyCheckedIn &&
        now.isAfter(startTime.subtract(const Duration(minutes: 60))) &&
        now.isBefore(effectiveEndTime);
    final newCheckOutState = isCurrentlyCheckedIn;
    return {'checkIn': newCheckInState, 'checkOut': newCheckOutState};
  }

  DateTime? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleAttendanceAction() async {
    if (widget.employeeId == null || _userShift == null) return;

    final newType = _attendanceStatus == 'IN' ? 'OUT' : 'IN';
    final now = DateTime.now();
    final startTime = _parseTime(_userShift!['start_time']);
    final endTime = _parseTime(_userShift!['end_time']);

    if (startTime == null || endTime == null) return;

    DateTime effectiveEndTime = endTime;
    if (endTime.isBefore(startTime)) {
      effectiveEndTime = endTime.add(const Duration(days: 1));
    }

    final checkInEnd = startTime.add(const Duration(minutes: 60));
    final checkOutEnd = effectiveEndTime.add(const Duration(minutes: 60));

    bool isLate = false;
    if (newType == 'IN' && now.isAfter(checkInEnd)) {
      isLate = true;
    }
    if (newType == 'OUT' && now.isAfter(checkOutEnd)) {
      isLate = true;
    }

    String? remark;
    if (isLate) {
      remark = await _showLateRemarkPopup(context, newType);
      if (remark == null || remark.trim().isEmpty) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: "Remark cannot be empty for late attendance.",
            isError: false,
            title: 'Notice',
          );
        }
        return;
      }
    }

    if (widget.employeeId != null) {
      final locationResult = await _checkEmployeeLocation(
        widget.employeeId!,
        newType,
      );

      if (locationResult['error'] != null) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: "${locationResult['error']}",
            isError: true,
            title: 'Location Error',
          );
        }
        return;
      }

      if (!locationResult['inRange']) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                "You are out of range: ${locationResult['distance'].toStringAsFixed(2)} km away from project.",
            isError: false,
            title: 'Notice',
          );
        }
        return;
      }
    }

    await _performAttendanceAction(newType, remark);
  }

  Future<Map<String, dynamic>> _checkEmployeeLocation(
    String employeeId,
    String logType,
  ) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Please turn on GPS in your device settings.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      if (widget.projects.isEmpty) {
        print("Employee is not assigned to a project.");
        return {'inRange': true, 'distance': 0.0};
      }

      double closestOverallDistance = double.infinity;
      bool inRangeOverall = false;

      for (final assignedProject in widget.projects) {
        print('DEBUG CHECKIN: Checking project ${assignedProject.projectName}');

        final targetGeoStr =
            assignedProject.loginCoordinates ?? assignedProject.location;

        if (targetGeoStr == null || targetGeoStr.isEmpty) {
          print("Project ${assignedProject.projectName} has no location data.");
          continue;
        }

        try {
          final projectLocationJson =
              jsonDecode(targetGeoStr) as Map<String, dynamic>;
          final features =
              projectLocationJson['features'] as List<dynamic>? ?? [];

          for (var feature in features) {
            final geometry = feature['geometry'];
            final type = geometry['type'];
            final coordinates = geometry['coordinates'];

            List<Map<String, double>> pointsToCheck = [];

            if (type == 'Point') {
              pointsToCheck.add({
                'lat': (coordinates[1] as num).toDouble(),
                'lng': (coordinates[0] as num).toDouble(),
              });
            } else if (type == 'Polygon') {
              for (var ring in coordinates) {
                for (var point in ring) {
                  pointsToCheck.add({
                    'lat': (point[1] as num).toDouble(),
                    'lng': (point[0] as num).toDouble(),
                  });
                }
              }
            }

            print(
              'DEBUG CHECKIN: Found ${pointsToCheck.length} points to check for ${assignedProject.projectName} (Type: $type)',
            );

            for (var p in pointsToCheck) {
              final double projectLat = p['lat']!;
              final double projectLon = p['lng']!;

              double distanceInMeters = Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                projectLat,
                projectLon,
              );
              double distanceInKm = distanceInMeters / 1000;

              print(
                'DEBUG CHECKIN: Checking coordinate ($projectLat, $projectLon) - Distance: $distanceInKm km',
              );

              if (distanceInKm < closestOverallDistance) {
                closestOverallDistance = distanceInKm;
              }

              if (distanceInKm <= 0.35) {
                // 350 meters
                print(
                  'DEBUG CHECKIN: ✅ MATCH FOUND! Picking coordinate ($projectLat, $projectLon) for ${assignedProject.projectName}. Distance is $distanceInKm km (<= 0.35 km)',
                );
                inRangeOverall = true;
                break;
              }
            }
            if (inRangeOverall) break;
          }
        } catch (e) {
          print("Error parsing project location: $e");
        }

        if (inRangeOverall) break;
      }

      print(
        "Closest distance to any assigned project: $closestOverallDistance km",
      );

      return {
        'inRange': inRangeOverall,
        'distance': closestOverallDistance == double.infinity
            ? 0.0
            : closestOverallDistance,
      };
    } catch (e) {
      print("Error checking employee location: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains('TimeoutException')) {
        errorMsg =
            'Timeout while getting location. Please make sure your device GPS is turned on and try again.';
      } else if (errorMsg.contains('Location services are disabled')) {
        errorMsg = 'Please turn on GPS in your device settings.';
      } else if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.replaceFirst('Exception: ', '');
      }
      return {'inRange': false, 'distance': 0.0, 'error': errorMsg};
    }
  }

  Future<String?> _showLateRemarkPopup(
    BuildContext context,
    String type,
  ) async {
    final remarkController = TextEditingController();
    final List<String> quickReasons = [
      'Traffic',
      'Public Transport Delay',
      'Medical Emergency',
      'Meeting',
    ];

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isSubmitEnabled = remarkController.text.trim().isNotEmpty;
            final theme = Theme.of(context);
            final isCheckIn = type == 'IN';

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color(0xFFFFFFFF),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.access_time_filled_rounded,
                            color: Colors.orange,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Late Check-${isCheckIn ? 'In' : 'Out'}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Please provide a reason.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Quick Select',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: quickReasons.map((reason) {
                        return InkWell(
                          onTap: () {
                            remarkController.text = reason;
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.dividerColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: remarkController,
                      maxLines: null,
                      minLines: 2,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Type your reason here...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: const Color.fromARGB(255, 244, 244, 244),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface
                                .withOpacity(0.7),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSubmitEnabled
                              ? () => Navigator.of(
                                  context,
                                ).pop(remarkController.text)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _performAttendanceAction(String newType, String? remark) async {
    if (widget.employeeId == null) return;
    setState(() => _isAttendanceLoading = true);
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';
      String deviceType = '';
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceType = 'Android';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'UnknownID';
        deviceType = 'iOS';
      }
      Map<String, dynamic> result;
      if (newType == 'IN') {
        result = await ShiftService.checkIn(
          deviceId,
          deviceType,
          remark: remark,
        );
      } else {
        result = await ShiftService.checkOut(
          deviceId,
          deviceType,
          remark: remark,
        );
      }
      if (result['success'] && mounted) {
        final optimisticButtonStates = _calculateButtonStates(
          _userShift,
          newType,
        );
        final newLastPunchTime = DateTime.now();
        _cacheAttendanceStatus(newType, newLastPunchTime);
        setState(() {
          _attendanceStatus = newType;
          _lastPunchTime = newLastPunchTime;
          _isCheckInButtonEnabled = optimisticButtonStates['checkIn']!;
          _isCheckOutButtonEnabled = optimisticButtonStates['checkOut']!;
        });
      } else {
        if (mounted && result['message'] != null) {
          CustomSnackBar.show(
            context,
            message: "Error: ${result['message']}",
            isError: true,
            title: 'Error',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "An error occurred: $e",
          isError: true,
          title: 'Error',
        );
      }
    } finally {
      if (mounted) setState(() => _isAttendanceLoading = false);
    }
  }

  Future<void> _refreshAttendanceStatus() async {
    if (widget.employeeId == null) return;
    try {
      final cookie = await AuthService.getCookie();
      final realEmployeeId = await WorkforceService.getTrueEmployeeId();

      final logUrl = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_checkins?days=0',
      );
      var logRes = await http.get(logUrl, headers: {'Cookie': cookie ?? ''});

      if (logRes.statusCode == 200) {
        var logData = jsonDecode(logRes.body);
        final checkins = logData['message'] as List?;

        if (mounted && checkins != null && checkins.isNotEmpty) {
          final profile = await AuthService.getMyProfile();
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

          final myCheckins = checkins
              .where(
                (log) =>
                    (log['owner'] != null &&
                        profile?.userId != null &&
                        profile!.userId.isNotEmpty &&
                        log['owner'] == profile.userId) ||
                    (log['employee'] != null &&
                        log['employee'] == profile?.name) ||
                    (log['employee'] != null &&
                        log['employee'] == realEmployeeId) ||
                    (log['employee'] != null &&
                        log['employee'] == widget.employeeId) ||
                    (log['employee_name'] != null &&
                        profile?.employeeName != null &&
                        log['employee_name'] == profile?.employeeName) ||
                    (log['employee_name'] != null &&
                        profile?.firstName != null &&
                        profile!.firstName.isNotEmpty &&
                        log['employee_name'].toString().toLowerCase().contains(
                          profile.firstName.toLowerCase(),
                        ) &&
                        (profile.lastName == null ||
                            profile.lastName!.isEmpty ||
                            log['employee_name']
                                .toString()
                                .toLowerCase()
                                .contains(profile.lastName!.toLowerCase()))) ||
                    (currentDeviceId.isNotEmpty &&
                        log['device_id'] == currentDeviceId),
              )
              .toList();

          if (myCheckins.isNotEmpty) {
            myCheckins.sort(
              (a, b) => b['time'].toString().compareTo(a['time'].toString()),
            );
            final lastLog = myCheckins.first;

            final lastLogTime = lastLog['time'] != null
                ? DateTime.parse(lastLog['time'])
                : null;

            // Verify the last log occurred today
            bool isToday = false;
            if (lastLogTime != null) {
              final now = DateTime.now();
              if (lastLogTime.year == now.year &&
                  lastLogTime.month == now.month &&
                  lastLogTime.day == now.day) {
                isToday = true;
              }
            }

            final newStatus = isToday ? (lastLog['log_type'] ?? 'OUT') : 'OUT';
            final newLastPunchTime = isToday ? lastLogTime : null;
            final buttonStates = _calculateButtonStates(_userShift, newStatus);

            _cacheAttendanceStatus(newStatus, newLastPunchTime);
            setState(() {
              _attendanceStatus = newStatus;
              _lastPunchTime = newLastPunchTime;
              _isCheckInButtonEnabled = buttonStates['checkIn']!;
              _isCheckOutButtonEnabled = buttonStates['checkOut']!;
            });
          } else {
            final buttonStates = _calculateButtonStates(_userShift, 'OUT');

            _cacheAttendanceStatus('OUT', null);
            setState(() {
              _attendanceStatus = 'OUT';
              _lastPunchTime = null;
              _isCheckInButtonEnabled = buttonStates['checkIn']!;
              _isCheckOutButtonEnabled = buttonStates['checkOut']!;
            });
          }
        }
      }
    } catch (e) {
      print("Error refreshing attendance status: $e");
    }
  }

  // --- End of logic moved from MainNavigation ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      onProfileTap: _toggleSidebar,
                      onRefresh: widget.onRefresh,
                    ),
                  ),

                  if (widget.employeeId != null &&
                      (widget.designation?.toLowerCase() ?? '') !=
                          'property developer' &&
                      (widget.designation?.toLowerCase() ?? '') !=
                          'lead caller' &&
                      (widget.designation?.toLowerCase() ?? '') !=
                          'admin')
                    SliverToBoxAdapter(
                      child: _AttendanceCard(
                        status: _attendanceStatus,
                        lastTime: _lastPunchTime,
                        isLoading: _isAttendanceLoading,
                        onTap: _handleAttendanceAction,
                        isCheckInEnabled: _isCheckInButtonEnabled,
                        isCheckOutEnabled: _isCheckOutButtonEnabled,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) {
                        final isPropertyDeveloper =
                            (widget.designation?.toLowerCase() ?? '') ==
                            'property developer';
                        final bannerAssets = widget.appAssets
                            .where((asset) => asset.assetCategory == 'Banner')
                            .toList();

                        if (isPropertyDeveloper) {
                          bannerAssets.insert(
                            0,
                            AppAsset(
                              name: 'FUND_RAISING',
                              assetName: 'Fund Raising Application',
                              assetCategory: 'Banner',
                              assetFile: '',
                              fullUrl: '',
                            ),
                          );
                        }

                        return _BannerCarousel(
                          banners: bannerAssets,
                          onBannerTap: (banner) {
                            if (banner.name == 'FUND_RAISING') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ConstructionFinanceFormPage(
                                        developerId: widget.developerId ?? '',
                                        projects: widget.projects.where((p) {
                                          final name = p.projectName
                                              .toLowerCase()
                                              .trim();
                                          return name != 'bhavin steel' &&
                                              name != 'parinee i';
                                        }).toList(),
                                      ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 1)),
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) {
                        final visibleProjectsForUI = widget.projects.where((p) {
                          final name = p.projectName.toLowerCase().trim();
                          return name != 'bhavin steel' && name != 'parinee i';
                        }).toList();

                        return PropertyCardsComponent(
                          projects: visibleProjectsForUI,
                          developers: widget.developers,
                          isLoading: widget.isLoadingData,
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          Sidebar(
            isOpen: _isSidebarOpen,
            onClose: _closeSidebar,
            developerId: widget.developerId,
            designation: widget.designation,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onProfileTap;
  final Future<void> Function() onRefresh;

  const _Header({required this.onProfileTap, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final secondary = theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/logo/logo.png', width: 32, height: 32),
              const SizedBox(width: 12),
              Text(
                'HomeSol',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'by HomeSol India',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          Row(
            children: [
              AnimatedBuilder(
                animation: NotificationManager.instance,
                builder: (context, _) {
                  final unreadCount = NotificationManager.instance.unreadCount;
                  final hasUnread = unreadCount > 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
                            ),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: hasUnread
                                ? const Color(0xFFddbe6c).withOpacity(0.15)
                                : onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: hasUnread
                                ? Border.all(
                                    color: const Color(
                                      0xFFddbe6c,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Icon(
                            hasUnread
                                ? Icons.notifications_active
                                : Icons.notifications_outlined,
                            color: hasUnread
                                ? const Color(0xFFddbe6c)
                                : onSurface.withOpacity(0.9),
                            size: 22,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFddbe6c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: onSurface.withOpacity(0.9),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final String status;
  final DateTime? lastTime;
  final bool isLoading;
  final VoidCallback onTap;
  final bool isCheckInEnabled;
  final bool isCheckOutEnabled;

  const _AttendanceCard({
    required this.status,
    required this.isLoading,
    required this.onTap,
    this.lastTime,
    required this.isCheckInEnabled,
    required this.isCheckOutEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCheckedIn = status == 'IN';
    final activeColor = const Color(0xFFddbe6c);

    bool isButtonEnabled = isCheckedIn ? isCheckOutEnabled : isCheckInEnabled;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCheckedIn
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCheckedIn ? Icons.access_time_filled : Icons.history_toggle_off,
              color: isCheckedIn ? Colors.green : Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckedIn ? 'You are Clocked In' : 'You are Clocked Out',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (lastTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last punch: ${lastTime!.hour}:${lastTime!.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isLoading || !isButtonEnabled ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCheckedIn ? Colors.redAccent : activeColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isCheckedIn ? 'Check Out' : 'Check In',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<AppAsset> banners;
  final void Function(AppAsset)? onBannerTap;

  const _BannerCarousel({required this.banners, this.onBannerTap});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_currentPage < widget.banners.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            double bannerHeight = 180;
            if (constraints.maxWidth > 600) {
              bannerHeight = constraints.maxWidth / 2.5;
              if (bannerHeight > 400) bannerHeight = 400; // Cap max height
            }
            return SizedBox(
              height: bannerHeight,
              child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (widget.onBannerTap != null) {
                      widget.onBannerTap!(banner);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: banner.name == 'FUND_RAISING'
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF0F172A), // Very dark slate/blue
                                  Color(0xFF1E293B), // Dark slate
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Background accent 1
                                Positioned(
                                  top: -40,
                                  right: -30,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                                // Background icon
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Transform.rotate(
                                    angle: -0.2,
                                    child: Icon(
                                      Icons.domain_add_rounded,
                                      size: 140,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.15),
                                    ),
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                    vertical: 20.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.auto_graph_rounded,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'EXCLUSIVE',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Project Finance',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              height: 1.1,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fast-track capital for your next big build.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white70),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Apply Now',
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 16,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: banner.fullUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.withOpacity(0.1),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.withOpacity(0.1),
                              child: const Icon(Icons.error_outline),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
    Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.banners.asMap().entries.map((entry) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(
                  _currentPage == entry.key ? 0.9 : 0.2,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

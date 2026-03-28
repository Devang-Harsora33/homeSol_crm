import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

import '../components/sidebar.dart';
import '../components/property_cards_component.dart';
import '../models/project.dart';
import '../models/developer.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/shift_service.dart';

class HomePage extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final List<Project> projects;
  final List<Developer> developers;
  final Future<void> Function() onRefresh;
  final String? employeeId;
  final String initialAttendanceStatus;
  final DateTime? initialLastPunchTime;
  final Map<String, dynamic>? userShift;
  final bool isLoadingData; // New parameter

  const HomePage({
    super.key,
    this.onNavigateToTab,
    required this.projects,
    required this.developers,
    required this.onRefresh,
    this.employeeId,
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

    // Fetch and set the initial attendance status from the backend
    _fetchAndSetInitialAttendanceStatus();

    // Start the timer to periodically update button states
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Recalculate button states periodically, but don't re-fetch attendance status
      final newButtonStates = _calculateButtonStates(_userShift, _attendanceStatus);
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
      final buttonStates = _calculateButtonStates(_userShift, _attendanceStatus);
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

  // --- Start of new method to fetch initial attendance status ---
  Future<void> _fetchAndSetInitialAttendanceStatus() async {
    if (widget.employeeId == null) return; // Ensure employeeId is available

    try {
      final cookie = await AuthService.getCookie();
      final headers = {'Cookie': cookie ?? ''};

      // Fetch last Check-IN
      final Uri lastInLogUrl = Uri.parse(
          '${AuthService.baseUrl}/api/resource/Employee Checkin?fields=["time","log_type"]&filters=[["employee","=","${widget.employeeId}"],["log_type","=","IN"]]&order_by=time%20desc&limit_page_length=1');
      final http.Response inResponse = await http.get(lastInLogUrl, headers: headers);
      final Map<String, dynamic> inLogData = (inResponse.statusCode == 200) ? json.decode(inResponse.body) : {'data': []};
      final DateTime? lastInTime = (inLogData['data']?.isNotEmpty ?? false)
          ? DateTime.tryParse(inLogData['data'][0]['time'])
          : null;

      // Fetch last Check-OUT
      final Uri lastOutLogUrl = Uri.parse(
          '${AuthService.baseUrl}/api/resource/Employee Checkin?fields=["time","log_type"]&filters=[["employee","=","${widget.employeeId}"],["log_type","=","OUT"]]&order_by=time%20desc&limit_page_length=1');
      final http.Response outResponse = await http.get(lastOutLogUrl, headers: headers);
      final Map<String, dynamic> outLogData = (outResponse.statusCode == 200) ? json.decode(outResponse.body) : {'data': []};
      final DateTime? lastOutTime = (outLogData['data']?.isNotEmpty ?? false)
          ? DateTime.tryParse(outLogData['data'][0]['time'])
          : null;

      String newAttendanceStatus;
      DateTime? newLastPunchTime;

      // Determine current status based on the latest IN/OUT log
      if (lastInTime != null && (lastOutTime == null || lastInTime.isAfter(lastOutTime))) {
        newAttendanceStatus = 'IN'; // Last action was IN (or IN exists and OUT doesn't)
        newLastPunchTime = lastInTime;
      } else if (lastOutTime != null && (lastInTime == null || lastOutTime.isAfter(lastInTime))) {
        newAttendanceStatus = 'OUT'; // Last action was OUT (or OUT exists and IN doesn't)
        newLastPunchTime = lastOutTime;
      } else {
        // Default to OUT if no logs or logs are ambiguous
        newAttendanceStatus = 'OUT';
        newLastPunchTime = null; // No clear last punch time
      }

      // Update state and recalculate button states
      if (mounted) {
        setState(() {
          _attendanceStatus = newAttendanceStatus;
          _lastPunchTime = newLastPunchTime;
          final buttonStates = _calculateButtonStates(_userShift, _attendanceStatus);
          _isCheckInButtonEnabled = buttonStates['checkIn']!;
          _isCheckOutButtonEnabled = buttonStates['checkOut']!;
        });
      }

    } catch (e) {
      print("Error fetching initial attendance status: $e");
      // Optionally show a snackbar or other error handling
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to fetch attendance status: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // --- End of new method to fetch initial attendance status ---

 void _toggleSidebar() {

    setState(() => _isSidebarOpen = !_isSidebarOpen);

  }

  void _closeSidebar() {
    setState(() => _isSidebarOpen = false);
  }
  
  // --- Start of logic moved from MainNavigation ---

  Map<String, bool> _calculateButtonStates(Map<String, dynamic>? userShift, String attendanceStatus) {
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
    final newCheckInState = !isCurrentlyCheckedIn &&
        now.isAfter(startTime) &&
        now.isBefore(effectiveEndTime);
    final newCheckOutState = isCurrentlyCheckedIn;
    return {'checkIn': newCheckInState, 'checkOut': newCheckOutState};
  }

  DateTime? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]),
          int.parse(parts[1]), int.parse(parts[2]));
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

    final checkInEnd = startTime.add(const Duration(minutes: 15));
    final checkOutEnd = effectiveEndTime.add(const Duration(minutes: 15));

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Remark cannot be empty for late attendance."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    if (widget.employeeId != null) {
      final locationResult = await _checkEmployeeLocation(widget.employeeId!, newType);

      if (!locationResult['inRange']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "You are out of range: ${locationResult['distance'].toStringAsFixed(2)} km away from project.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
       if (locationResult['error'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location Error: ${locationResult['error']}"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    await _performAttendanceAction(newType, remark);
  }

  Future<Map<String, dynamic>> _checkEmployeeLocation(String employeeId, String logType) async {
    try {
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
      );

      final assignedProject = widget.projects.isNotEmpty ? widget.projects.first : null;

      if (assignedProject == null || assignedProject.location == null) {
        print("Employee is not assigned to a project with location data.");
        return {'inRange': true, 'distance': 0.0};
      }

      double projectLat = 0.0;
      double projectLon = 0.0;
      try {
        final projectLocationJson = jsonDecode(assignedProject.location!) as Map<String, dynamic>;
        final coordinates = projectLocationJson['features'][0]['geometry']['coordinates'] as List<dynamic>;
        projectLon = coordinates[0];
        projectLat = coordinates[1];
      } catch (e) {
        print("Error parsing project location: $e");
        return {'inRange': true, 'distance': 0.0};
      }

      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        projectLat,
        projectLon,
      );

      double distanceInKm = distanceInMeters / 1000;
      print("Project ${assignedProject.projectName} Location: $projectLat, $projectLon");
      print("Distance to Project ${assignedProject.projectName}: $distanceInKm km");

      const double allowedCheckinRangeKm = 0.35; // 350 meters
      bool inRange = distanceInKm <= allowedCheckinRangeKm;

      return {'inRange': inRange, 'distance': distanceInKm};
    } catch (e) {
      print("Error checking employee location: $e");
      return {'inRange': false, 'distance': 0.0, 'error': e.toString()};
    }
  }


  Future<String?> _showLateRemarkPopup(BuildContext context, String type) async {
    final remarkController = TextEditingController();
    final List<String> quickReasons = ['Traffic', 'Public Transport Delay', 'Medical Emergency', 'Meeting'];

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isSubmitEnabled = remarkController.text.trim().isNotEmpty;
            final theme = Theme.of(context);
            final isCheckIn = type == 'IN';

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          child: const Icon(Icons.access_time_filled_rounded, color: Colors.orange, size: 28),
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
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.hintColor),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: remarkController,
                      maxLines: 3,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Type your reason here...',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                        filled: true,
                        fillColor: const Color.fromARGB(255, 244, 244, 244),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
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
                            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSubmitEnabled
                              ? () => Navigator.of(context).pop(remarkController.text)
                              : null,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        result = await ShiftService.checkIn(deviceId, deviceType, remark: remark);
      } else {
        result = await ShiftService.checkOut(deviceId, deviceType, remark: remark);
      }
      if (result['success'] && mounted) {
        final optimisticButtonStates = _calculateButtonStates(_userShift, newType);
        setState(() {
          _attendanceStatus = newType;
          _lastPunchTime = DateTime.now();
          _isCheckInButtonEnabled = optimisticButtonStates['checkIn']!;
          _isCheckOutButtonEnabled = optimisticButtonStates['checkOut']!;
        });
      } else {
         if (mounted && result['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${result['message']}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: $e"),
            backgroundColor: Colors.red,
          ),
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
      final filters = jsonEncode([
        ['employee', '=', widget.employeeId!]
      ]);
      final logUrl = Uri.parse(
          '${AuthService.baseUrl}/api/resource/Employee Checkin?filters=$filters&order_by=time desc&limit=1');
      final logRes = await http.get(logUrl, headers: {'Cookie': cookie ?? ''});

      if (logRes.statusCode == 200) {
        final logData = jsonDecode(logRes.body);
        if (mounted) {
          if (logData['data'] != null && logData['data'].isNotEmpty) {
            final lastLog = logData['data'][0];
            final newStatus = lastLog['log_type'] ?? 'OUT';
            final buttonStates = _calculateButtonStates(_userShift, newStatus);
            setState(() {
              _attendanceStatus = newStatus;
              _lastPunchTime = lastLog['time'] != null
                  ? DateTime.parse(lastLog['time'])
                  : null;
              _isCheckInButtonEnabled = buttonStates['checkIn']!;
              _isCheckOutButtonEnabled = buttonStates['checkOut']!;
            });
          } else {
             final buttonStates = _calculateButtonStates(_userShift, 'OUT');
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
                  if (widget.employeeId != null)
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
                  const SliverToBoxAdapter(child: SizedBox(height: 1)),
                  SliverToBoxAdapter(
                    child: PropertyCardsComponent(
                      projects: widget.projects,
                      developers: widget.developers,
                      isLoading: widget.isLoadingData,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          Sidebar(isOpen: _isSidebarOpen, onClose: _closeSidebar),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'HS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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

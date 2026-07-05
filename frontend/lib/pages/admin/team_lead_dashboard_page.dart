import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/team_attendance.dart';
import '../../models/team_checkin.dart';
import '../../models/sales_team.dart';
import '../../models/project.dart';
import '../../services/apis/team/team_service.dart';
import '../../services/apis/projects/project_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class TeamLeadDashboardPage extends StatefulWidget {
  const TeamLeadDashboardPage({super.key});

  @override
  State<TeamLeadDashboardPage> createState() => _TeamLeadDashboardPageState();
}

const Color goldAccent = Color(0xFF675D40);
const Color matteBlack = Color(0xFF1A1A1A);

class _TeamLeadDashboardPageState extends State<TeamLeadDashboardPage> {
  bool _isLoading = true;
  List<TeamAttendance> _attendances = [];
  List<TeamCheckin> _checkins = [];
  String _selectedTab = 'Check-ins'; // 'Check-ins' or 'Attendance'
  int _selectedDays = 7;
  final List<int> _durationOptions = [0, 7, 15, 30, 45, 60];

  // Filters
  String? _selectedUserFilter;
  String? _selectedProjectFilterForUser;
  List<SalesTeam> _salesTeams = [];
  List<Project> _projects = [];
  String? _currentBrokerId;
  String? _currentEmployeeId;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _getUserInfo();
    await _loadProjects();
    await _loadSalesTeams();
    await _fetchData();
  }

  Future<void> _getUserInfo() async {
    try {
      final profile = await AuthService.getMyProfile();
      if (profile != null) {
        setState(() {
          _currentEmployeeId = profile.employee;
          _currentUserEmail = profile.userId;
          _currentBrokerId = profile.employee; // Fallback
        });
      }
      final userData = await AuthService.getUserData();
      if (userData != null && userData['broker_id'] != null) {
        setState(() {
          _currentBrokerId = userData['broker_id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error getting user info: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final fetchedProjects = await ProjectService.syncProjects();
      setState(() {
        _projects = fetchedProjects;
      });
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  Future<void> _loadSalesTeams() async {
    try {
      final teams = await ApiService.syncSalesTeams();
      setState(() {
        _salesTeams = teams;
      });
    } catch (e) {
      debugPrint('Error loading sales teams: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      if (_selectedTab == 'Check-ins') {
        final checkins = await TeamService.fetchTeamCheckins(days: _selectedDays);
        setState(() {
          _checkins = checkins;
          _isLoading = false;
        });
      } else {
        final attendances = await TeamService.fetchTeamAttendances(days: _selectedDays);
        setState(() {
          _attendances = attendances;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching team lead data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Team Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: matteBlack,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToggle(),
          _buildDurationSelector(),
          _buildUserFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: goldAccent))
                : _selectedTab == 'Check-ins'
                    ? _buildCheckinsList()
                    : _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _toggleButton('Check-ins', _selectedTab == 'Check-ins'),
          _toggleButton('Attendance', _selectedTab == 'Attendance'),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != label) {
            setState(() {
              _selectedTab = label;
            });
            _fetchData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? goldAccent : Colors.black54,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    final double sliderValue = _durationOptions.indexOf(_selectedDays).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Duration: ${_selectedDays == 0 ? "Today" : "$_selectedDays Days"}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: matteBlack),
              ),
              const Icon(Icons.timer_outlined, size: 16, color: goldAccent),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: goldAccent,
              inactiveTrackColor: goldAccent.withOpacity(0.1),
              thumbColor: goldAccent,
              overlayColor: goldAccent.withOpacity(0.2),
              tickMarkShape: const RoundSliderTickMarkShape(),
              activeTickMarkColor: goldAccent,
              inactiveTickMarkColor: goldAccent.withOpacity(0.3),
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
            ),
            child: Slider(
              value: sliderValue,
              min: 0,
              max: (_durationOptions.length - 1).toDouble(),
              divisions: _durationOptions.length - 1,
              label: _selectedDays == 0 ? "Today" : "$_selectedDays Days",
              onChanged: (value) {
                setState(() {
                  _selectedDays = _durationOptions[value.toInt()];
                });
                _fetchData();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _durationOptions.map((d) => Text(
                d == 0 ? 'T' : d.toString(),
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: d == _selectedDays ? FontWeight.bold : FontWeight.normal,
                  color: d == _selectedDays ? goldAccent : Colors.grey,
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFilter() {
    // 1. Filter sales teams where current user is a member or lead/owner
    final mySalesTeams = _salesTeams.where((team) {
      bool isOwner = (_currentUserEmail != null && team.owner == _currentUserEmail) ||
                     (_currentBrokerId != null && team.owner == _currentBrokerId);
      
      bool isMember = team.members.any((m) => 
        (_currentUserEmail != null && m.userId != null && m.userId == _currentUserEmail) || 
        (_currentEmployeeId != null && m.employee != null && m.employee == _currentEmployeeId) ||
        (_currentBrokerId != null && (m.userId == _currentBrokerId || m.employee == _currentBrokerId))
      );
      
      return isOwner || isMember;
    }).toList();

    // 2. Get unique projects from MY sales teams
    final Set<String> projectIdsFromTeams = {};
    for (var team in mySalesTeams) {
      for (var p in team.projects) {
        projectIdsFromTeams.add(p.projects);
      }
    }
    
    final List<Project> filteredProjects = _projects.where((p) => projectIdsFromTeams.contains(p.id)).toList();

    // 3. Filter team members based on selected project (only from MY teams)
    final teamMembers = <Member>[];
    for (var team in mySalesTeams) {
      bool isMatch = _selectedProjectFilterForUser == null || 
                    team.projects.any((p) => p.projects == _selectedProjectFilterForUser);
      if (isMatch) {
        teamMembers.addAll(team.members);
      }
    }
    
    // Deduplicate by employee ID
    final uniqueMembersMap = <String, Member>{};
    for (var m in teamMembers) {
      final key = m.employee;
      
      if (!uniqueMembersMap.containsKey(key)) {
        uniqueMembersMap[key] = m;
      }
    }
    
    // Include everyone in the unique members list (including Sourcing)
    final uniqueMembers = uniqueMembersMap.values.toList();
    
    return Column(
      children: [
        // Project Selection Dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Select Project First'),
                value: _selectedProjectFilterForUser,
                icon: const Icon(Icons.apartment_rounded, color: goldAccent),
                dropdownColor: Colors.white,
                items: [
                  const DropdownMenuItem<String>(
                    value: null, 
                    child: Text('All My Projects', style: TextStyle(fontWeight: FontWeight.bold, color: matteBlack))
                  ),
                  ...filteredProjects.map((p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.projectName, style: const TextStyle(color: matteBlack)),
                  )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedProjectFilterForUser = val;
                    _selectedUserFilter = null; // Reset user filter when project changes
                  });
                },
              ),
            ),
          ),
        ),
        
        // User Selection Dropdown (Only shown if members are available)
        if (uniqueMembers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text(_selectedProjectFilterForUser == null ? 'Select Project to filter users' : 'All Sales Persons'),
                  value: _selectedUserFilter,
                  icon: const Icon(Icons.person_outline, color: goldAccent),
                  dropdownColor: Colors.white,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null, 
                      child: Text('All Sales Persons', style: TextStyle(fontWeight: FontWeight.bold, color: matteBlack))
                    ),
                    ...uniqueMembers.map((m) {
                      bool isMe = (_currentEmployeeId != null && m.employee == _currentEmployeeId) ||
                                  (_currentBrokerId != null && m.employee == _currentBrokerId);
                      return DropdownMenuItem<String>(
                        value: m.employee,
                        child: Text(isMe ? '${m.employeeName} (Me)' : m.employeeName, style: const TextStyle(color: matteBlack)),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedUserFilter = val),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckinsList() {
    List<TeamCheckin> filtered = _checkins;

    // Filter by project-based users if a project/user is selected
    if (_selectedProjectFilterForUser != null || _selectedUserFilter != null) {
      final Set<String> targetEmployeeIds = {};
      if (_selectedUserFilter != null) {
        targetEmployeeIds.add(_selectedUserFilter!);
      } else if (_selectedProjectFilterForUser != null) {
        // Get all members of sales teams assigned to this project
        for (var team in _salesTeams) {
          if (team.projects.any((p) => p.projects == _selectedProjectFilterForUser)) {
            for (var m in team.members) {
              targetEmployeeIds.add(m.employee);
            }
          }
        }
      }

      filtered = filtered.where((c) {
        final empId = c.employee.toLowerCase();
        return targetEmployeeIds.any((id) => id.toLowerCase() == empId);
      }).toList();
    }

    if (filtered.isEmpty) {
      return const Center(child: Text('No check-in records found for the selected filters.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final checkin = filtered[index];
        final isCheckIn = checkin.logType.toUpperCase() == 'IN';
        
        DateTime? time;
        try {
          time = DateTime.parse(checkin.time);
        } catch (_) {}

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCheckIn ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                    color: isCheckIn ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkin.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: matteBlack),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${checkin.logType} • ${time != null ? DateFormat('MMM d, h:mm a').format(time) : checkin.time}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      if (checkin.customRemark != null && checkin.customRemark!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Remark: ${checkin.customRemark}',
                            style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time != null ? DateFormat('h:mm a').format(time) : '',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: matteBlack),
                    ),
                    Text(
                      time != null ? DateFormat('MMM d').format(time) : '',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceList() {
    List<TeamAttendance> filtered = _attendances;

    // Filter by project-based users if a project/user is selected
    if (_selectedProjectFilterForUser != null || _selectedUserFilter != null) {
      final Set<String> targetEmployeeIds = {};
      if (_selectedUserFilter != null) {
        targetEmployeeIds.add(_selectedUserFilter!);
      } else if (_selectedProjectFilterForUser != null) {
        for (var team in _salesTeams) {
          if (team.projects.any((p) => p.projects == _selectedProjectFilterForUser)) {
            for (var m in team.members) {
              targetEmployeeIds.add(m.employee);
            }
          }
        }
      }

      filtered = filtered.where((a) {
        final empId = a.employee.toLowerCase();
        return targetEmployeeIds.any((id) => id.toLowerCase() == empId);
      }).toList();
    }

    if (filtered.isEmpty) {
      return const Center(child: Text('No attendance records found for the selected filters.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final attendance = filtered[index];
        final isPresent = attendance.status.toLowerCase() == 'present';
        
        DateTime? date;
        try {
          date = DateTime.parse(attendance.attendanceDate);
        } catch (_) {}

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isPresent ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attendance.employeeName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: matteBlack),
                          ),
                          Text(
                            attendance.department ?? 'Sales',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        attendance.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPresent ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _attendanceDetail('Date', date != null ? DateFormat('MMM d, yyyy').format(date) : attendance.attendanceDate),
                    _attendanceDetail('Working Hrs', '${attendance.workingHours.toStringAsFixed(1)}h'),
                    _attendanceDetail('In Time', _formatTime(attendance.inTime) ?? '--:--'),
                    _attendanceDetail('Out Time', _formatTime(attendance.outTime) ?? '--:--'),
                  ],
                ),
                if (attendance.lateEntry == 1 || attendance.earlyExit == 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (attendance.lateEntry == 1)
                        _badge('Late Entry', Colors.orange),
                      if (attendance.lateEntry == 1 && attendance.earlyExit == 1)
                        const SizedBox(width: 8),
                      if (attendance.earlyExit == 1)
                        _badge('Early Exit', Colors.redAccent),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String? _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final dt = DateTime.parse(timeStr);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return timeStr;
    }
  }

  Widget _attendanceDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: matteBlack)),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

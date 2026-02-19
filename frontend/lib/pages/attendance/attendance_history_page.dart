import 'package:Homesol/models/follow_up.dart';
import 'package:Homesol/models/lead.dart' as model_lead; // Alias Lead
import 'package:Homesol/models/project.dart' as project_model;
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/databases/lead_database.dart'; // Import LeadDatabase
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:Homesol/services/apis/workforces/workforce.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:Homesol/models/attendance_record.dart';
import 'package:Homesol/models/site_visit.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Add dart:convert

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  _AttendanceHistoryPageState createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late Future<List<AttendanceRecord>> _attendanceFuture;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<AttendanceRecord>> _events = {};

  List<SiteVisit> _siteVisits = [];
  Map<DateTime, List<SiteVisit>> _siteVisitEvents = {};
  List<SiteVisit> _selectedSiteVisits = [];

  List<project_model.Project> _projects = [];
  List<model_lead.Lead> _leads = []; // Use aliased Lead

  List<FollowUp> _followUps = [];
  Map<DateTime, List<FollowUp>> _followUpEvents = {};
  List<FollowUp> _selectedFollowUps = [];

  List<String> _teamMembers = [];
  Map<String, Color> _userColorMap = {};
  String? _currentUser;
  late LeadService _leadService; // Declare LeadService instance

  // ─── FILTER STATE VARIABLES ───
  String? _selectedFilterCategory; // 'Site Visits' or 'Follow-ups'
  String? _selectedFilterUser; // User ID (email)

  @override
  void initState() {
    super.initState();
    _leadService = LeadService(); // Initialize LeadService
    _selectedDay = _focusedDay;
    _refreshData();
  }

  Future<void> _refreshData() async {
    await _fetchAttendanceForMonth(_focusedDay.month, _focusedDay.year);
    await _fetchSiteVisits();
    await _fetchProjects();
    await _fetchLeads();
    await _fetchFollowUps();
    await _fetchTeamData();

    if (_selectedDay != null) {
      setState(() {
        _selectedSiteVisits = _siteVisits.where((visit) {
          final visitDate = DateTime.tryParse(visit.visitDate);
          return visitDate != null && isSameDay(visitDate, _selectedDay!);
        }).toList();
        _selectedFollowUps = _followUps.where((followUp) {
          final followUpDate = DateTime.tryParse(followUp.followUpDate ?? '');
          return followUpDate != null && isSameDay(followUpDate, _selectedDay!);
        }).toList();
      });
    }
  }

  Future<void> _fetchTeamData() async {
    final user = await AuthService.getUserData();
    setState(() {
      _currentUser = user?['email'];
    });
  }

  Future<void> _fetchSiteVisits() async {
    try {
      final visits = await SiteVisitService.fetchMySiteVisits();
      if (mounted) {
        setState(() {
          _siteVisits = visits;
          _siteVisitEvents = {};
          for (var visit in visits) {
            final visitDate = DateTime.tryParse(visit.visitDate);
            if (visitDate != null) {
              final date = DateTime.utc(
                visitDate.year,
                visitDate.month,
                visitDate.day,
              );
              if (_siteVisitEvents[date] == null) {
                _siteVisitEvents[date] = [];
              }
              _siteVisitEvents[date]!.add(visit);
            }
          }
          _updateTeamMembersAndColors();
        });
      }
    } catch (e) {
      print('Error fetching site visits: $e');
    }
  }

  Future<void> _fetchFollowUps() async {
    try {
      final followUps = await LeadService.syncMyFollowups();
      if (mounted) {
        setState(() {
          _followUps = followUps;
          _followUpEvents = {};
          for (var followUp in followUps) {
            final followUpDate = DateTime.tryParse(followUp.followUpDate ?? '');
            if (followUpDate != null) {
              final date = DateTime.utc(
                followUpDate.year,
                followUpDate.month,
                followUpDate.day,
              );
              if (_followUpEvents[date] == null) {
                _followUpEvents[date] = [];
              }
              _followUpEvents[date]!.add(followUp);
            }
          }
          _updateTeamMembersAndColors();
        });
      }
    } catch (e) {
      print('Error fetching follow-ups: $e');
    }
  }

  void _updateTeamMembersAndColors() {
    final siteVisitOwners = _siteVisits.map((v) => v.owner).toSet();
    final followUpOwners = _followUps
        .map((f) => f.leadName ?? 'Unknown')
        .toSet();
    final allOwners = [...siteVisitOwners, ...followUpOwners].toSet().toList();

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.cyan,
      Colors.amber,
      Colors.indigo,
      Colors.lime,
    ];

    final colorMap = <String, Color>{};
    for (var i = 0; i < allOwners.length; i++) {
      if (allOwners[i] == _currentUser) {
        colorMap[allOwners[i]] = Colors.purple;
      } else {
        colorMap[allOwners[i]] = colors[i % colors.length];
      }
    }

    setState(() {
      _teamMembers = allOwners;
      _userColorMap = colorMap;
    });
  }

  Future<void> _fetchAttendanceForMonth(int month, int year) async {
    _attendanceFuture = WorkforceService.getAttendanceHistory(month, year);
    await _attendanceFuture.then((records) {
      if (mounted) {
        setState(() {
          _events = {};
          for (var record in records) {
            final date = DateTime.utc(
              record.attendanceDate.year,
              record.attendanceDate.month,
              record.attendanceDate.day,
            );
            if (_events[date] == null) {
              _events[date] = [];
            }
            _events[date]!.add(record);
          }
        });
      }
    });
  }

  Future<void> _fetchProjects() async {
    try {
      final projects = await ProjectService.syncProjects();
      if (mounted) setState(() => _projects = projects);
    } catch (e) {
      print('Error fetching projects: $e');
    }
  }

  Future<void> _fetchLeads() async {
    try {
      await _leadService.syncMyLeads(); // Sync data from API to local DB
      final List<Map<String, dynamic>> rawLeads = await LeadDatabase().getAllLeads();
      final leads = rawLeads.map((data) {
        final leadJson = json.decode(data['data']);
        return model_lead.Lead.fromJson(leadJson);
      }).toList();
      if (mounted) setState(() => _leads = leads);
    } catch (e) {
      print('Error fetching leads: $e');
    }
  }

  String _getProjectName(String projectId) {
    try {
      final project = _projects.firstWhere((p) => p.id == projectId);
      return project.projectName;
    } catch (e) {
      return projectId;
    }
  }

  String _getLeadName(String leadId) {
    try {
      final model_lead.Lead lead = _leads.firstWhere((l) => l.name == leadId);
      return lead.leadName ?? leadId;
    } catch (e) {
      return leadId;
    }
  }

  List<AttendanceRecord> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  bool _hasStatus(DateTime day, AttendanceStatus status) {
    final events = _getEventsForDay(day);
    return events.any((element) => element.status == status);
  }

  List<SiteVisit> _getSiteVisitsForDay(DateTime day) {
    return _siteVisitEvents[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  String _getTeamMemberName(String ownerId) {
    if (ownerId == _currentUser) return 'Me';
    return ownerId.split('@').first;
  }

  List<FollowUp> _getFollowUpsForDay(DateTime day) {
    return _followUpEvents[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            TableCalendar<AttendanceRecord>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;

                  // Filter data for the selected day
                  _selectedSiteVisits = _siteVisits.where((visit) {
                    final visitDate = DateTime.tryParse(visit.visitDate);
                    return visitDate != null &&
                        isSameDay(visitDate, selectedDay);
                  }).toList();

                  _selectedFollowUps = _followUps.where((followUp) {
                    final followUpDate = DateTime.tryParse(
                      followUp.followUpDate ?? '',
                    );
                    return followUpDate != null &&
                        isSameDay(followUpDate, selectedDay);
                  }).toList();
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _fetchAttendanceForMonth(focusedDay.month, focusedDay.year);
              },
              calendarBuilders: CalendarBuilders(
                // 1. Remove Green Background from Default/Today builders
                defaultBuilder: (context, day, focusedDay) => null,

                selectedBuilder: (context, day, focusedDay) {
                  return _buildDayContainer(
                    day,
                    const Color(0xFF5C6BC0),
                    Colors.white,
                  );
                },

                todayBuilder: (context, day, focusedDay) {
                  return _buildDayContainer(
                    day,
                    Colors.blue.withOpacity(0.1),
                    Colors.blue,
                  );
                },

                // 2. Add Attendance Logic to Markers
                markerBuilder: (context, day, events) {
                  List<Widget> markers = [];

                  // --- A. Attendance Marker (First Dot) ---
                  if (_hasStatus(day, AttendanceStatus.present)) {
                    markers.add(_buildDot(Colors.green)); // Green for Present
                  } else if (_hasStatus(day, AttendanceStatus.absent)) {
                    markers.add(_buildDot(Colors.red)); // Red for Absent
                  }

                  // --- B. Event Markers (Site Visits & Follow-ups) ---
                  // 1. Get raw events
                  final siteVisitsForDay = _getSiteVisitsForDay(day);
                  final followUpsForDay = _getFollowUpsForDay(day);

                  // 2. Apply Filters
                  List<SiteVisit> filteredVisits = siteVisitsForDay;
                  if (_selectedFilterCategory != null &&
                      _selectedFilterCategory != 'Site Visits') {
                    filteredVisits = [];
                  } else if (_selectedFilterUser != null) {
                    filteredVisits = filteredVisits
                        .where((v) => v.owner == _selectedFilterUser)
                        .toList();
                  }

                  List<FollowUp> filteredFollowUps = followUpsForDay;
                  if (_selectedFilterCategory != null &&
                      _selectedFilterCategory != 'Follow-ups') {
                    filteredFollowUps = [];
                  } else if (_selectedFilterUser != null) {
                    filteredFollowUps = filteredFollowUps
                        .where((f) => f.leadName == _selectedFilterUser)
                        .toList();
                  }

                  // 3. Combine Owners
                  final siteVisitOwners = filteredVisits
                      .map((v) => v.owner)
                      .toSet();
                  final followUpOwners = filteredFollowUps
                      .map((f) => f.leadName ?? 'Unknown')
                      .toSet();
                  final allOwners = [
                    ...siteVisitOwners,
                    ...followUpOwners,
                  ].toSet().toList();

                  // 4. Add Event Dots
                  for (var owner in allOwners) {
                    markers.add(_buildDot(_userColorMap[owner] ?? Colors.grey));
                  }

                  if (markers.isEmpty) return null;

                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: markers,
                    ),
                  );
                },
              ),
            ),

            // Filter Legend
            _buildLegend(),

            const SizedBox(height: 8.0),

            // Event List
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
    );
  }

  // Helper widget for consistent dots
  Widget _buildDot(Color color) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildLegend() {
    final siteVisitOwners = _siteVisits.map((v) => v.owner).toSet().toList();
    final followUpOwners = _followUps
        .map((f) => f.leadName ?? 'Unknown')
        .toSet()
        .toList();

    if (siteVisitOwners.isEmpty && followUpOwners.isEmpty)
      return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Site Visits Filter Row
          if (siteVisitOwners.isNotEmpty)
            _buildLegendCategory(
              title: "Site Visits",
              icon: Icons.location_on,
              iconColor: Colors.redAccent,
              owners: siteVisitOwners,
              // Logic: Check if this category is selected or if ALL are selected (null)
              isCategoryActive:
                  _selectedFilterCategory == null ||
                  _selectedFilterCategory == 'Site Visits',
            ),

          if (siteVisitOwners.isNotEmpty && followUpOwners.isNotEmpty)
            const SizedBox(height: 12),

          // 2. Follow-ups Filter Row
          if (followUpOwners.isNotEmpty)
            _buildLegendCategory(
              title: "Follow-ups",
              icon: Icons.follow_the_signs,
              iconColor: Colors.blueAccent,
              owners: followUpOwners,
              isCategoryActive:
                  _selectedFilterCategory == null ||
                  _selectedFilterCategory == 'Follow-ups',
            ),
        ],
      ),
    );
  }

  Widget _buildLegendCategory({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> owners,
    required bool isCategoryActive,
  }) {
    // Determine opacity: If category is inactive, fade it out
    final double opacity = isCategoryActive ? 1.0 : 0.3;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: opacity,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            // A. Category Filter Button
            InkWell(
              onTap: () {
                setState(() {
                  // If clicking the currently active category, toggle it off (reset to all)
                  // If clicking a new category, set it as active
                  if (_selectedFilterCategory == title) {
                    _selectedFilterCategory = null;
                  } else {
                    _selectedFilterCategory = title;
                  }
                  // Reset user filter when switching categories for better UX
                  _selectedFilterUser = null;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 12.0),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 20, color: Colors.grey[300]),
                  ],
                ),
              ),
            ),

            // B. User Filter List
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: owners.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final member = owners[index];
                  final color = _userColorMap[member] ?? Colors.grey;

                  final name = member == _currentUser
                      ? 'Me'
                      : member.split('@').first;
                  final initial = name.isNotEmpty
                      ? name.substring(0, 1).toUpperCase()
                      : '?';

                  // User Filter Logic:
                  // Active if:
                  // 1. Category is active AND
                  // 2. (No user selected OR This specific user is selected)
                  final bool isUserActive =
                      isCategoryActive &&
                      (_selectedFilterUser == null ||
                          _selectedFilterUser == member);

                  return IgnorePointer(
                    ignoring:
                        !isCategoryActive, // Prevent clicking users in disabled category
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isUserActive ? 1.0 : 0.3,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            // Toggle user filter
                            if (_selectedFilterUser == member) {
                              _selectedFilterUser = null;
                            } else {
                              _selectedFilterUser = member;
                              // Auto-select category if not already selected
                              _selectedFilterCategory = title;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: _selectedFilterUser == member
                                  ? color
                                  : Colors.grey.shade200,
                              width: _selectedFilterUser == member
                                  ? 1.5
                                  : 1.0, // Highlight border if selected
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: color.withOpacity(0.15),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayContainer(DateTime day, Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.all(6.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // ─── FILTERED EVENT LIST ───

  Widget _buildEventList() {
    final targetDay = _selectedDay ?? DateTime.now();
    final attendanceEvents = _getEventsForDay(targetDay);

    // 1. Filter Lists based on State
    // Attendance is always shown unless we specifically want to hide it when filters are active (optional, keeping it visible here)
    // To hide attendance when filters are active, uncomment the next line:
    // final showAttendance = _selectedFilterCategory == null;
    final showAttendance = true;

    // Filter Site Visits
    List<SiteVisit> filteredVisits = _selectedSiteVisits;
    bool showSiteVisitsSection = true;

    if (_selectedFilterCategory != null &&
        _selectedFilterCategory != 'Site Visits') {
      showSiteVisitsSection = false; // Hidden if another category is selected
    } else {
      // If 'Site Visits' is active or 'All' is active
      if (_selectedFilterUser != null) {
        filteredVisits = filteredVisits
            .where((v) => v.owner == _selectedFilterUser)
            .toList();
      }
    }

    // Filter Follow Ups
    List<FollowUp> filteredFollowUps = _selectedFollowUps;
    bool showFollowUpsSection = true;

    if (_selectedFilterCategory != null &&
        _selectedFilterCategory != 'Follow-ups') {
      showFollowUpsSection = false; // Hidden if another category is selected
    } else {
      // If 'Follow-ups' is active or 'All' is active
      if (_selectedFilterUser != null) {
        filteredFollowUps = filteredFollowUps
            .where((f) => f.leadName == _selectedFilterUser)
            .toList();
      }
    }

    final hasAttendance = attendanceEvents.isNotEmpty && showAttendance;
    final hasSiteVisits = filteredVisits.isNotEmpty && showSiteVisitsSection;
    final hasFollowUps = filteredFollowUps.isNotEmpty && showFollowUpsSection;

    if (!hasAttendance && !hasSiteVisits && !hasFollowUps) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No activity matches your filter",
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Attendance Section ---
          if (hasAttendance) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    size: 18,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Attendance",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attendanceEvents.length,
              itemBuilder: (context, index) =>
                  _buildAttendanceCard(attendanceEvents[index]),
            ),
          ],

          // --- Site Visits Section ---
          if (hasSiteVisits) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  const Text(
                    "Site Visits",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredVisits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildSiteVisitCard(filteredVisits[index]),
            ),
          ],

          // --- Follow-ups Section ---
          if (hasFollowUps) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.follow_the_signs,
                    size: 18,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Follow-ups",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredFollowUps.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildFollowUpCard(filteredFollowUps[index]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord event) {
    final isPresent = event.status == AttendanceStatus.present;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPresent
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPresent ? Icons.check_circle : Icons.cancel,
              color: isPresent ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPresent ? 'Present' : 'Absent',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, d MMMM').format(event.attendanceDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSiteVisitCard(SiteVisit visit) {
    final ownerName = _getTeamMemberName(visit.owner);
    final ownerColor = _userColorMap[visit.owner] ?? Colors.grey;
    final leadName = _getLeadName(visit.lead);
    final projectName = _getProjectName(visit.project);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: ownerColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leadName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: Color(0xFF2D3436),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.business_rounded,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        projectName,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: ownerColor.withOpacity(0.1),
                                child: Text(
                                  ownerName.isNotEmpty
                                      ? ownerName.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: ownerColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ownerName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusBadge(visit.status),
                          if (visit.remark.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  visit.remark,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpCard(FollowUp followUp) {
    final ownerName = _getTeamMemberName(followUp.leadName ?? 'N/A');
    final ownerColor = _userColorMap[followUp.leadName] ?? Colors.grey;
    final leadName = followUp.leadName ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: ownerColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leadName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: Color(0xFF2D3436),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.watch_later_outlined,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        followUp.followUpDate ?? 'No Date',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: ownerColor.withOpacity(0.1),
                                child: Text(
                                  ownerName.isNotEmpty
                                      ? ownerName.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: ownerColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ownerName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusBadge(followUp.status ?? 'N/A'),
                          if (followUp.remarks != null &&
                              followUp.remarks!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  followUp.remarks!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
      case 'won':
        statusColor = Colors.green;
        break;
      case 'pending':
      case 'planned':
      case 'scheduled':
      case 'open':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
      case 'lost':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

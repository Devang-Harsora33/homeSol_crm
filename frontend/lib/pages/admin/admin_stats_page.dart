import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Homesol/services/apis/admin/admin_service.dart';
import 'package:Homesol/models/admin/admin_stats.dart';
import 'package:collection/collection.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:fl_chart/fl_chart.dart';

const Color goldAccent = Color(0xFFD4AF37);
const Color matteBlack = Color(0xFF2C2C2C);
const Color bgWhite = Color(0xFFF4F6F8);

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  bool _isLoading = true;
  String? _errorMessage;

  bool _showCharts = false;

  List<AdminUserActivity> _userActivities = [];
  
  // Filters
  int _selectedDays = 90; // Default to 90 as per user example
  final List<int> _durationOptions = [0, 1, 7, 15, 30, 60, 90, 180, 365];
  
  List<String> _selectedProjects = [];
  List<String> _selectedEmployees = [];

  // Extracted data for filters
  List<String> _availableProjects = []; // IDs
  List<String> _availableEmployees = [];
  Map<String, String> _projectNames = {};
  Map<String, String> _employeeNames = {};
  Map<String, String> _leadNames = {};

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Pass the selected days to the backend API.
      final activities = await AdminService.fetchUserActivityStats(days: _selectedDays);
      
      Set<String> projects = {};
      Set<String> employees = {};

      final Map<String, String> employeeNamesMap = {};
      final Map<String, String> leadNamesMap = {};

      for (var activity in activities) {
        if (activity.employee.isNotEmpty) {
          employeeNamesMap[activity.employee] = activity.employeeName.isNotEmpty ? activity.employeeName : activity.employee;
        }
        final empName = activity.employeeName.isNotEmpty ? activity.employeeName : activity.employee;
        if (empName.isNotEmpty) employees.add(empName);
        
        for (var lead in activity.leads) {
          if (lead.name.isNotEmpty) {
            leadNamesMap[lead.name] = lead.leadName.isNotEmpty ? lead.leadName : lead.name;
          }
          if (lead.customInterestedProject.isNotEmpty) {
            projects.add(lead.customInterestedProject);
          }
          for (var visit in lead.siteVisits) {
            if (visit.project.isNotEmpty) {
              projects.add(visit.project);
            }
          }
        }
      }

      // Fetch all projects to map IDs to Names
      final apiProjects = await ProjectService.fetchApiProjects();
      final Map<String, String> projectNamesMap = {};
      for (var p in apiProjects) {
        projectNamesMap[p['id'].toString()] = p['name'].toString();
      }

      if (mounted) {
        setState(() {
          _userActivities = activities;
          _projectNames = projectNamesMap;
          _employeeNames = employeeNamesMap;
          _leadNames = leadNamesMap;
          _availableProjects = projects.toList()..sort();
          _availableEmployees = employees.toList()..sort();
          
          // Clean up selected employees if they are no longer in the list for this time period
          _selectedEmployees.removeWhere((e) => !_availableEmployees.contains(e));
          _selectedProjects.removeWhere((p) => !_availableProjects.contains(p));
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getProjectName(String projectId) {
    if (projectId.isEmpty) return 'No Project Specified';
    return _projectNames[projectId] ?? projectId;
  }

  String _getEmployeeName(String employeeId) {
    if (employeeId.isEmpty) return 'Unknown Employee';
    return _employeeNames[employeeId] ?? employeeId;
  }

  String _getLeadName(String leadId) {
    if (leadId.isEmpty) return 'Unknown Lead';
    return _leadNames[leadId] ?? leadId;
  }

  String _formatGeoJsonLocation(String locationStr) {
    if (locationStr.isEmpty) return '';
    try {
      final data = json.decode(locationStr);
      if (data['type'] == 'FeatureCollection' && data['features'] != null) {
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          if (geometry != null && geometry['coordinates'] != null) {
            final coords = geometry['coordinates'] as List;
            if (coords.length >= 2) {
              final lng = (coords[0] as num).toStringAsFixed(4);
              final lat = (coords[1] as num).toStringAsFixed(4);
              return '$lat, $lng';
            }
          }
        }
      }
    } catch (e) {
      // If not valid JSON or unexpected format, just return a truncated string or fallback
      if (locationStr.length > 30) return '${locationStr.substring(0, 30)}...';
      return locationStr;
    }
    return 'Unknown Location';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 'Invalid';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Local filtering based on UI selections
    final filteredActivities = _userActivities.where((a) {
      if (_selectedEmployees.isEmpty) return true;
      final empName = a.employeeName.isNotEmpty ? a.employeeName : a.employee;
      return _selectedEmployees.contains(empName);
    }).toList();

    List<AdminLead> allLeads = [];
    List<AdminSiteVisit> allVisits = [];
    List<AdminFollowup> allFollowups = [];
    List<AdminSourcing> allSourcing = [];
    List<AdminCheckin> allCheckins = [];
    List<AdminCheckout> allCheckouts = [];
    List<AdminAttendance> allAttendance = [];

    for (var activity in filteredActivities) {
      // Leads & related info
      final relevantLeads = activity.leads.where((l) {
        return _selectedProjects.isEmpty || _selectedProjects.contains(l.customInterestedProject);
      }).toList();
      allLeads.addAll(relevantLeads);

      for (var lead in activity.leads) {
        final relevantVisits = lead.siteVisits.where((v) {
          return _selectedProjects.isEmpty || _selectedProjects.contains(v.project);
        }).toList();
        allVisits.addAll(relevantVisits);
        
        final relevantFollowups = lead.followups.where((f) {
           return _selectedProjects.isEmpty || _selectedProjects.contains(lead.customInterestedProject);
        }).toList();
        allFollowups.addAll(relevantFollowups);
      }

      if (_selectedProjects.isEmpty) {
        allSourcing.addAll(activity.sourcing);
        allCheckins.addAll(activity.checkins);
        allCheckouts.addAll(activity.checkouts);
        allAttendance.addAll(activity.attendance);
      }
    }

    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        title: const Text('Activity Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: matteBlack)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: matteBlack),
            onPressed: _fetchStats,
            tooltip: 'Refresh Data',
          )
        ],
      ),
      body: Column(
        children: [
          // Sticky Header for Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeRangeSelector(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMultiSelectButton(
                        hint: 'All Employees',
                        selectedItems: _selectedEmployees,
                        items: _availableEmployees,
                        icon: Icons.person_rounded,
                        onTap: () => _showMultiSelectBottomSheet(
                          title: 'Select Employees',
                          items: _availableEmployees,
                          selectedItems: _selectedEmployees,
                          onSelectionChanged: (selected) {
                            setState(() {
                              _selectedEmployees = selected;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMultiSelectButton(
                        hint: 'All Projects',
                        selectedItems: _selectedProjects,
                        items: _availableProjects,
                        icon: Icons.apartment_rounded,
                        onTap: () => _showMultiSelectBottomSheet(
                          title: 'Select Projects',
                          items: _availableProjects,
                          selectedItems: _selectedProjects,
                          itemLabelBuilder: (id) => _getProjectName(id),
                          onSelectionChanged: (selected) {
                            setState(() {
                              _selectedProjects = selected;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: goldAccent))
                : _errorMessage != null
                    ? _buildErrorState()
                    : _userActivities.isEmpty
                        ? const Center(child: Text('No data available for the selected period.', style: TextStyle(color: Colors.grey)))
                        : _buildDashboardContent(
                            allLeads,
                            allVisits,
                            allFollowups,
                            allSourcing,
                            allCheckins,
                            allCheckouts,
                            allAttendance,
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: matteBlack, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _fetchStats,
          )
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final double sliderValue = _durationOptions.indexOf(_selectedDays).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Time Period",
              style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: matteBlack.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _selectedDays == 0 ? "Today" : "Last $_selectedDays Days",
                style: const TextStyle(color: matteBlack, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            )
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: matteBlack,
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: matteBlack,
            trackHeight: 4.0,
            overlayColor: matteBlack.withOpacity(0.1),
            valueIndicatorTextStyle: const TextStyle(color: Colors.white),
          ),
          child: Slider(
            value: sliderValue,
            min: 0,
            max: (_durationOptions.length - 1).toDouble(),
            divisions: _durationOptions.length - 1,
            label: _selectedDays == 0 ? "Today" : "$_selectedDays Days",
            onChanged: (value) {
              final newDays = _durationOptions[value.round()];
              if (newDays != _selectedDays) {
                setState(() => _selectedDays = newDays);
              }
            },
            onChangeEnd: (value) {
              _fetchStats(); // Fetch data when slider is released
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectButton({
    required String hint,
    required List<String> selectedItems,
    required List<String> items,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    String displayText = hint;
    if (selectedItems.length == 1) {
      displayText = selectedItems.first;
    } else if (selectedItems.length > 1) {
      displayText = '${selectedItems.length} Selected';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selectedItems.isNotEmpty ? goldAccent : matteBlack),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  color: selectedItems.isNotEmpty ? matteBlack : Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: selectedItems.isNotEmpty ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600, size: 20),
          ],
        ),
      ),
    );
  }

  void _showMultiSelectBottomSheet({
    required String title,
    required List<String> items,
    required List<String> selectedItems,
    required ValueChanged<List<String>> onSelectionChanged,
    String Function(String)? itemLabelBuilder,
  }) {
    // Keep a local copy of selected items for the bottom sheet
    List<String> tempSelectedItems = List.from(selectedItems);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredItems = items.where((item) {
              final label = itemLabelBuilder != null ? itemLabelBuilder(item) : item;
              return label.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: matteBlack,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempSelectedItems.clear();
                            });
                          },
                          child: const Text('Clear', style: TextStyle(color: matteBlack, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: filteredItems.isEmpty 
                      ? const Center(child: Text("No options available", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSelected = tempSelectedItems.contains(item);
                            final displayLabel = itemLabelBuilder != null ? itemLabelBuilder(item) : item;
                            return CheckboxListTile(
                              activeColor: matteBlack,
                              checkColor: Colors.white,
                              title: Text(displayLabel, style: const TextStyle(color: matteBlack, fontWeight: FontWeight.w500)),
                              value: isSelected,
                              onChanged: (bool? checked) {
                                setSheetState(() {
                                  if (checked == true) {
                                    tempSelectedItems.add(item);
                                  } else {
                                    tempSelectedItems.remove(item);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            );
                          },
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matteBlack,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          onSelectionChanged(tempSelectedItems);
                          Navigator.pop(context);
                        },
                        child: const Text('Apply Selection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardContent(
    List<AdminLead> leads,
    List<AdminSiteVisit> visits,
    List<AdminFollowup> followups,
    List<AdminSourcing> sourcing,
    List<AdminCheckin> checkins,
    List<AdminCheckout> checkouts,
    List<AdminAttendance> attendance,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Grid
          const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: matteBlack)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            childAspectRatio: 1.4,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSummaryCard('Leads Created', leads.length, Icons.person_add_rounded, Colors.blue),
              _buildSummaryCard('Site Visits', visits.length, Icons.home_work_rounded, Colors.green),
              _buildSummaryCard('Follow-ups', followups.length, Icons.phone_callback_rounded, Colors.orange),
              _buildSummaryCard('Sourcing', sourcing.length, Icons.source_rounded, Colors.purple),
              _buildSummaryCard('Check-ins', checkins.length, Icons.login_rounded, Colors.teal),
              _buildSummaryCard('Check-outs', checkouts.length, Icons.logout_rounded, Colors.redAccent),
              _buildSummaryCard('Attendance', attendance.length, Icons.event_available_rounded, Colors.indigo),
            ],
          ),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Data Visualization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: matteBlack)),
              Switch(
                value: _showCharts,
                activeColor: goldAccent,
                onChanged: (val) {
                  setState(() => _showCharts = val);
                },
              ),
            ],
          ),
          if (_showCharts) ...[
            const SizedBox(height: 16),
            _buildChartsSection(leads, sourcing),
          ],
          
          const SizedBox(height: 24),
          _buildConversionInsights(visits.length, leads.where((l) => l.status.toLowerCase() == 'won' || l.status.toLowerCase() == 'converted' || l.status.toLowerCase() == 'booked').length),

          if (_selectedProjects.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sourcing and Check-in logs are hidden while a project filter is active.',
                      style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          const Text('Detailed Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: matteBlack)),
          const SizedBox(height: 16),
          
          // Detailed Expansion Tiles
          _buildDetailSection(
            title: 'Leads Created',
            icon: Icons.person_add_rounded,
            count: leads.length,
            color: Colors.blue,
            isEmpty: leads.isEmpty,
            items: leads.map((l) => _buildDetailCard(
              title: l.leadName,
              subtitle: _getProjectName(l.customInterestedProject),
              status: l.status,
              date: l.creation,
              icon: Icons.person_rounded,
              color: Colors.blue,
              extraDetails: [
                if (l.mobileNo.isNotEmpty) 'Phone: ${l.mobileNo}',
                if (l.emailId.isNotEmpty) 'Email: ${l.emailId}',
                if (l.source.isNotEmpty) 'Source: ${l.source}',
                if (l.customConfiguration != null && l.customConfiguration!.isNotEmpty) 'Config: ${l.customConfiguration}',
              ]
            )).toList(),
          ),
          
          _buildDetailSection(
            title: 'Site Visits',
            icon: Icons.home_work_rounded,
            count: visits.length,
            color: Colors.green,
            isEmpty: visits.isEmpty,
            items: visits.map((v) => _buildDetailCard(
              title: _getProjectName(v.project),
              subtitle: v.lead.isNotEmpty ? 'Lead: ${v.lead}' : 'No Lead Data',
              status: v.status,
              date: v.visitDate,
              icon: Icons.apartment_rounded,
              color: Colors.green,
              extraDetails: [
                if (v.visitDuration != null) 'Duration: ${v.visitDuration}',
                if (v.remark.isNotEmpty) 'Remark: ${v.remark}',
              ]
            )).toList(),
          ),

          _buildDetailSection(
            title: 'Follow-ups',
            icon: Icons.phone_callback_rounded,
            count: followups.length,
            color: Colors.orange,
            isEmpty: followups.isEmpty,
            items: followups.map((f) => _buildDetailCard(
              title: _getLeadName(f.parent),
              subtitle: f.type,
              status: f.status,
              date: f.followUpDate,
              icon: Icons.phone_rounded,
              color: Colors.orange,
              extraDetails: [
                if (f.remarks.isNotEmpty) 'Remark: ${f.remarks}',
                if (f.nextFollowUp != null) 'Next Date: ${_formatDate(f.nextFollowUp)}',
              ]
            )).toList(),
          ),

          if (_selectedProjects.isEmpty) ...[
            _buildDetailSection(
              title: 'Sourcing Actions',
              icon: Icons.source_rounded,
              count: sourcing.length,
              color: Colors.purple,
              isEmpty: sourcing.isEmpty,
              items: sourcing.map((s) => _buildDetailCard(
                title: s.salesPartner.isNotEmpty ? s.salesPartner : 'Unknown Partner',
                subtitle: 'Met: ${s.contactPersonMet}',
                status: s.visitStatus,
                date: s.visitDate,
                icon: Icons.handshake_rounded,
                color: Colors.purple,
                extraDetails: [
                  if (s.mobileNumber.isNotEmpty) 'Contact: ${s.mobileNumber}',
                  'Meeting: ${s.meetingType ?? 'OBM'}',
                  if (s.remark.isNotEmpty) 'Remark: ${s.remark}',
                ]
              )).toList(),
            ),

            _buildDetailSection(
              title: 'Check-ins',
              icon: Icons.login_rounded,
              count: checkins.length,
              color: Colors.teal,
              isEmpty: checkins.isEmpty,
              items: checkins.map((c) => _buildDetailCard(
                title: _getEmployeeName(c.employee),
                subtitle: 'Device: ${c.deviceId}',
                status: 'IN',
                date: c.time,
                icon: Icons.location_on_rounded,
                color: Colors.teal,
                extraDetails: [
                  if (c.customRemark.isNotEmpty) 'Remark: ${c.customRemark}',
                  'Location: ${c.latitude.toStringAsFixed(4)}, ${c.longitude.toStringAsFixed(4)}',
                ]
              )).toList(),
            ),

            _buildDetailSection(
              title: 'Check-outs',
              icon: Icons.logout_rounded,
              count: checkouts.length,
              color: Colors.redAccent,
              isEmpty: checkouts.isEmpty,
              items: checkouts.map((c) => _buildDetailCard(
                title: _getEmployeeName(c.employee),
                subtitle: 'Device: ${c.deviceId}',
                status: 'OUT',
                date: c.time,
                icon: Icons.location_off_rounded,
                color: Colors.redAccent,
              )).toList(),
            ),
            
            _buildDetailSection(
              title: 'Attendance',
              icon: Icons.event_available_rounded,
              count: attendance.length,
              color: Colors.indigo,
              isEmpty: attendance.isEmpty,
              items: attendance.map((a) => _buildDetailCard(
                title: _getEmployeeName(a.employee),
                subtitle: 'Shift: ${a.shift}',
                status: a.status,
                date: a.attendanceDate,
                icon: Icons.date_range_rounded,
                color: Colors.indigo,
                extraDetails: [
                  'Working Hours: ${a.workingHours}',
                ]
              )).toList(),
            ),
          ],
          
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildConversionInsights(int totalVisits, int totalBookings) {
    double convRate = totalVisits > 0 ? (totalBookings / totalVisits) : 0.0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [matteBlack, Color(0xFF3A3A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: goldAccent, size: 20),
              const SizedBox(width: 10),
              const Text("Conversion Insights", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("${(convRate * 100).toStringAsFixed(1)}%", style: const TextStyle(color: goldAccent, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          const Text("Visits to Bookings ratio", style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: convRate,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(goldAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(String title, Map<String, int> dataMap, List<Color> colors) {
    if (dataMap.isEmpty) return const SizedBox();
    
    int colorIndex = 0;
    List<PieChartSectionData> pieSections = dataMap.entries.map((e) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        color: color,
        value: e.value.toDouble(),
        title: '${e.value}',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: matteBlack)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: pieSections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: dataMap.entries.map((e) {
              final idx = dataMap.keys.toList().indexOf(e.key);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[idx % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: matteBlack)),
                ],
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildChartsSection(List<AdminLead> leads, List<AdminSourcing> sourcing) {
    if (leads.isEmpty && sourcing.isEmpty) {
      return const Center(child: Text("Not enough data for charts", style: TextStyle(color: Colors.grey)));
    }

    // 1. Lead Sources
    Map<String, int> sourceCount = {};
    for (var l in leads) {
      final s = (l.source.isNotEmpty) ? l.source : 'Unknown';
      sourceCount[s] = (sourceCount[s] ?? 0) + 1;
    }

    // 2. Lead Stages
    Map<String, int> stageCount = {};
    for (var l in leads) {
      final s = (l.customStages != null && l.customStages!.isNotEmpty) ? l.customStages! : (l.customLeadStatus ?? 'New');
      stageCount[s] = (stageCount[s] ?? 0) + 1;
    }
    
    // 3. Sourcing Outcomes
    Map<String, int> sourcingStatusCount = {};
    for (var s in sourcing) {
      final st = s.visitStatus.isNotEmpty ? s.visitStatus : 'Unknown';
      sourcingStatusCount[st] = (sourcingStatusCount[st] ?? 0) + 1;
    }

    final colors1 = [Colors.blue, Colors.orange, Colors.teal, Colors.redAccent, Colors.purple];
    final colors2 = [Colors.indigo, Colors.green, Colors.deepOrange, Colors.cyan, goldAccent];
    
    var sortedStages = stageCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    List<BarChartGroupData> barGroups = [];
    double maxStage = 0;
    for (int i = 0; i < sortedStages.length; i++) {
      double val = sortedStages[i].value.toDouble();
      if (val > maxStage) maxStage = val;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: goldAccent,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        )
      );
    }

    return Column(
      children: [
        _buildPieChartCard("Lead Sources", sourceCount, colors1),
        
        // Lead Stages Bar Chart
        if (stageCount.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Lead Stages Funnel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: matteBlack)),
                const SizedBox(height: 30),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxStage + (maxStage * 0.2).clamp(1.0, double.infinity),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              int idx = value.toInt();
                              if (idx >= 0 && idx < sortedStages.length) {
                                String name = sortedStages[idx].key;
                                if (name.length > 8) name = '${name.substring(0, 8)}..';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        _buildPieChartCard("Sourcing Outcomes", sourcingStatusCount, colors2),
      ],
    );
  }

  Widget _buildSummaryCard(String title, int count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, size: 80, color: color.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
                Text(
                  count.toString(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: matteBlack, height: 1.1),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required int count,
    required Color color,
    required bool isEmpty,
    required List<Widget> items,
  }) {
    if (isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            iconColor: color,
            collapsedIconColor: Colors.grey.shade400,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: matteBlack),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    count.toString(),
                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey.shade700, fontSize: 13),
                  ),
                )
              ],
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bgWhite,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => items[index],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required String subtitle,
    required String status,
    required String date,
    required IconData icon,
    required Color color,
    List<String> extraDetails = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.05), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: matteBlack)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              )
            ],
          ),
          if (extraDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgWhite,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: extraDetails.map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      Expanded(child: Text(detail, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                _formatDate(date),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

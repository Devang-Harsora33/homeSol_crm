import 'package:flutter/material.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:Homesol/models/lead.dart' as model_lead;
import 'package:Homesol/models/site_visit.dart';
import 'package:Homesol/models/sourcing.dart';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/models/profile.dart';
import 'package:Homesol/models/follow_up.dart';
import 'package:Homesol/models/sales_team.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';
import 'package:Homesol/components/lead_detail_view.dart';
import 'package:Homesol/pages/sourcing/sourcing_detail_page.dart';

class TeamLeadStatsPage extends StatefulWidget {
  const TeamLeadStatsPage({super.key});

  @override
  State<TeamLeadStatsPage> createState() => _TeamLeadStatsPageState();
}

class _StatsDataItem {
  final String label;
  final dynamic data;
  _StatsDataItem(this.label, this.data);
}

const Color goldAccent = Color(0xFF675D40);
const Color matteBlack = Color(0xFF1A1A1A);

class _TeamLeadStatsPageState extends State<TeamLeadStatsPage> {
  bool _isLoading = true;
  List<model_lead.Lead> _leads = [];
  List<SiteVisit> _siteVisits = [];
  List<Sourcing> _sourcingEntries = [];
  List<Project> _assignedProjects = [];
  List<FollowUp> _followUps = [];
  String _selectedTab = 'CRM'; // 'CRM' or 'Sourcing'
  String? _userDesignation;
  int _selectedDays = 7; // Default to 7 days
  final List<int> _durationOptions = [0, 7, 15, 30, 45, 60];
  String? _selectedProjectFilter;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        LeadService.fetchMyLeads(forceRefresh: true),
        SiteVisitService.fetchMySiteVisits(forceRefresh: true),
        SourcingService.getMySources(forceRefresh: true),
        ProjectService.fetchProjects(forceRefresh: false),
        LeadService.fetchMyFollowups(forceRefresh: true),
        ApiService.fetchSalesTeams(forceRefresh: true),
        AuthService.getUserData(),
        AuthService.getMyProfile(),
      ]);

      final leads = results[0] as List<model_lead.Lead>;
      final siteVisits = results[1] as List<SiteVisit>;
      final sourcingEntries = results[2] as List<Sourcing>;
      final allProjects = results[3] as List<Project>;
      final followUps = results[4] as List<FollowUp>;
      final salesTeams = results[5] as List<SalesTeam>;
      final userData = results[6] as Map<String, dynamic>?;
      final profile = results[7] as Profile?;

      final currentUserEmail = userData?['email'];
      final designation = profile?.designation.trim().toUpperCase() ?? '';
      
      // Identify assigned projects from SalesTeam
      Set<String> assignedProjectIds = {};
      for (final team in salesTeams) {
        bool isMember = team.members.any((m) => m.userId == currentUserEmail || m.employee == currentUserEmail);
        if (isMember) {
          assignedProjectIds.addAll(team.projects.map((p) => p.projects));
        }
      }

      final filteredProjects = allProjects.where((p) => assignedProjectIds.contains(p.id)).toList();

      setState(() {
        _leads = leads;
        _siteVisits = siteVisits;
        _sourcingEntries = sourcingEntries;
        _assignedProjects = filteredProjects;
        _followUps = followUps;
        _userDesignation = designation;
        
        // Initial tab logic
        if (designation == 'SOURCING') {
          _selectedTab = 'Sourcing';
        } else {
          _selectedTab = 'CRM';
        }
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching stats data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Performance Stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : Column(
              children: [
                _buildToggle(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTimeRangeSelector(),
                        if (_selectedTab == 'CRM') _buildProjectFilter(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _selectedTab == 'CRM' ? _buildCRMStats() : _buildSourcingStats(),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildShareButton(),
              ],
            ),
    );
  }

  Widget _buildProjectFilter() {
    return Padding(
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
            hint: const Text('All My Projects'),
            value: _selectedProjectFilter,
            icon: const Icon(Icons.filter_list_rounded, color: goldAccent),
            dropdownColor: Colors.white,
            items: [
              const DropdownMenuItem<String>(
                value: null, 
                child: Text('All My Projects', style: TextStyle(fontWeight: FontWeight.bold, color: matteBlack))
              ),
              ..._assignedProjects.map((p) => DropdownMenuItem<String>(
                value: p.id,
                child: Text(p.projectName ?? p.id ?? '', style: const TextStyle(color: matteBlack)),
              )),
            ],
            onChanged: (val) => setState(() => _selectedProjectFilter = val),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    final designation = _userDesignation?.toUpperCase() ?? '';
    final bool showCRM = designation != 'SOURCING';
    final bool showSourcing = designation == 'SOURCING' || 
                             designation == 'SALES AND SOURCING' || 
                             designation == 'SALES & SOURCING';

    if (!showCRM || !showSourcing) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (showCRM) _toggleButton('CRM', _selectedTab == 'CRM'),
          if (showSourcing) _toggleButton('Sourcing', _selectedTab == 'Sourcing'),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTab = label;
          _selectedProjectFilter = null; // Reset filter when switching tabs
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
            ] : null,
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

  Widget _buildTimeRangeSelector() {
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

  Widget _buildCRMStats() {
    final now = DateTime.now();
    final startDate = _selectedDays == 0 
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(Duration(days: _selectedDays));
    
    // Filter leads by project
    var filteredLeads = _leads;
    if (_selectedProjectFilter != null) {
      filteredLeads = _leads.where((l) => l.projectId.contains(_selectedProjectFilter)).toList();
    }

    final filteredLeadNames = filteredLeads.map((l) => l.name).toSet();

    final periodVisits = _siteVisits.where((v) {
      if (v.visitDate == null) return false;
      final vDate = DateTime.tryParse(v.visitDate!);
      if (vDate == null) return false;
      return vDate.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
             filteredLeadNames.contains(v.lead);
    }).toList();

    final visitDone = periodVisits.where((v) => v.status.toLowerCase() == 'visit done').toList();
    final revisitDone = periodVisits.where((v) => v.status.toLowerCase() == 'revisit done').toList();
    
    // Categorize visits into Direct, CP, Reference
    final directVisitsList = <model_lead.Lead>[];
    final cpVisitsList = <model_lead.Lead>[];
    final referenceVisitsList = <model_lead.Lead>[];

    for (var v in visitDone) {
      final lead = filteredLeads.firstWhereOrNull((l) => l.name == v.lead);
      if (lead == null) continue;
      final source = lead.source?.toLowerCase() ?? '';
      if (source.contains('cp') || lead.customChannelPartner != null) {
        cpVisitsList.add(lead);
      } else if (source.contains('reference')) {
        referenceVisitsList.add(lead);
      } else {
        directVisitsList.add(lead);
      }
    }

    int directCount = directVisitsList.length;
    int cpCount = cpVisitsList.length;
    int referenceCount = referenceVisitsList.length;

    final warmLeads = filteredLeads.where((l) => (l.customLeadQuality ?? 0) >= 4).toList();
    final opportunities = filteredLeads.where((l) => l.customLeadStatus?.toLowerCase() == 'prospect').toList();
    final bookings = filteredLeads.where((l) => l.customLeadStatus?.toLowerCase() == 'won').toList();

    // Follow-ups
    final periodFollowUps = _followUps.where((f) {
      if (f.followUpDate == null) return false;
      final fDate = DateTime.tryParse(f.followUpDate!);
      if (fDate == null) return false;
      return fDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
             fDate.isBefore(now.add(const Duration(days: 1))) &&
             filteredLeadNames.contains(f.parent);
    }).toList();

    final completedFollowUps = periodFollowUps.where((f) => f.status?.toLowerCase() == 'completed').length;
    final missedFollowUps = periodFollowUps.where((f) {
      if (f.status?.toLowerCase() != 'open') return false;
      final fDate = DateTime.tryParse(f.followUpDate!);
      return fDate != null && fDate.isBefore(now);
    }).length;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statCard('Total Visits', visitDone.length.toString(), Icons.home_work_rounded, Colors.blue),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Direct', directCount.toString(), Icons.person, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Reference', referenceCount.toString(), Icons.people_outline_rounded, Colors.purple)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('CP', cpCount.toString(), Icons.group, Colors.indigo)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Warm', warmLeads.length.toString(), Icons.local_fire_department, Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Opp.', opportunities.length.toString(), Icons.lightbulb, Colors.amber)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Revisits', revisitDone.length.toString(), Icons.history_rounded, Colors.teal)),
          ],
        ),
        const SizedBox(height: 12),
        _statCard('Bookings', bookings.length.toString(), Icons.verified_rounded, Colors.green),
        const SizedBox(height: 32),
        _buildFollowUpPerformance(periodFollowUps.length, completedFollowUps, missedFollowUps),

        const SizedBox(height: 32),
        _buildConversionInsights(visitDone.length, bookings.length),

        const SizedBox(height: 32),
        _buildDurationInsight(
          "Average Visit Duration", 
          "Time spent per lead interaction", 
          visitDone.map((v) => v.visitDuration).toList()
        ),

        const SizedBox(height: 32),
        _buildDataList('Total Visits (${visitDone.length})', visitDone.map((v) {
          final l = filteredLeads.firstWhereOrNull((lead) => lead.name == v.lead);
          return _StatsDataItem(l?.customerName ?? 'Unknown', l);
        }).toList(), Icons.home_work_rounded, Colors.blue),

        _buildDataList('Warm Leads (${warmLeads.length})', warmLeads.map((l) => _StatsDataItem(l.customerName, l)).toList(), Icons.local_fire_department_rounded, Colors.red),
        
        _buildDataList('Opportunities (${opportunities.length})', opportunities.map((l) => _StatsDataItem(l.customerName, l)).toList(), Icons.lightbulb_rounded, Colors.amber),

        _buildDataList('Revisits (${revisitDone.length})', revisitDone.map((v) {
          final l = filteredLeads.firstWhereOrNull((lead) => lead.name == v.lead);
          return _StatsDataItem(l?.customerName ?? 'Unknown', l);
        }).toList(), Icons.history_rounded, Colors.teal),

        _buildDataList('Direct Walk-ins (${directVisitsList.length})', directVisitsList.map((l) => _StatsDataItem(l.customerName, l)).toList(), Icons.person_rounded, Colors.orange),

        _buildDataList('References (${referenceVisitsList.length})', referenceVisitsList.map((l) => _StatsDataItem(l.customerName, l)).toList(), Icons.groups_rounded, Colors.purple),

        _buildDataList('CP Visits (${cpVisitsList.length})', cpVisitsList.map((l) => _StatsDataItem(l.customChannelPartner ?? l.customerName, l)).toList(), Icons.handshake_rounded, Colors.indigo),

        _buildDataList('Confirmed Bookings (${bookings.length})', bookings.map((l) => _StatsDataItem(l.customerName, l)).toList(), Icons.stars_rounded, Colors.green),
      ],
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

  Widget _buildFollowUpPerformance(int total, int completed, int missed) {
    double completionRate = total > 0 ? (completed / total) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Follow-ups Performance",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: matteBlack),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: goldAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${(completionRate * 100).toStringAsFixed(0)}% Score",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: goldAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Left side: Progress Indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: completionRate,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(completionRate > 0.7 ? Colors.green : (completionRate > 0.4 ? Colors.orange : Colors.red)),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${(completionRate * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: matteBlack)),
                      const Text("DONE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 32),
              // Right side: Stats
              Expanded(
                child: Column(
                  children: [
                    _miniFollowUpRow('Targeted', total.toString(), Colors.blueGrey),
                    const Divider(height: 20),
                    _miniFollowUpRow('Completed', completed.toString(), Colors.green),
                    const Divider(height: 20),
                    _miniFollowUpRow('Missed/Pending', missed.toString(), Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniFollowUpRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: matteBlack)),
      ],
    );
  }

  Widget _buildSourcingStats() {
    final now = DateTime.now();
    final startDate = _selectedDays == 0 
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(Duration(days: _selectedDays));

    var filteredSourcing = _sourcingEntries;
    if (_selectedProjectFilter != null) {
      filteredSourcing = _sourcingEntries.where((s) {
        if (s.interestedProject == null) return false;
        return s.interestedProject!.any((p) => p.project == _selectedProjectFilter);
      }).toList();
    }

    final periodSourcing = filteredSourcing.where((s) {
      if (s.visitDate == null) return false;
      final sDate = DateTime.tryParse(s.visitDate!);
      if (sDate == null) return false;
      return sDate.isAfter(startDate.subtract(const Duration(seconds: 1)));
    }).toList();

    final firstMeetings = periodSourcing.where((s) => s.visitType?.toLowerCase() == 'first meeting').toList();
    final followUps = periodSourcing.where((s) => s.visitType?.toLowerCase() == 'follow up').toList();
    final hospitalityVisits = periodSourcing.where((s) => s.offeredCoffee == 1).toList();
    final ownerVisits = periodSourcing.where((s) => s.metTheOwner == 1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statCard('Total CP Meetings', periodSourcing.length.toString(), Icons.handshake_rounded, Colors.indigo),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('First Meet', firstMeetings.length.toString(), Icons.person_add, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Follow-ups', followUps.length.toString(), Icons.repeat, Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Met Owner', ownerVisits.length.toString(), Icons.supervisor_account, Colors.purple)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Hospitality', hospitalityVisits.length.toString(), Icons.coffee_rounded, Colors.brown)),
          ],
        ),
        const SizedBox(height: 32),
        
        _buildSourcingBreakdown(periodSourcing.length, firstMeetings.length, followUps.length),

        const SizedBox(height: 32),
        _buildEngagementMetric("Owner Connectivity", "Ratio of meetings with the property owner", ownerVisits.length, periodSourcing.length),

        const SizedBox(height: 32),
        _buildDurationInsight(
          "Average Meeting Duration", 
          "Time spent per CP interaction", 
          periodSourcing.map((s) => s.visitDuration).toList()
        ),

        const SizedBox(height: 32),
        _buildDataList('Total CP Meetings (${periodSourcing.length})', periodSourcing.map((s) => _StatsDataItem(s.channelPartnerId ?? 'Unknown CP', s)).toList(), Icons.groups_rounded, Colors.indigo),

        _buildDataList('First Meetings (${firstMeetings.length})', firstMeetings.map((s) => _StatsDataItem(s.channelPartnerId ?? 'Unknown CP', s)).toList(), Icons.person_add_alt_1_rounded, Colors.blue),

        _buildDataList('Follow-up Meetings (${followUps.length})', followUps.map((s) => _StatsDataItem(s.channelPartnerId ?? 'Unknown CP', s)).toList(), Icons.sync_rounded, Colors.orange),

        _buildDataList('Owner Connections (${ownerVisits.length})', ownerVisits.map((s) => _StatsDataItem(s.channelPartnerId ?? 'Unknown CP', s)).toList(), Icons.verified_user_rounded, Colors.purple),

        _buildDataList('Hospitality Extended (${hospitalityVisits.length})', hospitalityVisits.map((s) => _StatsDataItem(s.channelPartnerId ?? 'Unknown CP', s)).toList(), Icons.local_cafe_rounded, Colors.brown),
      ],
    );
  }

  Widget _buildSourcingBreakdown(int total, int first, int follow) {
    double firstRate = total > 0 ? (first / total) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Meeting Breakdown",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: matteBlack),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: firstRate,
                      strokeWidth: 10,
                      backgroundColor: Colors.orange.shade50,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${(firstRate * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: matteBlack)),
                      const Text("NEW", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    _miniFollowUpRow('Total Meetings', total.toString(), Colors.indigo),
                    const Divider(height: 20),
                    _miniFollowUpRow('First Time', first.toString(), Colors.blue),
                    const Divider(height: 20),
                    _miniFollowUpRow('Existing CP', follow.toString(), Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetric(String title, String subtitle, int achieved, int total) {
    double rate = total > 0 ? (achieved / total) : 0.0;
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
              const Icon(Icons.stars_rounded, color: goldAccent, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("${(rate * 100).toStringAsFixed(0)}%", style: const TextStyle(color: goldAccent, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(goldAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationInsight(String title, String subtitle, List<String?> durations) {
    int totalMinutes = 0;
    int validCount = 0;

    for (var d in durations) {
      if (d == null || d.isEmpty || d == 'N/A') continue;
      final mins = _parseDurationToMinutes(d);
      if (mins > 0) {
        totalMinutes += mins;
        validCount++;
      }
    }

    final double avg = validCount > 0 ? (totalMinutes / validCount) : 0.0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [matteBlack, Color(0xFF2C2C2E)],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: goldAccent, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("${avg.toStringAsFixed(0)} min", style: const TextStyle(color: goldAccent, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              ...List.generate(15, (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: index < (avg / 60 * 15).clamp(1, 15) ? goldAccent : Colors.white10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  int _parseDurationToMinutes(String duration) {
    try {
      // Expects format like "15 mins" or "1 hour 10 mins"
      final clean = duration.toLowerCase().replaceAll('mins', '').replaceAll('min', '').trim();
      if (clean.contains('hour')) {
        final parts = clean.split('hour');
        int h = int.tryParse(parts[0].trim()) ?? 0;
        int m = 0;
        if (parts.length > 1) {
          m = int.tryParse(parts[1].replaceAll('s', '').trim()) ?? 0;
        }
        return (h * 60) + m;
      }
      return int.tryParse(clean) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Widget _buildDataList(String title, List<_StatsDataItem> items, IconData icon, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
            const Spacer(),
            Text('${items.length} items', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.take(10).mapIndexed((idx, item) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (item.data is model_lead.Lead) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailView(lead: item.data)));
                  } else if (item.data is Sourcing) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SourcingDetailPage(sourcing: item.data)));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    children: [
                      Text('${idx + 1}.', style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: matteBlack))),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: matteBlack, fontSize: 17, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: ElevatedButton.icon(
        onPressed: _shareWhatsAppReport,
        icon: const Icon(Icons.share_rounded, color: Colors.white),
        label: const Text('Share WhatsApp Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: matteBlack,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _shareWhatsAppReport() {
    final now = DateTime.now();
    final startDate = _selectedDays == 0 
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(Duration(days: _selectedDays));
    final endDate = now;

    // Respect project filter in report
    var filteredLeads = _leads;
    if (_selectedProjectFilter != null) {
      filteredLeads = _leads.where((l) => l.projectId.contains(_selectedProjectFilter)).toList();
    }
    final filteredLeadNames = filteredLeads.map((l) => l.name).toSet();

    final buffer = StringBuffer();
    final dateRangeStr = _selectedDays == 0
      ? DateFormat('d MMMM yyyy').format(now)
      : "${DateFormat('d MMMM').format(startDate)} to ${DateFormat('d MMMM yyyy').format(endDate)}";

    final durationTitle = _selectedDays == 0 ? "Daily" : "$_selectedDays Days";

    if (_selectedTab == 'CRM') {
      final periodVisits = _siteVisits.where((v) {
        if (v.visitDate == null) return false;
        final vDate = DateTime.tryParse(v.visitDate!);
        return vDate != null && vDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
               filteredLeadNames.contains(v.lead);
      }).toList();

      final visitDone = periodVisits.where((v) => v.status.toLowerCase() == 'visit done').toList();
      final revisitDone = periodVisits.where((v) => v.status.toLowerCase() == 'revisit done').toList();
      
      final directNames = <String>[];
      final cpNames = <String>[];
      final referenceNames = <String>[];

      for (var v in visitDone) {
        final lead = filteredLeads.firstWhereOrNull((l) => l.name == v.lead);
        if (lead == null) continue;
        final source = lead.source?.toLowerCase() ?? '';
        final isCP = source.contains('cp') || lead.customChannelPartner != null;
        final isRef = source.contains('reference');

        if (isCP) {
          cpNames.add(lead.customChannelPartner ?? lead.customerName);
        } else if (isRef) {
          referenceNames.add(lead.customerName);
        } else {
          directNames.add(lead.customerName);
        }
      }

      final warmLeads = filteredLeads.where((l) => (l.customLeadQuality ?? 0) >= 4).toList();
      final opportunities = filteredLeads.where((l) => l.customLeadStatus?.toLowerCase() == 'prospect').toList();
      final bookings = filteredLeads.where((l) => l.customLeadStatus?.toLowerCase() == 'won').toList();

      buffer.writeln("$durationTitle Report: Sanghvi Tirth ($dateRangeStr)");
      buffer.writeln("");
      
      buffer.writeln("• Total Visits: *${visitDone.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < visitDone.length; i++) {
        final lead = filteredLeads.firstWhereOrNull((l) => l.name == visitDone[i].lead);
        buffer.writeln("	${i + 1}) ${lead?.customerName ?? 'Unknown'}");
      }

      buffer.writeln("• Warm Leads: *${warmLeads.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < warmLeads.length; i++) {
        buffer.writeln("	${i + 1}) ${warmLeads[i].customerName}");
      }

      buffer.writeln("• Opportunities: *${opportunities.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < opportunities.length; i++) {
        buffer.writeln("	${i + 1}) ${opportunities[i].customerName}");
      }
      
      buffer.writeln("• Revisits: *${revisitDone.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < revisitDone.length; i++) {
        final lead = filteredLeads.firstWhereOrNull((l) => l.name == revisitDone[i].lead);
        buffer.writeln("	${i + 1}) ${lead?.customerName ?? 'Unknown'}");
      }

      buffer.writeln("• Direct Walk-ins/Pole Kiosks: *${directNames.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < directNames.length; i++) {
        buffer.writeln("	${i + 1}) ${directNames[i]}");
      }

      buffer.writeln("• Reference: *${referenceNames.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < referenceNames.length; i++) {
        buffer.writeln("	${i + 1}) ${referenceNames[i]}");
      }

      buffer.writeln("• CP Visits: *${cpNames.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < cpNames.length; i++) {
        buffer.writeln("	${i + 1}) ${cpNames[i]}");
      }

      buffer.writeln("• Bookings: *${bookings.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < bookings.length; i++) {
        buffer.writeln("	${i + 1}) ${bookings[i].customerName}");
      }
    } else {
      // Sourcing Report logic
      final periodSourcing = _sourcingEntries.where((s) {
        if (s.visitDate == null) return false;
        final sDate = DateTime.tryParse(s.visitDate!);
        bool matchesProject = true;
        if (_selectedProjectFilter != null) {
          matchesProject = s.interestedProject?.any((p) => p.project == _selectedProjectFilter) ?? false;
        }
        return sDate != null && sDate.isAfter(startDate.subtract(const Duration(seconds: 1))) && matchesProject;
      }).toList();

      buffer.writeln("$durationTitle Sourcing Report: Sanghvi Tirth ($dateRangeStr)");
      buffer.writeln("");
      buffer.writeln("• Total CP Meetings: *${periodSourcing.length.toString().padLeft(2, '0')}*");
      for (int i = 0; i < periodSourcing.length; i++) {
        buffer.writeln("	${i + 1}) ${periodSourcing[i].channelPartnerId ?? 'Unknown CP'}");
      }
      buffer.writeln("• First Meetings: ${periodSourcing.where((s) => s.visitType?.toLowerCase() == 'first meeting').length.toString().padLeft(2, '0')}");
      buffer.writeln("• Follow-ups: ${periodSourcing.where((s) => s.visitType?.toLowerCase() == 'follow up').length.toString().padLeft(2, '0')}");
    }

    _launchUrl("https://wa.me/?text=${Uri.encodeComponent(buffer.toString())}");
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

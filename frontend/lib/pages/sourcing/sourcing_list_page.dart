import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/models/sourcing.dart';
import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/auth_service.dart';
import 'sourcing_create_page.dart';
import 'sourcing_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:Homesol/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SourcingListPage extends StatefulWidget {
  final String? developerId;
  final bool showAddButton;
  final String searchQuery;
  final bool isStandaloneView;

  const SourcingListPage({
    super.key, 
    this.developerId, 
    this.showAddButton = true,
    this.searchQuery = '',
    this.isStandaloneView = true,
  });

  @override
  State<SourcingListPage> createState() => _SourcingListPageState();
}

const Color goldAccent = Color(0xFF675D40);
const Color matteBlack = Color(0xFF1A1A1A);
const Color offWhite = Color(0xFFF9F9F9);
const Color kBackgroundColor = Color(0xFFF2F2F7);

class _SourcingListPageState extends State<SourcingListPage> {
  Future<List<Sourcing>>? _future;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedVisitFilters = {};
  List<Sourcing> _allSources = [];
  Map<String, Map<String, double>> _projectLocations = {};
  List<ChannelPartner> _channelPartners = [];
  Map<String, String> _projectNames = {};
  String? _currentUserDesignation;
  Map<String, DateTime> _activeTimers = {};

  int _selectedDays = 15;

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: true);
    _fetchProfile();
    _loadPersistedTimers();
  }

  Future<void> _loadPersistedTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? timersJson = prefs.getString('active_sourcing_timers');
      if (timersJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(timersJson);
        final Map<String, DateTime> restored = {};
        decoded.forEach((key, value) {
          restored[key] = DateTime.parse(value as String);
        });
        if (mounted) {
          setState(() {
            _activeTimers = restored;
          });
        }
      }
    } catch (e) {
      print('Failed to load persisted timers: $e');
    }
  }

  Future<void> _saveTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> encoded = {};
      _activeTimers.forEach((key, value) {
        encoded[key] = value.toIso8601String();
      });
      await prefs.setString('active_sourcing_timers', jsonEncode(encoded));
    } catch (e) {
      print('Failed to save timers: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await AuthService.getMyProfile();
      if (mounted) {
        setState(() {
          _currentUserDesignation = profile?.designation;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final Future<List<Sourcing>> sourcingFuture = widget.developerId != null
          ? SourcingService.getSourcingByDeveloper(widget.developerId!, forceRefresh: forceRefresh)
          : SourcingService.getMySources(forceRefresh: forceRefresh);

      final results = await Future.wait([
        sourcingFuture,
        ProjectService.fetchProjectLocations(),
        ChannelPartnerService.fetchAllChannelPartners(forceRefresh: forceRefresh),
        ProjectService.fetchApiProjects(forceRefresh: forceRefresh),
      ]);
      
      final sources = results[0] as List<Sourcing>;
      final projectLocs = results[1] as List<Map<String, dynamic>>;
      final partners = results[2] as List<ChannelPartner>;
      final apiProjects = results[3] as List<Map<String, String>>;
      
      final Map<String, Map<String, double>> locMap = {};
      for (var loc in projectLocs) {
        if (loc['project_id'] != null && loc['latitude'] != null && loc['longitude'] != null) {
          locMap[loc['project_id'].toString()] = {
            'lat': double.tryParse(loc['latitude'].toString()) ?? 0.0,
            'lng': double.tryParse(loc['longitude'].toString()) ?? 0.0,
          };
        }
      }

      final Map<String, String> pNames = {};
      for (var p in apiProjects) {
        if (p['id'] != null) {
          pNames[p['id']!] = p['name'] ?? p['id']!;
        }
      }

      setState(() {
        _allSources = sources;
        _projectLocations = locMap;
        _channelPartners = partners;
        _projectNames = pNames;
        _future = Future.value(sources);
      });
    } catch (e) {
      print('Error loading sourcing data: $e');
      setState(() {
        _future = Future.error(e);
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) *
        (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000; // Result in meters
  }

  String _getFirmName(String? partnerId) {
    if (partnerId == null || partnerId.isEmpty) return 'No Sales Partner';
    try {
      final partner = _channelPartners.firstWhere((p) => p.name == partnerId);
      return partner.firmName ?? partnerId;
    } catch (_) {
      return partnerId; // Fallback to ID if not found
    }
  }

  String _getMeetingType(Sourcing source) {
    if (source.interestedProject == null || source.location == null) return 'OBM';
    
    final projectLoc = _projectLocations[source.interestedProject];
    if (projectLoc == null) return 'OBM';

    try {
      final locData = jsonDecode(source.location!);
      final coords = locData['features'][0]['geometry']['coordinates'];
      final sfsLng = double.tryParse(coords[0].toString()) ?? 0.0;
      final sfsLat = double.tryParse(coords[1].toString()) ?? 0.0;
      
      final distance = _calculateDistance(sfsLat, sfsLng, projectLoc['lat']!, projectLoc['lng']!);
      return distance < 200 ? 'IBM' : 'OBM';
    } catch (e) {
      return 'OBM';
    }
  }

  List<Sourcing> _getDatedSources(List<Sourcing> sources) {
    final now = DateTime.now();
    return sources.where((source) {
      if (source.visitDate == null) return false;
      try {
        final visitDate = DateTime.parse(source.visitDate!);
        return now.difference(visitDate).inDays <= _selectedDays;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  List<Sourcing> _filteredSources(List<Sourcing> sources) {
    final datedSources = _getDatedSources(sources);
    return datedSources.where((source) {
      final effectiveSearch = widget.isStandaloneView ? _searchQuery : widget.searchQuery;
      final matchesSearch = effectiveSearch.isEmpty ||
          (source.name?.toLowerCase().contains(effectiveSearch.toLowerCase()) ?? false) ||
          (source.contactPersonMet?.toLowerCase().contains(effectiveSearch.toLowerCase()) ?? false) ||
          (source.mobileNumber?.toLowerCase().contains(effectiveSearch.toLowerCase()) ?? false);
      
      bool matchesStatus = _selectedVisitFilters.isEmpty;
      if (!matchesStatus) {
        final meetingType = _getMeetingType(source);
        matchesStatus = _selectedVisitFilters.contains(source.visitStatus ?? 'Unknown') ||
                        _selectedVisitFilters.contains(meetingType);
      }
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: FutureBuilder<List<Sourcing>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: goldAccent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(backgroundColor: goldAccent),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final sources = snapshot.data ?? [];
          final datedSources = _getDatedSources(sources);
          final filteredSources = _filteredSources(sources);

          return RefreshIndicator(
            onRefresh: () => _load(forceRefresh: true),
            color: goldAccent,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: filteredSources.length + 1,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSearchAndOverview(datedSources, isDark, filteredSources.length, sources.length);
                }

                if (filteredSources.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No sourcing entries found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final source = filteredSources[index - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: _buildSourceCard(source),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: (widget.showAddButton && _currentUserDesignation?.trim().toLowerCase() != 'property developer') ? Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SourcingCreatePage()),
            );
            if (result == true) {
              _load();
            }
          },
          backgroundColor: matteBlack,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ) : null,
    );
  }

  Widget _buildSearchAndOverview(List<Sourcing> datedSources, bool isDark, int shown, int total) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Inline Header ──
          if (widget.isStandaloneView)
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 16,
                16,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sourcing',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$shown of $total entries',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _load(forceRefresh: true),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 19,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          if (widget.isStandaloneView)
            const SizedBox(height: 14),

          // ── Search Bar ──
          if (widget.isStandaloneView)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search by name, mobile...',
                    hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => setState(() { _searchQuery = ''; _searchController.clear(); }),
                            child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),

          if (widget.isStandaloneView)
            const SizedBox(height: 12),

          // ── Time Range Selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTimeRangeSelector(),
          ),

          // ── Summary Chart ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildSummaryWidgets(datedSources),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [15, 30, 45].map((days) {
          final isSelected = _selectedDays == days;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDays = days),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? goldAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: goldAccent.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    'Last $days Days',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryWidgets(List<Sourcing> datedSources) {
    final totalCount = datedSources.length;
    
    // Calculate counts by status
    final Map<String, int> statusCounts = {};
    int ibmCount = 0;
    int obmCount = 0;

    for (var s in datedSources) {
      final status = s.visitStatus ?? 'Unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      
      if (_getMeetingType(s) == 'IBM') {
        ibmCount++;
      } else {
        obmCount++;
      }
    }

    final List<PieChartSectionData> chartSections = [];
    
    // Visit Status Chart Sections
    final sortedStatuses = statusCounts.keys.toList()..sort();
    final List<Color> statusColors = [
      Colors.green.shade400,
      Colors.blue.shade400,
      Colors.orange.shade400,
      Colors.red.shade400,
      Colors.purple.shade400,
    ];

    for (int i = 0; i < sortedStatuses.length; i++) {
      final status = sortedStatuses[i];
      final count = statusCounts[status]!;
      chartSections.add(PieChartSectionData(
        color: statusColors[i % statusColors.length],
        value: count.toDouble(),
        title: '',
        radius: _selectedVisitFilters.contains(status) ? 22 : 18,
      ));
    }

    if (chartSections.isEmpty) {
      chartSections.add(PieChartSectionData(
        color: Colors.grey.shade200,
        value: 1,
        title: '',
        radius: 18,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Source Overview',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: matteBlack),
                ),
                if (_selectedVisitFilters.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _selectedVisitFilters.clear()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: goldAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Clear Filter', style: TextStyle(color: goldAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                if (event is FlTapUpEvent &&
                                    pieTouchResponse != null &&
                                    pieTouchResponse.touchedSection != null) {
                                  final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                  if (index >= 0 && index < sortedStatuses.length) {
                                    final status = sortedStatuses[index];
                                    setState(() {
                                      if (_selectedVisitFilters.contains(status)) {
                                        _selectedVisitFilters.remove(status);
                                      } else {
                                        _selectedVisitFilters.add(status);
                                      }
                                    });
                                  }
                                }
                              },
                            ),
                            sectionsSpace: 2,
                            centerSpaceRadius: 42,
                            sections: chartSections,
                            startDegreeOffset: -90,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              totalCount.toString(),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: matteBlack, height: 1.0),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sources',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildSummaryRow('IBM', ibmCount, Colors.indigo.shade700, Icons.business_rounded),
                      _buildSummaryRow('OBM', obmCount, Colors.amber.shade700, Icons.location_on_rounded),
                      const Divider(height: 12),
                      ...sortedStatuses.asMap().entries.map((entry) {
                        return _buildLegendRow(
                          entry.value, 
                          statusCounts[entry.value]!, 
                          statusColors[entry.key % statusColors.length],
                          _selectedVisitFilters.contains(entry.value)
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int count, Color color, IconData icon) {
    final isSelected = _selectedVisitFilters.contains(label);
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedVisitFilters.contains(label)) {
            _selectedVisitFilters.remove(label);
          } else {
            _selectedVisitFilters.add(label);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12, 
                  color: isSelected ? matteBlack : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold,
                color: isSelected ? goldAccent : matteBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(String label, int count, Color color, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedVisitFilters.contains(label)) {
            _selectedVisitFilters.remove(label);
          } else {
            _selectedVisitFilters.add(label);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)] : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11, 
                  color: isSelected ? matteBlack : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.bold,
                color: isSelected ? goldAccent : matteBlack.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(Sourcing source) {
    final statusColor = _getStatusColor(source.visitStatus ?? '');
    final meetingType = _getMeetingType(source);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SourcingDetailPage(sourcing: source)),
              );
              if (result == true) {
                _load(forceRefresh: true);
              }
            },
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Accent Bar
                  Container(
                    width: 4,
                    color: statusColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Header: ID & Doc Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    source.name ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (meetingType.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Text(
                                        meetingType,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              _buildDocStatusBadge(source.docstatus ?? 0),
                            ],
                          ),
                          const SizedBox(height: 14),
                          
                          // Main Info: Name & Phone
                          Text(
                            _getFirmName(source.salesPartner),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B), // Slate 800
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  source.contactPersonMet ?? 'No Contact Person',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  source.salesPartner ?? 'No Sales Partner',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Additional Data
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (source.visitType != null && source.visitType!.isNotEmpty)
                                _buildInfoChip(Icons.category_outlined, source.visitType!),
                              if (source.cpInterest != null && source.cpInterest!.isNotEmpty)
                                _buildInfoChip(Icons.favorite_outline, source.cpInterest!),
                              if (source.interestedProject != null && source.interestedProject!.isNotEmpty)
                                _buildInfoChip(Icons.apartment_rounded, _projectNames[source.interestedProject!] ?? source.interestedProject!),
                              if (source.visitDuration != null && source.visitDuration!.isNotEmpty)
                                _buildInfoChip(Icons.timer_outlined, source.visitDuration!),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Footer: Date & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    source.visitDate != null
                                        ? DateFormat('dd MMM, yyyy').format(DateTime.parse(source.visitDate!))
                                        : 'N/A',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              _buildVisitStatusBadge(source.visitStatus ?? '', statusColor),
                            ],
                          ),
                          
                          Builder(
                            builder: (context) {
                              bool isToday = false;
                              if (source.visitDate != null) {
                                try {
                                  final visitDate = DateTime.parse(source.visitDate!);
                                  final now = DateTime.now();
                                  isToday = visitDate.year == now.year && visitDate.month == now.month && visitDate.day == now.day;
                                } catch (_) {}
                              }
                              
                              if (!isToday) return const SizedBox.shrink();
                              
                              final bool hasDuration = source.visitDuration != null && source.visitDuration!.isNotEmpty;
                              
                              return Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  children: [
                                    if (!hasDuration) ...[
                                      Expanded(
                                        child: _LiveTimerButton(
                                          source: source,
                                          startTime: _activeTimers[source.name],
                                          onStart: () {
                                            setState(() {
                                              _activeTimers[source.name!] = DateTime.now();
                                            });
                                            _saveTimers();
                                            CustomSnackBar.show(context, message: 'Timer started for ${_getFirmName(source.salesPartner)}', isError: false, title: 'Notice');

                                            // System push notification (for when app is killed - real device)
                                            final int notificationId = source.name.hashCode;
                                            final String firmName = _getFirmName(source.salesPartner);
                                            NotificationService.instance.scheduleTimerNotification(
                                              notificationId,
                                              'Meeting Ongoing',
                                              'It\'s been 30s with $firmName.',
                                              const Duration(seconds: 30),
                                            );

                                            // Backup: Future.delayed + immediate show (works on emulator + backgrounded app)
                                            Future.delayed(const Duration(seconds: 30), () {
                                              if (_activeTimers.containsKey(source.name)) {
                                                NotificationService.instance.showImmediateNotification(
                                                  notificationId,
                                                  'Meeting Ongoing',
                                                  'It\'s been 30s with $firmName.',
                                                );
                                              }
                                            });

                                            // 30 second in-app reminder
                                            Future.delayed(const Duration(seconds: 30), () {
                                              if (mounted && _activeTimers.containsKey(source.name)) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    elevation: 8,
                                                    margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                                                    padding: const EdgeInsets.all(16),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                    backgroundColor: matteBlack,
                                                    behavior: SnackBarBehavior.floating,
                                                    duration: const Duration(seconds: 6),
                                                    content: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(10),
                                                          decoration: BoxDecoration(
                                                            color: goldAccent.withOpacity(0.15),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(Icons.timer_rounded, color: goldAccent, size: 24),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        Expanded(
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              const Text(
                                                                'Meeting Ongoing',
                                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                'It\'s been 30s with ${_getFirmName(source.salesPartner)}.',
                                                                style: TextStyle(color: Colors.grey[300], fontSize: 13),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }
                                            });

                                          },
                                          onStop: (int minutes) async {
                                            setState(() {
                                              _activeTimers.remove(source.name);
                                              source.visitDuration = '$minutes mins';
                                            });
                                            _saveTimers();
                                            
                                            // Cancel the notification if stopped early
                                            NotificationService.instance.cancelNotification(source.name.hashCode);

                                            
                                            try {
                                              await SourcingService.updateSourcingFields(source.name!, {
                                                'visit_duration': '$minutes mins',
                                              });
                                              // Automatically submit the sourcing
                                              await SourcingService.updateDocStatus(source.name!, 1);
                                              
                                              if (mounted) {
                                                _showAutoOpenBottomSheet(source, minutes);
                                              }
                                            } catch (e) {
                                              debugPrint('Error saving duration: $e');
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(child: _buildQuestionnaireButton(source)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Interested': return const Color(0xFF34C759); // iOS Green
      case 'Not Interested': return const Color(0xFFFF3B30); // iOS Red
      case 'Follow-up': return const Color(0xFFFF9F0A); // iOS Orange
      case 'Visit Done': return const Color(0xFF007AFF); // iOS Blue
      case 'Revisit Done': return const Color(0xFF5856D6); // iOS Indigo
      case 'Revisit Scheduled': return const Color(0xFFAF52DE); // iOS Purple
      default: return const Color(0xFF8E8E93); // iOS Gray
    }
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kBackgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocStatusBadge(int status) {
    String text = 'DRAFT';
    Color color = const Color(0xFFFF9F0A);
    if (status == 1) { 
      text = 'SUBMITTED'; 
      color = const Color(0xFF34C759);
    } else if (status == 2) { 
      text = 'CANCELLED'; 
      color = const Color(0xFF8E8E93); 
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVisitStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireButton(Sourcing source) {
    return InkWell(
      onTap: () => _showQuestionnairePopup(source),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: matteBlack,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            const Text(
              'Questions',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateDurationString(int minutes) {
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$hours Hour${hours > 1 ? 's' : ''}';
    }
    return '$hours Hour${hours > 1 ? 's' : ''} and $remainingMins mins';
  }

  Future<void> _showAutoOpenBottomSheet(Sourcing source, int minutes) async {
    bool cancelled = false;
    bool isFinished = false;

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext bContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 5.0, end: 0.0),
              duration: const Duration(seconds: 5),
              onEnd: () {
                if (!cancelled) {
                  isFinished = true;
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context); // Close the bottom sheet
                  }
                  _showQuestionnairePopup(source, minutes); // Open the questionnaire
                }
              },
              builder: (context, value, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Icon(Icons.timer_outlined, size: 48, color: goldAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Timer Stopped!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: matteBlack,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Duration recorded as ${_calculateDurationString(minutes)}.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Opening Questionnaire in ${value.ceil()}s...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: goldAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: value / 5.0,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(goldAccent),
                        borderRadius: BorderRadius.circular(8),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            cancelled = true;
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      if (!cancelled && !isFinished) {
        // User dismissed by swiping down or tapping outside before timer ended
        cancelled = true;
      }
    });
  }

  void _showQuestionnairePopup(Sourcing source, [int? calculatedMinutes]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuestionnairePopup(
        source: source,
        initialCalculatedMinutes: calculatedMinutes,
        durationStringGenerator: _calculateDurationString,
        onSaved: () => _load(forceRefresh: true),
      ),
    );
  }
}

class _QuestionnairePopup extends StatefulWidget {
  final Sourcing source;
  final int? initialCalculatedMinutes;
  final String Function(int) durationStringGenerator;
  final VoidCallback onSaved;

  const _QuestionnairePopup({
    required this.source,
    this.initialCalculatedMinutes,
    required this.durationStringGenerator,
    required this.onSaved,
  });

  @override
  State<_QuestionnairePopup> createState() => _QuestionnairePopupState();
}

class _QuestionnairePopupState extends State<_QuestionnairePopup> {
  bool _isLoading = false;
  
  late bool _offeredCoffee;
  late bool _metTheOwner;
  late bool _askedAboutPriceTrends;
  late bool _consideringRedevelopment;
  late bool _concernedAboutInterestRates;
  late bool _comparedMicroMarkets;
  late bool _strictlyReraRegistered;
  
  String? _finalDurationStr;

  @override
  void initState() {
    super.initState();
    _offeredCoffee = widget.source.offeredCoffee == 1;
    _metTheOwner = widget.source.metTheOwner == 1;
    _askedAboutPriceTrends = widget.source.askedAboutPriceTrends == 1;
    _consideringRedevelopment = widget.source.consideringRedevelopment == 1;
    _concernedAboutInterestRates = widget.source.concernedAboutInterestRates == 1;
    _comparedMicroMarkets = widget.source.comparedMicroMarkets == 1;
    _strictlyReraRegistered = widget.source.strictlyReraRegistered == 1;
    
    if (widget.initialCalculatedMinutes != null) {
      _finalDurationStr = widget.durationStringGenerator(widget.initialCalculatedMinutes!);
    } else {
      _finalDurationStr = widget.source.visitDuration;
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    
    try {
      final fieldsToUpdate = {
        'visit_duration': _finalDurationStr,
        'offered_coffee': _offeredCoffee ? 1 : 0,
        'met_the_owner': _metTheOwner ? 1 : 0,
        'asked_about_price_trends': _askedAboutPriceTrends ? 1 : 0,
        'considering_redevelopment': _consideringRedevelopment ? 1 : 0,
        'concerned_about_interest_rates': _concernedAboutInterestRates ? 1 : 0,
        'compared_micro_markets': _comparedMicroMarkets ? 1 : 0,
        'strictly_rera_registered': _strictlyReraRegistered ? 1 : 0,
      };

      final result = await SourcingService.updateSourcingFields(widget.source.name!, fieldsToUpdate);
      if (result && mounted) {
        Navigator.pop(context);
        widget.onSaved();
        CustomSnackBar.show(context, message: 'Details saved successfully', isError: false, title: 'Notice');
      } else if (!result && mounted) {
        throw Exception("Failed to update on server");
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: 'Error saving: $e', isError: true, title: 'Error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSwitchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: matteBlack),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: goldAccent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sourcing Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: matteBlack, letterSpacing: -0.5),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_finalDurationStr != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Visit Duration', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(_finalDurationStr!, style: const TextStyle(fontSize: 18, color: goldAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    const Text('Questionnaire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: matteBlack)),
                    const SizedBox(height: 12),
                    
                    _buildSwitchRow('Did he offer coffee?', _offeredCoffee, (v) => setState(() => _offeredCoffee = v)),
                    _buildSwitchRow('Did you meet the owner?', _metTheOwner, (v) => setState(() => _metTheOwner = v)),
                    _buildSwitchRow('Did the client ask about recent price trends in the area?', _askedAboutPriceTrends, (v) => setState(() => _askedAboutPriceTrends = v)),
                    _buildSwitchRow('Is the client considering redevelopment properties?', _consideringRedevelopment, (v) => setState(() => _consideringRedevelopment = v)),
                    _buildSwitchRow('Are they concerned about current home loan interest rates?', _concernedAboutInterestRates, (v) => setState(() => _concernedAboutInterestRates = v)),
                    _buildSwitchRow('Did they compare this locality to a neighboring micro-market?', _comparedMicroMarkets, (v) => setState(() => _comparedMicroMarkets = v)),
                    _buildSwitchRow('Is the client strictly looking for RERA-registered projects?', _strictlyReraRegistered, (v) => setState(() => _strictlyReraRegistered = v)),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Bottom Save Button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTimerButton extends StatefulWidget {
  final Sourcing source;
  final DateTime? startTime;
  final VoidCallback onStart;
  final Function(int) onStop;

  const _LiveTimerButton({
    required this.source,
    this.startTime,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<_LiveTimerButton> createState() => _LiveTimerButtonState();
}

class _LiveTimerButtonState extends State<_LiveTimerButton> {
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.startTime != null) {
      _startTicking();
    }
  }

  @override
  void didUpdateWidget(_LiveTimerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startTime != oldWidget.startTime) {
      if (widget.startTime != null) {
        _startTicking();
      } else {
        _timer?.cancel();
      }
    }
  }

  void _startTicking() {
    _updateDuration();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateDuration();
      }
    });
  }

  void _updateDuration() {
    if (widget.startTime != null) {
      setState(() {
        _duration = DateTime.now().difference(widget.startTime!);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final bool isRunning = widget.startTime != null;

    return InkWell(
      onTap: () {
        if (isRunning) {
          final minutes = _duration.inMinutes > 0 ? _duration.inMinutes : 1;
          widget.onStop(minutes);
        } else {
          widget.onStart();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isRunning ? const Color(0xFFFF3B30).withOpacity(0.1) : const Color(0xFF675D40).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isRunning ? const Color(0xFFFF3B30).withOpacity(0.2) : const Color(0xFF675D40).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 18,
              color: isRunning ? const Color(0xFFFF3B30) : const Color(0xFF675D40),
            ),
            const SizedBox(width: 6),
            Text(
              isRunning ? 'Stop (${_formatDuration(_duration)})' : 'Start Timer',
              style: TextStyle(
                color: isRunning ? const Color(0xFFFF3B30) : const Color(0xFF675D40),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

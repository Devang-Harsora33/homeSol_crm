import 'package:flutter/material.dart';
import 'package:Homesol/models/sourcing.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'sourcing_create_page.dart';
import 'sourcing_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:convert';

class SourcingListPage extends StatefulWidget {
  final String? developerId;
  final bool showAddButton;
  const SourcingListPage({super.key, this.developerId, this.showAddButton = true});

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

  int _selectedDays = 15;

  @override
  void initState() {
    super.initState();
    _load();
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
      ]);
      
      final sources = results[0] as List<Sourcing>;
      final projectLocs = results[1] as List<Map<String, dynamic>>;
      
      final Map<String, Map<String, double>> locMap = {};
      for (var loc in projectLocs) {
        if (loc['project_id'] != null && loc['latitude'] != null && loc['longitude'] != null) {
          locMap[loc['project_id'].toString()] = {
            'lat': double.tryParse(loc['latitude'].toString()) ?? 0.0,
            'lng': double.tryParse(loc['longitude'].toString()) ?? 0.0,
          };
        }
      }

      setState(() {
        _allSources = sources;
        _projectLocations = locMap;
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
      final matchesSearch = _searchQuery.isEmpty ||
          (source.name?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (source.contactPersonMet?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (source.mobileNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
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
      floatingActionButton: widget.showAddButton ? Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
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

          const SizedBox(height: 14),

          // ── Search Bar ──
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
                _load();
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
                            source.contactPersonMet ?? 'No Contact Person',
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
                              Icon(Icons.call_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                source.mobileNumber ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Divider
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 12),
                          
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
}

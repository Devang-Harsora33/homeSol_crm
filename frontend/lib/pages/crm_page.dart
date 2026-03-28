
import 'dart:convert';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart' as model_lead;
import '../models/sales_team.dart';
import '../services/databases/lead_database.dart';
import '../models/project.dart';
import '../models/site_visit.dart';
import '../models/follow_up.dart';
import '../components/lead_detail_view.dart';
import '../services/auth_service.dart';
import 'crm/lead_creation_page.dart';
import 'create_site_visit_page.dart';
import 'create_followup_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import 'package:fl_chart/fl_chart.dart';

class CRMPage extends StatefulWidget {
  const CRMPage({super.key});

  @override
  State<CRMPage> createState() => _CRMPageState();
}

const Color goldAccent = Color(0xFF675D40);
const Color matteBlack = Color(0xFF1A1A1A);
const Color offWhite = Color(0xFFF9F9F9);
class _CRMPageState extends State<CRMPage> {
  static const kBackgroundColor = Color(0xFFF2F2F7);
  List<model_lead.Lead> leads = []; // Use aliased Lead
  List<Project> projects = [];
  List<SiteVisit> siteVisits = []; // Added siteVisits list
  List<FollowUp> followUps = []; // Added followUps list
  List<String> campaigns = [];
  List<String> territories = [];
  List<SalesTeam> salesTeams = [];
  bool isLoading = false;
  String? errorMessage;
  String? currentBrokerId;
  String? currentDesignation;

  // Filter state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedProjects = <String>{};
  final Set<String> _selectedStatuses = <String>{};
  double _budgetMinSlider = 0.5; // 50L in Crores
  double _budgetMaxSlider = 50.0; // 50Cr in Crores
  final Set<String> _selectedConfigurations = <String>{};
  final Set<String> _selectedDateFilters = <String>{};
  final Set<String> _selectedSources = <String>{};
  final Set<String> _selectedLeadQualities = <String>{};
  final Set<String> _selectedIndustries = <String>{};
  final Set<String> _selectedNCD = <String>{};
  final Set<String> _selectedVisited = <String>{};
  final Set<String> _selectedDeadReasons = <String>{};
  String? _selectedVisitFilter;
  String? _selectedFollowUpFilter;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _showNumberSelectionDialog(
      BuildContext context, model_lead.Lead lead, String action) async {
    final primaryNumber = lead.customerPhone;
    final secondaryNumber = lead.whatsappNo;

    final List<String> numbers = [];
    if (primaryNumber.isNotEmpty) {
      numbers.add(primaryNumber);
    }
    if (secondaryNumber != null &&
        secondaryNumber.isNotEmpty &&
        !numbers.contains(secondaryNumber)) {
      numbers.add(secondaryNumber);
    }

    if (numbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    if (numbers.length == 1) {
      final url = action == 'call'
          ? 'tel:${numbers.first}'
          : 'https://wa.me/${numbers.first}';
      _launchUrl(url);
      if (lead.name != null) {
        LeadService.recordButtonPress(
            lead.name!, action == 'call' ? 'Call Button' : 'WhatsApp Button');
      }
      return;
    }

    final bool isCall = action == 'call';
    final IconData headerIcon = isCall ? Icons.call : Icons.message;
    final String title = isCall ? 'Select a number to call' : 'Select a number for WhatsApp';
    final String subtitle = 'This lead has multiple numbers.';


    showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // Removes Material 3 tint
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header Section ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: goldAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(headerIcon, size: 32, color: goldAccent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: matteBlack,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // --- Numbers List ---
              ...numbers.map((number) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final url = isCall ? 'tel:$number' : 'https://wa.me/$number';
                        _launchUrl(url);
                        if (lead.name != null) {
                          LeadService.recordButtonPress(lead.name!,
                              isCall ? 'Call Button' : 'WhatsApp Button');
                        }
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: offWhite,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // Number Icon
                            Icon(
                              Icons.sim_card_rounded,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 16),
                            // Number Text
                            Expanded(
                              child: Text(
                                number,
                                style: const TextStyle(
                                  color: matteBlack,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Monospace', // Optional: looks good for numbers
                                ),
                              ),
                            ),
                            // Arrow indicator
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: goldAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),

              // --- Cancel Button ---
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  Future<void> _initializeData() async {
    await _getBrokerId();
    await _loadProjects(forceRefresh: true);
    await _loadLeads(forceRefresh: true);
    await _loadSiteVisits(); // Load site visits
    await _loadFollowUps(); // Load follow ups
    await _loadCampaigns(); // Load campaigns
    await _loadTerritories(); // Load territories
    await _loadSalesTeams(); // Load sales teams
  }

  Future<void> _loadSiteVisits() async {
    try {
      final fetchedSiteVisits = await SiteVisitService.fetchMySiteVisits(forceRefresh: true);
      setState(() {
        siteVisits = fetchedSiteVisits;
      });
    } catch (e) {
      print('Error loading site visits: $e');
    }
  }

  Future<void> _loadFollowUps() async {
    try {
      final fetchedFollowUps = await LeadService.fetchMyFollowups(forceRefresh: true);
      setState(() {
        followUps = fetchedFollowUps;
      });
    } catch (e) {
      print('Error loading follow ups: $e');
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      final fetchedCampaigns = await LeadService.fetchCampaigns(forceRefresh: true);
      setState(() {
        campaigns = fetchedCampaigns;
      });
    } catch (e) {
      print('Error loading campaigns: $e');
    }
  }

  Future<void> _loadTerritories() async {
    try {
      final fetchedTerritories = await LeadService.fetchTerritories(forceRefresh: true);
      setState(() {
        territories = fetchedTerritories;
      });
    } catch (e) {
      print('Error loading territories: $e');
    }
  }

  Future<void> _loadSalesTeams() async {
    try {
      final fetchedSalesTeams = await ApiService.syncSalesTeams(forceRefresh: true);
      setState(() {
        salesTeams = fetchedSalesTeams;
      });
    } catch (e) {
      print('Error loading sales teams: $e');
    }
  }

  Future<void> _getBrokerId() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null && userData['broker_id'] != null) {
        setState(() {
          currentBrokerId = userData['broker_id'].toString();
        });
      }
      
      final profile = await AuthService.getMyProfile();
      if (profile != null) {
        setState(() {
          currentDesignation = profile.designation;
        });
        print('Current User Designation: $currentDesignation');
      }
    } catch (e) {
      print('Error getting broker ID/Designation: $e');
    }
  }

  Future<void> _loadProjects({bool forceRefresh = false}) async {
    try {
      final fetchedProjects = await ProjectService.syncProjects(forceRefresh: forceRefresh);
      setState(() {
        projects = fetchedProjects;
      });
    } catch (e) {
      print('Error loading projects: $e');
    }
  }

  Future<void> _loadLeads({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (forceRefresh) {
        await LeadService.syncMyLeads(); // Sync data from API to local DB
        await _loadFollowUps();
      }
      
      // Fetch leads from local database
      final List<Map<String, dynamic>> rawLeads = await LeadDatabase().getAllLeads();
      final fetchedLeads = rawLeads.map((data) {
        // Since 'data' column stores the full JSON, decode it back to a Lead object
        final leadJson = json.decode(data['data']);
        return model_lead.Lead.fromJson(leadJson);
      }).toList();

      setState(() {
        leads = fetchedLeads;
        isLoading = false;
      });
      print('🔍 [CRM_PAGE] Loaded ${fetchedLeads.length} leads from local DB');
       for (var i = 0; i < fetchedLeads.length; i++) {
         print('   Lead $i: ${fetchedLeads[i].name} - ${fetchedLeads[i].customerName}');
       }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }



  List<model_lead.Lead> get _filteredLeads {
    List<model_lead.Lead> filtered = leads;

    // Text search
    print('🔍 [FILTER] Starting with ${filtered.length} leads');
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((lead) {
        // Search in basic lead fields
        if (lead.customerName.toLowerCase().contains(query) ||
            lead.customerPhone.contains(query) ||
            // FIXED: Search logic parenthesis and property access
            (lead.notes.any(
              (n) => n.note?.toLowerCase().contains(query) ?? false,
            ))) {
          return true;
        }

        // Search in project names
        for (final projectId in lead.projectId) {
          final project = projects.where((p) => p.id == projectId).firstOrNull;
          if (project != null &&
              project.projectName.toLowerCase().contains(query)) {
            return true;
          }
        }

        // Search in configurations
        for (final config in lead.configuration) {
          if (config.toLowerCase().contains(query)) {
            return true;
          }
        }

        return false;
      }).toList();
    }

    // Project filter
    if (_selectedProjects.isNotEmpty) {
      filtered = filtered.where((lead) {
        return lead.projectId.any((projectId) {
          // Check if the project ID is in selected projects
          if (_selectedProjects.contains(projectId)) return true;

          // Also check if the project name is in selected projects
          final projectName = projects
              .where((p) => p.id == projectId)
              .map((p) => p.projectName)
              .firstOrNull;
          if (projectName != null && _selectedProjects.contains(projectName)) {
            return true;
          }

          return false;
        });
      }).toList();
    }

    // Status filter - uses customLeadStatus
    if (_selectedStatuses.isNotEmpty) {
      filtered = filtered
          .where(
            (lead) =>
                lead.customLeadStatus != null && _selectedStatuses.contains(lead.customLeadStatus!),
          )
          .toList();
    }

    // Budget filter - check if lead budget range overlaps with slider range
    filtered = filtered.where((lead) {
      final minVal = double.tryParse(lead.customBudgetMin ?? '') ?? 0.0;
      final maxVal = double.tryParse(lead.customBudgetMax ?? '') ?? 0.0;

      // Slider values are in Crores (e.g., 0.5 = 50L). Compare directly as doubles.
      final sliderMin = _budgetMinSlider;
      final sliderMax = _budgetMaxSlider;

      // If lead has no budget info, keep it by default
      if (minVal == 0.0 && maxVal == 0.0) return true;

      // If only one bound is present, treat both as that value
      final leadMin = minVal > 0.0 ? minVal : maxVal;
      final leadMax = maxVal > 0.0 ? maxVal : minVal;

      // Check overlap between [leadMin, leadMax] and [sliderMin, sliderMax]
      return !(leadMax < sliderMin || leadMin > sliderMax);
    }).toList();

    // Configuration filter - case-insensitive match for BHK types
    if (_selectedConfigurations.isNotEmpty) {
      filtered = filtered.where((lead) {
        return lead.configuration.any((config) {
          // Split comma-separated configs and check each one
          final configItems = config.split(',').map((c) => c.trim().toUpperCase()).toList();
          return configItems.any((item) => _selectedConfigurations.contains(item));
        });
      }).toList();
    }

    // Source filter
    if (_selectedSources.isNotEmpty) {
      filtered = filtered.where((lead) => lead.source != null && _selectedSources.contains(lead.source!)).toList();
    }

    // Industry filter
    if (_selectedIndustries.isNotEmpty) {
      filtered = filtered.where((lead) => lead.industry != null && _selectedIndustries.contains(lead.industry!)).toList();
    }

    // Lead Quality filter - 0.2 = 1 star, 0.4 = 2 stars, 1.0 = 5 stars
    if (_selectedLeadQualities.isNotEmpty) {
      filtered = filtered.where((lead) {
        if (lead.customLeadQuality == null) return false;
        // Convert quality value to star count (multiply by 5 since 0.2 * 5 = 1 star)
        final starCount = (lead.customLeadQuality! * 5).round();
        for (final selectedQuality in _selectedLeadQualities) {
          final selectedStars = selectedQuality.runes.where((r) => r == '⭐'.runes.first).length;
          if (selectedStars == starCount) return true;
        }
        return false;
      }).toList();
    }

    // Date filter
    if (_selectedDateFilters.isNotEmpty) {
      final now = DateTime.now();
      filtered = filtered.where((lead) {
        if (lead.createdAt == null) return false;
        final leadDate = lead.createdAt!;

        for (final dateFilter in _selectedDateFilters) {
          switch (dateFilter) {
            case 'Today':
              if (leadDate.year == now.year &&
                  leadDate.month == now.month &&
                  leadDate.day == now.day) {
                return true;
              }
              break;
            case 'Last 7 days':
              if (leadDate.isAfter(now.subtract(const Duration(days: 7)))) {
                return true;
              }
              break;
            case 'This month':
              if (leadDate.year == now.year && leadDate.month == now.month) {
                return true;
              }
              break;
          }
        }
        return false;
      }).toList();
    }

    // Visited filter
    if (_selectedVisited.isNotEmpty) {
      filtered = filtered.where((lead) {
        final hasVisited = siteVisits.any((visit) => visit.lead == lead.name);
        if (_selectedVisited.contains('Yes') && hasVisited) {
          return true;
        }
        if (_selectedVisited.contains('No') && !hasVisited) {
          return true;
        }
        return false;
      }).toList();
    }

    // Next Contact Date filter
    if (_selectedNCD.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final endOfWeek = today.add(Duration(days: DateTime.daysPerWeek - today.weekday));

      filtered = filtered.where((lead) {
        if (lead.customLeadDate == null) return false;
        
        final ncd = DateTime.tryParse(lead.customLeadDate!);
        if (ncd == null) return false;

        final ncdDate = DateTime(ncd.year, ncd.month, ncd.day);

        for (final filter in _selectedNCD) {
          switch (filter) {
            case 'Today':
              if (ncdDate == today) return true;
              break;
            case 'Tomorrow':
              if (ncdDate == tomorrow) return true;
              break;
            case 'This Week':
              if (ncdDate.isAfter(today.subtract(const Duration(days: 1))) && ncdDate.isBefore(endOfWeek.add(const Duration(days: 1)))) return true;
              break;
          }
        }
        return false;
      }).toList();
    }

    // Visit Overview Filter
    if (_selectedVisitFilter != null) {
      filtered = filtered.where((lead) {
        final leadVisits = siteVisits.where((v) => v.lead == lead.name).toList();
        
        switch (_selectedVisitFilter) {
          case 'Scheduled':
            return leadVisits.any((v) => v.status.toLowerCase() == 'scheduled');
          case 'Rescheduled':
            // Explicit rescheduled OR multiple scheduled
            if (leadVisits.any((v) => v.status.toLowerCase() == 'rescheduled')) return true;
            return leadVisits.where((v) => v.status.toLowerCase() == 'scheduled').length > 1;
          case 'Site Visits Done':
            return leadVisits.any((v) => v.status.toLowerCase() == 'visit done');
          case 'Revisits Done':
            return leadVisits.any((v) => v.status.toLowerCase() == 'revisit done');
          case 'Cancelled Visits':
            return leadVisits.any((v) => 
              v.status.toLowerCase() == 'cancelled' || v.status.toLowerCase() == 'canceled'
            );
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedProjects.isNotEmpty ||
        _selectedStatuses.isNotEmpty ||
        _budgetMinSlider > 0.5 ||
        _budgetMaxSlider < 50.0 ||
        _selectedConfigurations.isNotEmpty ||
        _selectedDateFilters.isNotEmpty ||
        _selectedSources.isNotEmpty ||
        _selectedLeadQualities.isNotEmpty ||
        _selectedIndustries.isNotEmpty ||
        _selectedNCD.isNotEmpty ||
        _selectedVisited.isNotEmpty ||
        _selectedDeadReasons.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedProjects.clear();
      _selectedStatuses.clear();
      _budgetMinSlider = 0.5;
      _budgetMaxSlider = 50.0;
      _selectedConfigurations.clear();
      _selectedDateFilters.clear();
      _selectedSources.clear();
      _selectedLeadQualities.clear();
      _selectedIndustries.clear();
      _selectedNCD.clear();
      _selectedVisited.clear();
      _selectedDeadReasons.clear();
      _selectedVisitFilter = null;
    });
  }

  // int _getStatusCount(String status) {
  //   return _filteredLeads.where((lead) => lead.customLeadStatus == status).length;
  // }

  void _showFiltersSheet(BuildContext context) {
    const kAccent = Color(0xFF675D40);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final projectNames = projects.map((p) => p.projectName).toList();
    final List<String> fixedConfigurations = [
      '1BHK', '2BHK', '3BHK', '4BHK', '5BHK', 'Penthouse', 'Studio'
    ];

    final allSources = leads.map((l) => l.source ?? '').where((s) => s.isNotEmpty).toSet().toList()..sort();
    final allIndustries = leads.map((l) => l.industry ?? '').where((i) => i.isNotEmpty).toSet().toList()..sort();

    final Map<String, List<String>> categories = {
      'Projects': ['All', ...projectNames],
      'Status': ['Open', 'Prospect', 'Won', 'Lost'],
      'Budget': ['< 50L', '50L - 1Cr', '1Cr - 2Cr', '> 2Cr'],
      'Configuration': fixedConfigurations,
      'Date Added': ['Today', 'Last 7 days', 'This month'],
      'Source': allSources,
      'Lead Quality': ['⭐⭐⭐⭐⭐', '⭐⭐⭐⭐', '⭐⭐⭐', '⭐⭐', '⭐'],
      'Industry': allIndustries,
      'Next Contact': ['Today', 'Tomorrow', 'This Week'],
      'Visited': ['Yes', 'No'],
    };

    String currentCategory = 'Projects';
    Set<String> checked = <String>{};

    void updateCheckedItems() {
      switch (currentCategory) {
        case 'Projects': checked = Set.from(_selectedProjects); break;
        case 'Status': checked = Set.from(_selectedStatuses); break;
        case 'Budget': break; // Budget is handled by sliders
        case 'Configuration': checked = Set.from(_selectedConfigurations); break;
        case 'Date Added': checked = Set.from(_selectedDateFilters); break;
        case 'Source': checked = Set.from(_selectedSources); break;
        case 'Lead Quality': checked = Set.from(_selectedLeadQualities); break;
        case 'Industry': checked = Set.from(_selectedIndustries); break;
        case 'Next Contact': checked = Set.from(_selectedNCD); break;
        case 'Visited': checked = Set.from(_selectedVisited); break;
        default: checked = <String>{};
      }
    }

    updateCheckedItems();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : kBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final options = categories[currentCategory] ?? const <String>[];
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ),
                        TextButton(
                          onPressed: () => setSheetState(() => checked.clear()),
                          child: const Text('Clear All', style: TextStyle(color: Colors.red), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.35,
                          color: isDark ? Colors.grey[850] : Colors.white,
                          child: ListView(
                            children: categories.keys.map((k) {
                              final bool selected = k == currentCategory;
                              return Material(
                                color: selected ? (isDark ? kAccent.withOpacity(0.3) : kAccent.withOpacity(0.1)) : Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setSheetState(() {
                                      currentCategory = k;
                                      updateCheckedItems();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border(left: BorderSide(color: selected ? kAccent : Colors.transparent, width: 3)),
                                    ),
                                    child: Text(k, 
                                      style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? kAccent : null),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Expanded(
                          child: currentCategory == 'Budget'
                            ? Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Minimum Budget: ₹${_budgetMinSlider.toStringAsFixed(1)} Cr',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Slider(
                                      value: _budgetMinSlider,
                                      min: 0.5,
                                      max: 50,
                                      divisions: 99,
                                      activeColor: kAccent,
                                      onChanged: (value) {
                                        setSheetState(() {
                                          if (value <= _budgetMaxSlider) {
                                            _budgetMinSlider = value;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                      'Maximum Budget: ₹${_budgetMaxSlider.toStringAsFixed(1)} Cr',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Slider(
                                      value: _budgetMaxSlider,
                                      min: 0.5,
                                      max: 50,
                                      divisions: 99,
                                      activeColor: kAccent,
                                      onChanged: (value) {
                                        setSheetState(() {
                                          if (value >= _budgetMinSlider) {
                                            _budgetMaxSlider = value;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: kAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Range: ₹${_budgetMinSlider.toStringAsFixed(1)} Cr - ₹${_budgetMaxSlider.toStringAsFixed(1)} Cr',
                                        style: TextStyle(color: kAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final opt = options[index];
                                  final value = checked.contains(opt);
                                  return CheckboxListTile(
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    activeColor: kAccent,
                                    value: value,
                                    onChanged: (v) => setSheetState(() {
                                      if (v == true) {
                                        checked.add(opt);
                                      } else {
                                        checked.remove(opt);
                                      }
                                    }),
                                    title: Text(opt, overflow: TextOverflow.ellipsis),
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                switch (currentCategory) {
                                  case 'Projects': _selectedProjects.clear(); _selectedProjects.addAll(checked); break;
                                  case 'Status': _selectedStatuses.clear(); _selectedStatuses.addAll(checked); break;
                                  case 'Budget': break; // Budget is handled by sliders, no action needed here
                                  case 'Configuration': _selectedConfigurations.clear(); _selectedConfigurations.addAll(checked); break;
                                  case 'Date Added': _selectedDateFilters.clear(); _selectedDateFilters.addAll(checked); break;
                                  case 'Source': _selectedSources.clear(); _selectedSources.addAll(checked); break;
                                  case 'Lead Quality': _selectedLeadQualities.clear(); _selectedLeadQualities.addAll(checked); break;
                                  case 'Industry': _selectedIndustries.clear(); _selectedIndustries.addAll(checked); break;
                                  case 'Next Contact': _selectedNCD.clear(); _selectedNCD.addAll(checked); break;
                                  case 'Visited': _selectedVisited.clear(); _selectedVisited.addAll(checked); break;
                                }
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeadCreationPage()),
          ).then((_) => _loadLeads(forceRefresh: true)); // Refresh leads when returning from LeadCreationPage
        },
        backgroundColor: const Color(0xFF675D40),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600 ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'CRM',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _loadLeads(forceRefresh: true),
                        tooltip: 'Refresh',
                        icon: Icon(
                          Icons.refresh,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.9),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Icons.bookmark_border,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSearchAndFilterCard(),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadLeads(forceRefresh: true),
                  color: theme.colorScheme.primary,
                  child: _buildLeadsList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildSummaryWidgets() {
  // --- 1. Calculation Logic (Unchanged) ---
  final totalLeadsCount = leads.length;
  final totalSiteVisitsDone = siteVisits.where((v) => v.status.toLowerCase() == 'visit done').length;
  final totalRevisitsDone = siteVisits.where((v) => v.status.toLowerCase() == 'revisit done').length;
  
  final Map<String, int> scheduledCountByLead = {};
  int explicitRescheduled = 0;
  int totalScheduled = 0;
  
  for (var v in siteVisits) {
    final status = v.status.toLowerCase();
    if (status == 'scheduled') {
      totalScheduled++;
      scheduledCountByLead[v.lead] = (scheduledCountByLead[v.lead] ?? 0) + 1;
    } else if (status == 'rescheduled') {
      explicitRescheduled++;
    }
  }
  
  int totalRescheduled = explicitRescheduled;
  scheduledCountByLead.forEach((lead, count) {
    if (count > 1) {
      totalRescheduled += (count - 1);
    }
  });

  final totalCancelledSiteVisits = siteVisits.where((v) => 
    v.status.toLowerCase() == 'cancelled' || v.status.toLowerCase() == 'canceled'
  ).length;

  // --- 2. Chart Data Preparation ---
  final List<PieChartSectionData> chartSections = [
    if (totalScheduled > 0) _buildChartSection(totalScheduled, Colors.indigo, 'Scheduled'),
    if (totalRescheduled > 0) _buildChartSection(totalRescheduled, Colors.deepPurple, 'Rescheduled'),
    if (totalSiteVisitsDone > 0) _buildChartSection(totalSiteVisitsDone, Colors.green, 'Site Visits Done'),
    if (totalRevisitsDone > 0) _buildChartSection(totalRevisitsDone, Colors.orange, 'Revisits Done'),
    if (totalCancelledSiteVisits > 0) _buildChartSection(totalCancelledSiteVisits, Colors.red, 'Cancelled Visits'),
  ];

  if (chartSections.isEmpty) {
    chartSections.add(_buildChartSection(1, Colors.grey.shade300, 'None'));
  }

  // --- 3. Compact UI Layout ---
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0), // Reduced padding
      child: Column(
        mainAxisSize: MainAxisSize.min, // Tells column to take minimum vertical space
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Visit Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Side-by-Side Layout to save vertical space
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LEFT SIDE: Donut Chart
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 140, // Smaller height to prevent overflow
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                return;
                              }
                              final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              if (index < 0 || index >= chartSections.length) return;
                              
                              final label = (chartSections[index] as dynamic).label as String?;
                              if (label == null || label == 'None') return;

                              if (event is FlTapUpEvent) {
                                setState(() {
                                  if (_selectedVisitFilter == label) {
                                    _selectedVisitFilter = null;
                                  } else {
                                    _selectedVisitFilter = label;
                                  }
                                });
                              }
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 45, // Smaller hole
                          sections: chartSections,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                      // Center Text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totalLeadsCount.toString(),
                            style: const TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Leads',
                            style: TextStyle(
                              fontSize: 11, 
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // RIGHT SIDE: Compact Legend
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendRow(Icons.calendar_month_rounded, 'Scheduled', totalScheduled, Colors.indigo),
                    _buildLegendRow(Icons.event_repeat_rounded, 'Rescheduled', totalRescheduled, Colors.deepPurple),
                    _buildLegendRow(Icons.home_work_rounded, 'Site Visits Done', totalSiteVisitsDone, Colors.green),
                    _buildLegendRow(Icons.repeat_rounded, 'Revisits Done', totalRevisitsDone, Colors.orange),
                    _buildLegendRow(Icons.cancel_rounded, 'Cancelled Visits', totalCancelledSiteVisits, Colors.red),
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

// --- Helper Methods ---

Widget _buildFollowUpSummaryWidgets() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Filter follow-ups based on manager vs employee logic
  // If the user is a manager, they might already have team follow-ups from LeadService.fetchMyFollowups
  // if the backend implementation of get_team_followups_list handles it.
  
  final totalFollowUps = followUps.length;
  final pendingAndOpen = followUps.where((f) => f.status?.toLowerCase() == 'open').length;
  final completed = followUps.where((f) => f.status?.toLowerCase() == 'completed').length;
  
  final missed = followUps.where((f) {
    if (f.status?.toLowerCase() != 'open') return false;
    if (f.followUpDate == null) return false;
    final fDate = DateTime.tryParse(f.followUpDate!);
    if (fDate == null) return false;
    return fDate.isBefore(now);
  }).length;

  final totalLeadsCount = leads.length;

  // Chart Data
  final List<PieChartSectionData> chartSections = [
    if (pendingAndOpen > 0) _buildFollowUpChartSection(pendingAndOpen, Colors.blue, 'Open'),
    if (completed > 0) _buildFollowUpChartSection(completed, Colors.green, 'Completed'),
    if (missed > 0) _buildFollowUpChartSection(missed, Colors.red, 'Missed'),
  ];

  if (chartSections.isEmpty) {
    chartSections.add(_buildFollowUpChartSection(1, Colors.grey.shade300, 'None'));
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow up Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LEFT SIDE: Donut Chart
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                return;
                              }
                              final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              if (index < 0 || index >= chartSections.length) return;
                              
                              final label = (chartSections[index] as dynamic).label as String?;
                              if (label == null || label == 'None') return;

                              if (event is FlTapUpEvent) {
                                setState(() {
                                  if (_selectedFollowUpFilter == label) {
                                    _selectedFollowUpFilter = null;
                                  } else {
                                    _selectedFollowUpFilter = label;
                                  }
                                });
                              }
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 45,
                          sections: chartSections,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totalFollowUps.toString(),
                            style: const TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Follow ups',
                            style: TextStyle(
                              fontSize: 10, 
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // RIGHT SIDE: Legend
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFollowUpLegendRow(Icons.people_outline, 'My Leads', totalLeadsCount, Colors.orange),
                    _buildFollowUpLegendRow(Icons.history, 'Total Count', totalFollowUps, Colors.blueGrey),
                    _buildFollowUpLegendRow(Icons.pending_actions, 'Pending & Open', pendingAndOpen, Colors.blue),
                    _buildFollowUpLegendRow(Icons.event_busy, 'Missed', missed, Colors.red),
                    _buildFollowUpLegendRow(Icons.check_circle_outline, 'Completed', completed, Colors.green),
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

PieChartSectionData _buildFollowUpChartSection(int value, Color color, String label) {
  final bool isSelected = _selectedFollowUpFilter == label;
  return _PieData(
    label: label,
    color: isSelected ? color.withOpacity(0.8) : color,
    value: value.toDouble(),
    title: '', 
    radius: isSelected ? 22 : 16,
  );
}

Widget _buildFollowUpLegendRow(IconData icon, String label, int count, Color color) {
  final bool isSelected = _selectedFollowUpFilter == label;
  return Padding(
    padding: const EdgeInsets.only(bottom: 6.0),
    child: InkWell(
      onTap: () {
        setState(() {
          if (_selectedFollowUpFilter == label) {
            _selectedFollowUpFilter = null;
          } else {
            _selectedFollowUpFilter = label;
          }
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12, 
                  color: isSelected ? color : Colors.grey.shade800,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 13, 
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

PieChartSectionData _buildChartSection(int value, Color color, String label) {
  final bool isSelected = _selectedVisitFilter == label;
  return _PieData(
    label: label,
    color: isSelected ? color.withOpacity(0.8) : color,
    value: value.toDouble(),
    title: '', 
    radius: isSelected ? 22 : 16, // Highlight selected section
  );
}

Widget _buildLegendRow(IconData icon, String label, int count, Color color) {
  final bool isSelected = _selectedVisitFilter == label;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0), // Tighter spacing
    child: InkWell(
      onTap: () {
        setState(() {
          if (_selectedVisitFilter == label) {
            _selectedVisitFilter = null;
          } else {
            _selectedVisitFilter = label;
          }
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label == 'Site Visits Done' ? 'Visits Done' : (label == 'Cancelled Visits' ? 'Cancelled' : label),
                style: TextStyle(
                  fontSize: 12, 
                  color: isSelected ? color : Colors.grey.shade800,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 13, 
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSearchAndFilterCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const kAccent = Color(0xFF675D40);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, project...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showFiltersSheet(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateSiteVisitScreen(
                          onSiteVisitCreated: () {
                            _loadLeads();
                            _loadSiteVisits();
                          },
                        ),
                      ),
                    );
                  },
                  icon: const FaIcon(FontAwesomeIcons.house, size: 14),
                  label: const Text('Add Site Visit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF675D40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateFollowUpScreen(
                          onFollowUpCreated: () {
                            _loadLeads();
                            _loadFollowUps();
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Follow Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          if (_hasActiveFilters()) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._selectedProjects.map((p) => _buildFilterChip(p, () => setState(() => _selectedProjects.remove(p)))),
                  ..._selectedStatuses.map((s) => _buildFilterChip(s, () => setState(() => _selectedStatuses.remove(s)))),
                  if (_budgetMinSlider > 0.5 || _budgetMaxSlider < 50.0)
                    _buildFilterChip(
                      '₹${_budgetMinSlider.toStringAsFixed(1)}-${_budgetMaxSlider.toStringAsFixed(1)} Cr',
                      () => setState(() {
                        _budgetMinSlider = 0.5;
                        _budgetMaxSlider = 50.0;
                      })
                    ),
                  ..._selectedConfigurations.map((c) => _buildFilterChip(c, () => setState(() => _selectedConfigurations.remove(c)))),
                  ..._selectedDateFilters.map((d) => _buildFilterChip(d, () => setState(() => _selectedDateFilters.remove(d)))),
                  ..._selectedNCD.map((n) => _buildFilterChip(n, () => setState(() => _selectedNCD.remove(n)))),
                  ..._selectedVisited.map((v) => _buildFilterChip(v, () => setState(() => _selectedVisited.remove(v)))),
                  ..._selectedDeadReasons.map((r) => _buildFilterChip(r, () => setState(() => _selectedDeadReasons.remove(r)))),
                  
                  TextButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  )
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(label),
        onDeleted: onDeleted,
        backgroundColor: Colors.grey.shade200,
        deleteIconColor: Colors.grey.shade700,
      ),
    );
  }

  String _formatNumber(int number) {
    // Always return plain comma formatting like 1,000,000
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildLeadsList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading) {
      return ListView.builder(
        itemCount: 5, // Display 5 skeleton cards
        itemBuilder: (context, index) => const _LeadCardSkeleton(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading leads',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadLeads, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'There are no leads yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final filteredLeads = _filteredLeads;
    // Debug: log filtered leads before building the list
    print('🔍 [BUILD_LEADS] filteredLeads.length = ${filteredLeads.length}');
    for (var i = 0; i < filteredLeads.length; i++) {
      print('   [BUILD_LEADS] Lead $i: ${filteredLeads[i].name} - ${filteredLeads[i].customerName}');
    }

    if (filteredLeads.isEmpty && (_hasActiveFilters() || _selectedVisitFilter != null)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No leads match your filters',
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredLeads.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              _buildSummaryWidgets(),
              _buildFollowUpSummaryWidgets(),
            ],
          );
        }
        
        final leadIndex = index - 1;
        print('🔍 [BUILD_LEADS] building item $leadIndex');
        final lead = filteredLeads[leadIndex];
        return GestureDetector(
          onTap: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LeadDetailView(lead: lead)),
            );
            // If the result is true, it means the lead was deleted, so refresh the list
            if (result == true) {
              _loadLeads();
            }
          },
          child: _LeadCard(
            lead: lead,
            projects: projects,
            siteVisits: siteVisits, // Pass siteVisits here
            followUps: followUps, // Pass followUps here
            currentDesignation: currentDesignation,
            onCall: () => _showNumberSelectionDialog(context, lead, 'call'),
            onWhatsApp: () =>
                _showNumberSelectionDialog(context, lead, 'whatsapp'),
            onFollowUp: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateFollowUpScreen(
                    preselectedLeadId: lead.name,
                    onFollowUpCreated: () {
                      _loadLeads();
                      _loadFollowUps();
                    },
                  ),
                ),
              );
            },
            onSiteVisit: () async {
              await Navigator.push(                context,
                MaterialPageRoute(
                  builder: (context) => CreateSiteVisitScreen(
                    preselectedLeadId: lead.name,
                    preselectedLeadDisplayName: lead.leadName,
                    preselectedProjectId: lead.customInterestedProject ??
                        (lead.projectId.isNotEmpty
                            ? lead.projectId.first
                            : null),
                    onSiteVisitCreated: () { // Add this callback
                      _loadLeads();
                      _loadSiteVisits();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}


class _LeadCard extends StatelessWidget {
  final model_lead.Lead lead;
  final List<Project> projects;
  final List<SiteVisit> siteVisits; // Added siteVisits
  final List<FollowUp> followUps; // Added followUps
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onSiteVisit;
  final VoidCallback onFollowUp;
  final String? currentDesignation;

  const _LeadCard({
    required this.lead,
    required this.projects,
    required this.siteVisits, // Required
    required this.followUps, // Required
    required this.onCall,
    required this.onWhatsApp,
    required this.onSiteVisit,
    required this.onFollowUp,
    this.currentDesignation,
  });

  FollowUp? _getLatestFollowUpForLead(String leadName) {
    final relevantFollowUps = followUps
        .where((f) => f.leadId == leadName)
        .toList();

    if (relevantFollowUps.isEmpty) {
      return null;
    }

    relevantFollowUps.sort((a, b) {
      final dateTimeA = DateTime.tryParse(a.followUpDate ?? '') ?? DateTime(0);
      final dateTimeB = DateTime.tryParse(b.followUpDate ?? '') ?? DateTime(0);
      return dateTimeB.compareTo(dateTimeA); // Sort in descending order
    });
    return relevantFollowUps.first;
  }

  SiteVisit? _getLatestSiteVisitForLead(String leadName) {
    final relevantVisits = siteVisits
        .where((visit) => visit.lead == leadName)
        .toList();

    if (relevantVisits.isEmpty) {
      return null;
    }

    relevantVisits.sort((a, b) {
      final dateTimeA = DateTime.tryParse(a.visitScheduledDatetime ?? '') ?? DateTime(0);
      final dateTimeB = DateTime.tryParse(b.visitScheduledDatetime ?? '') ?? DateTime(0);
      return dateTimeB.compareTo(dateTimeA); // Sort in descending order
    });
    return relevantVisits.first;
  }

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);

    // Find the project name from the projects list
    final projectName = projects
        .firstWhere((p) => lead.projectId.contains(p.id),
            orElse: () => Project(
                  id: '',
                  projectName: 'N/A',
                  developer: '',
                  mandate: '',
                  reraId: '',
                  constructionStatus: '',
                  propertyType: '',
                  description: '',
                  projectRm: '',
                  locationName: '',
                  city: '',
                  state: '',
                  nearbyLandmarks: '',
                  projectApproval: '',
                  developmentScheme: '',
                  priceRangeMin: 0,
                  priceRangeMax: 0,
                  parkingType: '',
                  launchDate: '',
                  possessionDate: '',
                  targetPossession: '',
                  architect: '',
                  contractor: '',
                  electricalContractor: '',
                  reraLiasoning: '',
                  amenities: [],
                  documents: [],
                  brokerageSlabs: [],
                  configurations: [],
                  galleryImages: [],
                  projectTimeline: [],
                  creation: '',
                  modified: '',
                ))
        .projectName;
        
    final latestSiteVisit = _getLatestSiteVisitForLead(lead.name ?? '');
    final latestFollowUp = _getLatestFollowUpForLead(lead.name ?? '');

    // Logic for Visit Done Date
    DateTime? visitDoneDate;
    if (latestSiteVisit != null) {
      final latestVisitDateStr = latestSiteVisit.visitScheduledDatetime ?? latestSiteVisit.visitDate;
      final latestVisitDate = latestVisitDateStr != null ? DateTime.tryParse(latestVisitDateStr) : null;
      
      if (latestVisitDate != null) {
        final threeMonthsBefore = latestVisitDate.subtract(const Duration(days: 90));
        
        final visitDoneVisits = siteVisits.where((v) {
          if (v.lead != lead.name) return false;
          final status = v.status?.toLowerCase() ?? '';
          if (status != 'visit done') return false;
          
          final vDateStr = v.visitScheduledDatetime ?? v.visitDate;
          final vDate = vDateStr != null ? DateTime.tryParse(vDateStr) : null;
          if (vDate == null) return false;
          
          return vDate.isAfter(threeMonthsBefore) && vDate.isBefore(latestVisitDate.add(const Duration(seconds: 1)));
        }).toList();

        if (visitDoneVisits.isNotEmpty) {
          visitDoneVisits.sort((a, b) {
            final dA = DateTime.tryParse(a.visitScheduledDatetime ?? a.visitDate ?? '') ?? DateTime(0);
            final dB = DateTime.tryParse(b.visitScheduledDatetime ?? b.visitDate ?? '') ?? DateTime(0);
            return dB.compareTo(dA);
          });
          visitDoneDate = DateTime.tryParse(visitDoneVisits.first.visitScheduledDatetime ?? visitDoneVisits.first.visitDate ?? '');
        }
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.width > 600 ? 20 : 16),
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600 ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Customer Name and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (lead.leadName?.isEmpty ?? true) ? 'N/A' : lead.leadName!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getStatusColor(lead.customLeadStatus ?? '', context)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _titleCase(lead.customLeadStatus ?? 'N/A'),
                  style: TextStyle(
                    color: _getStatusColor(lead.customLeadStatus ?? '', context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: Key Details with Icons
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _leadDetailRow(context, Icons.business_rounded, projectName,
                  color: kAccent),
              _leadDetailRow(context, Icons.timeline_rounded, lead.customStages ?? 'N/A'),
              _leadDetailRow(context, Icons.work_outline_rounded, lead.customOccupation ?? 'N/A'),
              if (lead.emailId != null && lead.emailId!.isNotEmpty)
                _leadDetailRow(context, Icons.email_outlined, lead.emailId!),
              if (lead.source != null && lead.source!.isNotEmpty)
                _leadDetailRow(
                    context, Icons.bookmark_border_rounded, lead.source!),
              // New: Latest Site Visit Date and Status
              if (latestSiteVisit != null) ...[
                if (visitDoneDate != null)
                  _leadDetailRow(context, Icons.event_available_rounded,
                      'Visit Done Date: ${_formatPostedDate(visitDoneDate)}',
                      color: Colors.green.shade700),
                _leadDetailRow(context, Icons.calendar_month,
                    'Last Visit: ${_formatPostedDate(DateTime.tryParse(latestSiteVisit.visitScheduledDatetime ?? latestSiteVisit.visitDate ?? ''))}',
                    color: kAccent),
                _leadDetailRow(context, Icons.info_outline,
                    'Visit Status: ${_titleCase(latestSiteVisit.status)}',
                    color: _getVisitStatusColor(latestSiteVisit.status),
                    isBold: true),
              ],
              
              if (latestFollowUp != null)
                _leadDetailRow(context, Icons.event_note_rounded,
                    'Follow up: ${_formatPostedDate(DateTime.tryParse(latestFollowUp.followUpDate ?? ''))} (${latestFollowUp.status})',
                    color: Colors.orange.shade800),
            ],
          ),

          const SizedBox(height: 16),
          
          // Divider
          Divider(color: Colors.grey.shade200, thickness: 1),
          const SizedBox(height: 8),

          // Footer: Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.phone, color: Colors.blueGrey, size: 18),                    
                  onPressed: onCall,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                  onPressed: onWhatsApp,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                const SizedBox(width: 8), 

                // 3. Site Visit (Primary Action Button)
                ElevatedButton.icon(
                  onPressed: onSiteVisit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent, // Your Gold #675d40
                    foregroundColor: Colors.white, // Text & Icon Color
                    elevation: 0, // Flat "Matte" look
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Slightly rounded corners
                    ),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.house, size: 14),
                  label: const Text(
                    "Site Visit",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),

                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onFollowUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.history, size: 14),
                  label: const Text(
                    "Follow Up",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Creation Date Info
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Created: ${_formatPostedDate(lead.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // String _formatBudget(int budget) {
  //   if (budget >= 10000000) {
  //     return '${(budget / 10000000).toStringAsFixed(1)} Cr';
  //   }
  //   if (budget >= 100000) {
  //     return '${(budget / 100000).toStringAsFixed(1)} L';
  //   }
  //   return budget.toString();
  // }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatPostedDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';
  }

  Widget _leadDetailRow(BuildContext context, IconData icon, String text,
      {Color color = Colors.black54, bool isBold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.8)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
  switch (status.toLowerCase()) {
    case 'open':
      return Colors.blueGrey.shade600; 

    case 'prospect':
    case 'site visit scheduled': // Added common alias just in case
      return Colors.amber.shade800; 

    case 'won':
      return Colors.green.shade800; 

    case 'lost':
      return Colors.red.shade800; 
      
    default:
      // Fallback to your primary theme color
      return Theme.of(context).colorScheme.primary;
  }
}

Color _getVisitStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'scheduled':
      return Colors.blue.shade700;
    case 'completed':
      return Colors.green.shade700;
    case 'rescheduled':
      return Colors.orange.shade700;
    case 'canceled':
      return Colors.red.shade700;
    default:
      return Colors.grey.shade600;
  }
}
}

class _LeadCardSkeleton extends StatelessWidget {
  const _LeadCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color? skeletonColor = isDark ? Colors.grey[800] : Colors.grey[300];
    Color? highlightColor = isDark ? Colors.grey[700] : Colors.grey[200];

    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.width > 600 ? 20 : 16),
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600 ? 18 : 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Customer Name and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 18,
                color: skeletonColor,
              ),
              const SizedBox(width: 8),
              Container(
                width: 70,
                height: 20,
                color: skeletonColor,
                // borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: Key Details with Icons (Simplified for skeleton)
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildSkeletonDetailRow(skeletonColor),
              _buildSkeletonDetailRow(skeletonColor),
              _buildSkeletonDetailRow(skeletonColor),
              _buildSkeletonDetailRow(skeletonColor),
            ],
          ),

          const SizedBox(height: 16),
          
          // Divider
          Divider(color: Colors.grey.shade200, thickness: 1),
          const SizedBox(height: 8),

          // Footer: Actions
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 120,
                height: 36,
                color: skeletonColor,
                // borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Creation Date Info
          Row(
            children: [
              Container(width: 14, height: 14, color: skeletonColor),
              const SizedBox(width: 6),
              Container(
                width: 100,
                height: 12,
                color: skeletonColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonDetailRow(Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Container(
          width: 80,
          height: 13,
          color: color,
        ),
      ],
    );
  }
}

class _StarRatingDisplay extends StatelessWidget {
  final double rating; // Rating is from 0.0 to 1.0
  const _StarRatingDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    int numberOfStars = (rating / 0.2).round();
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < numberOfStars ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber[600],
          size: 20,
        );
      }),
    );
  }
}

extension _LeadActions on _CRMPageState {
  void _showEditLeadSheet(model_lead.Lead lead) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nameController = TextEditingController(text: lead.customerName);
    final phoneController = TextEditingController(text: lead.customerPhone);
    // Removed email controller (email field removed from schema)
    // FIXED: Passing the string from the first note if available
    final notesController = TextEditingController(
      text: lead.notes.isNotEmpty ? lead.notes.first.plainText : '',
    );
    final budgetController = TextEditingController(
      text: _formatNumber(lead.budget),
    );
    String status = lead.status ?? 'pending';
    int numericBudget = lead.budget;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Lead',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LabeledTextField(
                      label: 'Customer Name',
                      hint: 'Enter Name',
                      keyboardType: TextInputType.name,
                      controller: nameController,
                    ),
                    const SizedBox(height: 12),
                    _LabeledTextField(
                      label: 'Customer Phone',
                      hint: 'Enter Phone',
                      keyboardType: TextInputType.phone,
                      controller: phoneController,
                    ),
                    const SizedBox(height: 12),
                    // Email field removed from schema
                    _LabeledTextField(
                      label: 'Budget (₹)',
                      hint: 'Enter Budget',
                      keyboardType: TextInputType.number,
                      controller: budgetController,
                      onChanged: (value) {
                        final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                        numericBudget = int.tryParse(clean) ?? 0;
                        final formatted = _formatNumber(numericBudget);
                        if (formatted != value) {
                          budgetController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }
                      },
                    ),
                    // const SizedBox(height: 12),
                    // _LabeledDropdown(
                    //   label: 'Status',
                    //   hint: 'Status',
                    //   items: const [
                    //     'pending',
                    //     'qualified',
                    //     'unqualified',
                    //     'closed',
                    //   ],
                    //   value: status,
                    //   onChanged: (v) =>
                    //       setSheetState(() => status = v ?? status),
                    // ),
                    const SizedBox(height: 12),
                    _LabeledMultiline(
                      label: 'Notes',
                      hint: 'Enter notes',
                      controller: notesController,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await LeadService.updateLead(lead.id ?? '', {
                              'customer_name': nameController.text,
                              'customer_phone': phoneController.text,
                              'budget': numericBudget,
                              'status': status,
                              'notes': notesController.text,
                            });
                            Navigator.pop(context);
                            _loadLeads(forceRefresh: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Lead updated',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.black,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save Changes'),
                      ),
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

  void _confirmDeleteLead(model_lead.Lead lead) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(
            'Delete Lead?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Text(
            'This action cannot be undone.',
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red.shade400),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await LeadService.deleteLead(lead.id ?? '');
        _loadLeads(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Lead deleted',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _LabeledText extends StatelessWidget {
  final String text;
  const _LabeledText(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.85),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FieldContainer extends StatelessWidget {
  final Widget child;
  const _FieldContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
        ),
      ),
      child: child,
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledText(label),
        _FieldContainer(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final List<String> items;
  final Function(String?)? onChanged;
  final String? value;
  const _LabeledDropdown({
    required this.label,
    required this.hint,
    required this.items,
    this.onChanged,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String? selected = value;
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledText(label),
            _FieldContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selected,
                  hint: Text(
                    hint,
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        0.6,
                      ),
                      fontSize: 16,
                    ),
                  ),
                  dropdownColor: theme.scaffoldBackgroundColor,
                  items: items
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => selected = v);
                    onChanged?.call(v);
                  },
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
// Note: This dropdown helper remains for edit sheet usage above; safe to keep.

class _LabeledMultiline extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  const _LabeledMultiline({
    required this.label,
    required this.hint,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledText(label),
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom data class to carry label
class _PieData extends PieChartSectionData {
  final String label;
  _PieData({
    required this.label,
    required double value,
    required Color color,
    required double radius,
    String title = '',
  }) : super(value: value, color: color, radius: radius, title: title);
}



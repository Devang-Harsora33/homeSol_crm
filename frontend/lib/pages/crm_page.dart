
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart' as model_lead;
import '../models/sales_team.dart';
import '../models/project.dart';
import '../models/site_visit.dart';
import '../models/follow_up.dart';
import '../components/lead_detail_view.dart';
import '../services/auth_service.dart';
import 'crm/lead_creation_page.dart' hide FirstWhereOrNullExtension;
import 'create_site_visit_page.dart' hide FirstWhereOrNullExtension;
import 'site_visit_detail_page.dart';
import 'crm/follow_up_detail_page.dart';
import 'create_followup_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import 'package:fl_chart/fl_chart.dart';
import '../components/project_share_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class CRMPage extends StatefulWidget {
  final String? developerId;
  const CRMPage({super.key, this.developerId});

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
  String? currentEmployeeId;
  String? currentUserEmail;
  String? currentDesignation;

  // Filter state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedProjects = <String>{};
  final Set<String> _selectedStatuses = <String>{};
  double _budgetMinSlider = 0.0; // 0Cr in Crores
  double _budgetMaxSlider = 100.0; // 100Cr in Crores
  final Set<String> _selectedConfigurations = <String>{};
  final Set<String> _selectedDateFilters = <String>{};
  final Set<String> _selectedSources = <String>{};
  final Set<String> _selectedLeadQualities = <String>{};
  final Set<String> _selectedIndustries = <String>{};
  final Set<String> _selectedNCD = <String>{};
  final Set<String> _selectedVisited = <String>{};
  final Set<String> _selectedDeadReasons = <String>{};
  final Set<String> _selectedVisitFilters = <String>{};
  final Set<String> _selectedFollowUpFilters = <String>{};
  int _selectedDays = 9999;
  String? _selectedUserFilter;
  String? _selectedProjectFilterForUser;
  final Map<String, String> _resolvedNames = {};

  @override
  void initState() {
    super.initState();
    // ScreenProtector.preventScreenshotOn();
    _initializeData();
  }

  @override
  void dispose() {
    // ScreenProtector.preventScreenshotOff();
    _searchController.dispose();
    super.dispose();
  }

  void _showReportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Generate Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.today, color: goldAccent),
                title: const Text('Daily Report (Today)'),
                onTap: () {
                  Navigator.pop(context);
                  _shareReport(isWeekly: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week, color: goldAccent),
                title: const Text('Weekly Report (Last 7 Days)'),
                onTap: () {
                  Navigator.pop(context);
                  _shareReport(isWeekly: true);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _shareReport({required bool isWeekly}) {
    final now = DateTime.now();
    final startDate = isWeekly ? now.subtract(const Duration(days: 7)) : DateTime(now.year, now.month, now.day);
    final endDate = now;

    final filteredLeadNames = _filteredLeads.map((l) => l.name).toSet();
    final periodVisits = siteVisits.where((v) {
      if (v.visitDate == null) return false;
      final vDate = DateTime.tryParse(v.visitDate!);
      if (vDate == null) return false;
      return vDate.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
             vDate.isBefore(endDate.add(const Duration(days: 1))) &&
             filteredLeadNames.contains(v.lead);
    }).toList();

    // Categories
    final visitDone = periodVisits.where((v) => v.status.toLowerCase() == 'visit done').toList();
    final revisitDone = periodVisits.where((v) => v.status.toLowerCase() == 'revisit done').toList();
    
    // Direct vs CP for visits
    final directVisits = <String>[];
    final cpVisits = <String>[];
    for (var v in visitDone) {
      final lead = leads.firstWhereOrNull((l) => l.name == v.lead);
      if (lead == null) continue;
      final isCP = (lead.source?.toLowerCase().contains('cp') ?? false) || lead.customChannelPartner != null;
      if (isCP) {
        cpVisits.add(lead.customChannelPartner ?? lead.customerName);
      } else {
        directVisits.add(lead.customerName);
      }
    }

    final revisits = revisitDone.map((v) {
      final lead = leads.firstWhereOrNull((l) => l.name == v.lead);
      return lead?.customerName ?? 'Unknown';
    }).toList();

    final warmLeadsCount = _filteredLeads.where((l) => (l.customLeadQuality ?? 0) >= 4).length;
    final opportunitiesCount = _filteredLeads.where((l) => l.customLeadStatus?.toLowerCase() == 'prospect').length;
    final bookings = _filteredLeads.where((l) => l.customLeadStatus?.toLowerCase() == 'won').map((l) => l.customerName).toList();

    final dateRangeStr = isWeekly 
      ? "${DateFormat('d MMMM').format(startDate)} to ${DateFormat('d MMMM yyyy').format(endDate)}"
      : DateFormat('d MMMM yyyy').format(now);

    final reportType = isWeekly ? "Weekly Report" : "Daily Report";
    final buffer = StringBuffer();
    buffer.writeln("$reportType: Sanghvi Tirth ($dateRangeStr)");
    buffer.writeln("");
    buffer.writeln("• Total Visits: *${visitDone.length.toString().padLeft(2, '0')}*");
    for (int i = 0; i < visitDone.length; i++) {
      final lead = leads.firstWhereOrNull((l) => l.name == visitDone[i].lead);
      buffer.writeln("  ${i + 1}) ${lead?.customerName ?? 'Unknown'}");
    }
    
    buffer.writeln("• Warm Leads: ${warmLeadsCount.toString().padLeft(2, '0')}");
    buffer.writeln("• Opportunities: ${opportunitiesCount.toString().padLeft(2, '0')}");
    
    buffer.writeln("• Revisits: *${revisits.length.toString().padLeft(2, '0')}*");
    for (int i = 0; i < revisits.length; i++) {
      buffer.writeln("  ${i + 1}) ${revisits[i]}");
    }

    buffer.writeln("• Direct Walk-ins: *${directVisits.length.toString().padLeft(2, '0')}*");
    for (int i = 0; i < directVisits.length; i++) {
      buffer.writeln("  ${i + 1}) ${directVisits[i]}");
    }

    buffer.writeln("• CP Visits: *${cpVisits.length.toString().padLeft(2, '0')}*");
    for (int i = 0; i < cpVisits.length; i++) {
      buffer.writeln("  ${i + 1}) ${cpVisits[i]}");
    }

    buffer.writeln("• Bookings: *${bookings.length.toString().padLeft(2, '0')}*");
    for (int i = 0; i < bookings.length; i++) {
      buffer.writeln("  ${i + 1}) ${bookings[i]}");
    }

    final message = Uri.encodeComponent(buffer.toString());
    _launchUrl("https://wa.me/?text=$message");
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      CustomSnackBar.show(context, message: 'No phone number available', isError: false, title: 'Notice');
      return;
    }

    if (numbers.length == 1) {
      String number = numbers.first.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (number.startsWith('0')) number = number.substring(1);
      if (number.length == 10) number = '91$number';

      final url = action == 'call'
          ? 'tel:${numbers.first}'
          : 'https://wa.me/$number';
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
                        String formattedNumber = number.trim().replaceAll(RegExp(r'[^0-9]'), '');
                        if (formattedNumber.startsWith('0')) formattedNumber = formattedNumber.substring(1);
                        if (formattedNumber.length == 10) formattedNumber = '91$formattedNumber';

                        final url = isCall ? 'tel:$number' : 'https://wa.me/$formattedNumber';
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
    await _loadSiteVisits(forceRefresh: true); // Load site visits
    await _loadFollowUps(forceRefresh: true); // Load follow ups
    await _loadCampaigns(); // Load campaigns
    await _loadTerritories(); // Load territories
    await _loadSalesTeams(); // Load sales teams
    await _resolveOwnerNames(); // Resolve names for lead owners
  }

  Future<void> _loadSiteVisits({bool forceRefresh = false}) async {
    try {
      final fetchedSiteVisits = (currentDesignation?.toLowerCase() == 'property developer' && widget.developerId != null)
          ? await SiteVisitService.fetchDeveloperSiteVisits(widget.developerId!, forceRefresh: forceRefresh)
          : await SiteVisitService.fetchMySiteVisits(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        siteVisits = fetchedSiteVisits;
      });
    } catch (e) {
      print('Error loading site visits: $e');
    }
  }

  Future<void> _loadFollowUps({bool forceRefresh = false}) async {
    try {
      final fetchedFollowUps = await LeadService.fetchMyFollowups(forceRefresh: forceRefresh);
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        salesTeams = fetchedSalesTeams;
      });
    } catch (e) {
      print('Error loading sales teams: $e');
    }
  }

  Future<void> _resolveOwnerNames() async {
    final Set<String> uniqueOwners = leads
        .map((l) => l.leadOwner?.toLowerCase().trim())
        .where((o) => o != null && o.isNotEmpty)
        .cast<String>()
        .toSet();

    // Prioritize resolving those that aren't already resolved in _resolvedNames
    final List<String> toResolve = uniqueOwners
        .where((o) => !_resolvedNames.containsKey(o))
        .toList();

    if (toResolve.isEmpty) return;

    print('🔍 [CRM_PAGE] Resolving names for ${toResolve.length} owners from Frappe: $toResolve');

    for (var email in toResolve) {
      try {
        final fullName = await ApiService.fetchUserFullName(email);
        if (fullName != null && fullName.isNotEmpty) {
          if (mounted) {
            setState(() {
              _resolvedNames[email] = fullName;
            });
          }
          print('✅ Resolved $email to $fullName');
        } else {
          print('⚠️ No full name found for $email');
          // Still mark as "tried" to avoid repeated attempts
          _resolvedNames[email] = email.split('@').first;
        }
      } catch (e) {
        print('❌ Error resolving name for $email: $e');
      }
    }
  }

  Future<void> _getBrokerId() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null && userData['broker_id'] != null) {
        if (!mounted) return;
        setState(() {
          currentBrokerId = userData['broker_id'].toString();
        });
      }
      
      final profile = await AuthService.getMyProfile();
      if (profile != null) {
        if (!mounted) return;
        setState(() {
          currentDesignation = profile.designation;
          currentEmployeeId = profile.employee;
          currentUserEmail = profile.userId;
          // Ensure currentBrokerId is set to something useful if null
          currentBrokerId ??= profile.employee;
        });
        print('Current User: ${profile.employeeName} | ID: ${profile.employee} | Email: ${profile.userId}');
      }
    } catch (e) {
      print('Error getting broker ID/Designation: $e');
    }
  }

  Future<void> _loadProjects({bool forceRefresh = false}) async {
    try {
      if (widget.developerId != null) {
        final dev = await DeveloperService.fetchDeveloperById(widget.developerId!);
        if (dev != null) {
          final allProjects = await ProjectService.fetchProjects();
          final List<Project> devProjects = [];
          for (final devProj in dev.projectsList) {
            try {
              final p = allProjects.firstWhere((element) => element.id == devProj.project);
              devProjects.add(p);
            } catch (_) {}
          }
          if (!mounted) return;
          setState(() {
            projects = devProjects;
          });
          return;
        }
      }
      final fetchedProjects = await ProjectService.syncProjects(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        projects = fetchedProjects;
      });
    } catch (e) {
      print('Error loading projects: $e');
    }
  }

  Future<void> _loadLeads({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (widget.developerId != null) {
        // Fetch leads for a specific developer from API
        final fetchedLeads = await LeadService.fetchLeadsByDeveloper(widget.developerId!);
        if (!mounted) return;
        setState(() {
          leads = fetchedLeads;
          isLoading = false;
        });
        print('🔍 [CRM_PAGE] Loaded ${fetchedLeads.length} leads for developer ${widget.developerId} from API');
        return;
      }

      // LeadService.fetchMyLeads handles local caching, connectivity checks, and sync
      final fetchedLeads = await LeadService.fetchMyLeads(forceRefresh: forceRefresh);

      if (!mounted) return;
      setState(() {
        leads = fetchedLeads;
        isLoading = false;
      });
      print('🔍 [CRM_PAGE] Loaded ${fetchedLeads.length} leads');
       for (var i = 0; i < fetchedLeads.length; i++) {
         print('   Lead $i: ${fetchedLeads[i].name} - ${fetchedLeads[i].customerName}');
       }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }



  List<model_lead.Lead> get _filteredLeads {
    List<model_lead.Lead> filtered = leads;

    // Project Filter (from Summary section)
    if (_selectedProjectFilterForUser != null) {
      final selProjId = _selectedProjectFilterForUser!.toLowerCase();
      // Also get the project name for this ID to be more robust
      final selProjName = projects.where((p) => p.id == _selectedProjectFilterForUser).firstOrNull?.projectName.toLowerCase();
      
      filtered = filtered.where((l) {
        return l.projectId.any((id) {
          final pid = id.toLowerCase();
          return pid == selProjId || (selProjName != null && pid == selProjName);
        });
      }).toList();
    }

    // User Filter
    if (_selectedUserFilter != null) {
      final selVal = _selectedUserFilter!.toLowerCase().trim();
      
      // Find the member to get their name and real email (if synced)
      String? selEmail;
      String? selName = _resolvedNames[selVal]; // Check resolved names first
      
      if (selName == null) {
        for (var team in salesTeams) {
          for (var m in team.members) {
            if (m.employee.toLowerCase() == selVal || m.userId?.toLowerCase() == selVal) {
              selEmail = m.userId?.toLowerCase().trim();
              selName = m.employeeName.toLowerCase().trim();
              break;
            }
          }
          if (selName != null) break;
        }
      }

      print('🔍 [DEBUG_FILTER] Selecting User: $selVal | Resolved Name: $selName | selEmail: $selEmail');

      filtered = filtered.where((l) {
        final owner = l.leadOwner?.toLowerCase().trim();

        bool isMatched = false;
        
        // 1. Strict exact match against the explicit email (if we have it)
        if (selEmail != null && selEmail.isNotEmpty) {
          isMatched = owner == selEmail;
        } 
        // 2. Strict match against the selected value (ID)
        else if (owner == selVal) {
          isMatched = true;
        }
        // 3. Mandatory Fallback (Triggered if ERP permissions block Employee doctype read)
        else {
           // We are missing the email locally. The backend stores emails (neha@...), but we only have ID (hr-emp...).
           bool matchPrefix(String? field) {
             if (field == null || !field.contains('@')) return false;
             final prefix = field.split('@').first;
             // Match prefix against ID or First Name
             if (prefix == selVal) return true;
             
             final firstName = selName?.split(' ').first;
             if (firstName != null && prefix == firstName) return true;
             
             // Check if prefix matches the full name without spaces
             final nameNoSpaces = selName?.replaceAll(' ', '');
             if (nameNoSpaces != null && nameNoSpaces.contains(prefix)) return true;
             
             return false;
           }
           
           isMatched = matchPrefix(owner);
        }
        
        if (owner?.contains('neha') == true || owner?.contains('suraj') == true) {
          print('🔍 [DEBUG_FILTER] Lead: ${l.name}, Owner: "$owner" | Matched: $isMatched');
        }

        return isMatched;
      }).toList();
      
      print('🔍 [DEBUG_FILTER] Filtered result: ${filtered.length} leads');
    }

    // Days Filter
    if (_selectedDays != 9999) {
      final now = DateTime.now();
      filtered = filtered.where((lead) {
        if (lead.createdAt == null) return false;
        return now.difference(lead.createdAt!).inDays <= _selectedDays;
      }).toList();
    }

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
      final selectedProjectIds = _selectedProjects.map((id) => id.toLowerCase()).toSet();
      final selectedProjectNames = _selectedProjects
          .map((id) => projects.where((p) => p.id == id).firstOrNull?.projectName.toLowerCase())
          .where((name) => name != null)
          .cast<String>()
          .toSet();

      filtered = filtered.where((lead) {
        return lead.projectId.any((id) {
          final pid = id.toLowerCase();
          return selectedProjectIds.contains(pid) || selectedProjectNames.contains(pid);
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

      // Slider values are in Crores (e.g., 1.0 = 1Cr). Compare directly as doubles.
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
    if (_selectedVisitFilters.isNotEmpty) {
      filtered = filtered.where((lead) {
        final leadVisits = siteVisits.where((v) => v.lead == lead.name).toList();
        
        for (final filter in _selectedVisitFilters) {
          switch (filter) {
            case 'Visit Scheduled':
              if (leadVisits.any((v) => v.status.toLowerCase() == 'visit scheduled' || v.status.toLowerCase() == 'scheduled')) return true;
              break;
            case 'Visit Done':
              if (leadVisits.any((v) => v.status.toLowerCase() == 'visit done' || v.status.toLowerCase() == 'site visits done')) return true;
              break;
          }
        }
        return false;
      }).toList();
    }

    // Follow-up Overview Filter
    if (_selectedFollowUpFilters.isNotEmpty) {
      final now = DateTime.now();
      filtered = filtered.where((lead) {
        final leadFollowUps = followUps.where((f) => f.leadId == lead.name).toList();
        
        for (final filter in _selectedFollowUpFilters) {
          switch (filter) {
            case 'Open':
              if (leadFollowUps.any((f) => f.status?.toLowerCase() == 'open')) return true;
              break;
            case 'Completed':
              if (leadFollowUps.any((f) => f.status?.toLowerCase() == 'completed')) return true;
              break;
            case 'Missed':
              if (leadFollowUps.any((f) {
                if (f.status?.toLowerCase() != 'open') return false;
                if (f.followUpDate == null) return false;
                final fDate = DateTime.tryParse(f.followUpDate!);
                if (fDate == null) return false;
                return fDate.isBefore(now);
              })) return true;
              break;
          }
        }
        return false;
      }).toList();
    }

    filtered.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedProjects.isNotEmpty ||
        _selectedStatuses.isNotEmpty ||
        _budgetMinSlider > 0.0 ||
        _budgetMaxSlider < 100.0 ||
        _selectedConfigurations.isNotEmpty ||
        _selectedDateFilters.isNotEmpty ||
        _selectedSources.isNotEmpty ||
        _selectedLeadQualities.isNotEmpty ||
        _selectedIndustries.isNotEmpty ||
        _selectedNCD.isNotEmpty ||
        _selectedVisited.isNotEmpty ||
        _selectedDeadReasons.isNotEmpty ||
        _selectedVisitFilters.isNotEmpty ||
        _selectedFollowUpFilters.isNotEmpty ||
        _selectedUserFilter != null;
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedProjects.clear();
      _selectedStatuses.clear();
      _budgetMinSlider = 0.0;
      _budgetMaxSlider = 100.0;
      _selectedConfigurations.clear();
      _selectedDateFilters.clear();
      _selectedSources.clear();
      _selectedLeadQualities.clear();
      _selectedIndustries.clear();
      _selectedNCD.clear();
      _selectedVisited.clear();
      _selectedDeadReasons.clear();
      _selectedVisitFilters.clear();
      _selectedFollowUpFilters.clear();
      _selectedDays = 9999;
      _selectedUserFilter = null;
      _selectedProjectFilterForUser = null;
    });
  }

  // int _getStatusCount(String status) {
  //   return _filteredLeads.where((lead) => lead.customLeadStatus == status).length;
  // }

  // ---------- helpers for filter bottom sheet ----------
  int _getFilterCount(String category) {
    switch (category) {
      case 'Projects':       return _selectedProjects.length;
      case 'Status':         return _selectedStatuses.length;
      case 'Budget':         return (_budgetMinSlider > 0.0 || _budgetMaxSlider < 100.0) ? 1 : 0;
      case 'Configuration': return _selectedConfigurations.length;
      case 'Date Added':    return _selectedDateFilters.length;
      case 'Source':        return _selectedSources.length;
      case 'Lead Quality':  return _selectedLeadQualities.length;
      case 'Industry':      return _selectedIndustries.length;
      case 'Next Contact':  return _selectedNCD.length;
      case 'Visited':       return _selectedVisited.length;
      case 'Visit Status':  return _selectedVisitFilters.length;
      case 'Follow-up Status': return _selectedFollowUpFilters.length;
      default: return 0;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Projects':       return Icons.apartment_rounded;
      case 'Status':         return Icons.label_rounded;
      case 'Budget':         return Icons.currency_rupee_rounded;
      case 'Configuration': return Icons.bed_rounded;
      case 'Date Added':    return Icons.calendar_today_rounded;
      case 'Source':        return Icons.alt_route_rounded;
      case 'Lead Quality':  return Icons.star_rounded;
      case 'Industry':      return Icons.business_center_rounded;
      case 'Next Contact':  return Icons.schedule_rounded;
      case 'Visited':       return Icons.home_work_rounded;
      case 'Visit Status':  return Icons.explore_rounded;
      case 'Follow-up Status': return Icons.phone_callback_rounded;
      default: return Icons.filter_list_rounded;
    }
  }

  void _showFiltersSheet(BuildContext context) {
    const kAccent = Color(0xFF675D40);
    const kAccentLight = Color(0xFFF5F0E8);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final sidebarBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final contentBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final projectNames = projects.map((p) => p.projectName).toList();
    final Map<String, String> projectNameToId = {for (var p in projects) p.projectName: p.id};
    final Map<String, String> projectIdToName = {for (var p in projects) p.id: p.projectName};

    final List<String> fixedConfigurations = [
      '1BHK', '2BHK', '3BHK', '4BHK', '5BHK', 'Penthouse', 'Studio'
    ];

    final allSources = leads.map((l) => l.source ?? '').where((s) => s.isNotEmpty).toSet().toList()..sort();
    final allIndustries = leads.map((l) => l.industry ?? '').where((i) => i.isNotEmpty).toSet().toList()..sort();

    // Display labels for sidebar (shorter to avoid wrapping)
    final Map<String, String> categoryLabels = {
      'Projects':        'Projects',
      'Status':          'Status',
      'Budget':          'Budget',
      'Configuration':   'Config',
      'Date Added':      'Date Added',
      'Source':          'Source',
      'Lead Quality':    'Quality',
      'Industry':        'Industry',
      'Next Contact':    'Next Contact',
      'Visited':         'Visited',
      'Visit Status':    'Visit Status',
      'Follow-up Status':'Follow-up',
    };

    final Map<String, List<String>> categories = {
      'Projects': projectNames,
      'Status': ['Lead Generated - Open', 'Prospect', 'Won'],
      'Budget': [],
      'Configuration': fixedConfigurations,
      'Date Added': ['Today', 'Last 7 days', 'This month'],
      'Source': allSources,
      'Lead Quality': ['⭐⭐⭐⭐⭐', '⭐⭐⭐⭐', '⭐⭐⭐', '⭐⭐', '⭐'],
      'Industry': allIndustries,
      if (currentDesignation?.toLowerCase() != 'property developer') ...{
        'Next Contact': ['Today', 'Tomorrow', 'This Week'],
      },
      'Visited': ['Yes', 'No'],
      'Visit Status': ['Visit Scheduled', 'Visit Done'],
      if (currentDesignation?.toLowerCase() != 'property developer') ...{
        'Follow-up Status': ['Open', 'Missed', 'Completed'],
      },
    };

    String currentCategory = 'Projects';
    Set<String> checked = <String>{};
    double localBudgetMin = _budgetMinSlider;
    double localBudgetMax = _budgetMaxSlider;

    void updateCheckedItems() {
      switch (currentCategory) {
        case 'Projects':       
          checked = _selectedProjects.map((id) => projectIdToName[id] ?? id).toSet(); 
          break;
        case 'Status':         checked = Set.from(_selectedStatuses); break;
        case 'Budget':         break;
        case 'Configuration':  checked = Set.from(_selectedConfigurations); break;
        case 'Date Added':     checked = Set.from(_selectedDateFilters); break;
        case 'Source':         checked = Set.from(_selectedSources); break;
        case 'Lead Quality':   checked = Set.from(_selectedLeadQualities); break;
        case 'Industry':       checked = Set.from(_selectedIndustries); break;
        case 'Next Contact':   checked = Set.from(_selectedNCD); break;
        case 'Visited':        checked = Set.from(_selectedVisited); break;
        case 'Visit Status':   checked = Set.from(_selectedVisitFilters); break;
        case 'Follow-up Status': checked = Set.from(_selectedFollowUpFilters); break;
        default: checked = <String>{};
      }
    }

    void applyAllFilters(StateSetter setSheet) {
      setState(() {
        // Persist whatever is currently in "checked" for the current tab
        switch (currentCategory) {
          case 'Projects':       
            _selectedProjects.clear(); 
            _selectedProjects.addAll(checked.map((name) => projectNameToId[name] ?? name)); 
            break;
          case 'Status':         _selectedStatuses.clear(); _selectedStatuses.addAll(checked); break;
          case 'Budget':         _budgetMinSlider = localBudgetMin; _budgetMaxSlider = localBudgetMax; break;
          case 'Configuration':  _selectedConfigurations.clear(); _selectedConfigurations.addAll(checked); break;
          case 'Date Added':     _selectedDateFilters.clear(); _selectedDateFilters.addAll(checked); break;
          case 'Source':         _selectedSources.clear(); _selectedSources.addAll(checked); break;
          case 'Lead Quality':   _selectedLeadQualities.clear(); _selectedLeadQualities.addAll(checked); break;
          case 'Industry':       _selectedIndustries.clear(); _selectedIndustries.addAll(checked); break;
          case 'Next Contact':   _selectedNCD.clear(); _selectedNCD.addAll(checked); break;
          case 'Visited':        _selectedVisited.clear(); _selectedVisited.addAll(checked); break;
          case 'Visit Status':   _selectedVisitFilters.clear(); _selectedVisitFilters.addAll(checked); break;
          case 'Follow-up Status': _selectedFollowUpFilters.clear(); _selectedFollowUpFilters.addAll(checked); break;
        }
        // Budget always applied from local sliders
        _budgetMinSlider = localBudgetMin;
        _budgetMaxSlider = localBudgetMax;
      });
    }

    updateCheckedItems();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final options = categories[currentCategory] ?? const <String>[];
            final int totalActiveCount = [
              _selectedProjects, _selectedStatuses, _selectedConfigurations,
              _selectedDateFilters, _selectedSources, _selectedLeadQualities,
              _selectedIndustries, _selectedNCD, _selectedVisited,
              _selectedVisitFilters, _selectedFollowUpFilters,
            ].fold(0, (sum, s) => sum + s.length) +
            (localBudgetMin > 0.0 || localBudgetMax < 100.0 ? 1 : 0);

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // ── Handle bar ──
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, color: kAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filter Leads',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                              ),
                              Text(
                                totalActiveCount > 0
                                    ? '$totalActiveCount filter${totalActiveCount > 1 ? 's' : ''} active'
                                    : 'No filters applied',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: totalActiveCount > 0 ? kAccent : Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Clear all
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              checked.clear();
                              localBudgetMin = 0.0;
                              localBudgetMax = 100.0;
                            });
                            setState(() {
                              _clearAllFilters();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Clear All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 0.5),

                  // ── Body: Sidebar + Content ──
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─ LEFT SIDEBAR ─
                        Container(
                          width: 148,
                          decoration: BoxDecoration(
                            color: sidebarBg,
                            border: Border(
                              right: BorderSide(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            children: categories.keys.map((k) {
                              final bool selected = k == currentCategory;
                              final int count = _getFilterCount(k);
                              final String displayLabel = categoryLabels[k] ?? k;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setSheetState(() {
                                    switch (currentCategory) {
                                      case 'Projects':       _selectedProjects.clear(); _selectedProjects.addAll(checked); break;
                                      case 'Status':         _selectedStatuses.clear(); _selectedStatuses.addAll(checked); break;
                                      case 'Configuration':  _selectedConfigurations.clear(); _selectedConfigurations.addAll(checked); break;
                                      case 'Date Added':     _selectedDateFilters.clear(); _selectedDateFilters.addAll(checked); break;
                                      case 'Source':         _selectedSources.clear(); _selectedSources.addAll(checked); break;
                                      case 'Lead Quality':   _selectedLeadQualities.clear(); _selectedLeadQualities.addAll(checked); break;
                                      case 'Industry':       _selectedIndustries.clear(); _selectedIndustries.addAll(checked); break;
                                      case 'Next Contact':   _selectedNCD.clear(); _selectedNCD.addAll(checked); break;
                                      case 'Visited':        _selectedVisited.clear(); _selectedVisited.addAll(checked); break;
                                      case 'Visit Status':   _selectedVisitFilters.clear(); _selectedVisitFilters.addAll(checked); break;
                                      case 'Follow-up Status': _selectedFollowUpFilters.clear(); _selectedFollowUpFilters.addAll(checked); break;
                                      case 'Budget':         _budgetMinSlider = localBudgetMin; _budgetMaxSlider = localBudgetMax; break;
                                    }
                                    setState(() {});
                                    currentCategory = k;
                                    updateCheckedItems();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? (isDark ? kAccent.withOpacity(0.22) : kAccentLight)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      // Left accent bar
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 3,
                                        height: 18,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: selected ? kAccent : Colors.transparent,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      Icon(
                                        _getCategoryIcon(k),
                                        size: 14,
                                        color: selected
                                            ? kAccent
                                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          displayLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected
                                                ? kAccent
                                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (count > 0)
                                        Container(
                                          width: 18,
                                          height: 18,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: kAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            count.toString(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ─ RIGHT CONTENT ─
                        Expanded(
                          child: Container(
                            color: contentBg,
                            child: currentCategory == 'Budget'
                                ? _buildBudgetPanel(setSheetState, localBudgetMin, localBudgetMax, (min, max) {
                                    setSheetState(() {
                                      localBudgetMin = min;
                                      localBudgetMax = max;
                                    });
                                  })
                                : options.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(32),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(18),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.filter_list_off_rounded, size: 28, color: Colors.grey.shade400),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                'No options',
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Nothing to filter here',
                                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Section header inside content
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                            child: Row(
                                              children: [
                                                Text(
                                                  currentCategory,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (checked.isNotEmpty)
                                                  GestureDetector(
                                                    onTap: () => setSheetState(() => checked.clear()),
                                                    child: Text(
                                                      'Clear',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.red.shade400,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: ListView.builder(
                                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                                              itemCount: options.length,
                                              itemBuilder: (context, index) {
                                                final opt = options[index];
                                                final isSelected = checked.contains(opt);
                                                return GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => setSheetState(() {
                                                    if (isSelected) {
                                                      checked.remove(opt);
                                                    } else {
                                                      checked.add(opt);
                                                    }
                                                  }),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 150),
                                                    margin: const EdgeInsets.only(bottom: 4),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? kAccent.withOpacity(isDark ? 0.2 : 0.07)
                                                          : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        // Custom checkbox
                                                        AnimatedContainer(
                                                          duration: const Duration(milliseconds: 150),
                                                          width: 20,
                                                          height: 20,
                                                          decoration: BoxDecoration(
                                                            color: isSelected ? kAccent : Colors.transparent,
                                                            borderRadius: BorderRadius.circular(5),
                                                            border: Border.all(
                                                              color: isSelected
                                                                  ? kAccent
                                                                  : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                          child: isSelected
                                                              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                                              : null,
                                                        ),
                                                        const SizedBox(width: 11),
                                                        Expanded(
                                                          child: Text(
                                                            opt,
                                                            style: TextStyle(
                                                              fontSize: 13.5,
                                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                              color: isSelected
                                                                  ? (isDark ? Colors.white : const Color(0xFF3D3420))
                                                                  : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                                                            ),
                                                          ),
                                                        ),
                                                        if (isSelected)
                                                          Icon(
                                                            Icons.check_circle_rounded,
                                                            size: 15,
                                                            color: kAccent.withOpacity(0.5),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom Action Bar ──
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Cancel
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              side: BorderSide(
                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Apply
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () {
                              applyAllFilters(setSheetState);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: kAccent.withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                if (checked.isNotEmpty || localBudgetMin > 0.0 || localBudgetMax < 100.0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      checked.isNotEmpty ? checked.length.toString() :
                                          (localBudgetMin > 0.0 || localBudgetMax < 100.0 ? '1' : ''),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetPanel(
    StateSetter setSheetState,
    double localMin,
    double localMax,
    void Function(double, double) onChanged,
  ) {
    const kAccent = Color(0xFF675D40);
    String _formatBudget(double val) {
      if (val < 1.0) return '₹${(val * 100).round()}L';
      return '₹${val % 1 == 0 ? val.toInt() : val.toStringAsFixed(1)}Cr';
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Budget Range',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Filter leads by their target budget',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),

          // Range display card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kAccent.withOpacity(0.08), kAccent.withOpacity(0.04)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minimum', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        _formatBudget(localMin),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kAccent),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: kAccent.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Maximum', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        _formatBudget(localMax),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Min slider
          Row(
            children: [
              const Icon(Icons.south_west_rounded, size: 14, color: Color(0xFF675D40)),
              const SizedBox(width: 6),
              Text('Minimum Budget', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: kAccent,
              inactiveTrackColor: kAccent.withOpacity(0.15),
              thumbColor: kAccent,
              overlayColor: kAccent.withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 4,
            ),
            child: Slider(
              value: localMin,
              min: 0.0,
              max: 100,
              divisions: 100,
              onChanged: (value) {
                if (value <= localMax) onChanged(value, localMax);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Max slider
          Row(
            children: [
              const Icon(Icons.north_east_rounded, size: 14, color: Color(0xFF675D40)),
              const SizedBox(width: 6),
              Text('Maximum Budget', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: kAccent,
              inactiveTrackColor: kAccent.withOpacity(0.15),
              thumbColor: kAccent,
              overlayColor: kAccent.withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 4,
            ),
            child: Slider(
              value: localMax,
              min: 0.0,
              max: 100,
              divisions: 100,
              onChanged: (value) {
                if (value >= localMin) onChanged(localMin, value);
              },
            ),
          ),
          const SizedBox(height: 20),

          // Quick presets
          Text('Quick Presets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBudgetPreset('< 50L', 0.0, 0.5, localMin, localMax, onChanged),
              _buildBudgetPreset('50L-1Cr', 0.5, 1.0, localMin, localMax, onChanged),
              _buildBudgetPreset('1Cr-2Cr', 1.0, 2.0, localMin, localMax, onChanged),
              _buildBudgetPreset('2Cr-5Cr', 2.0, 5.0, localMin, localMax, onChanged),
              _buildBudgetPreset('5Cr-100Cr', 5.0, 100.0, localMin, localMax, onChanged),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetPreset(String label, double min, double max, double currentMin, double currentMax, void Function(double, double) onChanged) {
    const kAccent = Color(0xFF675D40);
    final isActive = currentMin == min && currentMax == max;
    return GestureDetector(
      onTap: () => onChanged(min, max),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? kAccent : kAccent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? kAccent : kAccent.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : kAccent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: (currentDesignation?.toLowerCase() == 'property developer')
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 70.0),
              child: FloatingActionButton(
                heroTag: null,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LeadCreationPage()),
                  ).then((_) => _loadLeads(
                      forceRefresh:
                          true)); // Refresh leads when returning from LeadCreationPage
                },
                backgroundColor: const Color(0xFF1A1A1A),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width > 600 ? 20 : 16,
            MediaQuery.of(context).size.width > 600 ? 20 : 16,
            MediaQuery.of(context).size.width > 600 ? 20 : 16,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Leads',
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
                        isLoading
                            ? 'Loading...'
                            : '${_filteredLeads.length} of ${leads.length} leads',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildHeaderIconButton(
                        icon: Icons.refresh_rounded,
                        onTap: () => _initializeData(),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        icon: Icons.assignment_outlined,
                        onTap: _showReportOptions,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        icon: Icons.bookmark_border_rounded,
                        onTap: () {},
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSearchAndFilterCard(),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _initializeData,
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

  Widget _buildUserFilter() {
    // 1. Filter sales teams where current user is a member or lead/owner
    final mySalesTeams = salesTeams.where((team) {
      bool isOwner = (currentUserEmail != null && team.owner == currentUserEmail) ||
                     (currentBrokerId != null && team.owner == currentBrokerId);
      
      bool isMember = team.members.any((m) => 
        (currentUserEmail != null && m.userId != null && m.userId == currentUserEmail) || 
        (currentEmployeeId != null && m.employee != null && m.employee == currentEmployeeId) ||
        (currentBrokerId != null && (m.userId == currentBrokerId || m.employee == currentBrokerId))
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
    
    final List<Project> filteredProjects = projects.where((p) => projectIdsFromTeams.contains(p.id)).toList();

    // 1. Get unique leadOwner values from the CURRENT leads list
    final Set<String> ownersInLeads = leads
        .map((l) => l.leadOwner?.toLowerCase().trim())
        .where((o) => o != null && o.isNotEmpty)
        .cast<String>()
        .toSet();

    // 2. Map each unique owner to a Member object for the dropdown
    final List<Member> uniqueMembers = [];
    for (var ownerId in ownersInLeads) {
      String? displayName;
      
      // a. Try to get name from resolvedNames (Frappe lookup)
      if (_resolvedNames.containsKey(ownerId)) {
        displayName = _resolvedNames[ownerId];
      }
      
      // b. Try to find a matching member in ANY sales team to get their name
      if (displayName == null) {
        for (var team in salesTeams) {
          for (var m in team.members) {
            if (m.userId?.toLowerCase().trim() == ownerId || m.employee.toLowerCase().trim() == ownerId) {
              displayName = m.employeeName;
              break;
            }
          }
          if (displayName != null) break;
        }
      }
      
      // c. Fallback to email prefix
      displayName ??= ownerId.split('@').first;
      
      uniqueMembers.add(Member(
        name: ownerId,
        employee: ownerId,
        employeeName: displayName,
        userId: ownerId,
        role: 'Sales',
        owner: 'Administrator',
        creation: DateTime.now(),
        modified: DateTime.now(),
        modifiedBy: 'Administrator',
        docstatus: 0,
        idx: 0,
        parent: '',
        parentfield: '',
        parenttype: '',
        doctype: 'Sales Team Member',
      ));
    }
    
    // Determine if current user is a Team Lead or Manager
    bool isTeamLead = false;
    for (var team in salesTeams) {
      if ((currentUserEmail != null && team.owner == currentUserEmail) ||
          (currentEmployeeId != null && team.owner == currentEmployeeId) ||
          (currentBrokerId != null && team.owner == currentBrokerId)) {
        isTeamLead = true;
        break;
      }
      for (var m in team.members) {
        bool isMe = (currentUserEmail != null && m.userId != null && m.userId == currentUserEmail) || 
                    (currentEmployeeId != null && m.employee == currentEmployeeId) ||
                    (currentBrokerId != null && (m.userId == currentBrokerId || m.employee == currentBrokerId));
        if (isMe && (m.role.toLowerCase() == 'team lead' || m.role.toLowerCase() == 'manager')) {
          isTeamLead = true;
          break;
        }
      }
      if (isTeamLead) break;
    }
    
    if (!isTeamLead && currentDesignation != null) {
      final desig = currentDesignation!.toLowerCase();
      if (desig.contains('lead') || desig.contains('manager') || desig.contains('head')) {
        isTeamLead = true;
      }
    }

    return Column(
      children: [
        // Project Selection Dropdown
        Padding(
          padding: const EdgeInsets.only(top: 8),
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
        
        // User Selection Dropdown (Only shown if members are available AND user is a Team Lead or similar)
        if (uniqueMembers.isNotEmpty && isTeamLead)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
                      bool isMe = (currentUserEmail != null && m.userId != null && m.userId == currentUserEmail) || 
                                  (currentEmployeeId != null && m.employee != null && m.employee == currentEmployeeId) ||
                                  (currentBrokerId != null && (m.userId == currentBrokerId || m.employee == currentBrokerId));
                      // We must use m.userId (email) for strict filtering. If it's missing, use employee ID as fallback for value uniqueness
                      final value = (m.userId != null && m.userId!.isNotEmpty) ? m.userId : m.employee;
                      return DropdownMenuItem<String>(
                        value: value,
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
  
  Widget _buildSummaryWidgets(List<model_lead.Lead> filteredLeads) {
  // --- 1. Calculation Logic (Unchanged) ---
  final totalLeadsCount = filteredLeads.length;
  final filteredLeadNames = filteredLeads.map((l) => l.name).toSet();
  final currentSiteVisits = siteVisits.where((v) => filteredLeadNames.contains(v.lead)).toList();

  final totalSiteVisitsDone = currentSiteVisits.where((v) => v.status.toLowerCase() == 'visit done').length;
  final totalRevisitsDone = currentSiteVisits.where((v) => v.status.toLowerCase() == 'revisit done').length;
  final totalRevisitScheduled = currentSiteVisits.where((v) => v.status.toLowerCase() == 'revisit scheduled').length;
  final totalCancelled = currentSiteVisits.where((v) => 
    v.status.toLowerCase() == 'cancelled' || v.status.toLowerCase() == 'canceled'
  ).length;

  final Map<String, int> scheduledCountByLead = {};
  int explicitRescheduled = 0;
  int totalScheduled = 0;

  for (var v in currentSiteVisits) {
    final status = v.status.toLowerCase();
    if (status == 'scheduled' || status == 'visit scheduled') {
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

  // --- 2. Chart Data Preparation ---
  final List<PieChartSectionData> chartSections = [
    if (totalScheduled > 0) _buildChartSection(totalScheduled, Colors.indigo, 'Visit Scheduled'),
    if (totalRevisitScheduled > 0) _buildChartSection(totalRevisitScheduled, Colors.orange, 'Revisit Scheduled'),
    if (totalSiteVisitsDone > 0) _buildChartSection(totalSiteVisitsDone, Colors.green, 'Visit Done'),
    if (totalRevisitsDone > 0) _buildChartSection(totalRevisitsDone, Colors.teal, 'Revisit Done'),
    if (totalCancelled > 0) _buildChartSection(totalCancelled, Colors.red, 'Cancelled'),
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
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateSiteVisitScreen(),
                    ),
                  ).then((_) => _initializeData());
                },
                icon: const Icon(Icons.add_circle_outline, size: 14, color: goldAccent),
                label: const Text(
                  'Create Visit',
                  style: TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
                                  if (_selectedVisitFilters.contains(label)) {
                                    _selectedVisitFilters.remove(label);
                                  } else {
                                    _selectedVisitFilters.add(label);
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
                    _buildLegendRow(Icons.calendar_month_rounded, 'Visit Scheduled', totalScheduled, Colors.indigo),
                    _buildLegendRow(Icons.history_rounded, 'Revisit Scheduled', totalRevisitScheduled, Colors.orange),
                    _buildLegendRow(Icons.home_work_rounded, 'Visit Done', totalSiteVisitsDone, Colors.green),
                    _buildLegendRow(Icons.event_available_rounded, 'Revisit Done', totalRevisitsDone, Colors.teal),
                    _buildLegendRow(Icons.cancel_outlined, 'Cancelled', totalCancelled, Colors.red),
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

Widget _buildFollowUpSummaryWidgets(List<model_lead.Lead> filteredLeads) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Filter follow-ups based on manager vs employee logic
  // If the user is a manager, they might already have team follow-ups from LeadService.fetchMyFollowups
  // if the backend implementation of get_team_followups_list handles it.
  
  final filteredLeadNames = filteredLeads.map((l) => l.name).toSet();
  final currentFollowUps = followUps.where((f) => filteredLeadNames.contains(f.leadId)).toList();

  final totalFollowUps = currentFollowUps.length;
  final pendingAndOpen = currentFollowUps.where((f) => f.status?.toLowerCase() == 'open').length;
  final completed = currentFollowUps.where((f) => f.status?.toLowerCase() == 'completed').length;
  
  final missed = currentFollowUps.where((f) {
    if (f.status?.toLowerCase() != 'open') return false;
    if (f.followUpDate == null) return false;
    final fDate = DateTime.tryParse(f.followUpDate!);
    if (fDate == null) return false;
    return fDate.isBefore(now);
  }).length;

  final totalLeadsCount = filteredLeads.length;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Follow up Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateFollowUpScreen(),
                    ),
                  ).then((_) => _initializeData());
                },
                icon: const Icon(Icons.add_circle_outline, size: 14, color: goldAccent),
                label: const Text(
                  'Create Follow-up',
                  style: TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
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
                                  if (_selectedFollowUpFilters.contains(label)) {
                                    _selectedFollowUpFilters.remove(label);
                                  } else {
                                    _selectedFollowUpFilters.add(label);
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
                    _buildFollowUpLegendRow(Icons.people_outline, 'My Leads', totalLeadsCount, Colors.orange, isInteractive: false),
                    _buildFollowUpLegendRow(Icons.history, 'Total Count', totalFollowUps, Colors.blueGrey, isInteractive: false),
                    _buildFollowUpLegendRow(Icons.pending_actions, 'Open', pendingAndOpen, Colors.blue),
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
  final bool isSelected = _selectedFollowUpFilters.contains(label);
  return _PieData(
    label: label,
    color: isSelected ? color.withOpacity(0.8) : color,
    value: value.toDouble(),
    title: '', 
    radius: isSelected ? 22 : 16,
  );
}

Widget _buildFollowUpLegendRow(IconData icon, String label, int count, Color color, {bool isInteractive = true}) {
  final bool isSelected = _selectedFollowUpFilters.contains(label);
  return Padding(
    padding: const EdgeInsets.only(bottom: 6.0),
    child: InkWell(
      onTap: isInteractive ? () {
        setState(() {
          if (_selectedFollowUpFilters.contains(label)) {
            _selectedFollowUpFilters.remove(label);
          } else {
            _selectedFollowUpFilters.add(label);
          }
        });
      } : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: (isInteractive && isSelected) ? color.withOpacity(0.1) : Colors.transparent,
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
                  color: (isInteractive && isSelected) ? color : Colors.grey.shade800,
                  fontWeight: (isInteractive && isSelected) ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 13, 
                fontWeight: (isInteractive && isSelected) ? FontWeight.w800 : FontWeight.bold,
                color: (isInteractive && isSelected) ? color : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

PieChartSectionData _buildChartSection(int value, Color color, String label) {
  final bool isSelected = _selectedVisitFilters.contains(label);
  return _PieData(
    label: label,
    color: isSelected ? color.withOpacity(0.8) : color,
    value: value.toDouble(),
    title: '', 
    radius: isSelected ? 22 : 16, // Highlight selected section
  );
}

Widget _buildLegendRow(IconData icon, String label, int count, Color color) {
  final bool isSelected = _selectedVisitFilters.contains(label);
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0), // Tighter spacing
    child: InkWell(
      onTap: () {
        setState(() {
          if (_selectedVisitFilters.contains(label)) {
            _selectedVisitFilters.remove(label);
          } else {
            _selectedVisitFilters.add(label);
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

  Widget _buildTimeRangeSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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

  Widget _buildSearchAndFilterCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const kAccent = Color(0xFF675D40);
    final activeFilterCount = _countActiveFilters();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search Row ──
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, project...',
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
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Filter button with badge
            GestureDetector(
              onTap: () => _showFiltersSheet(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: activeFilterCount > 0 ? kAccent : (isDark ? Colors.grey[800] : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: activeFilterCount > 0
                          ? kAccent.withOpacity(0.35)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: activeFilterCount > 0 ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                      size: 22,
                    ),
                    if (activeFilterCount > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.red.shade500,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            activeFilterCount.toString(),
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildTimeRangeSelector()),
            if (activeFilterCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
                child: GestureDetector(
                  onTap: _clearAllFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: goldAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // ── Active Filter Chips ──
        if (_hasActiveFilters()) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._selectedProjects.map((p) => _buildFilterChip(p, Icons.apartment_rounded, const Color(0xFF5C6BC0), () => setState(() => _selectedProjects.remove(p)))),
                ..._selectedStatuses.map((s) => _buildFilterChip(s, Icons.label_rounded, const Color(0xFF26A69A), () => setState(() => _selectedStatuses.remove(s)))),
                if (_budgetMinSlider > 0.0 || _budgetMaxSlider < 100.0)
                  _buildFilterChip(
                    '₹${_budgetMinSlider < 1 ? "${(_budgetMinSlider * 100).round()}L" : "${_budgetMinSlider.toStringAsFixed(1)}Cr"} – ${_budgetMaxSlider < 1 ? "${(_budgetMaxSlider * 100).round()}L" : "${_budgetMaxSlider.toStringAsFixed(1)}Cr"}',
                    Icons.currency_rupee_rounded,
                    const Color(0xFFEF6C00),
                    () => setState(() { _budgetMinSlider = 0.0; _budgetMaxSlider = 100.0; }),
                  ),
                ..._selectedConfigurations.map((c) => _buildFilterChip(c, Icons.bed_rounded, const Color(0xFF7B1FA2), () => setState(() => _selectedConfigurations.remove(c)))),
                ..._selectedDateFilters.map((d) => _buildFilterChip(d, Icons.calendar_today_rounded, const Color(0xFF00838F), () => setState(() => _selectedDateFilters.remove(d)))),
                ..._selectedNCD.map((n) => _buildFilterChip(n, Icons.schedule_rounded, const Color(0xFF2E7D32), () => setState(() => _selectedNCD.remove(n)))),
                ..._selectedVisited.map((v) => _buildFilterChip(v, Icons.home_work_rounded, const Color(0xFF6D4C41), () => setState(() => _selectedVisited.remove(v)))),
                ..._selectedSources.map((s) => _buildFilterChip(s, Icons.alt_route_rounded, const Color(0xFF1565C0), () => setState(() => _selectedSources.remove(s)))),
                ..._selectedLeadQualities.map((q) => _buildFilterChip(q, Icons.star_rounded, const Color(0xFFF9A825), () => setState(() => _selectedLeadQualities.remove(q)))),
                ..._selectedIndustries.map((i) => _buildFilterChip(i, Icons.business_center_rounded, const Color(0xFF37474F), () => setState(() => _selectedIndustries.remove(i)))),
                ..._selectedDeadReasons.map((r) => _buildFilterChip(r, Icons.block_rounded, Colors.red.shade700, () => setState(() => _selectedDeadReasons.remove(r)))),
                ..._selectedVisitFilters.map((v) => _buildFilterChip(v, Icons.explore_rounded, const Color(0xFF00695C), () => setState(() => _selectedVisitFilters.remove(v)))),
                ..._selectedFollowUpFilters.map((f) => _buildFilterChip(f, Icons.phone_callback_rounded, const Color(0xFF558B2F), () => setState(() => _selectedFollowUpFilters.remove(f)))),
                // Clear All pill
                GestureDetector(
                  onTap: _clearAllFilters,
                  child: Container(
                    margin: const EdgeInsets.only(left: 4, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: goldAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  int _countActiveFilters() {
    return _selectedProjects.length +
        _selectedStatuses.length +
        _selectedConfigurations.length +
        _selectedDateFilters.length +
        _selectedSources.length +
        _selectedLeadQualities.length +
        _selectedIndustries.length +
        _selectedNCD.length +
        _selectedVisited.length +
        _selectedDeadReasons.length +
        _selectedVisitFilters.length +
        _selectedFollowUpFilters.length +
        (_selectedDays != 9999 ? 1 : 0) +
        (_budgetMinSlider > 0.0 || _budgetMaxSlider < 100.0 ? 1 : 0) +
        (_searchQuery.isNotEmpty ? 1 : 0);
  }

  Widget _buildHeaderIconButton({required IconData icon, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
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
          icon,
          size: 19,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(data: const IconThemeData(color: Colors.white), child: icon),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, Color color, VoidCallback onRemove) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.fromLTRB(9, 6, 8, 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 6),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 9, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalQuickActions() {
    final String userDesignation = (currentDesignation ?? '').trim().toLowerCase();
    if (userDesignation == 'lead caller' || userDesignation == 'property developer') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: const FaIcon(FontAwesomeIcons.house, size: 16, color: Colors.white),
              label: "Site Visit",
              color: goldAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateSiteVisitScreen()),
                ).then((_) => _initializeData());
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 16, color: Colors.white),
              label: "Follow Up",
              color: matteBlack,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateFollowUpScreen()),
                ).then((_) => _initializeData());
              },
            ),
          ),
        ],
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

    if (filteredLeads.isEmpty && _hasActiveFilters()) {
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
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: filteredLeads.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final String userDesignation = (currentDesignation ?? '').trim().toLowerCase();
          final bool isLeadCaller = userDesignation == 'lead caller';
          final bool isPropertyDeveloper = userDesignation == 'property developer';

          return Column(
            children: [
              _buildGlobalQuickActions(),
              if (!isLeadCaller && !isPropertyDeveloper)
                _buildUserFilter(),
              if (!isLeadCaller)
                _buildSummaryWidgets(filteredLeads),
              if (!isPropertyDeveloper && !isLeadCaller)
                _buildFollowUpSummaryWidgets(filteredLeads),
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
            onRefresh: () {
              _loadLeads(forceRefresh: true);
              _loadSiteVisits(forceRefresh: true);
              _loadFollowUps(forceRefresh: true);
            },
            onCall: () => _showNumberSelectionDialog(context, lead, 'call'),
            onWhatsApp: () =>
                _showNumberSelectionDialog(context, lead, 'whatsapp'),
            onFollowUp: () {
              if (lead.name != null) {
                LeadService.recordButtonPress(lead.name!, 'Follow Up Button');
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateFollowUpScreen(
                    preselectedLeadId: lead.name,
                    onFollowUpCreated: () {
                      _loadLeads(forceRefresh: true);
                      _loadFollowUps(forceRefresh: true);
                    },
                  ),
                ),
              );
            },
            onSiteVisit: () async {
              if (lead.name != null) {
                LeadService.recordButtonPress(lead.name!, 'Site Visit Button');
              }
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
                      _loadLeads(forceRefresh: true);
                      _loadSiteVisits(forceRefresh: true);
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
  final VoidCallback onRefresh; // Added onRefresh
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
    required this.onRefresh, // Required
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
      final dateTimeA = DateTime.tryParse(a.visitScheduledDatetime ?? a.modified ?? a.creation ?? '') ?? DateTime(0);
      final dateTimeB = DateTime.tryParse(b.visitScheduledDatetime ?? b.modified ?? b.creation ?? '') ?? DateTime(0);
      return dateTimeB.compareTo(dateTimeA); // Sort in descending order
    });
    return relevantVisits.first;
  }

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);

    // Find the project object from the projects list
    Project? project;
    try {
      project = projects.firstWhere((p) => lead.projectId.contains(p.id));
    } catch (e) {
      project = null;
    }

    final projectName = project?.projectName ?? 'N/A';
        
    final latestSiteVisit = _getLatestSiteVisitForLead(lead.name ?? '');
    final latestFollowUp = _getLatestFollowUpForLead(lead.name ?? '');
    
    bool hasValidDuration = false;
    bool isVisitDoneStatus = false;
    if (latestSiteVisit != null) {
      final status = latestSiteVisit.status.toLowerCase();
      isVisitDoneStatus = status == 'visit done' || status == 'revisit done';
      final dur = latestSiteVisit.visitDuration?.trim() ?? '';
      hasValidDuration = dur.isNotEmpty && dur != 'N/A' && dur.toLowerCase() != 'null';
    }
    final showDynamicDuration = isVisitDoneStatus && hasValidDuration;

    void _showDurationDialog(BuildContext parentContext, SiteVisit visit) {
      double duration = 15.0;
      bool isSaving = false;
      final currentStatus = visit.status.toLowerCase();
      String nextStatus = visit.status;
      
      if (currentStatus.contains('revisit')) {
        nextStatus = 'Revisit Done';
      } else if (currentStatus.contains('visit') || currentStatus == 'scheduled' || currentStatus == 'completed') {
        nextStatus = 'Visit Done';
      }

      showDialog(
        context: parentContext,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (builderContext, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                title: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_outlined, color: kAccent, size: 28),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Visit Duration',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Record the actual time spent during this visit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${duration.toInt()} mins',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: kAccent,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(builderContext).copyWith(
                        activeTrackColor: kAccent,
                        inactiveTrackColor: kAccent.withOpacity(0.1),
                        thumbColor: kAccent,
                        overlayColor: kAccent.withOpacity(0.1),
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                      ),
                      child: Slider(
                        value: duration,
                        min: 5,
                        max: 120,
                        divisions: 23, // 5 min increments
                        onChanged: (v) => setDialogState(() => duration = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('5m', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                          Text('2h', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            setDialogState(() => isSaving = true);
                            
                            final error = await SiteVisitService.updateSiteVisit(visit.name, {
                              'visit_duration': '${duration.toInt()} mins',
                              'status': nextStatus,
                            });
                            
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            
                            if (error == null) {
                              if (parentContext.mounted) {
                                CustomSnackBar.show(
                                  parentContext,
                                  message: 'Visit marked as $nextStatus with duration ${duration.toInt()} mins',
                                  isError: false,
                                  title: 'Success',
                                );
                              }
                              // Call onRefresh to update the UI
                              onRefresh();
                            } else {
                              if (parentContext.mounted) {
                                CustomSnackBar.show(
                                  parentContext,
                                  message: error,
                                  isError: true,
                                  title: 'Error',
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSaving 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      );
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (lead.leadName?.isNotEmpty == true) ? lead.leadName![0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: kAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (lead.leadName?.isEmpty ?? true) ? 'N/A' : lead.leadName!,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (lead.customLeadLostStages != null && lead.customLeadLostStages!.isNotEmpty)
                            ? Colors.red.withOpacity(0.1)
                            : _getStatusColor(lead.customLeadStatus ?? '', context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!(lead.customLeadLostStages != null && lead.customLeadLostStages!.isNotEmpty))
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(lead.customLeadStatus ?? '', context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'STAGE ${_getRomanStage(lead.customLeadStatus)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          Text(
                            (lead.customLeadLostStages != null && lead.customLeadLostStages!.isNotEmpty)
                                ? 'LOST'
                                : _titleCase(lead.customLeadStatus ?? 'N/A'),
                            style: TextStyle(
                              color: (lead.customLeadLostStages != null && lead.customLeadLostStages!.isNotEmpty)
                                  ? Colors.red
                                  : _getStatusColor(lead.customLeadStatus ?? '', context),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              if (lead.customLeadLostStages != null && lead.customLeadLostStages!.isNotEmpty)
                _leadDetailRow(context, Icons.do_not_disturb_alt, lead.customLeadLostStages!, color: Colors.red)
              else
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SiteVisitDetailPage(siteVisit: latestSiteVisit),
                      ),
                    ).then((_) => onRefresh());
                  },
                  child: _leadDetailRow(context, Icons.info_outline,
                      'Visit Status: ${_titleCase(latestSiteVisit.status)}',
                      color: _getVisitStatusColor(latestSiteVisit.status),
                      isBold: true,
                  ),
                ),
                if (latestSiteVisit.status.toLowerCase() != 'cancelled')
                  GestureDetector(
                    onTap: () => _showDurationDialog(context, latestSiteVisit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: showDynamicDuration
                            ? Colors.green.shade700.withOpacity(0.1)
                            : kAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: showDynamicDuration
                              ? Colors.green.shade700.withOpacity(0.3)
                              : kAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            showDynamicDuration
                                ? Icons.timer
                                : Icons.timer_outlined,
                            size: 14,
                            color: showDynamicDuration
                                ? Colors.green.shade700
                                : kAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            showDynamicDuration
                                ? latestSiteVisit.visitDuration!
                                : 'Log Duration',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: showDynamicDuration
                                  ? Colors.green.shade700
                                  : kAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (latestFollowUp != null && currentDesignation?.toLowerCase() != 'property developer')
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FollowUpDetailPage(followUpName: latestFollowUp.name),
                      ),
                    ).then((_) => onRefresh());
                  },
                  child: _leadDetailRow(context, Icons.event_note_rounded,
                      'Follow up: ${_formatPostedDate(DateTime.tryParse(latestFollowUp.followUpDate ?? ''))} (${latestFollowUp.status})',
                      color: Colors.orange.shade800),
                ),
              if (lead.customTagging != null && lead.customTagging!.isNotEmpty)
                _leadDetailRow(context, Icons.label_outline_rounded, lead.customTagging!, color: Colors.blueGrey),
            ],
          ),

          const SizedBox(height: 16),
          
          // Divider
          Divider(color: Colors.grey.shade200, thickness: 1),
          const SizedBox(height: 8),

          // Footer: Actions
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 1. Phone Action
                _actionIconButton(
                  icon: FontAwesomeIcons.phone,
                  color: Colors.blue.shade700,
                  onPressed: onCall,
                ),
                const SizedBox(width: 6),
                
                // 2. WhatsApp Action
                _actionIconButton(
                  icon: FontAwesomeIcons.whatsapp,
                  color: const Color(0xFF25D366),
                  onPressed: onWhatsApp,
                ),
                const SizedBox(width: 6),
                
                // 3. Share Project Action
                if (project != null) ...[
                  _actionIconButton(
                    icon: Icons.share_rounded,
                    color: kAccent,
                    onPressed: () {
                      if (lead.name != null) {
                        LeadService.recordButtonPress(lead.name!, 'Share Button');
                      }
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top + 20, 
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: ProjectShareBottomSheet(project: project!, lead: lead),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                ],

                // 4. Site Visit
                Builder(
                  builder: (context) {
                    final String dest = (currentDesignation ?? '').trim().toLowerCase();
                    if (dest != 'property developer' && dest != 'lead caller') {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionButton(
                            onPressed: onSiteVisit,
                            label: "Site Visit",
                            icon: FontAwesomeIcons.house,
                            backgroundColor: goldAccent,
                          ),
                          const SizedBox(width: 6),

                          // 5. Follow Up
                          _actionButton(
                            onPressed: onFollowUp,
                            label: "Follow Up",
                            icon: FontAwesomeIcons.clockRotateLeft,
                            backgroundColor: const Color(0xFF1A1A1A),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Creation Date & Age Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Created: ${_formatPostedDate(lead.createdAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (lead.createdAt != null)
                Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Age: ${DateTime.now().difference(lead.createdAt!).inDays} Days',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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

  String _getRomanStage(String? status) {
    switch (status) {
      case 'Lead Generated - Open': return 'I';
      case 'Prospect': return 'II';
      case 'Won': return 'III';
      default: return 'I';
    }
  }

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
      {Color color = Colors.black54, bool isBold = false, Widget? trailing}) {
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
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing,
        ],
      ],
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
  switch (status.toLowerCase()) {
    case 'open':
    case 'lead generated - open':
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
      case 'visit scheduled':
        return Colors.blue.shade700;
      case 'visit done':
        return Colors.green.shade700;
      case 'revisit scheduled':
        return Colors.indigo.shade700;
      case 'revisit done':
        return Colors.teal.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      case 'scheduled': // Backward compatibility
        return Colors.blue.shade700;
      case 'completed': // Backward compatibility
        return Colors.green.shade700;
      case 'rescheduled': // Backward compatibility
        return Colors.orange.shade700;
      case 'canceled': // Backward compatibility
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _actionIconButton({
    required dynamic icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    // Detect FontAwesome icons safely
    bool isFontAwesome = false;
    try {
      isFontAwesome = icon.fontFamily?.startsWith('FontAwesome') ?? false;
    } catch (_) {
      // Fallback check
      isFontAwesome = icon.toString().contains('FontAwesome');
    }
    
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: IconButton(
        icon: isFontAwesome 
            ? FaIcon(icon, color: color, size: 18)
            : Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 24,
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required dynamic icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    bool isFontAwesome = false;
    try {
      isFontAwesome = icon.fontFamily?.startsWith('FontAwesome') ?? false;
    } catch (_) {
      isFontAwesome = icon.toString().contains('FontAwesome');
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: isFontAwesome 
          ? FaIcon(icon, size: 14)
          : Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
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
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                            CustomSnackBar.show(context, message: 'Lead updated', isError: false, title: 'Notice');
                          } catch (e) {
                            CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
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
        CustomSnackBar.show(context, message: 'Lead deleted', isError: false, title: 'Notice');
      } catch (e) {
        CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
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
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.controller,
    this.onChanged,
    this.maxLength,
    this.inputFormatters,
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
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              counterText: "",
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



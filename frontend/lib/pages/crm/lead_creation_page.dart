import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/models/lead.dart';
import 'package:Homesol/models/campaign.dart';
import 'package:Homesol/models/sales_team.dart';
import 'package:Homesol/pages/channel_partner/channel_partner_creation_page.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';

// ─── EXTENSION ───
extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// ─── CONSTANTS ───
const String _leadDraftKey = 'lead_creation_draft';
const kAccent = Color(0xFF675D40);
const kInputDecoration = InputDecoration(
  isDense: true,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: kAccent, width: 2),
  ),
);
String getCurrentDateTime() {
  final now = DateTime.now();
  return "${now.year.toString().padLeft(4, '0')}-"
      "${now.month.toString().padLeft(2, '0')}-"
      "${now.day.toString().padLeft(2, '0')} "
      "${now.hour.toString().padLeft(2, '0')}:"
      "${now.minute.toString().padLeft(2, '0')}:"
      "${now.second.toString().padLeft(2, '0')}";
}

class LeadCreationPage extends StatefulWidget {
  final String? preselectedProjectId;
  final Lead? lead; // Add this line
  const LeadCreationPage({
    super.key,
    this.preselectedProjectId,
    this.lead,
  }); // Update constructor

  @override
  State<LeadCreationPage> createState() => _LeadCreationPageState();
}

class _LeadCreationPageState extends State<LeadCreationPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final Map<String, dynamic> _formData = {
    'custom_lead_quality': 0,
    'custom_occupation': 'Job',
    'custom_lead_status': 'Lead Generated - Open',
    'custom_tagging': 'No Tagging',
    'custom_current_residence_type': '1BHK',
  };

  int _step = 0;
  bool _otpSent = false;
  bool _verified = false;
  bool _isLoading = false;
  bool _isResendDisabled = false;
  int _countdown = 30;
  Timer? _timer;

  final _mobile = TextEditingController();
  final _otp = TextEditingController();
  final _configurationController = TextEditingController();
  final _attendedByController = TextEditingController();
  final _cpSearchController = TextEditingController();
// Removed _cpDisplayController
  List<String> _selectedConfigurations = [];

  String? _selectedSource;
  Timer? _debounceTimer;

  static const List<String> _taggingNoOptions = [
    'TeleCalling',
    'Reference',
    'Walk-in',
    'From Campaign'
  ];
  static const List<String> _taggingYesOptions = [
    'TeleCalling',
    'Live Leads',
    'Walk-in With CP',
    'From Campaign'
  ];

  late AnimationController _successCtrl;
  final ScrollController _scrollController = ScrollController();
  final _qualifiedOnController = TextEditingController();

  // Dropdown data sources
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _industryOptions = [];
  List<String> _marketSegmentOptions = [];
  List<ChannelPartner> _channelPartners = [];
  Project? _selectedProjectDetails;
  List<Campaign> _projectCampaigns = [];
  bool _isFetchingSelectedProject = false;
  List<SalesTeam> _salesTeams = [];
  List<SalesTeam> _userTeams = [];
  List<Map<String, dynamic>> _teamLeads = [];
  List<Map<String, dynamic>> _teamProjects = [];

  // Loading flags
  bool _isFetchingProjects = true;
  bool _isFetchingCampaigns = true;
  bool _isFetchingUsers = true;
  bool _isFetchingIndustryTypes = true;
  bool _isFetchingMarketSegments = true;
  bool _isFetchingChannelPartners = true;
  bool _isFetchingSalesTeams = true;
  bool _isGettingLocation = false;
  String? _locationError;
  bool _draftLoaded = false;
  int _resetCounter = 0;

  // Helper getter
  bool get _isEditing => widget.lead != null;
  int get _totalSteps => 3; // _isEditing ? 3 : 4;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (widget.lead != null) {
      // If editing an existing lead, pre-fill form data from Lead object
      final leadJson = widget.lead!.toJson();
      _formData.addAll(leadJson);

      // Populate all text controllers with Lead data
      _mobile.text = widget.lead!.mobileNo ?? widget.lead!.customerPhone ?? '-';
      _configurationController.text = widget.lead!.customConfiguration ?? '';
      _attendedByController.text = widget.lead!.customAttendedBy ?? '';
      // Removed _cpDisplayController assignment
      _qualifiedOnController.text =
          widget.lead!.qualifiedOn?.toIso8601String().split('T').first ??
          DateTime.now().toIso8601String().split('T').first;

      // Ensure all simple string fields are in _formData
      _formData['first_name'] = widget.lead!.firstName ?? '';
      _formData['last_name'] = widget.lead!.lastName ?? '';
      _formData['company_name'] = widget.lead!.companyName ?? '';
      _formData['email_id'] = widget.lead!.emailId ?? '';
      _formData['mobile_no'] =
          widget.lead!.mobileNo ?? widget.lead!.customerPhone ?? '';
      _formData['whatsapp_no'] = widget.lead!.whatsappNo ?? '';
      _formData['custom_postal_code'] = widget.lead!.customPostalCode ?? '';
      _formData['custom_remark'] = widget.lead!.customRemark ?? '';
      _formData['industry'] = widget.lead!.industry ?? '';
      _formData['market_segment'] = widget.lead!.marketSegment ?? '';
      _formData['source'] = widget.lead!.source ?? '';
      _formData['custom_campaign'] = widget.lead!.customCampaign ?? '';
      _formData['custom_occupation'] = widget.lead!.customOccupation ?? 'Job';
      _formData['custom_lead_status'] = widget.lead!.customLeadStatus ?? 'Lead Generated - Open';
      _formData['custom_tagging'] = widget.lead!.customTagging ?? 'No Tagging';
      _formData['custom_current_residence_type'] =
          widget.lead!.customCurrentResidenceType ?? '';
      _formData['custom_looking_for_property_type'] =
          widget.lead!.customLookingForPropertyType ?? '';
      _formData['custom_financing_details'] =
          widget.lead!.customFinancingDetails ?? '';
      _formData['custom_budget_min'] = widget.lead!.customBudgetMin ?? '';
      _formData['custom_budget_max'] = widget.lead!.customBudgetMax ?? '';
      _formData['custom_expected_time_of_purchase'] =
          widget.lead!.customExpectedTimeOfPurchase ?? '';
      _formData['custom_purpose_of_purchase'] =
          widget.lead!.customPurposeOfPurchase ?? '';
      _formData['custom_preferred_contact_method'] =
          widget.lead!.customPreferredContactMethod ?? '';
      _formData['custom_stages'] = widget.lead!.customStages ?? '';
      _formData['location_coordinates'] =
          widget.lead!.locationCoordinates ?? '';
      _selectedSource = widget.lead!.source;

      // Parse configuration selections
      if (widget.lead!.customConfiguration != null &&
          widget.lead!.customConfiguration!.isNotEmpty) {
        _selectedConfigurations = widget.lead!.customConfiguration!
            .split(',')
            .map((e) => e.trim())
            .toList();
      }

      // Set lead quality rating
      _formData['custom_lead_quality'] =
          (widget.lead!.customLeadQuality ?? 0.0);

      // Setup dropdown values as Map objects for proper selection
      if (widget.lead!.customInterestedProject != null &&
          widget.lead!.customInterestedProject!.isNotEmpty) {
        _formData['custom_interested_project'] = {
          'id': widget.lead!.customInterestedProject!,
          'name': widget.lead!.customInterestedProject!,
        };
      }
      if (widget.lead!.customSalesManager != null &&
          widget.lead!.customSalesManager!.isNotEmpty) {
        _formData['custom_sales_manager'] = {
          'id': widget.lead!.customSalesManager!,
          'name': widget.lead!.customSalesManager!,
        };
      }
      if (widget.lead!.qualifiedBy != null &&
          widget.lead!.qualifiedBy!.isNotEmpty) {
        _formData['qualified_by'] = {
          'id': widget.lead!.qualifiedBy!,
          'name': widget.lead!.qualifiedBy!,
        };
      }
      if (widget.lead!.customChannelPartner != null &&
          widget.lead!.customChannelPartner!.isNotEmpty) {
        _formData['custom_channel_partner_id'] =
            widget.lead!.customChannelPartner!;
      }

      // For editing, no OTP verification needed
      _verified = true;
      _otpSent = true;
      _step = 0;
    } else {
      _qualifiedOnController.text = DateTime.now()
          .toIso8601String()
          .split('T')
          .first;
      if (_formData['custom_configuration'] is String &&
          (_formData['custom_configuration'] as String).isNotEmpty) {
        _selectedConfigurations = (_formData['custom_configuration'] as String)
            .split(',')
            .map((e) => e.trim())
            .toList();
        _configurationController.text = _formData['custom_configuration'];
      }
      _selectedSource = 'Walk-in'; // Default source for new leads
      _formData['source'] = 'Walk-in';
      _formData['custom_tagging'] = 'No Tagging';
    }
    _initializeCurrentUserAndDropdownData(); // New method to handle async init
    _loadDraft();

    // Add listeners to controllers to save draft while typing
    _mobile.addListener(_saveDraft);
    _configurationController.addListener(_saveDraft);
    _attendedByController.addListener(_saveDraft);
    _qualifiedOnController.addListener(_saveDraft);
  }

  Future<void> _loadDraft() async {
    if (widget.lead != null) return; // Don't load draft when editing

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftString = prefs.getString(_leadDraftKey);
      if (draftString != null) {
        final Map<String, dynamic> draftData = json.decode(draftString);
        setState(() {
          // Merge draft data into _formData
          draftData.forEach((key, value) {
            if (key == 'custom_channel_partner' && value is Map<String, dynamic>) {
              _formData[key] = ChannelPartner.fromJson(value);
            } else {
              _formData[key] = value;
            }
          });

          // Restore controllers
          if (_formData['mobile_no'] != null) {
            _mobile.text = _formData['mobile_no'];
          }
          if (_formData['custom_configuration'] != null) {
            _configurationController.text = _formData['custom_configuration'];
            _selectedConfigurations = (_formData['custom_configuration'] as String)
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
          if (_formData['source'] != null) {
            _selectedSource = _formData['source'];
          }
          if (_formData['custom_attended_by'] != null) {
            _attendedByController.text = _formData['custom_attended_by'];
          }
          if (_formData['qualified_on'] != null) {
            _qualifiedOnController.text = _formData['qualified_on'];
          }
        });
        
        // Restore project details if available
        if (_formData['custom_interested_project'] != null && _formData['custom_interested_project'] is Map) {
          final projId = (_formData['custom_interested_project'] as Map)['id'];
          if (projId != null) {
            _fetchSelectedProjectDetails(projId.toString());
          }
        }
        
        // Wait for projects to load then restore campaign object if possible
        _restoreCampaignFromDraft(draftData['custom_campaign']);
      }
      setState(() {
        _draftLoaded = true;
      });
    } catch (e) {
      print('Error loading lead draft: $e');
      setState(() {
        _draftLoaded = true;
      });
    }
  }

  Future<void> _restoreCampaignFromDraft(String? campaignId) async {
    if (campaignId == null) return;
    
    // We need to wait until project details are fetched
    int retry = 0;
    while (_selectedProjectDetails == null && retry < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retry++;
    }

    if (_selectedProjectDetails != null) {
      final campaign = _projectCampaigns.firstWhereOrNull((c) => c.name == campaignId);
      if (campaign != null) {
        setState(() {
          _formData['custom_campaign_object'] = campaign;
        });
      }
    }
  }

  bool _isFormEmpty() {
    // Check text controllers
    if (_mobile.text.isNotEmpty ||
        _configurationController.text.isNotEmpty ||
        (_formData['first_name'] != null && _formData['first_name'].toString().trim().isNotEmpty) ||
        (_formData['last_name'] != null && _formData['last_name'].toString().trim().isNotEmpty) ||
        (_formData['email_id'] != null && _formData['email_id'].toString().trim().isNotEmpty) ||
        (_formData['custom_interested_project'] != null)) {
      return false;
    }

    // Check if any other non-default field is filled in _formData
    final ignoreKeys = {
      'custom_lead_quality',
      'custom_occupation',
      'custom_lead_status',
      'custom_tagging',
      'custom_current_residence_type',
      'source',
      'qualified_on',
      'qualified_by',
      'custom_attended_by',
    };

    for (var entry in _formData.entries) {
      if (ignoreKeys.contains(entry.key)) continue;
      if (entry.value != null) {
        if (entry.value is String && entry.value.toString().trim().isEmpty) continue;
        return false;
      }
    }

    return true;
  }

  void _saveDraft({bool immediate = false}) {
    if (widget.lead != null) return; // Don't save draft when editing
    
    // Don't save if form is essentially empty
    if (_isFormEmpty()) {
      _clearDraft(); // Clean up any existing stale draft
      return;
    }

    // Cancel existing timer
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    Future<void> performSave() async {
      try {
        // If immediate is false, we might have been disposed before timer fires
        if (!mounted && !immediate) return;

        final prefs = await SharedPreferences.getInstance();

        // Sync controller values to _formData before saving
        // Only access controllers if mounted
        if (mounted) {
          if (_mobile.text.isNotEmpty) _formData['mobile_no'] = _mobile.text;
          if (_configurationController.text.isNotEmpty) {
            _formData['custom_configuration'] = _configurationController.text;
          }
          // Note: NOT overwriting custom_attended_by here because controller has full name
          // but _formData should ideally hold the userId (email).
          // We will handle this in _submit mapping.
          
          if (_qualifiedOnController.text.isNotEmpty) {
            _formData['qualified_on'] = _qualifiedOnController.text;
          }
        }

        final draftToSave = Map<String, dynamic>.from(_formData);

        // Ensure we don't try to save non-serializable objects directly
        draftToSave.forEach((key, value) {
          if (value is ChannelPartner) {
            draftToSave[key] = value.toJson();
          } else if (value is Campaign) {
            draftToSave[key] = value.name; // Store the ID for campaigns
          }
        });

        await prefs.setString(_leadDraftKey, json.encode(draftToSave));
        debugPrint('💾 [Draft] Lead creation draft saved ${immediate ? "(immediate)" : "(debounced)"}');
      } catch (e) {
        print('Error saving lead draft: $e');
      }
    }

    if (immediate) {
      performSave();
    } else {
      // Start new timer for 500ms
      _debounceTimer = Timer(const Duration(milliseconds: 500), performSave);
    }
  }

  Future<void> _clearDraft() async {
    try {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_leadDraftKey);
    } catch (e) {
      print('Error clearing lead draft: $e');
    }
  }

  Future<void> _resetForm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh_rounded, color: kAccent, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reset Form?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will clear all entered data and delete your saved draft. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Reset Now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _clearDraft();
      setState(() {
        _resetCounter++; // Force entire form subtree to rebuild
        _formKey.currentState?.reset(); // Reset the Form state itself
        _formData.clear();
        // Reset defaults
        _formData['custom_lead_quality'] = 0;
        _formData['custom_occupation'] = 'Job';
        _formData['custom_lead_status'] = 'Lead Generated - Open';
        _formData['custom_tagging'] = 'No Tagging';
        _formData['custom_current_residence_type'] = '1BHK';
        _formData['source'] = 'Walk-in';
        _selectedSource = 'Walk-in';

        _mobile.clear();
        _configurationController.clear();
        _attendedByController.clear();
        _qualifiedOnController.clear();
        _selectedConfigurations.clear();
        _otp.clear();
        _step = 0;
      });
      _initializeCurrentUserAndDropdownData();
      if (mounted) {
        CustomSnackBar.show(context, message: 'Form reset successfully', isError: false, title: 'Notice');
      }
    }
  }

  Future<void> _initializeCurrentUserAndDropdownData() async {
    await _fetchDropdownData(); // First, get all users

    // Then, fetch the current user's profile
    final profile = await AuthService.getMyProfile();
    if (mounted) {
      setState(() {
        if (profile?.employee != null) {
          final currentUserEmployeeId = profile!.employee;

          // Filter sales teams to find the ones the current user is in
          _userTeams = _salesTeams
              .where(
                (team) => team.members.any(
                  (member) => member.employee == currentUserEmployeeId,
                ),
              )
              .toList();

          // From those teams, get the team leads and projects
          final Set<Map<String, dynamic>> teamLeads = {};
          final Set<Map<String, dynamic>> teamProjects = {};

          for (final team in _userTeams) {
            // Get Team Leads
            final leads = team.members
                .where((member) => member.role == 'Team Lead')
                .map(
                  (lead) {
                    String id = lead.userId ?? lead.employee;
                    if (!id.contains('@')) {
                      // Try to find by name in _users
                      final matchingUser = _users.firstWhereOrNull(
                        (u) => u['name'] == lead.employeeName,
                      );
                      if (matchingUser != null) {
                        id = matchingUser['id'];
                      }
                    }
                    return {
                      'id': id,
                      'name': lead.employeeName,
                    };
                  },
                );
            teamLeads.addAll(leads);

            // Get Projects and fetch their full details
            for (final p in team.projects) {
              final fullProject = _projects.firstWhereOrNull(
                (proj) => proj['id'] == p.projects,
              );
              if (fullProject != null) {
                teamProjects.add(fullProject);
              }
            }
          }
          _teamLeads = teamLeads.toList();
          _teamProjects = teamProjects.toList();

          if (widget.lead == null || _attendedByController.text.isEmpty) {
            _formData['custom_attended_by'] = profile.userId;
            _attendedByController.text = profile.employeeName;
          }
        }

        if (widget.preselectedProjectId != null &&
            (widget.lead == null ||
                _formData['custom_interested_project'] == null)) {
          final projectMap = _projects.firstWhere(
            (p) => p['id'] == widget.preselectedProjectId,
            orElse: () => <String, String>{},
          );
          if (projectMap.isNotEmpty) {
            _formData['custom_interested_project'] = projectMap;
          }
        }

        // Default to the first available project if none is selected
        if (_formData['custom_interested_project'] == null &&
            _teamProjects.isNotEmpty) {
          _formData['custom_interested_project'] = _teamProjects.first;
        }

        // Update team leads based on selected project
        if (_formData['custom_interested_project'] != null) {
          final projId = (_formData['custom_interested_project'] as Map)['id'];
          _updateTeamLeadsForProject(projId);
        }

        // Default to the first available sales manager if none is selected
        if (_formData['custom_sales_manager'] == null &&
            _teamLeads.isNotEmpty) {
          _formData['custom_sales_manager'] = _teamLeads.first;
        }

        // Resolve ChannelPartner object if in edit mode and ID was stored
        if (widget.lead != null &&
            _formData['custom_channel_partner_id'] != null) {
          final channelPartner = _channelPartners.firstWhere(
            (cp) => cp.name == _formData['custom_channel_partner_id'],
            orElse: () => ChannelPartner(
              name: '',
              firmName: '',
            ), // Provide a default or handle null
          );
          if (channelPartner.name != null && channelPartner.name!.isNotEmpty) {
            _formData['custom_channel_partner'] = channelPartner;
          }
        }
      });
      // Trigger campaign fetch if a project is already selected (pre-selected or defaulted)
      if (_formData['custom_interested_project'] != null &&
          _formData['custom_interested_project'] is Map) {
        final projId = (_formData['custom_interested_project'] as Map)['id'];
        if (projId != null && projId.isNotEmpty) {
          print('🚀 [DEBUG] Triggering initial campaign fetch for project: $projId');
          _fetchSelectedProjectDetails(projId);
        }
      }
    }
  }

  void _updateTeamLeadsForProject(String? projectId) {
    if (projectId == null || projectId.isEmpty) return;

    final Set<Map<String, dynamic>> filteredLeads = {};

    // Find teams that have this project among the user's teams
    final teamsWithProject = _userTeams.where(
      (team) => team.projects.any((p) => p.projects == projectId),
    );

    for (final team in teamsWithProject) {
      final leads = team.members
          .where((member) => member.role == 'Team Lead')
          .map(
            (lead) => {
              'id': lead.userId ?? lead.employee,
              'name': lead.employeeName,
            },
          );
      filteredLeads.addAll(leads);
    }

    if (mounted) {
      setState(() {
        _teamLeads = filteredLeads.toList();

        // Auto-select logic
        if (_teamLeads.isNotEmpty) {
          // If project details are already loaded and have a project RM, try to match it
          final projectRm = _selectedProjectDetails?.projectRm;
          if (projectRm != null && projectRm.isNotEmpty) {
            final matchingLead = _teamLeads.firstWhereOrNull(
              (l) => l['id'] == projectRm || l['name'] == projectRm,
            );
            if (matchingLead != null) {
              _formData['custom_sales_manager'] = matchingLead;
              return;
            }
          }

          // Otherwise, if current manager is not in the new list, pick first
          final currentManager = _formData['custom_sales_manager'] as Map?;
          if (currentManager == null ||
              !_teamLeads.any((l) => l['id'] == currentManager['id'])) {
            _formData['custom_sales_manager'] = _teamLeads.first;
          }
        } else {
          _formData['custom_sales_manager'] = null;
        }
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _fetchSelectedProjectDetails(String projectId) async {
    if (projectId.isEmpty) return;

    // Check if we already have these details to avoid redundant calls
    if (_selectedProjectDetails?.id == projectId &&
        !_isFetchingSelectedProject) {
      print('ℹ️ [DEBUG] Project details already loaded for: $projectId');
      return;
    }

    if (mounted) setState(() => _isFetchingSelectedProject = true);
    try {
      print('🔍 [DEBUG] Fetching details and campaigns for project: $projectId');
      
      // Fetch project details and campaigns in parallel
      final results = await Future.wait([
        ProjectService.fetchProject(projectId),
        LeadService.fetchCampaignsByProject(projectId),
      ]);

      final project = results[0] as Project?;
      final campaigns = results[1] as List<Campaign>;

      if (mounted) {
        setState(() {
          _selectedProjectDetails = project;
          _projectCampaigns = campaigns;
          _isFetchingSelectedProject = false;

          // RE-RUN lead filtering now that we have project details (with projectRm)
          _updateTeamLeadsForProject(projectId);

          // Validate or RESOLVE existing campaign selection using ID (name)
          if (_formData['custom_campaign'] != null) {
            print(
                '🔍 [DEBUG] Attempting to resolve campaign object for ID: ${_formData['custom_campaign']}');
            final campaign = _projectCampaigns.firstWhereOrNull(
              (c) =>
                  c.name == _formData['custom_campaign'] ||
                  c.campaignCodeName == _formData['custom_campaign'],
            );
            if (campaign != null) {
              print(
                  '✅ [DEBUG] Resolved campaign object: ${campaign.campaignCodeName}');
              _formData['custom_campaign_object'] = campaign;
            } else {
              print(
                  '⚠️ [DEBUG] Campaign ID ${_formData['custom_campaign']} not found in project campaigns');
              _formData['custom_campaign_object'] = null;
            }
          }
        });
      }
    } catch (e) {
      print('❌ [DEBUG] Error fetching project details: $e');
      if (mounted) {
        setState(() => _isFetchingSelectedProject = false);
      }
    }
  }

  Future<void> _fetchDropdownData() async {
    setState(() {
      _isFetchingProjects = true;
      _isFetchingCampaigns = true;
      _isFetchingUsers = true;
      _isFetchingIndustryTypes = true;
      _isFetchingMarketSegments = true;
      _isFetchingChannelPartners = true;
      _isFetchingSalesTeams = true;
    });
    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        ProjectService.fetchApiProjects(),
        LeadService.fetchUsersWithId(),
        LeadService.fetchIndustryTypes(),
        LeadService.fetchMarketSegments(),
        ChannelPartnerService.syncChannelPartners(forceRefresh: true),
        ApiService.fetchSalesTeams(),
      ]);
      setState(() {
        _projects = results[0] as List<Map<String, dynamic>>;
        _isFetchingProjects = false;

        _users = results[1] as List<Map<String, dynamic>>;
        _isFetchingUsers = false;

        _industryOptions = results[2] as List<String>;
        _isFetchingIndustryTypes = false;

        _marketSegmentOptions = results[3] as List<String>;
        _isFetchingMarketSegments = false;

        _channelPartners = results[4] as List<ChannelPartner>;
        _isFetchingChannelPartners = false;

        // MATCH EXISTING CHANNEL PARTNER (for editing or draft)
        if (_formData['custom_channel_partner_id'] != null) {
          final channelPartner = _channelPartners.firstWhereOrNull(
            (cp) => cp.name == _formData['custom_channel_partner_id'],
          );
          if (channelPartner != null) {
            _formData['custom_channel_partner'] = channelPartner;
          }
        }

        _salesTeams = results[5] as List<SalesTeam>;
        _isFetchingSalesTeams = false;
        _isFetchingCampaigns = false; // Still set to false as it's not global anymore
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load form data: $e')));
        setState(() {
          _isFetchingProjects = false;
          _isFetchingCampaigns = false;
          _isFetchingUsers = false;
          _isFetchingIndustryTypes = false;
          _isFetchingMarketSegments = false;
          _isFetchingChannelPartners = false;
          _isFetchingSalesTeams = false;
        });
      }
    }
  }

  Widget _buildUnifiedSourcingField() {
    return FormField<Map<String, dynamic>>(
      key: ValueKey(
        'unified_sourcing_${_formData['custom_tagging']}_${_formData['custom_interested_project']?['id']}',
      ),
      initialValue: {
        'source': _formData['source'],
        'campaign': _formData['custom_campaign_object'],
      },
      validator: (v) {
        if (_formData['source'] == null || _formData['source'].toString().isEmpty) {
          return 'Source is required';
        }
        return null;
      },
      builder: (state) {
        final source = _formData['source']?.toString() ?? 'Select Source';
        final campaign = _formData['custom_campaign_object'] is Campaign 
            ? _formData['custom_campaign_object'] as Campaign 
            : null;
        final campaignText = campaign != null
            ? (campaign.campaignCodeName.isNotEmpty ? campaign.campaignCodeName : campaign.name)
            : 'No Campaign Selected';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Sourcing & Campaign',
                style: TextStyle(
                  color: state.hasError ? Colors.red.shade700 : Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            InkWell(
              onTap: () => _showUnifiedSourcingSheet(state),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: state.hasError
                        ? Colors.red.shade300
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
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
                        color: kAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSourceIcon(source),
                        color: kAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source,
                            style: TextStyle(
                              color: _formData['source'] == null
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            campaignText,
                            style: TextStyle(
                              color: campaign != null
                                  ? kAccent
                                  : Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: campaign != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'TeleCalling':
        return Icons.phone_in_talk_rounded;
      case 'Reference':
        return Icons.group_rounded;
      case 'Walk-in':
        return Icons.directions_walk_rounded;
      case 'Live Leads':
        return Icons.bolt_rounded;
      case 'Walk-in With CP':
        return Icons.handshake_rounded;
      default:
        return Icons.hub_outlined;
    }
  }

  void _showUnifiedSourcingSheet(FormFieldState<Map<String, dynamic>> state) {
    final isTagging = _formData['custom_tagging'] == 'Tagging';
    final sources = isTagging ? _taggingYesOptions : _taggingNoOptions;
    final campaigns = _projectCampaigns;
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    child: Row(
                      children: [
                        const Text(
                          'Sourcing & Campaign',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        const Text(
                          'Select Lead Source',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: sources.map((s) {
                            final isSelected = _formData['source'] == s;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _formData['source'] = s;
                                  _saveDraft();
                                });
                                setSheetState(() {});
                                state.didChange({
                                  'source': s,
                                  'campaign': _formData['custom_campaign_object']
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? kAccent : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? kAccent
                                        : Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: kAccent.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getSourceIcon(s),
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      s,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            const Text(
                              'Select Campaign',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            if (_formData['custom_campaign_object'] != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _formData['custom_campaign_object'] = null;
                                    _formData['custom_campaign'] = null;
                                    _formData['campaign'] = null;
                                    _saveDraft();
                                  });
                                  setSheetState(() {});
                                  state.didChange({
                                    'source': _formData['source'],
                                    'campaign': null
                                  });
                                },
                                child: const Text('Clear Selection'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_formData['custom_interested_project'] == null)
                           _buildNoticeCard(
                            'Please select a project first to see active campaigns.',
                            Icons.info_outline_rounded,
                          )
                        else if (campaigns.isEmpty)
                          _buildNoticeCard(
                            'No active campaigns found for this project.',
                            Icons.campaign_outlined,
                          )
                        else ...[
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search campaigns...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onChanged: (v) => setSheetState(() => query = v),
                          ),
                          const SizedBox(height: 16),
                          ...campaigns
                              .where((c) =>
                                  c.campaignCodeName
                                      .toLowerCase()
                                      .contains(query.toLowerCase()) ||
                                  c.name
                                      .toLowerCase()
                                      .contains(query.toLowerCase()))
                              .map((c) {
                            final isSelected =
                                _formData['custom_campaign_object']?.name ==
                                    c.name;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _formData['custom_campaign_object'] = c;
                                    _formData['custom_campaign'] =
                                        c.campaignCodeName;
                                    _formData['campaign'] = c.name;
                                    _saveDraft();
                                  });
                                  setSheetState(() {});
                                  state.didChange({
                                    'source': _formData['source'],
                                    'campaign': c
                                  });
                                  // Optional: Auto-close after selecting both?
                                  // For now, let user see the selection
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? kAccent.withOpacity(0.05)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? kAccent
                                          : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? kAccent
                                              : Colors.grey[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.campaign_rounded,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[600],
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.campaignCodeName.isNotEmpty
                                                  ? c.campaignCodeName
                                                  : c.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isSelected
                                                    ? kAccent
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _buildBadge(
                                                  c.onlineOffline ??
                                                      c.activeInactive ??
                                                      'Unknown',
                                                  isSelected
                                                      ? kAccent
                                                      : Colors.grey[600]!,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${c.leadsGenerated} leads',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: kAccent,
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A1A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Confirm Selection',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
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

  Widget _buildNoticeCard(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permissions are denied';
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permissions are permanently denied, we cannot request permissions.';
          _isGettingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _formData['location_coordinates'] =
            '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"point_type":"marker"},"geometry":{"type":"Point","coordinates":[${position.longitude},${position.latitude}]}}]}';
        _isGettingLocation = false;
      });
      _saveDraft();
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: $e';
        _isGettingLocation = false;
      });
    }
  }

  void startResendTimer() {
    _isResendDisabled = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isResendDisabled = false;
          _countdown = 30;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Call cancel only if _timer is not null
    _successCtrl.dispose();
    _mobile.dispose();
    _otp.dispose();
    _scrollController.dispose();
    _qualifiedOnController.dispose();
    _attendedByController.dispose();
    super.dispose();
  }

  List<String> _getStagesForStatus(String? status) {
    switch (status) {
      case 'Lead Generated - Open':
        return [
          'Called - Interested',
          'Detail Sent',
          'Follow Up',
          'Site Visit Confirm (VC)',
          'Site Visit Prospect (VP)',
        ];
      case 'Prospect':
        return [
          'Project Visited',
          'Project Warm',
          'Opportunity',
          'Revisit Scheduled',
        ];
      case 'Won':
        return ['Booking in Approval', 'Booking Done'];
      default:
        return [];
    }
  }

  // ───────────────────────── HEADER STEPPER ─────────────────────────

  Widget _stepHeader() {
    final allSteps = ['Personal', 'Contact', 'Details', 'Verify'];
    final steps = allSteps.sublist(
      0,
      3,
    ); // _isEditing ? allSteps.sublist(0, 3) : allSteps;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_isEditing)
                TextButton.icon(
                  onPressed: _resetForm,
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.red),
                  label: const Text('Reset',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          Row(
            children: List.generate(steps.length, (i) {
              final active = i <= _step;
              final isCurrent = i == _step;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: active ? kAccent : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: kAccent.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: i < _step
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: active ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? Colors.black87 : Colors.grey,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── UI HELPERS ─────────────────────────

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: e,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _text(
    String keyName,
    String label,
    Function(String?) onSave, {
    bool required = false,
    TextInputType type = TextInputType.text,
    TextEditingController? controller,
    bool readOnly = false,
    FormFieldValidator<String>? validator, // Add validator parameter here
    int? maxLength,
    int? maxLines = 1,
    int? minLines,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
  }) {
    return TextFormField(
      key: ValueKey(keyName),
      controller: controller,
      readOnly: readOnly,
      initialValue: controller == null ? _formData[keyName]?.toString() : null,
      keyboardType: type,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: kInputDecoration.copyWith(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        counterText: "",
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: kAccent),
      ),
      validator: (v) {
        if (required && (v == null || v.isEmpty)) {
          return 'Required';
        }
        return validator?.call(v); // Call custom validator if provided
      },
      onSaved: onSave,
      onChanged: (val) {
        if (controller == null) _formData[keyName] = val;
        _saveDraft();
      },
    );
  }

  Widget _dropdown(
    String keyName,
    String label,
    List items,
    Function(dynamic) onChange, {
    String? displayKey,
    String? valueKey,
    bool readOnly = false,
    bool isLoading = false,
    FormFieldValidator<dynamic>? validator,
  }) {
    // Resolve the current value, ensuring it's valid and exists in items
    dynamic resolvedValue = _formData[keyName];

    if (resolvedValue is Map && items.isNotEmpty && valueKey != null) {
      final valueKeyLookup = resolvedValue[valueKey];
      final matchingItem = items.firstWhereOrNull(
        (item) => item is Map && item[valueKey] == valueKeyLookup,
      );
      if (matchingItem != null) {
        resolvedValue = matchingItem;
      }
    } else if (resolvedValue is String &&
        items.isNotEmpty &&
        items.first is Map &&
        valueKey != null) {
      final matchingItem = items.firstWhereOrNull(
        (item) => item is Map && item[valueKey] == resolvedValue,
      );
      if (matchingItem != null) {
        resolvedValue = matchingItem;
      }
    } else if (resolvedValue is String &&
        items.isNotEmpty &&
        items.first is String) {
      // For simple strings, if it's not in the list, we still keep it to show the initial value
    }

    String displayValue = '';
    if (resolvedValue is Map) {
      displayValue = resolvedValue[displayKey] ?? '';
    } else if (resolvedValue is String) {
      displayValue = resolvedValue;
    } else if (resolvedValue is ChannelPartner) {
      displayValue = resolvedValue.firmName ?? '';
    }

    final TextEditingController displayController = TextEditingController(text: displayValue);

    return TextFormField(
      key: ValueKey(keyName),
      controller: displayController,
      readOnly: true,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: kInputDecoration.copyWith(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        hintText: 'Select $label',
        suffixIcon: isLoading
            ? Transform.scale(
                scale: 0.5,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_drop_down, color: kAccent),
      ),
      validator: (v) => validator?.call(resolvedValue),
      onTap: (readOnly || isLoading)
          ? null
          : () {
              final searchController = TextEditingController();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setModalState) {
                      final filteredList = items.where((item) {
                        final query = searchController.text.toLowerCase();
                        String itemDisplay = '';
                        if (item is Map) {
                          itemDisplay = item[displayKey] ?? '';
                        } else if (item is String) {
                          itemDisplay = item;
                        } else if (item is ChannelPartner) {
                          itemDisplay = item.firmName ?? '';
                        }
                        return itemDisplay.toLowerCase().contains(query);
                      }).toList();

                      return Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: TextField(
                                controller: searchController,
                                decoration: kInputDecoration.copyWith(
                                  hintText: 'Search $label...',
                                  prefixIcon: const Icon(Icons.search, color: kAccent),
                                ),
                                onChanged: (val) => setModalState(() {}),
                              ),
                            ),
                            if (keyName == 'custom_channel_partner')
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const ChannelPartnerCreationPage()),
                                    ).then((result) {
                                      if (result == true) {
                                        _fetchDropdownData();
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: kAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kAccent.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: kAccent,
                                          child:
                                              Icon(Icons.add, size: 18, color: Colors.white),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          'Can\'t find partner? ',
                                          style:
                                              TextStyle(fontSize: 14, color: Colors.black54),
                                        ),
                                        Text(
                                          'Add New',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: kAccent,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (keyName == 'custom_channel_partner')
                              const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredList.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filteredList[index];
                                  String itemDisplay = '';
                                  String? subtitle;
                                  if (item is Map) {
                                    itemDisplay = item[displayKey] ?? '';
                                  } else if (item is String) {
                                    itemDisplay = item;
                                  } else if (item is ChannelPartner) {
                                    itemDisplay = item.firmName ?? 'No Name';
                                    subtitle = item.mobileNumber ?? item.email ?? '';
                                  }

                                  final bool isClearOption = itemDisplay == 'None (Clear)';

                                  return ListTile(
                                    leading: isClearOption ? const Icon(Icons.clear, color: Colors.red) : null,
                                    title: Text(
                                      itemDisplay, 
                                      style: TextStyle(
                                        fontWeight: isClearOption ? FontWeight.bold : FontWeight.w500,
                                        color: isClearOption ? Colors.red : Colors.black87,
                                      )
                                    ),
                                    subtitle: subtitle != null ? Text(subtitle) : null,
                                    onTap: () {
                                      final bool isClear = itemDisplay == 'None (Clear)';
                                      final selectedValue = isClear ? null : item;
                                      setState(() {
                                        _formData[keyName] = selectedValue;
                                      });
                                      onChange(selectedValue);
                                      _saveDraft();
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
    );
  }

  // Widget _check(String label, String key) {
  //   bool isChecked = (_formData[key] ?? 0) == 1;
  //   return CheckboxListTile(
  //     key: ValueKey(key),
  //     contentPadding: EdgeInsets.zero,
  //     activeColor: kAccent,
  //     title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
  //     value: isChecked,
  //     onChanged: (v) => setState(() => _formData[key] = v! ? 1 : 0),
  //   );
  // }

  Widget _starRating(String label) {
    return FormField<double>(
      initialValue: (_formData['custom_lead_quality'] as num?)?.toDouble(),
      validator: (v) => (v == null || v == 0.0) ? 'Required' : null,
      builder: (state) {
        int currentRating = ((state.value ?? 0.0) / 0.2).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: state.hasError
                    ? Colors.red.shade700
                    : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                int starValue = index + 1;
                bool isActive = starValue <= currentRating;
                return GestureDetector(
                  onTap: () {
                    final newVal = starValue * 0.2;
                    setState(() {
                      _formData['custom_lead_quality'] = newVal;
                    });
                    state.didChange(newVal);
                    _saveDraft();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isActive
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isActive ? Colors.amber[600] : Colors.grey[300],
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLocationWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_on),
              label: const Text('Get Location'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child:
                  (_formData['location_coordinates'] != null &&
                      _formData['location_coordinates'].isNotEmpty)
                  ? const Icon(Icons.check_circle_outline, color: Colors.green)
                  : const Text(
                      'No location set',
                      style: TextStyle(fontSize: 12),
                    ),
            ),
          ],
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _locationError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConfigurationButtons() {
    final configurations = [
      "1BHK",
      "1.5BHK",
      "2BHK",
      "2.5BHK",
      "3BHK",
      "3.5BHK",
      "4BHK+",
      "Jodi",
      "Studio",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional: Add a label for better UX
        Text(
          "Select Configuration",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10.0, // Horizontal space between buttons
          runSpacing: 10.0, // Vertical space between lines
          children: configurations.map((config) {
            final isSelected = _selectedConfigurations.contains(config);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // 1. UX: Add Haptic Feedback for a tactile feel
                  HapticFeedback.lightImpact();

                  setState(() {
                    if (isSelected) {
                      _selectedConfigurations.remove(config);
                    } else {
                      _selectedConfigurations.add(config);
                    }

                    // Update your controllers
                    String result = _selectedConfigurations.join(', ');
                    _formData['custom_configuration'] = result;
                    _configurationController.text = result;
                  });
                  _saveDraft();
                },
                borderRadius: BorderRadius.circular(
                  12,
                ), // Matches container radius
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ), // Smooth transition
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    // Filled when selected, White when not
                    color: isSelected ? kAccent : Colors.white,

                    // Modern rounded corners (Soft Square vs Pill)
                    borderRadius: BorderRadius.circular(12),

                    // Subtle border when unselected to define the area
                    border: Border.all(
                      color: isSelected ? kAccent : Colors.grey.shade300,
                      width: 1.5,
                    ),

                    // Optional: Add a subtle shadow for depth
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    config,
                    style: TextStyle(
                      // White text when selected, Dark Grey when not
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResidenceTypeButtons() {
    final types = [
      "1BHK",
      "1.5BHK",
      "2BHK",
      "2.5BHK",
      "3BHK",
      "3.5BHK",
      "4BHK+",
      "Studio",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Current Residence Type",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          children: types.map((type) {
            final isSelected =
                _formData['custom_current_residence_type'] == type;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _formData['custom_current_residence_type'] = type;
                  });
                  _saveDraft();
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? kAccent : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? kAccent : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0: // Personal
        return Column(
          children: [
            _card([
              Text("Identity", style: Theme.of(context).textTheme.titleMedium),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _text(
                      'first_name',
                      'First Name',
                      (v) => _formData['first_name'] = v,
                      required: true,
                    ),
                  ),
                ],
              ),
              _text(
                'last_name',
                'Last Name',
                (v) => _formData['last_name'] = v,
                required: true,
              ),
              _starRating('Lead Quality (Rate 1-5)'),
              _buildResidenceTypeButtons(),
            ]),

            _card([
              Text(
                "Project Info",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              _dropdown(
                'custom_interested_project',
                'Interested Project',
                _teamProjects,
                (val) {
                  setState(() {
                    _formData['custom_interested_project'] = val as Map?;
                    _formData['custom_campaign'] = null;
                    _formData['custom_campaign_object'] = null;
                    if (val != null && val is Map) {
                      final projId = val['id']?.toString();
                      if (projId != null) {
                        _fetchSelectedProjectDetails(projId);
                        _updateTeamLeadsForProject(projId);
                      }
                    }
                  });
                },
                displayKey: 'name',
                valueKey: 'id',
                isLoading: _isFetchingSalesTeams,
                validator: (v) => v == null ? 'Required' : null,
              ),
            ]),

            _card([
              Text(
                "Lead Source",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              _dropdown(
                'custom_tagging',
                'Tagging',
                ['Tagging', 'No Tagging'],
                (v) {
                  setState(() {
                    _formData['custom_tagging'] = v;
                    _formData['source'] = null; // Reset source on tagging change
                  });
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              
              _buildUnifiedSourcingField(),
              if (_formData['custom_tagging'] == 'Tagging')
                _dropdown(
                  'custom_channel_partner',
                  'Channel Partner',
                  _channelPartners,
                  (v) {
                    setState(() {
                      _formData['custom_channel_partner'] = v;
                    });
                  },
                  displayKey: 'firmName',
                  valueKey: 'name',
                  isLoading: _isFetchingChannelPartners,
                  validator: (v) => v == null ? 'Required' : null,
                ),
            ]),
            
            _card([
              Text(
                "Lead Funnel",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              _dropdown(
                'custom_lead_status',
                'Lead Status',
                ['Lead Generated - Open', 'Prospect', 'Won'],
                (v) {
                  setState(() {
                    _formData['custom_lead_status'] = v;
                    _formData['custom_stages'] = null; // Reset stage when status changes
                  });
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              if (_formData['custom_lead_status'] != null)
                _dropdown(
                  'custom_stages',
                  'Stage',
                  _getStagesForStatus(_formData['custom_lead_status']),
                  (v) {
                    setState(() {
                      _formData['custom_stages'] = v;
                    });
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
              const SizedBox(height: 8),
              Text("Lost/Dropped Lead?", style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
              _dropdown(
                'custom_lead_lost_stages',
                'Lost Reason',
                [
                  'None (Clear)',
                  'Ringing - Not Picking Up',
                  'Budget Issue',
                  'Plan Dropped',
                  'Location Issue',
                  'Builder Credibility',
                  'Carpet Area / Inventory',
                  'Plan on Hold'
                ],
                (v) {
                  setState(() {
                    if (v == null) {
                      _formData.remove('custom_lead_lost_stages');
                    } else {
                      _formData['custom_lead_lost_stages'] = v;
                    }
                  });
                },
                // Not required by default since it's a separate optional field
              ),            ]),
            
            _card([
              Text(
                "Professional Info",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              _dropdown(
                'custom_occupation',
                'Occupation',
                ['Job', 'Business'],
                (v) {
                  setState(() {
                    _formData['custom_occupation'] = v;
                  });
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              _text(
                'company_name',
                'Firm Name',
                (v) => _formData['company_name'] = v,
              ),

              _dropdown(
                'industry',
                'Industry',
                _industryOptions,
                (v) => _formData['industry'] = v,
                isLoading: _isFetchingIndustryTypes,
              ),
              _dropdown(
                'market_segment',
                'Market Segment',
                _marketSegmentOptions,
                (v) => _formData['market_segment'] = v,
                isLoading: _isFetchingMarketSegments,
              ),
            ]),
          ],
        );

      case 1: // Contact
        return _card([
          Text("Contact Info", style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          _text(
            'mobile_no',
            'Primary Number',
            (v) => _formData['mobile_no'] = v,
            required: true,
            type: TextInputType.phone,
            controller: _mobile,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (value.length != 10) {
                  return 'Phone number must be 10 digits';
                }
              }
              return null;
            },
          ),
          _text(
            'whatsapp_no',
            'Secondary Number',
            (v) => _formData['whatsapp_no'] = v,
            type: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (value.length != 10) {
                  return 'Phone number must be 10 digits';
                }
              }
              return null;
            },
          ),
          _text(
            'email_id',
            'Email',
            (v) => _formData['email_id'] = v,
            required: false,
            type: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value)) {
                return 'Enter a valid email address (e.g., name@example.com)';
              }
              return null;
            },
          ),
          _dropdown(
            'custom_preferred_contact_method',
            'Preferred Contact Method',
            ['Email', 'Phone Call', 'WhatsApp'],
            (v) => _formData['custom_preferred_contact_method'] = v,
          ),
          _text(
            'custom_postal_code',
            'Postal Code',
            (v) => _formData['custom_postal_code'] = v,
            type: TextInputType.number,
            required: false,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (value.length != 6) {
                  return 'Postal Code must be 6 digits long';
                }
              }
              return null;
            },
          ),
          _buildLocationWidget(),
        ]);

      case 2: // Details (Requirements + Professional + Status)
        return Column(
          children: [
            _card([
              Text(
                "Requirement Details",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              _text(
                'custom_configuration',
                'Configuration (e.g., 3BHK)',
                (v) => _formData['custom_configuration'] = v,
                controller: _configurationController,
                required: true,
                readOnly: true,
              ),
              _buildConfigurationButtons(),
              Row(
                children: [
                  Expanded(
                    child: _text(
                      'custom_budget_min',
                      'Min Budget',
                      (v) => _formData['custom_budget_min'] = v,
                      type: const TextInputType.numberWithOptions(decimal: true),
                      required: true,
                      suffixText: 'Cr',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(value)) {
                            return 'Enter a valid number';
                          }
                          if (double.tryParse(value)! <= 0) {
                            return 'Budget must be positive';
                          }
                          if (_formData['custom_budget_max'] != null &&
                              _formData['custom_budget_max'].toString().isNotEmpty) {
                            final min = double.tryParse(value);
                            final max = double.tryParse(
                              _formData['custom_budget_max'].toString(),
                            );
                            if (min != null && max != null && min > max) {
                              return 'Min budget cannot exceed Max';
                            }
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _text(
                      'custom_budget_max',
                      'Max Budget',
                      (v) => _formData['custom_budget_max'] = v,
                      type: const TextInputType.numberWithOptions(decimal: true),
                      required: true,
                      suffixText: 'Cr',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(value)) {
                            return 'Enter a valid number';
                          }
                          if (double.tryParse(value)! <= 0) {
                            return 'Budget must be positive';
                          }
                          if (_formData['custom_budget_min'] != null &&
                              _formData['custom_budget_min'].toString().isNotEmpty) {
                            final min = double.tryParse(
                              _formData['custom_budget_min'].toString(),
                            );
                            final max = double.tryParse(value);
                            if (min != null && max != null && max < min) {
                              return 'Max budget cannot be less than Min';
                            }
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              _dropdown(
                'custom_looking_for_property_type',
                'Property Type',
                ['Ready-To-Move', 'Under-Construction', 'Nearing Possession'],
                (v) => _formData['custom_looking_for_property_type'] = v,
              ),
              _dropdown(
                'custom_financing_details',
                'Financing',
                ['Own Funds', 'Loan Required', 'Own Funds And Loan', 'Sell Of Property'],
                (v) => _formData['custom_financing_details'] = v,
              ),
              if (_formData['custom_financing_details'] == 'Loan Required' ||
                  _formData['custom_financing_details'] == 'Own Funds And Loan')
                _text(
                  'custom_loan_requirements',
                  'Loan Requirements',
                  (v) => _formData['custom_loan_requirements'] = v,
                  type: const TextInputType.numberWithOptions(decimal: true),
                  suffixText: 'Cr',
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(value)) {
                        return 'Enter a valid number';
                      }
                    }
                    return null;
                  },
                ),
              _dropdown(
                'custom_purpose_of_purchase',
                'Purpose',
                ['Investment', 'Personal use'],
                (v) => _formData['custom_purpose_of_purchase'] = v,
              ),
              _text(
                'custom_remark',
                'Remark',
                (v) => _formData['custom_remark'] = v,
                maxLines: null,
                minLines: 3,
                type: TextInputType.multiline,
              ),
              _dropdown(
                'custom_expected_time_of_purchase',
                'Expected Purchase Time',
                [
                  'Immediate',
                  '3-6 months',
                  '6-12 months',
                  'More than 12 months',
                ],
                (v) => _formData['custom_expected_time_of_purchase'] = v,
              ),
            ]),
            _card([
              Text(
                "Qualification",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: _text(
                      'custom_attended_by',
                      'Attended By',
                      (v) {}, // No-op on save
                      controller: _attendedByController,
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _text(
                      'qualified_on',
                      'Qualified On',
                      (v) => _formData['qualified_on'] = v,
                      controller: _qualifiedOnController,
                    ),
                  ),
                ],
              ),
              _dropdown(
                'custom_sales_manager',
                'Sales Manager',
                _teamLeads,
                (val) => _formData['custom_sales_manager'] = val as Map?,
                displayKey: 'name',
                valueKey: 'id',
                isLoading: _isFetchingSalesTeams,
                validator: (v) => v == null ? 'Required' : null,
              ),
              _dropdown(
                'qualified_by',
                'Closed By',
                _users,
                (val) => _formData['qualified_by'] = val as Map?,
                displayKey: 'name',
                valueKey: 'id',
                readOnly: true,
              ),
            ]),
          ],
        );

      /*
      case 3: // Verification
        return Center(
          child: _card([
            Text("Verification", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              "Verify mobile number ${_mobile.text}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (!_otpSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          final otp = await LeadService.sendOTP(_mobile.text);
                          setState(() {
                            _isLoading = false;
                            if (otp != null) {
                              _otpSent = true;
                              startResendTimer(); // <--- Add this line
                              if (otp.isNotEmpty) {
                                CustomSnackBar.show(context, message: 'DEBUG: OTP $otp', isError: false, title: 'Notice');
                              }
                            }
                          });
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send OTP',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            if (_otpSent && !_verified)
              Column(
                children: [
                  TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      letterSpacing: 8,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: kInputDecoration.copyWith(
                      labelText: 'Enter OTP',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            padding: const EdgeInsets.all(16),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  final ok = await LeadService.verifyOTP(
                                    _mobile.text,
                                    _otp.text,
                                  );
                                  if (ok) {
                                    // Ensure status is set
                                    _formData['status'] = 'Lead';
                                    final submissionOk = await _submit();
                                    if (submissionOk) {
                                      await _clearDraft();
                                      setState(() {
                                        _isLoading = false;
                                        _verified = true;
                                      });
                                      Future.delayed(
                                        const Duration(seconds: 2),
                                        () {
                                          if (mounted) Navigator.of(context).pop();
                                        },
                                      );
                                    } else {
                                      setState(() => _isLoading = false);
                                      CustomSnackBar.show(context, message: 
                                            'Failed to create lead. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    setState(() => _isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Invalid OTP', isError: true, title: 'Error');
                                  }
                                },
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Verify & Submit',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                      if (_otpSent)
                        const SizedBox(width: 10),
                      if (_otpSent)
                        TextButton(
                          onPressed: _isResendDisabled
                              ? null
                              : () async {
                                  final otp = await LeadService.sendOTP(_mobile.text);
                                  if (otp != null) {
                                    startResendTimer();
                                    if (otp.isNotEmpty) {
                                      CustomSnackBar.show(context, message: 'DEBUG: OTP $otp', isError: false, title: 'Notice');
                                    }
                                  }
                                },
                          child: Text(_isResendDisabled ? 'Resend OTP in $_countdown s' : 'Resend OTP'),
                        ),
                    ],
                  ),
                ],
              ),
            if (_verified) _successView(),
          ]),
        );
      */

      default:
        return const SizedBox();
    }
  }

  // ───────────────────────── SUCCESS ─────────────────────────

  Widget _successView() {
    _successCtrl.forward();
    HapticFeedback.mediumImpact();

    return Center(
      child: Column(
        children: [
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _successCtrl,
              curve: Curves.elasticOut,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 90,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lead Created Successfully',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<bool> _submit() async {
    print('🚀 [DEBUG] Starting lead submission...');
    print('📦 [DEBUG] _formData before save: ${_formData['custom_campaign_object']}');
    
    _formKey.currentState!.save();

    print('📦 [DEBUG] _formData after save: ${_formData['custom_campaign_object']}');

    // Create a clean copy of form data for submission
    final submissionData = Map<String, dynamic>.from(_formData);
    
    print('📦 [DEBUG] submissionData initial: ${submissionData['custom_campaign_object']}');

    // Only set lead date if creating new lead
    if (widget.lead == null) {
      submissionData['custom_lead_date'] = getCurrentDateTime();
    }

    // Extract IDs from Map objects before submitting
    if (submissionData['custom_interested_project'] is Map) {
      final projId = (submissionData['custom_interested_project'] as Map)['id']?.toString();
      print('📍 [DEBUG] Extracted Project ID: $projId');
      submissionData['custom_interested_project'] = projId;
      submissionData['project'] = projId; 
      submissionData['project_name'] = projId;
      submissionData['custom_project'] = projId;
    }

    if (submissionData['custom_sales_manager'] is Map) {
      final managerMap = submissionData['custom_sales_manager'] as Map;
      String managerId = managerMap['id']?.toString() ?? '';
      final managerName = managerMap['name']?.toString() ?? '';

      // If ID is not an email, try to map the name to a User ID (email)
      if (managerId.isNotEmpty && !managerId.contains('@')) {
        final matchingUser = _users.firstWhereOrNull(
          (u) => u['name'] == managerName,
        );
        if (matchingUser != null) {
          managerId = matchingUser['id'];
          print('👤 [DEBUG] Mapped Sales Manager name "$managerName" to ID "$managerId"');
        }
      }
      submissionData['custom_sales_manager'] = managerId;
    } else if (submissionData['custom_sales_manager'] != null) {
      final managerIdStr = submissionData['custom_sales_manager'].toString();
      if (!managerIdStr.contains('@')) {
        // Try to find by name/id in _users
        final matchingUser = _users.firstWhereOrNull(
          (u) => u['id'] == managerIdStr || u['name'] == managerIdStr,
        );
        if (matchingUser != null) {
          submissionData['custom_sales_manager'] = matchingUser['id'];
          print('👤 [DEBUG] Mapped Sales Manager string "$managerIdStr" to ID "${matchingUser['id']}"');
        }
      }
    }

    if (submissionData['qualified_by'] is Map) {
      submissionData['qualified_by'] =
          (submissionData['qualified_by'] as Map)['id']?.toString();
    }

    if (submissionData['custom_channel_partner'] is ChannelPartner) {
      submissionData['custom_channel_partner'] =
          (submissionData['custom_channel_partner'] as ChannelPartner).name;
    }

    // Clean up temporary fields
    submissionData.remove('custom_channel_partner_id');

    // Convert budget fields and lead quality to numbers for Frappe API
    if (submissionData['custom_budget_min'] is String &&
        (submissionData['custom_budget_min'] as String).isNotEmpty) {
      submissionData['custom_budget_min'] = double.tryParse(
        submissionData['custom_budget_min'] as String,
      );
    }
    if (submissionData['custom_budget_max'] is String &&
        (submissionData['custom_budget_max'] as String).isNotEmpty) {
      submissionData['custom_budget_max'] = double.tryParse(
        submissionData['custom_budget_max'] as String,
      );
    }
    if (submissionData['custom_loan_requirements'] is String &&
        (submissionData['custom_loan_requirements'] as String).isNotEmpty) {
      submissionData['custom_loan_requirements'] = double.tryParse(
        submissionData['custom_loan_requirements'] as String,
      );
    }
    // Ensure custom_lead_quality is a double (it might be int from initialization)
    if (submissionData['custom_lead_quality'] is int) {
      submissionData['custom_lead_quality'] =
          (submissionData['custom_lead_quality'] as int).toDouble();
    }

    // Extract campaign name from object and remove temporary object
    final Campaign? selectedCampaignForIncrement = submissionData['custom_campaign_object'] is Campaign 
        ? submissionData['custom_campaign_object'] as Campaign 
        : null;

    if (selectedCampaignForIncrement != null) {
      print('📣 [DEBUG] Campaign found in submissionData: ${selectedCampaignForIncrement.campaignCodeName} (${selectedCampaignForIncrement.name})');
      submissionData['custom_campaign'] = selectedCampaignForIncrement.campaignCodeName;
      submissionData['campaign'] = selectedCampaignForIncrement.name; 
    } else {
      print('⚠️ [DEBUG] No custom_campaign_object found in submissionData or invalid type: ${submissionData['custom_campaign_object']?.runtimeType}');
    }
    submissionData.remove('custom_campaign_object');

    // Ensure custom_attended_by is an ID (email), not a full name
    if (submissionData['custom_attended_by'] != null) {
      final attendedByStr = submissionData['custom_attended_by'].toString();
      if (!attendedByStr.contains('@')) {
        // It's likely a full name, try to map it back to an ID
        final matchingUser = _users.firstWhereOrNull(
          (u) => u['name'] == attendedByStr,
        );
        if (matchingUser != null) {
          submissionData['custom_attended_by'] = matchingUser['id'];
          print('👤 [DEBUG] Mapped Attended By name "$attendedByStr" to ID "${matchingUser['id']}"');
        }
      }
    }

    // Ensure source is never null
    if (submissionData['source'] == null) {
      submissionData['source'] = submissionData['custom_tagging'] == 'Tagging'
          ? 'Walk-in With CP'
          : 'Walk-in';
      print('⚠️ [DEBUG] source was null, defaulted to ${submissionData['source']}');
    }

    print('📤 [DEBUG] Final Submission Data: $submissionData');
    
    if (submissionData['source'] == null || (submissionData['source'] as String).isEmpty) {
      print('⚠️ [DEBUG] WARNING: source field is null or empty!');
    } else {
      print('🔍 [DEBUG] Source field value: ${submissionData['source']}');
    }

    if (submissionData['custom_campaign'] == null || (submissionData['custom_campaign'] as String).isEmpty) {
      if (selectedCampaignForIncrement != null) {
        print('❌ [DEBUG] ERROR: Campaign object exists but custom_campaign was NOT set!');
      } else {
        print('ℹ ... [DEBUG] No campaign selected.');
      }
    } else {
      print('🔍 [DEBUG] Campaign field value: ${submissionData['custom_campaign']}');
    }

    // Set source flags based on selected source for better server compatibility
    if (submissionData['source'] != null) {
      final s = submissionData['source'].toString();
      submissionData['is_reference'] = s == 'Reference' ? 1 : 0;
      submissionData['is_data_calling'] = s == 'TeleCalling' ? 1 : 0;
      submissionData['is_retail'] = (s == 'Walk-in' || s == 'Walk-in With CP') ? 1 : 0;
      // You can add more mappings here if needed
      print('🚩 [DEBUG] Source flags set: reference=${submissionData['is_reference']}, data_calling=${submissionData['is_data_calling']}, retail=${submissionData['is_retail']}');
    }

    try {
      if (widget.lead != null) {
        // Update existing lead - only send the fields we need
        final updatePayload = <String, dynamic>{};

        // Add all fields to update
        for (final entry in submissionData.entries) {
          // Skip internal fields that shouldn't be sent to Frappe
          if (!entry.key.startsWith('_') && entry.key != 'name') {
            updatePayload[entry.key] = entry.value;
          }
        }

        print('📝 [DEBUG] Updating lead ${widget.lead!.name} with payload: $updatePayload');
        await LeadService.updateLead(widget.lead!.name!, updatePayload);

        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Lead updated successfully!',
            isError: false,
            title: 'Notice',
          );
          // Navigate back to CRM page by popping twice (once for form, once for detail view)
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pop(true); // Pop the form
              Navigator.of(
                context,
              ).pop(true); // Pop the detail view to go back to CRM
            }
          });
        }
        return true;
      } else {
        // Create new lead
        
        // Safety: Remove campaign_name if it contains project-specific IDs 
        // to avoid LinkValidationError on the server.
        // We will use the new custom_campaign field and increment the leads manually instead.
        submissionData.remove('campaign_name');

        final newLead = await LeadService.createLeadFromForm(submissionData);
        if (newLead != null) {
          print('✅ [DEBUG] Lead created: ${newLead.name}. Checking for campaign increment...');
          
          if (selectedCampaignForIncrement != null) {
            final campaign = selectedCampaignForIncrement;
            final currentCount = campaign.leadsGenerated;
            final projectId = submissionData['custom_interested_project']?.toString() ?? 'N/A';
            
            print('🚀 [DEBUG] Triggering manual increment for campaign: ${campaign.name} (Code: ${campaign.campaignCodeName}) in project: $projectId (Current: $currentCount -> New: ${currentCount + 1})');
            final success = await ProjectService.incrementCampaignLeads(projectId, campaign.name, currentCount);
            print('📊 [DEBUG] Campaign increment result: $success');
          } else {
            print('ℹ️ [DEBUG] No campaign to increment.');
          }

          if (mounted) {
            await _clearDraft(); // Clear draft after successful creation
            CustomSnackBar.show(
              context,
              message: 'Lead created successfully!',
              isError: false,
              title: 'Notice',
            );
            // Navigate back to CRM page with success result
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          }
          return true;
        } else {
          if (mounted) {
            CustomSnackBar.show(
              context,
              message: 'Failed to create lead. Please try again.',
              isError: true,
              title: 'Error',
            );
          }
          return false;
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        final errorString = e.toString();

        // Check for specific LinkValidationError for Sales Manager
        if (errorString.contains('LinkValidationError') &&
            errorString.contains('Sales Manager')) {
          errorMessage =
              'Invalid Sales Manager. Please select an existing Sales Manager from the list.';
        } else if (errorString.contains('DuplicateEntryError')) {
          if (errorString.contains('Email Address')) {
            errorMessage = 'A lead with this email address already exists.';
          } else if (errorString.contains('Mobile No')) {
            errorMessage = 'A lead with this mobile number already exists.';
          } else {
            errorMessage = 'This lead already exists (duplicate entry).';
          }
        } else if (errorString.contains('LinkValidationError') ||
            errorString.contains('Could not find')) {
          // Extract specific LinkValidationError message if possible
          final match = RegExp(
            r'Could not find (.*?): (.*)',
          ).firstMatch(errorString);
          if (match != null) {
            errorMessage =
                'Invalid selection: ${match.group(1)} "${match.group(2)}" not found.';
          } else {
            errorMessage =
                'Validation error: A linked record could not be found. Please check your selections.';
          }
        } else {
          errorMessage =
              'Error: ${e.toString().split(" - ").last}'; // Show raw error for debugging
        }

        CustomSnackBar.show(
          context,
          message: errorMessage,
          isError: true,
          title: 'Error',
        );
      }
      print('Submission error: $e'); // Keep for debugging
      return false;
    }
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop && widget.lead == null && result != true) {
          // Check if there is actual data to save
          if (!_isFormEmpty()) {
            // Force an immediate save before leaving
            _saveDraft(immediate: true);
            
            // Show saved as draft message only when creating a new lead with data
            CustomSnackBar.show(
              context,
              message: 'Your progress has been saved locally.',
              title: 'Draft Saved',
              isError: false,
              duration: const Duration(seconds: 2),
            );
          } else {
            // If empty, ensure any existing draft is cleared
            _clearDraft();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            widget.lead != null ? 'Edit Lead' : 'Create Lead', // Dynamic title
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: Form(
        key: _formKey,
        child: KeyedSubtree(
          key: ValueKey('lead_form_${_draftLoaded}_$_resetCounter'),
          child: Column(
            children: [
              _stepHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: _stepBody(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() => _step--);
                    _scrollToTop();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.grey.shade800,
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_step > 0 && _step < 2) const SizedBox(width: 12),
            // For creation: "Next" button on steps 0-1, "Submit" button on step 2
            // For editing: "Next" button on steps 0-1, "Save" button on step 2
            if (_step < 2)
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      _saveDraft();
                      setState(() => _step++);
                      _scrollToTop();
                    }
                  },                  child: const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // "Save" (editing) or "Submit" (creation) button on the last step (Details)
            if (_step == 2)
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            setState(() => _isLoading = true);
                            final submissionOk = await _submit();
                            if (submissionOk) {
                              await _clearDraft();
                              setState(() {
                                _isLoading = false;
                                _verified = true;
                              });
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) Navigator.of(context).pop(true);
                              });
                            } else {
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Save' : 'Submit',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            // For creation: OTP verification on step 3 (COMMENTED OUT)
            // if (!_isEditing && _step == 3)
            //   const SizedBox.shrink(),
          ],
        ),
      ),
    ),
  );
  }
}

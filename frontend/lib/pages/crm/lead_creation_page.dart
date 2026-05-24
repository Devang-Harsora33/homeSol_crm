import 'dart:async';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/models/lead.dart';
import 'package:Homesol/models/sales_team.dart';
import 'package:Homesol/pages/channel_partner/channel_partner_creation_page.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
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
  const LeadCreationPage({super.key, this.preselectedProjectId, this.lead}); // Update constructor

  @override
  State<LeadCreationPage> createState() => _LeadCreationPageState();
}

class _LeadCreationPageState extends State<LeadCreationPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final Map<String, dynamic> _formData = {
    'custom_lead_quality': 0,
    'custom_occupation': 'Job',
    'custom_lead_status': 'Open',
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
  List<String> _selectedConfigurations = [];

  String? _selectedSource;
  String? _selectedCustomSourceType;
  List<String> _customSourceTypeOptions = [];

  static const List<String> _directSourceOptions = [
    'Walk-in',
    'Pole Kiosks',
    'In-Bound Lead',
    'Site Branding',
    'Newspaper Insert',
    'Refercence',
    'Digital Marketing',
    'Web Leads',
    'Friends & Family',
  ];

  static const List<String> _channelPartnerSourceOptions = [
    'Walk-in With CP',
    'Cold Calling',
    'Tagging',
    'Live Leads',
  ];

  static const List<String> _allCustomSourceOptions = [
    ..._directSourceOptions,
    ..._channelPartnerSourceOptions,
  ];

  late AnimationController _successCtrl;
  final ScrollController _scrollController = ScrollController();
  final _qualifiedOnController = TextEditingController();

  // Dropdown data sources
  List<Map<String, String>> _projects = [];
  List<String> _campaigns = [];
  List<Map<String, String>> _users = [];
  List<String> _industryOptions = [];
  List<String> _marketSegmentOptions = [];
  List<String> _leadSourceOptions = [];
  List<ChannelPartner> _channelPartners = [];
  List<SalesTeam> _salesTeams = [];
  List<Map<String, String>> _teamLeads = [];
  List<Map<String, String>> _teamProjects = [];

  // Loading flags
  bool _isFetchingProjects = true;
  bool _isFetchingCampaigns = true;
  bool _isFetchingUsers = true;
  bool _isFetchingIndustryTypes = true;
  bool _isFetchingMarketSegments = true;
  bool _isFetchingLeadSources = true;
  bool _isFetchingChannelPartners = true;
  bool _isFetchingSalesTeams = true;
  bool _isGettingLocation = false;
  String? _locationError;

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
      _qualifiedOnController.text = widget.lead!.qualifiedOn?.toIso8601String().split('T').first ?? DateTime.now().toIso8601String().split('T').first;
      
      // Ensure all simple string fields are in _formData
      _formData['first_name'] = widget.lead!.firstName ?? '';
      _formData['last_name'] = widget.lead!.lastName ?? '';
      _formData['company_name'] = widget.lead!.companyName ?? '';
      _formData['email_id'] = widget.lead!.emailId ?? '';
      _formData['mobile_no'] = widget.lead!.mobileNo ?? widget.lead!.customerPhone ?? '';
      _formData['whatsapp_no'] = widget.lead!.whatsappNo ?? '';
      _formData['custom_postal_code'] = widget.lead!.customPostalCode ?? '';
      _formData['custom_remark'] = widget.lead!.customRemark ?? '';
      _formData['industry'] = widget.lead!.industry ?? '';
      _formData['market_segment'] = widget.lead!.marketSegment ?? '';
      _formData['source'] = widget.lead!.source ?? '';
      _formData['campaign_name'] = widget.lead!.campaignName ?? '';
      _formData['custom_occupation'] = widget.lead!.customOccupation ?? 'Job';
      _formData['custom_lead_status'] = widget.lead!.customLeadStatus ?? 'Open';
      _formData['custom_tagging'] = widget.lead!.customTagging ?? 'Tagging';
      _formData['custom_current_residence_type'] = widget.lead!.customCurrentResidenceType ?? '';
      _formData['custom_looking_for_property_type'] = widget.lead!.customLookingForPropertyType ?? '';
      _formData['custom_financing_details'] = widget.lead!.customFinancingDetails ?? '';
      _formData['custom_budget_min'] = widget.lead!.customBudgetMin ?? '';
      _formData['custom_budget_max'] = widget.lead!.customBudgetMax ?? '';
      _formData['custom_expected_time_of_purchase'] = widget.lead!.customExpectedTimeOfPurchase ?? '';
      _formData['custom_purpose_of_purchase'] = widget.lead!.customPurposeOfPurchase ?? '';
      _formData['custom_preferred_contact_method'] = widget.lead!.customPreferredContactMethod ?? '';
      _formData['custom_stages'] = widget.lead!.customStages ?? '';
      _formData['location_coordinates'] = widget.lead!.locationCoordinates ?? '';
      _selectedSource = widget.lead!.source;
      _selectedCustomSourceType = widget.lead!.customSourceType;
      
      // Parse configuration selections
      if (widget.lead!.customConfiguration != null && widget.lead!.customConfiguration!.isNotEmpty) {
        _selectedConfigurations = widget.lead!.customConfiguration!
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
      
      // Set lead quality rating
      _formData['custom_lead_quality'] = (widget.lead!.customLeadQuality ?? 0.0);

      // Setup dropdown values as Map objects for proper selection
      if (widget.lead!.customInterestedProject != null && widget.lead!.customInterestedProject!.isNotEmpty) {
        _formData['custom_interested_project'] = {
          'id': widget.lead!.customInterestedProject!,
          'name': widget.lead!.customInterestedProject!,
        };
      }
      if (widget.lead!.customSalesManager != null && widget.lead!.customSalesManager!.isNotEmpty) {
        _formData['custom_sales_manager'] = {
          'id': widget.lead!.customSalesManager!,
          'name': widget.lead!.customSalesManager!,
        };
      }
      if (widget.lead!.qualifiedBy != null && widget.lead!.qualifiedBy!.isNotEmpty) {
        _formData['qualified_by'] = {
          'id': widget.lead!.qualifiedBy!,
          'name': widget.lead!.qualifiedBy!,
        };
      }
      if (widget.lead!.customChannelPartner != null && widget.lead!.customChannelPartner!.isNotEmpty) {
        _formData['custom_channel_partner_id'] = widget.lead!.customChannelPartner!;
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
      if (_formData['custom_configuration'] is String && (_formData['custom_configuration'] as String).isNotEmpty) {
        _selectedConfigurations = (_formData['custom_configuration'] as String)
            .split(',')
            .map((e) => e.trim())
            .toList();
        _configurationController.text = _formData['custom_configuration'];
      }
      _selectedSource = 'Direct'; // Default source for new leads
      _selectedCustomSourceType = 'Walk-in'; // Default custom source for new leads
    }
    _updateCustomSourceTypeOptions();
    _initializeCurrentUserAndDropdownData(); // New method to handle async init
  }

  void _updateCustomSourceTypeOptions() {
    if (_selectedSource == 'Direct') {
      _customSourceTypeOptions = _directSourceOptions;
      if (_selectedCustomSourceType == null || !_customSourceTypeOptions.contains(_selectedCustomSourceType)) {
        _selectedCustomSourceType = 'Walk-in';
      }
    } else if (_selectedSource == 'Channel Partner') {
      _customSourceTypeOptions = _channelPartnerSourceOptions;
      if (_selectedCustomSourceType == null || !_customSourceTypeOptions.contains(_selectedCustomSourceType)) {
        _selectedCustomSourceType = 'Walk-in With CP';
      }
    } else {
      // If source is neither Direct nor Channel Partner, show all options
      _customSourceTypeOptions = _allCustomSourceOptions;
      if (_selectedCustomSourceType == null || !_customSourceTypeOptions.contains(_selectedCustomSourceType)) {
        _selectedCustomSourceType = null; // No default if source is ambiguous
      }
    }
    // Also update _formData so that it's available for submission logic
    _formData['source'] = _selectedSource;
    _formData['custom_source_type'] = _selectedCustomSourceType;

    // Clear campaign_name if custom_source_type is not Digital Marketing
    if (_selectedCustomSourceType != 'Digital Marketing') {
      _formData['campaign_name'] = null;
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
          final userTeams = _salesTeams.where((team) => team.members.any((member) => member.employee == currentUserEmployeeId)).toList();

          // From those teams, get the team leads and projects
          final Set<Map<String, String>> teamLeads = {};
          final Set<Map<String, String>> teamProjects = {};

          for (final team in userTeams) {
            // Get Team Leads
            final leads = team.members
                .where((member) => member.role == 'Team Lead')
                .map((lead) => {'id': lead.userId ?? lead.employee, 'name': lead.employeeName});
            teamLeads.addAll(leads);

            // Get Projects and fetch their full details
            for (final p in team.projects) {
              final fullProject = _projects.firstWhereOrNull((proj) => proj['id'] == p.projects);
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

        if (widget.preselectedProjectId != null && (widget.lead == null || _formData['custom_interested_project'] == null)) {
          final projectMap = _projects.firstWhere(
            (p) => p['id'] == widget.preselectedProjectId,
            orElse: () => <String, String>{},
          );
          if (projectMap.isNotEmpty) {
            _formData['custom_interested_project'] = projectMap;
          }
        }

        // Default to the first available project if none is selected
        if (_formData['custom_interested_project'] == null && _teamProjects.isNotEmpty) {
          _formData['custom_interested_project'] = _teamProjects.first;
        }

        // Default to the first available sales manager if none is selected
        if (_formData['custom_sales_manager'] == null && _teamLeads.isNotEmpty) {
          _formData['custom_sales_manager'] = _teamLeads.first;
        }

        // Resolve ChannelPartner object if in edit mode and ID was stored
        if (widget.lead != null && _formData['custom_channel_partner_id'] != null) {
          final channelPartner = _channelPartners.firstWhere(
            (cp) => cp.name == _formData['custom_channel_partner_id'],
            orElse: () => ChannelPartner(name: '', firmName: ''), // Provide a default or handle null
          );
          if (channelPartner.name != null && channelPartner.name!.isNotEmpty) {
            _formData['custom_channel_partner'] = channelPartner;
          }
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

  Future<void> _fetchDropdownData() async {
    setState(() {
      _isFetchingProjects = true;
      _isFetchingCampaigns = true;
      _isFetchingUsers = true;
      _isFetchingIndustryTypes = true;
      _isFetchingMarketSegments = true;
      _isFetchingLeadSources = true;
      _isFetchingChannelPartners = true;
      _isFetchingSalesTeams = true;
    });
    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        ProjectService.fetchApiProjects(),
        LeadService.fetchCampaigns(),
        LeadService.fetchUsersWithId(),
        LeadService.fetchIndustryTypes(),
        LeadService.fetchMarketSegments(),
        LeadService.fetchLeadSources(),
        ChannelPartnerService.syncChannelPartners(forceRefresh: true),
        ApiService.fetchSalesTeams(),
      ]);
      setState(() {
        _projects = results[0] as List<Map<String, String>>;
        _isFetchingProjects = false;

        _campaigns = results[1] as List<String>;
        _isFetchingCampaigns = false;

        _users = results[2] as List<Map<String, String>>;
        _isFetchingUsers = false;

        _industryOptions = results[3] as List<String>;
        _isFetchingIndustryTypes = false;

        _marketSegmentOptions = results[4] as List<String>;
        _isFetchingMarketSegments = false;

        _leadSourceOptions = results[5] as List<String>;
        _isFetchingLeadSources = false;

        _channelPartners = results[6] as List<ChannelPartner>;
        _isFetchingChannelPartners = false;

        _salesTeams = results[7] as List<SalesTeam>;
        _isFetchingSalesTeams = false;
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
          _isFetchingLeadSources = false;
          _isFetchingChannelPartners = false;
          _isFetchingSalesTeams = false;
        });
      }
    }
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
      case 'Open':
        return [
          'Lead Generated',
          'Interested',
          'Detail Sent',
          'Follow Up',
          'Ringing',
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
      case 'Lost':
        return ['Not Interested'];
      default:
        return [];
    }
  }

  // ───────────────────────── HEADER STEPPER ─────────────────────────

  Widget _stepHeader() {
    final allSteps = ['Personal', 'Contact', 'Details', 'Verify'];
    final steps = allSteps.sublist(0, 3); // _isEditing ? allSteps.sublist(0, 3) : allSteps;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
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
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      key: ValueKey(keyName),
      controller: controller,
      enabled: !readOnly,
      initialValue: controller == null ? _formData[keyName]?.toString() : null,
      keyboardType: type,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: kInputDecoration.copyWith(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        counterText: "",
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

    // For Map values, ensure the value actually exists in the items list
    if (resolvedValue is Map && items.isNotEmpty && valueKey != null) {
      final valueKeyLookup = resolvedValue[valueKey];
      final matchingItem = items.firstWhereOrNull(
        (item) => item is Map && item[valueKey] == valueKeyLookup,
      );
      resolvedValue = matchingItem ?? null;
    } else if (resolvedValue is String && items.isNotEmpty && items.first is Map && valueKey != null) {
      // If stored as String, try to find matching Map item
      final matchingItem = items.firstWhereOrNull(
        (item) => item is Map && item[valueKey] == resolvedValue,
      );
      resolvedValue = matchingItem ?? null;
    } else if (resolvedValue is String && items.isNotEmpty && items.first is String) {
      // For simple strings, check if value exists in items
      if (!items.contains(resolvedValue)) {
        resolvedValue = null;
      }
    }

    return DropdownButtonFormField<dynamic>(
      // Keep as dynamic for flexibility
      key: ValueKey(keyName),

      value: resolvedValue,

      decoration: kInputDecoration.copyWith(
        labelText: label,

        suffixIcon: isLoading
            ? Transform.scale(
                scale: 0.5,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),

      dropdownColor: Colors.white,

      isExpanded: true,

      items: [
        ...items.map((e) {
          String displayValue = '';
          dynamic itemValue;

          if (e is Map<String, String>) {
            displayValue = e[displayKey] ?? '';
            itemValue = e;
          } else if (e is String) {
            displayValue = e;
            itemValue = e;
          } else if (e is ChannelPartner) {
            displayValue = e.firmName ?? '';
            itemValue = e;
          }

          return DropdownMenuItem<dynamic>(
            value: itemValue,
            child: Text(
              displayValue,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          );
        }),
        if (keyName == 'custom_channel_partner')
          const DropdownMenuItem<String>(
            value: '+ Add Channel Partner',
            child: Text(
              '+ Add Channel Partner',
              style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
      onChanged: (readOnly || isLoading)
          ? null
          : (v) {
              if (v == '+ Add Channel Partner') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChannelPartnerCreationPage(),
                  ),
                ).then((result) {
                  if (result == true) {
                    _fetchDropdownData();
                  }
                });
              } else {
                setState(() {
                  _formData[keyName] = v;
                });
                onChange(v);
              }
            },

      onSaved: (v) => onChange(v),
      validator: validator,
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
                color: state.hasError ? Colors.red.shade700 : Colors.grey.shade600,
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
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isActive ? Icons.star_rounded : Icons.star_outline_rounded,
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
    "1BHK", "1.5BHK", "2BHK", "2.5BHK",
    "3BHK","3.5BHK", "4BHK+", "Studio",
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
              },
              borderRadius: BorderRadius.circular(12), // Matches container radius
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), // Smooth transition
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          )
                        ]
                      : [],
                ),
                child: Text(
                  config,
                  style: TextStyle(
                    // White text when selected, Dark Grey when not
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
    "1BHK", "1.5BHK", "2BHK", "2.5BHK",
    "3BHK","3.5BHK", "4BHK+", "Studio",
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
          final isSelected = _formData['custom_current_residence_type'] == type;
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _formData['custom_current_residence_type'] = type;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          )
                        ]
                      : [],
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
              _text('company_name', 'Firm Name',
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
            _card([
              Text(
                "Lead Source",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              _dropdown('custom_tagging', 'Tagging', [
                'Tagging',
                'No Tagging',
              ], (v) {
                setState(() {
                  _formData['custom_tagging'] = v;
                  if (v == 'Tagging') {
                    _selectedSource = 'Channel Partner';
                    _updateCustomSourceTypeOptions();
                  }
                  if (v == 'No Tagging') {
                    _selectedSource = 'Direct';
                    _updateCustomSourceTypeOptions();
                  }
                });
              },
              validator: (v) => v == null ? 'Required' : null,
              ),
              _dropdown(
                'source',
                'Source',
                _leadSourceOptions,
                (v) {
                  setState(() {
                    _selectedSource = v;
                    _updateCustomSourceTypeOptions();
                  });
                },
                isLoading: _isFetchingLeadSources,
                validator: (v) => v == null ? 'Required' : null,
              ),
              _dropdown(
                'custom_source_type',
                'Custom Source Type',
                _customSourceTypeOptions,
                (v) {
                  setState(() {
                    _selectedCustomSourceType = v;
                    if (v == 'Tagging') {
                      _selectedSource = 'Channel Partner';
                      _updateCustomSourceTypeOptions();
                    }
                    if (v != 'Digital Marketing') {
                      _formData['campaign_name'] = null;
                    }
                  });
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              
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
              _dropdown(
                'custom_lead_status',
                'Lead Status',
                ['Open', 'Prospect', 'Won', 'Lost'],
                (v) {
                  setState(() {
                    _formData['custom_lead_status'] = v;
                    _formData['custom_stages'] =
                        null; // Reset stage when status changes
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
              if (_formData['custom_source_type'] == 'Digital Marketing')
                _dropdown(
                  'campaign_name',
                  'Campaign Name',
                  _campaigns,
                  (v) => _formData['campaign_name'] = v,
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
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Please enter a valid postal code (digits only)';
                }
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
              _dropdown(
                'custom_interested_project',
                'Interested Project',
                _teamProjects,
                (val) {
                  setState(() {
                    _formData['custom_interested_project'] =
                        val as Map<String, String>?;                  });
                },
                displayKey: 'name',
                valueKey: 'id',
                isLoading: _isFetchingSalesTeams,
                validator: (v) => v == null ? 'Required' : null,
              ),
              _text(
                'custom_configuration',
                'Configuration (e.g., 3BHK)',
                (v) => _formData['custom_configuration'] = v,
                controller: _configurationController,
                required: true,
              ),
              _buildConfigurationButtons(),
              Row(
                children: [
                  Expanded(
                    child: _text(
                      'custom_budget_min',
                      'Min Budget(In Cr)',
                      (v) => _formData['custom_budget_min'] = v,
                      type: TextInputType.number,
                      required: true,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(value)) {
                            return 'Enter a valid number';
                          }
                          if (double.tryParse(value)! <= 0) {
                            return 'Budget must be positive';
                          }
                          if (_formData['custom_budget_max'] != null && _formData['custom_budget_max'].isNotEmpty) {
                            final min = double.tryParse(value);
                            final max = double.tryParse(_formData['custom_budget_max']);
                            if (min != null && max != null && min > max) {
                              return 'Min budget cannot be greater than Max budget';
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
                      'Max Budget(In Cr)',
                      (v) => _formData['custom_budget_max'] = v,
                      type: TextInputType.number,
                      required: true,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(value)) {
                            return 'Enter a valid number';
                          }
                          if (double.tryParse(value)! <= 0) {
                            return 'Budget must be positive';
                          }
                          if (_formData['custom_budget_min'] != null && _formData['custom_budget_min'].isNotEmpty) {
                            final min = double.tryParse(_formData['custom_budget_min']);
                            final max = double.tryParse(value);
                            if (min != null && max != null && max < min) {
                              return 'Max budget cannot be less than Min budget';
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
                ['Own Funds', 'Loan Required', 'Both'],
                (v) => _formData['custom_financing_details'] = v,
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
              ),
              _dropdown(
                'custom_expected_time_of_purchase',
                'Expected Purchase Time',
                ['Immediate', '3-6 months', '6-12 months', 'More than 12 months'],
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
                (val) => _formData['custom_sales_manager'] =
                    val as Map<String, String>?,
                displayKey: 'name',
                valueKey: 'id',
                isLoading: _isFetchingSalesTeams,
                validator: (v) => v == null ? 'Required' : null,
              ),
              _dropdown(
                'qualified_by',
                'Closed By',
                _users,
                (val) =>
                    _formData['qualified_by'] = val as Map<String, String>?,
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
    _formKey.currentState!.save();

    // Create a clean copy of form data for submission
    final submissionData = Map<String, dynamic>.from(_formData);

    // Only set lead date if creating new lead
    if (widget.lead == null) {
      submissionData['custom_lead_date'] = getCurrentDateTime();
    }

    // Extract IDs from Map objects before submitting
    if (submissionData['custom_interested_project'] is Map) {
      submissionData['custom_interested_project'] =
          (submissionData['custom_interested_project'] as Map<String, String>)['id'];
    }

    if (submissionData['custom_sales_manager'] is Map) {
      submissionData['custom_sales_manager'] =
          (submissionData['custom_sales_manager'] as Map<String, String>)['id'];
    }

    if (submissionData['qualified_by'] is Map) {
      submissionData['qualified_by'] =
          (submissionData['qualified_by'] as Map<String, String>)['id'];
    }

    if (submissionData['custom_channel_partner'] is ChannelPartner) {
      submissionData['custom_channel_partner'] =
          (submissionData['custom_channel_partner'] as ChannelPartner).name;
    }

    // Clean up temporary fields
    submissionData.remove('custom_channel_partner_id');

    // Convert budget fields and lead quality to numbers for Frappe API
    if (submissionData['custom_budget_min'] is String && (submissionData['custom_budget_min'] as String).isNotEmpty) {
      submissionData['custom_budget_min'] = double.tryParse(submissionData['custom_budget_min'] as String);
    }
    if (submissionData['custom_budget_max'] is String && (submissionData['custom_budget_max'] as String).isNotEmpty) {
      submissionData['custom_budget_max'] = double.tryParse(submissionData['custom_budget_max'] as String);
    }
    // Ensure custom_lead_quality is a double (it might be int from initialization)
    if (submissionData['custom_lead_quality'] is int) {
      submissionData['custom_lead_quality'] = (submissionData['custom_lead_quality'] as int).toDouble();
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

        if (mounted) {
          CustomSnackBar.show(context, message: 'Lead updated successfully!', isError: false, title: 'Notice');
          // Navigate back to CRM page by popping twice (once for form, once for detail view)
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pop(true); // Pop the form
              Navigator.of(context).pop(true); // Pop the detail view to go back to CRM
            }
          });
        }
        return true;
      } else {
        // Create new lead
        final newLead = await LeadService.createLeadFromForm(submissionData);
        if (newLead != null) {
          if (mounted) {
            CustomSnackBar.show(context, message: 'Lead created successfully!', isError: false, title: 'Notice');
            // Navigate back to CRM page with success result
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          }
          return true;
        } else {
          if (mounted) {
            CustomSnackBar.show(context, message: 'Failed to create lead. Please try again.', isError: true, title: 'Error');
          }
          return false;
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        final errorString = e.toString();
        
        // Check for specific LinkValidationError for Sales Manager
        if (errorString.contains('LinkValidationError') && errorString.contains('Sales Manager')) {
          errorMessage = 'Invalid Sales Manager. Please select an existing Sales Manager from the list.';
        } else if (errorString.contains('DuplicateEntryError')) {
          if (errorString.contains('Email Address')) {
            errorMessage = 'A lead with this email address already exists.';
          } else if (errorString.contains('Mobile No')) {
            errorMessage = 'A lead with this mobile number already exists.';
          } else {
            errorMessage = 'This lead already exists (duplicate entry).';
          }
        } else if (errorString.contains('LinkValidationError') || errorString.contains('Could not find')) {
          // General LinkValidationError or "Could not find" for other fields
          errorMessage = 'Validation error: One of the linked records could not be found. Please check your selections.';
        }
        else {
          errorMessage = 'Backend server issue. Please try again later.';
        }

        CustomSnackBar.show(context, message: errorMessage, isError: true, title: 'Error');
      }
      print('Submission error: $e'); // Keep for debugging
      return false;
    }
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
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
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      setState(() => _step++);
                      _scrollToTop();
                    }
                  },
                  child: const Text(
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
                              setState(() {
                                _isLoading = false;
                                _verified = true;
                              });
                              Future.delayed(
                                const Duration(seconds: 2),
                                () {
                                  if (mounted) Navigator.of(context).pop(true);
                                },
                              );
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
    );
  }
}




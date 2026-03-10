import 'package:Homesol/services/api_service.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; 
import '../models/lead.dart' as model_lead; // Alias this import
import '../models/sales_team.dart';
import '../services/databases/lead_database.dart'; 
import '../services/auth_service.dart'; // Uncomment if needed

const kAccent = Color(0xFF675D40);
const kBackgroundColor = Color(0xFFF2F2F7);

const kInputDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
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
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.redAccent),
  ),
);

// ─── EXTENSION ───
extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class CreateSiteVisitScreen extends StatefulWidget {
  final String? preselectedLeadId;
  final String? preselectedLeadDisplayName;
  final String? preselectedProjectId;
  final VoidCallback? onSiteVisitCreated; // New callback parameter

  const CreateSiteVisitScreen({
    super.key,
    this.preselectedLeadId,
    this.preselectedLeadDisplayName,
    this.preselectedProjectId,
    this.onSiteVisitCreated, // Initialize the new parameter
  });

  @override
  State<CreateSiteVisitScreen> createState() => _CreateSiteVisitScreenState();
}

class _CreateSiteVisitScreenState extends State<CreateSiteVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late LeadService _leadService; // Declare LeadService instance

  // Form field values
  String? _selectedLead;
  Map<String, String>? _selectedProject;
  String _status = 'Scheduled';

  // Lead additional fields (if missing)
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _residenceTypeController = TextEditingController();
  final TextEditingController _firmNameController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _configurationController = TextEditingController();
  final TextEditingController _budgetMinController = TextEditingController();
  final TextEditingController _budgetMaxController = TextEditingController();
  final TextEditingController _leadRemarkController = TextEditingController();
  
  String? _selectedFinancing;
  String? _selectedPurpose;
  String? _selectedExpectedTime;
  
  Map<String, String>? _selectedSalesManager;
  List<Map<String, String>> _salesManagerOptions = [];
  List<Map<String, String>> _teamLeads = [];
  List<SalesTeam> _salesTeams = [];
  bool _isSalesManagersLoading = false;

  bool _showMissingLeadFields = false;
  model_lead.Lead? _fullSelectedLead;
  List<String> _selectedConfigurations = [];
  Set<String> _missingFields = {}; // Added to track which fields were initially missing

  DateTime? _selectedDateTime; // For Visit Date

  bool _isMissing(String? val) => val == null || val.trim().isEmpty || val == '-';
  DateTime? _selectedScheduledDateTime; // For Scheduled Date (New)

  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _dateController =
      TextEditingController(); // Visit Date
  final TextEditingController _scheduledDateController =
      TextEditingController(); // Scheduled Date
  final TextEditingController _leadSearchController =
      TextEditingController(); // Lead Search Controller
  final TextEditingController _leadDisplayController =
      TextEditingController(); // Lead Display Controller

  // Dropdown data
  List<model_lead.Lead> _leadOptions = []; // Use aliased Lead
  List<model_lead.Lead> _filteredLeadOptions = []; // Filtered Lead options
  bool _isLeadsLoading = true;
  List<Map<String, String>> _projectOptions = [];
  bool _isProjectsLoading = true;
  final List<String> _statusOptions = [
    'Scheduled',
    'Visit Done',
    'Revisit Done',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _leadService = LeadService(); // Initialize LeadService
    _selectedDateTime = DateTime.now();
    _dateController.text = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(_selectedDateTime!);
    _initializeDropdownDataAndPreselect();
    
    // Add listener for lead search
    _leadSearchController.addListener(_onLeadSearchChanged);
    _fetchSalesManagers();
  }

  Future<void> _fetchSalesManagers() async {
    setState(() => _isSalesManagersLoading = true);
    try {
      final managers = await LeadService.fetchUsersWithId();
      final salesTeams = await ApiService.fetchSalesTeams();
      final profile = await AuthService.getMyProfile();

      if (mounted) {
        setState(() {
          _salesManagerOptions = managers;
          _salesTeams = salesTeams;

          if (profile?.employee != null) {
            final currentUserEmployeeId = profile!.employee;

            // Filter sales teams to find the ones the current user is in
            final userTeams = _salesTeams.where((team) => team.members.any((member) => member.employee == currentUserEmployeeId)).toList();

            // From those teams, get the team leads
            final Set<Map<String, String>> teamLeads = {};
            for (final team in userTeams) {
              final leads = team.members
                  .where((member) => member.role == 'Team Lead')
                  .map((lead) => {'id': lead.userId ?? lead.employee, 'name': lead.employeeName});
              teamLeads.addAll(leads);
            }
            _teamLeads = teamLeads.toList();
          } else {
            // Fallback if no profile or not employee
            _teamLeads = _salesManagerOptions;
          }
          
          _isSalesManagersLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching sales managers: $e');
      if (mounted) setState(() => _isSalesManagersLoading = false);
    }
  }

  Future<void> _onLeadSelected(String? leadId) async {
    if (leadId == null) {
      setState(() {
        _selectedLead = null;
        _fullSelectedLead = null;
        _showMissingLeadFields = false;
        _selectedSalesManager = null;
        _selectedFinancing = null;
        _selectedPurpose = null;
        _selectedExpectedTime = null;
        _selectedConfigurations = [];
        _missingFields.clear();
      });
      _updateLeadDisplayText();
      return;
    }

    // Reset controllers and try to pre-fill from local lead data
    model_lead.Lead? localLead;
    try {
      localLead = _leadOptions.firstWhere((l) => l.name == leadId);
    } catch (_) {}

    setState(() {
      _selectedLead = leadId;
      _isLoading = true;
      _selectedSalesManager = null;
      _selectedFinancing = null;
      _selectedPurpose = null;
      _selectedExpectedTime = null;
      
      if (localLead != null) {
        _firstNameController.text = localLead.firstName ?? '';
        _mobileController.text = localLead.mobileNo ?? localLead.customerPhone ?? '';
        _residenceTypeController.text = localLead.customCurrentResidenceType ?? '';
        _firmNameController.text = localLead.companyName ?? '';
        _postalCodeController.text = localLead.customPostalCode ?? '';
        _configurationController.text = localLead.customConfiguration ?? '';
        _budgetMinController.text = localLead.customBudgetMin ?? '';
        _budgetMaxController.text = localLead.customBudgetMax ?? '';
        _leadRemarkController.text = localLead.customRemark ?? '';
        _selectedFinancing = localLead.customFinancingDetails;
        _selectedPurpose = localLead.customPurposeOfPurchase;
        _selectedExpectedTime = localLead.customExpectedTimeOfPurchase;
        
        if (localLead.customConfiguration != null && localLead.customConfiguration!.isNotEmpty) {
          _selectedConfigurations = localLead.customConfiguration!
              .split(',')
              .map((e) => e.trim())
              .toList();
        } else {
          _selectedConfigurations = [];
        }

        // Track which fields are missing locally
        _missingFields.clear();
        if (_isMissing(localLead.firstName)) _missingFields.add('firstName');
        if (_isMissing(localLead.mobileNo ?? localLead.customerPhone)) _missingFields.add('mobileNo');
        if (_isMissing(localLead.customCurrentResidenceType)) _missingFields.add('residenceType');
        if (_isMissing(localLead.companyName)) _missingFields.add('firmName');
        if (_isMissing(localLead.customPostalCode)) _missingFields.add('postalCode');
        if (_isMissing(localLead.customConfiguration)) _missingFields.add('configuration');
        if (_isMissing(localLead.customBudgetMin)) _missingFields.add('budgetMin');
        if (_isMissing(localLead.customBudgetMax)) _missingFields.add('budgetMax');
        if (_isMissing(localLead.customSalesManager)) _missingFields.add('salesManager');
        if (_isMissing(localLead.customInterestedProject)) _missingFields.add('interestedProject');
        if (_isMissing(localLead.customFinancingDetails)) _missingFields.add('financing');
        if (_isMissing(localLead.customPurposeOfPurchase)) _missingFields.add('purpose');
        if (_isMissing(localLead.customExpectedTimeOfPurchase)) _missingFields.add('expectedTime');
        if (_isMissing(localLead.customRemark)) _missingFields.add('leadRemark');

        _showMissingLeadFields = _missingFields.isNotEmpty;
      }
    });
    _updateLeadDisplayText();

    try {
      final fullLead = await LeadService.fetchLead(leadId);
      if (mounted) {
        if (fullLead != null) {
          setState(() {
            _fullSelectedLead = fullLead;
            
            // Update controllers with full lead data
            _firstNameController.text = fullLead.firstName ?? '';
            _mobileController.text = fullLead.mobileNo ?? fullLead.customerPhone ?? '';
            _residenceTypeController.text = fullLead.customCurrentResidenceType ?? '';
            _firmNameController.text = fullLead.companyName ?? '';
            _postalCodeController.text = fullLead.customPostalCode ?? '';
            _configurationController.text = fullLead.customConfiguration ?? '';
            _budgetMinController.text = fullLead.customBudgetMin ?? '';
            _budgetMaxController.text = fullLead.customBudgetMax ?? '';
            _leadRemarkController.text = fullLead.customRemark ?? '';
            _selectedFinancing = fullLead.customFinancingDetails;
            _selectedPurpose = fullLead.customPurposeOfPurchase;
            _selectedExpectedTime = fullLead.customExpectedTimeOfPurchase;
            
            if (fullLead.customConfiguration != null && fullLead.customConfiguration!.isNotEmpty) {
              _selectedConfigurations = fullLead.customConfiguration!
                  .split(',')
                  .map((e) => e.trim())
                  .toList();
            } else {
              _selectedConfigurations = [];
            }

            if (fullLead.customSalesManager != null && fullLead.customSalesManager!.isNotEmpty) {
              try {
                // Try to find in filtered _teamLeads first
                _selectedSalesManager = _teamLeads.firstWhere(
                  (m) => m['id'] == fullLead.customSalesManager,
                  orElse: () => _salesManagerOptions.firstWhere(
                    (m) => m['id'] == fullLead.customSalesManager,
                    orElse: () => {'id': fullLead.customSalesManager!, 'name': fullLead.customSalesManager!},
                  ),
                );
              } catch (e) {
                _selectedSalesManager = {'id': fullLead.customSalesManager!, 'name': fullLead.customSalesManager!};
              }
            } else {
              _selectedSalesManager = null;
            }

            // Re-calculate missing fields based on full data
            _missingFields.clear();
            if (_isMissing(fullLead.firstName)) _missingFields.add('firstName');
            if (_isMissing(fullLead.mobileNo ?? fullLead.customerPhone)) _missingFields.add('mobileNo');
            if (_isMissing(fullLead.customCurrentResidenceType)) _missingFields.add('residenceType');
            if (_isMissing(fullLead.companyName)) _missingFields.add('firmName');
            if (_isMissing(fullLead.customPostalCode)) _missingFields.add('postalCode');
            if (_isMissing(fullLead.customConfiguration)) _missingFields.add('configuration');
            if (_isMissing(fullLead.customBudgetMin)) _missingFields.add('budgetMin');
            if (_isMissing(fullLead.customBudgetMax)) _missingFields.add('budgetMax');
            if (_isMissing(fullLead.customSalesManager)) _missingFields.add('salesManager');
            if (_isMissing(fullLead.customInterestedProject)) _missingFields.add('interestedProject');
            if (_isMissing(fullLead.customFinancingDetails)) _missingFields.add('financing');
            if (_isMissing(fullLead.customPurposeOfPurchase)) _missingFields.add('purpose');
            if (_isMissing(fullLead.customExpectedTimeOfPurchase)) _missingFields.add('expectedTime');
            if (_isMissing(fullLead.customRemark)) _missingFields.add('leadRemark');

            _showMissingLeadFields = _missingFields.isNotEmpty;
            
            if (_showMissingLeadFields) {
              _showSnackBar('Please complete missing lead details in the form.', isError: false);
            }
          });
          _updateLeadDisplayText();
        } else if (localLead == null) {
          // Both local and remote failed
          _showSnackBar('Failed to fetch lead details. Please try again.', isError: true);
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching lead: $e');
      if (mounted) {
        // If we have local data, we can still proceed with it
        if (localLead == null) {
          _showSnackBar('Error fetching lead: $e', isError: true);
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildConfigurationButtons() {
    final configurations = [
      "1BHK", "1.5BHK", "2BHK", "2.5BHK",
      "3BHK", "4BHK", "5BHK", "Studio",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          spacing: 10.0,
          runSpacing: 10.0,
          children: configurations.map((config) {
            final isSelected = _selectedConfigurations.contains(config);
            
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSelected) {
                      _selectedConfigurations.remove(config);
                    } else {
                      _selectedConfigurations.add(config);
                    }
                    String result = _selectedConfigurations.join(', ');
                    _configurationController.text = result;
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
                    config,
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

  void _onLeadSearchChanged() {
    final query = _leadSearchController.text.toLowerCase();
    setState(() {
      _filteredLeadOptions = _leadOptions.where((lead) {
        final name = (lead.leadName ?? '').toLowerCase();
        final id = (lead.name ?? '').toLowerCase();
        final phone = (lead.mobileNo ?? '').toLowerCase();
        final matches = name.contains(query) || id.contains(query) || phone.contains(query);
        final isSelected = lead.name == _selectedLead;
        return matches || isSelected;
      }).toList();
    });
  }

  void _updateLeadDisplayText() {
    if (_selectedLead == null) {
      _leadDisplayController.text = ''; // Clear text so validator works
    } else {
      final lead = _leadOptions.where((l) => l.name == _selectedLead);
      if (lead.isNotEmpty) {
        _leadDisplayController.text = lead.first.leadName ?? lead.first.name ?? 'Selected Lead';
      } else {
        _leadDisplayController.text = 'Selected Lead';
      }
    }
  }

  Future<void> _initializeDropdownDataAndPreselect() async {
    await _fetchDropdownData(); // Wait for data to be fetched

    if (mounted) {
      String? leadToSelect = widget.preselectedLeadId;
      if (leadToSelect == null && _leadOptions.isNotEmpty) {
        leadToSelect = _leadOptions.first.name;
      }

      if (leadToSelect != null) {
        await _onLeadSelected(leadToSelect);
      }

      setState(() {
        if (widget.preselectedProjectId != null) {
          try {
            _selectedProject = _projectOptions.firstWhere((p) => p['id'] == widget.preselectedProjectId);
          } catch (e) {
            _selectedProject = null; // Not found
          }
        }
      });
      // Update filtered list after setting _selectedLead
      _onLeadSearchChanged();
    }
  }
  Future<void> _fetchDropdownData() async {
    setState(() {
      _isLeadsLoading = true;
      _isProjectsLoading = true;
    });

    try {
      await _leadService.syncMyLeads(); // Sync data from API to local DB

      final List<Map<String, dynamic>> rawLeads = await LeadDatabase().getAllLeads();
      final List<model_lead.Lead> leads = rawLeads.map((data) {
        final leadJson = json.decode(data['data']);
        return model_lead.Lead.fromJson(leadJson);
      }).toList();

      final projects = await ProjectService.fetchApiProjects();

      if (mounted) {
        setState(() {
          _leadOptions = leads;
          _filteredLeadOptions = leads; // Initialize with all leads
          // No longer initializing _selectedLead with the first lead here
          // It will be set from widget.preselectedLeadId if available
          _projectOptions = projects;
          print('DEBUG: _projectOptions after fetch: $_projectOptions'); // Debug print for project options
          // No longer initializing _selectedProject with the first project here
          // It will be set from widget.preselectedProjectId if available
        });
        // Run filter logic to handle any pre-existing text or selection
        _onLeadSearchChanged();
        _updateLeadDisplayText();
      }
    } catch (e) {
      _showSnackBar('Failed to load dropdown data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLeadsLoading = false;
          _isProjectsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();

    _dateController.dispose();

    _scheduledDateController.dispose();
    
    _leadSearchController.dispose();
    _leadDisplayController.dispose();
    
    _firstNameController.dispose();
    _mobileController.dispose();
    _residenceTypeController.dispose();
    _firmNameController.dispose();
    _postalCodeController.dispose();
    _configurationController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();

    super.dispose();
  }

  // ───────────────────────── LOGIC ─────────────────────────

  // Helper to pick date time (reusable)

  Future<DateTime?> _pickDateTime(DateTime? initialDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,

      initialDate: initialDate ?? DateTime.now(),

      firstDate: DateTime(2000),

      lastDate: DateTime(2101),

      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: kAccent)),

          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,

        initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),

        builder: (context, child) {
          return Theme(
            data: Theme.of(
              context,
            ).copyWith(colorScheme: const ColorScheme.light(primary: kAccent)),

            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        return DateTime(
          pickedDate.year,

          pickedDate.month,

          pickedDate.day,

          pickedTime.hour,

          pickedTime.minute,
        );
      }
    }

    return null;
  }

  // Logic for Main Visit Date

  // Future<void> _selectDateTime() async {

  //   final dt = await _pickDateTime(_selectedDateTime);

  //   if (dt != null) {

  //     setState(() {

  //       _selectedDateTime = dt;

  //       _dateController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

  //     });

  //   }

  // }

  // Logic for Scheduled Date

  Future<void> _selectScheduledDateTime() async {
    final dt = await _pickDateTime(_selectedScheduledDateTime);

    if (dt != null) {
      setState(() {
        _selectedScheduledDateTime = dt;

        _scheduledDateController.text = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(dt);
      });
    }
  }

    Future<void> _submitForm() async {
      if (!_formKey.currentState!.validate()) return;
      
      if (_selectedLead == null || _selectedLead!.isEmpty) {
        _showSnackBar('Please select a lead.', isError: true);
        return;
      }

      setState(() => _isLoading = true);

      try {
        // 1. Update Lead if fields were missing
        if (_selectedLead != null && _showMissingLeadFields) {
          final leadUpdates = {
            "first_name": _firstNameController.text,
            "mobile_no": _mobileController.text,
            "custom_current_residence_type": _residenceTypeController.text,
            "company_name": _firmNameController.text,
            "custom_postal_code": _postalCodeController.text,
            "custom_configuration": _configurationController.text,
            "custom_budget_min": _budgetMinController.text,
            "custom_budget_max": _budgetMaxController.text,
            "custom_sales_manager": _selectedSalesManager?['id'],
            "custom_interested_project": _selectedProject?['id'],
            "custom_financing_details": _selectedFinancing,
            "custom_purpose_of_purchase": _selectedPurpose,
            "custom_expected_time_of_purchase": _selectedExpectedTime,
            "custom_remark": _leadRemarkController.text,
          };
          
          await _leadService.updateLead(_selectedLead!, leadUpdates);
          print('Lead updated successfully with missing fields.');
        }

        // 2. Create Site Visit
        final body = {
          "lead": _selectedLead,
          "project": _selectedProject?['id'],
          "remark": _remarkController.text,
          "visit_date": _dateController.text,
          "status": _status,
          // Only send scheduled time if status is Scheduled, otherwise default to visit_date
          "visit_scheduled_datetime": _status == 'Scheduled'
              ? _scheduledDateController.text
              : _dateController.text,
        };

        final String? errorMessage = await SiteVisitService.createSiteVisit(body);

        if (errorMessage == null) {
          _showSnackBar('Site visit created successfully!', isError: false);
          if (mounted) {
            widget.onSiteVisitCreated?.call(); // Invoke the callback
            Navigator.of(context).pop();
          }
        } else {
          _showSnackBar('Failed to create site visit: $errorMessage', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),

        // Use kAccent (0xFF675D40) for success, Red for error
        backgroundColor: isError ? Colors.redAccent : kAccent,

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ───────────────────────── UI HELPERS ─────────────────────────

  void _showLeadSearchPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _leadSearchController,
                      decoration: kInputDecoration.copyWith(
                        hintText: 'Search by name, ID or phone...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _leadSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _leadSearchController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setModalState(() {});
                      },
                    ),
                  ),
                  Expanded(
                    child: _isLeadsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _leadOptions.where((lead) {
                              final query = _leadSearchController.text.toLowerCase();
                              final name = (lead.leadName ?? '').toLowerCase();
                              final id = (lead.name ?? '').toLowerCase();
                              final phone = (lead.mobileNo ?? '').toLowerCase();
                              return name.contains(query) || id.contains(query) || phone.contains(query);
                            }).length,
                            itemBuilder: (context, index) {
                              final filteredList = _leadOptions.where((lead) {
                                final query = _leadSearchController.text.toLowerCase();
                                final name = (lead.leadName ?? '').toLowerCase();
                                final id = (lead.name ?? '').toLowerCase();
                                final phone = (lead.mobileNo ?? '').toLowerCase();
                                return name.contains(query) || id.contains(query) || phone.contains(query);
                              }).toList();
                              
                              final lead = filteredList[index];
                              final isSelected = lead.name == _selectedLead;
                              
                              return ListTile(
                                title: Text(lead.leadName ?? lead.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(lead.name ?? ''),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: kAccent) : null,
                                selected: isSelected,
                                onTap: () {
                                  _onLeadSelected(lead.name);
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
  }

  Widget _card(String title, List<Widget> children) {
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

        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          const Divider(height: 24),

          ...children.map(
            (e) =>
                Padding(padding: const EdgeInsets.only(bottom: 16.0), child: e),
          ),
        ],
      ),
    );
  }

  Widget _styledDropdown({
    required String label,
    required dynamic value, // This can be String for Lead/Status or Map<String,String> for Project
    required List<dynamic> items,
    required Function(dynamic) onChanged, // Now accepts dynamic
    bool isLoading = false,
    String? displayKey,
    String? valueKey,
  }) {
    dynamic resolvedValue = value;
    if (value != null && items.isNotEmpty) {
      if (value is String) {
        if (items.first is Map && valueKey != null) {
          resolvedValue = items.firstWhereOrNull(
            (item) => item is Map && item[valueKey] == value,
          );
        } else if (items.first is String) {
          if (!items.contains(value)) {
            resolvedValue = null;
          }
        }
      } else if (value is Map && valueKey != null) {
        final valueKeyLookup = value[valueKey];
        resolvedValue = items.firstWhereOrNull(
          (item) => item is Map && item[valueKey] == valueKeyLookup,
        );
      }
    } else {
      resolvedValue = null;
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<dynamic>( // Keep as dynamic for flexibility
          value: resolvedValue,
          decoration: kInputDecoration.copyWith(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade600),
            suffixIcon: isLoading 
            ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(strokeWidth: 2))             
            : null,
          ),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: items.map((dynamic item) {
            String displayValue = '';
            dynamic itemValue = null; // Can be null

            if (item is model_lead.Lead) {
              displayValue = item.leadName ?? item.name ?? '';
              itemValue = item.name; // This is a String
            } else if (item is Map<String, String>) { // For project options
              displayValue = item[displayKey] ?? '';
              itemValue = item; // This is a Map
            } else if (item is String) { // For status options
              displayValue = item;
              itemValue = item; // This is a String
            }
            
            return DropdownMenuItem<dynamic>( // Keep dynamic
              value: itemValue,
              child: Text(displayValue, style: const TextStyle(fontWeight: FontWeight.w500)),
            );
          }).toList(),
          onChanged: isLoading ? null : onChanged,
          validator: (val) => val == null || (val is String && val.isEmpty) ? 'Required' : null,
          selectedItemBuilder: (BuildContext context) {
            return items.map<Widget>((dynamic item) {
              String displayValue = '';
              if (item is model_lead.Lead) {
                displayValue = item.leadName ?? item.name ?? '';
              } else if (item is Map<String, String>) {
                displayValue = item[displayKey] ?? '';
              }
              else if (item is String) {
                displayValue = item;
              }
              return Text(displayValue, overflow: TextOverflow.ellipsis);
            }).toList();
          },
        ),
      ],
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,

    required String label,

    int maxLines = 1,

    bool readOnly = false,

    VoidCallback? onTap,

    ValueChanged<String>? onChanged, // Added onChanged

    IconData? icon,

    bool isRequired = true, // Added isRequired param
    
    TextInputType type = TextInputType.text, // Added type

    FormFieldValidator<String>? validator, // Added validator
  }) {
    return TextFormField(
      controller: controller,

      readOnly: readOnly,

      onTap: onTap,

      onChanged: onChanged, // Pass onChanged to TextFormField

      maxLines: maxLines,

      keyboardType: type, // Pass type to TextFormField

      style: const TextStyle(fontWeight: FontWeight.w500),

      decoration: kInputDecoration.copyWith(
        labelText: label,

        labelStyle: TextStyle(color: Colors.grey.shade600),

        alignLabelWithHint: maxLines > 1,

        suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      ),

      validator: (val) {
        if (isRequired && (val == null || val.isEmpty)) {
          return 'Required';
        }
        return validator?.call(val);
      },
    );
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Site Visit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 1. Visit Details Card
              _card("Visit Details", [
                InkWell(
                  onTap: _showLeadSearchPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: IgnorePointer(
                    child: _styledTextField(
                      controller: _leadDisplayController,
                      label: "Select Lead",
                      icon: Icons.search,
                      readOnly: true,
                      validator: (val) {
                        if (_selectedLead == null || _selectedLead!.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                _styledDropdown(
                  label: "Select Project",
                  value: _selectedProject,
                  items: _projectOptions,
                  isLoading: _isProjectsLoading,
                  onChanged: (val) {
                    setState(() {
                      _selectedProject = val as Map<String, String>?; // Cast to Map<String, String>?
                    });
                  },
                  displayKey: 'name',
                  valueKey: 'id',
                ),
                _styledTextField(
                  controller: _dateController,
                  label: "Entry Date & Time",
                  readOnly: true,
                  icon: Icons.calendar_today,
                  // onTap: _selectDateTime,
                ),
              ]),

              // 1b. Missing Lead Details Card (Conditional)
              if (_selectedLead != null && _showMissingLeadFields)
                _card("Missing Lead Details", [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "This lead has incomplete information. Please fill in the mandatory details to proceed with the site visit.",
                      style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_missingFields.contains('firstName'))
                    _styledTextField(
                      controller: _firstNameController,
                      label: "First Name",
                      icon: Icons.person,
                    ),
                  if (_missingFields.contains('mobileNo'))
                    _styledTextField(
                      controller: _mobileController,
                      label: "Mobile Number",
                      icon: Icons.phone,
                      type: TextInputType.phone,
                    ),
                  if (_missingFields.contains('residenceType'))
                    _styledTextField(
                      controller: _residenceTypeController,
                      label: "Current Residence Type",
                      icon: Icons.home,
                    ),
                  if (_missingFields.contains('firmName'))
                    _styledTextField(
                      controller: _firmNameController,
                      label: "Firm Name",
                      icon: Icons.business,
                    ),
                  if (_missingFields.contains('postalCode'))
                    _styledTextField(
                      controller: _postalCodeController,
                      label: "Postal Code",
                      icon: Icons.location_on,
                      type: TextInputType.number,
                    ),
                  if (_missingFields.contains('configuration')) ...[
                    _styledTextField(
                      controller: _configurationController,
                      label: "Configuration (e.g. 3BHK)",
                      icon: Icons.meeting_room,
                    ),
                    _buildConfigurationButtons(),
                  ],
                  if (_missingFields.contains('budgetMin') || _missingFields.contains('budgetMax'))
                    Row(
                      children: [
                        Expanded(
                          child: _styledTextField(
                            controller: _budgetMinController,
                            label: "Min Budget(In Cr)",
                            type: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _styledTextField(
                            controller: _budgetMaxController,
                            label: "Max Budget(In Cr)",
                            type: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  if (_missingFields.contains('salesManager'))
                    _styledDropdown(
                      label: "Sales Manager",
                      value: _selectedSalesManager,
                      items: _teamLeads,
                      isLoading: _isSalesManagersLoading,
                      onChanged: (val) {
                        setState(() {
                          _selectedSalesManager = val as Map<String, String>?;
                        });
                      },
                      displayKey: 'name',
                      valueKey: 'id',
                    ),
                  if (_missingFields.contains('financing'))
                    _styledDropdown(
                      label: "Financing",
                      value: _selectedFinancing,
                      items: ['Own Funds', 'Loan Required', 'Both'],
                      onChanged: (val) => setState(() => _selectedFinancing = val as String?),
                    ),
                  if (_missingFields.contains('purpose'))
                    _styledDropdown(
                      label: "Purpose",
                      value: _selectedPurpose,
                      items: ['Investment', 'Personal use'],
                      onChanged: (val) => setState(() => _selectedPurpose = val as String?),
                    ),
                  if (_missingFields.contains('expectedTime'))
                    _styledDropdown(
                      label: "Expected Purchase Time",
                      value: _selectedExpectedTime,
                      items: ['Immediate', '3-6 months', '6-12 months', 'More than 12 months'],
                      onChanged: (val) => setState(() => _selectedExpectedTime = val as String?),
                    ),
                  if (_missingFields.contains('leadRemark'))
                    _styledTextField(
                      controller: _leadRemarkController,
                      label: "Lead Remark",
                      icon: Icons.comment,
                      maxLines: 2,
                    ),
                ]),

              // 2. Status & Remarks Card
              _card("Status & Remarks", [
                _styledDropdown(
                  label: "Current Status",
                  value: _status,
                  items: _statusOptions,
                  onChanged: (val) => setState(() => _status = val!),
                ),
                
                // ★★★ CONDITIONAL FIELD: Scheduled Date ★★★
                if (_status == 'Scheduled')
                  _styledTextField(
                    controller: _scheduledDateController,
                    label: "Scheduled Date & Time",
                    readOnly: true,
                    icon: Icons.schedule,
                    onTap: _selectScheduledDateTime,
                    isRequired: true,
                  ),

                _styledTextField(
                  controller: _remarkController,
                  label: "Remarks (Optional)",
                  maxLines: 3,
                  isRequired: false,
                ),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _submitForm,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    'Create Site Visit',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/models/lead.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/models/sales_team.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';

class BulkLeadTransferPage extends StatefulWidget {
  const BulkLeadTransferPage({super.key});

  @override
  State<BulkLeadTransferPage> createState() => _BulkLeadTransferPageState();
}

class _BulkLeadTransferPageState extends State<BulkLeadTransferPage> {
  bool _isLoadingInitialData = true;

  List<SalesTeam> _allSalesTeams = [];
  Map<String, String> _projectIdToNameMap = {};
  String? _currentUserEmail;
  String? _currentUserName;

  // Filtered lists
  List<String> _availableProjects = [];
  List<Member> _teamMembersForProject = [];

  // Selections
  String? _selectedProject;
  String? _selectedSourceUserId;
  String? _selectedDestUserId;
  String _transferType = 'Temporary';
  DateTime? _validTill;

  bool _isLoadingLeads = false;
  int _sourceLeadCount = 0;
  List<Lead> _sourceLeads = [];
  Set<String> _selectedLeadNames = {};

  List<String> _eligibleDestUsers = [];
  bool _isLoadingEligibleUsers = false;

  bool _isTransferring = false;
  double _transferProgress = 0.0;
  String _transferStatus = '';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _fetchEligibleUsers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEligibleUsers() async {
    setState(() => _isLoadingEligibleUsers = true);
    try {
      _eligibleDestUsers = await LeadService.fetchEligibleTransferUsers();
    } catch (e) {
      print('Error fetching eligible users: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingEligibleUsers = false);
      }
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoadingInitialData = true);
    try {
      final profile = await AuthService.getMyProfile();
      final userData = await AuthService.getUserData();
      _currentUserEmail = userData?['email'];
      _currentUserName = profile?.employeeName;

      final futures = await Future.wait([
        ApiService.fetchSalesTeams(),
        ProjectService.fetchProjects(),
      ]);

      _allSalesTeams = futures[0] as List<SalesTeam>;
      final allProjects = futures[1] as List<dynamic>; // List<Project>

      // Map project ID to Project Name
      for (final p in allProjects) {
        _projectIdToNameMap[p.id] = p.projectName;
      }

      // Find all projects where this user is a Team Lead
      final Set<String> projectsSet = {};
      for (final team in _allSalesTeams) {
        bool isUserLeadInThisTeam = false;
        for (final member in team.members) {
          final isCurrentUser = member.employee == _currentUserEmail ||
              member.userId == _currentUserEmail ||
              (_currentUserName != null && member.employeeName.toLowerCase() == _currentUserName!.toLowerCase());

          if (isCurrentUser && member.role == 'Team Lead') {
            isUserLeadInThisTeam = true;
            break;
          }
        }

        if (isUserLeadInThisTeam) {
          for (final proj in team.projects) {
            projectsSet.add(proj.projects); // proj.projects stores the project ID
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableProjects = projectsSet.toList()..sort((a, b) {
            final nameA = _projectIdToNameMap[a] ?? a;
            final nameB = _projectIdToNameMap[b] ?? b;
            return nameA.compareTo(nameB);
          });
          _isLoadingInitialData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
        CustomSnackBar.show(context, message: 'Failed to fetch initial data: $e', isError: true);
      }
    }
  }

  void _onProjectSelected(String? projectId) async {
    setState(() {
      _selectedProject = projectId;
      _selectedSourceUserId = null;
      _selectedDestUserId = null;
      _sourceLeadCount = 0;
      _sourceLeads = [];
      _selectedLeadNames = {};
      _teamMembersForProject = [];
    });

    if (projectId == null) return;
    
    // Show a small loader while fetching profiles
    if (mounted) {
      CustomSnackBar.show(context, message: 'Loading team members...');
    }

    // Find all teams that have this project AND where the user is a Team Lead
    final Set<String> uniqueUserIds = {};
    final List<Member> members = [];

    for (final team in _allSalesTeams) {
      final hasProject = team.projects.any((p) => p.projects == projectId);
      if (!hasProject) continue;

      bool isUserLeadInThisTeam = false;
      for (final member in team.members) {
        final isCurrentUser = member.employee == _currentUserEmail ||
            member.userId == _currentUserEmail ||
            (_currentUserName != null && member.employeeName.toLowerCase() == _currentUserName!.toLowerCase());

        if (isCurrentUser && member.role == 'Team Lead') {
          isUserLeadInThisTeam = true;
          break;
        }
      }

      if (isUserLeadInThisTeam) {
        for (final member in team.members) {
          final role = member.role.toLowerCase();
          // First filter by SalesTeam role
          if (role == 'member' || role == 'team lead' || role == 'sales representative') {
            final identifier = member.userId ?? member.employee; 
            if (!uniqueUserIds.contains(identifier) && identifier.isNotEmpty) {
              uniqueUserIds.add(identifier);
              members.add(member);
            }
          }
        }
      }
    }

    // Now filter by actual designation by fetching profiles
    final List<Member> filteredMembers = [];
    for (var member in members) {
      if (member.employee.isNotEmpty) {
        try {
          final profile = await ApiService.fetchEmployeeDetails(member.employee);
          if (profile != null) {
            final designation = profile.designation.toLowerCase();
            // Exclude sourcing
            if (!designation.contains('sourcing')) {
              // Resolve the email address (userId) from profile with fallbacks
              String? resolvedEmail;
              if (profile.userId.isNotEmpty) {
                resolvedEmail = profile.userId;
              } else if (profile.companyEmail != null && profile.companyEmail!.isNotEmpty) {
                resolvedEmail = profile.companyEmail;
              } else if (profile.preferedEmail != null && profile.preferedEmail!.isNotEmpty) {
                resolvedEmail = profile.preferedEmail;
              } else if (profile.preferedContactEmail.isNotEmpty) {
                resolvedEmail = profile.preferedContactEmail;
              }
              
              // If still empty, use member.userId as last resort
              resolvedEmail ??= (member.userId?.isNotEmpty == true ? member.userId : member.employee);

              print('DEBUG: Resolved email for ${member.employee} (${member.employeeName}): $resolvedEmail');
              print('DEBUG: Profile details - userId: ${profile.userId}, companyEmail: ${profile.companyEmail}, preferedEmail: ${profile.preferedEmail}, preferedContactEmail: ${profile.preferedContactEmail}');
              
              final updatedMember = Member(
                name: member.name,
                owner: member.owner,
                creation: member.creation,
                modified: member.modified,
                modifiedBy: member.modifiedBy,
                docstatus: member.docstatus,
                idx: member.idx,
                employee: member.employee,
                employeeName: member.employeeName,
                userId: resolvedEmail, 
                designation: profile.designation, // Added designation
                role: member.role,
                parent: member.parent,
                parentfield: member.parentfield,
                parenttype: member.parenttype,
                doctype: member.doctype,
              );
              filteredMembers.add(updatedMember);
            }
          } else {
            print('DEBUG: Profile null for ${member.employee}, using member data');
            filteredMembers.add(member);
          }
        } catch (e) {
          print('DEBUG: Error resolving profile for ${member.employee}: $e');
          filteredMembers.add(member);
        }
      } else {
         filteredMembers.add(member);
      }
    }

    if (mounted) {
      setState(() {
        _teamMembersForProject = filteredMembers..sort((a, b) => a.employeeName.compareTo(b.employeeName));
      });
      // ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Optional: clear loading snackbar
    }
  }

  Future<void> _checkSourceLeads(String sourceIdentifier) async {
    setState(() {
      _isLoadingLeads = true;
      _sourceLeadCount = 0;
      _sourceLeads = [];
      _selectedLeadNames = {};
    });

    try {
      print('DEBUG: Checking leads for owner: $sourceIdentifier');
      final leads = await LeadService.fetchLeadsByOwner(sourceIdentifier);
      if (mounted) {
        setState(() {
          _sourceLeads = leads;
          _sourceLeadCount = leads.length;
          _isLoadingLeads = false;
          // By default select all
          _selectedLeadNames = leads.where((l) => l.name != null).map((l) => l.name!).toSet();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLeads = false);
        CustomSnackBar.show(context, message: 'Failed to count leads: $e', isError: true);
      }
    }
  }

  Future<void> _executeTransfer() async {
    print('DEBUG: _executeTransfer started');
    try {
      if (_selectedSourceUserId == null || _selectedDestUserId == null) {
        print('DEBUG: IDs are null: $_selectedSourceUserId, $_selectedDestUserId');
        return;
      }
      if (_selectedSourceUserId == _selectedDestUserId) {
        CustomSnackBar.show(context, message: 'Source and Destination cannot be the same.', isError: true);
        return;
      }
      if (_selectedLeadNames.isEmpty) {
        CustomSnackBar.show(context, message: 'Please select at least one lead to transfer.', isError: true);
        return;
      }
      if (_transferType == 'Temporary' && _validTill == null) {
        CustomSnackBar.show(context, message: 'Please select a validity date for temporary transfer.', isError: true);
        return;
      }

      print('DEBUG: Resolving sourceDisplayName');
      // Safely get source display name
      String sourceDisplayName = _selectedSourceUserId!;
      try {
        if (_teamMembersForProject.isNotEmpty) {
          final matchingMembers = _teamMembersForProject.where((m) => (m.userId ?? m.employee) == _selectedSourceUserId).toList();
          if (matchingMembers.isNotEmpty) {
            sourceDisplayName = matchingMembers.first.employeeName;
            print('DEBUG: Found source member: $sourceDisplayName');
          } else {
            print('DEBUG: Source member not found in _teamMembersForProject');
          }
        }
      } catch (e) {
        print('DEBUG: Error resolving sourceDisplayName: $e');
      }

      final destIdentifier = _selectedDestUserId!;
      print('DEBUG: Dest identifier: $destIdentifier');

      print('DEBUG: Showing confirmation dialog');
      final bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.move_up, color: Color(0xFF675d40)),
              SizedBox(width: 10),
              Text('Confirm Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text.rich(
            TextSpan(
              text: 'Are you sure you want to transfer ',
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              children: [
                TextSpan(text: '${_selectedLeadNames.length} selected leads', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF675d40))),
                const TextSpan(text: ' from '),
                TextSpan(text: sourceDisplayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' to '),
                TextSpan(text: destIdentifier, style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' as a ', style: const TextStyle(color: Colors.black87)),
                TextSpan(text: '$_transferType Transfer', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF675d40))),
                const TextSpan(text: '?\n\nThis will transfer leads through the bulk transfer API.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF675d40),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Confirm Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ?? false;

      if (!confirm) return;

      setState(() {
        _isTransferring = true;
        _transferProgress = 0.5;
        _transferStatus = 'Initiating bulk transfer...';
      });

      final List<Map<String, String>> selectedLeads = _selectedLeadNames
          .where((name) => name.isNotEmpty)
          .map((name) => {"lead": name})
          .toList();

      if (selectedLeads.isEmpty) {
        print('DEBUG: selectedLeads is empty after mapping');
        throw Exception('No valid leads selected for transfer.');
      }

      final Map<String, dynamic> body = {
        "transfer_type": _transferType,
        "from_employee": _selectedSourceUserId,
        "to_employee": _selectedDestUserId,
        "project": _selectedProject,
        "docstatus": 1,
        "selected_leads": selectedLeads
      };

      if (_transferType == 'Temporary' && _validTill != null) {
        body["valid_till"] = DateFormat('yyyy-MM-dd').format(_validTill!);
      }

      print('DEBUG: performLeadTransfer Body Construction Complete');
      print('DEBUG: performLeadTransfer Request Body from Page: ${jsonEncode(body)}');

      final error = await LeadService.performLeadTransfer(body);

      if (mounted) {
        setState(() {
          _isTransferring = false;
          _transferProgress = 1.0;
          _transferStatus = (error == null) ? 'Transfer complete.' : 'Transfer failed.';
        });

        if (error == null) {
          CustomSnackBar.show(
            context,
            message: 'Bulk transfer request submitted successfully.',
            isError: false,
          );
          // Return true to indicate success to the previous page
          Navigator.pop(context, true);
        } else {
          // Show error in a clean dialog as requested
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Transfer Failed', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                error,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF675d40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e, stack) {
      print('DEBUG: Critical error in _executeTransfer: $e');
      print('DEBUG: Stack trace: $stack');
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _transferStatus = 'Error occurred during transfer.';
        });
        CustomSnackBar.show(context, message: 'Transfer failed: $e', isError: true);
      }
    }
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required Widget child,
    bool isActive = true,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF675d40).withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      step.toString(),
                      style: TextStyle(
                        color: isActive ? const Color(0xFF675d40) : Colors.grey[500], 
                        fontWeight: FontWeight.w900, 
                        fontSize: 15
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.black87 : Colors.grey[500],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            IgnorePointer(
              ignoring: !isActive || _isTransferring,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Transfer Tool', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF675d40),
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FA), // Slightly cooler off-white
      body: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF675d40)))
          : _availableProjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                        ),
                        child: Icon(Icons.group_off_rounded, size: 56, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Teams Found',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.grey[800], letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You are not assigned as a Team Lead\nto any active projects.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 15, height: 1.5),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Reassign Leads',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -1.0),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Securely transfer active leads between members of your managed teams.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 36),

                      // STEP 1: SELECT PROJECT
                      _buildStepCard(
                        step: 1,
                        title: 'Select Project Site',
                        child: DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF675d40), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFF675d40)),
                          ),
                          hint: Text('Choose a project', style: TextStyle(color: Colors.grey.shade500)),
                          value: _selectedProject,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                          items: _availableProjects.map((p) {
                            final projectName = _projectIdToNameMap[p] ?? p;
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                projectName, 
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                              ),
                            );
                          }).toList(),
                          onChanged: _onProjectSelected,
                          isExpanded: true,
                        ),
                      ),

  // STEP 2: SELECT DEPARTING EMPLOYEE
  _buildStepCard(
    step: 2,
    title: 'Select Departing Employee',
    isActive: _selectedProject != null,
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            prefixIcon: Icon(Icons.person_remove_rounded, color: Colors.red.shade400),
          ),
          hint: Text('Select source employee', style: TextStyle(color: Colors.grey.shade500)),
          value: _selectedSourceUserId,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          items: _eligibleDestUsers.map((email) {
            return DropdownMenuItem(
              value: email,
              child: Text(
                email, 
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedSourceUserId = val;
            });
            if (val != null) _checkSourceLeads(val);
          },
          isExpanded: true,
        ),
        if (_isLoadingLeads)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF675d40)),
          )
        else if (_selectedSourceUserId != null)
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: double.infinity,
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _sourceLeadCount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _sourceLeadCount > 0 ? Colors.orange.shade200 : Colors.green.shade200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                      ),
                      child: Icon(
                        _sourceLeadCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        color: _sourceLeadCount > 0 ? Colors.orange.shade700 : Colors.green.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sourceLeadCount > 0 ? 'Leads Found' : 'No Leads',
                            style: TextStyle(
                              color: _sourceLeadCount > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sourceLeadCount > 0
                                ? '$_sourceLeadCount active leads found for reassignment.'
                                : 'This employee has no active leads.',
                            style: TextStyle(
                              color: _sourceLeadCount > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_sourceLeads.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Select All
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Leads (${_selectedLeadNames.length}/${_sourceLeads.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (_selectedLeadNames.length == _sourceLeads.length) {
                                  _selectedLeadNames.clear();
                                } else {
                                  _selectedLeadNames = _sourceLeads.where((l) => l.name != null).map((l) => l.name!).toSet();
                                }
                              });
                            },
                            icon: Icon(
                              _selectedLeadNames.length == _sourceLeads.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                              size: 18,
                              color: const Color(0xFF675d40),
                            ),
                            label: Text(
                              _selectedLeadNames.length == _sourceLeads.length ? 'Deselect All' : 'Select All',
                              style: const TextStyle(color: Color(0xFF675d40), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search leads by name or ID...',
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filtered Lead List
                      Container(
                        constraints: const BoxConstraints(maxHeight: 350),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade200, width: 1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Builder(
                            builder: (context) {
                              final filtered = _sourceLeads.where((lead) {
                                final name = lead.leadName?.toLowerCase() ?? '';
                                final id = lead.name?.toLowerCase() ?? '';
                                return name.contains(_searchQuery) || id.contains(_searchQuery);
                              }).toList();

                              if (filtered.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      children: [
                                        Icon(Icons.search_off_rounded, color: Colors.grey[300], size: 48),
                                        const SizedBox(height: 12),
                                        Text('No leads match your search', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                                itemBuilder: (ctx, index) {
                                  final lead = filtered[index];
                                  final isSelected = _selectedLeadNames.contains(lead.name);
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedLeadNames.remove(lead.name!);
                                        } else {
                                          _selectedLeadNames.add(lead.name!);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  lead.leadName ?? lead.name ?? 'Unknown',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700, 
                                                    fontSize: 14,
                                                    color: isSelected ? Colors.black : Colors.black87
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  lead.name ?? '',
                                                  style: TextStyle(
                                                    color: Colors.grey[500], 
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                    letterSpacing: 0.5
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 1.1,
                                            child: Checkbox(
                                              value: isSelected,
                                              activeColor: const Color(0xFF675d40),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedLeadNames.add(lead.name!);
                                                  } else {
                                                    _selectedLeadNames.remove(lead.name!);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  ),

  // STEP 3: SELECT NEW OWNER
  _buildStepCard(
    step: 3,
    title: 'Select New Owner',
    isActive: _selectedSourceUserId != null,
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.green.shade500, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            prefixIcon: Icon(Icons.person_add_rounded, color: Colors.green.shade600),
          ),
          hint: Text('Select receiving employee', style: TextStyle(color: Colors.grey.shade500)),
          value: _selectedDestUserId,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          items: _eligibleDestUsers.map((email) {
            return DropdownMenuItem(
              value: email,
              child: Text(
                email, 
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedDestUserId = val;
            });
          },
          isExpanded: true,
        ),
        if (_isLoadingEligibleUsers)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    ),
  ),

                      // STEP 4: TRANSFER TYPE
                      _buildStepCard(
                        step: 4,
                        title: 'Transfer Type',
                        isActive: _selectedDestUserId != null,
                        child: DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF675d40), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            prefixIcon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF675d40)),
                          ),
                          value: _transferType,
                          items: const [
                            DropdownMenuItem(value: 'Temporary', child: Text('Temporary Transfer', style: TextStyle(fontWeight: FontWeight.w600))),
                            DropdownMenuItem(value: 'Permanent', child: Text('Permanent Transfer', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _transferType = val;
                                if (val == 'Permanent') _validTill = null;
                              });
                            }
                          },
                          isExpanded: true,
                        ),
                      ),

                      // STEP 5: SELECT VALIDITY (Conditional)
                      if (_transferType == 'Temporary')
                        _buildStepCard(
                          step: 5,
                          title: 'Select Validity',
                          isActive: _selectedDestUserId != null,
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      dialogBackgroundColor: Colors.white,
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF675d40),
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(0xFF675d40),
                                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => _validTill = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, color: Color(0xFF675d40)),
                                  const SizedBox(width: 16),
                                  Text(
                                    _validTill == null 
                                        ? 'Select Date' 
                                        : DateFormat('dd MMM yyyy').format(_validTill!),
                                    style: TextStyle(
                                      color: _validTill == null ? Colors.grey.shade500 : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // ACTION BUTTON / PROGRESS
                      if (_isTransferring)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
                            border: Border.all(color: Colors.grey.shade100, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _transferProgress,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF675d40)),
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _transferStatus,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF675d40), fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      else
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: (_selectedSourceUserId != null && _selectedDestUserId != null && _selectedLeadNames.isNotEmpty && (_transferType == 'Permanent' || _validTill != null)) ? 1.0 : 0.4,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: (_selectedSourceUserId != null && _selectedDestUserId != null && _selectedLeadNames.isNotEmpty && (_transferType == 'Permanent' || _validTill != null))
                                ? [BoxShadow(color: const Color(0xFF675d40).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
                                : [],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton.icon(
                                onPressed: (_selectedSourceUserId != null && _selectedDestUserId != null && _selectedLeadNames.isNotEmpty && (_transferType == 'Permanent' || _validTill != null))
                                    ? _executeTransfer
                                    : null,
                                icon: const Icon(Icons.move_up_rounded, size: 22),
                                label: const Text('Transfer Leads', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF675d40),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
    );
  }
}

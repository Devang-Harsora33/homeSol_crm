import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/project.dart';
import '../models/developer.dart';
import '../models/site_visit.dart';
import '../models/activity_log.dart';
import '../services/apis/leads/lead_service.dart';
import '../components/property_detail_popup.dart';
import '../models/property_unit.dart';
import '../services/apis/projects/property_unit_service.dart';
import 'live_inventory_matrix.dart';
import '../pages/site_visit_detail_page.dart';
import '../pages/create_site_visit_page.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import '../pages/crm/follow_up_detail_page.dart';
import '../models/follow_up.dart';
import '../pages/crm/lead_creation_page.dart';
import 'project_share_bottom_sheet.dart';

// ─── STYLING CONSTANTS ───
const kAccent = Color(0xFF675D40);
const kBackgroundColor = Color(0xFFF2F2F7);
const kCardBorderRadius = 16.0;

class LeadDetailView extends StatefulWidget {
  final Lead lead;
  const LeadDetailView({super.key, required this.lead});

  @override
  State<LeadDetailView> createState() => _LeadDetailViewState();
}

class _LeadDetailViewState extends State<LeadDetailView> {
  late Lead _currentLead;
  List<Project> _projects = [];
  List<Developer> _developers = [];
  List<SiteVisit> _siteVisits = [];
  List<SiteVisit> _filteredSiteVisits = [];
  List<FollowUp> _followUps = []; // New list for follow-ups
  List<ActivityLog> _activityLogs = []; // New list for activity logs
  List<PropertyUnit> _linkedUnits = [];
  bool _isLoading = true;
  bool _isSiteVisitsLoading = true;
  bool _isFollowUpsLoading = true; // New loading state for follow-ups
  bool _isActivityLogsLoading = true; // New loading state for activity logs
  String _lastVisitDate = 'N/A'; // New state variable for last visit date
  String? _visitDoneDate; // Added for Visit Done Date

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    _currentLead = widget.lead;
    _fetchData();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final updatedLead = await LeadService.fetchLead(_currentLead.name!);
      final projects = await ProjectService.syncProjects();
      final developers = await DeveloperService.syncDevelopers();
      final siteVisits = await SiteVisitService.fetchMySiteVisits();
      final followUps = await LeadService.fetchTeamFollowups(_currentLead.name!); 
      final activityLogs = await LeadService.fetchLeadActivityLogs(_currentLead.name!);
      final linkedUnits = await PropertyUnitService.fetchPropertyUnitsForLead(_currentLead.name!);

      if (mounted) {
        setState(() {
          if (updatedLead != null) {
            _currentLead = updatedLead;
          }
          _projects = projects;
          _developers = developers;
          _isLoading = false;

          _siteVisits = siteVisits;
          _filteredSiteVisits = _siteVisits.where((visit) => visit.lead == _currentLead.name).toList();
          
          if (_filteredSiteVisits.isNotEmpty) {
            _filteredSiteVisits.sort((a, b) {
              DateTime? dateA = a.visitScheduledDatetime != null ? DateTime.tryParse(a.visitScheduledDatetime!) : null;
              DateTime? dateB = b.visitScheduledDatetime != null ? DateTime.tryParse(b.visitScheduledDatetime!) : null;
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA); // Sort descending to get latest
            });
            final latestVisit = _filteredSiteVisits.first;
            final latestVisitDateStr = latestVisit.visitScheduledDatetime ?? latestVisit.visitDate;
            final latestVisitDate = latestVisitDateStr != null ? DateTime.tryParse(latestVisitDateStr) : null;
            
            _lastVisitDate = latestVisitDate != null ? _formatPostedDate(latestVisitDate) : 'N/A';

            if (latestVisitDate != null) {
              final threeMonthsBefore = latestVisitDate.subtract(const Duration(days: 90));
              final visitDoneVisits = _filteredSiteVisits.where((v) {
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
                final bestDate = DateTime.tryParse(visitDoneVisits.first.visitScheduledDatetime ?? visitDoneVisits.first.visitDate ?? '');
                _visitDoneDate = bestDate != null ? _formatPostedDate(bestDate) : null;
              } else {
                _visitDoneDate = null;
              }
            }
          } else {
            _lastVisitDate = 'N/A';
            _visitDoneDate = null;
          }
          _isSiteVisitsLoading = false;

          _followUps = followUps.where((followUp) => followUp.leadId == _currentLead.name).toList(); // Filter follow-ups
          _isFollowUpsLoading = false;

          _activityLogs = activityLogs;
          _isActivityLogsLoading = false;
          _linkedUnits = linkedUnits;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSiteVisitsLoading = false;
          _isFollowUpsLoading = false; // Set loading to false on error
          _isActivityLogsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Helper to safely access JSON data if your Lead model doesn't have getters yet.
    // Assuming your Lead model maps these fields. If not, you might need to update your Lead model.
    // For this example, I will use _currentLead properties assuming they exist. 
    
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Lead Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 16),
              
              // 1. Interested Project (if any)
              if (_currentLead.projectId.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    final project = _projects.firstWhere((p) => p.id == _currentLead.projectId.first);
                    final developer = _developers.firstWhere((d) => d.id == project.developer);
                    showDialog(
                      context: context,
                      builder: (context) => PropertyDetailPopup(project: project, developer: developer),
                    );
                  },
                  child: _buildProjectCard(_currentLead.projectId.first),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Linked Inventory Units
              if (_linkedUnits.isNotEmpty) ...[
                _buildLinkedUnitsPremiumSection(),
                const SizedBox(height: 16),
              ],

              // 3. Requirements & Budget
              _buildSectionCard("Requirements", [
                _infoRow(Icons.home_work_outlined, "Configuration", _currentLead.customConfiguration ?? '-'),
                _infoRow(Icons.currency_rupee, "Budget Range", "${_formatBudgetFromString(_currentLead.customBudgetMin)} - ${_formatBudgetFromString(_currentLead.customBudgetMax)}"),
                _infoRow(Icons.category_outlined, "Purpose", _currentLead.customPurposeOfPurchase ?? '-'),
                _infoRow(Icons.build_circle_outlined, "Prop Type", _currentLead.customLookingForPropertyType ?? '-'),
                _infoRow(Icons.account_balance_outlined, "Financing", _currentLead.customFinancingDetails ?? '-'),
                _infoRow(Icons.timer_outlined, "Expected Time", _currentLead.customExpectedTimeOfPurchase ?? '-'),
                _infoRow(Icons.home_filled, "Current Residence", _currentLead.customCurrentResidenceType ?? '-'),
              ]),
              const SizedBox(height: 16),

              // 4. Status & Qualification (Admin Fields)
              _buildSectionCard("Lead Status & Qualification", [
                // _infoRow(Icons.flag, "Lead Status", _currentLead.customLatestVisitStatus  ?? 'New'),
                _infoRow(Icons.flag, "Lead Status", _currentLead.customLeadStatus ?? _currentLead.status ?? 'New', isTappable: true, onTap: _editLeadStatus),
                _infoRow(Icons.stacked_bar_chart, "Lead Stages", _currentLead.customStages ?? 'N/A', isTappable: true, onTap: _editLeadStages),
                // _infoRow(Icons.verified_user_outlined, "Qualification", _currentLead.qualificationStatus ?? '-'),
                _infoRow(Icons.calendar_today, "Qualified On", _currentLead.qualifiedOn?.toString() ?? '-'),
                _infoRow(Icons.calendar_month, "Last Visit", _lastVisitDate),
                if (_visitDoneDate != null)
                  _infoRow(Icons.event_available_rounded, "Visit Done Date", _visitDoneDate!),
                const SizedBox(height: 12),
                // const Text("Flags & Services:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                // const SizedBox(height: 8),
                // Wrap(
                //   spacing: 8,
                //   runSpacing: 8,
                //   children: [
                //     if (_currentLead.isRetail == 1) _chip("Retail"),
                //     if (_currentLead.isRental == 1) _chip("Rental"),
                //     if (_currentLead.isReadyToMove == 1) _chip("Ready To Move"),
                //     if (_currentLead.reqCallingSupport == 1) _chip("Call Support", color: Colors.blue.shade100),
                //     if (_currentLead.reqDigitalKit == 1) _chip("Digital Kit", color: Colors.blue.shade100),
                //     if (_currentLead.reqSmsBlast == 1) _chip("SMS Blast", color: Colors.blue.shade100),
                //     if (_currentLead.reqWhatsappBlast == 1) _chip("WA Blast", color: Colors.blue.shade100),
                //   ],
                // )
              ]),
              const SizedBox(height: 16),

               // 5. Source & Marketing
              _buildSectionCard("Source & Marketing", [
                _infoRow(Icons.source, "Source", _currentLead.source ?? '-'),
                _infoRow(Icons.source, "Source Type", _currentLead.customSourceType ??  'N/A'),
                _infoRow(Icons.campaign, "Campaign", _currentLead.campaignName ?? '-'),
                _infoRow(Icons.request_page, "Request Type", _currentLead.requestType ?? '-'),
                // const SizedBox(height: 12),
                // Wrap(
                //   spacing: 8,
                //   runSpacing: 8,
                //   children: [
                //     if (_currentLead.isDigital == 1) _chip("Digital"),
                //     if (_currentLead.isReference == 1) _chip("Reference"),
                //     if (_currentLead.isDataCalling == 1) _chip("Data Calling"),
                //     if (_currentLead.blogSubscriber == 1) _chip("Blog Sub"),
                //   ],
                // )
              ]),
              const SizedBox(height: 16),

              // 6. Contact & Location
              _buildSectionCard("Contact & Location", [
                _infoRow(Icons.phone_android, "Mobile", _currentLead.customerPhone, isCopyable: true),
                _infoRow(Icons.chat, "WhatsApp", _currentLead.whatsappNo ?? '-'),
                if (_currentLead.phone != null && _currentLead.phone!.isNotEmpty)
                _infoRow(Icons.email_outlined, "Email", _currentLead.emailId ?? '-', isCopyable: true),
                _infoRow(Icons.email_outlined, "Channel Partner", _currentLead.customChannelPartner ?? '-', isCopyable: true),
                _infoRow(Icons.print, "Fax", _currentLead.fax ?? '-'),
                const Divider(height: 24),
                // _infoRow(Icons.location_on_outlined, "Address", "${_currentLead.city}, ${_currentLead.state}, ${_currentLead.country}"),
                _infoRow(Icons.numbers, "Postal Code", _currentLead.customPostalCode ?? '-'),
                if (_currentLead.locationCoordinates != null && _currentLead.locationCoordinates!.isNotEmpty)
                  _infoRow(Icons.map, "Location", "View on Map", isTappable: true, onTap: () => _launchMaps(_currentLead.locationCoordinates!)),
              ]),
              const SizedBox(height: 16),

              // 7. Professional Info
              _buildSectionCard("Professional Details", [
                _infoRow(Icons.business, "Company", _currentLead.companyName ?? '-'),
                _infoRow(Icons.badge_outlined, "Job Title", _currentLead.jobTitle ?? '-'),
                _infoRow(Icons.work_outline, "Occupation", _currentLead.customOccupation ?? '-'),
                _infoRow(Icons.language, "Website", _currentLead.website ?? '-'),
                // const Divider(height: 24),
                _infoRow(Icons.factory_outlined, "Industry", _currentLead.industry ?? '-'),
                // _infoRow(Icons.people_outline, "Employees", _currentLead.noOfEmployees ?? '-'),
                _infoRow(Icons.monetization_on_outlined, "Annual Revenue", _formatBudget(_currentLead.annualRevenue?.toInt() ?? 0)),
                _infoRow(Icons.pie_chart_outline, "Market Segment", _currentLead.marketSegment ?? '-'),
              ]),
              const SizedBox(height: 16),


              // New Site Visits Card
              _buildSiteVisitsCard(),
              const SizedBox(height: 16),

              // New Follow-ups Card
              _buildFollowUpsCard(),
              const SizedBox(height: 16),

              // 7. System Info
              _buildSystemInfoCard(),
              
              const SizedBox(height: 80), 
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  String _formatPostedDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';
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
      BuildContext context, Lead lead, String action) async {
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
      String formattedNumber = numbers.first.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (formattedNumber.startsWith('0')) formattedNumber = formattedNumber.substring(1);
      if (formattedNumber.length == 10) formattedNumber = '91$formattedNumber';

      final url = action == 'call'
          ? 'tel:${numbers.first}'
          : 'https://wa.me/$formattedNumber';
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
    const Color matteBlack = Color(0xFF1A1A1A);
    const Color offWhite = Color(0xFFF9F9F9);


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
                  color: kAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(headerIcon, size: 32, color: kAccent),
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
                'This lead has multiple numbers.',
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
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: kAccent,
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

  Future<void> _launchMaps(String locationCoordinates) async {
    try {
      final decoded = json.decode(locationCoordinates);
      final coordinates = decoded['features'][0]['geometry']['coordinates'];
      final lon = coordinates[0];
      final lat = coordinates[1];

      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      CustomSnackBar.show(context, message: 'Could not open map: $e', isError: false, title: 'Notice');
    }
  }

  void _showShareProjectDialog(Project project) {
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
          child: ProjectShareBottomSheet(project: project, lead: _currentLead),
        );
      },
    );
  }

  // ─── UI COMPONENTS ───

  Widget _buildSiteVisitsCard() {
    return _buildSectionCard("Site Visits", [
      if (_isSiteVisitsLoading)
        const Center(child: CircularProgressIndicator())
      else if (_filteredSiteVisits.isEmpty)
        const Text("No site visits found for this lead.")
      else
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredSiteVisits.length,
          itemBuilder: (context, index) {
            final visit = _filteredSiteVisits[index];
            Project? project = _projects.firstWhere(
              (p) => p.id == visit.project,
              orElse: () => Project(
                id: visit.project,
                projectName: visit.project, // Use the project ID as the name for fallback
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
              ),
            );
            return ListTile(
              title: Text(project.projectName ?? 'N/A'),
              subtitle: Text(visit.status ?? 'N/A'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SiteVisitDetailPage(siteVisit: visit),
                  ),
                );
              },
            );
          },
        ),
    ]);
  }

Widget _buildFollowUpsCard() {
  return _buildSectionCard("Follow-ups", [
    if (_isFollowUpsLoading)
      const Center(child: CircularProgressIndicator())
    else if (_followUps.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text("No follow-ups found for this lead."),
      )
    else
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _followUps.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) {
          final followUp = _followUps[index];
          
          // 1. Icon Selection
          IconData activityIcon;
          switch (followUp.type?.toLowerCase()) {
            case 'call': activityIcon = Icons.phone_in_talk; break;
            case 'visit': activityIcon = Icons.location_on; break;
            case 'whatsapp': activityIcon = Icons.chat_bubble_outline; break;
            case 'email': activityIcon = Icons.email_outlined; break;
            default: activityIcon = Icons.event_note;
          }

          // 2. Status Color
          Color statusColor;
          switch (followUp.status?.toLowerCase()) {
            case 'completed':
            case 'closed': // Handle potential variation
              statusColor = Colors.green.shade700;
              break;
            case 'cancelled':
            case 'canceled': // Handle spelling variation
              statusColor = Colors.red.shade700;
              break;
            case 'open':
              statusColor = Colors.blue.shade700;
              break;
            default:
              statusColor = Colors.grey.shade700; // Fallback for 'Draft' or unknown
          }
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,

            // A. ICON
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: kAccent.withOpacity(0.1),
              child: Icon(activityIcon, color: kAccent, size: 18),
            ),

            // B. TYPE
            title: Text(
              followUp.type ?? 'Activity',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),

            // C. FOLLOW-UP DATE (Prominent in subtitle)
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    followUp.followUpDate ?? 'No Date',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

            // D. STATUS
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                followUp.status ?? 'N/A',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FollowUpDetailPage(followUpName: followUp.name),
                ),
              );
              if (result == true) {
                // If FollowUpDetailPage returned true, an update occurred, refresh data
                _fetchData();
              }
            },
          );
        },
      ),
  ]);
}
  Widget _buildHeaderCard() {
    String fullName = "${_currentLead.salutation ?? ''} ${_currentLead.firstName} ${_currentLead.middleName ?? ''} ${_currentLead.lastName ?? ''}".trim();
    // remove double spaces
    fullName = fullName.replaceAll(RegExp(r'\s+'), ' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFAF9F6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kAccent.withOpacity(0.1), width: 1),
                ),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kAccent.withOpacity(0.2), width: 2),
                  boxShadow: [
                    BoxShadow(color: kAccent.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)
                  ]
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: kAccent.withOpacity(0.08),
                  child: Text(
                    (_currentLead.firstName?.isNotEmpty ?? false) ? _currentLead.firstName![0].toUpperCase() : 'L',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kAccent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            fullName.isEmpty ? 'Lead' : fullName, 
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black87), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kAccent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: kAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kAccent.withOpacity(0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    Text(
                      _currentLead.customLeadStatus ?? 'New', 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kAccent, letterSpacing: 0.5)
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (_currentLead.customLeadQuality != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: List.generate(5, (index) {
                      int numberOfStars = (_currentLead.customLeadQuality! / 0.2).round();
                      return Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: Icon(
                          index < numberOfStars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16, color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton(FontAwesomeIcons.phone, "Call", Colors.green,
                onPressed: () => _showNumberSelectionDialog(context, _currentLead, 'call')),
            const SizedBox(width: 12),
            _actionButton(FontAwesomeIcons.whatsapp, "WhatsApp", const Color(0xFF25D366),
                onPressed: () => _showNumberSelectionDialog(context, _currentLead, 'whatsapp')),
            const SizedBox(width: 12),
            _actionButton(FontAwesomeIcons.envelope, "Email", Colors.blue, onPressed: () {
              if (_currentLead.name != null) {
                LeadService.recordButtonPress(_currentLead.name!, 'Email Button');
              }
              if (_currentLead.emailId != null && _currentLead.emailId!.isNotEmpty) {
                _launchUrl('mailto:${_currentLead.emailId}');
              } else {
                CustomSnackBar.show(context, message: 'No email address available', isError: false, title: 'Notice');
              }
            }),
            const SizedBox(width: 12),
            _actionButton(FontAwesomeIcons.calendarCheck, "Visit", Colors.orange, onPressed: () async {
              if (_currentLead.name != null) {
                LeadService.recordButtonPress(_currentLead.name!, 'Site Visit Button');
              }
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateSiteVisitScreen(
                  preselectedLeadId: _currentLead.name,
                  preselectedLeadDisplayName: _currentLead.leadName, // Pass the display name
                  preselectedProjectId: _currentLead.customInterestedProject,
                )),
              );
              // Refresh data after returning from CreateSiteVisitScreen
              if (result == true) {
                _fetchData();
              }
            }),
            const SizedBox(width: 12),
            _actionButton(FontAwesomeIcons.clockRotateLeft, "Follow Up", const Color(0xFF1A1A1A), onPressed: () async {
              if (_currentLead.name != null) {
                LeadService.recordButtonPress(_currentLead.name!, 'Follow Up Button');
              }
              // Navigating to CreateSiteVisitScreen as a fallback for Follow Up creation logic
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateSiteVisitScreen( 
                  preselectedLeadId: _currentLead.name,
                )),
              );
               if (result == true) {
                _fetchData();
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(dynamic icon, String label, Color color, {VoidCallback? onPressed}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            height: 52, width: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100, width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))
              ],
            ),
            child: Center(child: FaIcon(icon, color: color, size: 22)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: kAccent, size: 18),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Container(
                  width: 4, 
                  height: 20, 
                  decoration: BoxDecoration(
                    color: kAccent, 
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: kAccent.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                title, 
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.black87, 
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {String? subText, bool isCopyable = false, bool isTappable = false, VoidCallback? onTap}) {
    if (value == '-' || value.isEmpty) return const SizedBox.shrink(); // Hide empty fields
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isTappable ? onTap : (isCopyable ? () {
          Clipboard.setData(ClipboardData(text: value));
          CustomSnackBar.show(context, message: "Copied!", isError: false, title: 'Notice');
          HapticFeedback.lightImpact();
        } : null),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isTappable||isCopyable ? 12 : 4, vertical: 8),
          decoration: (isTappable || isCopyable) ? BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isTappable ? const Color(0xFFd6b864).withOpacity(0.15) : Colors.grey.shade100,
                      isTappable ? const Color(0xFFd6b864).withOpacity(0.05) : Colors.grey.shade50,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: isTappable ? const Color(0xFFd6b864) : Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                    const SizedBox(height: 4),
                    Text(value, style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w700, 
                      color: isTappable ? const Color(0xFFd6b864) : Colors.black87,
                    )),
                    if (subText != null) 
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                      ),
                  ],
                ),
              ),
              if (isCopyable) 
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Icon(Icons.copy_rounded, size: 16, color: Colors.grey.shade400),
                ),
              if (isTappable) 
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: const Color(0xFFd6b864)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _chip(String label, {Color? color}) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  //     decoration: BoxDecoration(
  //       color: color ?? Colors.grey.shade100,
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
  //   );
  // }

  Widget _buildProjectCard(String projectId) {
    // If we have loaded projects, try to find details, else show just ID
    if (_isLoading) return const LinearProgressIndicator();
    
    // Find project details if available
    Project? project;
    try {
      project = _projects.firstWhere((p) => p.id == projectId);
    } catch (e) {
      project = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardBorderRadius),
        border: Border.all(color: kAccent.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: kAccent.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.apartment, color: kAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Interested Project", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(project?.projectName ?? projectId, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (project != null)
                IconButton(
                  icon: const Icon(Icons.share, color: kAccent),
                  onPressed: () {
                    if (_currentLead.name != null) {
                      LeadService.recordButtonPress(_currentLead.name!, 'Share Button');
                    }
                    _showShareProjectDialog(project!);
                  },
                ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("System Info", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _miniInfo("Attended By", _currentLead.customAttendedBy ?? '-'),
          _miniInfo("Sales Manager", _currentLead.customSalesManager ?? '-'),
          _miniInfo("Lead Owner", _currentLead.leadOwner ?? '-'),
          _miniInfo("ID", _currentLead.name ?? ''), // The unique ID
          _miniInfo("Created", _currentLead.createdAt?.toString() ?? '-'),
          _miniInfo("Last Modified", _currentLead.modified?.toString() ?? '-'),
          if (_isActivityLogsLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: SizedBox(height: 2, child: LinearProgressIndicator()),
            )
          else if (_activityLogs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1, color: Colors.black12),
            ),
            Text("Activity Logs", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            ..._activityLogs.map((log) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.message ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text("${log.user} • ${log.timestamp}", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _miniInfo(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text("$k: ", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          // Show delete button only if lead status is not 'Do Not Contact'
          if (_currentLead.status != 'Do Not Contact')
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showDeleteConfirmation(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Delete'),
              ),
            ),
          if (_currentLead.status != 'Do Not Contact')
            const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LeadCreationPage(lead: _currentLead)),
                );
                if (result == true) {
                  _fetchData(); // Refresh lead details after editing
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Edit Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UTILS ───
  Widget _buildLinkedUnitsPremiumSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.key, size: 16, color: kAccent),
              ),
              const SizedBox(width: 10),
              const Text(
                'Linked Inventory Units',
                style: TextStyle(
                  fontWeight: FontWeight.w800, 
                  fontSize: 16,
                  color: Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._linkedUnits.map((u) => _buildPremiumUnitCard(u)).toList(),
      ],
    );
  }

  Widget _buildPremiumUnitCard(PropertyUnit unit) {
    Color statusBgColor;
    Color statusTextColor;
    if (unit.unitStatus == 'Sold') {
      statusBgColor = const Color(0xFFFFF0F0);
      statusTextColor = const Color(0xFFE53935);
    } else if (unit.unitStatus == 'Hold') {
      statusBgColor = const Color(0xFFFFF8E1);
      statusTextColor = const Color(0xFFFF8F00);
    } else {
      statusBgColor = const Color(0xFFE8F5E9);
      statusTextColor = const Color(0xFF43A047);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          highlightColor: kAccent.withOpacity(0.03),
          splashColor: kAccent.withOpacity(0.06),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) {
                return UnitDetailsBottomSheet(
                  unit: unit,
                  onStatusUpdated: () {
                    _fetchData(); 
                  },
                );
              },
            );
          },
          child: Stack(
            children: [
              // Subtle background decoration
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.apartment,
                  size: 100,
                  color: Colors.grey.shade50.withOpacity(0.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Glassmorphic / Gradient Icon
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF7F5F0), // Ultra light base
                            kAccent.withOpacity(0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.meeting_room_rounded, color: kAccent, size: 26),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Main Unit Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Unit ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                unit.flatNo,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.layers_outlined, size: 12, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Floor ${unit.floorNumber}',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  unit.configuration,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Status and Action
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusTextColor.withOpacity(0.15), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusTextColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusTextColor.withOpacity(0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                unit.unitStatus,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusTextColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_outlined, size: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editLeadStatus() {
    final statuses = ['Open', 'Prospect', 'Won', 'Lost'];
    _showSelectionDialog('Edit Lead Status', statuses, _currentLead.customLeadStatus ?? 'Open', (newVal) async {
      final updates = {
        'custom_lead_status': newVal,
        'custom_stages': null, // Reset stage
        'status': newVal == 'Lost' ? 'Do Not Contact' : 'Lead',
      };
      await _saveLeadUpdate(updates);
    });
  }

  void _editLeadStages() {
    final currentStatus = _currentLead.customLeadStatus ?? _currentLead.status;
    final stages = _getStagesForStatus(currentStatus);
    if (stages.isEmpty) {
      CustomSnackBar.show(context, message: 'No stages available for current status.', isError: false, title: 'Notice');
      return;
    }
    _showSelectionDialog('Edit Lead Stage', stages, _currentLead.customStages ?? '', (newVal) async {
      await _saveLeadUpdate({'custom_stages': newVal});
    });
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

  void _showSelectionDialog(String title, List<String> options, String currentValue, Function(String) onSave) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected = opt == currentValue;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      title: Text(
                        opt,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? kAccent : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: kAccent)
                          : const Icon(Icons.circle_outlined, color: Colors.black12),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        if (!isSelected) {
                          onSave(opt);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveLeadUpdate(Map<String, dynamic> updates) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kAccent)),
    );
    try {
      await LeadService.updateLead(_currentLead.name!, updates);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        CustomSnackBar.show(context, message: 'Lead updated successfully!', isError: false, title: 'Notice');
        _fetchData(); // Refresh lead details
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        CustomSnackBar.show(context, message: 'Failed to update lead: $e', isError: true, title: 'Error');
      }
    }
  }

  String _formatBudget(num budget) {
    if (budget <= 0) return '-';
    if (budget >= 10000000) {
      double cr = budget / 10000000;
      return "₹${cr.toStringAsFixed(cr.truncate() == cr ? 0 : 2)}Cr";
    } else if (budget >= 100000) {
      double lk = budget / 100000;
      return "₹${lk.toStringAsFixed(lk.truncate() == lk ? 0 : 2)}L";
    }
    return "₹$budget";
  }

  String _formatBudgetFromString(String? budgetString) {
    if (budgetString == null || budgetString.isEmpty) return '-';
    return "₹${budgetString}Cr";
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
  context: context,
  builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    title: const Column(
      children: [
        FaIcon(
          FontAwesomeIcons.triangleExclamation,
          // Changed to a matte red (Material Red 700)
          color: Color(0xFFD32F2F), 
          size: 50,
        ),
        SizedBox(height: 16),
        Text(
          'Mark Lead as Lost?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    ),
    content: const Text(
      'This will mark the lead as Lost.\nYou can still view it in your leads list.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF757575),
        fontSize: 15,
      ),
    ),
    actionsAlignment: MainAxisAlignment.center,
    actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF757575),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      
      const SizedBox(width: 8),
      
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _markLeadAsLost(context);
        },
        style: ElevatedButton.styleFrom(
          // Same matte red for the button background
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('Mark as Lost'),
      ),
    ],
  ),
);
  }

  Future<void> _markLeadAsLost(BuildContext context) async {
    try {
      final marked = await LeadService.markLeadAsLost(_currentLead.name!);
      if (marked) {
        if (context.mounted) {
          CustomSnackBar.show(context, message: 'Lead marked as Lost successfully!', isError: false, title: 'Notice');
          // Delay the pop to allow snackbar to show
          await Future.delayed(const Duration(milliseconds: 500));
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        }
      } else {
        if (context.mounted) {
          CustomSnackBar.show(context, message: 'Failed to mark lead as Lost. Please try again.', isError: true, title: 'Error');
        }
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.show(context, message: 'Error marking lead as Lost: $e', isError: true, title: 'Error');
      }
      print('Error marking lead as Lost: $e');
    }
  }
}
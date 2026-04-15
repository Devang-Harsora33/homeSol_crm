import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/project.dart';
import '../models/developer.dart';
import '../models/site_visit.dart';
import '../models/activity_log.dart';
import '../services/apis/leads/lead_service.dart';
import '../components/property_detail_popup.dart';
import '../pages/site_visit_detail_page.dart';
import '../pages/create_site_visit_page.dart'; 
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
import '../pages/crm/lead_creation_page.dart'; 
import '../pages/crm/follow_up_detail_page.dart';
import '../models/follow_up.dart';
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
  List<Project> _projects = [];
  List<Developer> _developers = [];
  List<SiteVisit> _siteVisits = [];
  List<SiteVisit> _filteredSiteVisits = [];
  List<FollowUp> _followUps = []; // New list for follow-ups
  List<ActivityLog> _activityLogs = []; // New list for activity logs
  bool _isLoading = true;
  bool _isSiteVisitsLoading = true;
  bool _isFollowUpsLoading = true; // New loading state for follow-ups
  bool _isActivityLogsLoading = true; // New loading state for activity logs
  String _lastVisitDate = 'N/A'; // New state variable for last visit date
  String? _visitDoneDate; // Added for Visit Done Date

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final projects = await ProjectService.syncProjects();
      final developers = await DeveloperService.syncDevelopers();
      final siteVisits = await SiteVisitService.fetchMySiteVisits();
      final followUps = await LeadService.fetchTeamFollowups(widget.lead.name!); 
      final activityLogs = await LeadService.fetchLeadActivityLogs(widget.lead.name!);

      if (mounted) {
        setState(() {
          _projects = projects;
          _developers = developers;
          _isLoading = false;

          _siteVisits = siteVisits;
          _filteredSiteVisits = _siteVisits.where((visit) => visit.lead == widget.lead.name).toList();
          
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

          _followUps = followUps.where((followUp) => followUp.leadId == widget.lead.name).toList(); // Filter follow-ups
          _isFollowUpsLoading = false;

          _activityLogs = activityLogs;
          _isActivityLogsLoading = false;
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
    // For this example, I will use widget.lead properties assuming they exist. 
    
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
              
              // 1. Contact & Location
              _buildSectionCard("Contact & Location", [
                _infoRow(Icons.phone_android, "Mobile", widget.lead.customerPhone, isCopyable: true),
                _infoRow(Icons.chat, "WhatsApp", widget.lead.whatsappNo ?? '-'),
                if (widget.lead.phone != null && widget.lead.phone!.isNotEmpty)
                _infoRow(Icons.email_outlined, "Email", widget.lead.emailId ?? '-', isCopyable: true),
                _infoRow(Icons.email_outlined, "Channel Partner", widget.lead.customChannelPartner ?? '-', isCopyable: true),
                _infoRow(Icons.print, "Fax", widget.lead.fax ?? '-'),
                const Divider(height: 24),
                // _infoRow(Icons.location_on_outlined, "Address", "${widget.lead.city}, ${widget.lead.state}, ${widget.lead.country}"),
                _infoRow(Icons.numbers, "Postal Code", widget.lead.customPostalCode ?? '-'),
                if (widget.lead.locationCoordinates != null && widget.lead.locationCoordinates!.isNotEmpty)
                  _infoRow(Icons.map, "Location", "View on Map", isTappable: true, onTap: () => _launchMaps(widget.lead.locationCoordinates!)),
              ]),
              const SizedBox(height: 16),

              // 2. Professional Info
              _buildSectionCard("Professional Details", [
                _infoRow(Icons.business, "Company", widget.lead.companyName ?? '-'),
                _infoRow(Icons.badge_outlined, "Job Title", widget.lead.jobTitle ?? '-'),
                _infoRow(Icons.work_outline, "Occupation", widget.lead.customOccupation ?? '-'),
                _infoRow(Icons.language, "Website", widget.lead.website ?? '-'),
                // const Divider(height: 24),
                _infoRow(Icons.factory_outlined, "Industry", widget.lead.industry ?? '-'),
                // _infoRow(Icons.people_outline, "Employees", widget.lead.noOfEmployees ?? '-'),
                _infoRow(Icons.monetization_on_outlined, "Annual Revenue", _formatBudget(widget.lead.annualRevenue?.toInt() ?? 0)),
                _infoRow(Icons.pie_chart_outline, "Market Segment", widget.lead.marketSegment ?? '-'),
              ]),
              const SizedBox(height: 16),

              // 3. Requirements & Budget
              _buildSectionCard("Requirements", [
                _infoRow(Icons.home_work_outlined, "Configuration", widget.lead.customConfiguration ?? '-'),
                _infoRow(Icons.currency_rupee, "Budget Range", "${_formatBudgetFromString(widget.lead.customBudgetMin)} - ${_formatBudgetFromString(widget.lead.customBudgetMax)}"),
                _infoRow(Icons.category_outlined, "Purpose", widget.lead.customPurposeOfPurchase ?? '-'),
                _infoRow(Icons.build_circle_outlined, "Prop Type", widget.lead.customLookingForPropertyType ?? '-'),
                _infoRow(Icons.account_balance_outlined, "Financing", widget.lead.customFinancingDetails ?? '-'),
                _infoRow(Icons.timer_outlined, "Expected Time", widget.lead.customExpectedTimeOfPurchase ?? '-'),
                _infoRow(Icons.home_filled, "Current Residence", widget.lead.customCurrentResidenceType ?? '-'),
              ]),
              const SizedBox(height: 16),

              // 4. Interested Project (if any)
              if (widget.lead.projectId.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    final project = _projects.firstWhere((p) => p.id == widget.lead.projectId.first);
                    final developer = _developers.firstWhere((d) => d.id == project.developer);
                    showDialog(
                      context: context,
                      builder: (context) => PropertyDetailPopup(project: project, developer: developer),
                    );
                  },
                  child: _buildProjectCard(widget.lead.projectId.first),
                ),
                const SizedBox(height: 16),
              ],

              // 5. Source & Marketing
              _buildSectionCard("Source & Marketing", [
                _infoRow(Icons.source, "Source", widget.lead.source ?? '-'),
                _infoRow(Icons.campaign, "Campaign", widget.lead.campaignName ?? '-'),
                _infoRow(Icons.request_page, "Request Type", widget.lead.requestType ?? '-'),
                // const SizedBox(height: 12),
                // Wrap(
                //   spacing: 8,
                //   runSpacing: 8,
                //   children: [
                //     if (widget.lead.isDigital == 1) _chip("Digital"),
                //     if (widget.lead.isReference == 1) _chip("Reference"),
                //     if (widget.lead.isDataCalling == 1) _chip("Data Calling"),
                //     if (widget.lead.blogSubscriber == 1) _chip("Blog Sub"),
                //   ],
                // )
              ]),
              const SizedBox(height: 16),

              // 6. Status & Qualification (Admin Fields)
              _buildSectionCard("Lead Status & Qualification", [
                // _infoRow(Icons.flag, "Lead Status", widget.lead.customLatestVisitStatus  ?? 'New'),
                _infoRow(Icons.flag, "Lead Status", widget.lead.customLeadStatus ?? widget.lead.status ?? 'New'),
                _infoRow(Icons.stacked_bar_chart, "Lead Status", widget.lead.customStages ?? 'N/A'),
                _infoRow(Icons.source, "Source", widget.lead.source ??  'N/A'),
                // _infoRow(Icons.verified_user_outlined, "Qualification", widget.lead.qualificationStatus ?? '-'),
                _infoRow(Icons.calendar_today, "Qualified On", widget.lead.qualifiedOn?.toString() ?? '-'),
                _infoRow(Icons.calendar_month, "Last Visit", _lastVisitDate),
                if (_visitDoneDate != null)
                  _infoRow(Icons.event_available_rounded, "Visit Done Date", _visitDoneDate!),
                const Divider(height: 24),
                _infoRow(Icons.admin_panel_settings_outlined, "Attended By", widget.lead.customAttendedBy ?? '-'),
                _infoRow(Icons.supervisor_account_outlined, "Sales Manager", widget.lead.customSalesManager ?? '-'),
                _infoRow(Icons.person_outline, "Lead Owner", widget.lead.leadOwner ?? '-'),
                const SizedBox(height: 12),
                // const Text("Flags & Services:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                // const SizedBox(height: 8),
                // Wrap(
                //   spacing: 8,
                //   runSpacing: 8,
                //   children: [
                //     if (widget.lead.isRetail == 1) _chip("Retail"),
                //     if (widget.lead.isRental == 1) _chip("Rental"),
                //     if (widget.lead.isReadyToMove == 1) _chip("Ready To Move"),
                //     if (widget.lead.reqCallingSupport == 1) _chip("Call Support", color: Colors.blue.shade100),
                //     if (widget.lead.reqDigitalKit == 1) _chip("Digital Kit", color: Colors.blue.shade100),
                //     if (widget.lead.reqSmsBlast == 1) _chip("SMS Blast", color: Colors.blue.shade100),
                //     if (widget.lead.reqWhatsappBlast == 1) _chip("WA Blast", color: Colors.blue.shade100),
                //   ],
                // )
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
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open map: $e')));
    }
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
    String fullName = "${widget.lead.salutation ?? ''} ${widget.lead.firstName} ${widget.lead.middleName ?? ''} ${widget.lead.lastName ?? ''}".trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardBorderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: kAccent.withOpacity(0.1),
            child: Text(
              (widget.lead.firstName?.isNotEmpty ?? false) ? widget.lead.firstName![0].toUpperCase() : 'L',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kAccent),
            ),
          ),
          const SizedBox(height: 12),
          Text(fullName.isEmpty ? 'Lead' : fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(widget.lead.customLeadStatus ?? 'New', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kAccent)),
              ),
              const SizedBox(width: 8),
              if (widget.lead.customLeadQuality != null)
                Row(
                  children: List.generate(5, (index) {
                    int numberOfStars = (widget.lead.customLeadQuality! / 0.2).round();
                    return Icon(
                      index < numberOfStars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16, color: Colors.amber,
                    );
                  }),
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionButton(FontAwesomeIcons.phone, "Call", Colors.green,
            onPressed: () => _showNumberSelectionDialog(context, widget.lead, 'call')),
        _actionButton(FontAwesomeIcons.whatsapp, "WhatsApp", const Color(0xFF25D366),
            onPressed: () => _showNumberSelectionDialog(context, widget.lead, 'whatsapp')),
        _actionButton(FontAwesomeIcons.envelope, "Email", Colors.blue),
        _actionButton(FontAwesomeIcons.calendarCheck, "Visit", Colors.orange, onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateSiteVisitScreen(
              preselectedLeadId: widget.lead.name,
              preselectedLeadDisplayName: widget.lead.leadName, // Pass the display name
              preselectedProjectId: widget.lead.customInterestedProject,
            )),
          );
          // Refresh data after returning from CreateSiteVisitScreen
          if (result == true) {
            _fetchData();
          }
        }),
      ],
    );
  }

  Widget _actionButton(dynamic icon, String label, Color color, {VoidCallback? onPressed}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            height: 48, width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Center(child: FaIcon(icon, color: color, size: 22)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardBorderRadius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {String? subText, bool isCopyable = false, bool isTappable = false, VoidCallback? onTap}) {
    if (value == '-' || value.isEmpty) return const SizedBox.shrink(); // Hide empty fields
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: isTappable ? onTap : (isCopyable ? () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!"), duration: Duration(milliseconds: 600)));
          HapticFeedback.lightImpact();
        } : null),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isTappable ? Colors.blue : null)),
                  if (subText != null) 
                    Text(subText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                ],
              ),
            ),
            if (isCopyable) Icon(Icons.copy, size: 14, color: Colors.grey.shade300),
            if (isTappable) Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
          ],
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
          _miniInfo("ID", widget.lead.name ?? ''), // The unique ID
          _miniInfo("Created", widget.lead.createdAt?.toString() ?? '-'),
          _miniInfo("Last Modified", widget.lead.modified?.toString() ?? '-'),
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
          if (widget.lead.status != 'Do Not Contact')
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
          if (widget.lead.status != 'Do Not Contact')
            const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LeadCreationPage(lead: widget.lead)),
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
      final marked = await LeadService.markLeadAsLost(widget.lead.name!);
      if (marked) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead marked as Lost successfully!')),
          );
          // Delay the pop to allow snackbar to show
          await Future.delayed(const Duration(milliseconds: 500));
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to mark lead as Lost. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking lead as Lost: $e')),
        );
      }
      print('Error marking lead as Lost: $e');
    }
  }
}
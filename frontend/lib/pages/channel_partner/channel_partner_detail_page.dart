import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/channel_partner.dart';
import '../../models/lead.dart' as model_lead;
import '../../models/project.dart';
import '../../services/auth_service.dart';
import '../../components/project_share_bottom_sheet.dart';

const kAccent = Color(0xFF675D40);
const kBackgroundColor = Color(0xFFF2F2F7);
const kCardBorderRadius = 16.0;

class ChannelPartnerDetailPage extends StatefulWidget {
  final String partnerId;

  const ChannelPartnerDetailPage({super.key, required this.partnerId});

  @override
  State<ChannelPartnerDetailPage> createState() => _ChannelPartnerDetailPageState();
}

class _ChannelPartnerDetailPageState extends State<ChannelPartnerDetailPage> {
  ChannelPartner? _partner;
  List<model_lead.Lead> _connectedLeads = [];
  List<Map<String, dynamic>> _siteVisits = [];
  List<Project> _projects = [];
  Map<String, String> _projectNames = {};
  Map<String, int> _projectLeadCounts = {};
  Map<String, int> _projectSiteVisitCounts = {};
  bool _isLoading = true;
  String? _errorMessage;
  int _siteVisitsLimit = 5;

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    _fetchPartnerDetails();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  Future<void> _fetchPartnerDetails({bool forceRefreshPartner = false, bool refreshLeadsAndProjects = true}) async {
    try {
      final partner = await ChannelPartnerService.fetchChannelPartner(widget.partnerId, forceRefresh: forceRefreshPartner);
      
      if (refreshLeadsAndProjects) {
        final leads = await LeadService.getLeadsByChannelPartner(widget.partnerId);
        final projects = await ProjectService.fetchProjects();
        final globalSiteVisits = await SiteVisitService.fetchSiteVisits();
        final partnerSiteVisits = await ChannelPartnerService.fetchSiteVisitsByChannelPartner(widget.partnerId);
        
        final projectMap = <String, String>{};
        for (var project in projects) {
          projectMap[project.id] = project.projectName;
        }

        // Calculate Lead Counts per Project
        final leadCounts = <String, int>{};
        for (var lead in leads) {
          final projectId = lead.customInterestedProject ?? 'No Project';
          leadCounts[projectId] = (leadCounts[projectId] ?? 0) + 1;
        }

        // Calculate Site Visit Counts per Project for this Partner's leads
        final siteVisitCounts = <String, int>{};
        final leadIds = leads.map((l) => l.name).toSet();
        for (var visit in globalSiteVisits) {
          if (leadIds.contains(visit.lead)) {
            final projectId = visit.project;
            siteVisitCounts[projectId] = (siteVisitCounts[projectId] ?? 0) + 1;
          }
        }

        setState(() {
          _partner = partner;
          _connectedLeads = leads;
          _siteVisits = partnerSiteVisits;
          _projects = projects;
          _projectNames = projectMap;
          _projectLeadCounts = leadCounts;
          _projectSiteVisitCounts = siteVisitCounts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _partner = partner;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Partner Overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
        centerTitle: true,
        backgroundColor: kBackgroundColor,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _buildBody(),
    );
  }

  Future<void> _refreshData() async {
    try {
      // Sync Leads and Site Visits as requested
      await LeadService.syncMyLeads();
      await SiteVisitService.fetchMySiteVisits(forceRefresh: true);
      await _fetchPartnerDetails(forceRefreshPartner: true);
    } catch (e) {
      CustomSnackBar.show(context, message: 'Error refreshing data: $e', isError: true, title: 'Error');
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
            ),
            const SizedBox(height: 16),
            Text('Error: $_errorMessage', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPartnerDetails,
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_partner == null) {
      return const Center(child: Text('Partner not found.', style: TextStyle(fontWeight: FontWeight.w500)));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: kAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroProfile(),
            const SizedBox(height: 20),
            
            _buildGridDetails(),
            const SizedBox(height: 16),
            _buildMarketingAndDataSection(),
            const SizedBox(height: 16),
            if (_partner!.fullAddress != null && _partner!.fullAddress!.isNotEmpty)
              ...[
                _buildAddressCard(),
                const SizedBox(height: 16),
              ],
            _buildSectionCard("Project Breakdown", Icons.pie_chart_rounded, [_buildProjectBreakdown()]),
            const SizedBox(height: 16),
            _buildSectionCard("Connected Leads", Icons.people_alt_rounded, [
              if (_connectedLeads.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text("No leads connected with this partner", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
                )
              else
                ..._connectedLeads.map((lead) => _buildLeadCard(lead)).toList()
            ]),
            const SizedBox(height: 16),
            _buildSectionCard("Site Visits", Icons.location_on_rounded, [
              if (_siteVisits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text("No site visits found for this partner", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
                )
              else ...[
                ..._siteVisits.take(_siteVisitsLimit).map((visit) => _buildPartnerSiteVisitCard(visit)).toList(),
                if (_siteVisits.length > _siteVisitsLimit)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _siteVisitsLimit += 5),
                      icon: const Icon(Icons.expand_more_rounded, color: kAccent),
                      label: const Text('See More', style: TextStyle(color: kAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]
            ]),
            const SizedBox(height: 16),
            _buildSectionCard("Station Preferences", Icons.train_rounded, [_buildStationPreferences()]),
            const SizedBox(height: 16),
            _buildSectionCard(
              "Team Members", 
              Icons.groups_rounded, 
              [
                if (_partner!.contactPersons == null || _partner!.contactPersons!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: Text("No team members added yet", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
                  )
                else
                  ..._partner!.contactPersons!.map((p) => _buildContactPersonCard(p)).toList()
              ],
              trailing: GestureDetector(
                onTap: () => _showContactPersonForm(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: kAccent, size: 16),
                      SizedBox(width: 4),
                      Text('Add', style: TextStyle(color: kAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard("Documents", Icons.folder_open_rounded, [
              if (_partner!.documents == null || _partner!.documents!.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: Text("No documents available", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
                )
              else
                ..._partner!.documents!.map((d) => _buildDocumentCard(d)).toList()
            ]),
            const SizedBox(height: 16),
            _buildSectionCard("Flags & Requirements", Icons.turned_in_not_rounded, [_buildFlags()]),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketingAndDataSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.campaign_rounded, size: 18, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              const Text("Marketing & Support", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchTile(
            "Digital Marketing", 
            "Is Digital Marketing Done by CP?", 
            Icons.ads_click_rounded, 
            _partner!.doesDigitalmarketing == 1,
            Colors.purple
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildSwitchTile(
            "AOP Signed", 
            "Has the AOP been officially signed?", 
            Icons.verified_user_rounded, 
            _partner!.aopSigned == 1,
            Colors.green
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildSwitchTile(
            "Calling Data", 
            "Does the CP provide calling data?", 
            Icons.contact_phone_rounded, 
            _partner!.givesCallingdata == 1,
            Colors.orange
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool isActive, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroProfile() {
    // Priority Badge Logic
    Widget? priorityBadge;
    if (_partner!.type != null) {
      String label = "";
      Gradient badgeGradient;
      Color textColor = Colors.white;
      IconData badgeIcon;
      Color borderColor;
      
      switch (_partner!.type!.toUpperCase()) {
        case 'P1':
          label = "GOLD";
          badgeGradient = const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFDB931), Color(0xFFDAA520)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          textColor = const Color(0xFF5C4033); // Dark bronze/brown for contrast on gold
          badgeIcon = Icons.workspace_premium_rounded;
          borderColor = const Color(0xFFB8860B).withOpacity(0.5);
          break;
        case 'P2':
          label = "SILVER";
          badgeGradient = const LinearGradient(
            colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          textColor = const Color(0xFF333333);
          badgeIcon = Icons.stars_rounded;
          borderColor = const Color(0xFF757575).withOpacity(0.5);
          break;
        case 'P3':
          label = "BRONZE";
          badgeGradient = const LinearGradient(
            colors: [Color(0xFFCD7F32), Color(0xFFB87333), Color(0xFF8B4513)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          textColor = Colors.white;
          badgeIcon = Icons.military_tech_rounded;
          borderColor = const Color(0xFF5D4037).withOpacity(0.5);
          break;
        default:
          label = "";
          badgeGradient = const LinearGradient(colors: [Colors.grey, Colors.grey]);
          badgeIcon = Icons.badge;
          borderColor = Colors.transparent;
      }

      if (label.isNotEmpty) {
        priorityBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: badgeGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: (badgeGradient.colors[0]).withOpacity(0.4), 
                blurRadius: 10, 
                offset: const Offset(0, 4)
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 12, color: textColor),
              const SizedBox(width: 4),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.w900, 
                  color: textColor, 
                  letterSpacing: 0.8,
                  shadows: [
                    if (textColor == Colors.white)
                      Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 2, offset: const Offset(0, 1))
                  ]
                ),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Premium dark background
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.white,
                  child: Text(
                    (_partner!.firmName?.isNotEmpty ?? false) ? _partner!.firmName![0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kAccent),
                  ),
                ),
              ),
              if (priorityBadge != null)
                Transform.translate(
                  offset: const Offset(10, 5),
                  child: priorityBadge,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _partner!.firmName ?? 'N/A', 
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 12),
          
          // Quality Ratings
          if (_partner!.cpQuality != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                // Quality is 0 to 1, or 1 to 5? LeadDetailView assumes 0 to 1 scale.
                // Assuming cpQuality is 0.0 to 1.0 based on LeadDetailView: 
                // int numberOfStars = (_currentLead.customLeadQuality! / 0.2).round();
                // But typically ratings are 1-5. Let's handle both.
                int numberOfStars;
                if (_partner!.cpQuality! <= 1.0) {
                  numberOfStars = (_partner!.cpQuality! / 0.2).round();
                } else {
                  numberOfStars = _partner!.cpQuality!.round();
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    index < numberOfStars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18, 
                    color: Colors.amber,
                  ),
                );
              }),
            ),
          
          const SizedBox(height: 12),
          if (_partner!.email != null && _partner!.email!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(_partner!.email!, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _heroActionButton(FontAwesomeIcons.phone, "Call", Colors.blue, onPressed: () {
                if (_partner!.name != null) ChannelPartnerService.recordButtonPress(_partner!.name!, 'Call Button');
                if (_partner!.mobileNumber != null) _launchUrl('tel:${_partner!.mobileNumber}');
              }),
              _heroActionButton(FontAwesomeIcons.whatsapp, "WhatsApp", const Color(0xFF25D366), onPressed: () {
                if (_partner!.name != null) ChannelPartnerService.recordButtonPress(_partner!.name!, 'WhatsApp Button');
                if (_partner!.mobileNumber != null) _launchUrl('https://wa.me/${_partner!.mobileNumber}');
              }),
              _heroActionButton(Icons.share_rounded, "Share", Colors.amber.shade700, onPressed: () {
                _showShareProjectPicker();
              }),
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget _heroActionButton(dynamic icon, String label, Color color, {required VoidCallback onPressed}) {
    bool isFontAwesome = false;
    try {
      isFontAwesome = icon.fontFamily?.startsWith('FontAwesome') ?? false;
    } catch (_) {
      isFontAwesome = icon.toString().contains('FontAwesome');
    }

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: isFontAwesome 
              ? FaIcon(icon as dynamic, color: Colors.white, size: 18)
              : Icon(icon as IconData, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showShareProjectPicker() {
    // 1. Get relevant project IDs from the breakdown data
    final relevantProjectIds = {..._projectLeadCounts.keys, ..._projectSiteVisitCounts.keys}.toList();
    relevantProjectIds.removeWhere((id) => id.isEmpty || id == 'null');

    // 2. Filter the projects list to only include these relevant projects
    final relevantProjects = _projects.where((p) => relevantProjectIds.contains(p.id)).toList();

    if (relevantProjects.isEmpty) {
      CustomSnackBar.show(context, message: 'No projects associated with this partner to share.', isError: false, title: 'Notice');
      return;
    }

    // 3. If there is only one relevant project, bypass the picker and share it directly
    if (relevantProjects.length == 1) {
      _shareProject(relevantProjects.first);
      return;
    }

    // 4. Otherwise, show the picker with only relevant projects
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select Project to Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: relevantProjects.length,
                itemBuilder: (context, index) {
                  final project = relevantProjects[index];
                  return ListTile(
                    leading: const Icon(Icons.business, color: kAccent),
                    title: Text(project.projectName),
                    subtitle: Text(project.locationName),
                    onTap: () {
                      Navigator.pop(context);
                      _shareProject(project);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  void _shareProject(Project project) {
    if (_partner!.name != null) {
      ChannelPartnerService.recordButtonPress(_partner!.name!, 'Share Button');
    }

    final tempLead = model_lead.Lead(
      name: _partner!.name ?? '',
      leadName: _partner!.firmName ?? 'N/A',
      customerName: _partner!.firmName ?? 'N/A',
      customerPhone: _partner!.mobileNumber ?? '',
      whatsappNo: _partner!.mobileNumber ?? '',
      projectId: [project.id],
      brokerId: '',
      status: 'Open',
      budget: 0,
    );

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
          child: ProjectShareBottomSheet(project: project, lead: tempLead),
        );
      },
    );
  }

  Widget _buildGridDetails() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDetailTile(Icons.phone_iphone_rounded, "Mobile", _partner!.mobileNumber)),
            const SizedBox(width: 12),
            Expanded(child: _buildDetailTile(Icons.category_rounded, "Category", _partner!.category)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDetailTile(Icons.map_rounded, "Territory", _partner!.territory)),
            const SizedBox(width: 12),
            Expanded(child: _buildDetailTile(Icons.verified_rounded, "RERA No.", _partner!.reraNumber)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDetailTile(Icons.label_important_rounded, "Type", _partner!.type)),
            const SizedBox(width: 12),
            Expanded(child: _buildDetailTile(Icons.business_center_rounded, "Firm Type", _partner!.category)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDetailTile(Icons.home_work_rounded, "Property Preferences", _partner!.propertyPreferences),
      ],
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String? value) {
    bool isPropertyPreference = label == "Property Preferences";
    List<String> prefs = [];
    if (isPropertyPreference && value != null && value.isNotEmpty) {
      prefs = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: kAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPropertyPreference && prefs.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  prefs.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kAccent.withOpacity(0.1)),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kAccent,
                        ),
                      ),
                    );
                  }).toList(),
            )
          else
            Text(
              value?.isNotEmpty == true ? value! : 'N/A',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              maxLines: isPropertyPreference ? 5 : 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on_rounded, color: Colors.blue.shade600, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registered Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  _partner!.fullAddress!,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children, {Widget? trailing}) {
    if (children.isEmpty && trailing == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)),
                    child: Icon(icon, size: 18, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.3)),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLeadCard(model_lead.Lead lead) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue.shade50,
          child: Text(
            lead.customerName.isNotEmpty ? lead.customerName[0].toUpperCase() : 'L',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
          ),
        ),
        title: Text(lead.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Icon(Icons.business_rounded, size: 13, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _projectNames[lead.customInterestedProject] ?? lead.customInterestedProject ?? 'No project',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: _buildLeadStatusBadge(lead.customLeadStatus),
      ),
    );
  }

  Widget _buildPartnerSiteVisitCard(Map<String, dynamic> visit) {
    final status = visit['status']?.toString() ?? 'Scheduled';
    final visitDateStr = visit['visit_date']?.toString();
    final visitDate = visitDateStr != null ? DateTime.tryParse(visitDateStr) : null;
    final projectName = _projectNames[visit['project']] ?? visit['project'] ?? 'No Project';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    projectName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildVisitStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Lead: ${visit['lead']}",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  visitDate != null ? DateFormat('dd MMM yyyy, hh:mm a').format(visitDate) : 'No Date',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (visit['remark'] != null && visit['remark'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      visit['remark'].toString(),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisitStatusBadge(String status) {
    final normalizedStatus = status.toLowerCase();
    Color baseColor = Colors.grey.shade600;
    IconData iconData = Icons.help_outline_rounded;

    if (normalizedStatus == 'scheduled') {
      baseColor = Colors.blue.shade700;
      iconData = Icons.schedule_rounded;
    } else if (normalizedStatus == 'completed' || normalizedStatus == 'visit done' || normalizedStatus == 'revisit done') {
      baseColor = Colors.green.shade700;
      iconData = Icons.check_circle_rounded;
    } else if (normalizedStatus == 'rescheduled') {
      baseColor = Colors.orange.shade800;
      iconData = Icons.event_repeat_rounded;
    } else if (normalizedStatus == 'cancelled' || normalizedStatus == 'canceled') {
      baseColor = Colors.red.shade700;
      iconData = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: baseColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: baseColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadStatusBadge(String? status) {
    final statusText = status ?? 'Open';
    final normalizedStatus = statusText.toLowerCase();

    Color baseColor = Colors.grey.shade600;
    IconData iconData = Icons.help_outline_rounded;

    if (normalizedStatus == 'open') {
      baseColor = Colors.blue.shade700;
      iconData = Icons.radio_button_checked_rounded;
    } else if (normalizedStatus == 'prospect') {
      baseColor = Colors.orange.shade800;
      iconData = Icons.person_search_rounded;
    } else if (normalizedStatus == 'won') {
      baseColor = Colors.green.shade700;
      iconData = Icons.check_circle_rounded;
    } else if (normalizedStatus == 'lost') {
      baseColor = Colors.red.shade700;
      iconData = Icons.cancel_rounded;
    } else if (normalizedStatus.contains('interested')) {
      baseColor = Colors.blue.shade700;
      iconData = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 14, color: baseColor),
          const SizedBox(width: 6),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              color: baseColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showContactPersonForm([ContactPerson? person]) {
    final isEditing = person != null;
    final fullNameController = TextEditingController(text: person?.fullName);
    final roleController = TextEditingController(text: person?.roles ?? 'Sales');
    final mobileController = TextEditingController(text: person?.mobile);
    final emailController = TextEditingController(text: person?.email);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
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
                              isEditing ? 'Edit Team Member' : 'Add Team Member',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEditing ? 'Update the details of this member' : 'Add a new member to the team',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Form Fields
                  TextFormField(
                    controller: fullNameController,
                    decoration: _dialogInputDecoration('Full Name', Icons.person_outline),
                    validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: ['Manager', 'Owner', 'Sales'].contains(roleController.text) ? roleController.text : 'Sales',
                    decoration: _dialogInputDecoration('Role', Icons.badge_outlined),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                    items: ['Manager', 'Owner', 'Sales'].map((role) {
                      return DropdownMenuItem(
                        value: role, 
                        child: Text(role, style: const TextStyle(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (v) => roleController.text = v!,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: mobileController,
                    decoration: _dialogInputDecoration('Mobile Number', Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: emailController,
                    decoration: _dialogInputDecoration('Email Address', Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  
                  // Action Buttons
                  Row(
                    children: [
                      if (isEditing) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _deleteContactPerson(person),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.red.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              _saveContactPerson(
                                isEditing,
                                person,
                                fullNameController.text,
                                roleController.text,
                                mobileController.text,
                                emailController.text,
                              );
                            }
                          },
                          child: Text(
                            isEditing ? 'Save Changes' : 'Add Member', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteContactPerson(ContactPerson person) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded, color: Colors.red.shade400, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Team Member?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to remove ${person.fullName} from your team? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    Navigator.pop(context); // Close the form dialog
    
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedPartner = ChannelPartner.fromJson(_partner!.toJson());
      updatedPartner.contactPersons?.removeWhere((p) => p.name == person.name);

      final success = await ChannelPartnerService.updateChannelPartner(updatedPartner.toJson());
      if (success != null) {
        CustomSnackBar.show(context, message: 'Team member deleted successfully', isError: false, title: 'Notice');
        await _fetchPartnerDetails();
      } else {
        throw Exception('Failed to update Channel Partner');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
    }
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, size: 22, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _saveContactPerson(bool isEditing, ContactPerson? originalPerson, String fullName, String role, String mobile, String email) async {
    Navigator.pop(context); // Close dialog
    
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedPartner = ChannelPartner.fromJson(_partner!.toJson());
      updatedPartner.contactPersons ??= [];

      if (isEditing) {
        final index = updatedPartner.contactPersons!.indexWhere((p) => p.name == originalPerson!.name);
        if (index != -1) {
          updatedPartner.contactPersons![index] = ContactPerson(
            name: originalPerson!.name,
            fullName: fullName,
            roles: role,
            mobile: mobile,
            email: email,
            parent: _partner!.name,
            parenttype: 'Channel Partner',
            parentfield: 'contact_persons',
            doctype: 'Contact Person',
          );
          print('Updating existing member: ${originalPerson!.name}');
        } else {
          print('❌ Could not find member index for: ${originalPerson!.name}');
        }
      } else {
        updatedPartner.contactPersons!.add(ContactPerson(
          fullName: fullName,
          roles: role,
          mobile: mobile,
          email: email,
          parent: _partner!.name,
          parenttype: 'Channel Partner',
          parentfield: 'contact_persons',
          doctype: 'Contact Person',
        ));
        print('Adding new member: $fullName');
      }

      // Create a minimal payload to avoid TimestampMismatchError (417)
      // by only sending the fields that need to be updated.
      final updateData = {
        'name': _partner!.name,
        'contact_persons': updatedPartner.contactPersons!.map((p) {
          final json = p.toJson();
          // Remove system-generated fields that can cause mismatch errors
          json.remove('modified');
          json.remove('creation');
          json.remove('owner');
          json.remove('modified_by');
          return json;
        }).toList(),
      };

      print('Sending minimal update data to service...');
      print('Payload: ${jsonEncode(updateData)}');
      
      final success = await ChannelPartnerService.updateChannelPartner(updateData);
      if (success != null) {
        print('✅ Channel Partner updated successfully');
        CustomSnackBar.show(context, message: 'Team member saved successfully', isError: false, title: 'Notice');
        // Optimized: Fetch only the updated partner data from server, skipping leads and projects
        await _fetchPartnerDetails(forceRefreshPartner: true, refreshLeadsAndProjects: false);
      } else {
        print('❌ Channel Partner update failed in service');
        throw Exception('Failed to update Channel Partner on server');
      }
    } catch (e, stackTrace) {
      print('❌ Error in _saveContactPerson: $e');
      print('StackTrace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
    }
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildContactPersonCard(ContactPerson person) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.fullName ?? 'N/A', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      if (person.roles != null && person.roles!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(person.roles!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showContactPersonForm(person),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                    child: const Icon(Icons.edit_rounded, size: 16, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (person.mobile != null && person.mobile!.isNotEmpty) ...[
                  _actionButton(Icons.call_rounded, 'Call', Colors.green, () async {
                    final url = 'tel:${person.mobile}';
                    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                  }),
                  _actionButton(FontAwesomeIcons.whatsapp, 'WhatsApp', const Color(0xFF25D366), () async {
                    String number = person.mobile!.trim().replaceAll(RegExp(r'[^0-9]'), '');
                    if (number.startsWith('0')) number = number.substring(1);
                    if (number.length == 10) number = '91$number';
                    
                    final url = 'https://wa.me/$number';
                    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }),
                ],
                if (person.email != null && person.email!.isNotEmpty)
                  _actionButton(Icons.email_rounded, 'Email', Colors.blue, () async {
                    final url = 'mailto:${person.email}';
                    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(dynamic icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: icon is IconData 
                ? Icon(icon, size: 16, color: color)
                : FaIcon(icon as FaIconData, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Document doc) {
    final isImage = ['.png', '.jpg', '.jpeg', '.gif', '.bmp']
        .any((ext) => doc.documentAttachment?.toLowerCase().endsWith(ext) ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isImage ? Colors.blue.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isImage ? Icons.image_rounded : Icons.description_rounded,
            color: isImage ? Colors.blue.shade600 : Colors.orange.shade600,
          ),
        ),
        title: Text(doc.documentName ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          doc.documentAttachment?.split('/').last ?? 'No attachment', 
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.black54),
        ),
        onTap: () async {
          if (doc.documentAttachment != null && doc.documentAttachment!.isNotEmpty) {
            final url = '${AuthService.baseUrl}${doc.documentAttachment}';
            if (isImage) {
              _openImageViewer(url);
            } else {
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _openImageViewer(String imageUrl) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.error, color: Colors.red)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlags() {
    final List<Map<String, dynamic>> flags = [
      {'label': 'Commercial', 'icon': Icons.business_rounded, 'value': _partner!.commercial},
      {'label': 'Luxury', 'icon': Icons.diamond_rounded, 'value': _partner!.luxury},
      {'label': 'Land', 'icon': Icons.landscape_rounded, 'value': _partner!.land},
      {'label': 'Redevelopment', 'icon': Icons.architecture_rounded, 'value': _partner!.redevelopment},
      {'label': 'Residential', 'icon': Icons.home_rounded, 'value': _partner!.residential},
      {'label': 'Retail', 'icon': Icons.storefront_rounded, 'value': _partner!.retail},
    ];

    final activeFlags = flags.where((f) => f['value'] == 1).toList();

    if (activeFlags.isEmpty) {
      return const Text('No flags active', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic));
    }

    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      children: activeFlags.map((flag) => _buildFlagBadge(flag['label'], flag['icon'])).toList(),
    );
  }

  Widget _buildStationPreferences() {
    if (_partner!.stationPreferences == null || _partner!.stationPreferences!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text("No station preferences added", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
      );
    }

    return Column(
      children: _partner!.stationPreferences!.map((pref) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.train_rounded, color: Colors.blue.shade600, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pref.railwayRoute ?? 'N/A',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${pref.fromStation} ↔ ${pref.toStation}",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlagBadge(String label, dynamic icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon is IconData)
            Icon(icon, size: 14, color: kAccent)
          else
            FaIcon(icon, size: 14, color: kAccent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectBreakdown() {
    final allProjectIds = {..._projectLeadCounts.keys, ..._projectSiteVisitCounts.keys}.toList();
    allProjectIds.removeWhere((id) => id.isEmpty || id == 'null');

    if (allProjectIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: Text("No projects associated with this partner's leads", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
      );
    }

    return Column(
      children: allProjectIds.map((projectId) {
        final projectName = _projectNames[projectId] ?? projectId;
        final leadCount = _projectLeadCounts[projectId] ?? 0;
        final siteVisitCount = _projectSiteVisitCounts[projectId] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projectName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Text("$leadCount Leads", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blue.shade800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: Colors.purple.shade600),
                          const SizedBox(width: 8),
                          Text("$siteVisitCount Visits", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.purple.shade800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

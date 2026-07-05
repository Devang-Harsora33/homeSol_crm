import 'package:Homesol/models/site_visit.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const Color goldAccent = Color(0xFF675D40);
const Color kBackgroundColor = Color(0xFFF5F7FA);
const Color matteBlack = Color(0xFF1A1A1A);

class SiteVisitDetailPage extends StatefulWidget {
  final SiteVisit siteVisit;

  const SiteVisitDetailPage({super.key, required this.siteVisit});

  @override
  State<SiteVisitDetailPage> createState() => _SiteVisitDetailPageState();
}

class _SiteVisitDetailPageState extends State<SiteVisitDetailPage> {
  late SiteVisit _currentSiteVisit;
  String _leadName = 'Loading Lead...';
  String _projectName = 'Loading Project...';
  String _leadPhone = '';
  bool _isLoadingNames = true;

  @override
  void initState() {
    super.initState();
    _currentSiteVisit = widget.siteVisit;
    _fetchNames();
  }

  Future<void> _fetchNames() async {
    try {
      final freshVisit = await SiteVisitService.fetchSiteVisit(widget.siteVisit.name);
      final lead = await LeadService.fetchLead(widget.siteVisit.lead);
      final project = await ProjectService.fetchProject(widget.siteVisit.project);

      if (mounted) {
        setState(() {
          if (freshVisit != null) {
            _currentSiteVisit = freshVisit;
          }
          _leadName = lead?.leadName ?? lead?.firstName ?? widget.siteVisit.lead;
          _projectName = project?.projectName ?? widget.siteVisit.project;
          _leadPhone = lead?.mobileNo ?? lead?.customerPhone ?? '';
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leadName = 'Error loading Lead';
          _projectName = 'Error loading Project';
          _isLoadingNames = false;
        });
      }
      print('Error fetching lead/project names: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader('Visit Information'),
                    _buildMainInfoCard(),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Additional Details'),
                    _buildDetailsCard(),
                    const SizedBox(height: 32),
                    if (_currentSiteVisit.remark.isNotEmpty) ...[
                      _buildSectionHeader('Remarks'),
                      _buildRemarkCard(),
                      const SizedBox(height: 30),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFloatingBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      backgroundColor: matteBlack,
      elevation: 0,
      stretch: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF3A3A3A), matteBlack],
                  center: Alignment.topCenter,
                  radius: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: goldAccent.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(color: goldAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.location_on_rounded, size: 40, color: goldAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLoadingNames ? '...' : _projectName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(_currentSiteVisit.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'visit scheduled':
      case 'scheduled':
        color = Colors.blue;
        break;
      case 'visit done':
      case 'completed':
        color = Colors.green;
        break;
      case 'revisit scheduled':
        color = Colors.indigo;
        break;
      case 'revisit done':
        color = Colors.teal;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: matteBlack, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.person_outline_rounded, 'Lead Name', _isLoadingNames ? 'Loading...' : _leadName),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          _buildInfoRow(Icons.apartment_rounded, 'Project Name', _isLoadingNames ? 'Loading...' : _projectName),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          Row(
            children: [
              Expanded(child: _buildInfoRow(Icons.event_available_rounded, 'Visit Date', _formatDate(_currentSiteVisit.visitDate))),
              if (_currentSiteVisit.visitDuration != null && _currentSiteVisit.visitDuration!.isNotEmpty) ...[
                Container(width: 1, height: 40, color: Colors.grey.shade100),
                const SizedBox(width: 16),
                Expanded(child: _buildInfoRow(Icons.timer_outlined, 'Duration', _currentSiteVisit.visitDuration)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.badge_outlined, 'Visit ID', _currentSiteVisit.name),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          _buildInfoRow(Icons.people_outline_rounded, 'Presence of CP', _currentSiteVisit.presenceOfCp == 1 ? 'Yes' : 'No'),
          
          if (_currentSiteVisit.visitScheduledDatetime != null) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            _buildInfoRow(Icons.schedule_rounded, 'Scheduled For', _currentSiteVisit.visitScheduledDatetime),
          ],
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          _buildInfoRow(Icons.person_pin_outlined, 'Owner', _currentSiteVisit.owner),
        ],
      ),
    );
  }

  Widget _buildRemarkCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.notes_rounded, size: 16, color: goldAccent),
              ),
              const SizedBox(width: 12),
              const Text('Visit Remarks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: matteBlack)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentSiteVisit.remark,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: kBackgroundColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: goldAccent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
              const SizedBox(height: 4),
              Text(
                value?.isNotEmpty == true ? value! : 'N/A',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: matteBlack, letterSpacing: -0.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              _buildSecondaryActionBtn(
                iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 22),
                bgColor: const Color(0xFF25D366).withOpacity(0.12),
                onTap: () {
                  if (_leadPhone.isNotEmpty) _launchUrl('https://wa.me/$_leadPhone');
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_leadPhone.isNotEmpty) _launchUrl('tel:$_leadPhone');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matteBlack,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_rounded, size: 18),
                        SizedBox(width: 12),
                        Text(
                          'CALL CUSTOMER',
                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActionBtn({
    required Widget iconWidget,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          width: 52,
          alignment: Alignment.center,
          child: iconWidget,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

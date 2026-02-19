import 'package:Homesol/models/site_visit.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

class SiteVisitDetailPage extends StatefulWidget {
  final SiteVisit siteVisit;

  const SiteVisitDetailPage({super.key, required this.siteVisit});

  @override
  State<SiteVisitDetailPage> createState() => _SiteVisitDetailPageState();
}

class _SiteVisitDetailPageState extends State<SiteVisitDetailPage> {
  String _leadName = 'Loading Lead...';
  String _projectName = 'Loading Project...';
  bool _isLoadingNames = true;

  @override
  void initState() {
    super.initState();
    _fetchNames();
  }

  Future<void> _fetchNames() async {
    try {
      final lead = await LeadService.fetchLead(widget.siteVisit.lead);
      final project = await ProjectService.fetchProject(widget.siteVisit.project);

      if (mounted) {
        setState(() {
          _leadName = lead?.leadName ?? lead?.firstName ?? widget.siteVisit.lead;
          _projectName = project?.projectName ?? widget.siteVisit.project;
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
    // Light grey background helps white cards pop
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 375),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    _buildSectionTitle('Project Info'),
                    _buildInfoCard(context),
                    const SizedBox(height: 20),
                  
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image
            Image.network(
              'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80',
              fit: BoxFit.cover,
            ),
            // 2. Gradient Overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(0, 0, 0, 0.8),
                    Color.fromRGBO(0, 0, 0, 0.2),
                    Color.fromRGBO(0, 0, 0, 0.6),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            // 3. Key Header Info
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(widget.siteVisit.status),
                  const SizedBox(height: 8),
                  Text(
                    widget.siteVisit.name, // The ID
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'scheduled': color = Colors.blue; break;
      case 'completed': color = Colors.green; break;
      case 'cancelled': color = Colors.red; break;
      default: color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color.fromRGBO(color.red, color.green, color.blue, 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return _ModernCard(
      child: Column(
        children: [
          _buildModernRow(Icons.person_outline, 'Lead Name', _isLoadingNames ? 'Loading...' : _leadName),
          const Divider(height: 1, indent: 50),
          
          _buildModernRow(Icons.apartment_rounded, 'Project', _isLoadingNames ? 'Loading...' : _projectName), // Changed to apartment icon
          const Divider(height: 1, indent: 50),
          
          _buildModernRow(Icons.event_available_outlined, 'Visit Date', widget.siteVisit.visitDate), // Changed to event icon
          const Divider(height: 1, indent: 50),
          
          _buildModernRow(Icons.flag_outlined, 'Status', widget.siteVisit.status), // Changed to flag icon
          
          if (widget.siteVisit.status == 'Scheduled') ...[
            const Divider(height: 1, indent: 50),
            _buildModernRow(
              Icons.schedule_rounded, // Specific schedule icon
              'Scheduled For', 
              widget.siteVisit.visitScheduledDatetime ?? 'N/A'
            ),
          ],

          const Divider(height: 1, indent: 50),
          _buildModernRow(Icons.notes_outlined, 'Remarks', widget.siteVisit.remark ?? 'No remarks'),
        ],
      ),
    );
  }


  Widget _buildModernRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multi-line text
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[100]!),
      ),
      child: Text(
        label,
        style: TextStyle(color: color[800], fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _launchPhone(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _ModernCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/channel_partner.dart';
import '../../models/lead.dart' as model_lead;
import '../../models/project.dart';
import '../../components/project_share_bottom_sheet.dart';
import '../../models/cp_connections.dart';
import '../../models/cp_campaign.dart';
import 'package:Homesol/services/apis/projects/cp_campaign_service.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'dart:ui';

// ─── EXTENSION ───
extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

const Color goldAccent = Color(0xFF675D40);
const Color kBackgroundColor = Color(0xFFF5F7FA);
const Color matteBlack = Color(0xFF1A1A1A);

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 16;
  @override
  double get maxExtent => tabBar.preferredSize.height + 16;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: kBackgroundColor.withOpacity(0.85),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: tabBar,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}

class ChannelPartnerDetailPage extends StatefulWidget {
  final String partnerId;

  const ChannelPartnerDetailPage({super.key, required this.partnerId});

  @override
  State<ChannelPartnerDetailPage> createState() => _ChannelPartnerDetailPageState();
}

class _ChannelPartnerDetailPageState extends State<ChannelPartnerDetailPage> with SingleTickerProviderStateMixin {
  ChannelPartner? _partner;
  CPConnections? _connections;
  List<Project> _allProjects = [];
  List<CPCampaign> _campaignsList = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // ScreenProtector.preventScreenshotOn();
    _initFetch();
  }

  @override
  void dispose() {
    // ScreenProtector.preventScreenshotOff();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initFetch() async {
    setState(() => _isLoading = true);
    try {
      final partner = await ChannelPartnerService.fetchChannelPartner(widget.partnerId);
      final connections = await ChannelPartnerService.fetchCPConnections(widget.partnerId);
      final projects = await ProjectService.fetchProjects();
      final campaigns = await CPCampaignService.fetchCPCampaigns(channelPartner: widget.partnerId);

      if (mounted) {
        setState(() {
          _partner = partner;
          _connections = connections;
          _allProjects = projects;
          _campaignsList = campaigns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _initFetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: kBackgroundColor, body: Center(child: CircularProgressIndicator(color: goldAccent)));
    }

    if (_errorMessage != null || _partner == null) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(title: const Text('Error', style: TextStyle(color: matteBlack)), backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 60, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Partner not found', style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initFetch,
                style: ElevatedButton.styleFrom(backgroundColor: matteBlack, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMetricsGrid(),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    indicator: BoxDecoration(
                      color: matteBlack,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: matteBlack.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade500,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                    splashBorderRadius: BorderRadius.circular(20),
                    tabs: const [
                      Tab(text: 'OVERVIEW'),
                      Tab(text: 'CAMPAIGNS'),
                      Tab(text: 'HISTORY'),
                    ],
                    onTap: (_) => setState(() {}),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), // Bottom padding for floating bar
                sliver: _buildTabContent(),
              ),
            ],
          ),
          
          // Floating Bottom Actions
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
      expandedHeight: 300.0,
      floating: false,
      pinned: true,
      backgroundColor: matteBlack,
      elevation: 0,
      stretch: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
          onPressed: _showShareProjectPicker,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Premium Radial Gradient Background
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF3A3A3A), matteBlack],
                  center: Alignment.topCenter,
                  radius: 1.2,
                ),
              ),
            ),
            // Header Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  Hero(
                    tag: 'cp_avatar_${_partner!.name}',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: goldAccent.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(color: goldAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        child: Text(
                          (_partner!.firmName?.isNotEmpty ?? false) ? _partner!.firmName![0].toUpperCase() : 'C',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: goldAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _partner!.firmName ?? 'N/A',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: Colors.lightBlueAccent),
                            const SizedBox(width: 6),
                            Text(
                              _partner!.reraNumber?.isNotEmpty == true ? _partner!.reraNumber! : 'No RERA',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildTypeBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    String label = _partner!.type ?? 'CP';
    Color color = Colors.grey;
    if (label == 'P1') { label = 'GOLD'; color = const Color(0xFFFFD700); }
    else if (label == 'P2') { label = 'SILVER'; color = Colors.blueGrey.shade300; }
    else if (label == 'P3') { label = 'BRONZE'; color = Colors.brown.shade400; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = _connections?.metrics;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('Total Leads', metrics?.totalLeads.toString() ?? '0', Icons.people_alt_rounded, const Color(0xFF4A90E2))),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('Total Visits', metrics?.totalVisits.toString() ?? '0', Icons.where_to_vote_rounded, const Color(0xFFF39C12))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Campaigns', metrics?.totalCampaigns.toString() ?? '0', Icons.campaign_rounded, const Color(0xFF9B59B6))),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('Active Projects', metrics?.activeProjectsCount.toString() ?? '0', Icons.apartment_rounded, const Color(0xFF2ECC71))),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: color),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: matteBlack, letterSpacing: -1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabController.index) {
      case 0: return _buildOverviewTab();
      case 1: return _buildCampaignsTab();
      case 2: return _buildHistoryTab();
      default: return SliverToBoxAdapter(child: Container());
    }
  }

  Widget _buildOverviewTab() {
    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSectionHeader('Contact Information'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildInfoRow(Icons.phone_iphone_rounded, 'Mobile', _partner!.mobileNumber)),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoRow(Icons.email_outlined, 'Email', _partner!.email)),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
              Row(
                children: [
                  Expanded(child: _buildInfoRow(Icons.map_outlined, 'Territory', _partner!.territory)),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfoRow(Icons.category_outlined, 'Category', _partner!.category)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionHeader('Preferences', onEdit: _showEditPreferencesPopup),
        _buildPreferencesCard(),
        const SizedBox(height: 32),
        _buildSectionHeader('Members', onEdit: _showEditMembersPopup),
        _buildMembersCard(),
        const SizedBox(height: 32),
        _buildSectionHeader('Network & Connections'),
        _buildConnectionsCard(),
        const SizedBox(height: 32),
        _buildSectionHeader('Associated Projects'),
        _buildProjectsWrap(),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _buildCampaignsTab() {
    final campaigns = List<CPCampaign>.from(_campaignsList);
    campaigns.sort((a, b) {
      final aActive = a.status.toLowerCase() == 'active';
      final bActive = b.status.toLowerCase() == 'active';
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return b.startDate.compareTo(a.startDate);
    });
    
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: ElevatedButton.icon(
            onPressed: () => _showCreateOrEditCampaignPopup(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('CREATE NEW CAMPAIGN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: matteBlack,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        if (campaigns.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.campaign_outlined, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No active campaigns yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        else
          ...campaigns.map((c) => _buildCampaignCard(c)).toList(),
      ]),
    );
  }

  void _showCreateOrEditCampaignPopup({CPCampaign? campaign}) {
    final bool isEditing = campaign != null;
    String? localCampaignType = campaign?.campaignType ?? 'NoBrokerHood';
    String localStatus = campaign?.status ?? 'Active';
    DateTime startDate = campaign != null && campaign.startDate.isNotEmpty ? DateTime.parse(campaign.startDate) : DateTime.now();
    String? localProject = campaign?.project ?? (_allProjects.isNotEmpty ? _allProjects.first.id : null);
    bool isSaving = false;

    final List<String> campaignTypes = [
      'NoBrokerHood',
      'MagicBricks',
      '99Acres',
      'Meta Ads',
      'Google Search Ads',
      'Youtube Ads',
      'SquareYards',
      'WhatsApp Broadcast',
      'Bulk SMS'
    ];

    final List<String> statusOptions = ['Active', 'Inactive'];

    final popupInputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: goldAccent, width: 2)),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(isEditing ? Icons.edit_rounded : Icons.campaign_outlined, color: goldAccent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(isEditing ? 'Edit Campaign' : 'New CP Campaign', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: matteBlack)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('For: ${_partner!.firmName}', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 28),
                  
                  DropdownButtonFormField<String>(
                    value: localProject,
                    dropdownColor: Colors.white,
                    decoration: popupInputDecoration.copyWith(
                      labelText: 'Project *',
                      prefixIcon: const Icon(Icons.apartment_rounded, color: goldAccent, size: 20),
                    ),
                    items: _allProjects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.projectName, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => localProject = v),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: localCampaignType,
                    dropdownColor: Colors.white,
                    decoration: popupInputDecoration.copyWith(
                      labelText: 'Campaign Type *',
                      prefixIcon: const Icon(Icons.category_outlined, color: goldAccent, size: 20),
                    ),
                    items: campaignTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => localCampaignType = v),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: localStatus,
                    dropdownColor: Colors.white,
                    decoration: popupInputDecoration.copyWith(
                      labelText: 'Status *',
                      prefixIcon: const Icon(Icons.info_outline_rounded, color: goldAccent, size: 20),
                    ),
                    items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => localStatus = v!),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context, 
                        initialDate: startDate, 
                        firstDate: DateTime(2000), 
                        lastDate: DateTime(2101),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: goldAccent, onPrimary: Colors.white, onSurface: matteBlack)),
                          child: child!,
                        ),
                      );
                      if (pickedDate != null) {
                        if (!context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startDate),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            startDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: popupInputDecoration.copyWith(
                        labelText: 'Start Date & Time',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: goldAccent, size: 20),
                      ),
                      child: Text(DateFormat('dd MMM yyyy, hh:mm a').format(startDate), style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            if (localProject == null || localCampaignType == null) {
                              CustomSnackBar.show(context, message: 'Please fill all required fields', isError: true);
                              return;
                            }
                            setDialogState(() => isSaving = true);
                            
                            CPCampaign? savedCampaign;
                            if (isEditing) {
                              savedCampaign = await CPCampaignService.updateCPCampaign(campaign!.name, {
                                'project': localProject,
                                'campaign_type': localCampaignType,
                                'start_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate),
                                'status': localStatus,
                              });
                            } else {
                              savedCampaign = await CPCampaignService.createCPCampaign({
                                'channel_partner': _partner!.name,
                                'project': localProject,
                                'campaign_type': localCampaignType,
                                'start_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(startDate),
                                'status': localStatus,
                              });
                            }

                            if (savedCampaign != null) {
                              if (mounted) {
                                Navigator.pop(context);
                                CustomSnackBar.show(context, message: isEditing ? 'Campaign updated successfully' : 'Campaign created successfully');
                                _refreshData(); // Refresh the whole page to get updated stats and campaigns
                              }
                            } else {
                              setDialogState(() => isSaving = false);
                              CustomSnackBar.show(context, message: isEditing ? 'Update failed' : 'Creation failed', isError: true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: matteBlack,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSaving 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : Text(isEditing ? 'Save' : 'Create', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildHistoryTab() {
    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSectionHeader('Recent Lead Activity'),
        ...(_connections?.recentLeads.map((l) => _buildLeadCard(l)).toList() ?? [const Text('No recent leads')]),
        const SizedBox(height: 32),
        _buildSectionHeader('Recent Field Visits'),
        ...(_connections?.recentVisits.map((v) => _buildVisitCard(v)).toList() ?? [const Text('No recent visits')]),
      ]),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: matteBlack, letterSpacing: 1.5),
          ),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 14, color: goldAccent),
                    SizedBox(width: 4),
                    Text('EDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: goldAccent, letterSpacing: 0.5)),
                  ],
                ),
              ),
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
          decoration: BoxDecoration(color: kBackgroundColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: goldAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                value?.isNotEmpty == true ? value! : 'N/A',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: matteBlack),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesCard() {
    final propertyPrefs = _partner?.propertyPreferences;
    final stationPrefs = _partner?.stationPreferences ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property Preferences', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(propertyPrefs?.isNotEmpty == true ? propertyPrefs! : 'Not specified', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: matteBlack)),
          
          if (stationPrefs.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
            Text('Station Preferences', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: stationPrefs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final sp = stationPrefs[index];
                return Row(
                  children: [
                    const Icon(Icons.train_outlined, size: 16, color: goldAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${sp.railwayRoute ?? "Any"} Route: ${sp.fromStation ?? "Any"} to ${sp.toStation ?? "Any"}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: matteBlack),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersCard() {
    final members = _partner?.contactPersons ?? [];
    if (members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Text('No members added', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: members.length,
        separatorBuilder: (_, __) => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        itemBuilder: (context, index) {
          final m = members[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kBackgroundColor,
                child: Text(
                  m.fullName?.isNotEmpty == true ? m.fullName![0].toUpperCase() : 'M',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: matteBlack),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.fullName ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: matteBlack)),
                    if (m.roles?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(m.roles!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (m.mobile?.isNotEmpty == true) ...[
                          const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(m.mobile!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                        ],
                        if (m.email?.isNotEmpty == true) ...[
                          const Icon(Icons.email_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(m.email!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectionsCard() {
    final creator = _connections?.connections?.creator;
    final network = _connections?.connections?.network ?? [];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (creator != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.handshake_rounded, size: 20, color: goldAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Onboarded By', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(creator.name ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: matteBlack)),
                      if (creator.email != null && creator.email!.isNotEmpty)
                        Text(creator.email!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
          ],
          
          Text('Network Connections (${network.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: matteBlack)),
          const SizedBox(height: 16),
          if (network.isEmpty)
            Text('No other connections found', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          else
            _buildNetworkList(network),
        ],
      ),
    );
  }

  Widget _buildNetworkList(List<CPNetworkMember> network) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: network.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final member = network[index];
        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: kBackgroundColor,
              child: Text(
                member.name?.isNotEmpty == true ? member.name![0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: matteBlack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: matteBlack)),
                  if (member.email != null && member.email!.isNotEmpty)
                    Text(member.email!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProjectsWrap() {
    final activeProjects = _connections?.activeProjects ?? [];
    if (activeProjects.isEmpty) return const Text('No active projects', style: TextStyle(color: Colors.grey));
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: activeProjects.map((id) {
        final name = _allProjects.firstWhereOrNull((p) => p.id == id)?.projectName ?? id;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apartment_rounded, size: 16, color: matteBlack),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: matteBlack)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCampaignCard(CPCampaign c) {
    final projectName = _allProjects.firstWhereOrNull((p) => p.id == c.project)?.projectName ?? c.project;
    final isActive = c.status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: isActive ? Colors.green.shade400 : Colors.grey.shade400, width: 6)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: kBackgroundColor, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_outlined, size: 14, color: matteBlack),
                        const SizedBox(width: 6),
                        Text(c.campaignType.isNotEmpty ? c.campaignType : 'N/A', style: const TextStyle(color: matteBlack, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c.status.toUpperCase(),
                          style: TextStyle(color: isActive ? Colors.green.shade700 : Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showCreateOrEditCampaignPopup(campaign: c),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.edit_rounded, size: 16, color: matteBlack),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Project', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              const SizedBox(height: 2),
              Text(projectName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: matteBlack)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text('Started: ${c.startDate}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadCard(CPRecentLead l) {
    final projectName = _allProjects.firstWhereOrNull((p) => p.id == l.project)?.projectName ?? l.project ?? 'N/A';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
            child: const Icon(Icons.person_rounded, color: Color(0xFF4A90E2), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.leadName ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: matteBlack)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.apartment_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(projectName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kBackgroundColor, borderRadius: BorderRadius.circular(12)),
            child: Text(l.status ?? 'Open', style: const TextStyle(color: matteBlack, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(CPRecentVisit v) {
    final projectName = _allProjects.firstWhereOrNull((p) => p.id == v.project)?.projectName ?? v.project ?? 'N/A';
    final date = v.visitDate != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(v.visitDate!)) : 'N/A';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF39C12).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.location_on_rounded, color: Color(0xFFF39C12), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(projectName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: matteBlack))),
                    Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.handshake_rounded, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text('Met: ${v.contactPersonMet ?? 'N/A'}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (v.campaignDiscussed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: kBackgroundColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_outlined, size: 16, color: goldAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Discussed: ${v.campaignDetails?['campaign_type'] ?? v.campaignDiscussed}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: matteBlack),
                            ),
                          ),
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
  }

  Widget _buildFloatingBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
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
                  if (_partner!.mobileNumber != null) _launchUrl('https://wa.me/${_partner!.mobileNumber}');
                },
              ),
              const SizedBox(width: 12),
              _buildSecondaryActionBtn(
                iconWidget: const Icon(Icons.share_rounded, color: Colors.black87, size: 22),
                bgColor: Colors.grey.shade100,
                onTap: _showShareProjectPicker,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_partner!.mobileNumber != null) _launchUrl('tel:${_partner!.mobileNumber}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: matteBlack,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'CALL NOW',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontSize: 14,
                          ),
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showShareProjectPicker() {
    final relevantProjects = _allProjects;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Padding(padding: EdgeInsets.all(20.0), child: Text('Share Project Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: matteBlack))),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: relevantProjects.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = relevantProjects[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kBackgroundColor, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.apartment_rounded, color: goldAccent)),
                  title: Text(p.projectName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () { Navigator.pop(context); _shareProject(p); },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _shareProject(Project project) {
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
      builder: (context) => ProjectShareBottomSheet(project: project, lead: tempLead),
    );
  }

  void _showSearchDialog(String label, List<String> items, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = items.where((i) => i.toLowerCase().contains(query.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Select $label', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: matteBlack, letterSpacing: -0.5)),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                          style: IconButton.styleFrom(backgroundColor: Colors.grey[100], padding: const EdgeInsets.all(8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
                      child: TextField(
                        autofocus: true,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Search for a station...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                          prefixIcon: const Icon(Icons.search_rounded, color: goldAccent),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[200]),
                              const SizedBox(height: 16),
                              Text('No stations found', style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 60, endIndent: 16, color: Color(0xFFF1F1F1)),
                            itemBuilder: (context, index) {
                              final station = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: goldAccent.withOpacity(0.05), shape: BoxShape.circle),
                                  child: const Icon(Icons.train_rounded, color: goldAccent, size: 20),
                                ),
                                title: Text(station, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: matteBlack)),
                                trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                onTap: () {
                                  onSelected(station);
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

  void _showEditPreferencesPopup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: goldAccent)),
    );
    final allStations = await ApiService.fetchRailwayStations();
    if (mounted) Navigator.pop(context);

    String propertyPrefsStr = _partner?.propertyPreferences ?? '';
    List<String> propertyPrefsList = propertyPrefsStr.isNotEmpty ? propertyPrefsStr.split(',').map((e) => e.trim()).toList() : [];
    
    List<Map<String, dynamic>> editableStations = [];
    if (_partner?.stationPreferences != null) {
      editableStations = _partner!.stationPreferences!.map<Map<String, dynamic>>((s) => {
        'railway_route': s.railwayRoute ?? 'Western',
        'from_station': s.fromStation,
        'to_station': s.toStation,
      }).toList();
    }
    if (editableStations.isEmpty) {
      editableStations.add({'railway_route': 'Western', 'from_station': null, 'to_station': null});
    }

    bool isSaving = false;
    final propertyOptions = ['Under Construction', 'Ready to Move In', 'Resale'];

    final popupInputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: goldAccent, width: 2)),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.settings_rounded, color: goldAccent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text('Edit Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: matteBlack)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Property Preferences', style: TextStyle(fontWeight: FontWeight.w800, color: matteBlack)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: propertyOptions.map((opt) {
                            final isSelected = propertyPrefsList.contains(opt);
                            return ChoiceChip(
                              label: Text(opt),
                              selected: isSelected,
                              selectedColor: matteBlack,
                              labelStyle: TextStyle(color: isSelected ? Colors.white : matteBlack, fontWeight: FontWeight.bold, fontSize: 12),
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    propertyPrefsList.add(opt);
                                  } else {
                                    propertyPrefsList.remove(opt);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),
                        const Text('Station Preferences', style: TextStyle(fontWeight: FontWeight.w800, color: matteBlack)),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: editableStations.length,
                          separatorBuilder: (_, __) => const Divider(height: 32),
                          itemBuilder: (context, index) {
                            final currentRoute = editableStations[index]['railway_route'];
                            final filteredStations = allStations.where((s) => s['route'] == currentRoute).map((s) => s['station_name']!).toSet().toList()..sort();
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Preference ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () => setDialogState(() => editableStations.removeAt(index)),
                                    ),
                                  ],
                                ),
                                DropdownButtonFormField<String>(
                                  value: currentRoute,
                                  decoration: popupInputDecoration.copyWith(labelText: 'Route'),
                                  dropdownColor: Colors.white,
                                  items: ['Western', 'Central', 'Harbour'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                  onChanged: (v) {
                                    setDialogState(() {
                                      editableStations[index]['railway_route'] = v;
                                      editableStations[index]['from_station'] = null;
                                      editableStations[index]['to_station'] = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () {
                                    _showSearchDialog('From Station', filteredStations, (selected) {
                                      setDialogState(() => editableStations[index]['from_station'] = selected);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('From Station', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                              const SizedBox(height: 4),
                                              Text(
                                                editableStations[index]['from_station'] ?? 'Select Station',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: editableStations[index]['from_station'] != null ? matteBlack : Colors.grey.shade400,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.search_rounded, color: Colors.black45, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () {
                                    _showSearchDialog('To Station', filteredStations, (selected) {
                                      setDialogState(() => editableStations[index]['to_station'] = selected);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('To Station', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                              const SizedBox(height: 4),
                                              Text(
                                                editableStations[index]['to_station'] ?? 'Select Station',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: editableStations[index]['to_station'] != null ? matteBlack : Colors.grey.shade400,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.search_rounded, color: Colors.black45, size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                editableStations.add({'railway_route': 'Western', 'from_station': null, 'to_station': null});
                              });
                            },
                            icon: const Icon(Icons.add, color: matteBlack),
                            label: const Text('Add Station Pref', style: TextStyle(color: matteBlack, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: matteBlack),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            setDialogState(() => isSaving = true);
                            final formattedStations = editableStations.where((s) => s['from_station'] != null && s['to_station'] != null).map((s) {
                              return {
                                "railway_route": s['railway_route'],
                                "from_station": s['from_station'],
                                "to_station": s['to_station'],
                                "parent": _partner!.name,
                                "parenttype": "Channel Partner",
                                "parentfield": "station_preferences",
                              };
                            }).toList();

                            final updateResponse = await ChannelPartnerService.updateChannelPartner({
                              'name': _partner!.name,
                              'property_preferences': propertyPrefsList.join(','),
                              'station_preferences': formattedStations,
                            });

                            if (updateResponse != null && mounted) {
                              Navigator.pop(context);
                              CustomSnackBar.show(context, message: 'Preferences updated successfully');
                              _refreshData();
                            } else {
                              setDialogState(() => isSaving = false);
                              CustomSnackBar.show(context, message: 'Failed to update preferences', isError: true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: matteBlack,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSaving 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditMembersPopup() {
    List<Map<String, dynamic>> editableMembers = [];
    if (_partner?.contactPersons != null) {
      editableMembers = _partner!.contactPersons!.map<Map<String, dynamic>>((m) => {
        'full_name': m.fullName ?? '',
        'roles': m.roles ?? 'Sales',
        'mobile': m.mobile ?? '',
        'email': m.email ?? '',
      }).toList();
    }
    if (editableMembers.isEmpty) {
      editableMembers.add({'full_name': '', 'roles': 'Sales', 'mobile': '', 'email': ''});
    }

    bool isSaving = false;

    final popupInputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: goldAccent, width: 2)),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: goldAccent.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.people_alt_rounded, color: goldAccent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text('Edit Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: matteBlack)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: editableMembers.length,
                    separatorBuilder: (_, __) => const Divider(height: 32),
                    itemBuilder: (context, index) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Member ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: matteBlack)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    editableMembers.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: editableMembers[index]['full_name'],
                            decoration: popupInputDecoration.copyWith(labelText: 'Full Name *'),
                            onChanged: (v) => editableMembers[index]['full_name'] = v,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: editableMembers[index]['roles'],
                            decoration: popupInputDecoration.copyWith(labelText: 'Role'),
                            dropdownColor: Colors.white,
                            items: ['Manager', 'Owner', 'Sales'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (v) => setDialogState(() => editableMembers[index]['roles'] = v ?? 'Sales'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: editableMembers[index]['mobile'],
                            decoration: popupInputDecoration.copyWith(labelText: 'Mobile'),
                            keyboardType: TextInputType.phone,
                            onChanged: (v) => editableMembers[index]['mobile'] = v,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: editableMembers[index]['email'],
                            decoration: popupInputDecoration.copyWith(labelText: 'Email'),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (v) => editableMembers[index]['email'] = v,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            editableMembers.add({'full_name': '', 'roles': 'Sales', 'mobile': '', 'email': ''});
                          });
                        },
                        icon: const Icon(Icons.add, color: matteBlack),
                        label: const Text('Add Member', style: TextStyle(color: matteBlack, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: matteBlack),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                setDialogState(() => isSaving = true);
                                final formattedMembers = editableMembers.where((m) => m['full_name']!.isNotEmpty).map((m) {
                                  return {
                                    "full_name": m['full_name'],
                                    "roles": m['roles'],
                                    "mobile": m['mobile'],
                                    "email": m['email'],
                                    "parent": _partner!.name,
                                    "parenttype": "Channel Partner",
                                    "parentfield": "contact_persons",
                                  };
                                }).toList();

                                final updateResponse = await ChannelPartnerService.updateChannelPartner({
                                  'name': _partner!.name,
                                  'contact_persons': formattedMembers,
                                });

                                if (updateResponse != null && mounted) {
                                  Navigator.pop(context);
                                  CustomSnackBar.show(context, message: 'Members updated successfully');
                                  _refreshData();
                                } else {
                                  setDialogState(() => isSaving = false);
                                  CustomSnackBar.show(context, message: 'Failed to update members', isError: true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: matteBlack,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: isSaving 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
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
      ),
    );
  }
}

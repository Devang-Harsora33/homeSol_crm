import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'channel_partner_creation_page.dart';
import 'channel_partner_detail_page.dart';
import '../sourcing/sourcing_create_page.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/models/lead.dart' as model_lead;
import '../../components/project_share_bottom_sheet.dart';

class ChannelPartnerListPage extends StatefulWidget {
  final String searchQuery;
  final bool isStandaloneView;

  const ChannelPartnerListPage({
    super.key,
    this.searchQuery = '',
    this.isStandaloneView = true,
  });

  @override
  State<ChannelPartnerListPage> createState() => _ChannelPartnerListPageState();
}

class _ChannelPartnerListPageState extends State<ChannelPartnerListPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<ChannelPartner> _channelPartners = [];
  List<ChannelPartner> _filteredPartners = [];
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String? _currentUserDesignation;

  // Filter States
  final List<String> _selectedCategories = [];
  final List<String> _selectedTerritories = [];
  final List<String> _selectedFlags = [];


  @override
  void initState() {
    super.initState();
    // ScreenProtector.preventScreenshotOn();
    _fetchChannelPartners(forceRefresh: true);
    _fetchProfile();
    _searchController.addListener(_filterPartners);
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await AuthService.getMyProfile();
      if (mounted) {
        setState(() {
          _currentUserDesignation = profile?.designation;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // ScreenProtector.preventScreenshotOff();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChannelPartnerListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isStandaloneView && widget.searchQuery != oldWidget.searchQuery) {
      _filterPartners();
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _showShareProjectPicker(ChannelPartner partner) async {
    if (partner.name == null) return;

    // Show loading indicator as we fetch relevant projects
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF675D40))),
    );

    List<Project> relevantProjects = [];
    try {
      // 1. Fetch leads and visits for this partner to find associated projects
      final leads = await LeadService.getLeadsByChannelPartner(partner.name!);
      final siteVisits = await SiteVisitService.fetchSiteVisits();
      
      final leadIds = leads.map((l) => l.name).toSet();
      final relevantProjectIds = {
        ...leads.map((l) => l.customInterestedProject).where((id) => id != null && id.isNotEmpty),
        ...siteVisits.where((v) => leadIds.contains(v.lead)).map((v) => v.project).where((id) => id != null && id.isNotEmpty)
      };

      // 2. Filter projects
      relevantProjects = _projects.where((p) => relevantProjectIds.contains(p.id)).toList();
    } catch (e) {
      debugPrint("Error fetching relevant projects: $e");
    } finally {
      if (mounted) Navigator.pop(context); // Remove loading indicator
    }

    if (relevantProjects.isEmpty) {
      if (mounted) {
        CustomSnackBar.show(context, message: 'No projects associated with this partner to share.', isError: false, title: 'Notice');
      }
      return;
    }

    // 3. If only one project, share directly
    if (relevantProjects.length == 1) {
      _shareProject(partner, relevantProjects.first);
      return;
    }

    // 4. Otherwise show picker with relevant projects
    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Project to Share',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: relevantProjects.length,
                  itemBuilder: (context, index) {
                    final project = relevantProjects[index];
                    return ListTile(
                      leading: const Icon(Icons.business, color: Color(0xFF675D40)),
                      title: Text(project.projectName),
                      subtitle: Text(project.locationName),
                      onTap: () {
                        Navigator.pop(context);
                        _shareProject(partner, project);
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
  }

  void _shareProject(ChannelPartner partner, Project project) {
    if (partner.name != null) {
      ChannelPartnerService.recordButtonPress(partner.name!, 'Share Button');
    }

    // Convert ChannelPartner to Lead for ProjectShareBottomSheet
    final tempLead = model_lead.Lead(
      name: partner.name ?? '',
      leadName: partner.firmName ?? 'N/A',
      customerName: partner.firmName ?? 'N/A',
      customerPhone: partner.mobileNumber ?? '',
      whatsappNo: partner.mobileNumber ?? '',
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

  void _filterPartners() {
    final query = widget.isStandaloneView ? _searchController.text.toLowerCase() : widget.searchQuery.toLowerCase();
    setState(() {
      _filteredPartners = _channelPartners.where((partner) {
        // Text Search
        bool matchSearch = true;
        if (query.isNotEmpty) {
          matchSearch = (partner.firmName?.toLowerCase().contains(query) ?? false) ||
              (partner.email?.toLowerCase().contains(query) ?? false) ||
              (partner.mobileNumber?.toLowerCase().contains(query) ?? false);
        }
        if (!matchSearch) return false;

        // Category Filter
        if (_selectedCategories.isNotEmpty) {
          if (partner.category == null || !_selectedCategories.contains(partner.category)) {
            return false;
          }
        }

        // Territory Filter
        if (_selectedTerritories.isNotEmpty) {
          if (partner.territory == null || !_selectedTerritories.contains(partner.territory)) {
            return false;
          }
        }

        // Flags Filter (requires all selected flags to be 1)
        if (_selectedFlags.isNotEmpty) {
          for (final flag in _selectedFlags) {
            switch (flag) {
              case 'Commercial': if (partner.commercial != 1) return false; break;
              case 'Luxury': if (partner.luxury != 1) return false; break;
              case 'Land': if (partner.land != 1) return false; break;
              case 'Redevelopment': if (partner.redevelopment != 1) return false; break;
              case 'Residential': if (partner.residential != 1) return false; break;
              case 'Retail': if (partner.retail != 1) return false; break;
              case 'Digital Marketing': if (partner.doesDigitalmarketing != 1) return false; break;
              case 'AOP Signed': if (partner.aopSigned != 1) return false; break;
              case 'Calling Data': if (partner.givesCallingdata != 1) return false; break;
            }
          }
        }

        return true;
      }).toList();
    });
  }

  int _countActiveFilters() {
    return _selectedCategories.length +
        _selectedTerritories.length +
        _selectedFlags.length +
        (_searchController.text.isNotEmpty ? 1 : 0);
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategories.clear();
      _selectedTerritories.clear();
      _selectedFlags.clear();
      _filterPartners();
    });
  }

  void _showFiltersSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const kAccent = Color(0xFF675D40);
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final sidebarBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final contentBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    final allCategories = _channelPartners.map((p) => p.category ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort();
    final allTerritories = _channelPartners.map((p) => p.territory ?? '').where((t) => t.isNotEmpty).toSet().toList()..sort();
    final List<String> allFlags = [
      'Commercial', 'Luxury', 'Land', 'Redevelopment', 
      'Residential', 'Retail', 'Digital Marketing', 
      'AOP Signed', 'Calling Data'
    ];

    final Map<String, List<String>> categories = {
      'Category': allCategories,
      'Territory': allTerritories,
      'Flags': allFlags,
    };

    String currentCategory = 'Category';
    Set<String> checked = <String>{};

    void updateCheckedItems() {
      switch (currentCategory) {
        case 'Category': checked = Set.from(_selectedCategories); break;
        case 'Territory': checked = Set.from(_selectedTerritories); break;
        case 'Flags': checked = Set.from(_selectedFlags); break;
      }
    }

    void applyAllFilters(StateSetter setSheet) {
      setState(() {
        switch (currentCategory) {
          case 'Category': _selectedCategories.clear(); _selectedCategories.addAll(checked); break;
          case 'Territory': _selectedTerritories.clear(); _selectedTerritories.addAll(checked); break;
          case 'Flags': _selectedFlags.clear(); _selectedFlags.addAll(checked); break;
        }
      });
      _filterPartners();
    }

    updateCheckedItems();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final options = categories[currentCategory] ?? const <String>[];
            final int totalActiveCount = _selectedCategories.length + _selectedTerritories.length + _selectedFlags.length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75, // Slightly smaller than CRM
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                   // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, color: kAccent, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '$totalActiveCount filter${totalActiveCount == 1 ? '' : 's'} applied',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        if (totalActiveCount > 0)
                          GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                _selectedCategories.clear();
                                _selectedTerritories.clear();
                                _selectedFlags.clear();
                                checked.clear();
                              });
                              setState(() => _filterPartners());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade600)),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),

                  // Content Area
                  Expanded(
                    child: Row(
                      children: [
                        // Left Sidebar
                        Container(
                          width: 125,
                          color: sidebarBg,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: categories.keys.map((k) {
                              final selected = currentCategory == k;
                              int count = 0;
                              if (k == 'Category') count = _selectedCategories.length;
                              if (k == 'Territory') count = _selectedTerritories.length;
                              if (k == 'Flags') count = _selectedFlags.length;

                              IconData getIcon() {
                                if (k == 'Category') return Icons.category_rounded;
                                if (k == 'Territory') return Icons.map_rounded;
                                return Icons.flag_rounded;
                              }

                              return GestureDetector(
                                onTap: () {
                                  // Apply current changes before switching
                                  applyAllFilters(setSheetState);
                                  setSheetState(() {
                                    currentCategory = k;
                                    updateCheckedItems();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: selected ? contentBg : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 3,
                                        height: 18,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: selected ? kAccent : Colors.transparent,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      Icon(getIcon(), size: 14, color: selected ? kAccent : Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          k,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected ? kAccent : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (count > 0)
                                        Container(
                                          width: 18,
                                          height: 18,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: kAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            count.toString(),
                                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Right Content
                        Expanded(
                          child: Container(
                            color: contentBg,
                            child: options.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.filter_list_off_rounded, size: 28, color: Colors.grey.shade400),
                                          ),
                                          const SizedBox(height: 14),
                                          Text('No options', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                        child: Row(
                                          children: [
                                            Text(
                                              currentCategory,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (checked.isNotEmpty)
                                              GestureDetector(
                                                onTap: () => setSheetState(() => checked.clear()),
                                                child: Text(
                                                  'Clear',
                                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.red.shade400),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final opt = options[index];
                                            final isSelected = checked.contains(opt);
                                            return GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => setSheetState(() {
                                                if (isSelected) checked.remove(opt);
                                                else checked.add(opt);
                                              }),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 150),
                                                margin: const EdgeInsets.only(bottom: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? kAccent.withOpacity(isDark ? 0.2 : 0.07) : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    AnimatedContainer(
                                                      duration: const Duration(milliseconds: 150),
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? kAccent : Colors.transparent,
                                                        borderRadius: BorderRadius.circular(5),
                                                        border: Border.all(
                                                          color: isSelected ? kAccent : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: isSelected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                                                    ),
                                                    const SizedBox(width: 11),
                                                    Expanded(
                                                      child: Text(
                                                        opt,
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                          color: isSelected ? (isDark ? Colors.white : const Color(0xFF3D3420)) : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(top: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () {
                              applyAllFilters(setSheetState);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
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

  Future<void> _fetchChannelPartners({bool forceRefresh = false}) async {
    if (!mounted) return;
    
    // 1. Instant Cache Load
    try {
      final cachedPartners = await ChannelPartnerService.fetchAllChannelPartners(forceRefresh: false);
      final cachedProjects = await ProjectService.fetchProjects();
      if (mounted) {
        setState(() {
          _channelPartners = cachedPartners;
          _projects = cachedProjects;
          _isLoading = cachedPartners.isEmpty; // Show skeleton only if completely empty
          _errorMessage = null;
        });
        _filterPartners(); // Apply any existing search/filters
      }
    } catch (e) {
      print('Error during CP cache load: $e');
    }

    // 2. Silent Background Sync
    if (forceRefresh) {
      try {
        // Sync Leads and Site Visits in background silently as originally requested, but don't block
        LeadService.syncMyLeads().catchError((e) => print('Lead sync failed: $e'));
        SiteVisitService.fetchMySiteVisits(forceRefresh: true).catchError((e) => print('Site visit sync failed: $e'));
        
        final freshPartners = await ChannelPartnerService.fetchAllChannelPartners(forceRefresh: true);
        final freshProjects = await ProjectService.fetchProjects(forceRefresh: true); // Optionally refresh projects too
        
        if (mounted) {
          setState(() {
            _channelPartners = freshPartners;
            _projects = freshProjects;
            _isLoading = false;
          });
          _filterPartners(); // Re-apply filters with fresh data
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = "Failed to load channel partners. Please swipe down to refresh.";
            _isLoading = false;
          });
        }
        print('Error fetching channel partners from API: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.isStandaloneView ? AppBar(
        title: const Text('Channel Partners', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Channel Partners',
            onPressed: () => _fetchChannelPartners(forceRefresh: true),
          ),
        ],
      ) : null,
      floatingActionButton: (widget.isStandaloneView && _currentUserDesignation?.trim().toLowerCase() != 'property developer') ? Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ChannelPartnerCreationPage()),
            ).then((result) {
              if (result == true) {
                _fetchChannelPartners(forceRefresh: true);
              } else {
                _fetchChannelPartners();
              }
            });
          },
          backgroundColor: const Color(0xFF1A1A1A),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ) : null,
      body: SafeArea(
        child: Padding(
          padding: widget.isStandaloneView ? const EdgeInsets.all(20) : const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              if (widget.isStandaloneView) ...[
                _buildSearchCard(),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchChannelPartners,
                  child: _isLoading
                      ? ListView.builder(
                          itemCount: 3, // Display 3 skeleton cards
                          itemBuilder: (context, index) => const _ChannelPartnerCardSkeleton(),
                        )
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!))
                          : _filteredPartners.isEmpty
                              ? const Center(child: Text('No Channel Partners Found'))
                              : ListView.builder(
                                  itemCount: _filteredPartners.length,
                                  itemBuilder: (context, index) {
                                    final partner = _filteredPartners[index];
                                    return GestureDetector(
                                      onTap: () {
                                        if (partner.name != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChannelPartnerDetailPage(partnerId: partner.name!),
                                            ),
                                          );
                                        }
                                      },
                                      child: _ChannelPartnerCard(
                                        partner: partner,
                                        onCall: () {
                                          if (partner.name != null) {
                                            ChannelPartnerService.recordButtonPress(partner.name!, 'Call Button');
                                          }
                                          if (partner.mobileNumber != null && partner.mobileNumber!.isNotEmpty) {
                                            _launchUrl('tel:${partner.mobileNumber}');
                                          }
                                        },
                                        onWhatsApp: () {
                                          if (partner.name != null) {
                                            ChannelPartnerService.recordButtonPress(partner.name!, 'WhatsApp Button');
                                          }
                                          if (partner.mobileNumber != null && partner.mobileNumber!.isNotEmpty) {
                                            String number = partner.mobileNumber!.trim().replaceAll(RegExp(r'[^0-9]'), '');
                                            if (number.startsWith('0')) number = number.substring(1);
                                            if (number.length == 10) number = '91$number';
                                            _launchUrl('https://wa.me/$number');
                                          }
                                        },
                                        onShare: () => _showShareProjectPicker(partner),
                                        showSourcingButton: _currentUserDesignation != null && 
                                          (_currentUserDesignation!.toLowerCase() == 'sales and sourcing' || 
                                           _currentUserDesignation!.toLowerCase() == 'sourcing'),
                                        onAddSourcing: () async {
                                          if (partner.name != null) {
                                            ChannelPartnerService.recordButtonPress(partner.name!, 'Sourcing Button');
                                          }
                                          final result = await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => SourcingCreatePage(
                                                initialChannelPartner: partner,
                                              ),
                                            ),
                                          );
                                          if (result is Map && result['refresh'] == true) {
                                             // Pass back to parent (likely SourcingMainPage) to handle tab switch/refresh/questionnaire
                                             if (mounted) Navigator.pop(context, result);
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const kAccent = Color(0xFF675D40);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search firm, email, phone...',
                hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          // The listener will automatically trigger _filterPartners
                        },
                        child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showFiltersSheet(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _countActiveFilters() > 0 ? kAccent : (isDark ? Colors.grey[800] : Colors.white),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _countActiveFilters() > 0 ? kAccent.withOpacity(0.35) : Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded, 
                  color: _countActiveFilters() > 0 ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade600), 
                  size: 22
                ),
                if (_countActiveFilters() > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _countActiveFilters().toString(),
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChannelPartnerCard extends StatelessWidget {
  final ChannelPartner partner;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onAddSourcing;
  final VoidCallback onShare;
  final bool showSourcingButton;

  const _ChannelPartnerCard({
    required this.partner,
    required this.onCall,
    required this.onWhatsApp,
    required this.onAddSourcing,
    required this.onShare,
    required this.showSourcingButton,
  });

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);

    // Priority Badge Logic
    Widget? priorityBadge;
    if (partner.type != null) {
      String label = "";
      Gradient badgeGradient;
      Color textColor = Colors.white;
      IconData badgeIcon;
      Color borderColor;
      
      switch (partner.type!.toUpperCase()) {
        case 'P1':
          label = "GOLD";
          badgeGradient = const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFDB931), Color(0xFFDAA520)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          textColor = const Color(0xFF5C4033);
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: badgeGradient,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: [BoxShadow(color: (badgeGradient.colors[0]).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 10, color: textColor),
              const SizedBox(width: 3),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 9, 
                  fontWeight: FontWeight.w900, 
                  color: textColor, 
                  letterSpacing: 0.5,
                  shadows: [
                    if (textColor == Colors.white)
                      Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: const Offset(0, 1))
                  ]
                ),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.firmName ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (partner.cpQuality != null)
                      Row(
                        children: List.generate(5, (index) {
                          int numberOfStars;
                          if (partner.cpQuality! <= 1.0) {
                            numberOfStars = (partner.cpQuality! / 0.2).round();
                          } else {
                            numberOfStars = partner.cpQuality!.round();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 2.0),
                            child: Icon(
                              index < numberOfStars ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 14, 
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      partner.category ?? 'N/A',
                      style: const TextStyle(
                        color: kAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (priorityBadge != null) ...[
                    const SizedBox(height: 6),
                    priorityBadge,
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              if (partner.email != null && partner.email!.isNotEmpty)
                _detailRow(context, Icons.mail_outline_rounded, partner.email!),

              if (partner.mobileNumber != null && partner.mobileNumber!.isNotEmpty)
                _detailRow(context, Icons.phone_iphone_rounded, partner.mobileNumber!),

              if (partner.reraNumber != null && partner.reraNumber!.isNotEmpty)
                _detailRow(
                  context, 
                  Icons.badge_outlined,
                  "RERA: ${partner.reraNumber!}",
                ),
              if (partner.territory != null && partner.territory!.isNotEmpty)
                _detailRow(context, Icons.map_outlined, partner.territory!),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade200, thickness: 1, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _actionIconButton(
                icon: FontAwesomeIcons.phone,
                color: Colors.blue.shade700,
                onPressed: onCall,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                icon: FontAwesomeIcons.whatsapp,
                color: const Color(0xFF25D366),
                onPressed: onWhatsApp,
              ),
              const SizedBox(width: 8),
              _actionIconButton(
                icon: Icons.share_rounded,
                color: kAccent,
                onPressed: onShare,
              ),
              if (showSourcingButton) ...[
                const SizedBox(width: 12),
                _actionButton(
                  onPressed: onAddSourcing,
                  icon: Icons.source_outlined,
                  label: 'Sourcing',
                  backgroundColor: const Color(0xFF1A1A1A),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Creation Date Info
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                'Created: ${partner.creation != null ? "${partner.creation!.day.toString().padLeft(2, '0')}/${partner.creation!.month.toString().padLeft(2, '0')}/${partner.creation!.year}" : "N/A"}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIconButton({
    required dynamic icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    // Detect FontAwesome icons safely
    bool isFontAwesome = false;
    try {
      isFontAwesome = icon.fontFamily?.startsWith('FontAwesome') ?? false;
    } catch (_) {
      isFontAwesome = icon.toString().contains('FontAwesome');
    }
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: IconButton(
        icon: isFontAwesome 
            ? FaIcon(icon, color: color, size: 16)
            : Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 24,
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required dynamic icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    bool isFontAwesome = false;
    try {
      isFontAwesome = icon.fontFamily?.startsWith('FontAwesome') ?? false;
    } catch (_) {
      isFontAwesome = icon.toString().contains('FontAwesome');
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        minimumSize: const Size(0, 40),
      ),
      icon: isFontAwesome 
          ? FaIcon(icon, size: 14)
          : Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
  }

  Widget _detailRow(BuildContext context, IconData icon, String text,
      {Color color = Colors.black87}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color.withOpacity(0.8)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }


class _ChannelPartnerCardSkeleton extends StatelessWidget {
  const _ChannelPartnerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color? skeletonColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 150, height: 18, color: skeletonColor),
              Container(width: 80, height: 20, color: skeletonColor),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildDetailRowSkeleton(skeletonColor),
              _buildDetailRowSkeleton(skeletonColor),
              _buildDetailRowSkeleton(skeletonColor),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200, thickness: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 40, height: 40, color: skeletonColor),
                  const SizedBox(width: 8),
                  Container(width: 40, height: 40, color: skeletonColor),
                ],
              ),
              Row(
                children: [
                  Container(width: 14, height: 14, color: skeletonColor),
                  const SizedBox(width: 6),
                  Container(width: 100, height: 12, color: skeletonColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowSkeleton(Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Container(width: 120, height: 13, color: color),
      ],
    );
  }
}
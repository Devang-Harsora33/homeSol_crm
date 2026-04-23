import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:Homesol/services/auth_service.dart';
import '../../pages/sourcing/sourcing_list_page.dart';
import '../../pages/channel_partner/channel_partner_list_page.dart';
import 'sourcing_create_page.dart';
import '../channel_partner/channel_partner_creation_page.dart';

class SourcingMainPage extends StatefulWidget {
  final String? developerId;

  const SourcingMainPage({super.key, this.developerId});

  @override
  State<SourcingMainPage> createState() => _SourcingMainPageState();
}

class _SourcingMainPageState extends State<SourcingMainPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _currentUserDesignation;
  
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchProfile();
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
    ScreenProtector.preventScreenshotOff();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchAndFilterCard(ThemeData theme, bool isDark) {
    const kAccent = Color(0xFF675D40);
    final isSourcingTab = _tabController.index == 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        16,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sourcing',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Search ──
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: isSourcingTab ? 'Search sourcing...' : 'Search partners...',
                      hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () => setState(() { _searchQuery = ''; _searchController.clear(); }),
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
            ],
          ),
          const SizedBox(height: 14),

          // ── Tab Bar ──
          if (_currentUserDesignation?.trim().toLowerCase() != 'property developer')
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800.withOpacity(0.6) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                padding: const EdgeInsets.all(4),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.business_center_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Sourcing'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.handshake_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Channel Partners'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildSearchAndFilterCard(theme, isDark),
          Expanded(
            child: (_currentUserDesignation?.trim().toLowerCase() == 'property developer')
                ? SourcingListPage(
                    developerId: widget.developerId,
                    showAddButton: false,
                    searchQuery: _searchQuery,
                    isStandaloneView: false,
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      SourcingListPage(
                        developerId: widget.developerId,
                        showAddButton: false, // Handled by global FAB now
                        searchQuery: _searchQuery,
                        isStandaloneView: false,
                      ),
                      ChannelPartnerListPage(
                        searchQuery: _searchQuery,
                        isStandaloneView: false,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: (_currentUserDesignation?.trim().toLowerCase() != 'property developer') ? Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () async {
            if (_tabController.index == 0) {
               await Navigator.push(context, MaterialPageRoute(builder: (context) => const SourcingCreatePage()));
            } else {
               await Navigator.push(context, MaterialPageRoute(builder: (context) => const ChannelPartnerCreationPage()));
            }
          },
          backgroundColor: const Color(0xFF1A1A1A),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ) : null,
    );
  }
}

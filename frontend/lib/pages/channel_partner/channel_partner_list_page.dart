import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/services/apis/channel_partners/channel_partner.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'channel_partner_creation_page.dart';
import 'channel_partner_detail_page.dart';

class ChannelPartnerListPage extends StatefulWidget {
  const ChannelPartnerListPage({super.key});

  @override
  State<ChannelPartnerListPage> createState() => _ChannelPartnerListPageState();
}

class _ChannelPartnerListPageState extends State<ChannelPartnerListPage> {
  List<ChannelPartner> _channelPartners = [];
  List<ChannelPartner> _filteredPartners = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChannelPartners();
    _searchController.addListener(_filterPartners);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  void _filterPartners() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPartners = _channelPartners.where((partner) {
        return (partner.firmName?.toLowerCase().contains(query) ?? false) ||
            (partner.email?.toLowerCase().contains(query) ?? false) ||
            (partner.mobileNumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _fetchChannelPartners({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Sync Leads and Site Visits as requested, but don't let them block channel partners if they fail
      try {
        await LeadService.syncMyLeads().timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Lead sync failed during CP fetch: $e');
      }
      
      try {
        await SiteVisitService.fetchMySiteVisits(forceRefresh: forceRefresh).timeout(const Duration(seconds: 10));
      } catch (e) {
        print('Site visit sync failed during CP fetch: $e');
      }
      
      final partners = await ChannelPartnerService.fetchAllChannelPartners(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _channelPartners = partners;
          _filteredPartners = partners;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load channel partners. Please swipe down to refresh.";
          _isLoading = false;
        });
      }
      print('Error fetching channel partners: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Channel Partners'),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ChannelPartnerCreationPage()),
          ).then((_) => _fetchChannelPartners());
        },
        backgroundColor: const Color(0xFF675D40),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSearchCard(),
              const SizedBox(height: 20),
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
                                          if (partner.mobileNumber != null && partner.mobileNumber!.isNotEmpty) {
                                            _launchUrl('tel:${partner.mobileNumber}');
                                          }
                                        },
                                        onWhatsApp: () {
                                          if (partner.mobileNumber != null && partner.mobileNumber!.isNotEmpty) {
                                            _launchUrl('https://wa.me/${partner.mobileNumber}');
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by firm, email, phone...',
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              // TODO: Implement filter sheet
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelPartnerCard extends StatelessWidget {
  final ChannelPartner partner;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  const _ChannelPartnerCard({
    required this.partner,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);

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
                child: Text(
                  partner.firmName ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  partner.category ?? 'N/A',
                  style: TextStyle(
                    color: kAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              if (partner.email != null && partner.email!.isNotEmpty)
                _detailRow(context, FontAwesomeIcons.envelope, partner.email!),

              if (partner.mobileNumber != null && partner.mobileNumber!.isNotEmpty)
                _detailRow(context, FontAwesomeIcons.mobileScreen, partner.mobileNumber!),

              if (partner.reraNumber != null && partner.reraNumber!.isNotEmpty)
                _detailRow(
                  context, 
                  FontAwesomeIcons.idCard, // Represents a License/ID
                  "RERA: ${partner.reraNumber!}", // Combined label + value if your function accepts 3 args
                ),
              if (partner.territory != null && partner.territory!.isNotEmpty)
                _detailRow(context, FontAwesomeIcons.mapLocationDot, partner.territory!),
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
                  IconButton(
                    icon: Icon(Icons.call, color: Colors.green, size: 20),
                    onPressed: onCall,
                  ),
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                    onPressed: onWhatsApp,
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    'Created: ${partner.creation != null ? "${partner.creation!.day}/${partner.creation!.month}/${partner.creation!.year}" : "N/A"}',
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
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String text,
      {Color color = Colors.black54}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.8)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
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
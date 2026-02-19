import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/developer.dart';
import '../models/project.dart';
import 'property_detail_popup.dart';
import '../../utils.dart';

class DeveloperDetailPopup extends StatefulWidget {
  final Developer developer;
  final List<Project> projects;

  const DeveloperDetailPopup({
    super.key,
    required this.developer,
    required this.projects,
  });

  @override
  State<DeveloperDetailPopup> createState() => _DeveloperDetailPopupState();
}

class _DeveloperDetailPopupState extends State<DeveloperDetailPopup> {
  bool _isBookmarked = false;
  Set<String> _cachedDeveloperBookmarks = {};
  List<Project> _detailedProjects = [];
  bool _isLoadingProjects = true;

  // --- Theme Constants ---
  static const Color kPrimaryGold = Color(0xFF675D40);
  static const Color kTextBlack = Color(0xFF1A1A1A);
  static const Color kTextGrey = Color(0xFF757575);
  static const Color kSurfaceWhite = Colors.white;
  static const Color kBackground = Color(0xFFF9F9F9);

  @override
  void initState() {
    super.initState();
    _initDeveloperBookmarkState();
    _fetchDetailedProjects();
  }

  Future<void> _fetchDetailedProjects() async {
    setState(() {
      _isLoadingProjects = true;
    });

    final List<Project> projects = [];
    for (final devProject in widget.developer.projectsList) {
      try {
        final project = await ProjectService.fetchProject(devProject.project);
        if (project != null) {
          projects.add(project);
        }
      } catch (e) {
        print('Failed to fetch project ${devProject.project}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _detailedProjects = projects;
        _isLoadingProjects = false;
      });
    }
  }

  // --- Helpers ---
  String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // --- Logic ---
  Future<void> _initDeveloperBookmarkState() async {
    final broker = await AuthService.getUserData();
    final brokerId = broker?['broker_id'];
    final devId = widget.developer.id;
    if (brokerId == null || devId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'bookmarks_developers_$brokerId';
    final list = prefs.getStringList(key) ?? [];
    _cachedDeveloperBookmarks = list.toSet();
    if (_cachedDeveloperBookmarks.contains(devId) && mounted) {
      setState(() {
        _isBookmarked = true;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final broker = await AuthService.getUserData();
    final brokerId = broker?['broker_id'];
    final devId = widget.developer.id;

    if (brokerId == null || devId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login required to bookmark')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'bookmarks_developers_$brokerId';
    final already = _cachedDeveloperBookmarks.contains(devId);

    setState(() {
      if (already) {
        _cachedDeveloperBookmarks.remove(devId);
        _isBookmarked = false;
      } else {
        _cachedDeveloperBookmarks.add(devId);
        _isBookmarked = true;
      }
    });

    await prefs.setStringList(cacheKey, _cachedDeveloperBookmarks.toList());

    final updateBody = {
      'bookmarks': {
        'projects': [],
        'developers': _cachedDeveloperBookmarks.toList(),
      },
    };

    try {
      await ApiService.updateBroker(brokerId, updateBody);
    } catch (e) {
      print('Error syncing bookmark: $e');
    }
  }

  void _shareDeveloper() {
    final developer = widget.developer;
    final shareText = '''
        🏗️ ${developer.developerName}
        📍 ${developer.officeAddress}
        🌐 ${developer.websiteUrl}
        Check out their projects on HomeSol!
        ''';
    Share.share(shareText);
  }

  // --- UI Construction ---
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: kBackground,
      child: Scaffold(
        backgroundColor: kBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 24),
                    _buildKeyDetailsGrid(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('About Company'),
                    const SizedBox(height: 12),
                    _buildAboutCard(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('Contact Details'),
                    const SizedBox(height: 12),
                    _buildContactCard(),
                    if (widget.developer.projectsList.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      _buildSectionTitle('Projects Portfolio'),
                      const SizedBox(height: 12),
                      _buildProjectsList(),
                    ],
                    const SizedBox(height: 30),
                    _buildSectionTitle('Legal Information'),
                    const SizedBox(height: 12),
                    _buildLegalGrid(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: kPrimaryGold,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Colors.black),
              onPressed: _toggleBookmark,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.black),
              onPressed: _shareDeveloper,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'dev_logo_${widget.developer.id}',
              child: Image.network(
                buildImageUrl(widget.developer.logoUrl),
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.5),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [kPrimaryGold, Colors.black],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.developer.developerName,
          style: const TextStyle(
            color: kTextBlack,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: 'Serif',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const FaIcon(FontAwesomeIcons.mapPin, color: kTextGrey, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.developer.officeAddress,
                style: const TextStyle(color: kTextBlack, fontSize: 14),
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const FaIcon(FontAwesomeIcons.calendar, color: kTextGrey, size: 14),
            const SizedBox(width: 8),
            Text(
              "Established in ${_formatDate(widget.developer.yearEstablished.toString())}",
              style: const TextStyle(
                color: kTextGrey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyDetailsGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildGridItem('Total Projects', widget.developer.totalProjectsCompleted.toString()),
          _buildVerticalDivider(),
          _buildGridItem('Active Projects', widget.developer.currentProjectsCount.toString()),
        ],
      ),
    );
  }
  
  Widget _buildGridItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(color: kPrimaryGold, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() => Container(height: 30, width: 1, color: const Color(0xFFEEEEEE));

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: kTextBlack, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        _stripHtml(widget.developer.companyDescription),
        style: const TextStyle(fontSize: 14, height: 1.5, color: kTextGrey),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _ContactTile(
            icon: FontAwesomeIcons.user,
            label: 'Contact Person',
            value: widget.developer.contactPerson,
          ),
          _ContactTile(
            icon: FontAwesomeIcons.phone,
            label: 'Phone',
            value: widget.developer.contactPhone,
            isLink: true,
            onTap: () => launchUrl(Uri.parse('tel:${widget.developer.contactPhone}')),
          ),
          _ContactTile(
            icon: FontAwesomeIcons.envelope,
            label: 'Email',
            value: widget.developer.contactEmail,
            isLink: true,
            onTap: () => launchUrl(Uri.parse('mailto:${widget.developer.contactEmail}')),
          ),
          _ContactTile(
            icon: FontAwesomeIcons.globe,
            label: 'Website',
            value: widget.developer.websiteUrl,
            isLink: true,
            isLast: true,
            onTap: () => launchUrl(Uri.parse(widget.developer.websiteUrl)),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList() {
    if (_isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detailedProjects.isEmpty) {
      return const Center(child: Text('No projects found.'));
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _detailedProjects.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final project = _detailedProjects[index];
          return _ProjectCard(
            project: project,
            developer: widget.developer,
            width: MediaQuery.of(context).size.width * 0.7,
          );
        },
      ),
    );
  }
  
  Widget _buildLegalGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _LegalCard(label: 'RERA', value: widget.developer.reraNumber),
        _LegalCard(label: 'GST', value: widget.developer.gstNumber),
        _LegalCard(label: 'PAN', value: widget.developer.panNumber),
        _LegalCard(label: 'Company Size', value: widget.developer.companySize),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;
  final bool isLast;
  final VoidCallback? onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLink ? onTap : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                FaIcon(icon, size: 16, color: _DeveloperDetailPopupState.kTextGrey),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12, color: _DeveloperDetailPopupState.kTextGrey)),
                      const SizedBox(height: 2),
                      Text(
                        value.isEmpty ? 'N/A' : value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isLink ? _DeveloperDetailPopupState.kPrimaryGold : _DeveloperDetailPopupState.kTextBlack,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLink) const FaIcon(FontAwesomeIcons.arrowUpRightFromSquare, size: 14, color: _DeveloperDetailPopupState.kTextGrey),
              ],
            ),
          ),
          if (!isLast) Divider(height: 1, color: Colors.grey.shade200, indent: 16, endIndent: 16),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  final String label;
  final String value;

  const _LegalCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _DeveloperDetailPopupState.kSurfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _DeveloperDetailPopupState.kTextGrey)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _DeveloperDetailPopupState.kTextBlack),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final Developer developer;
  final double width;

  const _ProjectCard({required this.project, required this.developer, required this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black54,
          builder: (_) => PropertyDetailPopup(project: project, developer: developer),
        );
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      project.galleryImages.isNotEmpty ? buildImageUrl(project.galleryImages.first.images) : '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          project.constructionStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        project.projectName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.mapMarkerAlt, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            project.locationDisplay,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // String _formatPrice(int min, int max) {
  //   if (min == 0 && max == 0) return 'Price on Request';
  //   final formatter = NumberFormat.compactSimpleCurrency(locale: 'en_IN');
  //   if (min == max) return formatter.format(min * 10000000);
  //   return '${formatter.format(min * 10000000)} - ${formatter.format(max * 10000000)}';
  // }
}
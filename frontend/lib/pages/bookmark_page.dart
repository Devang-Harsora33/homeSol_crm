import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:flutter/services.dart';
import '../models/project.dart';
import '../models/developer.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../components/developer_detail_popup.dart';
import '../components/property_detail_popup.dart';
// import '../components/add_enquiry_sheet.dart';
import 'package:intl/intl.dart';
import '../utils.dart';

class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data
  List<Project> _bookmarkedProjects = [];
  List<Developer> _bookmarkedDevelopers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentBrokerId;

  String _formatPriceRange(int min, int max) {
    if (min == 0 && max == 0) {
      return 'Price on Request';
    }
    final NumberFormat formatter = NumberFormat.compactSimpleCurrency(locale: 'en_IN');
    String minPrice = formatter.format(min * 10000000); // Assuming input is in Crores
    String maxPrice = formatter.format(max * 10000000); // Assuming input is in Crores
    if (min == max) return minPrice;
    return '$minPrice - $maxPrice';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _getCurrentBrokerId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentBrokerId() async {
    try {
      final userData = await AuthService.getUserData();
      setState(() {
        _currentBrokerId = userData?['broker_id']?.toString();
      });
      if (_currentBrokerId != null) {
        await _fetchBookmarks();
      }
    } catch (e) {
      print('❌ Error getting current broker ID: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to identify user. Please try again.';
      });
    }
  }

  Future<void> _fetchBookmarks({bool forceRefresh = false}) async {
    if (_currentBrokerId == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔍 Fetching bookmarks for broker: $_currentBrokerId');
      final bookmarks = await ApiService.fetchBookmarks(_currentBrokerId!);

      // Fetch detailed data for bookmarked projects and developers
      final projectsFuture = _fetchBookmarkedProjects(bookmarks.projects, forceRefresh: forceRefresh);
      final developersFuture = _fetchBookmarkedDevelopers(bookmarks.developers, forceRefresh: forceRefresh);

      await Future.wait([projectsFuture, developersFuture]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching bookmarks: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _fetchBookmarkedProjects(List<String> projectIds, {bool forceRefresh = false}) async {
    try {
      final allProjects = await ApiService.fetchProjects(forceRefresh: forceRefresh);
      setState(() {
        _bookmarkedProjects = allProjects
            .where((project) => projectIds.contains(project.id))
            .toList();
      });
    } catch (e) {
      print('❌ Error fetching bookmarked projects: $e');
    }
  }

  Future<void> _fetchBookmarkedDevelopers(List<String> developerIds, {bool forceRefresh = false}) async {
    try {
      final allDevelopers = await ApiService.fetchDevelopers(forceRefresh: forceRefresh);
      setState(() {
        _bookmarkedDevelopers = allDevelopers
            .where((developer) => developerIds.contains(developer.id))
            .toList();
      });
    } catch (e) {
      print('❌ Error fetching bookmarked developers: $e');
    }
  }

  Future<void> _removeProjectBookmark(Project project) async {
    if (_currentBrokerId == null) return;

    try {
      final success = await ApiService.removeProjectBookmark(
        _currentBrokerId!,
        project.id,
      );

      if (success) {
        setState(() {
          _bookmarkedProjects.removeWhere((p) => p.id == project.id);
        });
        CustomSnackBar.show(context, message: 'Project removed from bookmarks', isError: false, title: 'Notice');
      } else {
        CustomSnackBar.show(context, message: 'Failed to remove project from bookmarks', isError: true, title: 'Error');
      }
    } catch (e) {
      print('❌ Error removing project bookmark: $e');
    }
  }

  Future<void> _removeDeveloperBookmark(Developer developer) async {
    if (_currentBrokerId == null) return;

    try {
      final success = await ApiService.removeDeveloperBookmark(
        _currentBrokerId!,
        developer.id,
      );

      if (success) {
        setState(() {
          _bookmarkedDevelopers.removeWhere((d) => d.id == developer.id);
        });
        CustomSnackBar.show(context, message: 'Developer removed from bookmarks', isError: false, title: 'Notice');
      } else {
        CustomSnackBar.show(context, message: 'Failed to remove developer from bookmarks', isError: true, title: 'Error');
      }
    } catch (e) {
      print('❌ Error removing developer bookmark: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Bookmarks'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_work, size: 20),
                  const SizedBox(width: 8),
                  Text('Projects (${_bookmarkedProjects.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apartment, size: 20),
                  const SizedBox(width: 8),
                  Text('Developers (${_bookmarkedDevelopers.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [_buildProjectsTab(), _buildDevelopersTab()],
            ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('Error loading bookmarks', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchBookmarks,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (_bookmarkedProjects.isEmpty) {
      return _buildEmptyState(
        icon: Icons.home_work_outlined,
        title: 'No Bookmarked Projects',
        subtitle: 'Projects you bookmark will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchBookmarks(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarkedProjects.length,
        itemBuilder: (context, index) {
          final project = _bookmarkedProjects[index];
          return _buildProjectCard(project);
        },
      ),
    );
  }

  Widget _buildDevelopersTab() {
    if (_bookmarkedDevelopers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.apartment_outlined,
        title: 'No Bookmarked Developers',
        subtitle: 'Developers you bookmark will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchBookmarks(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarkedDevelopers.length,
        itemBuilder: (context, index) {
          final developer = _bookmarkedDevelopers[index];
          return _buildDeveloperCard(developer);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Find the developer for this project
    final developer = _bookmarkedDevelopers.firstWhere(
      (dev) => dev.id == project.developer,
      orElse: () => Developer(
        id: '',
        createdAt: '',
        updatedAt: '',
        username: 'Unknown',
        email: '',
        developerName: 'Unknown Developer',
        reraNumber: '',
        gstNumber: '',
        panNumber: '',
        officeAddress: '',
        contactPerson: '',
        contactEmail: '',
        contactPhone: '',
        companySize: '',
        specializations: [],
        certifications: [],
        bankDetails: BankDetails(accountNumber: '', ifscCode: '', bankName: ''),
        kycStatus: '',
        isVerified: false,
        isActive: false,
        websiteUrl: '',
        logoUrl: '',
        companyDescription: '',
        yearEstablished: 0,
        totalProjectsCompleted: 0,
        currentProjectsCount: 0,
        stories: [],
        projectsList: [],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 200,
              width: double.infinity,
              child: Stack(
                children: [
                  // Property Image
                  project.galleryImages.isNotEmpty
                      ? Image.network(
                          buildImageUrl(project.galleryImages.first.images),
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: double.infinity,
                                height: 200,
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.06),
                                child: Icon(
                                  Icons.apartment,
                                  color: theme.colorScheme.primary,
                                  size: 40,
                                ),
                              ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 200,
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.06),
                          child: Icon(
                            Icons.apartment,
                            color: theme.colorScheme.primary,
                            size: 40,
                          ),
                        ),
                  // Bookmark Remove Button
                  Positioned(
                    top: 16,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => _removeProjectBookmark(project),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_remove,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.projectName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            developer.developerName,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        project.constructionStatus,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        project.locationDisplay,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatPriceRange(project.priceRangeMin, project.priceRangeMax),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (project.amenities.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: project.amenities.take(4).map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          a.data,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                if (project.amenities.isNotEmpty) const SizedBox(height: 10),
                if (project.configurations.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: project.configurations.take(3).map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${c.name} • ${c.carpetArea} • ${c.price}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => PropertyDetailPopup(
                                  project: project,
                                  developer: developer,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'View Details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              try {
                                final broker = await AuthService.getUserData();
                                final brokerId = broker?['broker_id']
                                    ?.toString();

                                if (brokerId == null) {
                                  CustomSnackBar.show(context, 
                                    message: 'Please log in to add enquiry',
                                    isError: false, 
                                    title: 'Notice'
                                  );
                                  return;
                                }

                                // await AddEnquirySheet.show(
                                //   context,
                                //   projects: [project],
                                //   brokerId: brokerId,
                                //   initialSelectedProjectId: project.id,
                                //   lockProjectSelection: true,
                                //   onCreated: () {
                                //     // Enquiry created successfully - no snackbar needed
                                //   },
                                // );
                              } catch (e) {
                                CustomSnackBar.show(context, message: 'Error: ${e.toString()}', isError: true, title: 'Error');
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tag Clients',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final shareText =
                            '''
            🏢 ${project.projectName}

            📍 Location: ${project.locationDisplay}
            💰 Price: ${_formatPriceRange(project.priceRangeMin, project.priceRangeMax)}
            📊 Status: ${project.constructionStatus.toUpperCase()}
            🏗️ Developer: ${developer.developerName}

            ${project.amenities.isNotEmpty ? '🏠 Amenities: ${project.amenities.take(5).map((a) => a.data).join(', ')}' : ''}
            ''';
                        Clipboard.setData(ClipboardData(text: shareText));
                        CustomSnackBar.show(context, 
                          message: 'Project details copied to clipboard!',
                          isError: false, 
                          title: 'Notice'
                        );
                      },
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.share_outlined,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(Developer developer) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Calculate project stats for this developer
    final projectStats = {
      'total': _bookmarkedProjects
          .where((p) => p.developer == developer.id)
          .length,
      'active': _bookmarkedProjects
          .where(
            (p) =>
                p.developer == developer.id &&
                p.constructionStatus == 'active',
          )
          .length,
      'completed': _bookmarkedProjects
          .where(
            (p) =>
                p.developer == developer.id &&
                p.constructionStatus == 'completed',
          )
          .length,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => DeveloperDetailPopup(
              developer: developer,
              projects: _bookmarkedProjects,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Developer Logo
                  Stack(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: developer.logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  buildImageUrl(developer.logoUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.business_rounded,
                                      color: cs.primary,
                                      size: 32,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.business_rounded,
                                color: cs.primary,
                                size: 32,
                              ),
                      ),
                      // Status indicator
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: developer.isActive
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.cardColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Developer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                developer.developerName,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (developer.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: Colors.green,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'VERIFIED',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: cs.onSurface.withOpacity(0.6),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              developer.contactPerson,
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.business_center_outlined,
                              color: cs.onSurface.withOpacity(0.6),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              developer.companySize,
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.calendar_today_outlined,
                              color: cs.onSurface.withOpacity(0.6),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Est. ${developer.yearEstablished}',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bookmark Remove Button
                  GestureDetector(
                    onTap: () => _removeDeveloperBookmark(developer),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.bookmark_remove,
                        color: Colors.red,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Company description
              if (developer.companyDescription.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    developer.companyDescription,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 16),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total',
                      projectStats['total'].toString(),
                      Icons.home_work_outlined,
                      theme,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: cs.outline.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Active',
                      projectStats['active'].toString(),
                      Icons.trending_up_outlined,
                      theme,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: cs.outline.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Completed',
                      projectStats['completed'].toString(),
                      Icons.check_circle_outline,
                      theme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Specializations
              if (developer.specializations.isNotEmpty) ...[
                Text(
                  'Specializations',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: developer.specializations.take(3).map((spec) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        spec,
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => DeveloperDetailPopup(
                            developer: developer,
                            projects: _bookmarkedProjects,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        // Share functionality
                      },
                      icon: Icon(
                        Icons.share,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    return Column(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

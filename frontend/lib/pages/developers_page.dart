import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/property_detail_popup.dart';
import '../models/developer.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import 'developer_detail_page.dart';
import '../utils.dart';
import '../components/projects/filters/status_filter.dart';
import '../components/projects/filters/amenities_filter.dart';
import '../components/projects/filters/bedrooms_filter.dart';
import '../components/projects/filters/location_range_filter.dart';
import '../components/projects/filters/developer_filter.dart';

class DevelopersPage extends StatefulWidget {
  final String? initialSearchQuery;

  const DevelopersPage({super.key, this.initialSearchQuery});

  @override
  State<DevelopersPage> createState() => _DevelopersPageState();

  // Static method to set search query from external navigation
  static void setSearchQuery(String query) {
    _DevelopersPageState._globalSearchQuery = query;
  }
}

class _DevelopersPageState extends State<DevelopersPage>
    with SingleTickerProviderStateMixin {
  static String? _globalSearchQuery;

  List<Developer> _developers = [];
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  // Merged filter state
  final Set<String> _selectedSpecializations = <String>{};
  final Set<String> _selectedCompanySizes = <String>{};
  bool _verifiedOnly = false;
  bool _activeOnly = false;
  final Set<String> _selectedCertifications = <String>{};
  int? _yearMin;
  int? _yearMax;
  int? _minTotalProjects;
  double? _pPriceMinCr;
  double? _pPriceMaxCr;
  double? _pAreaMinSqft;
  double? _pAreaMaxSqft;
  final Set<int> _pBedrooms = <int>{};
  final Set<String> _pAmenities = <String>{};
  final Set<String> _pDeveloperNames = <String>{};
  final Set<String> _pDeveloperIds = <String>{};
  String? _pSelectedLocationArea;
  final Set<String> _pStatuses = <String>{};
  double? _pLocationRangeKm;

  // Available filter options
  final List<String> _companySizes = ['Small', 'Medium', 'Large'];
  List<String> _allSpecializations = [];
  List<String> _allCertifications = [];
  int _globalYearMin = 0;
  int _globalYearMax = 0;
  int _globalMaxTotalProjects = 0;
  double _pGlobalPriceMinCr = 0;
  double _pGlobalPriceMaxCr = 0;
  double _pGlobalAreaMinSqft = 0;
  double _pGlobalAreaMaxSqft = 0;

  String _devSpecQuery = '';
  String _devCertQuery = '';
  String _pAmenitiesQuery = '';
  String _pDeveloperQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Set initial search query if provided
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
      _searchController.text = widget.initialSearchQuery!;
    } else if (_globalSearchQuery != null) {
      _searchQuery = _globalSearchQuery!;
      _searchController.text = _globalSearchQuery!;
      _globalSearchQuery = null; // Clear after use
    }

    _fetchData();
    // Track developers page view
    AnalyticsService.instance.logScreenView('developers_page');
  }

  void _openProjectFiltersSheet(BuildContext context) {}

  void _computeProjectGlobalBounds() {
    double minPrice = double.infinity;
    double maxPrice = 0;
    double minArea = double.infinity;
    double maxArea = 0;
    for (final p in _projects) {
      final prices = (p.priceRangeMin.toDouble(), p.priceRangeMax.toDouble());
      if (prices.$1 != 0 || prices.$2 != 0) {
        minPrice = prices.$1 < minPrice ? prices.$1 : minPrice;
        maxPrice = prices.$2 > maxPrice ? prices.$2 : maxPrice;
      }
      for (final c in p.configurations) {
        final a = c.carpetArea;
        if (a < minArea) minArea = a;
        if (a > maxArea) maxArea = a;
      }
    }
    if (minPrice == double.infinity) minPrice = 0;
    if (maxPrice == 0) maxPrice = 1; // Default max price if none found
    if (minArea == double.infinity) minArea = 0;
    if (maxArea == 0) maxArea = 1; // Default max area if none found
    _pGlobalPriceMinCr = minPrice;
    _pGlobalPriceMaxCr = maxPrice;
    _pGlobalAreaMinSqft = minArea;
    _pGlobalAreaMaxSqft = maxArea;
    _pPriceMinCr ??= _pGlobalPriceMinCr;
    _pPriceMaxCr ??= _pGlobalPriceMaxCr;
    _pAreaMinSqft ??= _pGlobalAreaMinSqft;
    _pAreaMaxSqft ??= _pGlobalAreaMaxSqft;
  }

  // This function is no longer needed as price range is directly available as min/max integers
  // but keeping it for now in case other parts of the code still rely on string parsing
  (double, double)? _parseProjectPriceToCrRange(String input) {
    // New Project model uses priceRangeMin and priceRangeMax directly.
    // This function is now deprecated or needs to be re-evaluated.
    // For now, return null as it's not applicable directly.
    return null;
  }

  double? _parseSinglePriceToCr(String s) {
    var t = s.replaceAll(',', '').trim().toLowerCase();
    if (t.endsWith('cr')) {
      t = t.replaceAll('cr', '').trim();
      return double.tryParse(t);
    }
    if (t.endsWith('l')) {
      t = t.replaceAll('l', '').trim();
      final v = double.tryParse(t);
      return v == null ? null : v / 100;
    }
    return double.tryParse(t);
  }

  double? _parseAreaSqft(String s) {
    final digits = RegExp(
      r'[0-9]+',
    ).allMatches(s).map((m) => m.group(0)).join();
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  String _formatCr(double value) {
    if (value >= 1) {
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    }
    return (value * 100).toStringAsFixed(0);
  }

  Widget _buildActiveProjectFiltersSummary(ThemeData theme, bool isDark) {
    final List<String> active = [];
    if (_pPriceMinCr != null && _pPriceMinCr != _pGlobalPriceMinCr) {
      active.add('Min Price: ₹${_formatCr(_pPriceMinCr!)} Cr');
    }
    if (_pPriceMaxCr != null && _pPriceMaxCr != _pGlobalPriceMaxCr) {
      active.add('Max Price: ₹${_formatCr(_pPriceMaxCr!)} Cr');
    }
    if (_pAreaMinSqft != null && _pAreaMinSqft != _pGlobalAreaMinSqft) {
      active.add('Min Size: ${_pAreaMinSqft!.toStringAsFixed(0)} sq ft');
    }
    if (_pAreaMaxSqft != null && _pAreaMaxSqft != _pGlobalAreaMaxSqft) {
      active.add('Max Size: ${_pAreaMaxSqft!.toStringAsFixed(0)} sq ft');
    }
    if (_pLocationRangeKm != null) {
      active.add('Within ${_pLocationRangeKm!.toStringAsFixed(0)} km');
    }
    if (_pBedrooms.isNotEmpty) {
      final beds = _pBedrooms.toList()..sort();
      final text = beds.length == 1
          ? '${beds.first}BHK'
          : beds.map((b) => '${b}BHK').join(', ');
      active.add('Bedrooms: $text');
    }
    if (_pStatuses.isNotEmpty) {
      active.add('Status: ${_pStatuses.join(', ')}');
    }
    if (_pAmenities.isNotEmpty) {
      final list = _pAmenities.take(3).join(', ');
      final more = _pAmenities.length > 3
          ? ' +${_pAmenities.length - 3} more'
          : '';
      active.add('Amenities: $list$more');
    }
    if (_pDeveloperNames.isNotEmpty) {
      final list = _pDeveloperNames.take(2).join(', ');
      final more = _pDeveloperNames.length > 2
          ? ' +${_pDeveloperNames.length - 2} more'
          : '';
      active.add('Developers: $list$more');
    }
    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_alt,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Filters (${active.length})',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: active.map((filter) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeveloperFiltersSummary(ThemeData theme, bool isDark) {
    final List<String> active = [];
    if (_selectedCompanySizes.isNotEmpty) {
      active.add('Company: ${_selectedCompanySizes.join(', ')}');
    }
    if (_verifiedOnly) active.add('Verified');
    if (_activeOnly) active.add('Active');
    if (_selectedSpecializations.isNotEmpty) {
      final list = _selectedSpecializations.take(3).join(', ');
      final more = _selectedSpecializations.length > 3
          ? ' +${_selectedSpecializations.length - 3} more'
          : '';
      active.add('Specializations: $list$more');
    }
    if (_selectedCertifications.isNotEmpty) {
      final list = _selectedCertifications.take(3).join(', ');
      final more = _selectedCertifications.length > 3
          ? ' +${_selectedCertifications.length - 3} more'
          : '';
      active.add('Certifications: $list$more');
    }
    if (_yearMin != null && _yearMin != _globalYearMin) {
      active.add('Year ≥ ${_yearMin}');
    }
    if (_yearMax != null && _yearMax != _globalYearMax) {
      active.add('Year ≤ ${_yearMax}');
    }
    if (_minTotalProjects != null && _minTotalProjects! > 0) {
      active.add('Min Projects: $_minTotalProjects');
    }
    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_alt,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Filters (${active.length})',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: active.map((filter) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _projectPriceSizeContent(
    ThemeData theme,
    bool isDark,
    void Function(void Function()) setSheetState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price/Size',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Min - Price',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatCr(_pPriceMinCr ?? _pGlobalPriceMinCr)} Cr',
            style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_pPriceMinCr ?? _pGlobalPriceMinCr).clamp(
                _pGlobalPriceMinCr,
                _pGlobalPriceMaxCr,
              ),
              min: _pGlobalPriceMinCr,
              max: _pGlobalPriceMaxCr,
              onChanged: (v) => setSheetState(() => _pPriceMinCr = v),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Max - Price',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatCr(_pPriceMaxCr ?? _pGlobalPriceMaxCr)} Cr',
            style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_pPriceMaxCr ?? _pGlobalPriceMaxCr).clamp(
                _pGlobalPriceMinCr,
                _pGlobalPriceMaxCr,
              ),
              min: _pGlobalPriceMinCr,
              max: _pGlobalPriceMaxCr,
              onChanged: (v) => setSheetState(() => _pPriceMaxCr = v),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Min - Size',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_pAreaMinSqft ?? _pGlobalAreaMinSqft).toStringAsFixed(0)} (sq. ft.)',
            style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_pAreaMinSqft ?? _pGlobalAreaMinSqft).clamp(
                _pGlobalAreaMinSqft,
                _pGlobalAreaMaxSqft,
              ),
              min: _pGlobalAreaMinSqft,
              max: _pGlobalAreaMaxSqft,
              onChanged: (v) => setSheetState(() => _pAreaMinSqft = v),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Max - Size',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_pAreaMaxSqft ?? _pGlobalAreaMaxSqft).toStringAsFixed(0)} (sq. ft.)',
            style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_pAreaMaxSqft ?? _pGlobalAreaMaxSqft).clamp(
                _pGlobalAreaMinSqft,
                _pGlobalAreaMaxSqft,
              ),
              min: _pGlobalAreaMinSqft,
              max: _pGlobalAreaMaxSqft,
              onChanged: (v) => setSheetState(() => _pAreaMaxSqft = v),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('Fetching developers and projects data...');

      // Fetch both developers and projects in parallel
      final results = await Future.wait([
        DeveloperService.syncDevelopers(forceRefresh: true),
        ProjectService.syncProjects(forceRefresh: true),
      ]);

      final developers = results[0] as List<Developer>;
      final projects = results[1] as List<Project>;

      print('Developers fetched: ${developers.length}');
      print('Projects fetched: ${projects.length}');

      setState(() {
        _developers = developers;
        _projects = projects;
        _isLoading = false;
      });

      _extractSpecializations();
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _extractSpecializations() {
    final specializations = <String>{};
    final certifications = <String>{};
    int yearMin = 9999;
    int yearMax = 0;
    int maxTotal = 0;
    for (final developer in _developers) {
      specializations.addAll(developer.specializations);
      certifications.addAll(developer.certifications);
      yearMin = developer.yearEstablished < yearMin
          ? developer.yearEstablished
          : yearMin;
      yearMax = developer.yearEstablished > yearMax
          ? developer.yearEstablished
          : yearMax;
      // Use visible projects to determine total project count for more accuracy
      final totalForDev = _getDeveloperProjects(developer.id).length;
      if (totalForDev > maxTotal) maxTotal = totalForDev;
    }
    _allSpecializations = specializations.toList()..sort();
    _allCertifications = certifications.toList()..sort();
    _globalYearMin = yearMin == 9999 ? 0 : yearMin;
    _globalYearMax = yearMax;
    _globalMaxTotalProjects = maxTotal;
    _yearMin ??= _globalYearMin;
    _yearMax ??= _globalYearMax;
    _minTotalProjects ??= 0;
  }

  bool _hasActiveFilters() {
    if (_tabController.index == 0) {
      // Projects tab - check project filters only
      return _pLocationRangeKm != null ||
          (_pPriceMinCr != null && _pPriceMinCr != _pGlobalPriceMinCr) ||
          (_pPriceMaxCr != null && _pPriceMaxCr != _pGlobalPriceMaxCr) ||
          (_pAreaMinSqft != null && _pAreaMinSqft != _pGlobalAreaMinSqft) ||
          (_pAreaMaxSqft != null && _pAreaMaxSqft != _pGlobalAreaMaxSqft) ||
          _pBedrooms.isNotEmpty ||
          _pAmenities.isNotEmpty ||
          _pDeveloperNames.isNotEmpty ||
          _pDeveloperIds.isNotEmpty ||
          _pStatuses.isNotEmpty ||
          (_pSelectedLocationArea != null &&
              _pSelectedLocationArea!.isNotEmpty);
    } else {
      // Developers tab - check developer filters only
      return _selectedSpecializations.isNotEmpty ||
          _selectedCompanySizes.isNotEmpty ||
          _verifiedOnly ||
          _activeOnly ||
          _selectedCertifications.isNotEmpty ||
          (_yearMin != null && _yearMin != _globalYearMin) ||
          (_yearMax != null && _yearMax != _globalYearMax) ||
          (_minTotalProjects != null && _minTotalProjects! > 0);
    }
  }

  // Get projects for a specific developer
  List<Project> _getDeveloperProjects(String developerId) {
    return _projects
        .where((project) => project.developer == developerId)
        .toList();
  }

  // Calculate project statistics for a developer
  Map<String, int> _getProjectStats(String developerId) {
    final developerProjects = _getDeveloperProjects(developerId);

    int totalProjects = developerProjects.length;
    int activeProjects = developerProjects
        .where(
          (p) =>
              p.constructionStatus.toLowerCase() == 'active' ||
              p.constructionStatus.toLowerCase() == 'ongoing' ||
              p.constructionStatus.toLowerCase() == 'under_construction',
        )
        .length;
    int completedProjects = developerProjects
        .where(
          (p) =>
              p.constructionStatus.toLowerCase() == 'completed' ||
              p.constructionStatus.toLowerCase() == 'ready_to_move',
        )
        .length;

    return {
      'total': totalProjects,
      'active': activeProjects,
      'completed': completedProjects,
    };
  }

  List<Developer> get _filteredDevelopers {
    return _developers.where(_matchesFilters).toList();
  }

  bool _matchesFilters(Developer developer) {
    // Search query filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      if (!developer.developerName.toLowerCase().contains(query) &&
          !developer.username.toLowerCase().contains(query) &&
          !developer.contactPerson.toLowerCase().contains(query) &&
          !developer.companyDescription.toLowerCase().contains(query)) {
        return false;
      }
    }

    // Specializations filter
    if (_selectedSpecializations.isNotEmpty) {
      final hasMatch = developer.specializations.any(
        (spec) => _selectedSpecializations.contains(spec),
      );
      if (!hasMatch) return false;
    }

    // Company size filter
    if (_selectedCompanySizes.isNotEmpty) {
      if (!_selectedCompanySizes.contains(developer.companySize)) {
        return false;
      }
    }

    // Certifications filter
    if (_selectedCertifications.isNotEmpty) {
      final hasCert = developer.certifications.any(
        (c) => _selectedCertifications.contains(c),
      );
      if (!hasCert) return false;
    }

    // Year established range
    if (_yearMin != null && developer.yearEstablished < _yearMin!) {
      return false;
    }
    if (_yearMax != null && developer.yearEstablished > _yearMax!) {
      return false;
    }

    // Minimum total projects (use actual projects list rather than static field)
    if (_minTotalProjects != null && _minTotalProjects! > 0) {
      final totalProjectsForDev = _getDeveloperProjects(developer.id).length;
      if (totalProjectsForDev < _minTotalProjects!) {
        return false;
      }
    }

    // Verified filter
    if (_verifiedOnly && !developer.isVerified) {
      return false;
    }

    // Active filter
    if (_activeOnly && !developer.isActive) {
      return false;
    }

    return true;
  }

  void _showFiltersSheet(BuildContext context) {
    const kAccent = Color(0xFF675D40);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = {
      'Developer': [
        'Company',
        'Specializations',
        'Certifications',
        'Year/Total',
      ],
      'Project': [
        'Price/Size',
        'Location',
        'Bedrooms',
        'Status',
        'Amenities',
      ],
    };

    String currentFilterType = _tabController.index == 0 ? 'Project' : 'Developer';
    String currentCategory = _tabController.index == 0
        ? categories['Project']!.first
        : categories['Developer']!.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF2F2F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget body;
            if (currentFilterType == 'Developer') {
              if (currentCategory == 'Company') {
                body = _buildCompanyFilter(theme, setSheetState);
              } else if (currentCategory == 'Specializations') {
                body = _buildSpecializationsFilter(theme, setSheetState);
              } else if (currentCategory == 'Certifications') {
                body = _buildCertificationsFilter(theme, setSheetState);
              } else {
                body = _buildYearTotalFilter(theme, setSheetState);
              }
            } else {
              if (currentCategory == 'Price/Size') {
                body = _projectPriceSizeContent(theme, isDark, setSheetState);
              } else if (currentCategory == 'Location') {
                body = LocationRangeFilter(
                  isDark: isDark,
                  options: const [2.0, 5.0, 10.0, 15.0, 25.0, 50.0],
                  selectedRange: _pLocationRangeKm,
                  onChange: (v) => setSheetState(() => _pLocationRangeKm = v),
                );
              } else if (currentCategory == 'Bedrooms') {
                body = BedroomsFilter(
                  isDark: isDark,
                  options: const [1, 2, 3, 4, 5],
                  selectedBedrooms: _pBedrooms,
                  setSheetState: setSheetState,
                );
              } else if (currentCategory == 'Status') {
                body = StatusFilter(
                  isDark: isDark,
                  selectedStatuses: _pStatuses,
                  options: const [
                    'Active',
                    'Under Construction',
                    'Completed',
                    'Planning'
                  ],
                  setSheetState: setSheetState,
                );
              } else {
                body = AmenitiesFilter(
                  isDark: isDark,
                  amenities: (_projects
                      .expand((p) => p.amenities.map((a) => a.data))
                      .toSet()
                      .toList()
                    ..sort()),
                  selectedAmenities: _pAmenities,
                  query: _pAmenitiesQuery,
                  onQueryChanged: (v) =>
                      setSheetState(() => _pAmenitiesQuery = v),
                  setSheetState: setSheetState,
                );
              }
            }

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$currentFilterType Filters',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedSpecializations.clear();
                              _selectedCompanySizes.clear();
                              _verifiedOnly = false;
                              _activeOnly = false;
                              _selectedCertifications.clear();
                              _yearMin = _globalYearMin;
                              _yearMax = _globalYearMax;
                              _minTotalProjects = 0;
                              _pLocationRangeKm = null;
                              _pPriceMinCr = _pGlobalPriceMinCr;
                              _pPriceMaxCr = _pGlobalPriceMaxCr;
                              _pAreaMinSqft = _pGlobalAreaMinSqft;
                              _pAreaMaxSqft = _pGlobalAreaMaxSqft;
                              _pBedrooms.clear();
                              _pAmenities.clear();
                              _pDeveloperNames.clear();
                              _pDeveloperIds.clear();
                              _pStatuses.clear();
                            });
                            setSheetState(() {});
                          },
                          child: const Text('Clear All',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 130,
                          color: isDark ? Colors.grey[850] : Colors.white,
                          child: ListView(
                            children: categories[currentFilterType]!.map((k) {
                              final bool selected = k == currentCategory;
                              return Material(
                                color: selected
                                    ? (isDark
                                        ? kAccent.withOpacity(0.3)
                                        : kAccent.withOpacity(0.1))
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      setSheetState(() => currentCategory = k),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                          left: BorderSide(
                                              color: selected
                                                  ? kAccent
                                                  : Colors.transparent,
                                              width: 3)),
                                    ),
                                    child: Text(k,
                                        style: TextStyle(
                                            fontWeight: selected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: selected ? kAccent : null)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5))
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {});
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompanyFilter(ThemeData theme, void Function(void Function()) setSheetState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Company Size', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _companySizes.map((size) {
              final selected = _selectedCompanySizes.contains(size);
              return FilterChip(
                label: Text(size),
                selected: selected,
                onSelected: (sel) {
                  setState(() {
                    sel ? _selectedCompanySizes.add(size) : _selectedCompanySizes.remove(size);
                  });
                  setSheetState(() {});
                },
                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                checkmarkColor: theme.colorScheme.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Verified Only'),
            value: _verifiedOnly,
            onChanged: (v) {
              setState(() => _verifiedOnly = v ?? false);
              setSheetState(() {});
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            title: const Text('Active Only'),
            value: _activeOnly,
            onChanged: (v) {
              setState(() => _activeOnly = v ?? false);
              setSheetState(() {});
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationsFilter(ThemeData theme, void Function(void Function()) setSheetState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setSheetState(() => _devSpecQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search specializations',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allSpecializations
                .where((s) => _devSpecQuery.isEmpty ? true : s.toLowerCase().contains(_devSpecQuery))
                .map((spec) {
              final selected = _selectedSpecializations.contains(spec);
              return FilterChip(
                label: Text(spec),
                selected: selected,
                onSelected: (sel) {
                  setState(() {
                    sel ? _selectedSpecializations.add(spec) : _selectedSpecializations.remove(spec);
                  });
                  setSheetState(() {});
                },
                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                checkmarkColor: theme.colorScheme.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationsFilter(ThemeData theme, void Function(void Function()) setSheetState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setSheetState(() => _devCertQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search certifications',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allCertifications
                .where((c) => _devCertQuery.isEmpty ? true : c.toLowerCase().contains(_devCertQuery))
                .map((cert) {
              final selected = _selectedCertifications.contains(cert);
              return FilterChip(
                label: Text(cert),
                selected: selected,
                onSelected: (sel) {
                  setState(() {
                    sel ? _selectedCertifications.add(cert) : _selectedCertifications.remove(cert);
                  });
                  setSheetState(() {});
                },
                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                checkmarkColor: theme.colorScheme.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYearTotalFilter(ThemeData theme, void Function(void Function()) setSheetState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Min Year: ${_yearMin ?? _globalYearMin}'),
              Text('Max Year: ${_yearMax ?? _globalYearMax}'),
            ],
          ),
          RangeSlider(
            values: RangeValues((_yearMin ?? _globalYearMin).toDouble(), (_yearMax ?? _globalYearMax).toDouble()),
            min: _globalYearMin.toDouble(),
            max: _globalYearMax.toDouble(),
            onChanged: (values) {
              setSheetState(() {
                _yearMin = values.start.round();
                _yearMax = values.end.round();
              });
            },
          ),
          const SizedBox(height: 24),
          Text('Min Projects: ${_minTotalProjects ?? 0}'),
          Slider(
            value: (_minTotalProjects ?? 0).toDouble(),
            min: 0,
            max: _globalMaxTotalProjects.toDouble(),
            onChanged: (v) => setSheetState(() => _minTotalProjects = v.round()),
          ),
        ],
      ),
    );
  }

  void _shareDeveloper(Developer developer) {
    final shareText =
        '''
🏗️ ${developer.developerName}

👤 Contact: ${developer.contactPerson}
📧 Email: ${developer.contactEmail}
📱 Phone: ${developer.contactPhone}
🏢 Company Size: ${developer.companySize}
🌐 Website: ${developer.websiteUrl}

${developer.specializations.isNotEmpty ? '🔧 Specializations: ${developer.specializations.join(', ')}' : ''}

${developer.certifications.isNotEmpty ? '🏆 Certifications: ${developer.certifications.join(', ')}' : ''}

📝 About: ${developer.companyDescription}

${developer.isVerified ? '✅ Verified Developer' : ''}
${developer.isActive ? '🟢 Active' : ''}

Download HomeSol App to connect with developers and explore projects!

#HomeSol #RealEstate #Developer #${developer.developerName.replaceAll(' ', '')}
''';

    // Copy to clipboard and show message
    Clipboard.setData(ClipboardData(text: shareText));
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Developer details copied to clipboard!'),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'Share',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: shareText));
          },
        ),
      ),
    );
  }

  Widget _buildTagAllProjectsButton(ThemeData theme) {
    // Only show if there are filtered projects and filters are applied
    if (_filteredProjects.isEmpty ||
        _filteredProjects.length == _projects.length) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 12),
      child: ElevatedButton(
        onPressed: () async {
          try {
            final broker = await AuthService.getUserData();
            final brokerId = broker?['broker_id']?.toString();

            if (brokerId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please log in to add enquiry'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // await AddEnquirySheet.show(
            //   context,
            //   projects: _filteredProjects,
            //   brokerId: brokerId,
            //   lockProjectSelection: true,
            //   onCreated: () {
            //     // Enquiry created successfully - no snackbar needed
            //   },
            // );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_outlined, size: 16),
            const SizedBox(width: 4),
            Text(
              'Tag Client to All (${_filteredProjects.length})',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectsTab(theme, isDark),
                _buildDevelopersTab(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterCard(ThemeData theme, bool isDark) {
    const kAccent = Color(0xFF675D40);
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _tabController.index == 0 ? 'Projects' : 'Developers',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_tabController.index == 0) _buildTagAllProjectsButton(theme),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: _tabController.index == 0 ? 'Search projects...' : 'Search developers...',
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
                onTap: () => _showFiltersSheet(context),
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
          const SizedBox(height: 16),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.apartment_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Projects'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.groups_2_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Developers'),
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

  Widget _buildDevelopersTab(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 3, // Display a few skeleton cards
        itemBuilder: (context, index) => const _DeveloperCardSkeleton(),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_developers.isEmpty) {
      return const Center(child: Text('No developers found'));
    }
    final _filteredDevelopers = _developers.where(_matchesFilters).toList();
    if (_filteredDevelopers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No developers match your filters'),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedSpecializations.clear();
                  _selectedCompanySizes.clear();
                  _verifiedOnly = false;
                  _activeOnly = false;
                });
              },
              child: const Text('Clear Filters'),
            )
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredDevelopers.length,
      itemBuilder: (context, index) {
        final developer = _filteredDevelopers[index];
        final developerProjects = _getDeveloperProjects(developer.id);
        final projectStats = _getProjectStats(developer.id);
        return GestureDetector(
          onTap: () {
            // Log developer view event
            AnalyticsService.instance.logDeveloperView(
              developer.id.toString(),
              developer.developerName,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DeveloperDetailPage(
                  developer: developer,
                  projects: developerProjects,
                ),
              ),
            );
          },
          child: _DeveloperCard(
            developer: developer,
            totalProjects: projectStats['total'] ?? 0,
            activeProjects: projectStats['active'] ?? 0,
            onShare: () => _shareDeveloper(developer),
          ),
        );
      },
    );
  }

  // Helper method to get the list of filtered projects
  List<Project> get _filteredProjects {
    Iterable<Project> list = _projects;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final developerNames = Map.fromEntries(
        _developers.map((d) => MapEntry(d.id, d.developerName.toLowerCase())),
      );
      list = list.where(
        (p) =>
            p.projectName.toLowerCase().contains(q) ||
            (developerNames[p.developer]?.contains(q) ?? false) ||
            p.locationDisplay.toLowerCase().contains(q),
      );
    }

    if (_pDeveloperIds.isNotEmpty) {
      list = list.where((p) => _pDeveloperIds.contains(p.developer));
    }

    // Statuses
    if (_pStatuses.isNotEmpty) {
      list = list.where(
        (p) {
      for (final label in _pStatuses) {
        if (p.constructionStatus.toLowerCase() == label.toLowerCase()) {
          return true;
        }
      }
      return false;
    });
    }

    // Amenities
    if (_pAmenities.isNotEmpty) {
      list = list.where(
        (p) => _pAmenities.every(
          (a) =>
              p.amenities.map((e) => e.data.toLowerCase()).contains(a.toLowerCase()),
        ),
      );
    }

    // Bedrooms
    if (_pBedrooms.isNotEmpty) {
      list = list.where(
        (p) => p.configurations.any(
          (conf) {
          final beds = int.tryParse(conf.name.replaceAll(RegExp(r'[^0-9]'),''));
          return beds != null && _pBedrooms.contains(beds);
        }),
      );
    }

    // Price
    if (_pPriceMinCr != null || _pPriceMaxCr != null) {
      list = list.where((p) {
        final minPrice = p.priceRangeMin.toDouble();
        final maxPrice = p.priceRangeMax.toDouble();
        if (_pPriceMinCr != null && maxPrice < _pPriceMinCr!) return false;
        if (_pPriceMaxCr != null && minPrice > _pPriceMaxCr!) return false;
        return true;
      });
    }

    // Area
    if (_pAreaMinSqft != null || _pAreaMaxSqft != null) {
      list = list.where((p) {
        if (p.configurations.isEmpty) return false;
        double minArea = double.infinity;
        double maxArea = 0;
        for (final conf in p.configurations) {
          final a = _parseAreaSqft(conf.carpetArea.toString());
          if (a == null) continue;
          if (a < minArea) minArea = a;
          if (a > maxArea) maxArea = a;
        }
        if (_pAreaMaxSqft != null &&
            minArea > _pAreaMaxSqft!) {
          return false;
        }
        if (_pAreaMinSqft != null &&
            maxArea < _pAreaMinSqft!) {
          return false;
        }
        return true;
      });
    }

    // Location
    if (_pSelectedLocationArea != null && _pSelectedLocationArea!.isNotEmpty) {
      final loc = _pSelectedLocationArea!.toLowerCase();
      list = list.where((p) => p.locationDisplay.toLowerCase().contains(loc));
    }

    return list.toList();
  }

  Widget _buildProjectsTab(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 3, // Display a few skeleton cards
        itemBuilder: (context, index) => const _ProjectCardSkeleton(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_projects.isEmpty) {
      return const Center(
        child: Text('No projects found.'),
      );
    }

    // Use a getter to access the filtered list
    final filteredProjects = _filteredProjects;

    if (filteredProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No projects match your filters.'),
            TextButton(
              onPressed: () {
                setState(() {
                  _pLocationRangeKm = null;
                  _pPriceMinCr = _pGlobalPriceMinCr;
                  _pPriceMaxCr = _pGlobalPriceMaxCr;
                  _pAreaMinSqft = _pGlobalAreaMinSqft;
                  _pAreaMaxSqft = _pGlobalAreaMaxSqft;
                  _pBedrooms.clear();
                  _pAmenities.clear();
                  _pDeveloperNames.clear();
                  _pDeveloperIds.clear();
                  _pStatuses.clear();
                  _pSelectedLocationArea = null;
                  _pAmenitiesQuery = '';
                  _pDeveloperQuery = '';
                });
              },
              child: const Text('Clear Filters'),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: filteredProjects.length,
        itemBuilder: (context, index) {
          final project = filteredProjects[index];
          final dev = _developers.firstWhere(
            (d) => d.id == project.developer,
            orElse: () => Developer(
              id: '',
              createdAt: '',
              updatedAt: '',
              username: '',
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
          return _ProjectCard(
            project: project,
            developer: dev,
          );
        },
      ),
    );
  }
}

// Separate card for developer to manage complexity
class _DeveloperCard extends StatelessWidget {
  final Developer developer;
  final int totalProjects;
  final int activeProjects;
  final VoidCallback onShare;

  const _DeveloperCard({
    required this.developer,
    required this.totalProjects,
    required this.activeProjects,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeveloperDetailPage(developer: developer, projects: []))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(buildImageUrl(developer.logoUrl)),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        developer.developerName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Estd. ${developer.yearEstablished}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (developer.isVerified)
                  const Icon(Icons.verified, color: kAccent, size: 20),
                IconButton(onPressed: onShare, icon: const Icon(Icons.share, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Projects', totalProjects.toString()),
                _buildStat('Active Projects', activeProjects.toString()),
                _buildStat('Completed', (totalProjects - activeProjects).toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

class _DeveloperCardSkeleton extends StatelessWidget {
  const _DeveloperCardSkeleton({super.key});

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
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: skeletonColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 18, color: skeletonColor),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 12, color: skeletonColor),
                  ],
                ),
              ),
              Container(width: 20, height: 20, color: skeletonColor),
              const SizedBox(width: 8),
              Container(width: 24, height: 24, color: skeletonColor),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatSkeleton(skeletonColor),
              _buildStatSkeleton(skeletonColor),
              _buildStatSkeleton(skeletonColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSkeleton(Color? color) {
    return Column(
      children: [
        Container(width: 40, height: 18, color: color),
        const SizedBox(height: 6),
        Container(width: 60, height: 12, color: color),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final Developer? developer;

  const _ProjectCard({required this.project, this.developer});

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (context) => PropertyDetailPopup(project: project, developer: developer)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
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
            SizedBox(
              height: 180,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  buildImageUrl(project.galleryImages.first.images),
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => Container(color: Colors.grey[200]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.projectName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  if (developer != null)
                  Text(
                    'by ${developer!.developerName}',
                    style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          project.locationDisplay,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(kAccent, Icons.construction, project.constructionStatus),
                      _buildInfoChip(kAccent, Icons.business, project.propertyType),
                      _buildInfoChip(kAccent, Icons.event, project.possessionDate),
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

  Widget _buildInfoChip(Color color, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _ProjectCardSkeleton extends StatelessWidget {
  const _ProjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color? skeletonColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          // Image Section Skeleton
          SizedBox(
            height: 180,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(color: skeletonColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project Name Skeleton
                Container(
                  width: 200,
                  height: 18,
                  color: skeletonColor,
                ),
                const SizedBox(height: 8),
                // Developer Name Skeleton
                Container(
                  width: 150,
                  height: 14,
                  color: skeletonColor,
                ),
                const SizedBox(height: 8),
                // Location Skeleton
                Row(
                  children: [
                    Container(width: 14, height: 14, color: skeletonColor),
                    const SizedBox(width: 4),
                    Container(width: 100, height: 12, color: skeletonColor),
                  ],
                ),
                const SizedBox(height: 12),
                // Info Chips Skeleton
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChipSkeleton(skeletonColor),
                    _buildChipSkeleton(skeletonColor),
                    _buildChipSkeleton(skeletonColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSkeleton(Color? color) {
    return Container(
      width: 80,
      height: 25,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
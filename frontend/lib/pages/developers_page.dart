import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/components/cached_image.dart';
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
  final String? developerId;
  final String? designation;

  const DevelopersPage({
    super.key,
    this.initialSearchQuery,
    this.developerId,
    this.designation,
  });

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
    const kAccent = Color(0xFF675D40);

    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: kAccent.withOpacity(0.7),
      inactiveTrackColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
      thumbColor: kAccent,
      overlayColor: kAccent.withOpacity(0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    );

    Widget _rangeRow(String leftLabel, String leftVal, String rightLabel, String rightVal) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(leftLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(leftVal, style: TextStyle(fontSize: 14, color: kAccent, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey.shade400),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rightLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(rightVal, style: TextStyle(fontSize: 14, color: kAccent, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Price Section ──
          Text('Price Range', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          _rangeRow(
            'Min Price',
            '₹${_formatCr(_pPriceMinCr ?? _pGlobalPriceMinCr)} Cr',
            'Max Price',
            '₹${_formatCr(_pPriceMaxCr ?? _pGlobalPriceMaxCr)} Cr',
          ),
          const SizedBox(height: 8),

          SliderTheme(
            data: sliderTheme,
            child: RangeSlider(
              values: RangeValues(
                (_pPriceMinCr ?? _pGlobalPriceMinCr).clamp(_pGlobalPriceMinCr, _pGlobalPriceMaxCr),
                (_pPriceMaxCr ?? _pGlobalPriceMaxCr).clamp(_pGlobalPriceMinCr, _pGlobalPriceMaxCr),
              ),
              min: _pGlobalPriceMinCr,
              max: _pGlobalPriceMaxCr,
              onChanged: (v) => setSheetState(() {
                _pPriceMinCr = v.start;
                _pPriceMaxCr = v.end;
              }),
            ),
          ),

          const SizedBox(height: 20),

          // ── Size Section ──
          Text('Size Range', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          _rangeRow(
            'Min Size',
            '${(_pAreaMinSqft ?? _pGlobalAreaMinSqft).toStringAsFixed(0)} sq.ft',
            'Max Size',
            '${(_pAreaMaxSqft ?? _pGlobalAreaMaxSqft).toStringAsFixed(0)} sq.ft',
          ),
          const SizedBox(height: 8),

          SliderTheme(
            data: sliderTheme,
            child: RangeSlider(
              values: RangeValues(
                (_pAreaMinSqft ?? _pGlobalAreaMinSqft).clamp(_pGlobalAreaMinSqft, _pGlobalAreaMaxSqft),
                (_pAreaMaxSqft ?? _pGlobalAreaMaxSqft).clamp(_pGlobalAreaMinSqft, _pGlobalAreaMaxSqft),
              ),
              min: _pGlobalAreaMinSqft,
              max: _pGlobalAreaMaxSqft,
              onChanged: (v) => setSheetState(() {
                _pAreaMinSqft = v.start;
                _pAreaMaxSqft = v.end;
              }),
            ),
          ),
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

      final List<Developer> developers = results[0] as List<Developer>;
      final List<Project> projects = results[1] as List<Project>;

      List<Developer> filteredDevelopers = developers;
      List<Project> filteredProjects = projects;

      final isDeveloper = (widget.designation?.toLowerCase() ?? '').trim() == 'property developer';

      if (isDeveloper) {
        if (widget.developerId != null) {
          filteredDevelopers = developers.where((d) => d.id == widget.developerId).toList();
          final dev = filteredDevelopers.isNotEmpty ? filteredDevelopers.first : null;
          if (dev != null) {
            final projectIds = dev.projectsList.map((p) => p.project).toSet();
            filteredProjects = projects.where((p) => projectIds.contains(p.id)).toList();
          } else {
            filteredProjects = [];
          }
        } else {
          // If it's a developer but no developerId provided/found yet
          filteredDevelopers = [];
          filteredProjects = [];
        }
      } else if (widget.developerId != null) {
        // Handle case where developerId is passed for other reasons (not common here)
        filteredDevelopers = developers.where((d) => d.id == widget.developerId).toList();
        final dev = filteredDevelopers.isNotEmpty ? filteredDevelopers.first : null;
        if (dev != null) {
          final projectIds = dev.projectsList.map((p) => p.project).toSet();
          filteredProjects = projects.where((p) => projectIds.contains(p.id)).toList();
        } else {
          filteredProjects = [];
        }
      }

      print('Developers fetched: ${filteredDevelopers.length}');
      print('Projects fetched: ${filteredProjects.length}');

      setState(() {
        _developers = filteredDevelopers;
        _projects = filteredProjects;
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget body;
            if (currentFilterType == 'Developer') {
              if (currentCategory == 'Company') {
                body = _buildCompanyFilter(theme, isDark, setSheetState);
              } else if (currentCategory == 'Specializations') {
                body = _buildSpecializationsFilter(theme, isDark, setSheetState);
              } else if (currentCategory == 'Certifications') {
                body = _buildCertificationsFilter(theme, isDark, setSheetState);
              } else {
                body = _buildYearTotalFilter(theme, isDark, setSheetState);
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
                  options: const ['Active', 'Under Construction', 'Completed', 'Planning'],
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
                  onQueryChanged: (v) => setSheetState(() => _pAmenitiesQuery = v),
                  setSheetState: setSheetState,
                );
              }
            }

            final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
            final sidebarBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7F5F0);

            const devLabels = {
              'Company': 'Company',
              'Specializations': 'Specializ.',
              'Certifications': 'Certific.',
              'Year/Total': 'Year/Total',
            };
            const projLabels = {
              'Price/Size': 'Price/Size',
              'Location': 'Location',
              'Bedrooms': 'Bedrooms',
              'Status': 'Status',
              'Amenities': 'Amenities',
            };
            final labelMap = currentFilterType == 'Developer' ? devLabels : projLabels;
            final catList = categories[currentFilterType]!;

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // ── Handle bar ──
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),

                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.tune_rounded, color: kAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$currentFilterType Filters',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                              Text(
                                _hasActiveFilters() ? 'Filters applied' : 'No filters applied',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _hasActiveFilters() ? kAccent : Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Clear All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 0.5),

                  // ── Sidebar + Content ──
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sidebar
                        Container(
                          width: 148,
                          decoration: BoxDecoration(
                            color: sidebarBg,
                            border: Border(right: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, width: 1)),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            children: catList.map((k) {
                              final bool selected = k == currentCategory;
                              final String label = labelMap[k] ?? k;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setSheetState(() => currentCategory = k),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected ? (isDark ? kAccent.withOpacity(0.22) : const Color(0xFFF0EDE5)) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 160),
                                        width: 3, height: 18,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: selected ? kAccent : Colors.transparent,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected ? kAccent : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                                child: Text(
                                  currentCategory,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              Expanded(child: body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom Bar ──
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
                            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: () { setState(() {}); Navigator.pop(context); },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccent,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: kAccent.withOpacity(0.4),
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

  Widget _buildCompanyFilter(ThemeData theme, bool isDark, void Function(void Function()) setSheetState) {
    const kAccent = Color(0xFF675D40);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Company Size', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _companySizes.map((size) {
              final selected = _selectedCompanySizes.contains(size);
              return GestureDetector(
                onTap: () {
                  setState(() => selected ? _selectedCompanySizes.remove(size) : _selectedCompanySizes.add(size));
                  setSheetState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? kAccent.withOpacity(isDark ? 0.25 : 0.1) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? kAccent.withOpacity(0.5) : Colors.transparent, width: 1.5),
                  ),
                  child: Text(size, style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? kAccent : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ...([
            ('Verified Only', _verifiedOnly, (bool v) { setState(() => _verifiedOnly = v); setSheetState(() {}); }),
            ('Active Only', _activeOnly,   (bool v) { setState(() => _activeOnly = v);   setSheetState(() {}); }),
          ].map((item) {
            final label = item.$1;
            final isChecked = item.$2;
            final onChanged = item.$3;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!isChecked),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: isChecked ? kAccent.withOpacity(isDark ? 0.2 : 0.07) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: isChecked ? kAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: isChecked ? kAccent : (isDark ? Colors.grey.shade600 : Colors.grey.shade300), width: 1.5),
                    ),
                    child: isChecked ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Text(label, style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                    color: isChecked ? (isDark ? Colors.white : const Color(0xFF3D3420)) : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                  ))),
                  if (isChecked) Icon(Icons.check_circle_rounded, size: 15, color: kAccent.withOpacity(0.5)),
                ]),
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildSpecializationsFilter(ThemeData theme, bool isDark, void Function(void Function()) setSheetState) {
    const kAccent = Color(0xFF675D40);
    final filtered = _allSpecializations
        .where((s) => _devSpecQuery.isEmpty ? true : s.toLowerCase().contains(_devSpecQuery))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            onChanged: (v) => setSheetState(() => _devSpecQuery = v.trim().toLowerCase()),
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search specializations...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
              filled: true, fillColor: Colors.transparent,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      Expanded(child: filtered.isEmpty
        ? Center(child: Text('No results found', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final spec = filtered[i];
              final selected = _selectedSpecializations.contains(spec);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { setState(() => selected ? _selectedSpecializations.remove(spec) : _selectedSpecializations.add(spec)); setSheetState(() {}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? kAccent.withOpacity(isDark ? 0.2 : 0.07) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: selected ? kAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: selected ? kAccent : (isDark ? Colors.grey.shade600 : Colors.grey.shade300), width: 1.5),
                      ),
                      child: selected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Text(spec, style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? (isDark ? Colors.white : const Color(0xFF3D3420)) : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                    ))),
                    if (selected) Icon(Icons.check_circle_rounded, size: 15, color: kAccent.withOpacity(0.5)),
                  ]),
                ),
              );
            },
          ),
      ),
    ]);
  }

  Widget _buildCertificationsFilter(ThemeData theme, bool isDark, void Function(void Function()) setSheetState) {
    const kAccent = Color(0xFF675D40);
    final filtered = _allCertifications
        .where((c) => _devCertQuery.isEmpty ? true : c.toLowerCase().contains(_devCertQuery))
        .toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            onChanged: (v) => setSheetState(() => _devCertQuery = v.trim().toLowerCase()),
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search certifications...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
              filled: true, fillColor: Colors.transparent,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      Expanded(child: filtered.isEmpty
        ? Center(child: Text('No certifications found', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final cert = filtered[i];
              final selected = _selectedCertifications.contains(cert);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { setState(() => selected ? _selectedCertifications.remove(cert) : _selectedCertifications.add(cert)); setSheetState(() {}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? kAccent.withOpacity(isDark ? 0.2 : 0.07) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: selected ? kAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: selected ? kAccent : (isDark ? Colors.grey.shade600 : Colors.grey.shade300), width: 1.5),
                      ),
                      child: selected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Text(cert, style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? (isDark ? Colors.white : const Color(0xFF3D3420)) : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                    ))),
                    if (selected) Icon(Icons.check_circle_rounded, size: 15, color: kAccent.withOpacity(0.5)),
                  ]),
                ),
              );
            },
          ),
      ),
    ]);
  }

  Widget _buildYearTotalFilter(ThemeData theme, bool isDark, void Function(void Function()) setSheetState) {
    const kAccent = Color(0xFF675D40);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Year Established', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildYearBadge('From', (_yearMin ?? _globalYearMin).toString(), kAccent, isDark),
            Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey.shade400),
            _buildYearBadge('To', (_yearMax ?? _globalYearMax).toString(), kAccent, isDark),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kAccent.withOpacity(0.7),
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: kAccent,
            overlayColor: kAccent.withOpacity(0.12),
            trackHeight: 4,
          ),
          child: RangeSlider(
            values: RangeValues((_yearMin ?? _globalYearMin).toDouble(), (_yearMax ?? _globalYearMax).toDouble()),
            min: _globalYearMin.toDouble(),
            max: _globalYearMax.toDouble(),
            onChanged: (values) => setSheetState(() {
              _yearMin = values.start.round();
              _yearMax = values.end.round();
            }),
          ),
        ),
        const SizedBox(height: 24),
        Text('Minimum Projects', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.business_center_rounded, size: 16, color: kAccent),
            const SizedBox(width: 8),
            Text('${_minTotalProjects ?? 0} projects minimum',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kAccent)),
          ]),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kAccent.withOpacity(0.7),
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: kAccent,
            overlayColor: kAccent.withOpacity(0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: (_minTotalProjects ?? 0).toDouble(),
            min: 0,
            max: _globalMaxTotalProjects.toDouble(),
            onChanged: (v) => setSheetState(() => _minTotalProjects = v.round()),
          ),
        ),
      ]),
    );
  }

  Widget _buildYearBadge(String label, String value, Color accent, bool isDark) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: accent.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
      ),
    ]);
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
    final bool hasFilters = _hasActiveFilters();
    final isProjectTab = _tabController.index == 0;
    final displayCount = isProjectTab
        ? _filteredProjects.length
        : _filteredDevelopers.length;
    final totalCount = isProjectTab ? _projects.length : _developers.length;

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
                      isProjectTab ? 'Projects' : 'Developers',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoading
                          ? 'Loading...'
                          : '$displayCount of $totalCount shown',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isProjectTab) _buildTagAllProjectsButton(theme),
              const SizedBox(width: 8),
              _buildHeaderIconBtn(
                icon: Icons.refresh_rounded,
                onTap: _fetchData,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Search + Filter ──
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
                      hintText: isProjectTab ? 'Search projects...' : 'Search developers...',
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
              const SizedBox(width: 10),
              // Filter button with active badge
              GestureDetector(
                onTap: () => _showFiltersSheet(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasFilters ? kAccent : (isDark ? Colors.grey[800] : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: hasFilters
                            ? kAccent.withOpacity(0.35)
                            : Colors.black.withOpacity(0.06),
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
                        color: hasFilters ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                        size: 22,
                      ),
                      if (hasFilters)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Tab Bar ──
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
                      Icon(Icons.apartment_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Projects'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.groups_2_rounded, size: 16),
                      SizedBox(width: 6),
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

  Widget _buildHeaderIconBtn({required IconData icon, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 19, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
      ),
    );
  }

  Widget _buildDevelopersTab(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                 designation: widget.designation,
               ),
             ),
            );
            },
            child: _DeveloperCard(
            developer: developer,
            totalProjects: projectStats['total'] ?? 0,
            activeProjects: projectStats['active'] ?? 0,
            onShare: () => _shareDeveloper(developer),
            designation: widget.designation,
            ),        );
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
            designation: widget.designation,
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
  final String? designation;

  const _DeveloperCard({
    required this.developer,
    required this.totalProjects,
    required this.activeProjects,
    required this.onShare,
    this.designation,
  });

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeveloperDetailPage(
            developer: developer,
            projects: [],
            designation: designation,
          ),
        ),
      ),
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
                ClipOval(
                  child: CachedImage(
                    imageUrl: buildImageUrl(developer.logoUrl),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
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
  final String? designation;

  const _ProjectCard({required this.project, this.developer, this.designation});

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (context) => PropertyDetailPopup(project: project, developer: developer, designation: designation)),      child: Container(
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
              child: CachedImage(
                imageUrl: buildImageUrl(project.galleryImages.first.images),
                fit: BoxFit.cover,
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
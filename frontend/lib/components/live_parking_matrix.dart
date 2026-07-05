import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import '../models/property_parking.dart';
import '../models/property_unit.dart';
import '../services/apis/projects/property_parking_service.dart';
import '../services/apis/projects/property_unit_service.dart';
import '../models/lead.dart';
import '../services/apis/leads/lead_service.dart';

class LiveParkingMatrix extends StatefulWidget {
  final String projectId;
  final String? designation;

  const LiveParkingMatrix({
    super.key,
    required this.projectId,
    this.designation,
  });

  @override
  State<LiveParkingMatrix> createState() => _LiveParkingMatrixState();
}

class _LiveParkingMatrixState extends State<LiveParkingMatrix> {
  late Future<List<PropertyParking>> _parkingFuture;
  String? _filterStatus;
  
  // Track which levels are expanded. Default to first one being open.
  final Map<String, bool> _expandedLevels = {};

  @override
  void initState() {
    super.initState();
    _refreshParking();
  }

  void _refreshParking() {
    setState(() {
      _parkingFuture = PropertyParkingService.fetchPropertyParkings(widget.projectId);
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available': return const Color(0xFF4CAF50);
      case 'Hold': return const Color(0xFFFF9800);
      case 'Sold': return const Color(0xFFF44336);
      default: return Colors.blueGrey;
    }
  }

  void _showParkingDetails(PropertyParking parking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ParkingDetailsBottomSheet(
          parking: parking,
          designation: widget.designation,
          onStatusUpdated: () {
            _refreshParking();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PropertyParking>>(
      future: _parkingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                TextButton(onPressed: _refreshParking, child: const Text('Retry')),
              ],
            ),
          );
        }

        final parkings = snapshot.data ?? [];
        if (parkings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('No parking units found for this project'),
            ),
          );
        }

        // Process data: Group by level
        final Map<String, List<PropertyParking>> groupedByLevel = {};
        for (final p in parkings) {
          groupedByLevel.putIfAbsent(p.level, () => []).add(p);
        }

        final sortedLevels = groupedByLevel.keys.toList()
          ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));

        for (var level in sortedLevels) {
          groupedByLevel[level]!.sort((a, b) => a.parkingNumber.compareTo(b.parkingNumber));
        }
        
        // Initialize expanded state for newly loaded levels
        for (int i = 0; i < sortedLevels.length; i++) {
           _expandedLevels.putIfAbsent(sortedLevels[i], () => i == 0); // Open first by default
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControls(),
            const SizedBox(height: 20),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: sortedLevels.map((level) => _buildExpandableLevelSection(level, groupedByLevel[level]!)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Available', 'Available'),
                const SizedBox(width: 8),
                _buildFilterChip('Hold', 'Hold'),
                const SizedBox(width: 8),
                _buildFilterChip('Sold', 'Sold'),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Available', const Color(0xFF4CAF50)),
              _buildLegendItem('Hold', const Color(0xFFFF9800)),
              _buildLegendItem('Sold', const Color(0xFFF44336)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _filterStatus == status;
    final color = status == null ? const Color(0xFF675D40) : _getStatusColor(status);
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = selected ? status : null);
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.blueGrey[800],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildExpandableLevelSection(String level, List<PropertyParking> parkings) {
    final isExpanded = _expandedLevels[level] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedLevels[level] = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF675D40).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.layers, size: 20, color: Color(0xFF675D40)),
              ),
              const SizedBox(width: 16),
              Text(
                'Level $level',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF2C3E50)),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${parkings.length} Spots',
                  style: TextStyle(color: Colors.blueGrey[700], fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.blueGrey[400],
              ),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.start,
                children: parkings.map((p) => _buildParkingCard(p)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingCard(PropertyParking p) {
    final bool isHighlighted = _filterStatus == null || p.parkingStatus == _filterStatus;
    
    final color = _getStatusColor(p.parkingStatus);
    final isLinked = p.linkedUnit != null && p.linkedUnit!.isNotEmpty;
    
    IconData typeIcon = Icons.local_parking;
    if (p.parkingType.toLowerCase().contains('cover')) typeIcon = Icons.roofing;
    else if (p.parkingType.toLowerCase().contains('open')) typeIcon = Icons.wb_sunny_outlined;
    else if (p.parkingType.toLowerCase().contains('mech')) typeIcon = Icons.settings_suggest;
    
    return GestureDetector(
      onTap: () => _showParkingDetails(p),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isHighlighted ? 1.0 : 0.4,
        child: Container(
          width: 105,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            boxShadow: [
              if (isHighlighted)
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(typeIcon, size: 16, color: Colors.blueGrey[400]),
                  if (isLinked)
                    Icon(Icons.link, size: 16, color: color)
                  else
                    const SizedBox(width: 16),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                p.parkingNumber,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: color.withOpacity(0.9),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.parkingStatus,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParkingDetailsBottomSheet extends StatefulWidget {
  final PropertyParking parking;
  final VoidCallback onStatusUpdated;
  final String? designation;

  const ParkingDetailsBottomSheet({
    required this.parking,
    required this.onStatusUpdated,
    this.designation,
  });

  @override
  State<ParkingDetailsBottomSheet> createState() => _ParkingDetailsBottomSheetState();
}

class _ParkingDetailsBottomSheetState extends State<ParkingDetailsBottomSheet> {
  late String _currentStatus;
  bool _isUpdating = false;
  
  List<PropertyUnit> _unitOptions = [];
  bool _isUnitsLoading = false;
  final TextEditingController _unitSearchController = TextEditingController();

  PropertyUnit? _linkedUnitObj;
  Future<Lead?>? _linkedLeadFuture;
  final Map<String, Future<Lead?>> _leadFuturesCache = {};

  Future<Lead?> _getLeadFuture(String leadId) {
    if (!_leadFuturesCache.containsKey(leadId)) {
      _leadFuturesCache[leadId] = LeadService.fetchLead(leadId);
    }
    return _leadFuturesCache[leadId]!;
  }

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.parking.parkingStatus;
    _fetchUnits();
  }
  
  @override
  void dispose() {
    _unitSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnits() async {
    setState(() => _isUnitsLoading = true);
    try {
      final units = await PropertyUnitService.fetchPropertyUnits(widget.parking.project);
      
      PropertyUnit? linkedU;
      if (widget.parking.linkedUnit != null && widget.parking.linkedUnit!.isNotEmpty) {
        final matches = units.where((u) => u.name == widget.parking.linkedUnit);
        linkedU = matches.isNotEmpty ? matches.first : null;
        print('🔍 Parking linked to: ${widget.parking.linkedUnit}. Found unit: ${linkedU?.name}, Lead: ${linkedU?.clientName}');
      }

      if (mounted) {
        setState(() {
          _unitOptions = units;
          _linkedUnitObj = linkedU;
          if (_linkedUnitObj?.clientName != null && _linkedUnitObj!.clientName!.isNotEmpty) {
            _linkedLeadFuture = LeadService.fetchLead(_linkedUnitObj!.clientName!);
          } else {
            _linkedLeadFuture = null;
          }
          _isUnitsLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching units for parking details: $e');
      if (mounted) setState(() => _isUnitsLoading = false);
    }
  }

  Future<void> _updateStatus(String? newStatus) async {
    if (newStatus == null || newStatus == _currentStatus) return;

    setState(() => _isUpdating = true);

    final success = await PropertyParkingService.updateParkingStatus(
      widget.parking.name,
      newStatus,
    );

    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (success) {
          _currentStatus = newStatus;
        }
      });

      if (success) {
        widget.onStatusUpdated();
        Navigator.pop(context);
        CustomSnackBar.show(context, message: 'Status updated successfully');
      } else {
        CustomSnackBar.show(context, message: 'Failed to update status', isError: true);
      }
    }
  }

  Future<void> _linkUnit(String unitId) async {
    setState(() => _isUpdating = true);
    try {
      bool success = await PropertyParkingService.linkUnitToParking(widget.parking.name, unitId);
      
      if (success) {
        final newStatus = unitId.isEmpty ? 'Available' : 'Hold';
        success = await PropertyParkingService.updateParkingStatus(widget.parking.name, newStatus);
      }

      if (mounted) {
        if (success) {
          widget.onStatusUpdated();
          Navigator.pop(context);
          CustomSnackBar.show(context, message: unitId.isEmpty 
                  ? 'Unit unlinked and parking marked Available' 
                  : 'Unit linked and parking marked Hold');
        } else {
          setState(() => _isUpdating = false);
          CustomSnackBar.show(context, message: 'Operation failed', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        CustomSnackBar.show(context, message: 'Error: $e', isError: true);
      }
    }
  }

  void _showUnitSearchPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = _unitSearchController.text.toLowerCase();
            final filteredUnits = _unitOptions.where((u) {
              return u.flatNo.toLowerCase().contains(query) || u.name.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Select Unit to Link',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _unitSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search by flat no or name...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                  ),
                  Expanded(
                    child: _isUnitsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              if (query.isEmpty)
                                ListTile(
                                  leading: const Icon(Icons.link_off),
                                  title: const Text('Remove Linked Unit'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _linkUnit('');
                                  },
                                ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filteredUnits.length,
                                  itemBuilder: (context, index) {
                                    final u = filteredUnits[index];
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      title: Row(
                                        children: [
                                          Text('Flat ${u.flatNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const Spacer(),
                                          if (u.clientName != null && u.clientName!.isNotEmpty)
                                            Flexible(
                                              flex: 2,
                                              child: FutureBuilder<Lead?>(
                                                future: _getLeadFuture(u.clientName!),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return const SizedBox(
                                                      height: 14,
                                                      width: 14,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    );
                                                  }
                                                  
                                                  String displayName = u.clientName!;
                                                  bool hasLead = false;
                                                  
                                                  if (snapshot.hasData && snapshot.data != null) {
                                                    final lead = snapshot.data!;
                                                    displayName = lead.customerName.isNotEmpty ? lead.customerName : lead.leadName ?? lead.name ?? '';
                                                    hasLead = true;
                                                  }
                                                  
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF675D40).withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: const Color(0xFF675D40).withOpacity(0.15)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.person, size: 12, color: hasLead ? const Color(0xFF675D40) : Colors.grey),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            displayName, 
                                                            style: TextStyle(
                                                              fontSize: 11, 
                                                              color: hasLead ? const Color(0xFF675D40) : Colors.grey, 
                                                              fontWeight: FontWeight.bold
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(u.name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _linkUnit(u.name);
                                      },
                                    );
                                  },
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available': return const Color(0xFF5CB85C);
      case 'Hold': return const Color(0xFFF0AD4E);
      case 'Sold': return const Color(0xFFD9534F);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parking ${widget.parking.parkingNumber}',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(_currentStatus),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentStatus,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSpecRow(Icons.layers, 'Level', widget.parking.level),
          _buildSpecRow(Icons.local_parking, 'Type', widget.parking.parkingType),
          if (widget.parking.modifiedBy != null)
            _buildSpecRow(Icons.edit_note, 'Last Modified By', widget.parking.modifiedBy!),
          
          const Divider(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.apartment, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LINKED UNIT', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 10)),
                    const SizedBox(height: 4),
                    if (_isUnitsLoading)
                      const Text('Loading...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                    else if (widget.parking.linkedUnit == null || widget.parking.linkedUnit!.isEmpty)
                      const Text('None', style: TextStyle(fontWeight: FontWeight.bold))
                    else ...[
                      Text('Flat ${_linkedUnitObj?.flatNo ?? widget.parking.linkedUnit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (_linkedLeadFuture != null)
                        FutureBuilder<Lead?>(
                          future: _linkedLeadFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Text('Loading customer...', style: TextStyle(fontSize: 12, color: Colors.grey));
                            }
                            if (snapshot.hasError) {
                              return Text('Error fetching lead', style: TextStyle(fontSize: 12, color: Colors.red[300]));
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              final lead = snapshot.data!;
                              final displayName = lead.customerName.isNotEmpty ? lead.customerName : lead.leadName ?? lead.name ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 12, color: Colors.blueGrey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (_linkedUnitObj?.clientName != null) {
                               // Fallback to showing just the raw client ID if fetch returned null
                               return Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _linkedUnitObj!.clientName!,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                    ],
                  ],
                ),
              ),
              if (widget.designation?.toLowerCase() != 'sourcing')
                TextButton.icon(
                  onPressed: _showUnitSearchPicker,
                  icon: const Icon(Icons.link),
                  label: Text(widget.parking.linkedUnit == null || widget.parking.linkedUnit!.isEmpty ? 'Link Unit' : 'Replace'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF675D40)),
                ),
            ],
          ),

          if (widget.designation?.toLowerCase() != 'sourcing') ...[
            const SizedBox(height: 24),
            const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_isUpdating)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _currentStatus,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'Available', child: Text('Available')),
                  DropdownMenuItem(value: 'Hold', child: Text('Hold')),
                  DropdownMenuItem(value: 'Sold', child: Text('Sold')),
                ],
                onChanged: _updateStatus,
              ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

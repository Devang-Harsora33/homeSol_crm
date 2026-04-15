import 'package:flutter/material.dart';
import '../models/property_unit.dart';
import '../models/lead.dart';
import '../services/apis/projects/property_unit_service.dart';
import '../services/apis/leads/lead_service.dart';
import 'lead_detail_view.dart';

class LiveInventoryMatrix extends StatefulWidget {
  final String projectId;
  final String? designation;

  const LiveInventoryMatrix({
    super.key,
    required this.projectId,
    this.designation,
  });

  @override
  State<LiveInventoryMatrix> createState() => _LiveInventoryMatrixState();
}

class _LiveInventoryMatrixState extends State<LiveInventoryMatrix> {
  late Future<List<PropertyUnit>> _unitsFuture;
  final TransformationController _transformationController = TransformationController();
  String? _filterStatus;
  
  // Grid settings
  final double _cellWidth = 50.0;
  final double _cellHeight = 45.0;
  final double _headerSize = 44.0;

  @override
  void initState() {
    super.initState();
    _refreshUnits();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _refreshUnits() {
    setState(() {
      _unitsFuture = PropertyUnitService.fetchPropertyUnits(widget.projectId);
    });
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _zoomIn() {
    final Matrix4 current = _transformationController.value;
    final double scale = current.getMaxScaleOnAxis();
    if (scale < 2.5) {
      setState(() {
        _transformationController.value = current.clone()..scale(1.2);
      });
    }
  }

  void _zoomOut() {
    final Matrix4 current = _transformationController.value;
    final double scale = current.getMaxScaleOnAxis();
    if (scale > 0.2) {
      setState(() {
        _transformationController.value = current.clone()..scale(0.8);
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Available':
        return const Color(0xFF4CAF50); // Material Green
      case 'Hold':
        return const Color(0xFFFF9800); // Material Orange
      case 'Sold':
        return const Color(0xFFF44336); // Material Red
      default:
        return Colors.blueGrey;
    }
  }

  void _showUnitDetails(PropertyUnit unit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _UnitDetailsBottomSheet(
          unit: unit,
          designation: widget.designation,
          onStatusUpdated: () {
            _refreshUnits();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PropertyUnit>>(
      future: _unitsFuture,
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
                TextButton(onPressed: _refreshUnits, child: const Text('Retry')),
              ],
            ),
          );
        }

        final units = snapshot.data ?? [];
        if (units.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('No units found for this project'),
            ),
          );
        }

        // Process data into matrix
        final floors = <String>{};
        final series = <String>{};
        final Map<String, Map<String, PropertyUnit>> matrix = {};

        for (final unit in units) {
          final f = unit.floorNumber;
          String s = unit.flatNo;
          if (s.startsWith(f)) {
            s = s.substring(f.length);
          }
          if (s.isEmpty) s = unit.flatNo;

          floors.add(f);
          series.add(s);
          matrix.putIfAbsent(f, () => {})[s] = unit;
        }

        final sortedFloors = floors.toList()..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
        final sortedSeries = series.toList()..sort();

        // Account for the margin (1.5 * 2 = 3.0) in total size calculation
        final double cellSpacing = 3.0;
        final double totalGridWidth = sortedSeries.length * (_cellWidth + cellSpacing);
        final double totalGridHeight = sortedFloors.length * (_cellHeight + cellSpacing);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControls(),
            SizedBox(
              height: 550, // Fixed height to avoid layout errors in scrollable parents
              child: Container(
                color: const Color(0xFFF5F7FA),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // The Main Interactive Grid (shifted to leave room for headers)
                        Positioned(
                          top: _headerSize,
                          left: _headerSize,
                          right: 0,
                          bottom: 0,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            constrained: false,
                            minScale: 0.1,
                            maxScale: 2.5,
                            boundaryMargin: EdgeInsets.zero,
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              width: totalGridWidth + 8,
                              height: totalGridHeight + 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: _buildMatrixGrid(sortedFloors, sortedSeries, matrix),
                            ),
                          ),
                        ),
                        
                        // Sticky Headers
                        AnimatedBuilder(
                          animation: _transformationController,
                          builder: (context, child) {
                            final transform = _transformationController.value;
                            final scale = transform.getMaxScaleOnAxis();
                            final offset = transform.getTranslation();

                            return Stack(
                              children: [
                                // Top Series Header
                                Positioned(
                                  top: 0,
                                  left: _headerSize + offset.x,
                                  width: totalGridWidth * scale,
                                  height: _headerSize * scale,
                                  child: ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.topLeft,
                                      minWidth: totalGridWidth,
                                      maxWidth: totalGridWidth,
                                      minHeight: _headerSize,
                                      maxHeight: _headerSize,
                                      child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.topLeft,
                                        child: _buildTopHeader(sortedSeries),
                                      ),
                                    ),
                                  ),
                                ),
                                // Left Floor Header
                                Positioned(
                                  top: _headerSize + offset.y,
                                  left: 0,
                                  width: _headerSize * scale,
                                  height: totalGridHeight * scale,
                                  child: ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.topLeft,
                                      minWidth: _headerSize,
                                      maxWidth: _headerSize,
                                      minHeight: totalGridHeight,
                                      maxHeight: totalGridHeight,
                                      child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.topLeft,
                                        child: _buildLeftHeader(sortedFloors),
                                      ),
                                    ),
                                  ),
                                ),
                                // Corner Reset Button
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  width: _headerSize,
                                  height: _headerSize,
                                  child: GestureDetector(
                                    onTap: _resetZoom,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF675d40), // Deep Indigo
                                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.center_focus_strong,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
              ),
              const SizedBox(width: 12),
              _buildZoomControls(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Available', const Color(0xFF4CAF50)),
              _buildLegendItem('Hold', const Color(0xFFFF9800)),
              _buildLegendItem('Sold', const Color(0xFFF44336)),
              Text(
                'Tip: Pinch to zoom, drag to pan',
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 20),
            onPressed: _zoomOut,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: 'Zoom Out',
          ),
          Container(width: 1, height: 20, color: Colors.grey[300]),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: _zoomIn,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: 'Zoom In',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _filterStatus == status;
    final color = status == null ? const Color(0xFF675d40) : _getStatusColor(status);
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = selected ? status : null);
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.blueGrey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTopHeader(List<String> series) {
    return Row(
      children: series.map((s) => Container(
        width: _cellWidth,
        height: _headerSize,
        decoration: BoxDecoration(
          color: const Color(0xFF37474F), // Blue Grey 800
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SERIES',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            Text(
              s,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildLeftHeader(List<String> floors) {
    return Column(
      children: floors.map((f) => Container(
        width: _headerSize,
        height: _cellHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF37474F),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'F',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.bold),
              ),
              Text(
                f,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildMatrixGrid(List<String> floors, List<String> series, Map<String, Map<String, PropertyUnit>> matrix) {
    return Column(
      children: floors.map((floor) {
        return Row(
          children: series.map((s) {
            final unit = matrix[floor]?[s];
            return _buildMicroCard(unit);
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildMicroCard(PropertyUnit? unit) {
    if (unit == null) {
      return Container(
        width: _cellWidth,
        height: _cellHeight,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.white, width: 0.5),
        ),
      );
    }

    final bool isHighlighted = _filterStatus == null || unit.unitStatus == _filterStatus;
    final color = _getStatusColor(unit.unitStatus);
    
    return GestureDetector(
      onTap: () => _showUnitDetails(unit),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isHighlighted ? 1.0 : 0.1,
        child: Container(
          width: _cellWidth,
          height: _cellHeight,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 0.5),
            boxShadow: [
              if (isHighlighted)
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  unit.flatNo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 3,
                child: Text(
                  unit.configuration.split(' ').first, // e.g. "2" from "2 BHK"
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _StatusCornerPainter extends CustomPainter {
  final Color color;
  _StatusCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnitDetailsBottomSheet extends StatefulWidget {
  final PropertyUnit unit;
  final VoidCallback onStatusUpdated;
  final String? designation;

  const _UnitDetailsBottomSheet({
    required this.unit,
    required this.onStatusUpdated,
    this.designation,
  });

  @override
  State<_UnitDetailsBottomSheet> createState() => _UnitDetailsBottomSheetState();
}

class _UnitDetailsBottomSheetState extends State<_UnitDetailsBottomSheet> {
  late String _currentStatus;
  bool _isUpdating = false;
  Future<Lead?>? _linkedLeadFuture;
  
  List<Lead> _leadOptions = [];
  bool _isLeadsLoading = false;
  final TextEditingController _leadSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.unit.unitStatus;
    if (widget.unit.clientName != null && widget.unit.clientName!.isNotEmpty) {
      _linkedLeadFuture = LeadService.fetchLead(widget.unit.clientName!);
    }
    _fetchLeads();
  }
  
  @override
  void dispose() {
    _leadSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLeadsLoading = true);
    try {
      final leads = await LeadService.fetchMyLeads();
      if (mounted) {
        setState(() {
          _leadOptions = leads;
          _isLeadsLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching leads: $e');
      if (mounted) setState(() => _isLeadsLoading = false);
    }
  }

  Future<void> _updateStatus(String? newStatus) async {
    if (newStatus == null || newStatus == _currentStatus) return;

    setState(() {
      _isUpdating = true;
    });

    final success = await PropertyUnitService.updatePropertyUnitStatus(
      widget.unit.name,
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
        Navigator.pop(context); // Close bottom sheet after successful update
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToLeadDetails(Lead lead) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeadDetailView(lead: lead),
      ),
    );
  }

  Future<void> _linkLead(String leadId) async {
    setState(() => _isUpdating = true);
    try {
      bool success = await PropertyUnitService.linkLeadToUnit(widget.unit.name, leadId);
      
      // If success, update the unit status: Available if lead is removed, Hold if lead is linked
      if (success) {
        final newStatus = leadId.isEmpty ? 'Available' : 'Hold';
        success = await PropertyUnitService.updatePropertyUnitStatus(widget.unit.name, newStatus);
      }

      if (mounted) {
        if (success) {
          widget.onStatusUpdated();
          Navigator.pop(context); // Close bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(leadId.isEmpty 
                  ? 'Lead removed and unit marked Available' 
                  : 'Lead linked and unit marked Hold'),
            ),
          );
        } else {
          setState(() => _isUpdating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operation failed'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLeadSearchPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = _leadSearchController.text.toLowerCase();
            final filteredLeads = _leadOptions.where((lead) {
              final name = (lead.leadName ?? lead.customerName ?? '').toLowerCase();
              final id = (lead.name ?? '').toLowerCase();
              final phone = (lead.mobileNo ?? '').toLowerCase();
              return name.contains(query) || id.contains(query) || phone.contains(query);
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
                    'Select Lead to Link',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _leadSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, ID or phone...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _leadSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _leadSearchController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setModalState(() {});
                      },
                    ),
                  ),
                  Expanded(
                    child: _isLeadsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              if (query.isEmpty)
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(0xFF675d40).withOpacity(0.1),
                                    child: const Icon(Icons.link_off, color: Color(0xFF675d40)),
                                  ),
                                  title: const Text(
                                    'None / Remove Linked Lead',
                                    style: TextStyle(color: Color(0xFF675d40), fontWeight: FontWeight.bold),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _linkLead('');
                                  },
                                ),
                              if (filteredLeads.isEmpty && query.isNotEmpty)
                                const Expanded(child: Center(child: Text('No leads found')))
                              else
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filteredLeads.length,
                                    itemBuilder: (context, index) {
                                      final lead = filteredLeads[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(0xFF675D40).withOpacity(0.1),
                                          child: Text(
                                            (lead.leadName ?? lead.customerName ?? '?')[0].toUpperCase(),
                                            style: const TextStyle(color: Color(0xFF675D40), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          lead.leadName ?? lead.customerName ?? 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text('${lead.name} • ${lead.mobileNo ?? ''}'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _linkLead(lead.name!);
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
      case 'Available':
        return const Color(0xFF5CB85C);
      case 'Hold':
        return const Color(0xFFF0AD4E);
      case 'Sold':
        return const Color(0xFFD9534F);
      default:
        return Colors.grey;
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
                'Flat ${widget.unit.flatNo}',
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
          _buildSpecRow(Icons.layers, 'Floor', widget.unit.floorNumber),
          _buildSpecRow(Icons.apartment, 'Configuration', widget.unit.configuration),
          _buildSpecRow(Icons.square_foot, 'Carpet Area', '${widget.unit.carpetArea} sq.ft'),
          if (widget.unit.modifiedBy != null)
            _buildSpecRow(Icons.edit_note, 'Last Modified By', widget.unit.modifiedBy!),
          if (_linkedLeadFuture != null)
            FutureBuilder<Lead?>(
              future: _linkedLeadFuture,
              builder: (context, snapshot) {
                String labelText = 'Linked Lead: ';
                Widget valueWidget;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  valueWidget = const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                } else if (snapshot.hasData && snapshot.data != null) {
                  final lead = snapshot.data!;
                  final displayName = lead.customerName.isNotEmpty ? lead.customerName : lead.leadName ?? lead.name ?? widget.unit.clientName!;
                  
                  valueWidget = GestureDetector(
                    onTap: () => _navigateToLeadDetails(lead),
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF675D40),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  );
                } else {
                  valueWidget = Text(
                    widget.unit.clientName!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_outline, size: 20, color: Colors.blueGrey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LINKED LEAD',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            valueWidget,
                          ],
                        ),
                      ),
                      if (_currentStatus != 'Sold' && !(widget.designation?.toLowerCase().contains('sourcing') ?? false))
                        OutlinedButton.icon(
                          onPressed: _showLeadSearchPicker,
                          icon: const Icon(Icons.swap_horiz, size: 14),
                          label: const Text('Replace', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF675D40),
                            side: BorderSide(color: const Color(0xFF675D40).withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
           
          else if (_currentStatus == 'Available' )
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.person_add, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Text(
                    'No lead linked',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  const Spacer(),
                  if (!(widget.designation?.toLowerCase().contains('sourcing') ?? false))
                    TextButton.icon(
                      onPressed: _showLeadSearchPicker,
                      icon: const Icon(Icons.link),
                      label: const Text('Link Lead'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF675D40),
                      ),
                    ),
                ],
              ),
            ),

          if (!(widget.designation?.toLowerCase().contains('sourcing') ?? false)) ...[
            const Divider(height: 40),
            const Text(
              'Update Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
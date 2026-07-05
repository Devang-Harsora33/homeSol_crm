import 'package:flutter/material.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
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
  String? _selectedWing;
  bool _showStats = false;
  
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
      case 'Refuge':
        return Colors.grey;
      case 'Investor Unit':
        return Colors.purple;
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
        return UnitDetailsBottomSheet(
          unit: unit,
          designation: widget.designation,
          onStatusUpdated: () {
            _refreshUnits();
          },
        );
      },
    );
  }

  Widget _buildStatsTable(List<PropertyUnit> units) {
    final Map<String, InventoryStatRow> statsMap = {};
    for (final unit in units) {
      final key = "${unit.configuration}_${unit.carpetArea}";
      if (!statsMap.containsKey(key)) {
        statsMap[key] = InventoryStatRow(
          configuration: unit.configuration,
          carpetArea: unit.carpetArea,
        );
      }
      statsMap[key]!.totalUnits++;
      if (unit.unitStatus == 'Sold') {
        statsMap[key]!.soldUnits++;
      }
    }

    final sortedStats = statsMap.values.toList()
      ..sort((a, b) {
        int cmp = a.configuration.compareTo(b.configuration);
        if (cmp != 0) return cmp;
        return a.carpetArea.compareTo(b.carpetArea);
      });

    int grandTotalUnits = 0;
    double grandTotalSqFt = 0;

    for (var stat in sortedStats) {
      grandTotalUnits += stat.totalUnits;
      grandTotalSqFt += stat.totalSqFt;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF675d40).withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF675d40)),
                const SizedBox(width: 8),
                Text(
                  '$_selectedWing - Wing Inventory Stats',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF675d40),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey[100]!, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[50]),
                children: [
                  _buildTableCell('Total Inventory', isHeader: true),
                  _buildTableCell('Carpet Area', isHeader: true),
                  _buildTableCell('Total Units', isHeader: true),
                  _buildTableCell('Sq:ft', isHeader: true),
                  _buildTableCell('Sold Out', isHeader: true),
                ],
              ),
              ...sortedStats.map((stat) => TableRow(
                children: [
                  _buildTableCell(stat.configuration),
                  _buildTableCell(stat.carpetArea.toStringAsFixed(0)),
                  _buildTableCell(stat.totalUnits.toString()),
                  _buildTableCell(stat.totalSqFt.toStringAsFixed(0)),
                  _buildTableCell(stat.soldUnits.toString(), textColor: stat.soldUnits > 0 ? Colors.red[700] : null),
                ],
              )),
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[50]),
                children: [
                  _buildTableCell('Total', isHeader: true),
                  _buildTableCell(''),
                  _buildTableCell(grandTotalUnits.toString(), isHeader: true),
                  _buildTableCell(grandTotalSqFt.toStringAsFixed(0), isHeader: true),
                  _buildTableCell(''),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 10 : 11,
          color: textColor ?? (isHeader ? Colors.black87 : Colors.black54),
        ),
        textAlign: TextAlign.center,
      ),
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

        // Get unique wings
        final wings = units
            .map((u) => u.wing)
            .where((w) => w != null && w.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

        // Auto-select first wing if none selected
        if (_selectedWing == null && wings.isNotEmpty) {
          _selectedWing = wings.first;
        }

        // Filter units by wing
        final filteredByWingUnits = _selectedWing == null
            ? units
            : units.where((u) => u.wing == _selectedWing).toList();

        // Process data into matrix
        final floors = <String>{};
        final seriesSet = <String>{};
        
        // Detailed mapping: floor -> series -> unit
        final Map<String, Map<String, PropertyUnit>> matrix = {};
        
        // Track units that span multiple series (Jodi flats)
        // Unit Name -> List of Series it covers
        final Map<String, List<String>> unitSpans = {};

        for (final unit in filteredByWingUnits) {
          final f = unit.floorNumber;
          floors.add(f);
          
          final List<String> unitParts = unit.flatNo.split('-');
          final List<String> currentUnitSeries = [];
          
          for (final part in unitParts) {
            String s = part.trim();
            // If the part starts with the floor number, strip it to get the series
            if (s.startsWith(f)) {
              s = s.substring(f.length);
            }
            // If stripping floor number results in empty (e.g. flat 14 on floor 14), 
            // fallback to the full part as series
            if (s.isEmpty) s = part.trim();
            
            seriesSet.add(s);
            currentUnitSeries.add(s);
            
            matrix.putIfAbsent(f, () => {})[s] = unit;
          }
          
          if (unitParts.length > 1) {
            unitSpans[unit.name] = currentUnitSeries;
          }
        }

        final sortedFloors = floors.toList()
          ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
        final sortedSeries = seriesSet.toList()..sort();

        // Account for the margin (1.5 * 2 = 3.0) in total size calculation
        final double cellSpacing = 3.0;
        final double totalGridWidth = sortedSeries.length * (_cellWidth + cellSpacing);
        final double totalGridHeight = sortedFloors.length * (_cellHeight + cellSpacing);
        
        // Calculate dynamic height: header + grid height + padding (8.0 total), capped at 550
        final double calculatedHeight = _headerSize + totalGridHeight + 16.0;
        final double displayHeight = calculatedHeight.clamp(150.0, 550.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControls(wings),
            if (_showStats) _buildStatsTable(filteredByWingUnits),
            SizedBox(
              height: displayHeight, // Dynamic height capped at 550
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
                              child: _buildMatrixGrid(sortedFloors, sortedSeries, matrix, unitSpans),
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
                                  left: _headerSize + offset.x + (4.0 * scale),
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
                                  top: _headerSize + offset.y + (4.0 * scale),
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

  Widget _buildControls(List<String> wings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.03),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF675d40).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.domain_rounded, size: 18, color: Color(0xFF675d40)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'WING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildZoomControls(),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => setState(() => _showStats = !_showStats),
                          icon: Icon(_showStats ? Icons.visibility_off_outlined : Icons.analytics_outlined, size: 16),
                          label: Text(_showStats ? 'Hide Stats' : 'Show Stats', style: const TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF675d40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        'Pinch to zoom, drag to pan',
                        style: TextStyle(fontSize: 9, color: Colors.grey[400], fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (wings.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: wings.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final wing = wings[index];
                  final isSelected = _selectedWing == wing;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () {
                        if (!isSelected) {
                          setState(() {
                            _selectedWing = wing;
                            _resetZoom();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.fastOutSlowIn,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected 
                            ? const LinearGradient(
                                colors: [Color(0xFF675d40), Color(0xFF8E825D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [Colors.white, Colors.grey[50]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF675d40).withOpacity(0.5) : Colors.grey[200]!,
                            width: 1,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: const Color(0xFF675d40).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                                spreadRadius: -2,
                              )
                            else
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            wing,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Status', null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Available', 'Available'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Hold', 'Hold'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Sold', 'Sold'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Refuge', 'Refuge'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Investor Unit', 'Investor Unit'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLegendItem('Available', const Color(0xFF4CAF50)),
                      const SizedBox(width: 12),
                      _buildLegendItem('Hold', const Color(0xFFFF9800)),
                      const SizedBox(width: 12),
                      _buildLegendItem('Sold', const Color(0xFFF44336)),
                      const SizedBox(width: 12),
                      _buildLegendItem('Refuge', Colors.grey),
                      const SizedBox(width: 12),
                      _buildLegendItem('Investor Unit', Colors.purple),
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
    final double totalCellWidth = _cellWidth + 3.0; // _cellWidth + 1.5 margin on each side
    return Row(
      children: series.map((s) => Container(
        width: totalCellWidth,
        height: _headerSize,
        decoration: BoxDecoration(
          color: const Color(0xFF37474F), // Blue Grey 800
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SERIES',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                Text(
                  s,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildLeftHeader(List<String> floors) {
    final double totalCellHeight = _cellHeight + 3.0; // _cellHeight + 1.5 margin on each side
    return Column(
      children: floors.map((f) => Container(
        width: _headerSize,
        height: totalCellHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF37474F),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'F',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.bold),
                ),
                Text(
                  f,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildMatrixGrid(List<String> floors, List<String> series, Map<String, Map<String, PropertyUnit>> matrix, Map<String, List<String>> unitSpans) {
    return Column(
      children: floors.map((floor) {
        final List<Widget> rowCells = [];
        final Set<String> renderedSeriesInRow = {};

        for (final s in series) {
          if (renderedSeriesInRow.contains(s)) continue;

          final unit = matrix[floor]?[s];
          if (unit == null) {
            rowCells.add(_buildMicroCard(null));
            renderedSeriesInRow.add(s);
            continue;
          }

          final span = unitSpans[unit.name];
          if (span != null && span.length > 1) {
            // It's a Jodi unit
            final int colspan = span.length;
            rowCells.add(_buildMicroCard(unit, colspan: colspan));
            renderedSeriesInRow.addAll(span);
          } else {
            rowCells.add(_buildMicroCard(unit));
            renderedSeriesInRow.add(s);
          }
        }

        return Row(children: rowCells);
      }).toList(),
    );
  }

  Widget _buildMicroCard(PropertyUnit? unit, {int colspan = 1}) {
    // Account for the margin (1.5 * 2 = 3.0)
    final double cellSpacing = 3.0;
    final double width = (colspan * _cellWidth) + ((colspan - 1) * cellSpacing);
    
    if (unit == null) {
      return Container(
        width: width,
        height: _cellHeight,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F8).withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final bool isHighlighted = _filterStatus == null || unit.unitStatus == _filterStatus;
    final color = _getStatusColor(unit.unitStatus);
    final isJodi = colspan > 1;
    
    return GestureDetector(
      onTap: () => _showUnitDetails(unit),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isHighlighted ? 1.0 : 0.15,
        child: Container(
          width: width,
          height: _cellHeight,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color, 
              width: 0.5
            ),
            boxShadow: [
              if (isHighlighted)
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      unit.flatNo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 4,
                child: Text(
                  unit.configuration.split(' ').first,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8), 
                    fontSize: 8, 
                    fontWeight: FontWeight.bold
                  ),
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

class UnitDetailsBottomSheet extends StatefulWidget {
  final PropertyUnit unit;
  final VoidCallback onStatusUpdated;
  final String? designation;

  const UnitDetailsBottomSheet({
    required this.unit,
    required this.onStatusUpdated,
    this.designation,
  });

  @override
  State<UnitDetailsBottomSheet> createState() => UnitDetailsBottomSheetState();
}

class UnitDetailsBottomSheetState extends State<UnitDetailsBottomSheet> {
  late String _currentStatus;
  String? _currentPaymentMethod;
  bool _isUpdating = false;
  bool _isUpdatingPaymentMethod = false;
  Future<Lead?>? _linkedLeadFuture;
  
  List<Lead> _leadOptions = [];
  bool _isLeadsLoading = false;
  final TextEditingController _leadSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.unit.unitStatus;
    _currentPaymentMethod = (widget.unit.paymentMethod?.isEmpty ?? true) ? null : widget.unit.paymentMethod;
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
        if (widget.unit.clientName != null && widget.unit.clientName!.isNotEmpty) {
          try {
            if (newStatus == 'Sold') {
              await LeadService.updateLead(widget.unit.clientName!, {
                'custom_lead_status': 'Won',
                'status': 'Converted',
              });
            } else if (newStatus == 'Hold') {
              await LeadService.updateLead(widget.unit.clientName!, {
                'custom_lead_status': 'Prospect',
                'status': 'Opportunity',
              });
            } else if (newStatus == 'Available') {
              await LeadService.updateLead(widget.unit.clientName!, {
                'custom_lead_status': 'Open',
                'status': 'Open',
              });
            }
          } catch (e) {
            print('Error updating lead status: $e');
          }
        }

        widget.onStatusUpdated();
        Navigator.pop(context); // Close bottom sheet after successful update
        CustomSnackBar.show(context, message: 'Status updated successfully', isError: false, title: 'Notice');
      } else {
        CustomSnackBar.show(context, message: 'Failed to update status', isError: true, title: 'Error');
      }
    }
  }

  Future<void> _updatePaymentMethod(String? newMethod) async {
    if (newMethod == null || newMethod == _currentPaymentMethod) return;

    setState(() {
      _isUpdatingPaymentMethod = true;
    });

    final success = await PropertyUnitService.updatePropertyUnitPaymentMethod(
      widget.unit.name,
      newMethod,
    );

    if (mounted) {
      setState(() {
        _isUpdatingPaymentMethod = false;
        if (success) {
          _currentPaymentMethod = newMethod;
        }
      });

      if (success) {
        widget.onStatusUpdated();
        CustomSnackBar.show(context, message: 'Payment Method updated successfully', isError: false, title: 'Notice');
      } else {
        CustomSnackBar.show(context, message: 'Failed to update Payment Method', isError: true, title: 'Error');
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
        
        if (success) {
          try {
            if (leadId.isEmpty && widget.unit.clientName != null && widget.unit.clientName!.isNotEmpty) {
              await LeadService.updateLead(widget.unit.clientName!, {
                'custom_lead_status': 'Open',
                'status': 'Open',
              });
            } else if (leadId.isNotEmpty) {
              await LeadService.updateLead(leadId, {
                'custom_lead_status': 'Prospect',
                'status': 'Opportunity',
              });
            }
          } catch (e) {
            print('Error updating lead status: $e');
          }
        }
      }

      if (mounted) {
        if (success) {
          widget.onStatusUpdated();
          Navigator.pop(context); // Close bottom sheet
          CustomSnackBar.show(context, message: leadId.isEmpty 
                  ? 'Lead removed and unit marked Available' 
                  : 'Lead linked and unit marked Hold');
        } else {
          setState(() => _isUpdating = false);
          CustomSnackBar.show(context, message: 'Operation failed', isError: true, title: 'Error');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
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
      case 'Refuge':
        return Colors.grey;
      case 'Investor Unit':
        return Colors.purple;
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
              Row(
                children: [
                  if (widget.unit.wing != null && widget.unit.wing!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Wing ${widget.unit.wing}',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
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
            ],
          ),
          const SizedBox(height: 20),
          if (widget.unit.wing != null && widget.unit.wing!.isNotEmpty)
            _buildSpecRow(Icons.domain, 'Wing', widget.unit.wing!),
          if (widget.unit.side != null && widget.unit.side!.isNotEmpty)
            _buildSpecRow(Icons.view_column_outlined, 'Side', widget.unit.side!),
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
                      if (_currentStatus != 'Sold' && 
                          widget.designation?.trim().toLowerCase() != 'sourcing' && 
                          widget.designation?.trim().toLowerCase() != 'property developer')
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
                  if (widget.designation?.trim().toLowerCase() != 'sourcing' && 
                      widget.designation?.trim().toLowerCase() != 'property developer')
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

          if (widget.designation?.toLowerCase() != 'sourcing' && widget.designation?.toLowerCase() != 'property developer') ...[
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
                  DropdownMenuItem(value: 'Refuge', child: Text('Refuge')),
                  DropdownMenuItem(value: 'Investor Unit', child: Text('Investor Unit')),
                ],
                onChanged: _updateStatus,
              ),

            const SizedBox(height: 24),
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_isUpdatingPaymentMethod)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _currentPaymentMethod,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Select Payment Method',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'Full Payment', child: Text('Full Payment')),
                  DropdownMenuItem(value: 'Home Loan', child: Text('Home Loan')),
                  DropdownMenuItem(value: 'Installment', child: Text('Installment')),
                ],
                onChanged: _updatePaymentMethod,
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

class InventoryStatRow {
  final String configuration;
  final double carpetArea;
  int totalUnits;
  int soldUnits;

  InventoryStatRow({
    required this.configuration,
    required this.carpetArea,
    this.totalUnits = 0,
    this.soldUnits = 0,
  });

  double get totalSqFt => carpetArea * totalUnits;
}

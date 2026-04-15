import 'package:flutter/material.dart';

class AmenitiesFilter extends StatelessWidget {
  final bool isDark;
  final List<String> amenities;
  final Set<String> selectedAmenities;
  final String query;
  final void Function(String) onQueryChanged;
  final void Function(void Function()) setSheetState;

  const AmenitiesFilter({
    super.key,
    required this.isDark,
    required this.amenities,
    required this.selectedAmenities,
    required this.query,
    required this.onQueryChanged,
    required this.setSheetState,
  });

  IconData _amenityIcon(String amenity) {
    final a = amenity.toLowerCase();
    if (a.contains('park') || a.contains('garden')) return Icons.park_rounded;
    if (a.contains('gym') || a.contains('fitness')) return Icons.fitness_center_rounded;
    if (a.contains('pool') || a.contains('swim')) return Icons.pool_rounded;
    if (a.contains('lift') || a.contains('elevator')) return Icons.elevator_rounded;
    if (a.contains('secur') || a.contains('cctv') || a.contains('guard')) return Icons.security_rounded;
    if (a.contains('club') || a.contains('lounge')) return Icons.meeting_room_rounded;
    if (a.contains('power') || a.contains('backup')) return Icons.bolt_rounded;
    if (a.contains('water')) return Icons.water_drop_rounded;
    if (a.contains('parking') || a.contains('car')) return Icons.local_parking_rounded;
    if (a.contains('play') || a.contains('kid') || a.contains('child')) return Icons.child_care_rounded;
    if (a.contains('wifi') || a.contains('internet')) return Icons.wifi_rounded;
    if (a.contains('shop') || a.contains('market')) return Icons.shopping_bag_rounded;
    if (a.contains('terrace') || a.contains('roof')) return Icons.roofing_rounded;
    if (a.contains('temple') || a.contains('prayer')) return Icons.temple_hindu_rounded;
    return Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);

    final filtered = query.isEmpty
        ? amenities
        : amenities.where((a) => a.toLowerCase().contains(query.toLowerCase())).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              onChanged: onQueryChanged,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search amenities...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),

        // Selected count banner
        if (selectedAmenities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: kAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedAmenities.length} amenit${selectedAmenities.length == 1 ? 'y' : 'ies'} selected',
                      style: TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setSheetState(() => selectedAmenities.clear()),
                    child: Text('Clear', style: TextStyle(fontSize: 11.5, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('No amenities found', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final amenity = filtered[i];
                    final selected = selectedAmenities.contains(amenity);
                    final icon = _amenityIcon(amenity);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setSheetState(() {
                        selected ? selectedAmenities.remove(amenity) : selectedAmenities.add(amenity);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? kAccent.withOpacity(isDark ? 0.2 : 0.07)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: selected
                                    ? kAccent.withOpacity(isDark ? 0.3 : 0.12)
                                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 16,
                                color: selected ? kAccent : Colors.grey.shade500),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                amenity,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: selected
                                      ? (isDark ? Colors.white : const Color(0xFF3D3420))
                                      : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: selected ? kAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: selected ? kAccent : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

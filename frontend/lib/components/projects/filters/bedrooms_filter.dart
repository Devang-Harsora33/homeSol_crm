import 'package:flutter/material.dart';

class BedroomsFilter extends StatelessWidget {
  final bool isDark;
  final List<int> options;
  final Set<int> selectedBedrooms;
  final void Function(void Function()) setSheetState;

  const BedroomsFilter({
    super.key,
    required this.isDark,
    required this.options,
    required this.selectedBedrooms,
    required this.setSheetState,
  });

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select bedroom count',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Large number tiles in a row
          Row(
            children: options.map((b) {
              final selected = selectedBedrooms.contains(b);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: b == options.last ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setSheetState(() {
                      selected ? selectedBedrooms.remove(b) : selectedBedrooms.add(b);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 64,
                      decoration: BoxDecoration(
                        color: selected
                            ? kAccent.withOpacity(isDark ? 0.3 : 0.12)
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? kAccent.withOpacity(0.6) : Colors.transparent,
                          width: 1.8,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: kAccent.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$b',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? kAccent
                                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'BHK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: selected
                                  ? kAccent.withOpacity(0.8)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Selected summary chip row
          if (selectedBedrooms.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.bed_rounded, size: 15, color: kAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${(selectedBedrooms.toList()..sort()).map((b) => '${b}BHK').join(', ')}',
                      style: TextStyle(fontSize: 12.5, color: kAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setSheetState(() => selectedBedrooms.clear()),
                    child: Icon(Icons.close_rounded, size: 16, color: kAccent.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to select multiple options',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

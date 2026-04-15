import 'package:flutter/material.dart';

class LocationRangeFilter extends StatelessWidget {
  final bool isDark;
  final List<double> options;
  final double? selectedRange;
  final void Function(double?) onChange;

  const LocationRangeFilter({
    super.key,
    required this.isDark,
    required this.options,
    required this.selectedRange,
    required this.onChange,
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
            'Distance from location',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // 2-column grid of distance tiles
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: options.map((range) {
              final selected = selectedRange == range;
              return GestureDetector(
                onTap: () => onChange(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  decoration: BoxDecoration(
                    color: selected
                        ? kAccent.withOpacity(isDark ? 0.25 : 0.1)
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? kAccent.withOpacity(0.55) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.social_distance_rounded,
                        size: 15,
                        color: selected ? kAccent : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${range.toStringAsFixed(0)} km',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? kAccent
                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // "No limit" clear row
          GestureDetector(
            onTap: () => onChange(null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selectedRange == null
                    ? kAccent.withOpacity(isDark ? 0.2 : 0.07)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedRange == null
                      ? kAccent.withOpacity(0.45)
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: selectedRange == null ? kAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: selectedRange == null ? kAccent : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                        width: 1.5,
                      ),
                    ),
                    child: selectedRange == null
                        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'No distance limit',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selectedRange == null ? FontWeight.w600 : FontWeight.w400,
                      color: selectedRange == null
                          ? (isDark ? Colors.white : const Color(0xFF3D3420))
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ),
                  if (selectedRange == null) ...[
                    const Spacer(),
                    Icon(Icons.check_circle_rounded, size: 15, color: kAccent.withOpacity(0.5)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

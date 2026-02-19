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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Range',
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred distance range from your current location',
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...options.map((range) {
                final selected = selectedRange == range;
                return ChoiceChip(
                  label: Text('Within ${range.toStringAsFixed(0)} km'),
                  selected: selected,
                  onSelected: (_) => onChange(range),
                  selectedColor: const Color(0xFFdbc163).withOpacity(0.2),
                  backgroundColor: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.05),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF7b641a)
                        : (isDark ? Colors.white : Colors.black),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFdbc163)
                          : (isDark ? Colors.white : Colors.black).withOpacity(
                              0.1,
                            ),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                );
              }),
              ChoiceChip(
                label: const Text('None'),
                selected: selectedRange == null,
                onSelected: (_) => onChange(null),
                selectedColor: const Color(0xFFdbc163).withOpacity(0.2),
                backgroundColor: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.05),
                labelStyle: TextStyle(
                  color: selectedRange == null
                      ? const Color(0xFF7b641a)
                      : (isDark ? Colors.white : Colors.black),
                  fontWeight: selectedRange == null
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: selectedRange == null
                        ? const Color(0xFFdbc163)
                        : (isDark ? Colors.white : Colors.black).withOpacity(
                            0.1,
                          ),
                    width: selectedRange == null ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

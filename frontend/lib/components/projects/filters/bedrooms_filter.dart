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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bedrooms',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the number of bedrooms you need',
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((b) {
              final selected = selectedBedrooms.contains(b);
              return FilterChip(
                label: Text('${b}BHK'),
                selected: selected,
                onSelected: (v) => setSheetState(() {
                  if (v) {
                    selectedBedrooms.add(b);
                  } else {
                    selectedBedrooms.remove(b);
                  }
                }),
                selectedColor: const Color(0xFFdbc163).withOpacity(0.2),
                checkmarkColor: const Color(0xFFdbc163),
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
            }).toList(),
          ),
        ],
      ),
    );
  }
}

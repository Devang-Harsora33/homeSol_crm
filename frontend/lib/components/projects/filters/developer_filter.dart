import 'package:flutter/material.dart';
import '../../../models/developer.dart';

class DeveloperFilter extends StatelessWidget {
  final bool isDark;
  final List<Developer> developers;
  final Set<String> selectedDeveloperIds;
  final Set<String> selectedDeveloperNames;
  final String query;
  final void Function(String) onQueryChanged;
  final void Function(void Function()) setSheetState;

  const DeveloperFilter({
    super.key,
    required this.isDark,
    required this.developers,
    required this.selectedDeveloperIds,
    required this.selectedDeveloperNames,
    required this.query,
    required this.onQueryChanged,
    required this.setSheetState,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = query.isEmpty
        ? developers
        : developers
              .where(
                (d) =>
                    d.developerName.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Developers',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filter by trusted developers',
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search developers',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: (isDark ? Colors.white : Colors.black).withOpacity(
                0.04,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: filtered.map((developer) {
              final selected = selectedDeveloperIds.contains(developer.id);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(developer.developerName),
                    if (developer.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: Color(0xFFdbc163),
                      ),
                    ],
                  ],
                ),
                selected: selected,
                onSelected: (v) => setSheetState(() {
                  if (v) {
                    selectedDeveloperIds.add(developer.id);
                    selectedDeveloperNames.add(developer.developerName);
                  } else {
                    selectedDeveloperIds.remove(developer.id);
                    selectedDeveloperNames.remove(developer.developerName);
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

import 'package:flutter/material.dart';

class StatusFilter extends StatelessWidget {
  final bool isDark;
  final Set<String> selectedStatuses;
  final List<String> options;
  final void Function(void Function()) setSheetState;

  const StatusFilter({
    super.key,
    required this.isDark,
    required this.selectedStatuses,
    required this.options,
    required this.setSheetState,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF34C759);
      case 'completed':
        return const Color(0xFF007AFF);
      case 'under construction':
        return const Color(0xFFFF9500);
      case 'planning':
        return const Color(0xFF5856D6);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle_rounded;
      case 'completed':
        return Icons.verified_rounded;
      case 'under construction':
        return Icons.construction_rounded;
      case 'planning':
        return Icons.architecture_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF675D40);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      shrinkWrap: true,
      children: [
        Text(
          'Filter by project status',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...options.map((status) {
          final selected = selectedStatuses.contains(status);
          final statusColor = _statusColor(status);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setSheetState(() {
              selected ? selectedStatuses.remove(status) : selectedStatuses.add(status);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: selected
                    ? statusColor.withOpacity(isDark ? 0.15 : 0.07)
                    : (isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? statusColor.withOpacity(0.5) : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Status icon circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_statusIcon(status), size: 18, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                            : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                  // Custom checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: selected ? kAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? kAccent : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

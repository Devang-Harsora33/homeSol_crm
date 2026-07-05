import 'dart:convert';

class LeadTransfer {
  final String name;
  final String owner;
  final DateTime creation;
  final String transferType;
  final String project;
  final String fromEmployee;
  final String toEmployee;
  final DateTime? validTill;
  final String status;
  final List<LeadTransferItem> selectedLeads;

  LeadTransfer({
    required this.name,
    required this.owner,
    required this.creation,
    required this.transferType,
    required this.project,
    required this.fromEmployee,
    required this.toEmployee,
    this.validTill,
    required this.status,
    required this.selectedLeads,
  });

  factory LeadTransfer.fromJson(Map<String, dynamic> json) {
    return LeadTransfer(
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      creation: DateTime.tryParse(json['creation'] ?? '') ?? DateTime.now(),
      transferType: json['transfer_type'] ?? '',
      project: json['project'] ?? '',
      fromEmployee: json['from_employee'] ?? '',
      toEmployee: json['to_employee'] ?? '',
      validTill: json['valid_till'] != null ? DateTime.tryParse(json['valid_till']) : null,
      status: json['status'] ?? '',
      selectedLeads: json['selected_leads'] != null
          ? (json['selected_leads'] as List)
              .map((i) => LeadTransferItem.fromJson(i))
              .toList()
          : [],
    );
  }
}

class LeadTransferItem {
  final String name;
  final String lead;

  LeadTransferItem({
    required this.name,
    required this.lead,
  });

  factory LeadTransferItem.fromJson(Map<String, dynamic> json) {
    return LeadTransferItem(
      name: json['name'] ?? '',
      lead: json['lead'] ?? '',
    );
  }
}

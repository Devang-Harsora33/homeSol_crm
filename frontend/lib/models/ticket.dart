class Ticket {
  final String id;
  final String status;
  final String priority;
  final String category;
  final String description;
  final String raisedBy;
  final String creation;
  final int docstatus;
  final String doctype;
  final int idx;
  final String modified;
  final String owner;

  Ticket({
    required this.id,
    required this.status,
    required this.priority,
    required this.category,
    required this.description,
    required this.raisedBy,
    required this.creation,
    required this.docstatus,
    required this.doctype,
    required this.idx,
    required this.modified,
    required this.owner,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['name'] ?? '',
      status: json['status'] ?? '',
      priority: json['priority'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      raisedBy: json['raised_by'] ?? '',
      creation: json['creation'] ?? '',
      docstatus: json['docstatus'] ?? 0,
      doctype: json['doctype'] ?? '',
      idx: json['idx'] ?? 0,
      modified: json['modified'] ?? '',
      owner: json['owner'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'status': status,
      'priority': priority,
      'category': category,
      'description': description,
      'raised_by': raisedBy,
      'creation': creation,
      'docstatus': docstatus,
      'doctype': doctype,
      'idx': idx,
      'modified': modified,
      'owner': owner,
    };
  }
}

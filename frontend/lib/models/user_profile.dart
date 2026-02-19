import 'dart:convert';

class UserProfile {
  final String name;
  final String owner;
  final DateTime creation;
  final DateTime modified;
  final String modifiedBy;
  final int docstatus;
  final int idx;
  final String employeeName;
  final String? defaultShift; // Make it nullable
  final String doctype;

  UserProfile({
    required this.name,
    required this.owner,
    required this.creation,
    required this.modified,
    required this.modifiedBy,
    required this.docstatus,
    required this.idx,
    required this.employeeName,
    this.defaultShift, // Add to constructor
    required this.doctype,
  });

  String get fullName => employeeName;
  String get email => name;
  String get initials {
    if (employeeName.isEmpty) return '';
    final names = employeeName.split(' ');
    if (names.length > 1) {
      return names.first[0].toUpperCase() + names.last[0].toUpperCase();
    } else {
      return names.first[0].toUpperCase();
    }
  }

  factory UserProfile.fromRawJson(String str) =>
      UserProfile.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json["name"],
        owner: json["owner"],
        creation: DateTime.parse(json["creation"]),
        modified: DateTime.parse(json["modified"]),
        modifiedBy: json["modified_by"],
        docstatus: json["docstatus"],
        idx: json["idx"],
        employeeName: json["employee_name"],
        defaultShift: json["default_shift"], // Add fromJson logic
        doctype: json["doctype"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "owner": owner,
        "creation": creation.toIso8601String(),
        "modified": modified.toIso8601String(),
        "modified_by": modifiedBy,
        "docstatus": docstatus,
        "idx": idx,
        "employee_name": employeeName,
        "default_shift": defaultShift, // Add toJson logic
        "doctype": doctype,
      };
}

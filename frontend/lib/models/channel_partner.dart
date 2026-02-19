import 'dart:convert';

ChannelPartner channelPartnerFromJson(String str) => ChannelPartner.fromJson(json.decode(str));

String channelPartnerToJson(ChannelPartner data) => json.encode(data.toJson());

class ChannelPartner {
    String? name;
    String? owner;
    DateTime? creation;
    DateTime? modified;
    String? modifiedBy;
    int? docstatus;
    int? idx;
    String? firmName;
    String? mobileNumber;
    String? reraNumber;
    String? email;
    String? territory;
    String? category;
    String? location;
    String? fullAddress;
    int? isDigital;
    int? isReference;
    int? isDataCalling;
    int? isRetail;
    int? isUnderConstruction;
    int? isRental;
    int? isReadyToMove;
    int? reqCallingSupport;
    int? reqDigitalKit;
    int? reqStandees;
    int? reqSmsBlast;
    int? reqWhatsappBlast;
    String? doctype;
    List<ContactPerson>? contactPersons;
    List<Document>? documents;

    ChannelPartner({
        this.name,
        this.owner,
        this.creation,
        this.modified,
        this.modifiedBy,
        this.docstatus,
        this.idx,
        this.firmName,
        this.mobileNumber,
        this.reraNumber,
        this.email,
        this.territory,
        this.category,
        this.location,
        this.fullAddress,
        this.isDigital,
        this.isReference,
        this.isDataCalling,
        this.isRetail,
        this.isUnderConstruction,
        this.isRental,
        this.isReadyToMove,
        this.reqCallingSupport,
        this.reqDigitalKit,
        this.reqStandees,
        this.reqSmsBlast,
        this.reqWhatsappBlast,
        this.doctype,
        this.contactPersons,
        this.documents,
    });

    factory ChannelPartner.fromJson(Map<String, dynamic> json) => ChannelPartner(
        name: json["name"],
        owner: json["owner"],
        creation: json["creation"] == null ? null : DateTime.parse(json["creation"]),
        modified: json["modified"] == null ? null : DateTime.parse(json["modified"]),
        modifiedBy: json["modified_by"],
        docstatus: json["docstatus"],
        idx: json["idx"],
        firmName: json["firm_name"],
        mobileNumber: json["mobile_number"],
        reraNumber: json["rera_number"],
        email: json["email"],
        territory: json["territory"],
        category: json["category"],
        location: json["location"],
        fullAddress: json["full_address"],
        isDigital: json["is_digital"],
        isReference: json["is_reference"],
        isDataCalling: json["is_data_calling"],
        isRetail: json["is_retail"],
        isUnderConstruction: json["is_under_construction"],
        isRental: json["is_rental"],
        isReadyToMove: json["is_ready_to_move"],
        reqCallingSupport: json["req_calling_support"],
        reqDigitalKit: json["req_digital_kit"],
        reqStandees: json["req_standees"],
        reqSmsBlast: json["req_sms_blast"],
        reqWhatsappBlast: json["req_whatsapp_blast"],
        doctype: json["doctype"],
        contactPersons: json["contact_persons"] == null ? [] : List<ContactPerson>.from(json["contact_persons"].map((x) => ContactPerson.fromJson(x))),
        documents: json["documents"] == null ? [] : List<Document>.from(json["documents"].map((x) => Document.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "name": name,
        "owner": owner,
        "creation": creation?.toIso8601String(),
        "modified": modified?.toIso8601String(),
        "modified_by": modifiedBy,
        "docstatus": docstatus,
        "idx": idx,
        "firm_name": firmName,
        "mobile_number": mobileNumber,
        "rera_number": reraNumber,
        "email": email,
        "territory": territory,
        "category": category,
        "location": location,
        "full_address": fullAddress,
        "is_digital": isDigital,
        "is_reference": isReference,
        "is_data_calling": isDataCalling,
        "is_retail": isRetail,
        "is_under_construction": isUnderConstruction,
        "is_rental": isRental,
        "is_ready_to_move": isReadyToMove,
        "req_calling_support": reqCallingSupport,
        "req_digital_kit": reqDigitalKit,
        "req_standees": reqStandees,
        "req_sms_blast": reqSmsBlast,
        "req_whatsapp_blast": reqWhatsappBlast,
        "doctype": doctype,
        "contact_persons": contactPersons == null ? [] : List<dynamic>.from(contactPersons!.map((x) => x.toJson())),
        "documents": documents == null ? [] : List<dynamic>.from(documents!.map((x) => x.toJson())),
    };
}

class ContactPerson {
    String? name;
    String? owner;
    DateTime? creation;
    DateTime? modified;
    String? modifiedBy;
    int? docstatus;
    int? idx;
    String? fullName;
    String? roles;
    String? mobile;
    String? email;
    String? parent;
    String? parentfield;
    String? parenttype;
    String? doctype;

    ContactPerson({
        this.name,
        this.owner,
        this.creation,
        this.modified,
        this.modifiedBy,
        this.docstatus,
        this.idx,
        this.fullName,
        this.roles,
        this.mobile,
        this.email,
        this.parent,
        this.parentfield,
        this.parenttype,
        this.doctype,
    });

    factory ContactPerson.fromJson(Map<String, dynamic> json) => ContactPerson(
        name: json["name"],
        owner: json["owner"],
        creation: json["creation"] == null ? null : DateTime.parse(json["creation"]),
        modified: json["modified"] == null ? null : DateTime.parse(json["modified"]),
        modifiedBy: json["modified_by"],
        docstatus: json["docstatus"],
        idx: json["idx"],
        fullName: json["full_name"],
        roles: json["roles"],
        mobile: json["mobile"],
        email: json["email"],
        parent: json["parent"],
        parentfield: json["parentfield"],
        parenttype: json["parenttype"],
        doctype: json["doctype"],
    );

    Map<String, dynamic> toJson() => {
        "name": name,
        "owner": owner,
        "creation": creation?.toIso8601String(),
        "modified": modified?.toIso8601String(),
        "modified_by": modifiedBy,
        "docstatus": docstatus,
        "idx": idx,
        "full_name": fullName,
        "roles": roles,
        "mobile": mobile,
        "email": email,
        "parent": parent,
        "parentfield": parentfield,
        "parenttype": parenttype,
        "doctype": doctype,
    };
}

class Document {
    String? name;
    String? owner;
    DateTime? creation;
    DateTime? modified;
    String? modifiedBy;
    int? docstatus;
    int? idx;
    String? documentName;
    String? documentAttachment;
    String? parent;
    String? parentfield;
    String? parenttype;
    String? doctype;

    Document({
        this.name,
        this.owner,
        this.creation,
        this.modified,
        this.modifiedBy,
        this.docstatus,
        this.idx,
        this.documentName,
        this.documentAttachment,
        this.parent,
        this.parentfield,
        this.parenttype,
        this.doctype,
    });

    factory Document.fromJson(Map<String, dynamic> json) => Document(
        name: json["name"],
        owner: json["owner"],
        creation: json["creation"] == null ? null : DateTime.parse(json["creation"]),
        modified: json["modified"] == null ? null : DateTime.parse(json["modified"]),
        modifiedBy: json["modified_by"],
        docstatus: json["docstatus"],
        idx: json["idx"],
        documentName: json["document_name"],
        documentAttachment: json["document_attachment"],
        parent: json["parent"],
        parentfield: json["parentfield"],
        parenttype: json["parenttype"],
        doctype: json["doctype"],
    );

    Map<String, dynamic> toJson() => {
        "name": name,
        "owner": owner,
        "creation": creation?.toIso8601String(),
        "modified": modified?.toIso8601String(),
        "modified_by": modifiedBy,
        "docstatus": docstatus,
        "idx": idx,
        "document_name": documentName,
        "document_attachment": documentAttachment,
        "parent": parent,
        "parentfield": parentfield,
        "parenttype": parenttype,
        "doctype": doctype,
    };
}

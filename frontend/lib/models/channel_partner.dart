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
    
    // New fields
    double? cpQuality;
    String? type; // P1, P2, P3
    String? propertyPreferences; // Under Construction, Ready to Move In, Resale
    
    int? commercial;
    int? luxury;
    int? land;
    int? redevelopment;
    int? residential;
    int? retail;
    int? doesDigitalmarketing;
    int? aopSigned;
    int? givesCallingdata;
    
    String? doctype;
    List<ContactPerson>? contactPersons;
    List<Document>? documents;
    List<ButtonPressedLog>? buttonLogs;
    List<StationPreference>? stationPreferences;

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
        this.cpQuality,
        this.type,
        this.propertyPreferences,
        this.commercial,
        this.luxury,
        this.land,
        this.redevelopment,
        this.residential,
        this.retail,
        this.doesDigitalmarketing,
        this.aopSigned,
        this.givesCallingdata,
        this.doctype,
        this.contactPersons,
        this.documents,
        this.buttonLogs,
        this.stationPreferences,
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
        cpQuality: json["cp_quality"] == null ? null : double.tryParse(json["cp_quality"].toString()),
        type: json["type"],
        propertyPreferences: json["property_preferences"],
        commercial: json["commercial"],
        luxury: json["luxury"],
        land: json["land"],
        redevelopment: json["redevelopment"],
        residential: json["residential"],
        retail: json["retail"],
        doesDigitalmarketing: json["does_digitalmarketing"],
        aopSigned: json["aop_signed"],
        givesCallingdata: json["gives_callingdata"],
        doctype: json["doctype"],
        contactPersons: json["contact_persons"] == null ? [] : List<ContactPerson>.from(json["contact_persons"].map((x) => ContactPerson.fromJson(x))),
        documents: json["documents"] == null ? [] : List<Document>.from(json["documents"].map((x) => Document.fromJson(x))),
        buttonLogs: json["button_logs"] == null ? [] : List<ButtonPressedLog>.from(json["button_logs"].map((x) => ButtonPressedLog.fromJson(x))),
        stationPreferences: json["station_preferences"] == null ? [] : List<StationPreference>.from(json["station_preferences"].map((x) => StationPreference.fromJson(x))),
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
        "cp_quality": cpQuality,
        "type": type,
        "property_preferences": propertyPreferences,
        "commercial": commercial,
        "luxury": luxury,
        "land": land,
        "redevelopment": redevelopment,
        "residential": residential,
        "retail": retail,
        "does_digitalmarketing": doesDigitalmarketing,
        "aop_signed": aopSigned,
        "gives_callingdata": givesCallingdata,
        "doctype": doctype,
        "contact_persons": contactPersons == null ? [] : List<dynamic>.from(contactPersons!.map((x) => x.toJson())),
        "documents": documents == null ? [] : List<dynamic>.from(documents!.map((x) => x.toJson())),
        "button_logs": buttonLogs == null ? [] : List<dynamic>.from(buttonLogs!.map((x) => x.toJson())),
        "station_preferences": stationPreferences == null ? [] : List<dynamic>.from(stationPreferences!.map((x) => x.toJson())),
    };
}

class StationPreference {
    String? name;
    String? owner;
    DateTime? creation;
    DateTime? modified;
    String? modifiedBy;
    int? docstatus;
    int? idx;
    String? railwayRoute;
    String? fromStation;
    String? toStation;
    String? parent;
    String? parentfield;
    String? parenttype;
    String? doctype;

    StationPreference({
        this.name,
        this.owner,
        this.creation,
        this.modified,
        this.modifiedBy,
        this.docstatus,
        this.idx,
        this.railwayRoute,
        this.fromStation,
        this.toStation,
        this.parent,
        this.parentfield,
        this.parenttype,
        this.doctype,
    });

    factory StationPreference.fromJson(Map<String, dynamic> json) => StationPreference(
        name: json["name"],
        owner: json["owner"],
        creation: json["creation"] == null ? null : DateTime.parse(json["creation"]),
        modified: json["modified"] == null ? null : DateTime.parse(json["modified"]),
        modifiedBy: json["modified_by"],
        docstatus: json["docstatus"],
        idx: json["idx"],
        railwayRoute: json["railway_route"],
        fromStation: json["from_station"],
        toStation: json["to_station"],
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
        "railway_route": railwayRoute,
        "from_station": fromStation,
        "to_station": toStation,
        "parent": parent,
        "parentfield": parentfield,
        "parenttype": parenttype,
        "doctype": doctype,
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

class ButtonPressedLog {
    String? name;
    String? owner;
    DateTime? creation;
    DateTime? modified;
    String? modifiedBy;
    int? docstatus;
    int? idx;
    String? dateAndTime;
    String? buttonPressed;
    String? pressedBy;
    String? parent;
    String? parentfield;
    String? parenttype;
    String? doctype;

    ButtonPressedLog({
        this.name,
        this.owner,
        this.creation,
        this.modified,
        this.modifiedBy,
        this.docstatus,
        this.idx,
        this.dateAndTime,
        this.buttonPressed,
        this.pressedBy,
        this.parent,
        this.parentfield,
        this.parenttype,
        this.doctype,
    });

    factory ButtonPressedLog.fromJson(Map<String, dynamic> json) => ButtonPressedLog(
        name: json["name"],
        owner: json["owner"],
        creation: json["creation"] == null ? null : DateTime.parse(json["creation"]),
        modified: json["modified"] == null ? null : DateTime.parse(json["modified"]),
        modifiedBy: json["modified_by"],
        docstatus: json["docstatus"],
        idx: json["idx"],
        dateAndTime: json["date_and_time"],
        buttonPressed: json["button_pressed"],
        pressedBy: json["pressed_by"],
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
        "date_and_time": dateAndTime,
        "button_pressed": buttonPressed,
        "pressed_by": pressedBy,
        "parent": parent,
        "parentfield": parentfield,
        "parenttype": parenttype,
        "doctype": doctype,
    };
}

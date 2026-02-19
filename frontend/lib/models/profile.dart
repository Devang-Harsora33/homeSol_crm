class Profile {
  final String name;
  final String employee;
  final String salutation;
  final String firstName;
  final String? middleName;
  final String? lastName;
  final String employeeName;
  final String jobTitle;
  final String gender;
  final String? dateOfBirth;
  final String dateOfJoining;
  final String? image;
  final String status;
  final String userId;
  final bool createUserPermission;
  final String company;
  final String department;
  final String employmentType;
  final String? employeeNumber;
  final String designation;
  final String? reportsTo;
  final String? branch;
  final String? grade;
  final String? jobApplicant;
  final String? scheduledConfirmationDate;
  final String? finalConfirmationDate;
  final String? contractEndDate;
  final int noticeNumberOfDays;
  final String? dateOfRetirement;
  final String? cellNumber;
  final String? personalEmail;
  final String? companyEmail;
  final String preferedContactEmail;
  final String? preferedEmail;
  final bool unsubscribed;
  final String? currentAddress;
  final String currentAccommodationType;
  final String? permanentAddress;
  final String permanentAccommodationType;
  final String? personToBeContacted;
  final String? emergencyPhoneNumber;
  final String? relation;
  final String? attendanceDeviceId;
  final String? holidayList;
  final String? defaultShift;
  final String? expenseApprover;
  final String? leaveApprover;
  final String? shiftRequestApprover;
  final double ctc;
  final String salaryCurrency;
  final String salaryMode;
  final String? payrollCostCenter;
  final String? panNumber;
  final String? providentFundAccount;
  final String? bankName;
  final String? bankAcNo;
  final String? ifscCode;
  final String? micrCode;
  final String? iban;
  final String maritalStatus;
  final String? familyBackground;
  final String bloodGroup;
  final String? healthDetails;
  final String? healthInsuranceProvider;
  final String? healthInsuranceNo;
  final String? passportNumber;
  final String? validUpto;
  final String? dateOfIssue;
  final String? placeOfIssue;
  final String? bio;
  final String? resignationLetterDate;
  final String? relievingDate;
  final String? heldOn;
  final String? newWorkplace;
  final String leaveEncashed;
  final String? encashmentDate;
  final String? reasonForLeaving;
  final String? feedback;
  final int lft;
  final int rgt;
  final String? oldParent;
  final String doctype;
  final List<dynamic> internalWorkHistory;
  final List<dynamic> externalWorkHistory;
  final List<dynamic> education;

  Profile({
    required this.name,
    required this.employee,
    required this.salutation,
    required this.firstName,
    this.middleName,
    this.lastName,
    required this.employeeName,
    required this.jobTitle,
    required this.gender,
    this.dateOfBirth,
    required this.dateOfJoining,
    this.image,
    required this.status,
    required this.userId,
    required this.createUserPermission,
    required this.company,
    required this.department,
    required this.employmentType,
    this.employeeNumber,
    required this.designation,
    this.reportsTo,
    this.branch,
    this.grade,
    this.jobApplicant,
    this.scheduledConfirmationDate,
    this.finalConfirmationDate,
    this.contractEndDate,
    required this.noticeNumberOfDays,
    this.dateOfRetirement,
    this.cellNumber,
    this.personalEmail,
    this.companyEmail,
    required this.preferedContactEmail,
    this.preferedEmail,
    required this.unsubscribed,
    this.currentAddress,
    required this.currentAccommodationType,
    this.permanentAddress,
    required this.permanentAccommodationType,
    this.personToBeContacted,
    this.emergencyPhoneNumber,
    this.relation,
    this.attendanceDeviceId,
    this.holidayList,
    this.defaultShift,
    this.expenseApprover,
    this.leaveApprover,
    this.shiftRequestApprover,
    required this.ctc,
    required this.salaryCurrency,
    required this.salaryMode,
    this.payrollCostCenter,
    this.panNumber,
    this.providentFundAccount,
    this.bankName,
    this.bankAcNo,
    this.ifscCode,
    this.micrCode,
    this.iban,
    required this.maritalStatus,
    this.familyBackground,
    required this.bloodGroup,
    this.healthDetails,
    this.healthInsuranceProvider,
    this.healthInsuranceNo,
    this.passportNumber,
    this.validUpto,
    this.dateOfIssue,
    this.placeOfIssue,
    this.bio,
    this.resignationLetterDate,
    this.relievingDate,
    this.heldOn,
    this.newWorkplace,
    required this.leaveEncashed,
    this.encashmentDate,
    this.reasonForLeaving,
    this.feedback,
    required this.lft,
    required this.rgt,
    this.oldParent,
    required this.doctype,
    required this.internalWorkHistory,
    required this.externalWorkHistory,
    required this.education,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      name: json['name'] ?? '',
      employee: json['employee'] ?? '',
      salutation: json['salutation'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'],
      lastName: json['last_name'],
      employeeName: json['employee_name'] ?? '',
      jobTitle: json['job_title'] ?? '',
      gender: json['gender'] ?? '',
      dateOfBirth: json['date_of_birth'],
      dateOfJoining: json['date_of_joining'] ?? '',
      image: json['image'],
      status: json['status'] ?? '',
      userId: json['user_id'] ?? '',
      createUserPermission: json['create_user_permission'] == 1,
      company: json['company'] ?? '',
      department: json['department'] ?? '',
      employmentType: json['employment_type'] ?? '',
      employeeNumber: json['employee_number'],
      designation: json['designation'] ?? '',
      reportsTo: json['reports_to'],
      branch: json['branch'],
      grade: json['grade'],
      jobApplicant: json['job_applicant'],
      scheduledConfirmationDate: json['scheduled_confirmation_date'],
      finalConfirmationDate: json['final_confirmation_date'],
      contractEndDate: json['contract_end_date'],
      noticeNumberOfDays: json['notice_number_of_days'] ?? 0,
      dateOfRetirement: json['date_of_retirement'],
      cellNumber: json['cell_number'],
      personalEmail: json['personal_email'],
      companyEmail: json['company_email'],
      preferedContactEmail: json['prefered_contact_email'] ?? '',
      preferedEmail: json['prefered_email'],
      unsubscribed: json['unsubscribed'] == 1,
      currentAddress: json['current_address'],
      currentAccommodationType: json['current_accommodation_type'] ?? '',
      permanentAddress: json['permanent_address'],
      permanentAccommodationType: json['permanent_accommodation_type'] ?? '',
      personToBeContacted: json['person_to_be_contacted'],
      emergencyPhoneNumber: json['emergency_phone_number'],
      relation: json['relation'],
      attendanceDeviceId: json['attendance_device_id'],
      holidayList: json['holiday_list'],
      defaultShift: json['default_shift'],
      expenseApprover: json['expense_approver'],
      leaveApprover: json['leave_approver'],
      shiftRequestApprover: json['shift_request_approver'],
      ctc: (json['ctc'] ?? 0.0).toDouble(),
      salaryCurrency: json['salary_currency'] ?? '',
      salaryMode: json['salary_mode'] ?? '',
      payrollCostCenter: json['payroll_cost_center'],
      panNumber: json['pan_number'],
      providentFundAccount: json['provident_fund_account'],
      bankName: json['bank_name'],
      bankAcNo: json['bank_ac_no'],
      ifscCode: json['ifsc_code'],
      micrCode: json['micr_code'],
      iban: json['iban'],
      maritalStatus: json['marital_status'] ?? '',
      familyBackground: json['family_background'],
      bloodGroup: json['blood_group'] ?? '',
      healthDetails: json['health_details'],
      healthInsuranceProvider: json['health_insurance_provider'],
      healthInsuranceNo: json['health_insurance_no'],
      passportNumber: json['passport_number'],
      validUpto: json['valid_upto'],
      dateOfIssue: json['date_of_issue'],
      placeOfIssue: json['place_of_issue'],
      bio: json['bio'],
      resignationLetterDate: json['resignation_letter_date'],
      relievingDate: json['relieving_date'],
      heldOn: json['held_on'],
      newWorkplace: json['new_workplace'],
      leaveEncashed: json['leave_encashed'] ?? '',
      encashmentDate: json['encashment_date'],
      reasonForLeaving: json['reason_for_leaving'],
      feedback: json['feedback'],
      lft: json['lft'] ?? 0,
      rgt: json['rgt'] ?? 0,
      oldParent: json['old_parent'],
      doctype: json['doctype'] ?? '',
      internalWorkHistory: json['internal_work_history'] ?? [],
      externalWorkHistory: json['external_work_history'] ?? [],
      education: json['education'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'employee': employee,
      'salutation': salutation,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'employee_name': employeeName,
      'job_title': jobTitle,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'date_of_joining': dateOfJoining,
      'image': image,
      'status': status,
      'user_id': userId,
      'create_user_permission': createUserPermission ? 1 : 0,
      'company': company,
      'department': department,
      'employment_type': employmentType,
      'employee_number': employeeNumber,
      'designation': designation,
      'reports_to': reportsTo,
      'branch': branch,
      'grade': grade,
      'job_applicant': jobApplicant,
      'scheduled_confirmation_date': scheduledConfirmationDate,
      'final_confirmation_date': finalConfirmationDate,
      'contract_end_date': contractEndDate,
      'notice_number_of_days': noticeNumberOfDays,
      'date_of_retirement': dateOfRetirement,
      'cell_number': cellNumber,
      'personal_email': personalEmail,
      'company_email': companyEmail,
      'prefered_contact_email': preferedContactEmail,
      'prefered_email': preferedEmail,
      'unsubscribed': unsubscribed ? 1 : 0,
      'current_address': currentAddress,
      'current_accommodation_type': currentAccommodationType,
      'permanent_address': permanentAddress,
      'permanent_accommodation_type': permanentAccommodationType,
      'person_to_be_contacted': personToBeContacted,
      'emergency_phone_number': emergencyPhoneNumber,
      'relation': relation,
      'attendance_device_id': attendanceDeviceId,
      'holiday_list': holidayList,
      'default_shift': defaultShift,
      'expense_approver': expenseApprover,
      'leave_approver': leaveApprover,
      'shift_request_approver': shiftRequestApprover,
      'ctc': ctc,
      'salary_currency': salaryCurrency,
      'salary_mode': salaryMode,
      'payroll_cost_center': payrollCostCenter,
      'pan_number': panNumber,
      'provident_fund_account': providentFundAccount,
      'bank_name': bankName,
      'bank_ac_no': bankAcNo,
      'ifsc_code': ifscCode,
      'micr_code': micrCode,
      'iban': iban,
      'marital_status': maritalStatus,
      'family_background': familyBackground,
      'blood_group': bloodGroup,
      'health_details': healthDetails,
      'health_insurance_provider': healthInsuranceProvider,
      'health_insurance_no': healthInsuranceNo,
      'passport_number': passportNumber,
      'valid_upto': validUpto,
      'date_of_issue': dateOfIssue,
      'place_of_issue': placeOfIssue,
      'bio': bio,
      'resignation_letter_date': resignationLetterDate,
      'relieving_date': relievingDate,
      'held_on': heldOn,
      'new_workplace': newWorkplace,
      'leave_encashed': leaveEncashed,
      'encashment_date': encashmentDate,
      'reason_for_leaving': reasonForLeaving,
      'feedback': feedback,
      'lft': lft,
      'rgt': rgt,
      'old_parent': oldParent,
      'doctype': doctype,
      'internal_work_history': internalWorkHistory,
      'external_work_history': externalWorkHistory,
      'education': education,
    };
  }
}

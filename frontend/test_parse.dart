import 'dart:convert';
import 'lib/models/sourcing.dart';

void main() {
  String jsonStr = '''{
    "data": {
        "name": "SFS-2026-00121",
        "owner": "tonystark@homesolindia.com",
        "creation": "2026-05-06 01:13:01.535051",
        "modified": "2026-05-06 01:13:01.535051",
        "modified_by": "tonystark@homesolindia.com",
        "docstatus": 0,
        "idx": 0,
        "sales_partner": "devangkh1206@gmail.com",
        "contact_person_met": "Devang",
        "mobile_number": "9082512330",
        "whatsapp_number": "876576767",
        "interested_project": "PROJ-00002",
        "next_follow_up": "2026-05-13 01:11:55",
        "visit_status": "Visit Done",
        "visit_type": "Open",
        "cp_interest": "Interested",
        "visit_date": "2026-05-06 01:15:00",
        "remark": "aasdasdasd",
        "location": "{\\"type\\":\\"FeatureCollection\\",\\"features\\":[{\\"type\\":\\"Feature\\",\\"properties\\":{\\"point_type\\":\\"marker\\"},\\"geometry\\":{\\"type\\":\\"Point\\",\\"coordinates\\":[-122.084,37.4219983]}}]}",
        "address": "abc",
        "enter_otp": "421754",
        "is_verified": 1,
        "offered_coffee": 0,
        "met_the_owner": 0,
        "asked_about_price_trends": 0,
        "considering_redevelopment": 0,
        "concerned_about_interest_rates": 0,
        "compared_micro_markets": 0,
        "strictly_rera_registered": 0,
        "doctype": "Sales Fields Service"
    }
}''';
  var data = json.decode(jsonStr);
  Sourcing sourcing = Sourcing.fromJson(data['data']);
  print('Visit Type: ${sourcing.visitType}');
  print('CP Interest: ${sourcing.cpInterest}');
  print('Interested Project: ${sourcing.interestedProject}');
}

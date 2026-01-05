# Copyright (c) 2025, homesol_team and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe import _
import random

class SiteVisit(Document):
    @frappe.whitelist()
    def trigger_otp(self):
        # 1. Validate that a Lead is selected
        if not self.lead:
            frappe.throw(_("Please select a Lead first to send OTP."))

        # 2. Fetch the Mobile Number directly from the Lead Record
        # We look up the 'mobile_no' field in the 'Lead' DocType
        mobile_number = frappe.db.get_value("Lead", self.lead, "mobile_no")

        if not mobile_number:
            frappe.throw(_("The selected Lead ({0}) does not have a Mobile Number saved.").format(self.lead))

        # 3. Generate a 6-digit Random OTP
        otp = str(random.randint(100000, 999999))

        # 4. Store OTP in Cache (Key is specific to this Lead)
        # Expires in 600 seconds (10 minutes)
        cache_key = f"site_visit_otp:{self.lead}"
        frappe.cache().set_value(cache_key, otp, expires_in_sec=600)

        # 5. Send the Message
        message = f"Hello! Your Verification Code for the Site Visit is {otp}. Valid for 10 mins."

        try:
            # --- OPTION A: REAL SMS (Uncomment if you have SMS Settings configured) ---
            # from frappe.core.doctype.sms_settings.sms_settings import send_sms
            # send_sms([mobile_number], message)
            
            # --- OPTION B: DEBUGGING (Pop-up on screen for testing) ---
            # This allows you to test without spending money on SMS credits
            frappe.msgprint(f"<b>DEBUG MODE:</b><br>Sending to Lead: <b>{mobile_number}</b><br>OTP: <b>{otp}</b>")
            
            return "success"
        except Exception as e:
            frappe.log_error(message=str(e), title="OTP Send Error")
            return "failed"

    @frappe.whitelist()
    def verify_client_otp(self, user_otp):
        if not self.lead:
            frappe.throw(_("Lead information is missing."))

        # 1. Retrieve the OTP from Cache using the Lead ID
        cache_key = f"site_visit_otp:{self.lead}"
        cached_otp = frappe.cache().get_value(cache_key)

        if not cached_otp:
            frappe.throw(_("The OTP has expired or is invalid. Please generate a new one."))

        # 2. Compare User Input vs Cached OTP
        if str(user_otp) == str(cached_otp):
            # Success: Clear the cache so the OTP cannot be used twice
            frappe.cache().delete_value(cache_key)
            return True
        else:
            return False


@frappe.whitelist()
def flutter_trigger_otp(site_visit_name):
    """
    API Endpoint for Mobile App to trigger OTP.
    It reuses the exact same logic but handles the object fetching manually.
    """
    if not site_visit_name:
        frappe.throw(_("Site Visit Name is required"))
    
    # 1. Load the document
    doc = frappe.get_doc("Site Visit", site_visit_name)
    
    # 2. Call the existing function (so logic stays consistent)
    # This ensures your CRM and App use the exact same cache keys and rules.
    return doc.trigger_otp()

@frappe.whitelist()
def flutter_verify_otp(site_visit_name, user_otp):
    """
    API Endpoint for Mobile App to verify OTP.
    """
    if not site_visit_name:
        frappe.throw(_("Site Visit Name is required"))
        
    doc = frappe.get_doc("Site Visit", site_visit_name)
    
    # Call the existing function
    result = doc.verify_client_otp(user_otp)
    
    if result is True:
        # If verified, we also update the document status immediately for the App
        doc.db_set("is_verified", 1)
        doc.save()
        return "success"
    else:
        return "failed"
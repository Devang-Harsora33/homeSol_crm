# Copyright (c) 2025, homesol_team and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe import _
import random

class ChannelPartnerVisit(Document):
    @frappe.whitelist()
    def trigger_otp(self):
        # 1. Validate that a Channel Partner is selected
        if not self.channel_partner:
            frappe.throw(_("Please select a Channel Partner first to send OTP."))

        # 2. Fetch the Mobile Number directly from the 'Channel Partner' DocType
        # Note: Ensure the mobile field in 'Channel Partner' is named 'mobile_number'
        mobile_number = frappe.db.get_value("Channel Partner", self.channel_partner, "mobile_number")

        if not mobile_number:
            frappe.throw(_("The selected Channel Partner ({0}) does not have a Mobile Number saved.").format(self.channel_partner))

        # 3. Generate a 6-digit Random OTP
        otp = str(random.randint(100000, 999999))

        # 4. Store OTP in Cache (Key is specific to this Channel Partner)
        # We use a different key prefix 'cp_visit_otp' to avoid mixing with Lead OTPs
        cache_key = f"cp_visit_otp:{self.channel_partner}"
        frappe.cache().set_value(cache_key, otp, expires_in_sec=600)

        # 5. Send the Message
        message = f"Hello! Your Verification Code for the CP Visit is {otp}. Valid for 10 mins."

        try:
            # --- DEBUG MODE (Prints to screen) ---
            frappe.msgprint(f"<b>DEBUG MODE:</b><br>Sending to CP: <b>{mobile_number}</b><br>OTP: <b>{otp}</b>")
            
            # --- REAL SMS MODE (Uncomment to use) ---
            # from frappe.core.doctype.sms_settings.sms_settings import send_sms
            # send_sms([mobile_number], message)
            
            return "success"
        except Exception as e:
            frappe.log_error(message=str(e), title="OTP Send Error")
            return "failed"

    @frappe.whitelist()
    def verify_client_otp(self, user_otp):
        if not self.channel_partner:
            frappe.throw(_("Channel Partner information is missing."))

        # 1. Retrieve the OTP from Cache
        cache_key = f"cp_visit_otp:{self.channel_partner}"
        cached_otp = frappe.cache().get_value(cache_key)

        if not cached_otp:
            frappe.throw(_("The OTP has expired or is invalid. Please generate a new one."))

        # 2. Compare User Input vs Cached OTP
        if str(user_otp) == str(cached_otp):
            frappe.cache().delete_value(cache_key)
            return True
        else:
            return False
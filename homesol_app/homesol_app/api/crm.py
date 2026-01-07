import frappe
from frappe import _
import random

@frappe.whitelist()
def get_my_lead():
    logged_in_user = frappe.session.user
    if logged_in_user == "Guest":
        frappe.throw("You must be logged in to view your lead.")

    lead_name = frappe.db.get_value("Lead", {"lead_owner": logged_in_user}, "name")
    if not lead_name:
        return {"message": f"No Lead found assigned to user {logged_in_user}"}

    doc = frappe.get_doc("Lead", lead_name)
    return doc.as_dict()

@frappe.whitelist(allow_guest=True)
def get_all_projects():
    project_list = frappe.get_all("Property Projects", fields=["name"])
    full_data = []
    for project in project_list:
        doc = frappe.get_doc("Property Projects", project.name)
        full_data.append(doc.as_dict())
    return full_data

@frappe.whitelist(allow_guest=True)
def get_all_developers():
    dev_list = frappe.get_all("Developer", fields=["name"])
    full_data = []
    for dev in dev_list:
        doc = frappe.get_doc("Developer", dev.name)
        full_data.append(doc.as_dict())
    return full_data

@frappe.whitelist(allow_guest=True)
def get_all_mandates():
    mandate_list = frappe.get_all("Mandate", fields=["name"]) 
    full_data = []
    for item in mandate_list:
        doc = frappe.get_doc("Mandate", item.name)
        full_data.append(doc.as_dict())
    return full_data

@frappe.whitelist(allow_guest=True) 
def get_all_site_visits():
    visit_list = frappe.get_all("Site Visit", fields=["name"])
    full_data = []
    for visit in visit_list:
        doc = frappe.get_doc("Site Visit", visit.name)
        full_data.append(doc.as_dict())
    return full_data

@frappe.whitelist(allow_guest=True)
def get_all_channel_partners():
    cp_list = frappe.get_all("Channel Partner", fields=["name"])
    full_data = []
    for cp in cp_list:
        doc = frappe.get_doc("Channel Partner", cp.name)
        full_data.append(doc.as_dict())
    return full_data

@frappe.whitelist(allow_guest=True)
def get_all_sales_team():
    team_list = frappe.get_all("Property Sales Team", fields=["name"])
    full_data = []
    for team in team_list:
        doc = frappe.get_doc("Property Sales Team", team.name)
        full_data.append(doc.as_dict())
    return full_data




@frappe.whitelist()
def trigger_otp_lead(mobile_no, lead_name=None):
    """
    Generates OTP.
    - If Lead is new (no valid ID), uses Mobile No as the cache key.
    - If Lead is saved, uses Lead Name as the cache key.
    """
    if not mobile_no:
        frappe.throw(_("Mobile Number is required to send OTP"))

    # Determine the unique Cache Key
    # If lead_name is real (not None and not temporary 'new-lead-...'), use it.
    if lead_name and not lead_name.startswith("new-lead"):
        cache_key = f"lead_otp:{lead_name}"
    else:
        # New Unsaved Lead -> Use Mobile Number as key
        cache_key = f"lead_otp:{mobile_no}"

    # Generate 6-digit Random OTP
    otp = str(random.randint(100000, 999999))

    # Store OTP in Cache (Expires in 10 minutes)
    frappe.cache().set_value(cache_key, otp, expires_in_sec=600)

    # DEBUG: Show OTP on screen
    frappe.msgprint(f"<b>DEBUG MODE:</b><br>Sending to: <b>{mobile_no}</b><br>OTP: <b>{otp}</b>")

    # TODO: Uncomment for real SMS
    # from frappe.core.doctype.sms_settings.sms_settings import send_sms
    # send_sms([mobile_no], f"Your verification code is {otp}")
    
    return "success"


@frappe.whitelist()
def verify_otp_lead(user_otp, mobile_no, lead_name=None):
    """
    Verifies OTP using the same key logic as trigger.
    """
    if not user_otp:
        return False

    # Reconstruct the Key to find the OTP
    if lead_name and not lead_name.startswith("new-lead"):
        cache_key = f"lead_otp:{lead_name}"
    else:
        cache_key = f"lead_otp:{mobile_no}"

    cached_otp = frappe.cache().get_value(cache_key)

    if cached_otp and str(user_otp) == str(cached_otp):
        frappe.cache().delete_value(cache_key) # Clear cache so it can't be used twice
        return True
    else:
        return False
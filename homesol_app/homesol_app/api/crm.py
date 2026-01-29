import frappe
from frappe import _
import random


@frappe.whitelist()
def get_my_leads():
    logged_in_user = frappe.session.user
    if logged_in_user == "Guest":
        frappe.throw("You must be logged in to view your leads.")

    # --- TEAM LEAD LOGIC (Optional: Keep this if you want team access) ---
    users_to_fetch = [logged_in_user]
    
    # 1. Find Employee linked to User
    employee = frappe.db.get_value("Employee", {"user_id": logged_in_user}, "name")
    
    if employee:
        # 2. Check if Team Lead
        team_member = frappe.db.get_value("Sales Team Member", {"employee": employee}, ["parent", "role"], as_dict=True)
        if team_member and team_member.role == "Team Lead":
            # Fetch all team members
            team_employees = frappe.get_all("Sales Team Member", filters={"parent": team_member.parent}, fields=["employee"])
            emp_ids = [e.employee for e in team_employees]
            linked_users = frappe.get_all("Employee", filters={"name": ["in", emp_ids]}, fields=["user_id"])
            users_to_fetch = [u.user_id for u in linked_users if u.user_id]
    # ---------------------------------------------------------------------

    # --- FETCH ALL LEADS (The Fix) ---
    # We use get_list instead of get_value to return MULTIPLE records
    leads = frappe.get_list(
        "Lead",
        filters={
            "lead_owner": ["in", users_to_fetch]
        },
        fields=["*"],  # <--- '*' fetches ALL fields (standard & custom)
        order_by="creation desc"
    )

    return leads

@frappe.whitelist()
def get_team_leads():
    user = frappe.session.user
    
    users_to_fetch = [user]
    
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")

    if employee:
        team_member = frappe.db.get_value(
            "Sales Team Member", 
            {"employee": employee}, 
            ["parent", "role"], 
            as_dict=True
        )

        if team_member and team_member.role == "Team Lead":
            # Get all team members
            team_employees = frappe.get_all(
                "Sales Team Member", 
                filters={"parent": team_member.parent}, 
                fields=["employee"]
            )
            emp_ids = [e.employee for e in team_employees]

            # Get user emails for those employees
            linked_users = frappe.get_all(
                "Employee", 
                filters={"name": ["in", emp_ids]}, 
                fields=["user_id"]
            )
            users_to_fetch = [u.user_id for u in linked_users if u.user_id]

    # --- 2. Fetch Leads with EXACTLY ALL FIELDS ---
    leads = frappe.get_list(
        "Lead",
        filters={
            "lead_owner": ["in", users_to_fetch]
        },
        fields=['*'],  # Fetch all fields
        order_by="creation desc"
    )

    return leads

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


@frappe.whitelist(allow_guest=True)
def get_all_tickets():
    ticket_list = frappe.get_all("Tickets", fields=["name"])
    full_data = []
    for ticket in ticket_list:
        doc = frappe.get_doc("Tickets", ticket.name)
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
    

@frappe.whitelist()
def get_team_site_visits():
    logged_in_user = frappe.session.user
    
    if logged_in_user == "Guest":
        frappe.throw("You must be logged in to view site visits.")

    users_to_fetch = [logged_in_user]
    employee = frappe.db.get_value("Employee", {"user_id": logged_in_user}, "name")
    
    if employee:
        team_member = frappe.db.get_value(
            "Sales Team Member", 
            {"employee": employee}, 
            ["parent", "role"], 
            as_dict=True
        )

        if team_member and team_member.role == "Team Lead":
            # If Team Lead -> Fetch ALL members of that team
            team_employees = frappe.get_all(
                "Sales Team Member", 
                filters={"parent": team_member.parent}, 
                fields=["employee"]
            )
            
            # Convert Member Employee IDs -> User Emails
            emp_ids = [e.employee for e in team_employees]
            linked_users = frappe.get_all(
                "Employee", 
                filters={"name": ["in", emp_ids]}, 
                fields=["user_id"]
            )
            
            # Add all team members' emails to the fetch list
            users_to_fetch = [u.user_id for u in linked_users if u.user_id]

    # 3. Fetch Site Visits for ALL identified users
    visits = frappe.get_all(
        "Site Visit",
        fields=[
            "name",           
            "lead",           
            "project",        
            "visit_date",     
            "status",         
            "remark",         
            "creation",       
            "visit_scheduled_datetime",
            "owner" # Added owner so you can see WHO did the visit
        ],
        filters={
            "owner": ["in", users_to_fetch]  # <--- Filters by the whole team list
        },
        order_by="visit_date desc" 
    )
    
    return visits
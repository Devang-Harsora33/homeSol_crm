import frappe
from frappe.utils import today, add_days

@frappe.whitelist()
def get_my_profile():
    logged_in_user = frappe.session.user
    if logged_in_user == "Guest":
        frappe.throw("You must be logged in to view your profile.")

    employee_name = frappe.db.get_value("Employee", {"user_id": logged_in_user}, "name")
    if not employee_name:
        return {"status": "error", "message": "No Employee record found linked to this user."}

    doc = frappe.get_doc("Employee", employee_name)
    return doc.as_dict()


@frappe.whitelist()
def get_my_tickets():
    return frappe.get_all(
        "Tickets",
        fields=[
            "name",           
            "creation",       
            "status",        
            "priority",       
            "category",       
            "description",   
            "raised_by"
        ],
        filters={
            "raised_by": frappe.session.user
        },
        order_by="creation desc"    )

@frappe.whitelist()
def get_my_site_visits():
    user = frappe.session.user
    
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
            "visit_scheduled_datetime" # Scheduled Time
        ],
        filters={
            "owner": user  
        },
        order_by="visit_date desc" 
    )
    
    return visits

@frappe.whitelist()
def get_my_sources():
    
    user = frappe.session.user
    
    sources = frappe.get_all(
        "Sales Fields Service",
        fields=["*"
            # # Standard Standard System Fields
            # "name",
            # "owner",
            # "creation",
            # "modified",
            # "modified_by",
            # "docstatus", # 0 for Draft, 1 for Submitted, 2 for Cancelled
            # "idx",
            
            # # Core Visit Info
            # "sales_partner",
            # "contact_person_met",
            # "mobile_number",
            # "whatsapp_number",
            # "visit_status",
            # "visit_date",
            # "remark",
            # "address",
            # "location",
            
            # # Work Type Checkboxes
            # "digital",
            # "reference",
            # "data_calling",
            
            # # Business Mode Checkboxes
            # "retail",
            # "under_construction",
            # "rental",
            # "ready_to_move",
            
            # # CP Requirement Checkboxes
            # "calling_support",
            # "digital_kit",
            # "standees",
            # "sms_blast",
            # "whatsapp_blast"
        ],
        filters={
            "owner": user  # Only show records owned by the logged-in user
        },
        order_by="visit_date desc"
    )
    
    return sources

@frappe.whitelist()
def get_user_full_name(user_id):
    """
    Takes a user_id (email) and returns their full name.
    """
    # 1. Try to get the official name from the Employee profile first
    full_name = frappe.db.get_value("Employee", {"user_id": user_id}, "employee_name")
    
    # 2. If they aren't an Employee, fall back to the standard User profile
    if not full_name:
        full_name = frappe.db.get_value("User", user_id, "full_name")
        
    # 3. Return the exact JSON structure you need
    if full_name:
        return {
            "user_id": user_id,
            "full_name": full_name
        }
    else:
        # Failsafe if the email doesn't exist in the system at all
        return {
            "user_id": user_id,
            "full_name": "Unknown User"
        }
    
@frappe.whitelist(allow_guest=True, methods=['GET'])
def get_app_assets(category=None):
    # Only fetch assets where 'is_active' is checked
    filters = {"is_active": 1}
    
    # If your Flutter app asks for a specific category (e.g., "?category=Banner")
    if category:
        filters["asset_category"] = category

    # Fetch the data safely
    assets = frappe.get_all(
        "App Assets",  # Make sure this exactly matches your DocType name
        filters=filters,
        fields=["name", "asset_name", "asset_category", "asset_file"],
        order_by="creation desc",
        ignore_permissions=True  # Prevents 403 errors
    )
    
    # Automatically grab your server's domain (https://erp.homesolindia.com)
    domain = frappe.utils.get_url()
    
    # Clean up the URLs for Flutter
    for asset in assets:
        if asset.asset_file and asset.asset_file.startswith("/files/"):
            asset.full_url = f"{domain}{asset.asset_file}"
        else:
            asset.full_url = asset.asset_file

    return assets

@frappe.whitelist()
def get_users_activity_stats(days=7, target_user=None):
    cutoff_date = add_days(today(), -int(days))
    cutoff_datetime = f"{cutoff_date} 00:00:00"
    
    # Build list of employees to process
    filters = {"status": "Active"}
    if target_user:
        filters["user_id"] = target_user
        
    employees = frappe.get_all("Employee", filters=filters, fields=["name", "employee_name", "user_id"])
    
    # Collect all user_emails and employee_names
    user_emails = [e.user_id for e in employees if e.user_id]
    employee_names = [e.name for e in employees]
    
    if not employees:
        return []
        
    # Bulk fetch ALL fields using ["*"]
    leads = frappe.get_all("Lead", filters={"lead_owner": ["in", user_emails], "creation": [">=", cutoff_datetime]}, fields=["*"])
    
    # Fetch Site Visits and Followups for these leads
    lead_names = [l.name for l in leads]
    site_visits = []
    followups = []
    if lead_names:
        site_visits = frappe.get_all("Site Visit", filters={"lead": ["in", lead_names]}, fields=["*"])
        followups = frappe.get_all("Lead FollowUps", filters={"parent": ["in", lead_names]}, fields=["*"])
        
    # Map site visits and followups to leads
    sv_map = {}
    for sv in site_visits:
        sv_map.setdefault(sv.get("lead"), []).append(sv)
        
    fu_map = {}
    for fu in followups:
        fu_map.setdefault(fu.get("parent"), []).append(fu)
        
    # Attach them to the lead records
    for l in leads:
        l["site_visits"] = sv_map.get(l.name, [])
        l["followups"] = fu_map.get(l.name, [])
    
    sources = frappe.get_all("Sales Fields Service", filters={"owner": ["in", user_emails], "creation": [">=", cutoff_datetime]}, fields=["*"])
    cps = frappe.get_all("Channel Partner", filters={"owner": ["in", user_emails], "creation": [">=", cutoff_datetime]}, fields=["*"])
    
    checkins = frappe.get_all("Employee Checkin", filters={"employee": ["in", employee_names], "time": [">=", cutoff_datetime]}, fields=["*"])
    attendances = frappe.get_all("Attendance", filters={"employee": ["in", employee_names], "docstatus": 1, "attendance_date": [">=", cutoff_date]}, fields=["*"])
    
    # Map lists
    lead_map = {}
    source_map = {}
    cp_map = {}
    
    for l in leads:
        lead_map.setdefault(l.get("lead_owner"), []).append(l)
    for s in sources:
        source_map.setdefault(s.get("owner"), []).append(s)
    for c in cps:
        cp_map.setdefault(c.get("owner"), []).append(c)
        
    in_map = {}
    out_map = {}
    for c in checkins:
        if c.get("log_type") == "IN":
            in_map.setdefault(c.get("employee"), []).append(c)
        elif c.get("log_type") == "OUT":
            out_map.setdefault(c.get("employee"), []).append(c)
            
    att_map = {}
    for a in attendances:
        att_map.setdefault(a.get("employee"), []).append(a)
        
    results = []
    
    for emp in employees:
        user_email = emp.user_id
        
        results.append({
            "employee": emp.name,
            "employee_name": emp.employee_name,
            "user_id": user_email,
            "leads": lead_map.get(user_email, []) if user_email else [],
            "sourcing": source_map.get(user_email, []) if user_email else [],
            "channel_partners": cp_map.get(user_email, []) if user_email else [],
            "checkins": in_map.get(emp.name, []),
            "checkouts": out_map.get(emp.name, []),
            "attendance": att_map.get(emp.name, [])
        })
        
    return results


@frappe.whitelist()
def get_my_construction_finance_applications():
    user = frappe.session.user
    
    applications = frappe.get_all(
        "Construction Finance Application",
        fields=["*"
            # "name",
            # "owner",
            # "creation",
            # "modified",
            # "modified_by",
            # "docstatus",
            # "idx",
            # "developer",
            # "project",
            # "meeting_type",
            # "meeting_schedule",
            # "fund_requirement",
            # "submission_linked"
        ],
        filters={
            "owner": user
        },
        order_by="creation desc" 
    )
    
    return applications


@frappe.whitelist()
def get_my_construction_finance_websites():
    user = frappe.session.user
    
    websites = frappe.get_all(
        "Construction Finance Website",
        fields=["*"], # The asterisk wildcard forces Frappe to return every single field
        filters={
            "owner": user
        },
        order_by="creation desc" 
    )
    
    return websites



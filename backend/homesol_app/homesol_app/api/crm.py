import frappe
from frappe import _
import random
import json


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

@frappe.whitelist(methods=['GET'])
def get_leads_by_developer(developer_id):
    if not developer_id:
        return {"error": "Developer ID is required"}

    current_user = frappe.session.user
    
    if current_user != "Administrator":
        
        actual_developer_email = frappe.db.get_value("Developer", developer_id, "username")
        
        if actual_developer_email != current_user:
            frappe.throw("Not Authorized: You can only view your own leads.", frappe.PermissionError)
    # ----------------------

    # 1. Find all projects that belong to this specific developer
    projects = frappe.get_all(
        "Property Projects",
        filters={"developer": developer_id},
        fields=["name"],
        ignore_permissions=True # Safe: We verified their identity above
    )

    if not projects:
        return []

    project_ids = [project.name for project in projects]

    # 2. Fetch all Leads interested in any of these projects
    leads = frappe.get_all(
        "Lead",
        filters={
            "custom_interested_project": ["in", project_ids]
        },
        fields=["*"],
        order_by="creation desc",
        ignore_permissions=True # Safe: We verified their identity above
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
def get_all_project_locations():
    # Only fetch name, project_name, and location to make the API super fast
    project_list = frappe.get_all("Property Projects", fields=["name", "project_name", "location"])
    
    clean_locations = []
    
    for project in project_list:
        if project.location:
            try:
                # 1. Convert the GeoJSON string into a Python dictionary
                loc_data = json.loads(project.location)
                
                # 2. Drill down to the coordinates array [Longitude, Latitude]
                coordinates = loc_data.get("features")[0].get("geometry").get("coordinates")
                
                # 3. Extract them safely
                if coordinates and len(coordinates) == 2:
                    longitude = coordinates[0]
                    latitude = coordinates[1]
                    
                    clean_locations.append({
                        "project_id": project.name,
                        "project_name": project.project_name,
                        "latitude": latitude,   # Flipped to standard Lat/Lng order for Flutter Maps!
                        "longitude": longitude
                    })
            except Exception as e:
                # If a project has a corrupted location string, skip it without crashing
                continue
                
    return clean_locations

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

@frappe.whitelist(methods=['GET'])
def get_site_visits_by_developer(developer_id):
    if not developer_id:
        return {"error": "Developer ID is required"}

    current_user = frappe.session.user
    
    if current_user != "Administrator":
        # Fetch the 'username' (email) attached to the requested Developer ID
        actual_developer_email = frappe.db.get_value("Developer", developer_id, "username")
        
        if actual_developer_email != current_user:
            frappe.throw("Not Authorized: You can only view your own site visits.", frappe.PermissionError)

    projects = frappe.get_all(
        "Property Projects",
        filters={"developer": developer_id},
        fields=["name"],
        ignore_permissions=True 
    )

    if not projects:
        return []

    project_ids = [project.name for project in projects]

    # 2. Fetch Site Visits linked to any of these projects
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
            "owner"           # Shows which field agent logged the visit
        ],
        filters={
            "project": ["in", project_ids]  # <--- Filters by the Developer's projects
        },
        order_by="visit_date desc",
        ignore_permissions=True # Safe: Identity is already verified
    )
    
    return visits

@frappe.whitelist(methods=['GET'])
def get_site_visits_by_channel_partner(partner_id):
    if not partner_id:
        return {"error": "Channel Partner ID is required"}

    current_user = frappe.session.user
    user_roles = frappe.get_roles()
    
    # Define roles that have permission to view all site visits
    management_roles = ["System Manager", "Sales Manager", "CRM Manager"]
    is_manager = any(role in user_roles for role in management_roles)
    is_admin = current_user == "Administrator" or "administrator@homesolindia.com" in current_user.lower()
    is_cp = partner_id.lower() == current_user.lower()

    # Determine filtering for site visits
    # If not admin, manager, or the CP itself, we only show visits OWNED by the current user
    owner_filter = None
    if not is_admin and not is_manager and not is_cp:
        owner_filter = current_user

    # 1. Fetch Leads tagged to this Channel Partner
    leads = frappe.get_all(
        "Lead",
        filters={"custom_channel_partner": partner_id},
        fields=["name"],
        ignore_permissions=True 
    )

    if not leads:
        return []

    lead_ids = [lead.name for lead in leads]

    # 2. Fetch Site Visits linked to any of these leads
    visit_filters = {
        "lead": ["in", lead_ids]
    }
    
    if owner_filter:
        visit_filters["owner"] = owner_filter

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
            "owner"           # Shows which field agent logged the visit
        ],
        filters=visit_filters,
        order_by="visit_date desc",
        ignore_permissions=True # Safe: Filtering handles access
    )
    
    return visits

@frappe.whitelist()
def get_team_followups_list():
    """
    Fetches follow-ups using standard ORM (No SQL).
    Merges Parent (Lead) details into the Child (FollowUp) list.
    """
    user = frappe.session.user
    
    # --- 1. Get Team User IDs (Same as before) ---
    users_to_fetch = [user]
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")

    if employee:
        team_member = frappe.db.get_value("Sales Team Member", {"employee": employee}, ["parent", "role"], as_dict=True)
        if team_member and team_member.role == "Team Lead":
            team_employees = frappe.get_all("Sales Team Member", filters={"parent": team_member.parent}, fields=["employee"])
            emp_ids = [e.employee for e in team_employees]
            linked_users = frappe.get_all("Employee", filters={"name": ["in", emp_ids]}, fields=["user_id"])
            users_to_fetch = [u.user_id for u in linked_users if u.user_id]

    # --- 2. Fetch Relevant LEADS (Parent Data) ---
    # We fetch ID, Name, and Phone so we can show them on the task card later.
    leads = frappe.get_all(
        "Lead",
        filters={
            "lead_owner": ["in", users_to_fetch]
        },
        fields=["name", "lead_name", "mobile_no", "lead_owner"]
    )

    if not leads:
        return []

    # Create a lookup map: { 'LEAD-001': {'lead_name': 'Tony', 'mobile': '123'} }
    lead_map = { d.name: d for d in leads }
    lead_ids = list(lead_map.keys())

    follow_ups = frappe.get_all(
        "Lead FollowUps",  
        filters={
            "parent": ["in", lead_ids],
            # "status": "Open"  # Optional: Only show open tasks
        },
        fields=["name", "follow_up_date", "status", "type", "remarks", "parent", "assigned_to"],
        order_by="follow_up_date asc"
    )

    # --- 4. Python Merge (The "Join") ---
    final_data = []
    for task in follow_ups:
        # Grab the parent lead details from our map
        parent_lead = lead_map.get(task.parent)
        
        if parent_lead:
            # Combine Task + Lead details into one object
            row = task.copy()
            row.update({
                "lead_id": parent_lead.name,
                "lead_name": parent_lead.lead_name,
                "mobile_no": parent_lead.mobile_no,
                "lead_owner": parent_lead.lead_owner
            })
            final_data.append(row)

    return final_data


@frappe.whitelist()
def create_followup(lead_id, follow_up_date, status="Open", type="Call", remarks=None, next_follow_up=None, assigned_to=None):
    """
    Creates a new follow-up entry for a specific Lead.
    """
    if not lead_id:
        frappe.throw(_("Lead ID is required"))

    # Load the parent Lead document
    lead = frappe.get_doc("Lead", lead_id)

    # Append to the 'custom_follow_up_history' child table
    new_row = lead.append("custom_follow_up_history", {
        "status": status,
        "follow_up_date": follow_up_date,
        "type": type,
        "remarks": remarks,
        "next_follow_up": next_follow_up,
        "assigned_to": assigned_to or frappe.session.user,
        "created_at": frappe.utils.now_datetime()
    })

    # Save the parent document to persist the child table entry
    lead.save(ignore_permissions=True)

    return new_row.as_dict()


@frappe.whitelist()
def update_followup(followup_name, lead_id, status=None, follow_up_date=None, type=None, remarks=None, next_follow_up=None, assigned_to=None):

    """
    Updates an existing follow-up entry within a Lead.
    """
    if not followup_name or not lead_id:
        frappe.throw(_("Follow-up Name and Lead ID are required"))

    lead = frappe.get_doc("Lead", lead_id)
    
    updated = False
    for row in lead.get("custom_follow_up_history"):
        if row.name == followup_name:
            if status: row.status = status
            if follow_up_date: row.follow_up_date = follow_up_date
            if type: row.type = type
            if remarks: row.remarks = remarks
            if next_follow_up: row.next_follow_up = next_follow_up
            if assigned_to: row.assigned_to = assigned_to
            updated = True
            break
            
    if not updated:
        frappe.throw(_("Follow-up {0} not found in Lead {1}").format(followup_name, lead_id))
        
    lead.save(ignore_permissions=True)
    return "success"


@frappe.whitelist()
def get_lead_activity_logs(lead_id):
    if not lead_id:
        return {"error": "Lead ID is required"}

    versions = frappe.get_all(
        "Version",
        filters={
            "ref_doctype": "Lead",
            "docname": lead_id
        },
        fields=["*"],
        order_by="creation desc",
        ignore_permissions=True 
    )

    if not versions:
        return {"debug": "No versions found matching this Lead ID.", "raw": versions}

    activity_logs = []

    for v in versions:
        if v.data:
            try:
                if isinstance(v.data, str):
                    changes = json.loads(v.data)
                else:
                    changes = v.data 

                if "changed" in changes:
                    for change in changes["changed"]:
                        fieldname = change[0]
                        old_val = change[1]
                        new_val = change[2]
                        
                        clean_fieldname = fieldname.replace("_", " ").title()

                        activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Edit",
                            "message": f"Changed {clean_fieldname} from '{old_val}' to '{new_val}'",
                        })
                
                elif "added" in changes:
                    for added_row in changes["added"]:
                        child_table_name = added_row[0].replace("_", " ").title()
                        activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Addition",
                            "message": f"Added a new entry to {child_table_name}"
                        })
                
                else:
                     activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Creation/Other",
                            "message": "System Log Created"
                        })

            except Exception as e:
                activity_logs.append({
                    "version_id": v.name,
                    "error_message": str(e),
                    "raw_data": str(v.data)
                })

    return activity_logs


@frappe.whitelist()
def get_channel_partner_activity_logs(partner_id):

    if not partner_id:
        return {"error": "Channel Partner ID is required"}

    # Fetch history specifically for the Channel Partner DocType
    versions = frappe.get_all(
        "Version",
        filters={
            "ref_doctype": "Channel Partner",
            "docname": partner_id
        },
        fields=["*"],
        order_by="creation desc",
        ignore_permissions=True 
    )

    if not versions:
        return {"debug": "No versions found matching this Channel Partner ID.", "raw": versions}

    activity_logs = []

    for v in versions:
        if v.data:
            try:
                # Safely parse the JSON data stored in the version log
                if isinstance(v.data, str):
                    changes = json.loads(v.data)
                else:
                    changes = v.data 

                # Handle standard field edits
                if "changed" in changes:
                    for change in changes["changed"]:
                        fieldname = change[0]
                        old_val = change[1]
                        new_val = change[2]
                        
                        clean_fieldname = fieldname.replace("_", " ").title()

                        activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Edit",
                            "message": f"Changed {clean_fieldname} from '{old_val}' to '{new_val}'",
                        })
                
                # Handle additions to child tables (like the Contacts or Links table)
                elif "added" in changes:
                    for added_row in changes["added"]:
                        child_table_name = added_row[0].replace("_", " ").title()
                        activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Addition",
                            "message": f"Added a new entry to {child_table_name}"
                        })
                
                # Handle generic saves/creations
                else:
                     activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Creation/Other",
                            "message": "System Log Created"
                        })

            except Exception as e:
                activity_logs.append({
                    "version_id": v.name,
                    "error_message": str(e),
                    "raw_data": str(v.data)
                })

    return activity_logs


@frappe.whitelist()
def trigger_otp_sales_service(mobile_number, service_name=None):
    """
    Generates OTP for Sales Fields Service.
    - If document is new (no valid ID), uses Mobile No as the cache key.
    - If document is saved, uses Service Name as the cache key.
    """
    if not mobile_number:
        frappe.throw(_("Mobile Number is required to send OTP"))

    # Determine the unique Cache Key
    # If service_name is real (not None and not temporary 'new-sales-fields-service-...'), use it.
    if service_name and not service_name.startswith("new-sales-fields-service"):
        cache_key = f"sales_service_otp:{service_name}"
    else:
        # New Unsaved Document -> Use Mobile Number as key
        cache_key = f"sales_service_otp:{mobile_number}"

    # Generate 6-digit Random OTP
    otp = str(random.randint(100000, 999999))

    # Store OTP in Cache (Expires in 10 minutes)
    frappe.cache().set_value(cache_key, otp, expires_in_sec=600)

    # DEBUG: Show OTP on screen
    frappe.msgprint(f"<b>DEBUG MODE:</b><br>Sending to: <b>{mobile_number}</b><br>OTP: <b>{otp}</b>")

    # TODO: Uncomment for real SMS
    # from frappe.core.doctype.sms_settings.sms_settings import send_sms
    # send_sms([mobile_number], f"Your verification code is {otp}")
    
    return "success"


@frappe.whitelist()
def verify_otp_sales_service(user_otp, mobile_number, service_name=None):
    """
    Verifies OTP using the same key logic as trigger.
    """
    if not user_otp:
        return False

    # Reconstruct the Key to find the OTP
    if service_name and not service_name.startswith("new-sales-fields-service"):
        cache_key = f"sales_service_otp:{service_name}"
    else:
        cache_key = f"sales_service_otp:{mobile_number}"

    cached_otp = frappe.cache().get_value(cache_key)

    if cached_otp and str(user_otp) == str(cached_otp):
        frappe.cache().delete_value(cache_key) # Clear cache so it can't be used twice
        return True
    else:
        return False
    
@frappe.whitelist(methods=['GET'])
def get_sourcing_by_developer(developer_id):
    if not developer_id:
        return {"error": "Developer ID is required"}

    current_user = frappe.session.user
    
    if current_user != "Administrator":
        actual_developer_email = frappe.db.get_value("Developer", developer_id, "username")
        
        if actual_developer_email != current_user:
            frappe.throw("Not Authorized: You can only view your own sourcing records.", frappe.PermissionError)

    projects = frappe.get_all(
        "Property Projects",
        filters={"developer": developer_id},
        fields=["name"],
        ignore_permissions=True # Safe: We verified their identity above
    )

    if not projects:
        return []

    project_ids = [project.name for project in projects]

    sourcing_records = frappe.get_all(
        "Sales Fields Service",
        filters={
            "interested_project": ["in", project_ids]  
        },
        fields=["*"],  # Fetch all fields just like the Leads API
        order_by="creation desc",
        ignore_permissions=True 
    )

    return sourcing_records

@frappe.whitelist()
def get_sourcing_activity_logs(sfs_id):

    if not sfs_id:
        return {"error": "Sales Fields Service ID is required"}

    # Fetch history specifically for the Sales Fields Service DocType
    versions = frappe.get_all(
        "Version",
        filters={
            "ref_doctype": "Sales Fields Service",
            "docname": sfs_id
        },
        fields=["*"],
        order_by="creation desc",
        ignore_permissions=True 
    )

    if not versions:
        return {"debug": "No versions found matching this Sales Fields Service ID.", "raw": versions}

    activity_logs = []

    for v in versions:
        if v.data:
            try:
                # Safely parse the JSON data stored in the version log
                if isinstance(v.data, str):
                    changes = json.loads(v.data)
                else:
                    changes = v.data 

                # Handle standard field edits (e.g., changing 'Visit Status' or checkboxes)
                if "changed" in changes:
                    for change in changes["changed"]:
                        fieldname = change[0]
                        old_val = change[1]
                        new_val = change[2]
                        
                        clean_fieldname = fieldname.replace("_", " ").title()

                        activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Edit",
                            "message": f"Changed {clean_fieldname} from '{old_val}' to '{new_val}'",
                        })
                
                # Handle additions to child tables (if you ever add any to this DocType)
                elif "added" in changes:
                    for added_row in changes["added"]:
                        child_table_name = added_row[0].replace("_", " ").title()
                        activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Addition",
                            "message": f"Added a new entry to {child_table_name}"
                        })
                
                # Handle generic saves/creations
                else:
                     activity_logs.append({
                            "version_id": v.name,
                            "user": v.owner,
                            "timestamp": v.creation,
                            "type": "Creation/Other",
                            "message": "System Log Created"
                        })

            except Exception as e:
                activity_logs.append({
                    "version_id": v.name,
                    "error_message": str(e),
                    "raw_data": str(v.data)
                })

    return activity_logs


@frappe.whitelist(methods=['GET'])
def get_campaigns_by_project(project_id):
    if not project_id:
        return {"error": "Project ID is required"}

    # 1. Find all instances where this project is linked inside a Campaign
    linked_campaigns = frappe.get_all(
        "Campaign Project Link",
        filters={"projects": project_id},
        fields=["parent"],
        ignore_permissions=True 
    )

    if not linked_campaigns:
        return {"data": []}

    # Extract the parent campaign IDs from the child table results
    campaign_ids = [camp.parent for camp in linked_campaigns]

    # 2. Fetch the actual Campaign details using those extracted IDs
    campaigns = frappe.get_all(
        "Property Project Campaign",
        filters={"name": ["in", campaign_ids]},
        fields=["*"],  # Fetch all fields for the campaigns
        order_by="creation desc",
        ignore_permissions=True
    )

    # Wrapping in a "data" key to match standard Frappe REST API structures
    return {"data": campaigns}
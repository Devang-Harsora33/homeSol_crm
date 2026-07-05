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
    
    # ---------------------------------------------------------
    # QUERY 1: Always get the User's Personal Leads
    # ---------------------------------------------------------
    personal_leads = frappe.get_all(
        "Lead",
        filters={"lead_owner": user},
        fields=['*'],  
        order_by="creation desc",
        ignore_permissions=True
    )

    team_leads = []

    # ---------------------------------------------------------
    # QUERY 2: Get ALL teams where this employee is a Team Lead
    # ---------------------------------------------------------
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    
    if employee:
        # Fetch every team where the user is officially the Team Lead
        led_teams = frappe.get_all(
            "Sales Team Member", 
            filters={"employee": employee, "role": "Team Lead"}, 
            fields=["parent"]
        )

        if led_teams:
            team_names = [t.parent for t in led_teams]
            
            # 1. Get all subordinate team members across ALL those teams
            team_employees = frappe.get_all(
                "Sales Team Member", 
                filters={
                    "parent": ["in", team_names], 
                    "employee": ["!=", employee]
                }, 
                fields=["employee"]
            )
            
            emp_ids = list(set([e.employee for e in team_employees if e.employee]))
            
            if emp_ids:
                # 2. Convert Employee IDs to User Emails
                linked_users = frappe.get_all(
                    "Employee", 
                    filters={"name": ["in", emp_ids]}, 
                    fields=["user_id"]
                )
                team_user_ids = list(set([u.user_id for u in linked_users if u.user_id]))
                
                if team_user_ids:
                    # 3. Fetch allowed projects from the child table for ALL his teams
                    tl_projects = frappe.get_all(
                        "Sales Team Project",
                        filters={"parent": ["in", team_names]}, 
                        fields=["projects"]
                    )
                    
                    # These might be Names (Sukhsagar Heights) OR IDs (PROJ-00139)
                    raw_project_values = list(set([p.projects for p in tl_projects if p.projects]))

                    if raw_project_values:
                        # NEW: Check the Project table to get the true database IDs
                        actual_projects = frappe.get_all(
                            "Project", 
                            filters={
                                "name": ["in", raw_project_values]
                            },
                            or_filters={
                                "project_name": ["in", raw_project_values]
                            },
                            fields=["name"]
                        )
                        
                        # Extract the true IDs (e.g., PROJ-00139)
                        allowed_project_ids = list(set([p.name for p in actual_projects if p.name]))

                        # Fallback: Just in case the raw value IS the ID and wasn't caught
                        for raw_val in raw_project_values:
                            if raw_val not in allowed_project_ids:
                                allowed_project_ids.append(raw_val)

                        # 4. Fetch the Team's leads using the True IDs
                        if allowed_project_ids:
                            team_leads = frappe.get_all(
                                "Lead",
                                filters={
                                    "lead_owner": ["in", team_user_ids],
                                    "custom_interested_project": ["in", allowed_project_ids]
                                },
                                fields=['*'],  
                                order_by="creation desc",
                                ignore_permissions=True
                            )

    all_leads = personal_leads + team_leads
    
    # Sort the combined list by creation date (newest first)
    all_leads.sort(key=lambda x: str(x.get('creation', '')), reverse=True)

    return all_leads

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
        fields=["*"
            # "name",           
            # "lead",           
            # "project",        
            # "visit_date",     
            # "status",         
            # "remark",         
            # "creation",       
            # "visit_scheduled_datetime",
            # "owner" # Added owner so you can see WHO did the visit
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
        fields=["*"
            # "name",           
            # "lead",           
            # "project",        
            # "visit_date",     
            # "status",         
            # "remark",         
            # "creation",       
            # "visit_scheduled_datetime",
            # "owner"           # Shows which field agent logged the visit
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
        fields=["*"
            # "name",           
            # "lead",           
            # "project",        
            # "visit_date",     
            # "status",         
            # "remark",         
            # "creation",       
            # "visit_scheduled_datetime",
            # "owner"           # Shows which field agent logged the visit
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

    # Generate 4-digit Random OTP
    otp = str(random.randint(1000, 9999))

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



@frappe.whitelist(methods=['GET'])
def get_cp_connections(cp_name):
    if not cp_name:
        return {"error": "Channel Partner name is required"}

    # 1. Fetch Core CP Info + Creation Date
    cp = frappe.db.get_value(
        "Channel Partner", 
        cp_name, 
        ["name", "firm_name", "owner", "mobile_number", "creation"], 
        as_dict=True
    )

    if not cp:
        return {"error": "Channel Partner not found"}

    # 2. Fetch Leads
    leads = frappe.get_all(
        "Lead",
        filters={"custom_channel_partner": cp_name},
        fields=[
            "name", 
            "lead_name", 
            "custom_lead_status", 
            "custom_interested_project", 
            "creation",
            "lead_owner", 
            "custom_attended_by", 
            "custom_sales_manager"
        ],
        order_by="creation desc"
    )

    # 3. Fetch Site Visits & Attach to Leads
    lead_ids = [l.name for l in leads]
    site_visits_map = {}

    if lead_ids:
        site_visits = frappe.get_all(
            "Site Visit",
            filters={"lead": ["in", lead_ids]},
            fields=["name", "lead", "project", "visit_date", "status", "presence_of_cp", "remark"],
            order_by="visit_date desc"
        )
        for sv in site_visits:
            if sv.lead not in site_visits_map:
                site_visits_map[sv.lead] = []
            site_visits_map[sv.lead].append(sv)

    for lead in leads:
        lead["site_visits"] = site_visits_map.get(lead.name, [])

    # 4. Fetch CP Campaigns
    campaigns = frappe.get_all(
        "CP Campaign",
        filters={"channel_partner": cp_name},
        fields=["name", "project", "campaign_type", "start_date", "end_date", "status"],
        order_by="start_date desc"
    )
    
    # Create a quick dictionary to map campaigns by their name/ID
    campaign_map = {c.name: c for c in campaigns}

    # 5. Fetch Internal Sourcing Visits
    visits = frappe.get_all(
        "Sales Fields Service",
        filters={"sales_partner": cp_name},
        fields=[
            "name", 
            "owner", 
            "visit_date", 
            "visit_status", 
            "interested_project", 
            "cp_interest",
            "contact_person_met",
            "campaign_discussed", # Added this to fetch the linked campaign
            "creation"
        ],
        order_by="visit_date desc"
    )

    # 6. Dynamically Calculate Active Projects, Collect Users, & Attach Campaigns to Visits
    active_projects = set()
    internal_emails = set()
    
    if cp.owner:
        internal_emails.add(cp.owner)

    for lead in leads:
        if lead.custom_interested_project:
            active_projects.add(lead.custom_interested_project)
        if lead.lead_owner: internal_emails.add(lead.lead_owner)
        if lead.custom_attended_by: internal_emails.add(lead.custom_attended_by)
        if lead.custom_sales_manager: internal_emails.add(lead.custom_sales_manager)
            
    for visit in visits:
        if visit.interested_project:
            active_projects.add(visit.interested_project)
        if visit.owner: internal_emails.add(visit.owner)
        
        # Attach the full campaign details directly inside the visit object
        if visit.campaign_discussed and visit.campaign_discussed in campaign_map:
            visit["campaign_details"] = campaign_map[visit.campaign_discussed]
        else:
            visit["campaign_details"] = None

    # 7. Build the Connections List (Map Emails to Human Names)
    internal_emails = [e for e in internal_emails if e] 
    
    user_map = {}
    if internal_emails:
        users = frappe.get_all("User", filters={"email": ["in", internal_emails]}, fields=["email", "full_name"])
        user_map = {u.email: u.full_name for u in users}

    creator_email = cp.owner
    creator_data = {
        "email": creator_email,
        "name": user_map.get(creator_email, creator_email)
    }

    network_connections = []
    for email in internal_emails:
        if email != creator_email:
            network_connections.append({
                "email": email,
                "name": user_map.get(email, email)
            })

    return {
        "status": "success",
        "data": {
            "profile": cp,
            "onboarded_on": cp.creation,
            "connections": {
                "creator": creator_data,
                "network": network_connections
            },
            "metrics": {
                "total_leads": len(leads),
                "total_visits": len(visits),
                "total_campaigns": len(campaigns),
                "active_projects_count": len(active_projects)
            },
            "active_projects": list(active_projects),
            "campaigns": campaigns,      # Global list of all campaigns for this CP
            "recent_leads": leads[:5],   
            "recent_visits": visits[:5]  # Visits now include a nested 'campaign_details' object
        }
    }


@frappe.whitelist()
def get_eligible_transfer_users(project=None):
    user = frappe.session.user
    allowed_users = set([user])
    
    target_designations = [
        "Lead Caller", 
        "Sales Representative", 
        "Head of Marketing and Sales", 
        "Sales Manager", 
        "Sales And Sourcing"
    ]

    user_roles = frappe.get_roles(user)
    
    employee_filters = {
        "designation": ["in", target_designations], 
        "status": "Active"
    }

    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    is_team_lead = False

    # 1. ALWAYS check for Team Hierarchy First!
    if employee:
        team_member = frappe.db.get_value("Sales Team Member", {"employee": employee, "role": "Team Lead"}, ["parent"], as_dict=True)
        
        if team_member:
            is_team_lead = True 
            team_employees = frappe.get_all("Sales Team Member", filters={"parent": team_member.parent}, fields=["employee"])
            emp_ids = [e.employee for e in team_employees if e.employee]
            
            if emp_ids:
                employee_filters["name"] = ["in", emp_ids]
                linked_users = frappe.get_all("Employee", filters=employee_filters, fields=["user_id"])
                for u in linked_users:
                    if u.user_id: allowed_users.add(u.user_id)

    # 2. If they are NOT a Team Lead, but are Top-Level Management/Admin
    if not is_team_lead and ("System Manager" in user_roles or "Sales Manager" in user_roles):
        all_sales = frappe.get_all("Employee", filters=employee_filters, fields=["user_id"])
        for u in all_sales:
            if u.user_id: allowed_users.add(u.user_id)

    # 3. Security Lock: Remove employees already tied up in an active transfer
    active_transfers = frappe.get_all(
        "Lead Transfer",
        filters={"status": "Active", "transfer_type": "Temporary", "docstatus": 1},
        fields=["from_employee", "to_employee"]
    )
    
    locked_users = set()
    for t in active_transfers:
        if t.from_employee: locked_users.add(t.from_employee)
        if t.to_employee: locked_users.add(t.to_employee)
        
    final_users = [u for u in allowed_users if u not in locked_users]
    
    return final_users

def validate_lead_assignment(doc, method):
    """Prevents assigning leads to employees involved in an active temporary transfer"""
    
    # 1. VIP PASS: Allow the automated Lead Transfer script to bypass this block
    if getattr(frappe.flags, "in_lead_transfer", False):
        return

    # 2. ONLY run this check if the lead owner is actually being changed manually!
    if doc.lead_owner and (doc.is_new() or doc.has_value_changed("lead_owner")):
        active_transfer = frappe.db.exists(
            "Lead Transfer", 
            {
                "status": "Active",
                "transfer_type": "Temporary",
                "docstatus": 1,
                "from_employee": doc.lead_owner
            }
        ) or frappe.db.exists(
            "Lead Transfer", 
            {
                "status": "Active",
                "transfer_type": "Temporary",
                "docstatus": 1,
                "to_employee": doc.lead_owner
            }
        )
        
        if active_transfer:
            t = frappe.get_doc("Lead Transfer", active_transfer)
            if t.from_employee == doc.lead_owner:
                frappe.throw(f"<b>Assignment Blocked:</b> {doc.lead_owner} is on temporary leave until {t.valid_till}.")
            elif t.to_employee == doc.lead_owner:
                frappe.throw(f"<b>Assignment Blocked:</b> {doc.lead_owner} is covering a temporary lead transfer until {t.valid_till}. Capacity locked.")



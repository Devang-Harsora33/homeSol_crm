import frappe

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
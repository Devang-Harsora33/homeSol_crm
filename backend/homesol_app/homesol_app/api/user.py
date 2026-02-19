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
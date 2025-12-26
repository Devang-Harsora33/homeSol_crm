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
def get_my_lead():
    logged_in_user = frappe.session.user
    
    if logged_in_user == "Guest":
        frappe.throw("You must be logged in to view your lead.")

    lead_name = frappe.db.get_value("Lead", {"lead_owner": logged_in_user}, "name")

    if not lead_name:
        return {
            "message": f"No Lead found assigned to user {logged_in_user}"
        }

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

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
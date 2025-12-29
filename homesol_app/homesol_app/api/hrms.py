import frappe
from frappe.utils import now_datetime, getdate, today, flt

# --- Attendance & Check-in ---
@frappe.whitelist(allow_guest=True)
def get_shift_types():
    shifts = frappe.get_all("Shift Type", fields=["name", "start_time", "end_time", "holiday_list"])
    return shifts

@frappe.whitelist()
def employee_checkin(log_type, latitude=None, longitude=None, device_id=None, device_type=None):
    user = frappe.session.user
    if user == "Guest":
        frappe.throw("Please log in to check in.")

    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    if not employee:
        frappe.throw("No Employee record found linked to this user.")

    try:
        doc_data = {
            "doctype": "Employee Checkin",
            "employee": employee,
            "log_type": log_type,
            "time": now_datetime(),
            "latitude": latitude,
            "longitude": longitude,
            "device_id": device_id, 
        }
        if device_type:
             doc_data["custom_device_type"] = device_type

        doc = frappe.get_doc(doc_data)
        doc.insert(ignore_permissions=True)
        return {"status": "success", "message": f"Successfully marked {log_type}", "data": doc.as_dict()}
    except Exception as e:
        frappe.log_error(f"Checkin Error: {str(e)}")
        return {"status": "error", "message": str(e)}

# --- Holidays ---
@frappe.whitelist(allow_guest=True)
def get_all_holiday_lists():
    holiday_lists = frappe.get_all("Holiday List", fields=["name"])
    full_data = []
    for h_list in holiday_lists:
        doc = frappe.get_doc("Holiday List", h_list.name)
        full_data.append(doc.as_dict())
    return full_data

@frappe.whitelist()
def get_my_holidays():
    user = frappe.session.user
    if user == "Guest":
        frappe.throw("Please log in")

    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    if not employee:
        return {"message": "No Employee found for this user"}

    holiday_list_name = frappe.db.get_value("Employee", employee, "holiday_list")
    if not holiday_list_name:
        company = frappe.db.get_value("Employee", employee, "company")
        holiday_list_name = frappe.db.get_value("Company", company, "default_holiday_list")

    if holiday_list_name:
        return frappe.get_doc("Holiday List", holiday_list_name).as_dict()
    return {"message": "No Holiday List assigned"}

# --- Leave Management ---
@frappe.whitelist()
def get_my_leave_balance():
    user = frappe.session.user
    if user == "Guest":
        frappe.throw("Please log in.")

    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    if not employee:
        return {"status": "error", "message": "No Employee linked to this user."}

    allocations = frappe.get_all(
        "Leave Allocation",
        filters={"employee": employee, "to_date": [">=", today()], "docstatus": 1},
        fields=["name", "leave_type", "total_leaves_allocated", "new_leaves_allocated", "total_leaves_encashed"]
    )

    data = []
    for alloc in allocations:
        leaves_taken = frappe.get_all("Leave Application", 
            filters={"employee": employee, "leave_type": alloc.leave_type, "status": "Approved", "docstatus": 1},
            fields=["total_leave_days"]
        )
        used_count = sum([x.total_leave_days for x in leaves_taken])
        total_allocated = flt(alloc.total_leaves_allocated) + flt(alloc.new_leaves_allocated)
        remaining = total_allocated - used_count

        data.append({
            "leave_type": alloc.leave_type,
            "allocated": total_allocated,
            "used": used_count,
            "remaining": remaining
        })

    return {"status": "success", "employee": employee, "leaves": data}

@frappe.whitelist()
def apply_leave(leave_type, from_date, to_date, reason, is_half_day=0, half_day_period=None):
    user = frappe.session.user
    if user == "Guest":
        frappe.throw("Please log in.")

    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    if not employee:
        frappe.throw("No Employee linked to this user.")

    try:
        doc = frappe.new_doc("Leave Application")
        doc.employee = employee
        doc.leave_type = leave_type
        doc.from_date = getdate(from_date)
        
        if int(is_half_day) == 1:
            doc.half_day = 1
            doc.half_day_date = getdate(from_date)
            doc.to_date = getdate(from_date)
        else:
            doc.half_day = 0
            doc.to_date = getdate(to_date)

        doc.description = reason
        doc.follow_via_email = 0
        doc.posting_date = today()
        doc.insert(ignore_permissions=True)
        doc.submit() 

        return {"status": "success", "message": "Leave Application Submitted", "id": doc.name}
    except Exception as e:
        frappe.log_error(f"Leave Application Error: {str(e)}")
        return {"status": "error", "message": str(e)}
import frappe
from frappe.utils import now_datetime, getdate, today, flt
import json

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

from frappe.utils import get_first_day, get_last_day

@frappe.whitelist()
def get_my_attendance_history(month=None, year=None):
    """
    Fetches attendance status for a specific month.
    If month/year not provided, defaults to current month.
    """
    user = frappe.session.user
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    
    if not employee:
        return {"status": "error", "message": "No Employee found"}

    # Default to current month
    current_date = getdate(today())
    if not month: month = current_date.month
    if not year: year = current_date.year

    # Construct start and end dates
    start_date = f"{year}-{int(month):02d}-01"
    end_date = get_last_day(start_date)

    attendance = frappe.get_all(
        "Attendance",
        filters={
            "employee": employee,
            "attendance_date": ["between", [start_date, end_date]],
            "docstatus": 1
        },
        fields=["attendance_date", "status"], # Status can be Present, Absent, On Leave
        order_by="attendance_date asc"
    )
    
    return {"status": "success", "data": attendance}

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
def apply_leave_by_employee(leave_type, from_date, to_date, reason, is_half_day=0, half_day_period=None):
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
        
        # Explicitly set status to Open
        doc.status = "Open"

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
        
        # --- CHANGE IS HERE ---
        # Only INSERT (Save), do not SUBMIT
        doc.insert(ignore_permissions=True) 
        # doc.submit()  <-- REMOVED THIS LINE

        return {"status": "success", "message": "Leave Application Submitted", "id": doc.name}

    except Exception as e:
        frappe.log_error(f"Leave Application Error: {str(e)}")
        return {"status": "error", "message": str(e)}



@frappe.whitelist()
def get_my_leave_applications():
    user = frappe.session.user
    if user == "Guest":
        frappe.throw("Please log in.")

    # 1. Get Employee ID
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    if not employee:
        return {"status": "error", "message": "No Employee linked to this user."}

    # 2. Query the Leave Application table
    applications = frappe.get_all(
        "Leave Application",
        filters={
            "employee": employee
        },
        fields=[
            "name",              # The ID (e.g., HR-LAP-2025-0001)
            "leave_type",        # e.g., Casual Leave
            "from_date",
            "to_date",
            "total_leave_days",  # e.g., 0.5 or 2.0
            "status",            # Open, Approved, Rejected
            "posting_date",      # When it was applied
            "description",       # Reason
            "half_day"           # 1 or 0
        ],
        order_by="posting_date desc, creation desc" # Newest on top
    )

    return {
        "status": "success",
        "data": applications
    }

#-------Salary APIs-------#


@frappe.whitelist()
def get_my_salary_slips():
    """Returns a list of salary slips for the logged-in employee."""
    user = frappe.session.user
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    
    if not employee:
        return {"status": "error", "message": "No Employee found"}

    # Fetch submitted salary slips, newest first
    # FIX: Replaced 'month', 'year' with 'start_date', 'end_date'
    slips = frappe.get_all(
        "Salary Slip",
        filters={"employee": employee, "docstatus": 1}, 
        fields=[
            "name", 
            "start_date",  # Use this to show "Jan 2026" in App
            "end_date", 
            "net_pay", 
            "gross_pay", 
            "posting_date"
        ],
        order_by="posting_date desc"
    )
    
    return {"status": "success", "data": slips}

@frappe.whitelist()
def download_salary_slip(salary_slip_id):
    """Returns the PDF URL for a specific salary slip."""
    # Security check: Ensure this slip belongs to the user
    user = frappe.session.user
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    
    slip_owner = frappe.db.get_value("Salary Slip", salary_slip_id, "employee")
    
    if slip_owner != employee:
        frappe.throw("You are not authorized to view this salary slip.")

    return {
        "pdf_url": f"/api/method/frappe.utils.print_format.download_pdf?doctype=Salary+Slip&name={salary_slip_id}&format=Salary+Slip+Standard&no_letterhead=0"
    }

#------Tax APIS------#


@frappe.whitelist()
def get_my_tax_info():
    """
    Fetches the employee's Tax Regime (Old/New) and active Payroll Period.
    """
    user = frappe.session.user
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    
    if not employee:
        return {"status": "error", "message": "No Employee found"}

    # FIX: Removed 'status="Active"' because the column doesn't exist.
    # We filter by 'docstatus=1' (Submitted) and ensure it's the latest one.
    assignment = frappe.db.get_value("Salary Structure Assignment", 
        {
            "employee": employee, 
            "docstatus": 1,
            "from_date": ["<=", today()] # Ensure assignment has started
        }, 
        "income_tax_slab",
        order_by="from_date desc" # Get the most recent one
    )
    
    # Get Current Payroll Period (e.g., 2025-2026)
    period = frappe.db.get_value("Payroll Period", 
        {"company": frappe.defaults.get_user_default("Company"), "start_date": ["<=", today()], "end_date": [">=", today()]}, 
        "name"
    )

    return {
        "status": "success",
        "regime": assignment or "Not Assigned", 
        "current_period": period
    }
@frappe.whitelist()
def get_tax_declaration_options():
    """
    Fetches dropdown options for the tax form.
    """
    categories = frappe.get_all("Employee Tax Exemption Category", fields=["name", "max_amount"])
    return {"status": "success", "categories": categories}

@frappe.whitelist()
def submit_tax_declaration(payroll_period, declarations):
    """
    Submits the investment plan.
    declarations: List of JSON objects like [{"exemption_sub_category": "80C", "amount": 150000}]
    """
    user = frappe.session.user
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    
    if isinstance(declarations, str):
        declarations = json.loads(declarations)

    try:
        # Check for existing declaration to update instead of creating duplicate
        existing_name = frappe.db.get_value("Employee Tax Exemption Declaration", 
            {"employee": employee, "payroll_period": payroll_period, "docstatus": 0}, "name")

        if existing_name:
            doc = frappe.get_doc("Employee Tax Exemption Declaration", existing_name)
        else:
            doc = frappe.new_doc("Employee Tax Exemption Declaration")
            doc.employee = employee
            doc.company = frappe.defaults.get_user_default("Company")
            doc.payroll_period = payroll_period
            doc.currency = "INR"

        # Clear old rows and set new ones
        doc.set("declarations", [])
        for item in declarations:
            doc.append("declarations", {
                "exemption_sub_category": item.get("exemption_sub_category"),
                "amount": item.get("amount"),
                "max_amount": item.get("max_amount", 150000)
            })

        doc.save(ignore_permissions=True)
        # Note: We usually keep it in 'Draft' (Saved) so they can edit it later. 
        # doc.submit() <--- Uncomment if you want to lock it immediately.

        return {"status": "success", "message": "Declaration Saved", "id": doc.name}

    except Exception as e:
        frappe.log_error(f"Tax Error: {str(e)}")
        return {"status": "error", "message": str(e)}


@frappe.whitelist()
def get_salary_breakdown():
    """
    Fetches the Earnings and Deductions breakdown from the latest Salary Slip.
    """
    user = frappe.session.user
    employee = frappe.db.get_value("Employee", {"user_id": user}, "name")
    
    if not employee:
        return {"status": "error", "message": "No Employee found"}

    # 1. Get the ID of the latest submitted Salary Slip
    latest_slip = frappe.db.get_value("Salary Slip", 
        {"employee": employee, "docstatus": 1}, 
        "name", 
        order_by="posting_date desc"
    )

    if not latest_slip:
        return {
            "status": "error", 
            "message": "No Salary Slip found. Payroll has not been processed yet."
        }

    # 2. Load the full document to get the child tables (Earnings & Deductions)
    doc = frappe.get_doc("Salary Slip", latest_slip)

    # 3. Format Earnings
    earnings_list = []
    for item in doc.earnings:
        earnings_list.append({
            "component": item.salary_component,
            "amount": item.amount,
            "year_to_date": item.year_to_date # Optional: Shows total earned this year
        })

    # 4. Format Deductions
    deductions_list = []
    for item in doc.deductions:
        deductions_list.append({
            "component": item.salary_component,
            "amount": item.amount,
            "year_to_date": item.year_to_date
        })

    return {
        "status": "success",
        "start_date": doc.start_date,  # <--- CHANGED THIS (Was doc.month)
        "end_date": doc.end_date,
        "net_pay": doc.net_pay,
        "gross_pay": doc.gross_pay,
        "total_deduction": doc.total_deduction,
        "earnings": earnings_list,
        "deductions": deductions_list
    }
import frappe
from frappe.model.document import Document

class LeadTransfer(Document):
    def validate(self):
        # Fetch ALL active temporary transfers (excluding this exact document if updating)
        active_transfers = frappe.get_all(
            "Lead Transfer",
            filters={
                "status": "Active", 
                "transfer_type": "Temporary", 
                "docstatus": 1,
                "name": ["!=", self.name] 
            },
            fields=["name", "from_employee", "to_employee"]
        )
        
        # Check if either chosen employee is locked in any active transfer
        for t in active_transfers:
            if self.from_employee in [t.from_employee, t.to_employee]:
                frappe.throw(f"<b>{self.from_employee}</b> is currently locked in Active Transfer: {t.name}")
            if self.to_employee in [t.from_employee, t.to_employee]:
                frappe.throw(f"<b>{self.to_employee}</b> is currently locked in Active Transfer: {t.name}")

    def on_submit(self):
        if not self.selected_leads:
            frappe.throw("Please select at least one lead to transfer.")

        count = 0
        
        for item in self.selected_leads:
            lead = frappe.get_doc("Lead", item.lead)
            lead.lead_owner = self.to_employee
            
            if self.transfer_type == "Temporary":
                lead.custom_original_owner = self.from_employee
                lead.custom_active_transfer_id = self.name
                
            lead.flags.ignore_validate = True
            lead.flags.ignore_mandatory = True
            lead.save(ignore_permissions=True)
            
            count += 1
            
        self.db_set("status", "Active")
        frappe.msgprint(f"Successfully transferred {count} specific leads to {self.to_employee}.")

    def on_cancel(self):
        if self.transfer_type == "Temporary":
            self.db_set("status", "Cancelled")
            count = 0
            
            for item in self.selected_leads:
                lead = frappe.get_doc("Lead", item.lead)
                
                # Check the custom status field instead of standard status
                current_status = frappe.db.get_value("Lead", item.lead, "custom_lead_status")
                
                if current_status == "Lead Generated - Open":
                    lead.lead_owner = self.from_employee
                    lead.custom_original_owner = ""
                    lead.custom_active_transfer_id = ""
                    
                    lead.flags.ignore_validate = True
                    lead.flags.ignore_mandatory = True
                    lead.save(ignore_permissions=True)
                    
                    count += 1
                    
            frappe.msgprint(f"Transfer Cancelled: {count} leads securely returned to {self.from_employee}.")
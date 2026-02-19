# Copyright (c) 2025, homesol_team and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document
from frappe import _

class PropertyProjects(Document):
    def on_update(self):
        """
        Runs automatically every time you Save the Project.
        """
        self.add_to_developer_list()
        self.add_to_mandate_list()

    def add_to_developer_list(self):
        # 1. Check if the 'developer' field has a value
        if self.developer:
            try:
                # 2. Open the linked Developer document
                dev_doc = frappe.get_doc("Developer", self.developer)
                
                # 3. Check if this project is already in their list
                # Note: We use 'projects_list' because that is the actual name in your Developer form
                is_exist = False
                if hasattr(dev_doc, 'projects_list'):
                    for row in dev_doc.projects_list: 
                        if row.project == self.name:
                            is_exist = True
                            break
                    
                    # 4. If not found, add it
                    if not is_exist:
                        dev_doc.append("projects_list", {
                            "project": self.name,
                            "project_name": self.project_name,
                            "start_date": frappe.utils.nowdate(),
                            "status": "Active"
                        })
                        dev_doc.save(ignore_permissions=True)
                        frappe.msgprint(_("Project added to Developer List."))
                else:
                    frappe.log_error("Table 'projects_list' not found in Developer", "Developer Sync Error")
            
            except Exception as e:
                frappe.log_error(title="Developer Update Error", message=str(e))

    def add_to_mandate_list(self):
            if self.mandate:
                try:
                    mandate_doc = frappe.get_doc("Mandate", self.mandate)
                    
                    # Check table name (usually 'projects')
                    target_table = "projects"
                    if not hasattr(mandate_doc, target_table):
                        # If named 'assigned_projects' in DocType, switch to that
                        target_table = "assigned_projects"

                    if hasattr(mandate_doc, target_table):
                        # Check duplicates
                        is_exist = False
                        for row in getattr(mandate_doc, target_table):
                            existing_link = getattr(row, "project", None) or getattr(row, "project_id", None)
                            if existing_link == self.name:
                                is_exist = True
                                break
                        
                        if not is_exist:
                            # Prepare the row data based on your screenshot
                            row_data = {
                                "start_date": frappe.utils.nowdate(),
                                "status": "Active",
                                "project" : self.name, 
                                "project_name" : self.project_name
                            }
                            mandate_doc.append(target_table, row_data)
                            mandate_doc.save(ignore_permissions=True)
                            frappe.msgprint(_("Project added to Mandate: {0}").format(self.mandate))

                except Exception as e:
                    frappe.log_error(title="Mandate Update Error", message=str(e))
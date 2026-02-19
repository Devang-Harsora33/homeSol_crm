import json
import requests

# =================================================================
# CONFIGURATION
# =================================================================
BASE_URL = "https://erp.homesolindia.com"
TOKENS = {
    "Manager": "token 430e071770ddab7:a2d285c4ba66423",
    "Employee": "token 11497a0ff9508b7:ed36bee726627e1",
}

ENDPOINTS = {
    "My Leads": "/api/method/homesol_app.api.get_my_leads",
    "Team Leads": "/api/method/homesol_app.api.get_team_leads",
}

def get_data(endpoint, token):
    url = f"{BASE_URL}{endpoint}"
    headers = {"Authorization": token}
    try:
        response = requests.get(url, headers=headers, timeout=20)
        if response.status_code == 200:
            return response.json().get("message", [])
        return f"Error: {response.status_code}"
    except Exception as e:
        return f"Exception: {str(e)}"

def validate_leads():
    print("Starting Deep Permission Validation for LEADS")
    
    results = {}
    for role_name, token in TOKENS.items():
        results[role_name] = {}
        for ep_name, path in ENDPOINTS.items():
            data = get_data(path, token)
            results[role_name][ep_name] = data

    print("\n" + "="*50)
    print("📊 OWNERSHIP BREAKDOWN")
    print("="*50)

    for role_name in ["Manager", "Employee"]:
        for ep_name in ["My Leads", "Team Leads"]:
            data = results[role_name][ep_name]
            print(f"\n[{role_name} - {ep_name}]")
            if isinstance(data, list):
                owners = {}
                for lead in data:
                    owner_field = lead.get("lead_owner") or lead.get("owner")
                    owners[owner_field] = owners.get(owner_field, 0) + 1
                
                for owner, count in owners.items():
                    print(f"  - {owner}: {count} leads")
                if not owners:
                    print("  - (Empty List)")
            else:
                print(f"  - Error fetching data: {data}")

    # Specific check for Rajesh's missing lead
    print("\n" + "="*50)
    print("🔍 DIAGNOSIS")
    print("="*50)
    
    mgr_my = results["Manager"]["My Leads"]
    mgr_team = results["Manager"]["Team Leads"]
    emp_my = results["Employee"]["My Leads"]
    
    mgr_emails = {lead.get("custom_attended_by") for lead in mgr_my if isinstance(lead, dict)}
    
    if "rajesh@homesolindia.com" not in mgr_emails:
        print("❌ ISSUE: Rajesh's own lead is MISSING from his 'My Leads' list.")
        print("   The list is only showing leads 'Attended By' Prachi.")
    
    if len(mgr_team) < 8:
        print(f"❌ ISSUE: 'Team Leads' count is {len(mgr_team)}, but should be 8 (1 from Rajesh + 7 from Prachi).")


if __name__ == "__main__":
    validate_leads()

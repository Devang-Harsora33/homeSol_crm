import json
import csv
import time
import requests
import re
from datetime import datetime

# =================================================================
# 1. CONFIGURATION SECTION
# =================================================================

BASE_URL = "https://erp.homesolindia.com"

# The Login endpoint is special as it doesn't use pre-defined tokens for its primary function.
# However, we keep TOKENS for consistency if needed for other checks.
TOKENS = {
    "Admin": "token 16b54fcb694b109:79dac6f5a318d62",
    "Manager": "token 430e071770ddab7:a2d285c4ba66423",
    "Employee": "token 11497a0ff9508b7:ed36bee726627e1",
}

COLLECTION_FILE = "HomeSol Frappe Cloud.postman_collection.json"
REPORT_FILE = "login_api_test_report.csv"
MODULE_NAME = "Login"

# =================================================================
# 2. HELPER FUNCTIONS
# =================================================================

def extract_login_request(items, module_name, parent_name=""):
    """
    Extracts only the "Login" request from the module.
    """
    extracted = []
    for item in items:
        name = item.get("name", "")
        current_full_name = f"{parent_name} > {name}" if parent_name else name
        
        if module_name == name or module_name in parent_name:
            if "item" in item:
                extracted.extend(extract_login_request(item["item"], module_name, current_full_name))
            elif "request" in item and name == "Login": # Only extract the specific "Login" request
                req = item["request"]
                url_raw = req["url"]["raw"] if isinstance(req["url"], dict) else req["url"]
                
                url = url_raw.replace("{{baseurl_production}}", BASE_URL)
                
                method = req["method"]
                body = None
                if "body" in req and req["body"].get("mode") == "urlencoded":
                    body = {param["key"]: param["value"] for param in req["body"]["urlencoded"] if "key" in param}
                
                # Login request typically does not have Authorization header, or it's for getting one.
                # We'll extract other headers, but for login, Authorization won't be from TOKENS
                headers = {h["key"]: h["value"] for h in req.get("header", []) if h["key"].lower() != "authorization"}
                
                extracted.append({
                    "name": name,
                    "method": method,
                    "url": url,
                    "headers": headers,
                    "body": body
                })
        elif "item" in item:
            extracted.extend(extract_login_request(item["item"], module_name, current_full_name))
                
    return extracted

# =================================================================
# 3. LOGIN TESTING LOGIC
# =================================================================

def run_tests():
    print(f"🎯 Starting {MODULE_NAME} Module Testing")
    
    try:
        with open(COLLECTION_FILE, "r", encoding="utf-8") as f:
            collection = json.load(f)
    except FileNotFoundError:
        print(f"❌ Error: {COLLECTION_FILE} not found.")
        return
    except json.JSONDecodeError as e:
        print(f"❌ JSON Decode Error: {e} in {COLLECTION_FILE}. Please ensure it's valid JSON.")
        return

    login_requests = extract_login_request(collection["item"], MODULE_NAME)
    
    if not login_requests:
        print(f"⚠️ No 'Login' requests found in the '{MODULE_NAME}' module.")
        return
        
    # We expect only one login request for this module, take the first one
    req = login_requests[0]

    print(f"✅ Found 1 unique {MODULE_NAME} endpoint.")
    print(f"🔍 Testing: {req['name']}")
    
    report_data = []

    # For Login endpoint, we test with the credentials directly from Postman, not roles
    # We can add an 'Admin' role entry in report for clarity.
    role = "Test_User" 
    
    test_headers = req["headers"].copy()
    # No Authorization header added from TOKENS for login itself

    test_body = req.get('body') # Assume body is already prepared (urlencoded)

    start_time = time.time()
    try:
        if req["method"] == "POST" and isinstance(test_body, dict):
            # For form-urlencoded, requests library uses 'data'
            response = requests.request(req["method"], req["url"], headers=test_headers, data=test_body, timeout=20)
        else:
            response = requests.request(req["method"], req["url"], headers=test_headers, data=test_body, timeout=20)
        
        duration = int((time.time() - start_time) * 1000)
        status = response.status_code
        
        result = "PASS" if status == 200 else "FAIL" # Expecting 200 for successful login
        if status == 401: result = "AUTH_FAIL"
        if status >= 500: result = "SERVER_ERROR"

        print(f"   - User [{role}]: Status {status} ({duration}ms) -> {result}")
        
        report_data.append({
            "Endpoint": req["name"],
            "Method": req["method"],
            "URL": req["url"],
            "Role": role,
            "Status": status,
            "Time_ms": duration,
            "Result": result,
            "Response_Snippet": response.text[:150].replace('\n', ' ').replace('\r', ' ')
        })
        
        # Optionally, extract and print cookie or token if login was successful
        if status == 200 and "set-cookie" in response.headers:
            print(f"     ✅ Login successful! Set-Cookie: {response.headers['set-cookie'][:100]}...")
            if response.json():
                print(f"     Response JSON: {response.json()}")

    except Exception as e:
        print(f"   - User [{role}]: EXCEPTION {str(e)}")

    if report_data:
        with open(REPORT_FILE, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=report_data[0].keys())
            writer.writeheader()
            writer.writerows(report_data)
        print(f"📊 {MODULE_NAME} report saved to: {REPORT_FILE}")

if __name__ == "__main__":
    run_tests()

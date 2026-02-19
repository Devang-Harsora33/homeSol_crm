import json
import csv
import time
import random
import re
import requests
from datetime import datetime

# =================================================================
# 1. CONFIGURATION SECTION
# =================================================================

BASE_URL = "https://erp.homesolindia.com"

TOKENS = {
    "Admin": "token 16b54fcb694b109:79dac6f5a318d62",
    "Manager": "token 430e071770ddab7:a2d285c4ba66423",
    "Employee": "token 11497a0ff9508b7:ed36bee726627e1",
}

COLLECTION_FILE = "HomeSol Frappe Cloud.postman_collection.json"
REPORT_FILE = "tickets_api_test_report_verbose.csv" # New report file for verbose output
MODULE_NAME = "Tickets"

# =================================================================
# 2. HELPER FUNCTIONS
# =================================================================

def randomize_value(key, value):
    timestamp = int(time.time())
    if "description" in key.lower() and isinstance(value, str):
        return f"Test Ticket Description - {timestamp} - {random.randint(1000, 9999)}"
    if "category" in key.lower() and isinstance(value, str):
        # Using valid categories from the error message
        return random.choice(["General"])
    if "priority" in key.lower() and isinstance(value, str):
        # Using valid priorities from the error message
        return random.choice(["Low", "Medium", "High"])
    if "status" in key.lower() and isinstance(value, str):
        # Ensure these statuses exist in your Frappe instance
        return random.choice(["Open", "In Progress", "Resolved", "Closed"])
    
    return value

def process_body_recursive(data):
    if isinstance(data, dict):
        return {k: process_body_recursive(randomize_value(k, v)) for k, v in data.items()}
    elif isinstance(data, list):
        return [process_body_recursive(item) for item in data]
    else:
        return data

def extract_module_requests(items, module_name, parent_name=""):
    extracted = []
    for item in items:
        name = item.get("name", "")
        current_full_name = f"{parent_name} > {name}" if parent_name else name
        
        # Only extract requests from the "Tickets" module
        if module_name == name or module_name in parent_name.split(' > '): # Use split to check if module_name is a parent
            if "item" in item:
                extracted.extend(extract_module_requests(item["item"], module_name, current_full_name))
            elif "request" in item:
                req = item["request"]
                url_raw = req["url"]["raw"] if isinstance(req["url"], dict) else req["url"]
                
                # Handling of {{baseurl_production}} and localhost
                if "localhost" in url_raw:
                    url = re.sub(r"http(s)?://localhost(:\d+)?", BASE_URL, url_raw)
                else:
                    url = url_raw.replace("{{baseurl_production}}", BASE_URL)
                
                method = req["method"]
                body = None
                if "body" in req and req["body"].get("mode") == "raw":
                    try:
                        body = json.loads(req["body"]["raw"])
                    except (json.JSONDecodeError, TypeError):
                        body = req["body"]["raw"] # Keep as string if not valid JSON
                elif "body" in req and req["body"].get("mode") == "urlencoded":
                    body = {param["key"]: param["value"] for param in req["body"]["urlencoded"] if "key" in param}
                
                headers = {h["key"]: h["value"] for h in req.get("header", []) if h["key"].lower() != "authorization"}
                
                extracted.append({
                    "name": name,
                    "method": method,
                    "url": url,
                    "headers": headers,
                    "body": body
                })
        elif "item" in item: # Recurse if it's a folder, even if not the target module yet, to find the target.
            extracted.extend(extract_module_requests(item["item"], module_name, current_full_name))
                
    return extracted

# =================================================================
# 3. TICKETS TESTING LOGIC
# =================================================================

def run_tests():
    print(f"🎯 Starting {MODULE_NAME} Module Testing (Verbose Diagnostics)")
    
    try:
        with open(COLLECTION_FILE, "r", encoding="utf-8") as f:
            collection = json.load(f)
    except FileNotFoundError:
        print(f"❌ Error: {COLLECTION_FILE} not found.")
        return
    except json.JSONDecodeError as e:
        print(f"❌ JSON Decode Error: {e} in {COLLECTION_FILE}. Please ensure it's valid JSON.")
        return

    all_requests = extract_module_requests(collection["item"], MODULE_NAME)
    
    unique_requests = []
    seen = set()
    for r in all_requests:
        identifier = (r["method"], r["url"])
        if identifier not in seen:
            unique_requests.append(r)
            seen.add(identifier)

    print(f"✅ Found {len(unique_requests)} unique {MODULE_NAME} endpoints.")
    
    report_data = []

    for req in unique_requests:
        print(f"\n🔍 Testing: {req['name']}")
        
        for role, token in TOKENS.items():
            test_headers = req["headers"].copy()
            test_headers["Authorization"] = token
            
            test_body_sent = None
            original_body = req.get('body')

            if req["name"] == "Create Ticket" and req["method"] == "POST" and isinstance(original_body, dict):
                test_body_sent = process_body_recursive(original_body)
                print(f"   [Request Body for {role}]: {json.dumps(test_body_sent, indent=2)}")
            elif original_body:
                test_body_sent = original_body

            start_time = time.time()
            try:
                if req["method"] in ["POST", "PUT"] and isinstance(test_body_sent, dict):
                    response = requests.request(req["method"], req["url"], headers=test_headers, json=test_body_sent, timeout=20)
                else:
                    response = requests.request(req["method"], req["url"], headers=test_headers, data=test_body_sent, timeout=20)
                
                duration = int((time.time() - start_time) * 1000)
                status = response.status_code
                
                result = "PASS" if 200 <= status < 300 else "FAIL"
                if status in [401, 403]: result = "AUTH_RESTRICTED"
                if status >= 500: result = "SERVER_ERROR"

                print(f"   - Role [{role}]: Status {status} ({duration}ms) -> {result}")
                if status != 200: # Print full response for non-200 statuses for debugging
                    print(f"     Full Response Body for {role}: {response.text}")
                
                report_data.append({
                    "Endpoint": req["name"],
                    "Method": req["method"],
                    "URL": req["url"],
                    "Role": role,
                    "Status": status,
                    "Time_ms": duration,
                    "Result": result,
                    "Response_Body_Snippet": response.text[:200].replace('\n', ' ')
                })
            except Exception as e:
                print(f"   - Role [{role}]: EXCEPTION {str(e)}")
                report_data.append({
                    "Endpoint": req["name"],
                    "Method": req["method"],
                    "URL": req["url"],
                    "Role": role,
                    "Status": "ERR",
                    "Time_ms": 0,
                    "Result": "ERROR",
                    "Response_Body_Snippet": str(e)
                })


    if report_data:
        with open(REPORT_FILE, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=report_data[0].keys())
            writer.writeheader()
            writer.writerows(report_data)
        print(f"\n📊 {MODULE_NAME} report saved to: {REPORT_FILE}")

if __name__ == "__main__":
    run_tests()

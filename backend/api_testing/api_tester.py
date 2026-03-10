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

# The base URL of your Frappe/ERPNext instance
BASE_URL = "https://erp.homesolindia.com"

# API Tokens for different roles
# Format: "token api_key:api_secret"
TOKENS = {
    "Admin": "token YOUR_ADMIN_KEY:YOUR_ADMIN_SECRET",
    "Manager": "token YOUR_MANAGER_KEY:YOUR_MANAGER_SECRET",
    "Employee": "token YOUR_EMPLOYEE_KEY:YOUR_EMPLOYEE_SECRET",
}

COLLECTION_FILE = "HomeSol Frappe Cloud.postman_collection.json"
REPORT_FILE = "api_test_report.csv"

# =================================================================
# 2. HELPER FUNCTIONS
# =================================================================

def randomize_value(key, value):
    """
    Generates random or timestamped data for specific keys to avoid 
    'Duplicate Entry' errors in the database.
    """
    timestamp = int(time.time())
    
    # Handle Email
    if "email" in key.lower():
        return f"test_user_{timestamp}_{random.randint(100, 999)}@example.com"
    
    # Handle Mobile/Phone
    if any(k in key.lower() for k in ["mobile", "phone", "whatsapp"]):
        return f"9{random.randint(100000000, 999999999)}"
    
    # Handle Device ID
    if "device_id" in key.lower():
        return f"device-{timestamp}-{random.randint(1000, 9999)}"
    
    # Handle Dates (e.g., "2026-01-10" -> "2026-02-18")
    if "date" in key.lower() and isinstance(value, str) and re.match(r"\d{4}-\d{2}-\d{2}", value):
        return datetime.now().strftime("%Y-%m-%d")

    return value

def process_body_recursive(data):
    """
    Recursively iterates through JSON body to find and randomize fields.
    """
    if isinstance(data, dict):
        return {k: process_body_recursive(randomize_value(k, v)) for k, v in data.items()}
    elif isinstance(data, list):
        return [process_body_recursive(item) for item in data]
    else:
        return data

def extract_requests(items, parent_name=""):
    """
    Recursively extracts all API requests from the Postman 'item' list.
    """
    extracted = []
    for item in items:
        full_name = f"{parent_name} > {item['name']}" if parent_name else item['name']
        
        if "item" in item:
            # It's a folder, recurse
            extracted.extend(extract_requests(item["item"], full_name))
        elif "request" in item:
            # It's a request
            req = item["request"]
            
            # Extract URL
            url_raw = req["url"]["raw"] if isinstance(req["url"], dict) else req["url"]
            
            # Substitute BASE_URL variable
            url = url_raw.replace("{{baseurl_production}}", BASE_URL)
            # Handle cases where localhost or other strings might be hardcoded in raw but baseurl is preferred
            if url.startswith("http://localhost") or url.startswith("https://localhost"):
                # Optionally override localhost if the user wants everything against production
                url = re.sub(r"http(s)?://localhost(:\d+)?", BASE_URL, url)
            
            # Extract Method
            method = req["method"]
            
            # Extract Body
            body = None
            if "body" in req and req["body"].get("mode") == "raw":
                try:
                    body = json.loads(req["body"]["raw"])
                except Exception:
                    body = req["body"]["raw"]
            elif "body" in req and req["body"].get("mode") == "urlencoded":
                body = {param["key"]: param["value"] for param in req["body"]["urlencoded"] if "key" in param}

            # Extract Headers (excluding Authorization which we override)
            headers = {}
            if "header" in req:
                for h in req["header"]:
                    if h["key"].lower() != "authorization":
                        headers[h["key"]] = h["value"]
            
            extracted.append({
                "name": full_name,
                "method": method,
                "url": url,
                "headers": headers,
                "body": body
            })
    return extracted

# =================================================================
# 3. MAIN TESTING LOGIC
# =================================================================

def run_tests():
    print(f"🚀 Starting API Testing against: {BASE_URL}")
    print(f"📂 Loading collection: {COLLECTION_FILE}")

    try:
        with open(COLLECTION_FILE, "r", encoding="utf-8") as f:
            collection = json.load(f)
    except FileNotFoundError:
        print(f"❌ Error: {COLLECTION_FILE} not found.")
        return

    all_requests = extract_requests(collection["item"])
    print(f"✅ Found {len(all_requests)} requests in collection.")
    
    report_data = []

    for req in all_requests:
        print(f"--- Testing Request: {req['name']} ---")
        
        for role, token in TOKENS.items():
            # Prepare headers
            test_headers = req["headers"].copy()
            test_headers["Authorization"] = token
            
            # Prepare body (with randomization)
            test_body = process_body_recursive(req["body"]) if req["body"] else None
            
            start_time = time.time()
            try:
                # Execute request
                if isinstance(test_body, dict) and req["method"] in ["POST", "PUT"]:
                    response = requests.request(
                        method=req["method"],
                        url=req["url"],
                        headers=test_headers,
                        json=test_body,
                        timeout=30
                    )
                else:
                    response = requests.request(
                        method=req["method"],
                        url=req["url"],
                        headers=test_headers,
                        data=test_body if req["method"] in ["POST", "PUT"] else None,
                        timeout=30
                    )
                
                response_time = int((time.time() - start_time) * 1000)
                status_code = response.status_code
                
                # Determine Pass/Fail
                if 200 <= status_code < 300:
                    result = "PASS"
                elif status_code in [401, 403]:
                    result = "AUTH FAIL"
                elif status_code >= 500:
                    result = "SERVER FAIL"
                else:
                    result = "FAIL"
                
                print(f"  [{role}] {req['method']} {req['url']} -> Status: {status_code} ({response_time}ms) - {result}")
                
                report_data.append({
                    "Request Name": req["name"],
                    "Method": req["method"],
                    "URL": req["url"],
                    "Role": role,
                    "Status Code": status_code,
                    "Response Time (ms)": response_time,
                    "Pass/Fail": result,
                    "Response Body": response.text[:200] + "..." if len(response.text) > 200 else response.text
                })

            except Exception as e:
                print(f"  [{role}] ERROR: {str(e)}")
                report_data.append({
                    "Request Name": req["name"],
                    "Method": req["method"],
                    "URL": req["url"],
                    "Role": role,
                    "Status Code": "ERR",
                    "Response Time (ms)": 0,
                    "Pass/Fail": "ERROR",
                    "Response Body": str(e)
                })

    # Save to CSV
    keys = report_data[0].keys() if report_data else []
    if keys:
        with open(REPORT_FILE, "w", newline="", encoding="utf-8") as f:
            dict_writer = csv.DictWriter(f, fieldnames=keys)
            dict_writer.writeheader()
            dict_writer.writerows(report_data)
        print(f"📊 Test report saved to {REPORT_FILE}")

if __name__ == "__main__":
    run_tests()

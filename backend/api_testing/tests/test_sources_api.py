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

TOKENS = {
    "Admin": "token 16b54fcb694b109:79dac6f5a318d62",
    "Manager": "token 430e071770ddab7:a2d285c4ba66423",
    "Employee": "token 11497a0ff9508b7:ed36bee726627e1",
}

COLLECTION_FILE = "HomeSol Frappe Cloud.postman_collection.json"
REPORT_FILE = "sources_api_test_report.csv"
MODULE_NAME = "Sources"

# =================================================================
# 2. HELPER FUNCTIONS
# =================================================================

def extract_module_requests(items, module_name, parent_name=""):
    extracted = []
    for item in items:
        name = item.get("name", "")
        current_full_name = f"{parent_name} > {name}" if parent_name else name
        
        if module_name == name or module_name in parent_name:
            if "item" in item:
                extracted.extend(extract_module_requests(item["item"], module_name, current_full_name))
            elif "request" in item:
                req = item["request"]
                url_raw = req["url"]["raw"] if isinstance(req["url"], dict) else req["url"]
                
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
                        body = req["body"]["raw"]
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
        elif "item" in item: 
            extracted.extend(extract_module_requests(item["item"], module_name, current_full_name))
                
    return extracted

# =================================================================
# 3. SOURCES TESTING LOGIC
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
        print(f"🔍 Testing: {req['name']}")
        
        for role, token in TOKENS.items():
            test_headers = req["headers"].copy()
            test_headers["Authorization"] = token
            
            test_body = None
            if req["method"] in ["POST", "PUT"] and isinstance(req.get('body'), dict):
                # For 'Sources', probably no POST/PUT with dynamic body, but keep the logic
                test_body = {} # No randomization for now, assume GET or simple POST/PUT
            elif req.get('body'):
                test_body = req.get('body')

            start_time = time.time()
            try:
                if req["method"] in ["POST", "PUT"] and isinstance(test_body, dict):
                    response = requests.request(req["method"], req["url"], headers=test_headers, json=test_body, timeout=20)
                else:
                    response = requests.request(req["method"], req["url"], headers=test_headers, data=test_body, timeout=20)
                
                duration = int((time.time() - start_time) * 1000)
                status = response.status_code
                
                result = "PASS" if 200 <= status < 300 else "FAIL"
                if status in [401, 403]: result = "AUTH_RESTRICTED"
                if status >= 500: result = "SERVER_ERROR"

                print(f"   - Role [{role}]: Status {status} ({duration}ms) -> {result}")
                
                report_data.append({
                    "Endpoint": req["name"],
                    "Method": req["method"],
                    "URL": req["url"],
                    "Role": role,
                    "Status": status,
                    "Time_ms": duration,
                    "Result": result,
                    "Response_Snippet": response.text[:150].replace('', ' ')
                })
            except Exception as e:
                print(f"   - Role [{role}]: EXCEPTION {str(e)}")

    if report_data:
        with open(REPORT_FILE, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=report_data[0].keys())
            writer.writeheader()
            writer.writerows(report_data)
        print(f"📊 {MODULE_NAME} report saved to: {REPORT_FILE}")

if __name__ == "__main__":
    run_tests()

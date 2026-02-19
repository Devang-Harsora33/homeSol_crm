import requests
import json

BASE_URL = "https://erp.homesolindia.com"
# Using Admin token for verification
ADMIN_TOKEN = "token 16b54fcb694b109:79dac6f5a318d62" 

PROJECT_ID = "PROJ-00002"
VERIFY_URL = f"{BASE_URL}/api/resource/Property Projects/{PROJECT_ID}"

headers = {
    "Authorization": ADMIN_TOKEN,
    "Content-Type": "application/json"
}

print(f"Fetching current state of {PROJECT_ID}...")

try:
    response = requests.get(VERIFY_URL, headers=headers, timeout=10)
    response.raise_for_status() # Raise an HTTPError for bad responses (4xx or 5xx)
    
    data = response.json()
    
    if "data" in data and "location" in data["data"]:
        print(f"Current 'location' for {PROJECT_ID}:")
        print(json.dumps(json.loads(data["data"]["location"]), indent=2)) # Parse the stringified JSON
    else:
        print(f"Could not find 'location' field or 'data' key in response for {PROJECT_ID}.")
        print(json.dumps(data, indent=2))

except requests.exceptions.HTTPError as errh:
    print(f"HTTP Error: {errh}")
except requests.exceptions.ConnectionError as errc:
    print(f"Error Connecting: {errc}")
except requests.exceptions.Timeout as errt:
    print(f"Timeout Error: {errt}")
except requests.exceptions.RequestException as err:
    print(f"Oops: Something Else {err}")
except json.JSONDecodeError:
    print(f"Failed to decode JSON from response: {response.text}")

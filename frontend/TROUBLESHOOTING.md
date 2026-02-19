# Network Connectivity Troubleshooting Guide

## Issue: Flutter App Cannot Connect to Backend Server

Your Flutter app is showing "Network error: Unable to connect to server" even though the backend server is running and accessible from your development machine.

## Root Cause

The Flutter app (running on a device/emulator) cannot reach your development computer's IP address `192.168.29.220:8000`.

## Solutions to Try (in order of likelihood)

### 1. **Check Network Configuration** ✅ Most Likely

- Ensure both your Flutter device/emulator and development computer are on the **same Wi-Fi network**
- Check that your device is not using mobile data
- Verify the device can access the internet (try opening a website)

### 2. **Test Network Connectivity**

- Use the "Test Connection" button in the app to diagnose the issue
- Check the console logs for detailed error messages
- Look for specific error types:
  - `SocketException`: Network connectivity issue
  - `TimeoutException`: Server response too slow

### 3. **Firewall Configuration**

- **Windows Firewall**: Allow Python/uvicorn through firewall
- **Antivirus**: Check if antivirus is blocking connections
- **Router**: Ensure router allows local network communication

### 4. **Backend Server Configuration**

Your server is running on `0.0.0.0:8000` which should accept connections from any IP, but verify:

- No additional firewall rules blocking external connections
- Server is not restricted to localhost only

### 5. **Alternative IP Addresses**

Try these IP addresses if `192.168.29.220` doesn't work:

- `10.0.2.2` (Android Emulator to host machine)
- `127.0.0.1` (Localhost - only works on same machine)
- Your computer's other network adapter IPs

### 6. **Network Testing Commands**

From your development machine, test these:

```bash
# Test if server responds locally
curl http://localhost:8000/api/v1/stories/

# Test if server responds on network IP
curl http://192.168.29.220:8000/api/v1/stories/

# Test from another device on same network (if available)
# Use a phone or another computer to test the URL
```

### 7. **Flutter Device-Specific Solutions**

#### **Android Emulator**

- Use `10.0.2.2:8000` instead of `192.168.29.220:8000`
- This is the special IP that Android emulator uses to reach the host machine

#### **Physical Android Device**

- Ensure device is on same Wi-Fi network
- Try turning off mobile data temporarily
- Check device firewall settings

#### **iOS Simulator**

- Use `localhost:8000` or `127.0.0.1:8000`
- iOS simulator runs on the same machine as your development environment

#### **Physical iOS Device**

- Same as Android physical device
- Check iOS firewall and network settings

## Quick Fixes to Try

### **Option 1: Update API Service for Emulator**

If using Android emulator, change the base URL to:

```dart
static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
```

### **Option 2: Update API Service for Localhost**

If testing on same machine, change to:

```dart
static const String baseUrl = 'http://127.0.0.1:8000/api/v1';
```

### **Option 3: Use Network IP (Current)**

Keep current configuration:

```dart
static const String baseUrl = 'http://192.168.29.220:8000/api/v1';
```

## Debugging Steps

1. **Run the app** and check console logs
2. **Press "Test Connection"** button to see detailed connectivity info
3. **Check error messages** for specific network issues
4. **Verify network configuration** on both device and computer
5. **Test with different IP addresses** as needed

## Expected Behavior

After fixing the connectivity issue:

- Stories section should show real data from API
- Projects section should display real property data
- No more "Network error" messages
- Console should show successful API responses

## Still Having Issues?

If none of the above solutions work:

1. Check if your router has any special network isolation features
2. Try using a mobile hotspot to test if it's a router issue
3. Check if your ISP blocks local network communication
4. Consider using a VPN or different network configuration

# Page-Specific Test Cases

This document provides a detailed breakdown of test cases implemented for each page of the Homesol application.

---

## 1. Home Page (`lib/pages/home_page.dart`)
**Test File**: `test/home_page_enhanced_test.dart`

### UI & Initial State
- **TC-HP-01: Header Elements Verification**
  - **Goal**: Ensure the app bar shows "HomeSol" and "by HomeSol India".
  - **Expectation**: Both text strings are found exactly once.
- **TC-HP-02: Initial Attendance Status**
  - **Goal**: Verify that the page starts with the correct initial attendance status.
  - **Expectation**: If `initialAttendanceStatus` is 'OUT', "You are Clocked Out" is displayed.

### Attendance Logic
- **TC-HP-03: Shift-Based Button Enablement (Active Shift)**
  - **Goal**: "Check In" button should be enabled during shift hours.
  - **Condition**: Current time is between `start_time` and `end_time`.
  - **Expectation**: `ElevatedButton` with text 'Check In' is enabled.
- **TC-HP-04: Shift-Based Button Enablement (Inactive Shift)**
  - **Goal**: "Check In" button should be disabled outside shift hours.
  - **Condition**: Current time is before `start_time` or after `end_time`.
  - **Expectation**: `ElevatedButton` with text 'Check In' is disabled.
- **TC-HP-05: Late Check-In Remark Popup**
  - **Goal**: Show a remark dialog if checking in more than 15 minutes late.
  - **Action**: Tap 'Check In' when current time > `start_time` + 15 mins.
  - **Expectation**: Dialog with title "Late Check-In" appears.
- **TC-HP-06: Remark Validation**
  - **Goal**: "Submit" button in late popup remains disabled until a reason is provided.
  - **Action**: Open late popup, verify 'Submit' is disabled, enter text, verify 'Submit' is enabled.
- **TC-HP-07: Clock-Out Flow**
  - **Goal**: Verify the transition from 'IN' to 'OUT'.
  - **Action**: Tap 'Check Out' when status is 'IN'.
  - **Expectation**: `ShiftService.checkOut` is called once, and status updates to "You are Clocked Out".

### Location Services
- **TC-HP-08: Geofencing Check (Out of Range)**
  - **Goal**: Prevent attendance actions if the user is too far from the project site.
  - **Condition**: User distance > 350 meters from project coordinates.
  - **Action**: Tap 'Check In'.
  - **Expectation**: Snackbar appears with "You are out of range" and `ShiftService` is not called.

### Interactions
- **TC-HP-09: Pull-to-Refresh**
  - **Goal**: Ensure the page triggers a refresh when pulled down.
  - **Action**: Trigger a vertical fling on the `RefreshIndicator`.
  - **Expectation**: The `onRefresh` callback provided to the widget is executed.

---

## 2. CRM Page (`lib/pages/crm_page.dart`)
**Test File**: `test/crm_page_test.dart`

### UI Verification
- **TC-CRM-01: Header Verification**
  - **Goal**: Verify the page title.
  - **Expectation**: Text "CRM" is found.
- **TC-CRM-02: Search Bar Rendering**
  - **Goal**: Verify the search input field exists with correct hint.
  - **Expectation**: `TextField` with hint "Search by name, phone, project..." is found.

### Lead Management
- **TC-CRM-03: Data Binding (Leads List)**
  - **Goal**: Ensure leads from the local database are displayed.
  - **Condition**: A mock lead "John Doe" exists in `LeadDatabase`.
  - **Expectation**: Text "John Doe" is visible in the list.
- **TC-CRM-04: Search Functionality (Success)**
  - **Goal**: Filter the list by lead name.
  - **Action**: Enter "John" in the search bar.
  - **Expectation**: "John Doe" remains visible.
- **TC-CRM-05: Search Functionality (No Results)**
  - **Goal**: Show empty state when no leads match.
  - **Action**: Enter a name that doesn't exist (e.g., "Jane").
  - **Expectation**: "John Doe" disappears, and "No leads match your filters" is displayed.

### Filters
- **TC-CRM-06: Filter Sheet Interaction**
  - **Goal**: Verify the filter bottom sheet opens.
  - **Action**: Tap the filter icon (`Icons.tune`).
  - **Expectation**: Bottom sheet with title "Filters" and "Apply Filters" button appears.

---

## 3. Data Models (`lib/models/`)
**Test File**: `test/lead_test.dart`

### Lead Model
- **TC-MDL-01: JSON Deserialization**
  - **Goal**: Correct parsing of API response into `Lead` object.
- **TC-MDL-02: HTML Stripping in Notes**
  - **Goal**: Ensure `plainText` getter removes HTML tags from notes.
  - **Condition**: Note content is `<p>Hello <b>World</b></p>`.
  - **Expectation**: `plainText` returns "Hello World".
- **TC-MDL-03: Null Safety**
  - **Goal**: Ensure model handles missing JSON fields gracefully.

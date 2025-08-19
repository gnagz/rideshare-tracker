# Rideshare Tracker - Test Plan

## Overview
This test plan validates the functionality and user experience of the Rideshare Tracker app across both iOS and macOS platforms following the recent cross-platform updates.

## Test Environment
- **iOS Version**: _[To be filled]_
- **macOS Version**: _[To be filled]_
- **App Version**: _[To be filled]_
- **Tester**: _[To be filled]_

---

## Test 1: Complete Shift Workflow (Both Platforms)
**Objective**: Verify the full lifecycle of creating, running, and completing a shift

**Test Steps**:
1. Open the app
2. Tap/click the "+" button to start a new shift
3. Set start time to current time
4. Enter odometer reading (e.g., 50000.0)
5. Toggle "Full Tank of Gas" to ON
6. Save the shift
7. Verify the shift appears in the list with "Active" status
8. Select/tap the active shift to view details
9. Click/tap "End Shift" button
10. Set end time 2 hours later than start time
11. Enter end odometer reading (e.g., 50125.5 - for 125.5 miles)
12. Toggle "Refueled Tank" to ON and enter 8.5 gallons, $29.75
13. Enter trip data: 12 trips, $95.50 net fare, $25.00 tips
14. Enter expenses: $5.00 tolls, $3.00 tolls reimbursed, $2.00 parking
15. Save the completed shift

**Acceptance Criteria**:
- Shift shows calculated duration (2h 0m)
- Shift mileage shows correctly (125.5 mi)
- Total earnings shows $120.50 ($95.50 + $25.00)
- All financial calculations appear reasonable
- Shift no longer shows "Active" status

### Test Results

| Test Date | Platform | Success/Fail | Duration | Notes | Issues Found |
|-----------|----------|--------------|----------|-------|--------------|
|           | iOS      |              |          |       |              |
|           | macOS    |              |          |       |              |

---

## Test 2: Platform-Specific UI Elements
**Objective**: Verify platform-appropriate UI behaviors

### macOS Specific Tests:
**Test Steps**:
1. Open shift detail view
2. Verify header has inline "Edit" and "End Shift" buttons (not in toolbar)
3. Test keyboard shortcuts: Cmd+W to close, Cmd+, for preferences
4. Verify two-column layout displays properly
5. Test window resizing behavior
6. Test preferences window opens as separate modal

**Acceptance Criteria**:
- Buttons appear in header, not toolbar
- Layout adapts well to different window sizes
- Keyboard shortcuts work as expected
- macOS-native UI elements (GroupBox, etc.) display correctly

### iOS Specific Tests:
**Test Steps**:
1. Open shift detail view
2. Verify "Edit" and "End Shift" buttons appear in navigation bar
3. Test form scrolling behavior
4. Test keyboard handling (numeric keypad for numbers)
5. Tap "Done" on keyboard toolbar when editing numbers
6. Test navigation back/forward gestures

**Acceptance Criteria**:
- Navigation bar buttons work correctly
- Keyboard appears/dismisses properly
- Form sections scroll smoothly
- iOS-native styling appears correct

### Test Results

| Test Date | Platform | UI Element | Success/Fail | Notes | Issues Found |
|-----------|----------|------------|--------------|-------|--------------|
|           | macOS    | Button Placement |        |       |              |
|           | macOS    | Window Resizing |         |       |              |
|           | macOS    | Keyboard Shortcuts |      |       |              |
|           | macOS    | Two-Column Layout |       |       |              |
|           | iOS      | Navigation Buttons |      |       |              |
|           | iOS      | Keyboard Handling |       |       |              |
|           | iOS      | Form Scrolling |          |       |              |
|           | iOS      | Navigation Gestures |     |       |              |

---

## Test 3: Data Persistence & Week Navigation (Both Platforms)
**Objective**: Verify data saves correctly and week navigation works

**Test Steps**:
1. Create 2-3 shifts in current week
2. Close and reopen the app
3. Verify all shifts are still present
4. Use left arrow to navigate to previous week
5. Create a shift in previous week
6. Navigate back to current week
7. Navigate to next week (should be disabled if current week)
8. Test week totals calculations

**Acceptance Criteria**:
- All shifts persist after app restart
- Week navigation works correctly
- Weekly totals calculate accurately
- Date ranges display correctly in header
- Future weeks are properly disabled

### Test Results

| Test Date | Platform | Feature | Success/Fail | Notes | Issues Found |
|-----------|----------|---------|--------------|-------|--------------|
|           | iOS      | Data Persistence |     |       |              |
|           | iOS      | Week Navigation |      |       |              |
|           | iOS      | Weekly Totals |        |       |              |
|           | macOS    | Data Persistence |     |       |              |
|           | macOS    | Week Navigation |      |       |              |
|           | macOS    | Weekly Totals |        |       |              |

---

## Test 4: Edit Functionality (Both Platforms)
**Objective**: Verify editing existing shifts works correctly

**Test Steps**:
1. Select a completed shift
2. Click/tap "Edit" button
3. Modify start time, odometer reading
4. Change earnings data (add $10 to tips)
5. Save changes
6. Verify all calculations update automatically
7. Test editing an active (uncompleted) shift
8. Verify you can only edit start data for active shifts

**Acceptance Criteria**:
- All editable fields save correctly
- Calculations update immediately after editing
- Active vs completed shift editing restrictions work
- UI refreshes to show updated data

### Test Results

| Test Date | Platform | Edit Type | Success/Fail | Calculations Updated | Notes | Issues Found |
|-----------|----------|-----------|--------------|---------------------|-------|--------------|
|           | iOS      | Completed Shift |   |                     |       |              |
|           | iOS      | Active Shift |      |                     |       |              |
|           | macOS    | Completed Shift |   |                     |       |              |
|           | macOS    | Active Shift |      |                     |       |              |

---

## Test 5: Preferences Integration (Both Platforms)
**Objective**: Verify preferences affect calculations correctly

**Test Steps**:
1. Open Preferences/Settings
2. Change gas price to $4.00/gallon
3. Change tank capacity to 16.0 gallons
4. Change standard mileage rate to $0.75
5. Save preferences
6. View a completed shift's details
7. Verify gas cost calculations reflect new price
8. Verify tax deductible expense reflects new mileage rate

**Acceptance Criteria**:
- Preference changes immediately affect calculations
- All monetary calculations update correctly
- Gas usage calculations use new tank capacity
- UI displays updated values without restart

### Test Results

| Test Date | Platform | Preference Changed | Success/Fail | Calculations Updated | Notes | Issues Found |
|-----------|----------|--------------------|--------------|---------------------|-------|--------------|
|           | iOS      | Gas Price |                |                     |       |              |
|           | iOS      | Tank Capacity |            |                     |       |              |
|           | iOS      | Mileage Rate |             |                     |       |              |
|           | macOS    | Gas Price |                |                     |       |              |
|           | macOS    | Tank Capacity |            |                     |       |              |
|           | macOS    | Mileage Rate |             |                     |       |              |

---

## Test 6: Edge Cases & Error Handling (Both Platforms)
**Objective**: Verify app handles unusual inputs gracefully

**Test Steps**:
1. Try to create shift with empty odometer reading
2. Try to end shift with end mileage less than start mileage
3. Enter very large numbers for earnings/expenses
4. Test with decimal values in all numeric fields
5. Test deleting shifts (swipe on iOS, context menu on macOS)

**Acceptance Criteria**:
- Required field validation works
- Logical validation prevents invalid data
- Large numbers display/calculate correctly
- Decimal precision maintained appropriately
- Deletion works on both platforms

### Test Results

| Test Date | Platform | Edge Case | Success/Fail | Handled Gracefully | Notes | Issues Found |
|-----------|----------|-----------|--------------|-------------------|-------|--------------|
|           | iOS      | Empty Required Fields |  |                 |       |              |
|           | iOS      | Invalid Mileage |        |                 |       |              |
|           | iOS      | Large Numbers |          |                 |       |              |
|           | iOS      | Decimal Values |         |                 |       |              |
|           | iOS      | Delete Shift |           |                 |       |              |
|           | macOS    | Empty Required Fields |  |                 |       |              |
|           | macOS    | Invalid Mileage |        |                 |       |              |
|           | macOS    | Large Numbers |          |                 |       |              |
|           | macOS    | Decimal Values |         |                 |       |              |
|           | macOS    | Delete Shift |           |                 |       |              |

---

## Summary

### Overall Test Results
| Test Category | iOS Status | macOS Status | Critical Issues | Notes |
|---------------|------------|--------------|-----------------|-------|
| Complete Workflow |        |              |                 |       |
| Platform UI |             |              |                 |       |
| Data Persistence |         |              |                 |       |
| Edit Functionality |       |              |                 |       |
| Preferences |              |              |                 |       |
| Edge Cases |               |              |                 |       |

### Testing Notes
- **Recommended Testing Order**: Start with Test 1 (Complete Workflow) on both platforms
- **Priority Issues**: Any failures in Tests 1, 3, or 4 should be addressed immediately
- **UI Polish**: Test 2 results will guide any UI refinements needed

### Sign-off
- **Tester**: _______________  **Date**: _______________
- **Developer**: _______________  **Date**: _______________
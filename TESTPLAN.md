# Rideshare Tracker - Test Plan

## Overview
This test plan validates the functionality and user experience of the Rideshare Tracker app on iOS devices (iPhone, iPad, and Mac) following recent updates to currency input and expense management systems.

## Current Automated Test Status (September 2025)

### Unit Tests: ✅ ALL PASSING (95 tests)
- **ExpenseManagementTests**: 20 tests - Image management, CSV export, data operations
- **CloudSyncTests**: 19 tests - iCloud sync, conflict resolution, metadata handling
- **RideshareShiftModelTests**: 15 tests - Business logic, profit calculations, photo attachments
- **TollImportTests**: 14 tests - CSV parsing, Excel formulas, shift matching, image generation
- **MathCalculatorTests**: 8 tests - Expression evaluation, rideshare scenarios
- **DateRangeCalculationTests**: 15 tests - Week/month filtering, boundary calculations
- **CSVImportExportTests**: 4 tests - CSV import/export, tank reading conversions

**Total Execution Time**: ~28 seconds

### UI Tests: ✅ ALL PASSING (32 tests across 6 files)
- **Photo picker workflows**: All 5 photo-related tests now passing (previously broken)
- **Complete user workflows**: Shift creation, expense management, import/export
- **Calculator integration**: Currency input field calculator functionality
- **Toll import workflows**: CSV import with automatic shift matching

**Parallel Execution Time**: ~5 minutes (significant performance improvement)
**Serial Execution Time**: ~10+ minutes

### Test Infrastructure
- **Parallel Testing**: Enabled and optimized for UI tests
- **Test Consolidation Opportunity**: 32 tests could potentially be optimized to ~31 tests
- **Error Resolution**: All previously failing photo picker tests now pass
- **Coverage**: Complete feature coverage including advanced features (toll import, calculator, cloud sync)

## Test Environment
- **iOS Version**: _[To be filled]_
- **Device Type**: _[iPhone/iPad/Mac - To be filled]_
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

## Test 7: Currency Input Fields
**Objective**: Verify enhanced currency input behavior across all forms

**Test Steps**:
1. Open StartShiftView and navigate to currency fields
2. Test clearing a currency field - verify it stays empty (not "$0.00")
3. Type "5.67" in a currency field and tab away - verify it formats to "$5.67"
4. Edit an existing "$12.34" value by deleting characters - verify no interference
5. Test in EndShiftView, EditShiftView, and expense forms
6. Test both required and optional currency fields
7. Verify decimal precision is maintained correctly

**Acceptance Criteria**:
- Empty fields stay empty when cleared
- No typing interference or unwanted zero insertion
- Proper formatting only occurs when editing is complete
- Consistent behavior across all currency fields app-wide
- Both Double and Optional<Double> bindings work correctly

### Test Results

| Test Date | Device Type | Form | Clear Behavior | Edit Behavior | Format Behavior | Issues Found |
|-----------|-------------|------|----------------|---------------|-----------------|--------------|
|           | iPhone      | StartShift |          |               |                 |              |
|           | iPhone      | EndShift |            |               |                 |              |
|           | iPhone      | EditShift |           |               |                 |              |
|           | iPhone      | Expenses |            |               |                 |              |
|           | iPad        | All Forms |           |               |                 |              |
|           | Mac         | All Forms |           |               |                 |              |

---

## Test 8: Expense Management System  
**Objective**: Verify complete expense tracking functionality

**Test Steps**:
1. Switch to Expenses tab in main navigation
2. Verify empty state shows correctly for current month
3. Add expense: Vehicle category, "Oil change", $45.00, today's date
4. Add expense: Equipment category, "Phone mount", $25.99, different date
5. Verify month total updates to $70.99
6. Navigate to previous/next month using arrow buttons
7. Test date picker for month selection
8. Edit an existing expense - change amount to $50.00
9. Verify totals update automatically
10. Delete an expense using swipe gesture
11. Test expense row layout - day number should not wrap
12. Add expense with very long description - verify truncation works

**Acceptance Criteria**:
- Month navigation works correctly
- Totals calculate and update automatically
- All CRUD operations work properly
- Day numbers never wrap or show "..."
- Long descriptions truncate with ellipsis
- Category icons display correctly

### Test Results

| Test Date | Device Type | Feature | Success/Fail | Totals Correct | Layout Issues | Notes |
|-----------|-------------|---------|--------------|----------------|---------------|-------|
|           | iPhone      | Add Expense |        |                |               |       |
|           | iPhone      | Month Navigation |   |                |               |       |
|           | iPhone      | Edit/Delete |       |                |               |       |
|           | iPhone      | Layout/Truncation | |                |               |       |
|           | iPad        | All Features |      |                |               |       |
|           | Mac         | All Features |      |                |               |       |

---

## Summary

### Overall Test Results
| Test Category | iPhone | iPad | Mac | Critical Issues | Notes |
|---------------|--------|------|-----|-----------------|-------|
| Complete Workflow |      |      |     |                 |       |
| Platform UI |           |      |     |                 |       |
| Data Persistence |       |      |     |                 |       |
| Edit Functionality |     |      |     |                 |       |
| Preferences |            |      |     |                 |       |
| Edge Cases |             |      |     |                 |       |
| Currency Input |         |      |     |                 |       |
| Expense Management |     |      |     |                 |       |

### Testing Notes
- **Recommended Testing Order**: Start with Test 1 (Complete Workflow), then Test 7 (Currency Input), then Test 8 (Expense Management)
- **Priority Issues**: Any failures in Tests 1, 3, 4, 7, or 8 should be addressed immediately
- **New Features**: Tests 7 and 8 validate recent currency input and expense management enhancements
- **Device Coverage**: Test on iPhone, iPad, and Mac to ensure universal compatibility

---

## Test 9: Scientific Calculator Integration
**Objective**: Verify built-in calculator functionality in currency fields

**Test Steps**:
1. Open any form with currency input (StartShift, EndShift, AddExpense)
2. Tap the calculator button on any currency field
3. Test basic arithmetic: 45+23, 100-25, 50*2, 100/4
4. Test complex expressions: (250-175)*0.67, 100+50*2-25/5
5. Test memory functions: M+, M-, MR, MC with different values
6. Test calculation tape - verify previous calculations are shown
7. Enter complex expression and tap "Done" to insert result
8. Test parentheses and percentage functions
9. Test error handling with invalid expressions

**Acceptance Criteria**:
- Calculator opens as popup overlay without leaving current form
- All arithmetic operations calculate correctly
- Memory functions work and persist during session
- Calculation tape shows previous calculations
- "Done" button inserts calculated result into field
- Error states display clearly for invalid expressions

### Test Results

| Test Date | Device Type | Feature | Success/Fail | Accuracy | Integration Works | Issues Found |
|-----------|-------------|---------|--------------|----------|-------------------|--------------|
|           | iPhone      | Basic Math |        |          |                   |              |
|           | iPhone      | Complex Expressions |  |        |                   |              |
|           | iPhone      | Memory Functions |     |        |                   |              |
|           | iPhone      | Result Integration |   |        |                   |              |
|           | iPad        | All Features |        |        |                   |              |
|           | Mac         | All Features |        |        |                   |              |

---

## Test 10: Toll Import System
**Objective**: Verify CSV toll import with automatic shift matching

**Test Steps**:
1. Create 2-3 test shifts with different start/end times
2. Navigate to Settings → Import/Export → Import
3. Select "Tolls" import type
4. Create test CSV with toll transactions during shift times
5. Include columns: Transaction Entry Date, Transaction Amount, Location
6. Test with Excel formula dates: "=Text(""09/16/2025 18:20:33"",""mm/dd/yyyy HH:mm:SS"")"
7. Test with negative amounts: "-$1.30" format
8. Import the CSV file
9. Verify tolls are added to matching shifts
10. Verify toll summary images are generated and attached
11. Test with tolls outside shift time windows (should be ignored)

**Acceptance Criteria**:
- CSV file imports successfully with progress feedback
- Toll transactions match to shifts based on time windows
- Toll amounts are added to existing shift toll totals
- Toll summary images are generated and attached to shifts
- Transactions outside shift windows are properly ignored
- Excel formula parsing works correctly
- Negative amounts are converted to positive values

### Test Results

| Test Date | Device Type | Feature | Success/Fail | Matching Accurate | Images Generated | Issues Found |
|-----------|-------------|---------|--------------|-------------------|------------------|--------------|
|           | iPhone      | CSV Import |        |                   |                  |              |
|           | iPhone      | Time Matching |     |                   |                  |              |
|           | iPhone      | Image Generation |  |                   |                  |              |
|           | iPad        | All Features |      |                   |                  |              |
|           | Mac         | All Features |      |                   |                  |              |

---

## Test 11: Photo Attachment Workflows
**Objective**: Verify complete photo management system

**Test Steps**:
1. Create new shift and navigate to photo section
2. Test "Add Receipt Photo" - camera and photo library options
3. Add multiple photos (up to 5) to a single shift
4. Verify thumbnail previews appear in shift detail
5. Tap thumbnails to view full-screen with zoom/pan capabilities
6. Test photo sharing from full-screen viewer
7. Test photo deletion with confirmation
8. Repeat for expense photo attachments
9. Verify photos persist after app restart
10. Test photo display in shift/expense list views

**Acceptance Criteria**:
- Camera and photo library access work correctly
- Multiple photos can be attached per shift/expense
- Thumbnails display properly in lists and detail views
- Full-screen viewer supports zoom, pan, and sharing
- Photo deletion works with proper confirmation
- Photos persist correctly in local storage
- Image compression and storage optimization work

### Test Results

| Test Date | Device Type | Feature | Success/Fail | Photo Quality | Performance | Issues Found |
|-----------|-------------|---------|--------------|---------------|-------------|--------------|
|           | iPhone      | Photo Capture |     |               |             |              |
|           | iPhone      | Multiple Photos |   |               |             |              |
|           | iPhone      | Full-Screen Viewer | |               |             |              |
|           | iPhone      | Photo Persistence |  |               |             |              |
|           | iPad        | All Features |       |               |             |              |
|           | Mac         | All Features |       |               |             |              |

---

### Sign-off
- **Tester**: _______________  **Date**: _______________
- **Developer**: _______________  **Date**: _______________
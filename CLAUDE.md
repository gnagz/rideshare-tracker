# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SwiftUI iOS Universal application for rideshare drivers to track shifts, earnings, and expenses. The app runs on iPhone, iPad, and Mac with iOS-native UI design.

**Core Purpose**: Help rideshare drivers track profitability by logging shift data including mileage, fuel costs, earnings, and business expenses.

## Build Commands

### Building and Testing
```bash
# Build iOS app
xcodebuild -scheme "Rideshare Tracker" -configuration Debug

# Run iOS tests
xcodebuild test -scheme "Rideshare Tracker" -destination "platform=iOS Simulator,arch=arm64,OS=18.6,name=iPhone 16 Pro" -parallel-testing-enabled NO

# Open in Xcode
open "Rideshare Tracker.xcodeproj"
```

## Architecture

### Data Layer
- **ShiftDataManager**: Singleton managing all shift data using UserDefaults persistence
- **ExpenseDataManager**: Singleton managing business expense data with monthly filtering
- **AppPreferences**: User settings (tank capacity, gas prices, mileage rates, date/time formats, sync preferences) with UserDefaults persistence
- **RideshareShift**: Core data model with comprehensive business logic for calculations and sync metadata
- **ExpenseItem**: Business expense data model with categorization and sync metadata

### Cloud Sync Layer
- **CloudSyncManager**: Handles all iCloud operations including initial sync, incremental sync, and conflict resolution
- **SyncLifecycleManager**: Manages automatic sync triggers based on app lifecycle events
- **IncrementalSyncView**: Comprehensive UI for sync settings, education, and manual sync operations

### UI Architecture
The app uses a tab-based navigation with iOS Universal design:
- **MainTabView**: Tab-based interface with Shifts and Expenses sections
- **Shifts Tab**: Track driving shifts with earnings and shift-specific expenses
- **Expenses Tab**: Track general business expenses with monthly navigation

### Key Business Logic
All financial calculations are in RideshareShift model:
- `shiftGasUsage()`: Calculates fuel consumption based on tank readings
- `totalTaxDeductibleExpense()`: IRS mileage-based deductions  
- `grossProfit()` and `netProfit()`: Profitability calculations
- Tank readings stored as eighths (0-8 scale) for fuel gauge precision

### Data Persistence
- **Local Storage**: JSON encoded to UserDefaults via data managers
- **Cloud Storage**: JSON files in iCloud Documents container for sync
- **Sync Metadata**: All records include timestamps, deviceID, and deletion flags
- **Conflict Resolution**: Last-modified-wins strategy with device tracking
- No Core Data or external databases used

### Incremental Cloud Sync System
- **Real iCloud Integration**: Uses FileManager with ubiquity container
- **Multi-Device Support**: Seamless synchronization across iPhone, iPad, and Mac
- **Automatic Sync**: Configurable frequency (Immediate, Hourly, Daily) with app lifecycle triggers
- **Manual Sync**: User-triggered sync with progress indication and status feedback
- **Data Protection**: Ultimate backup protection - never lose data again
- **Initial Sync**: Migrates existing user data when first enabling sync
- **Conflict Handling**: Intelligent merge of concurrent edits across devices

### Currency Input System
- **CurrencyTextField**: Reusable SwiftUI component for user-friendly currency input
- **No Real-time Formatting**: Eliminates typing interference by formatting only on completion
- **Dual Binding Support**: Handles both `Double` and `Optional<Double>` bindings
- **Empty Field Handling**: Fields stay empty when cleared instead of showing "$0.00"

### Import/Export System
- **Comprehensive CSV Export**: 32 columns including all input fields and calculated metrics
- **Dual Purpose**: Serves as both editable data file and complete business report
- **Smart Matching**: Import matches records by start date + odometer reading (no conflicts with multiple shifts per day)
- **Bulk Edit Workflow**: Export → Edit in spreadsheet → Import with user choice for duplicates
- **Business Reporting**: Tax-ready data with taxable income, deductible expenses, profit metrics
- **Fuel Tracking**: Complete tank readings, refuel data, MPG calculations preserved
- **Preference Context**: Tank capacity, gas prices, mileage rates included for analysis

## Key Files Structure

```
Rideshare Tracker/
├── Models/
│   ├── RideshareShift.swift      # Core data model with business logic and sync metadata
│   ├── ExpenseItem.swift         # Business expense data model with sync metadata
│   └── AppPreferences.swift      # User settings and sync preferences management
├── Managers/
│   ├── ShiftDataManager.swift    # Shift data persistence layer (singleton)
│   ├── ExpenseDataManager.swift  # Expense data persistence layer (singleton)
│   ├── CloudSyncManager.swift    # iCloud sync operations and conflict resolution
│   └── SyncLifecycleManager.swift # Automatic sync triggers on app lifecycle events
├── Views/
│   ├── MainTabView.swift         # Tab navigation (Shifts/Expenses)
│   ├── ContentView.swift         # Shifts dashboard with weekly view
│   ├── StartShiftView.swift      # Shift creation form
│   ├── EndShiftView.swift        # Shift completion form
│   ├── EditShiftView.swift       # Edit existing shifts
│   ├── ShiftDetailView.swift     # View shift details
│   ├── ExpenseListView.swift     # Expenses dashboard with monthly view
│   ├── AddExpenseView.swift      # Add business expenses
│   ├── EditExpenseView.swift     # Edit existing expenses
│   ├── PreferencesView.swift     # Settings/preferences
│   ├── IncrementalSyncView.swift # Cloud sync settings and education
│   ├── MainMenuView.swift        # Settings menu with sync integration
│   └── BackupRestoreView.swift   # Local backup/restore functionality
└── Extensions/
    ├── DateFormatter+Extensions.swift
    └── NumberFormatter+Extensions.swift  # Includes CurrencyTextField
```

## Development Guidelines

### Making Changes
- Business logic belongs in the model classes (RideshareShift, ExpenseItem), not in views
- Use `@EnvironmentObject` for data manager and preferences injection, or access via .shared singletons
- For currency input fields, always use CurrencyTextField instead of native TextField with currency formatting
- Use MainTabView for primary navigation between Shifts and Expenses sections
- All data models include sync metadata (createdDate, modifiedDate, deviceID, isDeleted) for cloud sync
- CloudSyncManager handles all iCloud operations with async/await patterns
- SyncLifecycleManager automatically triggers sync on app lifecycle events

### Testing
The project includes comprehensive test coverage:
- **Unit Tests**: Complete sync functionality, data persistence, business logic calculations
- **UI Tests**: Full user workflows including sync setup, manual sync, and navigation
- **Sync Testing**: Initial sync, incremental sync, conflict resolution, and error handling
- **Legacy Testing**: Complete shift workflows, expense management, and currency input behavior
- All tests pass and build is warning-free

#### Critical Testing Rules
**CARDINAL RULE: DO NOT REWRITE or REMOVE CODE WITHOUT EXPLICIT USER AGREEMENT**

**Testing Best Practices:**
- Use standard destination: `"platform=iOS Simulator,arch=arm64,OS=18.6,name=iPhone 16 Pro"` unless discussed otherwise
- UI tests can take up to 10 minutes - never timeout early
- Use `--disable-concurrent-testing` when troubleshooting failures
- Test one at a time with `-only-testing` when debugging specific issues
- Add new tests incrementally, one at a time
- Look for consolidation opportunities in repetitive UI tests
- Some tests require keyboard dismissal to prevent timeouts

**Recovery Protocol:**
- If tests break, comment out working tests to isolate failures quickly
- Once fixed, remove comment characters (not comment blocks) to restore tests
- Always verify git status before major changes to avoid losing progress

### Common Patterns
- All forms use two-way binding with model properties
- Calculations update automatically when underlying data changes
- Dual persistence: UserDefaults for local + iCloud Documents for sync
- CurrencyTextField used for all currency input fields to prevent formatting interference
- Tab-based navigation with environment objects shared across all views
- Singleton pattern for data managers with thread-safe access
- Async/await throughout sync operations with proper error handling

## Current Development Status

**Latest Major Feature: Incremental Cloud Sync System (Complete)**

The app now features enterprise-grade iCloud synchronization that provides:
- **Multi-Device Sync**: Seamless data sharing across iPhone, iPad, and Mac
- **Ultimate Data Protection**: Automatic cloud backup prevents data loss
- **Intelligent Conflict Resolution**: Handles concurrent edits across devices
- **User-Friendly Setup**: Beautiful interface with clear benefits and requirements
- **Automatic Operation**: Configurable sync frequency with lifecycle triggers
- **Production Ready**: Comprehensive testing and error handling

### Recent Implementation Highlights:
- Real iCloud Documents integration with FileManager APIs
- Comprehensive sync metadata system for all data models
- Beautiful IncrementalSyncView with user education and progress indication
- Automatic sync triggers on app background/foreground/termination
- Last-modified-wins conflict resolution with device tracking
- 25+ unit and UI tests covering all sync functionality
- Full backward compatibility with existing user data

The app provides professional-grade rideshare tracking with the reliability and convenience expected by drivers managing their business across multiple devices.
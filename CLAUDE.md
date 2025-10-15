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

**FUNDAMENTAL DEVELOPMENT PRINCIPLES - NEVER VIOLATE THESE:**
1. **NEVER declare work "done" without running ALL tests (Unit + UI) to verify nothing broke**
2. **NEVER commit changes to Git without first ensuring ALL tests pass**
3. **ALWAYS run full test suite before any Git commit**
4. **If tests fail, FIX them before declaring victory or committing**
5. **Take it slow - move forward, never backwards**
6. **Follow TDD principles - tests guide development, not afterthoughts**

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
- Compare with branches where tests previously passed (like phase1) to understand what broke
- Focus on fixing tests rather than rewriting code unless there's a proven legitimate bug

### Common Patterns
- All forms use two-way binding with model properties
- Calculations update automatically when underlying data changes
- Dual persistence: UserDefaults for local + iCloud Documents for sync
- CurrencyTextField used for all currency input fields to prevent formatting interference
- Tab-based navigation with environment objects shared across all views
- Singleton pattern for data managers with thread-safe access
- Async/await throughout sync operations with proper error handling

## Current System Capabilities

### **Core Features**
- **Shift Tracking**: Record start/end times, mileage, fuel usage, earnings, and expenses
- **Expense Management**: Track business expenses with categories and monthly filtering
- **Financial Calculations**: Automatic profit, tax deduction, and MPG calculations
- **Photo Attachments**: Camera and photo library integration for receipts and documentation

### **Advanced Features**
- **Toll Import System** (`ImportExportView.swift`): CSV import with Excel formula parsing, automatic toll-to-shift matching, generates toll summary images
- **Scientific Calculator** (`CalculatorPopupView.swift`): Integrated into currency fields with memory functions, expression evaluation, calculation history
- **Import/Export System**: CSV import/export for shifts, expenses, and tolls with 32-column comprehensive format and date range selection
- **Cloud Sync** (`CloudSyncManager.swift`): iCloud Documents integration with conflict resolution, device tracking, automatic/manual sync

### **Data Management**
- **Persistence**: UserDefaults for local data + iCloud Documents for sync
- **Models**: RideshareShift, ExpenseItem with sync metadata (createdDate, modifiedDate, deviceID, isDeleted)
- **Managers**: ShiftDataManager, ExpenseDataManager, CloudSyncManager singletons
- **Image Management**: Automatic resizing, storage, cleanup with ImageManager

### **Testing Infrastructure**
- **Unit Tests**: 95 tests across 7 files (ExpenseManagementTests, CloudSyncTests, RideshareShiftModelTests, TollImportTests, MathCalculatorTests, DateRangeCalculationTests, CSVImportExportTests)
- **UI Tests**: 32 tests across 6 files covering complete user workflows including photo workflows
- **Parallel Execution**: ~6.5 minutes total test time with parallel UI testing

### **User Interface**
- **MainTabView**: Tab navigation between Shifts and Expenses
- **Calculator Integration**: `CalculatorTextField` and `CurrencyTextField` with popup calculator
- **Photo Workflows**: `PhotosPicker` in shift and expense forms
- **Import/Export Interface**: Accessible via MainMenuView with tabbed interface for different data types

## Essential Documentation for New Sessions

These are the authoritative reference documents that should be consulted at the start of each new development session. These documents contain current, verified information about the system:

### **Primary Reference Documents**
- **[FEATURE_STATUS.md](./FEATURE_STATUS.md)**: **START HERE** - Comprehensive implementation status and system capabilities (September 2025)
- **[README.md](./README.md)**: Complete feature overview, setup instructions, and user-facing documentation
- **[TESTPLAN.md](./TESTPLAN.md)**: Manual testing procedures with current automated test status (95 unit + 32 UI tests)
- **[UI_AUTOMATED_TESTING.md](./UI_AUTOMATED_TESTING.md)**: Testing infrastructure documentation with current test execution status

### **Session Startup Protocol**
For new development sessions, read these documents in order:
1. **FEATURE_STATUS.md** - Current system state and implementation status
2. **CLAUDE.md** (this file) - Technical architecture and development patterns
3. **README.md** - Feature descriptions and setup procedures
4. **TESTPLAN.md** - Testing approach and current test status

### **Avoid Outdated References**
The project folder may contain temporary planning documents (various .md files) that reflect outdated status or planning information. The four documents listed above contain current, verified information. When in doubt, ask the user before consulting other documentation files.
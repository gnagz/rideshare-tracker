# Rideshare Tracker

A comprehensive SwiftUI iOS Universal app (iPhone, iPad, Mac) for rideshare drivers to track shifts, earnings, shift expenses, general business expenses, and vehicle data to analyze profitability and prepare for tax season. Features enterprise-grade iCloud synchronization for seamless multi-device usage and ultimate data protection.

## Features

### Shift Tracking
- **Shift Recording**: Start/end times, odometer readings, and fuel tank levels
- **Trip Data**: Number of trips, net fare, tips, promotions, and rider fees
- **Shift Expenses**: Tolls, parking fees, misc fees with reimbursement tracking
- **Vehicle Monitoring**: Fuel consumption, MPG calculations, and refuel tracking

### Expense Management
- **Business Expenses**: Track non-shift related expenses with categorization
- **Expense Categories**: Vehicle (maintenance, insurance), Equipment (bags, mounts), Supplies (cleaning, safety), Amenities (water, snacks)
- **Photo Attachments**: Attach receipt photos and images to expenses for better record-keeping
- **Monthly Filtering**: View expenses by month with automatic totals
- **Date Range Tracking**: Full calendar support for expense dating

### Financial Analysis
- **Profit Calculations**: Gross profit, cash flow, and profit per hour
- **Tax Preparation**: IRS standard mileage deductions and tax-deductible expense tracking
- **Revenue Tracking**: Comprehensive earnings including promotions and rider fees

### Data Management
- **Export/Import**: JSON backup/restore and CSV export with date range selection
- **Expense Export**: Separate CSV export for business expenses
- **Toll Import**: CSV import with automatic toll-to-shift matching and Excel formula parsing
- **Incremental Cloud Sync**: Real-time iCloud synchronization across all devices
- **Ultimate Data Protection**: Automatic cloud backup prevents data loss forever
- **Multi-Device Support**: Start shift on iPhone, end on iPad, view on Mac seamlessly

### User Experience
- **Dual Navigation**: Tab-based interface with Shifts and Expenses sections
- **Enhanced Currency Input**: User-friendly currency fields without typing interference
- **Scientific Calculator**: Built-in calculator with memory functions integrated into all number inputs
- **Customizable Preferences**: Date/time formats, timezone selection, vehicle settings
- **Universal Design**: Native experience on iPhone, iPad, and Mac

## Requirements

- Xcode 15.0 or later
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

### For Cloud Sync Features
- iCloud account signed in to device
- iCloud Drive enabled in device settings
- Internet connection for synchronization

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd "Rideshare Tracker"
```

### 2. Open in Xcode

Open `Rideshare Tracker.xcodeproj` in Xcode.

### 3. Configure Build Settings

The project includes an automated build number incrementing system. **Important setup required:**

#### A. Disable User Script Sandboxing
1. Select the project in Navigator
2. Go to Build Settings
3. Search for "User Script Sandboxing"
4. Set to **NO** (this allows the build script to modify project files)

#### B. Verify Build Script Configuration
1. Select the project target
2. Go to Build Phases
3. Confirm "Increment Build Number" script is **first** in the list
4. The script should contain:
```bash
# Only increment for actual iPhone device builds, not Mac deployment
if [ "${PLATFORM_NAME}" = "iphoneos" ] && [ "${TARGET_DEVICE_PLATFORM_NAME}" != "macosx" ]; then
    echo "iPhone device build detected - incrementing build number"
    
    # Run agvtool to increment build number
    xcrun agvtool next-version -all
    
    if [ $? -eq 0 ]; then
        echo "✅ Build number incremented successfully"
        NEW_BUILD=$(xcrun agvtool what-version -terse 2>/dev/null || echo "unknown")
        echo "New build number: ${NEW_BUILD}"
    else
        echo "⚠️ agvtool failed"
        exit 1
    fi
else
    echo "Mac deployment or other platform - not incrementing build number"
    echo "Platform: ${PLATFORM_NAME}, Target: ${TARGET_DEVICE_PLATFORM_NAME:-unknown}"
fi
```

### 4. Build and Run

1. Select your target device (iPhone/iPad for mobile, My Mac for desktop)
2. Build and run (⌘+R)

**Note**: Build numbers auto-increment only for iPhone device builds, not simulator or Mac builds.

## Testing Infrastructure

The app includes a professional UI automated testing system with comprehensive debug utilities and environment detection. See [UI_AUTOMATED_TESTING.md](UI_AUTOMATED_TESTING.md) for complete documentation.

### Key Testing Features
- **35+ UI Automated Tests**: Complete test coverage with 100% pass rate
- **Environment-Aware Testing**: Tests adapt to iCloud availability automatically
- **Local Sync Testing**: Tests use local storage instead of requiring iCloud connectivity  
- **Conditional Debug Output**: Clean test runs by default, detailed debug when needed
- **Visual Verification Controls**: Configurable pauses for manual UI inspection

### Debug Utilities
Configure debug behavior via Xcode scheme settings (Product → Scheme → Edit Scheme → Run → Arguments Passed On Launch):

- **`-testing`**: Enables local storage mode, removes iCloud warnings
- **`-debug`**: Shows detailed debug output during execution (available in both production and test code)
- **`-visual-debug`**: Adds visual verification pauses for manual observation (UI tests only)

#### Production Debug Features
The `-debug` flag enables comprehensive logging throughout the app:

**CSV Import Debugging**: Detailed tracing of import operations including:
- File loading and validation (line counts, header detection)
- Row-by-row processing with field mapping
- Date/time parsing attempts and format detection
- Tank level conversion from decimal to eighths
- Duplicate detection and handling strategies
- Final import statistics (added/updated/skipped counts)

**Cloud Sync Debugging**: Sync operations, conflict resolution, and data transfer status

**Example Debug Output**:
```
DEBUG [AppPreferences.swift:importCSV]: Starting CSV import from: shifts_export.csv
DEBUG [AppPreferences.swift:importCSV]: CSV file loaded: 25 non-empty lines found
DEBUG [AppPreferences.swift:importCSV]: CSV headers parsed: 15 columns - [StartDate, StartTime, StartMileage, ...]
DEBUG [AppPreferences.swift:parseDateFromCSV]: Date '8/15/24' parsed successfully with format 'M/d/yy' -> 2024-08-15
DEBUG [ImportExportView.swift:importShifts]: Processing shift 2024-08-15: duplicate=false, action=merge
DEBUG [ImportExportView.swift:importShifts]: Import completed: added=23, updated=0, skipped=2
```

### Testing Architecture
- **`configureTestApp()` helper**: Applied to all tests for consistent flag propagation
- **Environment detection**: Tests automatically detect and adapt to cloud availability
- **Professional debugging**: Contextual debug messages with function names
- **Zero code changes**: All debug control via Xcode scheme settings

### Example Debug Output
```
DEBUG [testSyncStatusDisplay]: Initial sync enabled: true
DEBUG [testSyncStatusDisplay]: Found sync time: '3 days ago'
DEBUG [testSyncStatusDisplay]: Manual sync test completed - button correctly enabled with local test storage
```

## Project Structure

```
Rideshare Tracker/
├── Models/
│   ├── RideshareShift.swift          # Core shift data model with sync metadata
│   ├── ExpenseItem.swift             # Business expense data model with sync metadata
│   ├── ImageAttachment.swift         # Photo attachment model with file management
│   └── AppPreferences.swift          # User preferences, settings & sync configuration
├── Views/
│   ├── MainTabView.swift             # Main tab navigation (Shifts/Expenses)
│   ├── ContentView.swift             # Shifts dashboard
│   ├── StartShiftView.swift          # Begin shift recording
│   ├── EndShiftView.swift            # Complete shift recording
│   ├── EditShiftView.swift           # Modify existing shifts
│   ├── ShiftDetailView.swift         # View shift details
│   ├── ShiftRowView.swift            # Shift list item display
│   ├── ExpenseListView.swift         # Expenses dashboard with monthly filtering
│   ├── AddExpenseView.swift          # Add new business expenses
│   ├── EditExpenseView.swift         # Modify existing expenses
│   ├── ImageViewerView.swift         # Full-screen photo viewer with zoom/share
│   ├── PreferencesView.swift         # App settings
│   ├── IncrementalSyncView.swift     # Cloud sync settings and education
│   ├── MainMenuView.swift            # Settings menu with sync integration
│   ├── BackupRestoreView.swift       # Local backup/restore functionality
│   ├── ImportExportView.swift        # CSV export/import interface with toll import
│   ├── CalculatorPopupView.swift     # Scientific calculator with memory functions
│   └── AppInfoView.swift             # App information and credits
├── Managers/
│   ├── ShiftDataManager.swift        # Shift data persistence (singleton)
│   ├── ExpenseDataManager.swift      # Expense data persistence (singleton)
│   ├── ImageManager.swift            # Photo storage and file management (singleton)
│   ├── CloudSyncManager.swift        # iCloud sync operations & conflict resolution
│   └── SyncLifecycleManager.swift    # Automatic sync triggers on app lifecycle
├── Extensions/
│   ├── NumberFormatter+Extensions.swift # Currency input & formatting
│   └── DateFormatter+Extensions.swift   # Date/time formatting utilities
├── Assets.xcassets/
│   └── AppIcon.appiconset/           # App icons for all platforms
├── Rideshare TrackerTests/
│   └── Rideshare_TrackerTests.swift     # Unit tests for sync functionality & business logic
├── Rideshare TrackerUITests/
│   └── Rideshare_TrackerUITests.swift   # UI automated tests with debug utilities
└── UI_AUTOMATED_TESTING.md              # Comprehensive testing system documentation
```

## Key Features Explained

### Incremental Cloud Sync System

The app features enterprise-grade iCloud synchronization that provides seamless multi-device usage and ultimate data protection:

#### Core Capabilities
- **Real iCloud Integration**: Uses native FileManager with iCloud Documents container
- **Multi-Device Sync**: Seamless data sharing across iPhone, iPad, and Mac
- **Ultimate Data Protection**: Automatic cloud backup prevents data loss forever
- **Intelligent Conflict Resolution**: Last-modified-wins strategy handles concurrent edits
- **Automatic Operation**: Configurable sync frequency (Immediate, Hourly, Daily)
- **Manual Sync**: User-triggered sync with progress indication and status feedback

#### How It Works
1. **Initial Setup**: User enables sync from beautiful settings interface with clear benefits explanation
2. **Data Migration**: Existing user data automatically migrated with sync metadata
3. **Initial Sync**: All shifts, expenses, and preferences uploaded to iCloud Documents
4. **Ongoing Sync**: Changes automatically sync based on user's frequency preference
5. **Lifecycle Triggers**: Automatic sync on app background/foreground/termination events
6. **Conflict Resolution**: Concurrent edits across devices intelligently merged

#### Technical Architecture
- **CloudSyncManager**: Handles all iCloud operations with async/await patterns
- **SyncLifecycleManager**: Automatic sync triggers on app lifecycle events  
- **Sync Metadata**: All records include timestamps, deviceID, and deletion flags
- **File-Based Storage**: JSON files in iCloud Documents for reliability and debugging
- **Error Handling**: Comprehensive error types with clear user feedback

#### User Experience
- **Educational Interface**: Clear explanation of benefits and requirements
- **Progress Indication**: Real-time feedback during sync operations
- **Status Display**: Shows last sync time and iCloud location
- **Seamless Setup**: One-time configuration with automatic migration
- **Cross-Platform**: Consistent experience on iPhone, iPad, and Mac

#### Production Ready
- **25+ Tests**: Comprehensive unit and UI test coverage with 100% pass rate
- **Advanced Testing Infrastructure**: Professional UI automated testing system with debug utilities
- **Error Handling**: Robust error recovery and user feedback
- **Backward Compatibility**: Works with existing user data
- **Real iCloud APIs**: Production-grade integration that works on actual devices

### Automated Build Numbers
- Build numbers increment automatically for iPhone device builds
- Mac builds use the same number without incrementing
- Prevents version conflicts between platforms

### Date/Time Preferences
- User-selectable date formats (US, International, ISO, etc.)
- 12-hour vs 24-hour time display
- Timezone selection with live examples
- Consistent formatting across all views

### Universal Design
- Native SwiftUI interface adapts to each platform
- Custom macOS interface with proper window management
- iOS interface optimized for touch interaction

## Troubleshooting

### Build Script Issues
- Ensure "User Script Sandboxing" is disabled
- Check that script is first in Build Phases
- Verify `agvtool` permissions

### Platform Detection
- iPhone builds increment build number
- Mac deployment does not increment
- Check build logs for platform detection messages

## Development Notes

The app uses SwiftUI with singleton architecture and `@EnvironmentObject` for state management:

### State Management
- `ShiftDataManager.shared`: Singleton handling all shift data operations and persistence
- `ExpenseDataManager.shared`: Manages business expense data and monthly filtering
- `AppPreferences.shared`: Controls user settings, date/time formatting, CSV export, and sync preferences
- `CloudSyncManager.shared`: Handles all iCloud sync operations with async/await patterns
- `SyncLifecycleManager.shared`: Manages automatic sync triggers on app lifecycle events

### Navigation Architecture
- `MainTabView`: Top-level tab interface with Shifts and Expenses sections
- Consistent data sharing across all views via environment objects and singletons
- Platform-optimized interfaces for iPhone, iPad, and Mac
- `IncrementalSyncView`: Comprehensive sync settings with user education

### Sync Architecture
- **Dual Persistence**: UserDefaults for local storage + iCloud Documents for cloud sync
- **Metadata System**: All records include sync metadata (timestamps, deviceID, isDeleted)
- **Conflict Resolution**: Last-modified-wins strategy with device tracking
- **Lifecycle Integration**: Automatic sync triggers on app background/foreground/termination
- **Real iCloud APIs**: Production-grade FileManager integration with ubiquity container

### Development Patterns
- Singleton pattern for data managers with thread-safe access
- Async/await throughout sync operations with proper error handling
- Environment object injection for UI components
- Comprehensive test coverage for all sync functionality
- Global `debugPrint()` function available throughout codebase for conditional logging

All date/time formatting uses the user's preferences via `AppPreferences.formatDate()` and `AppPreferences.formatTime()` methods.

### Debug System Architecture
- **DebugUtilities.swift**: Global debug functions available throughout production code
- **Conditional Output**: Debug statements only output when `-debug` flag is enabled
- **File Context**: Debug output includes source file and function names for easy tracing
- **No Code Changes**: Debug behavior controlled entirely via Xcode scheme settings

## Photo Attachments System

The app features a comprehensive photo attachment system for expense documentation and record-keeping:

### Core Features
- **Photo Capture/Selection**: Use device camera or select from photo library
- **Multiple Photos**: Attach up to 5 photos per expense with horizontal scrolling preview
- **Automatic Processing**: Images automatically compressed and thumbnails generated
- **Local Storage**: Photos stored securely in app's Documents directory
- **Full-Screen Viewer**: Tap thumbnails to view full-screen with zoom, pan, and share capabilities
- **Photo Management**: Add, remove, and organize photos with visual feedback

### Technical Architecture
- **ImageManager**: Singleton utility handling all photo operations (save, load, delete, compress)
- **ImageAttachment**: Data model linking photos to expenses with metadata
- **Local File System**: Organized storage in Documents/Images/{expense-id}/ structure
- **PhotosUI Integration**: Native iOS photo picker with cross-platform compatibility
- **Memory Optimized**: Automatic image compression (2048px max) and thumbnail generation (150px)

### User Experience
- **Visual Previews**: Thumbnail images displayed in expense list for quick identification
- **Touch Interaction**: Tap to view full-screen, pinch to zoom, drag to pan
- **Share Integration**: Native share sheet for exporting photos
- **Deletion Feedback**: Visual confirmation and proper file cleanup
- **Progress Indicators**: Loading states during photo processing

### Storage & Performance
- **Efficient Storage**: JPEG compression (80% quality) balances quality and file size
- **Fast Loading**: Thumbnail caching for smooth list scrolling
- **Error Handling**: Graceful handling of photo loading failures with fallback UI
- **File Organization**: Hierarchical structure prevents conflicts and enables easy cleanup

## Expense Tracking System

The app includes a comprehensive business expense tracking system separate from shift-specific expenses:

### Expense Categories
- **Vehicle** 🚗: Car maintenance, insurance, rideshare-specific vehicle costs, car washes
- **Equipment** 🎒: Phone mounts, charging cables, insulated delivery bags, dashboard accessories  
- **Supplies** ❓: Cleaning supplies, safety equipment (first aid, tire inflator, jump pack), misc items
- **Amenities** 🍼: Passenger comfort items like bottled water, snacks, tissues, hand sanitizer

### Key Features
- **Monthly View**: Navigate by month with previous/next controls or date picker
- **Automatic Totals**: Month and year totals displayed prominently
- **Photo Attachments**: Attach receipt photos to expenses with full-screen viewing
- **Full CRUD Operations**: Add, view, edit, and delete expenses with photo management
- **Date Flexibility**: Set any date for expenses with calendar picker
- **Export Ready**: Separate CSV export for business expense records
- **Cross-Platform**: Consistent interface across iPhone, iPad, and Mac

### Usage Workflow
1. **Navigate to Expenses Tab**: Switch from Shifts to Expenses in the main tab bar
2. **Select Month**: Use arrow buttons or tap the month header to change time period
3. **Add Expenses**: Tap + button to add new business expenses
4. **Attach Photos**: Use "Add Receipt Photo" to capture or select images from your library
5. **Review Totals**: Month and year totals update automatically with photo indicators
6. **View Photos**: Tap photo thumbnails in expense list to view full-screen
7. **Edit/Delete**: Tap any expense to edit details and manage photos, or swipe to delete
8. **Export Data**: Use preferences to export expense data to CSV

## Scientific Calculator System

The app includes a built-in scientific calculator integrated into all currency and number input fields:

### Core Features
- **Calculator Button**: Appears on all currency/number input fields for instant access
- **Scientific Functions**: Basic arithmetic, parentheses, percentage, memory functions (M+, M-, MR, MC)
- **Calculation History**: Scrollable tape showing previous calculations and results
- **Expression Evaluation**: Enter complex math expressions like "45+23*2" and get instant results
- **Memory Persistence**: Calculator state persists across app sessions

### User Experience
- **Popup Interface**: Calculator opens as overlay without leaving current screen
- **Result Integration**: Tap "Done" to insert calculated result into the input field
- **Visual Feedback**: Animated button presses and calculation tape updates
- **Error Handling**: Clear error display for invalid expressions

### Technical Integration
- **CalculatorPopupView**: Full-featured calculator interface with professional styling
- **CalculatorTextField**: Enhanced input field with integrated calculator access
- **CurrencyTextField**: Currency-specific input with calculator integration
- **Expression Engine**: Robust math evaluation supporting complex expressions

## Toll Import System

The app supports importing toll transaction data from CSV files with automatic matching to existing shifts:

### Import Process
1. **Access Import**: Navigate to Settings → Import/Export → Import → Tolls
2. **Select CSV File**: Choose toll authority CSV export file
3. **Automatic Processing**: App parses Excel formulas and matches transactions to shifts by date/time
4. **Shift Updates**: Toll amounts automatically added to matching shifts
5. **Summary Images**: Toll summary images generated and attached to affected shifts

### Supported Formats
- **Excel Formula Dates**: Handles complex Excel date formulas from toll authority exports
- **Negative Amounts**: Converts negative toll amounts (e.g., "-$1.30") to positive values
- **Multiple Columns**: Flexible column detection for different toll authority formats
- **Real-World Data**: Tested with actual Austin toll authority CSV exports

### Technical Features
- **Time Window Matching**: Tolls matched to shifts based on transaction time falling within shift start/end times
- **Image Generation**: Creates professional 800px toll summary tables with transaction details
- **Error Handling**: Clear feedback for CSV format issues or parsing errors
- **Non-Destructive**: Original shift data preserved, only toll amounts updated

## Incremental Cloud Sync Workflow

The cloud sync system provides ultimate data protection and seamless multi-device usage:

### First-Time Setup
1. **Access Sync Settings**: Navigate to Settings → Incremental Cloud Sync
2. **Review Benefits**: Read about multi-device sync and data protection features
3. **Check Requirements**: Ensure iCloud account is signed in and iCloud Drive is enabled
4. **Enable Sync**: Toggle "Enable Incremental Cloud Sync" to start the process
5. **Initial Upload**: Confirm upload of all existing data (shifts, expenses, preferences)
6. **Configure Frequency**: Choose sync frequency (Immediate, Hourly, or Daily)

### Daily Usage
1. **Automatic Sync**: Data syncs automatically based on your frequency preference
2. **Background Sync**: Changes sync when you close or minimize the app
3. **Manual Sync**: Use "Sync Now" button for immediate synchronization
4. **Status Monitoring**: Check "Last Sync" time and sync location in settings
5. **Cross-Device**: Make changes on any device, see them on all others

### Multi-Device Scenario
1. **Install on Second Device**: Download and install app on iPad/Mac
2. **Enable Sync**: Navigate to sync settings and enable cloud sync
3. **Download Data**: All your existing data automatically appears
4. **Seamless Usage**: Start shift on iPhone, end on iPad, view reports on Mac
5. **Conflict Resolution**: Concurrent edits automatically merged using latest changes

### Data Protection
- **Never Lose Data**: Even if device is lost/destroyed, all data is safe in iCloud
- **Automatic Backup**: Every change is automatically backed up to the cloud
- **Device Recovery**: New device setup restores 100% of your data instantly
- **No Manual Export**: No need for manual backups or exports anymore

## CSV Export/Import

The app supports CSV export/import functionality for data analysis and sharing:

### CSV Export Features

#### Shift Data Export
- **Date Range Selection**: Export specific date ranges for shift data
- **User Preferences**: Date/time formats match your app preferences  
- **Comprehensive Data**: All shift details, earnings, expenses, and calculated values
- **Spreadsheet Ready**: Tank readings exported as decimal values (0.000-1.000) to prevent Excel date auto-conversion

#### Expense Data Export  
- **Separate Export**: Business expenses exported to dedicated CSV file
- **Date Range Filtering**: Select specific date ranges for expense export
- **Simple Format**: Date, Category, Description, Amount columns for easy analysis
- **Category Icons**: Preserved in export for easy identification

### CSV Column Organization
Columns are clearly identified with prefixes for easy recognition:

**Data Fields** (no prefix):
- Date/Time: StartDate, StartTime, EndDate, EndTime
- Mileage: StartMileage, EndMileage
- Fuel: StartTankReading, EndTankReading, HasFullTankAtStart, DidRefuelAtEnd, RefuelGallons, RefuelCost
- Earnings: Trips, NetFare, Tips, Promotions, RiderFees
- Expenses: Tolls, TollsReimbursed, ParkingFees, MiscFees

**Calculated Fields** (C_ prefix):
- C_ShiftMileage, C_ShiftDuration
- C_GasUsed, C_GasCost, C_MPG  
- C_Revenue, C_TaxableIncome
- C_ExpectedPayout, C_OutOfPocketCosts, C_CashFlowProfit, C_GrossProfit, C_ProfitPerHour
- C_TaxDeductibleExpense

**Preference Fields** (P_ prefix):
- P_TankCapacity, P_GasPrice, P_StandardMileageRate
- **Important**: Preference fields must have the same value in every row. The first row's values are used, and warnings are shown if inconsistent values are found in other rows.

### CSV Import Features
- **Flexible Parsing**: Handles multiple date/time formats
- **Tank Level Conversion**: Supports decimal values (0.000-1.000) rounded to nearest 1/8 increment
- **Merge or Replace**: Choose to merge with existing data or replace all shifts
- **Whitelist Import**: Only imports known data fields, ignores calculated columns and unknown columns
- **Optional Preferences**: Imports TankCapacity, GasPrice, StandardMileageRate if present in CSV
- **Preference Consistency**: Uses first row's preference values; shows warnings if other rows have different values
- **Custom Columns**: Users can add their own columns - they'll be safely ignored during import
- **Backward Compatibility**: Imports all preference field formats (P_TankCapacity, PREF_TankCapacity, or TankCapacity)
- **Error Handling**: Clear error messages for invalid file formats

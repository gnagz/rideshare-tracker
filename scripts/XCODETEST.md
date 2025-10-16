# xcodetest.command Documentation

**Location**: `~/.local/bin/xcodetest.command` (symlinked to project's `scripts/xcodetest.command`)

**Important**: This script must be run from the Xcode project root directory (the directory containing the `.xcodeproj` file).

## Overview

Automated test runner for Xcode projects with intelligent test targeting, exclusion, code coverage, and debug output. This script simplifies running tests by auto-discovering test targets and providing powerful filtering options.

## Features

### Core Capabilities
- ✅ **Auto-Discovery**: Automatically finds Xcode project, test targets, and test classes
- ✅ **Test Type Selection**: Run unit tests, UI tests, or both
- ✅ **Specific Test Targeting**: Run individual test functions or entire test classes
- ✅ **Test Exclusion**: Skip specific tests or entire test classes
- ✅ **Smart Test Matching**: Intelligently maps test names to correct class/function paths
- ✅ **Code Coverage**: Automatic coverage report with file-level breakdown (requires jq)
- ✅ **Coverage Control**: Optional `--skip-coverage` flag for faster test execution
- ✅ **Debug Logging**: Shows all DEBUG log lines from test output
- ✅ **Visual Debug Mode**: Enable UI test visual debugging
- ✅ **Dry Run**: Preview what tests would run without executing
- ✅ **xcpretty Integration**: Clean, formatted test output

### Test Output Features
- Real-time test output with xcpretty formatting
- Debug logs extracted and displayed after tests complete
- Code coverage summary by file
- Option to open detailed coverage in Xcode
- Exit codes properly propagate for CI/CD integration

## Command Line Options

### Basic Options
```bash
-u, --unit          # Run unit tests only
-g, --gui           # Run UI tests only
-a, --all           # Run both unit and UI tests
-h, --help          # Show help message
```

### Advanced Options
```bash
-t, --test <name>   # Run specific test function or class (can be repeated)
                    # Must be used with -u OR -g, not both

-x, --exclude <name> # Exclude specific test function or class (can be repeated)
                     # Cannot be used with -t (mutually exclusive)

--dryrun            # Show what would be tested without running
--visual-debug      # Enable UI_TEST_VISUAL_DEBUG environment variable
--debug             # Enable DEBUG environment variable for debug output
--skip-coverage     # Skip code coverage collection and reporting
```

## Usage Examples

### Basic Usage
```bash
# Navigate to project directory first
cd "/path/to/Rideshare Tracker"

# Run unit tests (default behavior)
xcodetest.command

# Run UI tests
xcodetest.command -g

# Run all tests (unit + UI)
xcodetest.command -a
```

### Running Specific Tests
```bash
# Run specific unit test function (exact match)
xcodetest.command -u -t testProfitCalculation

# Run specific UI test function (exact match)
xcodetest.command -g -t testStartShift

# Run tests with partial matching (finds all matching functions)
xcodetest.command -g -t shift     # Matches all test functions containing "shift"
xcodetest.command -g -t launch    # Matches testPerformanceAndLaunch

# Run multiple specific tests
xcodetest.command -g -t testStartShift -t testEndShift

# Run entire test class
xcodetest.command -g -t RideshareShiftTrackingUITests
```

### Excluding Tests
```bash
# Exclude entire test class from UI tests
xcodetest.command -g -x RideshareExpenseTrackingUITests

# Exclude specific test function
xcodetest.command -g -x testShiftWeekNavigation

# Exclude multiple tests
xcodetest.command -a -x testSlowTest1 -x testSlowTest2

# Exclude from all tests (defaults to -a when -x used alone)
xcodetest.command -x testFlakeyTest

# Combined: Run specific class but exclude one test
xcodetest.command -g -t RideshareShiftTrackingUITests -x testShiftWeekNavigation

# Combined: Run tests matching "shift" but exclude one
xcodetest.command -g -t shift -x testShiftWeekNavigation
```

### Debug and Preview
```bash
# Dry run to see what would execute
xcodetest.command --dryrun -a

# Run with visual debugging enabled
xcodetest.command -g -t testShiftPhotoViewerIntegration --visual-debug

# Run with debug output
xcodetest.command -g -t testShiftPhotoViewerIntegration --debug

# Run with both visual debug and debug output
xcodetest.command -g -t testShiftPhotoViewerIntegration --visual-debug --debug

# Run without code coverage (faster execution)
xcodetest.command -a --skip-coverage

# Quick test run without coverage reporting
xcodetest.command -g -t testStartShift --skip-coverage
```

## Tab Completion Setup

Enable tab completion for command-line options to speed up usage.

### For zsh (macOS default shell)

**1. The completion script has already been created at:**
```
~/.zsh/completions/_xcodetest.command
```

**2. The following has been added to `~/.zshrc`:**
```zsh
# Enable command completion
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

**3. Reload your shell configuration:**
```bash
source ~/.zshrc
# Or simply use the alias:
reload
```

### For bash users

If you're using bash instead of zsh:

**1. Install bash-completion via Homebrew:**
```bash
brew install bash-completion@2
```

**2. The completion script has been created at:**
```
~/.local/share/bash-completion/completions/xcodetest.command
```

**3. Add to `~/.bash_profile` or `~/.bashrc`:**
```bash
# Enable bash completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
fi
```

**4. Reload:**
```bash
source ~/.bash_profile
```

### Testing Tab Completion

After setup, test that it works:
```bash
xcodetest.command --<TAB>
# Should show: --all --debug --dryrun --exclude --gui --help --skip-coverage --test --unit --visual-debug

xcodetest.command -<TAB>
# Should show: -a -g -h -t -u -x
```

### Completion Features
- Completes all long-form options (`--unit`, `--gui`, etc.)
- Completes all short-form options (`-u`, `-g`, etc.)
- Recognizes options that require arguments (`-t`, `-x`) and stops completing after them
- Works with partial matches (type `--sk<TAB>` to complete `--skip-coverage`)

## How It Works

### 1. Project Discovery
The script automatically discovers:
- Xcode project file (*.xcodeproj)
- Project name from project file
- Test targets (separate discovery for unit tests and UI tests)
- Test class names by searching for *Tests.swift and *UITests.swift files

### 2. Test Matching Logic
The `find_matching_tests()` function intelligently maps test names with partial matching support:

**Step 1: Exact Function Match**
- Searches for exact function name match (e.g., `testStartShift`)
- Returns `TestTarget/ClassName/testFunctionName` format
- Example: `testStartShift` → `Rideshare TrackerUITests/RideshareShiftTrackingUITests/testStartShift`

**Step 2: Partial Function Match** (if no exact match)
- Case-insensitive partial match on function names
- Returns ALL matching test functions
- Example: `shift` → matches `testShiftWeekNavigation`, `testShiftDetailAndNavigation`, `testStartShiftFormValidation`, `testEndShiftFormValidation`, `testEditShiftFormValidation`

**Step 3: Class Match** (only if no function matches)
- Partial match on class names
- Returns `TestTarget/ClassName` format to run entire class
- Example: `RideshareShiftTrackingUITests` → `Rideshare TrackerUITests/RideshareShiftTrackingUITests`

### 3. xcodebuild Command Construction
The script builds an xcodebuild command with:
- Scheme: Auto-detected from project name
- Destination: iOS Simulator (iPhone 15 Pro iOS 18.6, arm64)
- Parallel testing: Disabled (`-parallel-testing-enabled NO`)
- Code coverage: Enabled (`-enableCodeCoverage YES`)
- Test targeting: Multiple `-only-testing` or `-skip-testing` flags

### 4. Output Processing
- Pipes output through `xcpretty` for clean formatting
- Also saves to temp log file for post-processing
- Extracts DEBUG lines after tests complete
- Generates code coverage report from .xcresult bundle

## Code Coverage

### Requirements
- **jq**: Install with `brew install jq` for full coverage parsing
- Coverage must be enabled in Xcode scheme settings

### Coverage Output
When coverage is available, the script shows:
- Overall app coverage percentage
- Per-file coverage percentages (sorted by coverage)
- Option to open detailed results in Xcode

### Enabling Coverage in Xcode
1. Product → Scheme → Edit Scheme
2. Test tab → Options
3. Enable "Gather coverage for some targets"
4. Select your app target

## Environment Variables

The script can set environment variables for test execution:

### UI_TEST_VISUAL_DEBUG
Enable with `--visual-debug` flag. Used by UI tests to enable visual debugging features (longer pauses, screenshot captures, etc.)

### DEBUG
Enable with `--debug` flag. Used by tests to enable verbose debug logging.

## Known Issues & Limitations

### Current Known Issues
*(To be documented as issues are discovered)*

### Limitations
1. **Must Run from Project Directory**: Script requires being run from the Xcode project root directory (where .xcodeproj is located)
2. **Test Target Ambiguity**: When using `-t` with function names, the script attempts smart matching but may not always choose the correct test class if multiple classes have similar test names
3. **Single Destination**: Currently hardcoded to iPhone 15 Pro iOS 18.6 simulator
4. **No Retry Logic**: Failed tests are not automatically retried
5. **xcpretty Required**: Script assumes xcpretty is installed for formatted output

## Troubleshooting

### "No tests were executed"
**Symptom**: Script reports success but shows "No tests were executed"

**Common Causes**:
- Test target path is incorrect
- Test name misspelled
- Test class doesn't match expected pattern

**Solutions**:
1. Use `--dryrun` to verify test target paths
2. Check test names with `grep -r "func test" "Rideshare TrackerUITests/"`
3. Verify test class names match Swift file names

### "No Xcode project found"
**Symptom**: Script fails to find project

**Solutions**:
1. Navigate to your Xcode project root directory (where .xcodeproj is located)
2. Run the script from that directory:
   ```bash
   cd "/path/to/Rideshare Tracker"
   xcodetest.command -a
   ```

### Code Coverage Not Showing
**Symptom**: "No coverage data found" or coverage section shows errors

**Solutions**:
1. Ensure coverage is enabled in Xcode scheme (see "Enabling Coverage in Xcode" above)
2. Install jq: `brew install jq`
3. Check that tests actually ran successfully
4. If you used `--skip-coverage`, the coverage report is intentionally disabled

### Tests Take Too Long
**Symptom**: UI tests timeout or take excessively long

**Considerations**:
- UI tests include visual pauses for debugging (5s delays)
- Photo workflow tests include multiple visual pauses
- Calculator field clearing uses 20 arrow keys + 20 deletes (can add time)
- Code coverage collection adds overhead to test execution
- Consider using `-x` to exclude long-running tests during development
- Use `--skip-coverage` to disable coverage collection for faster test runs

## Maintenance Notes

### File Structure
```
~/.local/bin/xcodetest.command
├── Argument Parsing (lines 16-88)
├── Project Discovery (lines 124-143)
├── Test Target Discovery (lines 147-208)
├── Test Matching Logic (lines 227-279)
├── Test Execution (lines 281-467)
├── Debug Log Display (lines 469-474)
├── Coverage Report (lines 476-556)
└── Cleanup & Summary (lines 558-577)
```

### Key Functions
- `find_matching_tests()`: Maps test names to xcodebuild target paths with partial matching support
  - Step 1: Exact match on function names
  - Step 2: Case-insensitive partial match on function names (returns ALL matches)
  - Step 3: Partial match on class names (only if no function matches)
  - Returns array of properly formatted target strings via stdout
  - Bash 3.2 compatible (uses temp files instead of process substitution)

### Configuration Variables
```bash
# Project Directory: Detected from current working directory (must contain .xcodeproj)
# Destination: iPhone 15 Pro iOS 18.6, arm64
# Parallel Testing: Disabled
# Code Coverage: Enabled by default (use --skip-coverage to disable)
```

## Version History

### Version 2025-10-16
- **`--skip-coverage` flag**: Skip code coverage collection and reporting for faster test execution
- **Conditional coverage**: Coverage can now be disabled via command line flag instead of being always-on
- **Performance improvement**: Tests run faster when coverage is not needed
- **Security improvement**: Removed hardcoded home directory path; script now requires running from project directory
- **Tab completion**: Added zsh and bash completion support for all command-line options

### Version 2025-10-13
- **Combined `-t` and `-x` support**: Can now use inclusion and exclusion together for fine-grained test control
- **Partial test name matching**: Supports case-insensitive partial matching on test function names
- **Multiple `-only-testing` flags**: Executes all tests matching partial criteria
- **Function matching prioritized**: Test functions matched before test classes
- **Error output to stderr**: Validation errors don't interfere with match capture
- **Bash 3.2 compatibility**: Uses temp files instead of process substitution

### Version 2025-10-12
- Initial documentation created
- Added test validation to prevent "0 tests executed" false positives
- Script functional with all core features
- Known issue: Calculator field clearing can slow down UI tests (20 arrows + 20 deletes)

---

## Recent Fixes

### 2025-10-13 - Combined `-t` and `-x` Support
**Issue**: Could not use `-t` (include) and `-x` (exclude) together, limiting flexibility for running specific test classes with exclusions
**Fix**: Removed mutual exclusivity restriction and added support for combining `-t` with `-x`
**Behavior**:
- Can now specify test class/function with `-t` and exclude specific tests with `-x`
- Example: `xcodetest.command -g -t RideshareShiftTrackingUITests -x testShiftWeekNavigation`
  - Runs all tests in `RideshareShiftTrackingUITests` class
  - Excludes `testShiftWeekNavigation` from that class
- xcodebuild receives both `-only-testing` (for inclusion) and `-skip-testing` (for exclusion)
- Partial matching works with both `-t` and `-x`
**Impact**: Provides fine-grained control over test execution, useful for debugging specific test combinations

### 2025-10-13 - Partial Test Name Matching
**Issue**: Partial test names (like "launch" or "shift") would result in "0 tests executed" being reported as success
**Fix**: Replaced `validate_test_exists()` with `find_matching_tests()` function that supports partial matching
**Behavior**:
- **Exact Match**: Tries exact function name match first (e.g., `testStartShift`)
- **Partial Function Match**: Falls back to case-insensitive partial match on function names (e.g., `shift` matches `testStartShiftFormValidation`, `testEndShiftFormValidation`, etc.)
- **Class Match**: Only if NO function matches found, tries partial match on class names
- **Multiple Matches**: Constructs multiple `-only-testing` flags, one for each match
- **User Feedback**: Shows user exactly what matches were found before executing
**Examples**:
- `xcodetest.command -g -t launch` → finds `testPerformanceAndLaunch`
- `xcodetest.command -g -t shift` → finds 5 tests: `testShiftWeekNavigation`, `testShiftDetailAndNavigation`, `testStartShiftFormValidation`, `testEndShiftFormValidation`, `testEditShiftFormValidation`
- `xcodetest.command -g -t shift` → does NOT match `RideshareShiftTrackingUITests` class (function matches take priority)
**Impact**: Significant time savings when running related tests, no need to type full test names

### 2025-10-12 - Test Validation Added
**Issue**: Script would execute xcodebuild with invalid test names, resulting in "0 tests executed" being reported as success
**Fix**: Added `validate_test_exists()` function that searches Swift test files for test function/class names before executing
**Behavior**:
- Script now fails immediately with clear error if test name not found
- Shows list of available tests when validation fails
- Validates ALL specified tests before running ANY tests
**Impact**: Prevents wasted time waiting for xcodebuild to compile/run when test names are wrong

---

## TODO: Document Issues as Discovered

Please document any issues you encounter below this line, and we'll update the appropriate sections above.

### Issue Log

#### [Date] - Issue Title
**Description**:
**Impact**:
**Workaround**:
**Status**:

---

*Last Updated: 2025-10-13*

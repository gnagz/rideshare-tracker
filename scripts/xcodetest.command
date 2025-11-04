#!/bin/bash

# Exit on any failure in the pipe
set -o pipefail

# Initialize variables
RUN_UNIT=false
RUN_GUI=false
SPECIFIC_TESTS=()
EXCLUDE_TESTS=()
DRY_RUN=false
VISUAL_DEBUG=false
DEBUG_MODE=false
SKIP_COVERAGE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--unit)
            RUN_UNIT=true
            shift
            ;;
        -g|--gui)
            RUN_GUI=true
            shift
            ;;
        -a|--all)
            RUN_UNIT=true
            RUN_GUI=true
            shift
            ;;
        -t|--test)
            SPECIFIC_TESTS+=("$2")
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_TESTS+=("$2")
            shift 2
            ;;
        --dryrun)
            DRY_RUN=true
            shift
            ;;
        --visual-debug)
            VISUAL_DEBUG=true
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --skip-coverage)
            SKIP_COVERAGE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -u, --unit          Run unit tests only"
            echo "  -g, --gui           Run UI tests only"
            echo "  -a, --all           Run both unit and UI tests"
            echo "  -t, --test <name>   Run specific test function or class (can be repeated)"
            echo "                      Must be used with -u OR -g, not both"
            echo "                      Can be combined with -x to exclude specific tests from -t scope"
            echo "  -x, --exclude <name> Exclude specific test function or class (can be repeated)"
            echo "                      Can be used alone or with -t to narrow the scope"
            echo "  --dryrun            Show what would be tested without running"
            echo "  --visual-debug      Enable UI_TEST_VISUAL_DEBUG environment variable"
            echo "  --debug             Enable DEBUG environment variable for debug output"
            echo "  --skip-coverage     Skip code coverage collection and reporting"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Run unit tests (default)"
            echo "  $0 -g                        # Run UI tests"
            echo "  $0 -a                        # Run all tests"
            echo "  $0 -u -t testProfitCalculation"
            echo "  $0 -g -t testStartShift"
            echo "  $0 -g -x RideshareExpenseTrackingUITests  # Exclude entire class"
            echo "  $0 -g -x testShiftPhotoWorkflow          # Exclude specific function"
            echo "  $0 -g -t RideshareShiftTrackingUITests -x testShiftPhotoWorkflow  # Run class, exclude one test"
            echo "  $0 --dryrun -a               # Show what all tests would run"
            echo "  $0 -g -t testShiftPhotoViewerIntegration --visual-debug"
            echo "  $0 -g -t testShiftPhotoViewerIntegration --debug"
            echo "  $0 -g -t testShiftPhotoViewerIntegration --visual-debug --debug"
            echo "  $0 -a --skip-coverage        # Run all tests without coverage"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Default to unit tests if no flags specified
if [[ $RUN_UNIT == false && $RUN_GUI == false && ${#SPECIFIC_TESTS[@]} -eq 0 ]]; then
    RUN_UNIT=true
fi

# Validate -t and -x usage
if [[ ${#SPECIFIC_TESTS[@]} -gt 0 ]]; then
    # -t is being used
    if [[ $RUN_UNIT == true && $RUN_GUI == true ]]; then
        echo "❌ Error: Cannot use -t with both -u and -g (ambiguous target)"
        echo "Use -t with either -u OR -g to specify which test target"
        exit 1
    fi
    if [[ $RUN_UNIT == false && $RUN_GUI == false ]]; then
        echo "❌ Error: Must specify -u or -g when using -t"
        echo "Use -t with either -u (unit tests) or -g (UI tests)"
        exit 1
    fi

    # If -x is also being used with -t, ensure it's for the same test type
    if [[ ${#EXCLUDE_TESTS[@]} -gt 0 ]]; then
        echo "💡 Using -t and -x together: will include specified tests and exclude specific functions"
    fi
fi

if [[ ${#EXCLUDE_TESTS[@]} -gt 0 ]]; then
    if [[ $RUN_UNIT == false && $RUN_GUI == false ]]; then
        # Default to all tests when excluding (most common use case)
        RUN_UNIT=true
        RUN_GUI=true
        echo "💡 Using -x without specifying test type, excluding from all tests"
    fi
fi

# Require script to be run from project directory
shopt -s nullglob
xcodeproj_dirs=( *.xcodeproj )
if [[ ${#xcodeproj_dirs[@]} -gt 0 ]]; then
    echo "📍 Detected Xcode project in current directory: $(pwd)"
    PROJECT_DIR="$(pwd)"
else
    echo "❌ No Xcode project found in current directory"
    echo "💡 This script must be run from the Xcode project root directory"
    echo "   (the directory containing the .xcodeproj file)"
    exit 1
fi

# Discover project name and test targets
PROJECT_FILE=$(find "$PROJECT_DIR" -name "*.xcodeproj" -type d | head -1)
if [[ -z "$PROJECT_FILE" ]]; then
    echo "❌ No Xcode project found in $PROJECT_DIR"
    exit 1
fi

PROJECT_NAME=$(basename "$PROJECT_FILE" .xcodeproj)
SCHEME_NAME="$PROJECT_NAME"
echo "🔍 Found project: $PROJECT_NAME"

# Discover test targets
UNIT_TARGET=""
UNIT_TARGET_DIR_FULL=""
GUI_TARGET=""

# Look for unit tests (not UITests) - handle spaces properly
while IFS= read -r test_dir; do
    if [[ -n "$test_dir" && ! "$test_dir" =~ UITests ]]; then
        UNIT_TARGET_DIR=$(basename "$test_dir")

        # Discover actual test class names by searching for Swift test files
        UNIT_TEST_CLASSES=()
        while IFS= read -r swift_file; do
            if [[ -n "$swift_file" ]]; then
                # Extract class name from Swift file
                class_name=$(basename "$swift_file" .swift)
                UNIT_TEST_CLASSES+=("$class_name")
            fi
        done <<< "$(find "$test_dir" -name "*Tests.swift" -type f)"

        if [[ ${#UNIT_TEST_CLASSES[@]} -gt 0 ]]; then
            # Store both the full target directory and specific test class target
            UNIT_TARGET_DIR_FULL="$UNIT_TARGET_DIR"
            UNIT_TARGET="$UNIT_TARGET_DIR/${UNIT_TEST_CLASSES[0]}"
            echo "🧪 Found unit test target: $UNIT_TARGET_DIR_FULL (for full suite) / $UNIT_TARGET (for specific tests)"
            echo "🔍 Discovered unit test classes: ${UNIT_TEST_CLASSES[*]}"
        else
            echo "❌ No unit test classes found in $UNIT_TARGET_DIR"
        fi
        break
    fi
done <<< "$(find "$PROJECT_DIR" -name "*Tests" -type d -print0 | tr '\0' '\n')"

# Look for UI tests - handle spaces properly
while IFS= read -r test_dir; do
    if [[ -n "$test_dir" && "$test_dir" =~ UITests ]]; then
        GUI_TARGET_DIR=$(basename "$test_dir")

        # Discover actual UI test class names by searching for Swift test files
        GUI_TEST_CLASSES=()
        while IFS= read -r swift_file; do
            if [[ -n "$swift_file" ]]; then
            # Extract class name from Swift file
            class_name=$(basename "$swift_file" .swift)
            GUI_TEST_CLASSES+=("$class_name")
            fi        done <<< "$(find "$test_dir" -name "*UITests.swift" -type f)"

        if [[ ${#GUI_TEST_CLASSES[@]} -gt 0 ]]; then
            # Include all discovered test classes for consolidated test suite
            GUI_FULL_TARGETS=()
            for class_name in "${GUI_TEST_CLASSES[@]}"; do
                GUI_FULL_TARGETS+=("$GUI_TARGET_DIR/$class_name")
            done
            GUI_FULL_TARGET="${GUI_FULL_TARGETS[0]}" # Keep backward compatibility for single target usage
            echo "🖱️  Found UI test targets: ${GUI_FULL_TARGETS[*]}"
            echo "🔍 Discovered UI test classes: ${GUI_TEST_CLASSES[*]}"
        else
            echo "❌ No UI test classes found in $GUI_TARGET_DIR"
        fi
        break
    fi
done <<< "$(find "$PROJECT_DIR" -name "*UITests" -type d -print0 | tr '\0' '\n')"

# Validate that we found the required targets
if [[ $RUN_UNIT == true && -z "$UNIT_TARGET" ]]; then
    echo "❌ Unit tests requested but no unit test target found"
    exit 1
fi

if [[ $RUN_GUI == true && -z "$GUI_FULL_TARGET" ]]; then
    echo "❌ UI tests requested but no UI test target found"
    exit 1
fi

# Define a temporary log file (skip for dry run)
if [[ $DRY_RUN == false ]]; then
    LOG_FILE=$(mktemp)
    echo "📝 Log file: $LOG_FILE"
fi

# Function to determine if a test name refers to a class or function
# and build the appropriate test target path
determine_test_target() {
    local test_name="$1"
    local base_target="$2"  # e.g., "Rideshare TrackerUITests/RideshareExpenseTrackingUITests"
    local available_classes=("${@:3}")  # Remaining arguments are available classes

    # Check if test_name is actually a class name
    for class_name in "${available_classes[@]}"; do
        if [[ "$test_name" == "$class_name" ]]; then
            # It's a class - return TestTarget/ClassName format
            local target_dir=$(dirname "$base_target")
            echo "$target_dir/$class_name"
            return 0
        fi
    done

    # Check if test_name contains a class name (for function matching)
    local matched_class=""
    for class_name in "${available_classes[@]}"; do
        # Check if class name is in the test name or if test name matches class patterns
        if [[ "$test_name" == *"$class_name"* ]] || \
           [[ "$test_name" == *"Shift"* && "$class_name" == *"Shift"* ]] || \
           [[ "$test_name" == *"Expense"* && "$class_name" == *"Expense"* ]] || \
           [[ "$test_name" == *"Sync"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Export"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Settings"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Preferences"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Navigation"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Accessibility"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Performance"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Utility"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"EdgeCases"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"DateRange"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"DatePicker"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Backup"* && "$class_name" == *"Tools"* ]] || \
           [[ "$test_name" == *"Gestures"* && "$class_name" == *"Tools"* ]]; then
            matched_class="$class_name"
            break
        fi
    done

    # If we found a matching class, return TestTarget/ClassName/testFunctionName format
    if [[ -n "$matched_class" ]]; then
        local target_dir=$(dirname "$base_target")
        echo "$target_dir/$matched_class/$test_name"
    else
        # Fallback to first available class for function names
        local target_dir=$(dirname "$base_target")
        local first_class=$(basename "$base_target")
        echo "$target_dir/$first_class/$test_name"
    fi
}

# Function to find matching tests (supports partial matching)
# Returns array of full test paths for all matches
find_matching_tests() {
    local test_name="$1"
    local test_dir="$2"
    local test_type="$3"  # "unit" or "UI"
    local available_classes=("${@:4}")  # Remaining arguments are available classes
    local base_target=""

    # Determine base target from test_type
    if [[ "$test_type" == "unit" ]]; then
        base_target="$UNIT_TARGET"
    else
        base_target="$GUI_FULL_TARGET"
    fi

    # Array to store matches
    local -a matches=()

    # Step 1: Try exact match on function name
    local exact_func_matches=$(find "$test_dir" -name "*.swift" -type f -exec grep -l "func ${test_name}(" {} \; 2>/dev/null)

    if [[ -n "$exact_func_matches" ]]; then
        # Found exact function match - determine which class it's in
        for class_name in "${available_classes[@]}"; do
            local class_file=$(find "$test_dir" -name "${class_name}.swift" -type f 2>/dev/null)
            if [[ -n "$class_file" ]] && grep -q "func ${test_name}(" "$class_file" 2>/dev/null; then
                local target_dir=$(dirname "$base_target")
                matches+=("$target_dir/$class_name/$test_name")
            fi
        done
    fi

    # Step 2: If no exact function match, try partial match on function names
    if [[ ${#matches[@]} -eq 0 ]]; then
        for class_name in "${available_classes[@]}"; do
            local class_file=$(find "$test_dir" -name "${class_name}.swift" -type f 2>/dev/null)
            if [[ -n "$class_file" ]]; then
                # Find all test functions that contain the search term
                local partial_funcs=$(grep -o "func test[^(]*" "$class_file" 2>/dev/null | \
                    sed 's/func //' | \
                    grep -i "$test_name")

                if [[ -n "$partial_funcs" ]]; then
                    while IFS= read -r func_name; do
                        if [[ -n "$func_name" ]]; then
                            local target_dir=$(dirname "$base_target")
                            matches+=("$target_dir/$class_name/$func_name")
                        fi
                    done <<< "$partial_funcs"
                fi
            fi
        done
    fi

    # Step 3: If still no matches, try partial match on class names
    if [[ ${#matches[@]} -eq 0 ]]; then
        for class_name in "${available_classes[@]}"; do
            if [[ "$class_name" =~ .*${test_name}.* ]] || [[ "$class_name" =~ ${test_name} ]]; then
                local target_dir=$(dirname "$base_target")
                matches+=("$target_dir/$class_name")
            fi
        done
    fi

    # Return matches via global array (bash doesn't have great array return support)
    if [[ ${#matches[@]} -gt 0 ]]; then
        # Export matches for caller
        printf '%s\n' "${matches[@]}"
        return 0
    else
        # Output error messages to stderr so they don't get captured as matches
        echo "❌ Error: Could not find any ${test_type} tests matching '${test_name}'" >&2
        echo "💡 Available tests in $(basename "$test_dir"):" >&2

        # Show available test functions and classes
        find "$test_dir" -name "*.swift" -type f -exec grep -h "^\s*func test\|^\s*class.*Tests" {} \; 2>/dev/null | \
            sed 's/^[[:space:]]*//' | \
            sed 's/func \(test[^(]*\).*/  • \1/' | \
            sed 's/class \([^:]*\).*/  • \1/' | \
            sort -u | head -20 >&2

        return 1  # No matches found
    fi
}

# Main execution logic
OVERALL_EXIT_CODE=0

# Build array of test targets to run and exclude
TEST_TARGETS=()
EXCLUDE_TARGETS=()

if [[ ${#SPECIFIC_TESTS[@]} -gt 0 ]]; then
    # Handle specific tests with partial matching support
    if [[ $RUN_UNIT == true ]]; then
        VALIDATION_FAILED=false

        # Find matches for each test name
        for test_name in "${SPECIFIC_TESTS[@]}"; do
            echo "🔍 Searching for unit tests matching: '$test_name'"

            # Get matches from find_matching_tests function (bash 3.2 compatible using temp file)
            tmp_matches=$(mktemp)
            find_matching_tests "$test_name" "$(dirname "$PROJECT_FILE")/$UNIT_TARGET_DIR_FULL" "unit" "${UNIT_TEST_CLASSES[@]}" > "$tmp_matches"

            matched_tests=()
            while IFS= read -r match; do
                if [[ -n "$match" ]]; then
                    matched_tests+=("$match")
                fi
            done < "$tmp_matches"
            rm -f "$tmp_matches"

            if [[ ${#matched_tests[@]} -eq 0 ]]; then
                VALIDATION_FAILED=true
            else
                # Add all matches to TEST_TARGETS
                for match in "${matched_tests[@]}"; do
                    TEST_TARGETS+=("$match")
                done

                if [[ ${#matched_tests[@]} -eq 1 ]]; then
                    echo "   ✓ Found 1 match: ${matched_tests[0]##*/}"
                else
                    echo "   ✓ Found ${#matched_tests[@]} matches:"
                    for match in "${matched_tests[@]}"; do
                        echo "     • ${match##*/}"
                    done
                fi
            fi
        done

        if [[ $VALIDATION_FAILED == true ]]; then
            echo ""
            echo "❌ Test validation failed - no tests will be executed"
            exit 1
        fi

        echo "🎯 Will execute ${#TEST_TARGETS[@]} unit test(s)"

        # Handle excludes when using -t (specific tests with exclusions)
        if [[ ${#EXCLUDE_TESTS[@]} -gt 0 ]]; then
            echo "🚫 Processing exclude requests: ${EXCLUDE_TESTS[*]}"
            for exclude_name in "${EXCLUDE_TESTS[@]}"; do
                tmp_matches=$(mktemp)
                find_matching_tests "$exclude_name" "$(dirname "$PROJECT_FILE")/$UNIT_TARGET_DIR_FULL" "unit" "${UNIT_TEST_CLASSES[@]}" > "$tmp_matches"

                while IFS= read -r match; do
                    if [[ -n "$match" ]]; then
                        EXCLUDE_TARGETS+=("$match")
                    fi
                done < "$tmp_matches"
                rm -f "$tmp_matches"
            done

            if [[ ${#EXCLUDE_TARGETS[@]} -gt 0 ]]; then
                echo "🚫 Will exclude: ${EXCLUDE_TARGETS[*]}"
            fi
        fi

    elif [[ $RUN_GUI == true ]]; then
        VALIDATION_FAILED=false
        GUI_TARGET_DIR_PATH=$(dirname "$PROJECT_FILE")/$(dirname "$GUI_FULL_TARGET")

        # Find matches for each test name
        for test_name in "${SPECIFIC_TESTS[@]}"; do
            echo "🔍 Searching for UI tests matching: '$test_name'"

            # Get matches from find_matching_tests function (bash 3.2 compatible using temp file)
            tmp_matches=$(mktemp)
            find_matching_tests "$test_name" "$GUI_TARGET_DIR_PATH" "UI" "${GUI_TEST_CLASSES[@]}" > "$tmp_matches"

            matched_tests=()
            while IFS= read -r match; do
                if [[ -n "$match" ]]; then
                    matched_tests+=("$match")
                fi
            done < "$tmp_matches"
            rm -f "$tmp_matches"

            if [[ ${#matched_tests[@]} -eq 0 ]]; then
                VALIDATION_FAILED=true
            else
                # Add all matches to TEST_TARGETS
                for match in "${matched_tests[@]}"; do
                    TEST_TARGETS+=("$match")
                done

                if [[ ${#matched_tests[@]} -eq 1 ]]; then
                    echo "   ✓ Found 1 match: ${matched_tests[0]##*/}"
                else
                    echo "   ✓ Found ${#matched_tests[@]} matches:"
                    for match in "${matched_tests[@]}"; do
                        echo "     • ${match##*/}"
                    done
                fi
            fi
        done

        if [[ $VALIDATION_FAILED == true ]]; then
            echo ""
            echo "❌ Test validation failed - no tests will be executed"
            exit 1
        fi

        echo "🎯 Will execute ${#TEST_TARGETS[@]} UI test(s)"

        # Handle excludes when using -t (specific tests with exclusions)
        if [[ ${#EXCLUDE_TESTS[@]} -gt 0 ]]; then
            echo "🚫 Processing exclude requests: ${EXCLUDE_TESTS[*]}"
            for exclude_name in "${EXCLUDE_TESTS[@]}"; do
                tmp_matches=$(mktemp)
                find_matching_tests "$exclude_name" "$GUI_TARGET_DIR_PATH" "UI" "${GUI_TEST_CLASSES[@]}" > "$tmp_matches"

                while IFS= read -r match; do
                    if [[ -n "$match" ]]; then
                        EXCLUDE_TARGETS+=("$match")
                    fi
                done < "$tmp_matches"
                rm -f "$tmp_matches"
            done

            if [[ ${#EXCLUDE_TARGETS[@]} -gt 0 ]]; then
                echo "🚫 Will exclude: ${EXCLUDE_TARGETS[*]}"
            fi
        fi
    fi
else
    # Handle full test suites (with optional excludes)
    if [[ $RUN_UNIT == true ]]; then
        # For unit tests, use the target directory to run all unit test classes
        TEST_TARGETS+=("$UNIT_TARGET_DIR_FULL")
        echo "🧪 Including unit tests: $UNIT_TARGET_DIR_FULL"
    fi

    if [[ $RUN_GUI == true ]]; then
        if [[ ${#GUI_FULL_TARGETS[@]} -gt 0 ]]; then
            # Include all consolidated test classes
            for target in "${GUI_FULL_TARGETS[@]}"; do
                TEST_TARGETS+=("$target")
            done
            echo "🖱️  Including all UI test classes: ${GUI_FULL_TARGETS[*]}"
        else
            # Fallback to single target for backward compatibility
            TEST_TARGETS+=("$GUI_FULL_TARGET")
            echo "🖱️  Including UI tests: $GUI_FULL_TARGET"
        fi
    fi

    # Handle excludes by building exclude targets for -skip-testing
    if [[ ${#EXCLUDE_TESTS[@]} -gt 0 ]]; then
        echo "🚫 Processing exclude requests: ${EXCLUDE_TESTS[*]}"

        # Process unit test excludes
        if [[ $RUN_UNIT == true ]]; then
            for exclude_name in "${EXCLUDE_TESTS[@]}"; do
                target=$(determine_test_target "$exclude_name" "$UNIT_TARGET" "${UNIT_TEST_CLASSES[@]}")
                EXCLUDE_TARGETS+=("$target")
            done
        fi

        # Process UI test excludes
        if [[ $RUN_GUI == true ]]; then
            for exclude_name in "${EXCLUDE_TESTS[@]}"; do
                target=$(determine_test_target "$exclude_name" "$GUI_FULL_TARGET" "${GUI_TEST_CLASSES[@]}")
                EXCLUDE_TARGETS+=("$target")
            done
        fi

        if [[ ${#EXCLUDE_TARGETS[@]} -gt 0 ]]; then
            echo "🚫 Will exclude: ${EXCLUDE_TARGETS[*]}"
        fi
    fi
fi

# Build and run single xcodebuild command with multiple -only-testing
if [[ ${#TEST_TARGETS[@]} -gt 0 ]]; then
    echo ""

    if [[ $DRY_RUN == true ]]; then
        echo "🔍 DRY RUN: Would execute the following test command:"
    else
        echo "🚀 Running tests..."
    fi

    # Build xcodebuild command with multiple -only-testing parameters
    # Build environment variables array
    env_vars=()
    if [[ $VISUAL_DEBUG == true ]]; then
        env_vars+=(VISUAL_DEBUG=1)
    fi
    if [[ $DEBUG_MODE == true ]]; then
        env_vars+=(DEBUG=1)
        SCHEME_NAME="Debug Text & Visual Pauses"
    fi

    # Build command with optional environment variables and coverage setting
    if [[ ${#env_vars[@]} -gt 0 ]]; then
        cmd=(
            env "${env_vars[@]}"
            xcodebuild test
            -scheme "$SCHEME_NAME"
            -destination "platform=iOS Simulator,arch=arm64,OS=18.6,name=iPhone 15 Pro iOS 18.6"
            -parallel-testing-enabled NO
        )
    else
        cmd=(
            xcodebuild test
            -scheme "$SCHEME_NAME"
            -destination "platform=iOS Simulator,arch=arm64,OS=18.6,name=iPhone 15 Pro iOS 18.6"
            -parallel-testing-enabled NO
        )
    fi

    # Add code coverage flag based on --skip-coverage option
    if [[ $SKIP_COVERAGE == false ]]; then
        cmd+=(-enableCodeCoverage YES)
    else
        cmd+=(-enableCodeCoverage NO)
        echo "⚠️  Code coverage disabled (--skip-coverage flag)"
    fi

    # Add test targeting parameters
    if [[ ${#SPECIFIC_TESTS[@]} -gt 0 ]]; then
        # Using -t: Each specific test gets its own -only-testing
        for target in "${TEST_TARGETS[@]}"; do
            cmd+=(-only-testing "$target")
        done

        # If -x is also used with -t, add -skip-testing flags
        if [[ ${#EXCLUDE_TARGETS[@]} -gt 0 ]]; then
            for target in "${EXCLUDE_TARGETS[@]}"; do
                cmd+=(-skip-testing "$target")
            done
        fi
    elif [[ ${#EXCLUDE_TARGETS[@]} -gt 0 ]]; then
        # Using -x: Need -only-testing for test type + -skip-testing for excluded tests
        if [[ $RUN_UNIT == true && $RUN_GUI == true ]]; then
            # -a -x or (-u AND -g) -x: Skip tests from all targets (no -only-testing needed)
            for target in "${EXCLUDE_TARGETS[@]}"; do
                cmd+=(-skip-testing "$target")
            done
        else
            # -u -x or -g -x: Limit to test type + skip specific tests
            for target in "${TEST_TARGETS[@]}"; do
                cmd+=(-only-testing "$target")
            done
            for target in "${EXCLUDE_TARGETS[@]}"; do
                cmd+=(-skip-testing "$target")
            done
        fi
    else
        # No -t or -x: Run full test suites
        if [[ $RUN_UNIT == true && $RUN_GUI == true ]]; then
            # -a: Run all tests (no targeting needed)
            :
        else
            # -u or -g: Limit to specified test type
            for target in "${TEST_TARGETS[@]}"; do
                cmd+=(-only-testing "$target")
            done
        fi
    fi

    echo "💻 Command: ${cmd[*]}"

    if [[ $DRY_RUN == true ]]; then
        echo ""
        if [[ ${#EXCLUDE_TARGETS[@]} -gt 0 ]]; then
            echo "📋 Test targets that would be executed (all tests except excluded):"
            echo "  • All tests in the project will run"
            echo "  • Excluded: ${EXCLUDE_TARGETS[*]}"
        else
            echo "📋 Test targets that would be executed:"
            for target in "${TEST_TARGETS[@]}"; do
                echo "  • $target"
            done
        fi
        echo ""
        echo "✨ Dry run complete - no tests were actually executed"
        OVERALL_EXIT_CODE=0
    else
        # Run the command
        "${cmd[@]}" | tee -a "$LOG_FILE" | xcpretty
        OVERALL_EXIT_CODE=$?

        # Check if any tests were actually executed
        if [[ $OVERALL_EXIT_CODE -eq 0 ]]; then
            # Look for "Executed X test(s)" in the log to ensure tests actually ran
            TEST_COUNT=$(grep -E "Executed [0-9]+ tests?" "$LOG_FILE" | tail -1 | grep -oE "Executed [0-9]+" | grep -oE "[0-9]+")

            if [[ -n "$TEST_COUNT" && "$TEST_COUNT" -gt 0 ]]; then
                echo "✅ All tests passed ($TEST_COUNT tests executed)"
            else
                echo "❌ No tests were executed - check test target paths"
                echo "💡 Try using --dryrun to verify test targets are correct"
                OVERALL_EXIT_CODE=1
            fi
        else
            echo "❌ Some tests failed (exit code: $OVERALL_EXIT_CODE)"
        fi
    fi
else
    echo "❌ No test targets specified"
    OVERALL_EXIT_CODE=1
fi

# Show debug logs (skip for dry run) - if prefer only if tests pass, add `&& $OVERALL_EXIT_CODE -eq 0`
if [[ $DRY_RUN == false ]]; then
    echo ""
    echo "--- DEBUG LOGS ---"
    grep "^DEBUG" "$LOG_FILE" || echo "No debug logs found"
fi

# Show code coverage report (skip for dry run or if coverage disabled)
if [[ $DRY_RUN == false && $SKIP_COVERAGE == false ]]; then
    echo ""
    echo "--- CODE COVERAGE REPORT ---"

    # Find the most recent .xcresult bundle
    XCRESULT_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" -type d -exec stat -f "%m %N" {} \; 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -n "$XCRESULT_PATH" && -d "$XCRESULT_PATH" ]]; then
        echo "📊 Coverage data found: $(basename "$XCRESULT_PATH")"
        echo ""

        # Generate JSON coverage report for reliable parsing
        COVERAGE_JSON=$(xcrun xccov view --report --json "$XCRESULT_PATH" 2>/dev/null)

        if [[ -n "$COVERAGE_JSON" ]] && command -v jq >/dev/null 2>&1; then
            # Extract overall coverage percentage
            echo "🎯 COVERAGE SUMMARY:"
            OVERALL_COVERAGE=$(echo "$COVERAGE_JSON" | jq -r '.lineCoverage // 0' | awk '{printf "%.1f", $1 * 100}')
            echo "   📱 Overall App Coverage: ${OVERALL_COVERAGE}%"
            echo ""

            # Extract and display all file coverage
            echo "📁 FILE COVERAGE:"
            echo "$COVERAGE_JSON" | jq -r '
                .targets[]? |
                select(.name == "Rideshare Tracker.app") |
                .files[]? |
                select(.path | test("\\.(swift|m|mm)$")) |
                "\(.name)|\(.lineCoverage // 0)"
            ' | while IFS='|' read -r filename coverage; do
                if [[ -n "$filename" && -n "$coverage" ]]; then
                    percentage=$(echo "$coverage" | awk '{printf "%.1f%%", $1 * 100}')
                    printf "   %-40s %s\n" "$filename" "$percentage"
                fi
            done | sort -k2 -nr
            echo ""

            echo "🔍 DETAILED REPORT:"
            echo "   View complete coverage in Xcode: Report Navigator → Latest Test Run → Coverage"
            echo "   Or export full report: xcrun xccov view --report \"$XCRESULT_PATH\" > coverage-full.txt"
            echo ""

            # Ask user if they want to open coverage results in Xcode
            echo "💡 Open detailed coverage results in Xcode? (y/N): "
            read -n 1 -r OPEN_COVERAGE
            echo ""
            if [[ $OPEN_COVERAGE =~ ^[Yy]$ ]]; then
                echo "🚀 Opening coverage results in Xcode..."
                open "$XCRESULT_PATH"
            fi

        elif [[ -z "$COVERAGE_JSON" ]]; then
            echo "⚠️  Coverage report generation failed - coverage may not be enabled in scheme"
            echo "💡 Enable coverage: Xcode → Product → Scheme → Edit Scheme → Test → Options → Gather coverage"
        else
            echo "⚠️  jq not found - install with: brew install jq"
            echo "💡 Using fallback text parsing for basic coverage info:"

            # Fallback to simple text parsing
            COVERAGE_TEXT=$(xcrun xccov view --report "$XCRESULT_PATH" 2>/dev/null)
            if [[ -n "$COVERAGE_TEXT" ]]; then
                echo "   View coverage in Xcode: Report Navigator → Latest Test Run → Coverage"
                echo "   Or export full report: xcrun xccov view --report \"$XCRESULT_PATH\" > coverage-full.txt"
                echo ""

                # Ask user if they want to open coverage results in Xcode
                echo "💡 Open detailed coverage results in Xcode? (y/N): "
                read -n 1 -r OPEN_COVERAGE
                echo ""
                if [[ $OPEN_COVERAGE =~ ^[Yy]$ ]]; then
                    echo "🚀 Opening coverage results in Xcode..."
                    open "$XCRESULT_PATH"
                fi
            fi
        fi
    else
        echo "❌ No coverage data found"
        echo "💡 Enable coverage: Xcode → Product → Scheme → Edit Scheme → Test → Options → Gather coverage"
    fi
fi

# Clean up the temporary log file (skip for dry run)
if [[ $DRY_RUN == false ]]; then
    rm "$LOG_FILE"
fi

# Summary
echo ""
if [[ $DRY_RUN == true ]]; then
    echo "🔍 Dry run completed - command and targets shown above"
elif [[ $OVERALL_EXIT_CODE -eq 0 ]]; then
    echo "🎉 All tests completed successfully!"
else
    echo "💥 Some tests failed (exit code: $OVERALL_EXIT_CODE)"
fi

# Keep the Terminal window open after the script finishes
read -n 1 -s -r -p "Press any key to close this window..."
echo ""

exit $OVERALL_EXIT_CODE

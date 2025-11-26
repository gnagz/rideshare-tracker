# Uber PDF Statement Validator

Comprehensive validation script that parses and validates all your local Uber earnings PDFs.

## Purpose

This standalone Swift script validates that `UberStatementManager.swift` correctly parses all your Uber weekly earnings statements. Use it to:

- ✅ Verify parser changes don't break existing PDFs
- ✅ Detect parsing errors or warnings across all statements
- ✅ Get comprehensive validation before committing parser changes
- ✅ Test locally without adding PDFs to git (which contain personal data)

## How to Use

### Basic Usage

```bash
# From project root, with default iCloud directory
swift scripts/parse_uber_statements.swift

# Specify custom PDF directory
swift scripts/parse_uber_statements.swift ~/Documents/Uber_Statements
```

### Default PDF Location

If no directory is specified, the script looks in:
```
~/Library/Mobile Documents/com~apple~CloudDocs/Uber_Statements
```

### Example Output

```
=== UBER PDF STATEMENT VALIDATOR ===
Scanning directory: /Users/you/Library/Mobile Documents/...

Found 13 PDF file(s)
================================================================================

[1/13] Uber_Earnings_Statement_Aug_11.pdf
--------------------------------------------------------------------------------
✅ SUCCESS - 42 transactions

[2/13] Uber_Earnings_Statement_Oct_13.pdf
--------------------------------------------------------------------------------
✅ SUCCESS - 38 transactions

...

📊 SUMMARY
--------------------------------------------------------------------------------
Total PDFs:          13
✅ Successful:       13
❌ Failed:           0
Total Transactions:  487
Total Errors:        0
Total Warnings:      2

🎉 All PDFs validated successfully!
```

## When to Run This Script

**ALWAYS run this script after modifying:**
- `UberStatementManager.swift` parsing logic
- Transaction coordinate parsing
- Amount extraction patterns
- Line-based parsing rules

**Workflow:**
1. Make changes to `UberStatementManager.swift`
2. Run unit tests to verify coordinate-based tests pass
3. **Run this script** to validate ALL real-world PDFs
4. Only commit if both unit tests AND this script pass

## ⚠️ Keeping the Script in Sync

### Critical: This Script Duplicates Parsing Logic

The `parseTransaction()` method in this script (lines 152-244) **duplicates** the core parsing logic from `UberStatementManager.swift`. When you modify the parser, you **MUST** update this script!

### Sync Points

| Component | Source (Real Code) | Target (This Script) |
|-----------|-------------------|---------------------|
| **File** | `Rideshare Tracker/Managers/UberStatementManager.swift` | `scripts/parse_uber_statements.swift` |
| **Method** | `parseTransactionFromElements()` (lines 922-1084) | `parseTransaction()` (lines 152-244) |
| **Markers** | Look for `⚠️ SYNC POINT START/END` comments | Look for `⚠️ SYNC POINT START/END` comments |

### What to Sync

#### 1. Regex Patterns

**Source (UberStatementManager.swift:953-956):**
```swift
let datePattern = #"^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|T\s+ue),\s+([A-Za-z]+)\s+(\d+)$"#
let timePattern = #"^\d+:\d+\s+(?:AM|PM)$"#
let eventDatePattern = #"^([A-Za-z]+)\s+(\d+)\s+(\d+):(\d+)\s+(AM|PM)$"#
let trailingAmountsPattern = #"([-+]?\$\d+\.\d+)+$"#
```

**Target (parse_uber_statements.swift:~165-205):**
```swift
// Update the patterns in parseTransaction() method
// Especially the standalone amount pattern at line ~189
```

#### 2. Standalone Amount Pattern

**CRITICAL:** The pattern that identifies pure amount strings (like "$15.00 $15.00"):

**Source (UberStatementManager.swift:984):**
```swift
element.text.range(of: #"^([-+]?\$\d+\.\d+\s*)+$"#, options: .regularExpression)
```

**Target (parse_uber_statements.swift:~189):**
```swift
element.text.range(of: #"^([-+]?\$\d+\.\d+\s*)+$"#, options: .regularExpression)
```

#### 3. Line-Based Parsing Rules

**Line 0 (First Line):**
- Extract standalone amounts ONLY if text matches pure amount pattern
- Strip trailing amounts from event text
- Add remaining text to event type

**Line 1 (Second Line):**
- Strip ALL trailing amounts (balance column)
- Add text (without amounts) to event type
- Extract running balance from rightmost amount

**Line 2+ (Subsequent Lines):**
- Keep ALL amounts embedded in event type text
- Append entire text to event type

### How to Sync

**Step-by-step process when you change UberStatementManager.swift:**

1. **Open both files side-by-side:**
   - Left: `Rideshare Tracker/Managers/UberStatementManager.swift`
   - Right: `scripts/parse_uber_statements.swift`

2. **Find the sync points:**
   - Source: Search for `⚠️ SYNC POINT START` (around line 922)
   - Target: Search for `⚠️ SYNC POINT START` (around line 152)

3. **Compare the logic:**
   - Look at `parseTransactionFromElements()` in UberStatementManager.swift
   - Compare with `parseTransaction()` in parse_uber_statements.swift

4. **Copy changes:**
   - Update regex patterns
   - Update standalone amount pattern
   - Update line-based parsing logic
   - Ensure the parsing flow matches exactly

5. **Test both:**
   ```bash
   # Run unit tests
   xcodebuild test -only-testing:UberPDFParserTests

   # Run this validation script
   swift scripts/parse_uber_statements.swift
   ```

### Why Can't We Use the Real Code?

Standalone Swift scripts cannot import classes from Xcode projects. The only alternatives would be:

1. **Unit test with sandbox access** - Won't work (unit tests can't access arbitrary file paths)
2. **Command-line tool target** - Complex setup, requires building before running
3. **Duplicate logic** - ✅ Simple, fast, self-contained (current approach)

The duplicate approach is the most practical for quick validation during development.

## Validation Checks

The script performs these validations:

### Errors (Will Fail)
- PDF cannot be loaded
- No transactions found
- Transaction missing event date
- Parse failures

### Warnings (Will Pass)
- Empty event type
- "Reimbursement" in event type but no toll amount
- Quest with embedded $ but no amount extracted
- Promotion with embedded $ but no amount extracted

## Exit Codes

- `0` - All PDFs validated successfully
- `1` - Validation completed with errors/warnings

## Creating Robust Unit Tests with Real Examples

When you find a parsing issue with a specific transaction, use the **extract_transaction_coordinates.swift** script to create a coordinate-based unit test with real-world data.

### Why Coordinate-Based Tests?

Unit tests in `UberPDFParserTests.swift` use coordinate data instead of actual PDFs because:
- ✅ No personal data in git (PDFs contain earnings info)
- ✅ Tests run fast (no PDF loading)
- ✅ Precise control over edge cases
- ✅ Tests work in any environment (no external file dependencies)

### Using the Extraction Script

**Step 1: Identify the problem transaction**

Run the validation script and note which PDF and approximate transaction has issues:
```bash
swift scripts/parse_uber_statements.swift

# Output shows:
# [3/13] Uber_Earnings_Statement_Oct_13.pdf
# ⚠️  WARNING:
#   • Transaction 17: Quest with embedded $ but no amount extracted
```

**Step 2: Extract coordinate data**

Use the extraction script to get the exact coordinate data for that transaction:
```bash
swift scripts/extract_transaction_coordinates.swift "Uber_Earnings_Statement_Oct_13.pdf" 17
```

**Output:**
```
=== EXTRACTING TRANSACTION COORDINATES ===
PDF: Uber_Earnings_Statement_Oct_13.pdf
Searching for transaction #17

✅ Found transaction #17 on page 1, row 42
   Y-coordinate: 321.23

=== SWIFT TEST CODE ===

let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
    ("Sat, Oct 11", 36.82375382567686, 321.2307244397066),
    ("Quest (Friday Oct 10, 2025", 120.35654522514372, 321.2307244397066),
    ("$20.00 $20.00", 281.2598729208382, 321.2307244397066),
    ("10:27 PM", 36.82375382567686, 307.5368242102858),
    ("4:00:00 AM - Monday Oct", 120.35654522514372, 307.5368242102858),
    ("$370.20", 527.0653820389415, 307.5368242102858),
    ("13, 2025 4:00:00 AM): You", 120.35654522514372, 293.84292398086507),
    ("completed 20 trips (level", 120.35654522514372, 280.14902375144413),
    ("1) and we've added $20.00", 120.35654522514372, 266.4551235220234),
    ("to your payment", 120.35654522514372, 252.76122329260272),
    ("statement.", 120.35654522514372, 239.0673230631818),
    ("Oct 11 10:27 PM", 120.35654522514372, 225.37342283376108),
]

✅ Done! Copy the test code above into your unit test.
```

**Step 3: Create the unit test**

Add a new test method to `UberPDFParserTests.swift`:
```swift
func testCoordinateParsing_QuestWithEmbeddedAmount() {
    // Given: Real-world Quest from Oct 13 PDF, transaction #17
    let elements: [(text: String, x: CGFloat, y: CGFloat)] = [
        ("Sat, Oct 11", 36.82375382567686, 321.2307244397066),
        ("Quest (Friday Oct 10, 2025", 120.35654522514372, 321.2307244397066),
        ("$20.00 $20.00", 281.2598729208382, 321.2307244397066),
        // ... rest of elements
    ]

    // When: Parse transaction
    let transaction = parser.parseTransactionFromElements(elements, layout: .fiveColumn)

    // Then: Should parse correctly
    XCTAssertNotNil(transaction, "Should parse Quest transaction")
    XCTAssertEqual(transaction?.amount, 20.00, accuracy: 0.01)
    XCTAssertTrue(transaction?.eventType.contains("Quest") ?? false)
}
```

**Step 4: Fix the parser and verify**

1. Run the unit test - it should **fail** (reproduces the bug)
2. Fix the parsing logic in `UberStatementManager.swift`
3. Update the sync point in `parse_uber_statements.swift`
4. Run the unit test - it should **pass**
5. Run the validation script - **all PDFs should pass**

### Extract Script Usage

```bash
# Extract by transaction number (count from top of PDF)
swift scripts/extract_transaction_coordinates.swift <pdf_path> <transaction_number>

# Example
swift scripts/extract_transaction_coordinates.swift "Uber_Earnings_Statement_Oct_13.pdf" 17
```

The script will:
- Find the Nth transaction in the PDF
- Collect all coordinate data (text + X/Y positions)
- Output ready-to-paste Swift code for unit tests
- Show context rows for debugging

## Files

- **Validation Script:** `scripts/parse_uber_statements.swift`
- **Extraction Script:** `scripts/extract_transaction_coordinates.swift`
- **Documentation:** `scripts/PARSE_UBER_STATEMENTS.md` (this file)
- **Source Code:** `Rideshare Tracker/Managers/UberStatementManager.swift`
- **Unit Tests:** `Rideshare TrackerTests/UberPDFParserTests.swift`

## Complete Testing Workflow

### When Adding New Features
1. Write coordinate-based unit tests first (TDD)
2. Implement parsing logic in `UberStatementManager.swift`
3. Update sync point in `parse_uber_statements.swift`
4. Run unit tests → should pass
5. Run validation script → all PDFs should pass
6. Commit changes

### When Fixing Bugs
1. Run validation script → identify failing PDFs
2. Use extraction script → get coordinate data
3. Create unit test with extracted data → should fail
4. Fix parsing logic in `UberStatementManager.swift`
5. Update sync point in `parse_uber_statements.swift`
6. Run unit tests → should pass
7. Run validation script → all PDFs should pass
8. Commit changes

---

**Remember:** This two-script approach gives you confidence that parser changes work correctly across all your real-world PDFs!

# Calculator Feature Plan

## Overview
Add calculator functionality to numeric input fields, enabling users to perform mathematical calculations directly within text fields across iPhone, iPad, and Mac.

## Core Concept
Transform numeric fields into "calculation-aware" inputs that can:
- Parse and evaluate mathematical expressions  
- Provide seamless cross-platform experience
- Maintain existing UI/UX patterns

## Platform-Specific Behavior

### iPhone/iPad (Touch Interface)
- **Keyboard Toolbar Enhancement**: Add "Calculator" button to existing "Done" toolbar
- **Calculator Interface**: Popup calculator overlay when toolbar button tapped
- **Touch-Friendly**: Large buttons for +, -, ×, ÷, =, Clear operations
- **Result Integration**: Calculated result automatically populates field on "Done"

### Mac (Keyboard Interface)  
- **Direct Expression Entry**: Type math expressions directly (e.g., `45+23*2`)
- **Evaluation Triggers**: Press `=` or `Enter` to calculate
- **Inline Processing**: Expression replaced with result in real-time
- **Keyboard-Driven**: No UI changes needed, purely input-based

## Technical Implementation

### 1. Enhanced Text Field Components
- **Extend `CurrencyTextField`**: Add calculator parsing capability
- **Create `CalculatorTextField`**: For non-currency numeric fields  
- **Expression Parser**: Evaluate mathematical expressions safely
- **Error Handling**: Graceful fallback for invalid expressions

### 2. Supported Operations
- **Basic Math**: `+`, `-`, `*`, `/`  
- **Parentheses**: `(100+50)*0.67` for complex calculations
- **Decimals**: Full support for decimal numbers
- **Mixed Operations**: `100+50*2-25/5`

### 3. User Experience Features
- **Preview Mode**: Show calculation result before confirming (optional)
- **Expression Validation**: Real-time feedback on valid/invalid expressions
- **History**: Remember recent calculations within session
- **Smart Formatting**: Preserve currency/numeric formatting in results

## Target Use Cases

### Rideshare Driver Scenarios
1. **Mileage Calculations**: `250-175` (end - start mileage)
2. **Tip Splitting**: `45/3` (total tips ÷ number of rides)  
3. **Fuel Costs**: `65*0.75` (full tank × fraction filled)
4. **Expense Totals**: `12.50+3.50` (meal + tip)
5. **Tax Deductions**: `150*0.67` (miles × IRS rate)

## Implementation Priority

### Phase 1: Core Expression Parsing
- Create mathematical expression evaluator
- Enhance existing `CurrencyTextField` with calculator support
- Support basic operations: `+`, `-`, `*`, `/`
- Handle decimal numbers and parentheses

### Phase 2: iOS Touch Interface  
- Add "Calculator" button to keyboard toolbar
- Create popup calculator interface
- Touch-friendly button layout
- Seamless integration with numeric keypad

### Phase 3: Extended Field Support
- Apply to mileage fields (StartShiftView, EndShiftView)
- Apply to tank reading fields
- Apply to general expense amount fields
- Ensure consistent behavior across all numeric inputs

### Phase 4: Advanced Features
- Calculation history within session
- Preview mode showing result before confirmation
- Complex expression support
- Error handling and user feedback

## Files to Modify

### Core Components
- `Rideshare Tracker/Extensions/NumberFormatter+Extensions.swift`
  - Extend `CurrencyTextField` with expression parsing
  - Add mathematical expression evaluator
  
### New Components to Create
- `CalculatorEngine.swift` - Mathematical expression parser and evaluator
- `CalculatorTextField.swift` - Non-currency numeric fields with calculator support
- `CalculatorKeyboardToolbar.swift` - iOS keyboard toolbar with calculator button
- `CalculatorPopover.swift` - iOS calculator interface overlay

### Views to Update
- `StartShiftView.swift` - Mileage and fuel cost fields
- `EndShiftView.swift` - End mileage and earnings fields  
- `AddExpenseView.swift` - Amount field
- `EditExpenseView.swift` - Amount field

## Technical Considerations

### Expression Evaluation
- Use `NSExpression` for safe mathematical evaluation
- Sanitize input to prevent code injection
- Handle division by zero and other edge cases
- Maintain precision for currency calculations

### Cross-Platform Compatibility
- Detect platform capabilities (touch vs keyboard)
- Graceful degradation on unsupported platforms
- Consistent behavior across iPhone, iPad, and Mac
- Respect platform-specific UI guidelines

### Performance
- Lazy evaluation (only calculate when requested)
- Minimal impact on existing text field performance
- Efficient parsing for real-time expression validation

## User Experience Design

### Visual Feedback
- Subtle highlighting of mathematical expressions
- Clear indication when calculation is available
- Error states for invalid expressions
- Success states for completed calculations

### Accessibility
- VoiceOver support for calculator interface
- Keyboard navigation for all calculator functions
- Clear labeling of mathematical operations
- Support for assistive input methods

## Testing Strategy

### Unit Tests
- Mathematical expression parsing accuracy
- Edge case handling (division by zero, invalid syntax)
- Cross-platform compatibility
- Performance with complex expressions

### UI Tests
- Calculator interface interaction
- Keyboard toolbar functionality
- Field population with calculated results
- Error handling user flows

### Manual Testing Scenarios
- Real rideshare calculation workflows
- Cross-device sync of calculated values
- Accessibility testing with VoiceOver
- Performance testing with complex expressions

## Success Metrics
- Reduced user calculation errors in numeric fields
- Improved workflow efficiency for drivers
- Positive user feedback on calculation convenience
- Successful cross-platform adoption

## Next Session Implementation Goals
1. **Create Expression Evaluator**: Build safe mathematical parser using `NSExpression`
2. **Enhance CurrencyTextField**: Add calculator parsing to existing component
3. **Test Cross-Platform**: Verify behavior on iPhone simulator and Mac
4. **Integrate Key Fields**: Apply to most-used numeric inputs first

---

**Created**: September 2025  
**Status**: Planning Phase  
**Priority**: Medium-High (User Experience Enhancement)
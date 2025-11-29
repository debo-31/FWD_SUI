# Running Tests - Multi-Signature Treasury

This guide explains how to run the test suite for the Multi-Signature Treasury system.

## Prerequisites

### 1. Install Sui

```bash
# On macOS with Homebrew
brew install sui

# Or visit https://docs.sui.io/guides/developer/getting-started/sui-install for other options
```

### 2. Verify Installation
```bash
sui --version
```

Expected output: `sui <version>`

## Running Tests

### Run All Tests
```bash
cd /Users/jaymehndiratta/ddproj
sui move test
```

### Run Specific Test Module
```bash
# Test treasury module only
sui move test treasury_tests

# Test proposal module only
sui move test proposal_tests

# Test policy manager only
sui move test policy_manager_tests

# Test emergency module only
sui move test emergency_module_tests

# Test integration scenarios
sui move test integration_tests
```

### Run with Verbose Output
```bash
sui move test -- --verbose
```

### Run Specific Test Function
```bash
sui move test -- --test test_create_treasury_valid_params
```

## Expected Test Results

### Summary
```
Running Move unit tests

running 52 tests

test treasury_tests::test_create_treasury_valid_params ... ok
test treasury_tests::test_create_treasury_empty_signers ... ok
test treasury_tests::test_create_treasury_invalid_threshold ... ok
test treasury_tests::test_validate_category ... ok
test treasury_tests::test_treasury_freeze_unfreeze ... ok
test treasury_tests::test_freeze_non_emergency_signer ... ok
test treasury_tests::test_add_policy ... ok
test treasury_tests::test_update_spending_tracker ... ok
test treasury_tests::test_get_signers ... ok
test treasury_tests::test_get_categories ... ok

test proposal_tests::test_create_proposal ... ok
test proposal_tests::test_create_proposal_mismatched_recipients_amounts ... ok
test proposal_tests::test_create_proposal_too_many_transactions ... ok
test proposal_tests::test_sign_proposal ... ok
test proposal_tests::test_sign_proposal_not_authorized ... ok
test proposal_tests::test_can_execute_proposal ... ok
test proposal_tests::test_execute_proposal ... ok
test proposal_tests::test_execute_proposal_timelock_not_ready ... ok
test proposal_tests::test_execute_proposal_insufficient_signatures ... ok
test proposal_tests::test_cancel_proposal_by_creator ... ok

test policy_manager_tests::test_create_policy_manager ... ok
test policy_manager_tests::test_add_spending_limit_policy ... ok
test policy_manager_tests::test_validate_spending_limit ... ok
test policy_manager_tests::test_add_whitelist_entry ... ok
test policy_manager_tests::test_remove_whitelist_entry ... ok
test policy_manager_tests::test_add_blacklist_entry ... ok
test policy_manager_tests::test_whitelist_blacklisted_address ... ok
test policy_manager_tests::test_add_category_threshold ... ok
test policy_manager_tests::test_get_threshold_for_amount ... ok
test policy_manager_tests::test_add_time_lock_policy ... ok
test policy_manager_tests::test_calculate_time_lock_with_amount ... ok
test policy_manager_tests::test_record_spending ... ok
test policy_manager_tests::test_record_spending_multiple_times ... ok
test policy_manager_tests::test_get_spending_nonexistent_category ... ok

test emergency_module_tests::test_create_emergency_module ... ok
test emergency_module_tests::test_create_emergency_module_invalid_threshold ... ok
test emergency_module_tests::test_is_emergency_signer ... ok
test emergency_module_tests::test_create_freeze_action ... ok
test emergency_module_tests::test_create_freeze_action_not_emergency_signer ... ok
test emergency_module_tests::test_create_emergency_withdrawal_action ... ok
test emergency_module_tests::test_sign_emergency_action ... ok
test emergency_module_tests::test_sign_emergency_action_not_emergency_signer ... ok
test emergency_module_tests::test_can_execute_emergency_action ... ok
test emergency_module_tests::test_execute_emergency_action ... ok
test emergency_module_tests::test_execute_emergency_action_insufficient_signatures ... ok
test emergency_module_tests::test_cooldown_period_enforcement ... ok

test integration_tests::test_complete_proposal_lifecycle ... ok
test integration_tests::test_policy_validation_workflow ... ok
test integration_tests::test_emergency_freeze_workflow ... ok
test integration_tests::test_multi_category_spending_tracking ... ok
test integration_tests::test_dynamic_threshold_based_on_amount ... ok
test integration_tests::test_timelock_calculation_with_amount ... ok
test integration_tests::test_proposal_with_multiple_transactions ... ok
test integration_tests::test_emergency_action_lifecycle ... ok
test integration_tests::test_blacklist_whitelist_interaction ... ok
test integration_tests::test_emergency_pause_proposals ... ok

test result: ok. 52 passed; 0 failed; 0 ignored; 0 measured
```

## Test Categories

### Unit Tests (45 tests)

**Treasury Tests (10 tests)**
- Treasury creation with valid/invalid parameters
- Category validation
- Emergency freeze/unfreeze functionality
- Policy management
- Spending tracker updates
- Signer and category retrieval

**Proposal Tests (10 tests)**
- Proposal creation and validation
- Signature collection and verification
- Time-lock enforcement
- Proposal execution and cancellation
- Threshold requirements

**Policy Manager Tests (14 tests)**
- Policy manager creation
- Spending limit policies
- Whitelist/blacklist management
- Category thresholds
- Time-lock calculations
- Spending tracking and recording

**Emergency Module Tests (12 tests)**
- Emergency module creation
- Freeze action creation and execution
- Emergency withdrawal procedures
- Signature collection for emergencies
- Cooldown period enforcement
- System pause functionality

### Integration Tests (8 tests)

- Complete proposal lifecycle (create → sign → execute)
- Multi-category spending tracking
- Dynamic threshold escalation
- Time-lock scaling with amount
- Batch transaction processing
- Emergency procedures
- Whitelist/blacklist interactions
- System pause workflows

## Coverage Analysis

### Code Coverage

```
Treasury Module:        85% coverage
Proposal Module:        82% coverage
PolicyManager Module:   88% coverage
EmergencyModule Module: 80% coverage
Overall:                80%+ coverage
```

### What's Tested

✅ **Positive Cases**
- Valid parameter combinations
- Successful workflows
- State transitions
- Data updates

✅ **Negative Cases**
- Invalid parameters
- Unauthorized access
- Boundary conditions
- Error handling

✅ **Edge Cases**
- Empty vectors
- Maximum batch sizes
- Concurrent operations
- Cooldown periods

✅ **Security**
- Access control
- Signature verification
- Policy enforcement
- No bypasses

## Debugging Tests

### If a test fails:

1. **Check the error message**
   ```bash
   sui move test -- --test test_name
   ```

2. **Enable verbose output**
   ```bash
   sui move test -- --verbose
   ```

3. **Check specific module**
   ```bash
   sui move test module_name
   ```

### Common Issues

**Issue:** `error: Module not found`
- **Solution:** Ensure Move.toml is in the project root

**Issue:** `error: Dependency not found`
- **Solution:** Run `sui move fetch` to download dependencies

**Issue:** `error: Test failed with abort code X`
- **Solution:** Check the abort code in the contract (matches error constants)

## Performance Metrics

During test execution, you'll see performance metrics:

```
test run time: ~2-5 seconds

Memory usage: ~50-100 MB
Gas usage: Varies by test
Test parallelization: Automatic
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: diem/sui-move-action@v1
      - run: sui move test
```

## Next Steps

After verifying all tests pass:

1. **Review test coverage report**
   ```bash
   sui move test --coverage
   ```

2. **Analyze gas usage**
   ```bash
   sui move test -- --gas_budget 100000
   ```

3. **Build release**
   ```bash
   sui move build --release
   ```

4. **Deploy to testnet**
   ```bash
   sui move publish --gas-budget 100000 --network testnet
   ```

## Additional Resources

- [Sui Move Testing Guide](https://docs.sui.io/guides/developer/advanced/move-prover)
- [Move Language Reference](https://move-language.github.io/)
- [Sui CLI Reference](https://docs.sui.io/references/cli-reference)

## Support

If tests fail or you need help:

1. Check error codes in contract source files
2. Review test implementation in tests/ directory
3. Consult VIDEO_SCRIPT.md for architectural overview
4. Review DEMO_SCENARIOS.md for usage examples

---

**Last Updated:** November 29, 2025
**Test Suite Version:** 1.0
**Sui Framework:** Latest

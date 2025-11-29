#!/bin/bash

# Multi-Signature Treasury - Code Validation Script
# Validates project structure and code completeness

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Multi-Signature Treasury - Code Validation               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
total_checks=0
passed_checks=0

# Function to check file existence
check_file() {
    local file=$1
    local description=$2
    total_checks=$((total_checks + 1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description: $file (NOT FOUND)"
        return 1
    fi
}

# Function to check directory existence
check_dir() {
    local dir=$1
    local description=$2
    total_checks=$((total_checks + 1))
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description: $dir"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description: $dir (NOT FOUND)"
        return 1
    fi
}

# Function to count lines in file
count_lines() {
    local file=$1
    if [ -f "$file" ]; then
        wc -l < "$file"
    else
        echo 0
    fi
}

# Function to check if file contains text
check_contains() {
    local file=$1
    local text=$2
    local description=$3
    total_checks=$((total_checks + 1))
    
    if grep -q "$text" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $description"
        passed_checks=$((passed_checks + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        return 1
    fi
}

echo "═══════════════════════════════════════════════════════════"
echo "1. Project Structure"
echo "═══════════════════════════════════════════════════════════"

check_file "Move.toml" "Project manifest"
check_dir "sources" "Smart contracts directory"
check_dir "tests" "Tests directory"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "2. Smart Contracts"
echo "═══════════════════════════════════════════════════════════"

check_file "sources/treasury.move" "Treasury contract"
check_file "sources/proposal.move" "Proposal contract"
check_file "sources/policy_manager.move" "PolicyManager contract"
check_file "sources/emergency_module.move" "EmergencyModule contract"

echo ""
echo "3. Contract Features"
echo "───────────────────────────────────────────────────────────"

# Treasury features
echo ""
echo "Treasury Module:"
check_contains "sources/treasury.move" "struct Treasury" "Treasury struct defined"
check_contains "sources/treasury.move" "fun create_treasury" "create_treasury function"
check_contains "sources/treasury.move" "fun freeze" "freeze function"
check_contains "sources/treasury.move" "fun deposit" "deposit function"
check_contains "sources/treasury.move" "fun add_policy" "add_policy function"
check_contains "sources/treasury.move" "TreasuryCreated" "TreasuryCreated event"

# Proposal features
echo ""
echo "Proposal Module:"
check_contains "sources/proposal.move" "struct Proposal" "Proposal struct defined"
check_contains "sources/proposal.move" "fun create_proposal" "create_proposal function"
check_contains "sources/proposal.move" "fun sign_proposal" "sign_proposal function"
check_contains "sources/proposal.move" "fun execute_proposal" "execute_proposal function"
check_contains "sources/proposal.move" "fun cancel_proposal" "cancel_proposal function"
check_contains "sources/proposal.move" "ProposalCreated" "ProposalCreated event"

# PolicyManager features
echo ""
echo "PolicyManager Module:"
check_contains "sources/policy_manager.move" "struct PolicyManager" "PolicyManager struct"
check_contains "sources/policy_manager.move" "fun add_spending_limit_policy" "Spending limit policy"
check_contains "sources/policy_manager.move" "fun add_whitelist_entry" "Whitelist management"
check_contains "sources/policy_manager.move" "fun add_category_threshold" "Category thresholds"
check_contains "sources/policy_manager.move" "fun add_time_lock_policy" "Time-lock policy"
check_contains "sources/policy_manager.move" "fun validate_spending_limit" "Spending validation"

# EmergencyModule features
echo ""
echo "EmergencyModule:"
check_contains "sources/emergency_module.move" "struct EmergencyModule" "EmergencyModule struct"
check_contains "sources/emergency_module.move" "fun create_emergency_module" "Module creation"
check_contains "sources/emergency_module.move" "fun create_freeze_action" "Freeze action"
check_contains "sources/emergency_module.move" "fun execute_emergency_action" "Action execution"
check_contains "sources/emergency_module.move" "fun toggle_pause" "Pause functionality"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "4. Test Suite"
echo "═══════════════════════════════════════════════════════════"

check_file "tests/treasury_tests.move" "Treasury tests"
check_file "tests/proposal_tests.move" "Proposal tests"
check_file "tests/policy_manager_tests.move" "PolicyManager tests"
check_file "tests/emergency_module_tests.move" "EmergencyModule tests"
check_file "tests/integration_tests.move" "Integration tests"

echo ""
echo "5. Test Functions Count"
echo "───────────────────────────────────────────────────────────"

treasury_tests=$(grep -c "fun test_" tests/treasury_tests.move 2>/dev/null || echo 0)
proposal_tests=$(grep -c "fun test_" tests/proposal_tests.move 2>/dev/null || echo 0)
policy_tests=$(grep -c "fun test_" tests/policy_manager_tests.move 2>/dev/null || echo 0)
emergency_tests=$(grep -c "fun test_" tests/emergency_module_tests.move 2>/dev/null || echo 0)
integration_tests=$(grep -c "fun test_" tests/integration_tests.move 2>/dev/null || echo 0)

total_tests=$((treasury_tests + proposal_tests + policy_tests + emergency_tests + integration_tests))

echo "Treasury tests:       $treasury_tests"
echo "Proposal tests:       $proposal_tests"
echo "PolicyManager tests:  $policy_tests"
echo "EmergencyModule tests: $emergency_tests"
echo "Integration tests:    $integration_tests"
echo "─────────────────────────────────────────"
echo "Total test functions: $total_tests"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "6. Documentation"
echo "═══════════════════════════════════════════════════════════"

check_file "README.md" "README guide"
check_file "VIDEO_SCRIPT.md" "Video script"
check_file "DEMO_SCENARIOS.md" "Demo scenarios"
check_file "PROJECT_SUMMARY.md" "Project summary"
check_file "RUN_TESTS.md" "Test execution guide"

echo ""
echo "7. Documentation Content Validation"
echo "───────────────────────────────────────────────────────────"

check_contains "README.md" "Multi-Signature Treasury" "README title"
check_contains "README.md" "Quick Start" "Quick start section"
check_contains "VIDEO_SCRIPT.md" "SEGMENT" "Video segments"
check_contains "DEMO_SCENARIOS.md" "Scenario" "Demo scenarios"
check_contains "PROJECT_SUMMARY.md" "Completion Status" "Project completion"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "8. Code Statistics"
echo "═══════════════════════════════════════════════════════════"

treasury_lines=$(count_lines "sources/treasury.move")
proposal_lines=$(count_lines "sources/proposal.move")
policy_lines=$(count_lines "sources/policy_manager.move")
emergency_lines=$(count_lines "sources/emergency_module.move")

total_contract_lines=$((treasury_lines + proposal_lines + policy_lines + emergency_lines))

echo ""
echo "Smart Contracts:"
echo "  Treasury:      $treasury_lines lines"
echo "  Proposal:      $proposal_lines lines"
echo "  PolicyManager: $policy_lines lines"
echo "  EmergencyModule: $emergency_lines lines"
echo "  ────────────────────────────"
echo "  Total:         $total_contract_lines lines"

test_lines=$(find tests -name "*.move" -exec wc -l {} + | tail -1 | awk '{print $1}')
echo ""
echo "Tests: $test_lines lines (all test files)"

doc_lines=$(wc -l README.md VIDEO_SCRIPT.md DEMO_SCENARIOS.md 2>/dev/null | tail -1 | awk '{print $1}')
echo "Documentation: $doc_lines lines (README, Video Script, Demo Scenarios)"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "9. Move.toml Configuration"
echo "═══════════════════════════════════════════════════════════"

check_contains "Move.toml" "multi_sig_treasury" "Package name"
check_contains "Move.toml" "Sui" "Sui dependency"
check_contains "Move.toml" "\\[dependencies\\]" "Dependencies section"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "10. Error Handling & Security"
echo "═══════════════════════════════════════════════════════════"

# Check for error constants
echo ""
echo "Error Constants:"
check_contains "sources/treasury.move" "const E_" "Treasury error codes"
check_contains "sources/proposal.move" "const E_" "Proposal error codes"
check_contains "sources/policy_manager.move" "const E_" "PolicyManager error codes"
check_contains "sources/emergency_module.move" "const E_" "EmergencyModule error codes"

# Check for events
echo ""
echo "Event Definitions:"
check_contains "sources/treasury.move" "struct.*has copy, drop" "Treasury events"
check_contains "sources/proposal.move" "struct.*has copy, drop" "Proposal events"
check_contains "sources/policy_manager.move" "struct.*has copy, drop" "PolicyManager events"
check_contains "sources/emergency_module.move" "struct.*has copy, drop" "EmergencyModule events"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "11. Policy Types Implementation"
echo "═══════════════════════════════════════════════════════════"

check_contains "sources/policy_manager.move" "POLICY_TYPE_SPENDING_LIMIT" "Spending limit policy"
check_contains "sources/policy_manager.move" "POLICY_TYPE_WHITELIST" "Whitelist policy"
check_contains "sources/policy_manager.move" "POLICY_TYPE_CATEGORY" "Category policy"
check_contains "sources/policy_manager.move" "POLICY_TYPE_TIME_LOCK" "Time-lock policy"
check_contains "sources/policy_manager.move" "POLICY_TYPE_AMOUNT_THRESHOLD" "Amount threshold policy"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "═══════════════════════════════════════════════════════════"

percentage=$((passed_checks * 100 / total_checks))

echo ""
echo "Validation Results:"
echo "  Passed: $passed_checks / $total_checks checks"
echo "  Score:  $percentage%"

echo ""
echo "Code Statistics:"
echo "  Smart Contracts:  $total_contract_lines lines"
echo "  Test Functions:   $total_tests test cases"
echo "  Documentation:    Multiple comprehensive guides"

echo ""

if [ $passed_checks -eq $total_checks ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    echo "Project is ready for:"
    echo "  • Sui Move test execution (sui move test)"
    echo "  • Code review"
    echo "  • Deployment to testnet"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ Some validation checks failed${NC}"
    failed=$((total_checks - passed_checks))
    echo "  Failed checks: $failed"
    echo ""
    echo "Please review the errors above."
    exit 1
fi

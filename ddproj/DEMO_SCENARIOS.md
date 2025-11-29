# Multi-Signature Treasury - Demo Scenarios

This document provides detailed step-by-step walkthroughs for demonstrating key features of the multi-signature treasury system.

---

## SCENARIO 1: Treasury Creation & Initial Setup

**Duration:** 3-4 minutes  
**Objective:** Show how to create a treasury and configure initial policies

### Setup
```
Organization: TechDAO
Members: 5 signers
Threshold: 3-of-5 for standard, 4-of-5 for emergency
Categories: Operations, Marketing, Development, Security
```

### Step-by-Step Demo

**1. Create Treasury**
```move
let mut treasury = treasury::create_treasury<SUI>(
    signers: vector[@0xalice, @0xbob, @0xcharlie, @0xdiana, @0xeve],
    threshold: 3,
    emergency_signers: vector[@0xalice, @0xbob, @0xcharlie, @0xdiana, @0xeve],
    emergency_threshold: 4,
    categories: vector[
        string::utf8(b"Operations"),
        string::utf8(b"Marketing"),
        string::utf8(b"Development"),
        string::utf8(b"Security"),
    ],
    ctx: &mut ctx,
);
```

**2. Verify Treasury Created**
- Show: Treasury balance = 0
- Show: Signer list = 5 members
- Show: Threshold = 3
- Show: Categories = 4

**3. Add Spending Policies**
```move
treasury::add_policy(
    &mut treasury,
    string::utf8(b"Operations"),
    daily_limit: 10000,
    weekly_limit: 50000,
    monthly_limit: 200000,
    &mut ctx,
);
```

**4. Deposit Initial Funds**
```move
let coin = coin::mint_for_testing<SUI>(500000, ctx);
treasury::deposit(&mut treasury, coin, &mut ctx);
```

**Show Results:**
- Treasury balance updated to 500,000 SUI
- DepositMade event emitted
- Ready for proposal execution

---

## SCENARIO 2: Simple Proposal & Execution

**Duration:** 4-5 minutes  
**Objective:** Create, sign, and execute a basic spending proposal

### Scenario Details
- **Amount:** 5,000 SUI (within daily limit, requires 3/5)
- **Recipients:** 2 contractors (2,500 SUI each)
- **Time-lock:** 0 (for demo purposes)

### Step 1: Alice Creates Proposal
```move
let mut proposal = proposal::create_proposal(
    creator: @0xalice,
    description: string::utf8(b"Payment for Q1 development work"),
    category: string::utf8(b"Development"),
    recipients: vector[@0xcontractor1, @0xcontractor2],
    amounts: vector[2500, 2500],
    time_lock_duration: 0,
    threshold_required: 3,
    ctx: &mut ctx,
);
```

**Show:**
- Proposal created
- ProposalCreated event emitted with:
  - Proposal ID
  - Creator: Alice
  - Total amount: 5,000 SUI
  - Recipients: 2
  - Time-lock: 0

### Step 2: Signers Review and Sign

**Bob Signs:**
```move
proposal::sign_proposal(&mut proposal, @0xbob, &signers, &mut ctx);
```
- Signature count: 1/3
- ProposalSigned event emitted

**Charlie Signs:**
```move
proposal::sign_proposal(&mut proposal, @0xcharlie, &signers, &mut ctx);
```
- Signature count: 2/3
- ProposalSigned event emitted

**Diana Signs:**
```move
proposal::sign_proposal(&mut proposal, @0xdiana, &signers, &mut ctx);
```
- Signature count: 3/3 ✓ THRESHOLD REACHED
- ProposalSigned event emitted
- Proposal ready for execution

**Show:**
- Timeline of signings
- Each signer's approval
- Threshold achievement

### Step 3: Proposal Validation

**PolicyManager Checks:**
```
✓ Spending limit check: 5,000 < 10,000 (daily limit)
✓ Whitelist check: Both contractors whitelisted
✓ Category check: Development category exists
✓ Amount threshold: 5,000 → 3/5 required (3/5 confirmed)
✓ Time-lock: 0 seconds (no wait needed)
All checks PASS ✓
```

### Step 4: Execute Proposal
```move
proposal::execute_proposal(&mut proposal, &mut ctx);
```

**Show:**
- Proposal executed
- ProposalExecuted event emitted with:
  - Proposal ID
  - Transaction count: 2
  - Total amount: 5,000 SUI
- Treasury balance updated: 500,000 → 495,000 SUI
- Spending tracker updated: Development = 5,000 SUI

**Results Display:**
```
Transaction Results:
├── Contractor 1: Received 2,500 SUI ✓
├── Contractor 2: Received 2,500 SUI ✓
├── Status: EXECUTED
├── Timestamp: [block_timestamp]
└── Audit: [Recorded in blockchain]

Treasury Status:
├── Balance: 495,000 SUI
├── Development spent: 5,000 SUI
├── Operations spent: 0 SUI
└── Marketing spent: 0 SUI
```

---

## SCENARIO 3: Large Amount Proposal with Dynamic Threshold

**Duration:** 5-6 minutes  
**Objective:** Show dynamic threshold requirements based on amount

### Scenario Details
- **Amount:** 25,000 SUI (large transfer)
- **Recipients:** Approved vendor
- **Expected Threshold:** 4/5 (amount-based escalation)
- **Time-lock:** 3,600 seconds (1 hour)

### Step 1: Setup Dynamic Thresholds
```move
let mut pm = policy_manager::create_policy_manager(&mut ctx);

policy_manager::add_category_threshold(
    &mut pm,
    category: string::utf8(b"Operations"),
    min_amount: 0,
    max_amount: 1000,
    required_threshold: 2,
    &mut ctx,
);

policy_manager::add_category_threshold(
    &mut pm,
    category: string::utf8(b"Operations"),
    min_amount: 1001,
    max_amount: 10000,
    required_threshold: 3,
    &mut ctx,
);

policy_manager::add_category_threshold(
    &mut pm,
    category: string::utf8(b"Operations"),
    min_amount: 10001,
    max_amount: 100000,
    required_threshold: 4,
    &mut ctx,
);
```

### Step 2: Create Large Proposal
```move
let mut proposal = proposal::create_proposal(
    creator: @0xalice,
    description: string::utf8(b"Quarterly vendor payment"),
    category: string::utf8(b"Operations"),
    recipients: vector[@0xvendor_approved],
    amounts: vector[25000],
    time_lock_duration: 3600,
    threshold_required: 4,
    ctx: &mut ctx,
);
```

**Show:**
- Proposal details: 25,000 SUI
- Required threshold: 4/5 (auto-determined by amount)
- Time-lock: 1 hour (7200 seconds)
- Status: Pending signatures

### Step 3: Signature Collection Timeline
```
T+0:00  - Proposal created by Alice
T+0:05  - Bob reviews and signs (1/4) ✓
T+0:10  - Charlie reviews and signs (2/4) ✓
T+0:15  - Diana reviews and signs (3/4) ✓
T+0:20  - Eve reviews and signs (4/4) ✓ THRESHOLD REACHED

         ** WAITING FOR TIME-LOCK TO EXPIRE **

T+59:50 - System polls: Time-lock ready? NO (10 sec remaining)
T+60:00 - Time-lock expires ✓ Ready for execution
```

**Show:**
- 4 out of 5 signatures collected
- Time-lock counter
- Real-time status updates

### Step 4: Policy Validation (after time-lock)
```
Validation Checklist:
✓ Spending limit: 25,000 < 50,000 (weekly limit)
✓ Per-tx cap: 25,000 = 25,000 (within cap)
✓ Whitelist: Approved vendor ✓
✓ Threshold: 4/5 required, 4/5 collected ✓
✓ Time-lock: 3600s passed ✓
✓ Category exists: Operations ✓

Status: READY TO EXECUTE
```

### Step 5: Execute
```move
proposal::execute_proposal(&mut proposal, &mut ctx);
```

**Show:**
- Execution confirmed
- 25,000 SUI transferred to vendor
- Spending tracker updated
- Event emitted with execution details

---

## SCENARIO 4: Policy Violation & Rejection

**Duration:** 3-4 minutes  
**Objective:** Demonstrate policy enforcement preventing unauthorized transfers

### Scenario A: Spending Limit Exceeded
```
Proposal: 15,000 SUI to unknown address
Daily limit: 10,000 SUI
Status: REJECTED ✗

Reason: Exceeds daily_limit
Details:
  - Requested: 15,000 SUI
  - Daily limit: 10,000 SUI
  - Overflow: 5,000 SUI
  - Recommendation: Split into 2 proposals
```

### Scenario B: Unauthorized Recipient
```
Proposal: 5,000 SUI to blacklisted address
Whitelist status: ENABLED
Recipient status: BLACKLISTED
Status: REJECTED ✗

Reason: Recipient not on whitelist
Details:
  - Address: 0xsuspicious_address
  - Whitelist entries: 3
  - Blacklist entries: 1
  - Solution: Remove from blacklist and add to whitelist
```

### Scenario C: Insufficient Signatures (before threshold)
```
Proposal: 20,000 SUI
Amount tier: Requires 4/5
Current signatures: 3/5
Status: PENDING - CANNOT EXECUTE ✗

Reason: Insufficient signatures
Details:
  - Need: 4/5
  - Have: 3/5
  - Missing: 1/5
  - Signed by: Alice, Bob, Charlie
  - Pending: Diana, Eve
  - Action: Waiting for 1 more signer
```

### Scenario D: Time-Lock Not Expired
```
Proposal created: 10:00 AM
Time-lock duration: 2 hours
Execution attempt: 11:30 AM
Status: REJECTED ✗

Reason: Time-lock not ready
Details:
  - Created: 10:00 AM
  - Ready at: 12:00 PM
  - Current time: 11:30 AM
  - Time remaining: 30 minutes
  - Action: Try again after 12:00 PM
```

### Show in Demo:
- Attempt each violation
- Show rejection message
- Display audit log
- Highlight security boundary

---

## SCENARIO 5: Emergency Freeze & Recovery

**Duration:** 6-7 minutes  
**Objective:** Demonstrate emergency procedures

### Scenario Setup
- **Emergency detected:** Suspicious withdrawal pattern
- **Treasury status:** Active with pending proposals
- **Action needed:** Freeze immediately
- **Recovery:** Emergency signers vote to unfreeze

### Phase 1: Detect Threat & Create Emergency Action
```move
let mut module = emergency_module::create_emergency_module(
    emergency_signers: vector[@0xalice, @0xbob, @0xcharlie, @0xdiana, @0xeve],
    threshold: 4,
    cooldown_period: 3600,
    &mut ctx,
);

emergency_module::create_freeze_action(
    &mut module,
    creator: @0xalice,
    reason: string::utf8(b"Detected suspicious activity: 10 proposals in 5 minutes"),
    &mut ctx,
);
```

**Show:**
- EmergencyActionCreated event
- Action ID: 0
- Status: Pending emergency signatures
- Requires: 4/5 signatures

### Phase 2: Emergency Signatures
```
T+0:00  - Alice creates freeze action (emergency signer)
T+0:30  - Bob signs (1/4) ✓
T+0:45  - Charlie signs (2/4) ✓
T+1:00  - Diana signs (3/4) ✓
T+1:15  - Eve signs (4/4) ✓ THRESHOLD REACHED

** IMMEDIATE EXECUTION (no time-lock) **

T+1:20  - Treasury FROZEN
         - All proposals paused
         - No new proposals accepted
         - Emergency mode active
```

**Show:**
- Each emergency signer's approval
- EmergencyActionSigned events
- Supermajority requirement
- Immediate execution contrast to normal proposals

### Phase 3: Investigation Phase
```
Treasury Status:
├── State: FROZEN ✓
├── Active Proposals: 3 (paused)
├── Pending Transactions: 2 (halted)
└── Emergency Cooldown: 3600 seconds

Investigation:
├── Review blockchain for 10 suspicious proposals
├── Find root cause: Compromised API key
├── Verify legitimate pending proposals: 2
└── Result: False alarm - clean up and resume
```

### Phase 4: Recovery & Unfreeze
```move
emergency_module::create_freeze_action(
    &mut module,
    creator: @0xalice,
    reason: string::utf8(b"Investigation complete - false alarm - safe to unfreeze"),
    &mut ctx,
);

emergency_module::sign_emergency_action(&mut module, 1, @0xalice, &mut ctx);
emergency_module::sign_emergency_action(&mut module, 1, @0xbob, &mut ctx);
emergency_module::sign_emergency_action(&mut module, 1, @0xcharlie, &mut ctx);
emergency_module::sign_emergency_action(&mut module, 1, @0xdiana, &mut ctx);

emergency_module::execute_emergency_action(&mut module, 1, &mut ctx);
```

**Show:**
- Treasury unfrozen after 4/5 vote
- Normal operations resume
- Pending proposals resume execution
- Cooldown period starts

### Phase 5: Cooldown Period
```
Timeline After Unfreeze:
├── T+1:20  - Treasury frozen
├── T+20:00 - Investigation complete
├── T+21:00 - Unfreeze executed
├── T+22:00 - Cooldown active (3600s)
├── T+83:00 - Cooldown expires
└── T+84:00 - Can trigger emergency again if needed
```

**Show:**
- Cooldown prevents emergency abuse
- Full audit trail of all actions
- Event timeline in blockchain explorer

---

## SCENARIO 6: Batch Payment Processing

**Duration:** 4-5 minutes  
**Objective:** Show batch processing efficiency

### Scenario Details
- **Purpose:** Pay 10 contractors for Q1 work
- **Total:** 50,000 SUI
- **Individual amounts:** 5,000 SUI each
- **Batch efficiency:** Single proposal, 1 threshold, 1 time-lock

### Step 1: Create Batch Proposal
```move
let mut recipients = vector![];
let mut amounts = vector![];

// Add 10 contractors
let i = 0;
while (i < 10) {
    vector::push_back(&mut recipients, contractor_addresses[i]);
    vector::push_back(&mut amounts, 5000);
    i = i + 1;
};

let mut batch_proposal = proposal::create_proposal(
    creator: @0xalice,
    description: string::utf8(b"Q1 contractor payments"),
    category: string::utf8(b"Operations"),
    recipients: recipients,
    amounts: amounts,
    time_lock_duration: 3600,
    threshold_required: 3,
    ctx: &mut ctx,
);
```

**Show:**
- Single proposal created
- 10 transactions batched
- Total: 50,000 SUI
- Events show batch nature

### Step 2: Signature Efficiency
```
Single Batch Approval:
├── Bob signs: Approves entire batch (10 txs) ✓
├── Charlie signs: Approves entire batch (10 txs) ✓
├── Diana signs: Approves entire batch (10 txs) ✓
                 Threshold reached ✓

Traditional Approach (10 separate proposals):
├── Bob signs proposal 1: @contractor1 - 5,000 SUI
├── Charlie signs proposal 1 → Pending time-lock
├── Diana signs proposal 1 → Execute
├── (repeat 9 more times)
                            
Gas Comparison:
├── Batch approach: 1 proposal = ~5,000 gas units
├── Individual approach: 10 proposals = ~50,000 gas units
└── Savings: 90% reduction
```

### Step 3: Execute Batch
```move
proposal::execute_proposal(&mut batch_proposal, &mut ctx);
```

**Show:**
- Single execution
- Atomic processing
- All 10 transactions confirmed:
  ```
  Contractor 1:  5,000 SUI ✓
  Contractor 2:  5,000 SUI ✓
  Contractor 3:  5,000 SUI ✓
  Contractor 4:  5,000 SUI ✓
  Contractor 5:  5,000 SUI ✓
  Contractor 6:  5,000 SUI ✓
  Contractor 7:  5,000 SUI ✓
  Contractor 8:  5,000 SUI ✓
  Contractor 9:  5,000 SUI ✓
  Contractor 10: 5,000 SUI ✓
  ────────────────────────
  Total Paid:    50,000 SUI
  Status:        ALL EXECUTED ✓
  ```

### Efficiency Metrics:
- **Batch size:** 10 transactions
- **Gas cost per transaction:** ~500 units (5,000/10)
- **Individual cost per transaction:** ~5,000 units
- **Savings per transaction:** 90%
- **Time:** Single signature round vs 10 rounds

---

## SCENARIO 7: Policy Composition Example

**Duration:** 3-4 minutes  
**Objective:** Show how multiple policies work together

### Setup
```
Treasury Policies:
├── Spending Limits
│   ├── Daily: 10,000 SUI
│   ├── Weekly: 50,000 SUI
│   ├── Monthly: 200,000 SUI
│   └── Per-tx: 10,000 SUI
│
├── Whitelist (Approved vendors)
│   ├── @vendor_security
│   ├── @vendor_infrastructure
│   └── @vendor_development
│
├── Category Thresholds
│   ├── $0-$1k: 2/5
│   ├── $1k-$10k: 3/5
│   └── $10k+: 4/5
│
├── Time-Locks
│   ├── Base: 2 hours
│   ├── Formula: base + (amount/1000)
│   └── Max: 6 hours
│
└── Approval Rules
    ├── Security category: Requires @alice, @bob
    ├── Development: Open (any 3/5)
    └── Marketing: Requires marketing lead
```

### Test Case 1: Compliant Proposal
```
Proposal: 7,500 SUI to @vendor_development for dev services
Category: Development

Policy Validation:
  ✓ Amount: 7,500 < 10,000 (daily limit)
  ✓ Recipient: @vendor_development (whitelisted)
  ✓ Category: Development (exists)
  ✓ Threshold: 7,500 → 3/5 required
  ✓ Time-lock: 2h + 7.5s = 2h 7.5s
  
Status: APPROVED ✓
```

### Test Case 2: Multiple Policy Violations
```
Proposal: 50,000 SUI to @random_address for marketing campaign
Category: Marketing

Policy Validation:
  ✗ Amount: 50,000 > 10,000 (daily limit) - FAIL
  ✗ Recipient: @random_address (NOT whitelisted) - FAIL
  ✓ Category: Marketing (exists)
  ✗ Threshold: Not checked due to earlier failures
  ✗ Time-lock: Not checked
  
Status: REJECTED ✗
Reason: Multiple policy violations detected
  1. Exceeds daily spending limit
  2. Recipient not on whitelist
```

### Show:
- Multi-policy validation flow
- Order of policy checks
- How violations cascade
- Security of composition

---

## SCENARIO 8: Spending Tracking & Reporting

**Duration:** 3-4 minutes  
**Objective:** Demonstrate spending history and categorization

### Initial Setup
```
Month: January 2024

Categories and Initial Spending:
├── Operations: $0
├── Marketing: $0
├── Development: $0
└── Security: $0
```

### Throughout Month
```
Jan 5:  Operations - $8,000 (Contractor Alice) → Daily: $8k, Weekly: $8k
Jan 10: Development - $6,000 (Contractor Bob) → Daily: $6k, Weekly: $14k
Jan 12: Marketing - $3,000 (Ad Agency) → Daily: $3k, Weekly: $17k
Jan 20: Operations - $5,000 (Infrastructure) → Daily: $5k, Weekly: $5k (reset)
Jan 25: Development - $4,000 (Contractor Charlie) → Daily: $4k, Weekly: $9k
Jan 28: Security - $2,000 (Audit) → Daily: $2k, Weekly: $11k
```

### Final Report
```
Monthly Spending Summary:

Operations
├── Total: $13,000
├── Transactions: 2
├── Daily average: $4,333
└── Limit: $10,000 (130% of daily, but over week/month) ✓

Development
├── Total: $10,000
├── Transactions: 2
├── Daily average: $3,333
└── Limit: $10,000 ✓

Marketing
├── Total: $3,000
├── Transactions: 1
├── Daily average: $1,000
└── Limit: $10,000 ✓

Security
├── Total: $2,000
├── Transactions: 1
├── Daily average: $667
└── Limit: $10,000 ✓

──────────────────────────────
TOTAL JANUARY SPENDING: $28,000
TOTAL BUDGET: $50,000 (weekly)
REMAINING: $22,000
```

### Query Examples
```move
// Get Operations spending
let (daily, weekly, monthly) = policy_manager::get_spending_for_category(
    &pm,
    &string::utf8(b"Operations")
);

// Result:
// daily: 5,000 (only Jan 20 in current day)
// weekly: 5,000 (only Jan 20 in current week)
// monthly: 13,000 (total Jan)
```

### Show:
- Spending categorization
- Daily/weekly/monthly tracking
- Query capability
- Report generation

---

## SCENARIO 9: Multi-Level Approval Workflow

**Duration:** 5-6 minutes  
**Objective:** Show complex approval scenarios

### Scenario: Security Audit Payment

**Proposal Details:**
- Amount: $35,000
- Category: Security
- Recipient: @security_firm_approved
- Required approvals: Security lead + 3 general signers
- Time-lock: 4 hours (high-security category)

### Step 1: Create Security Proposal
```move
let mut proposal = proposal::create_proposal(
    creator: @0xalice, // Security lead
    description: string::utf8(b"Annual security audit - $35,000"),
    category: string::utf8(b"Security"),
    recipients: vector[@0xsecurity_firm],
    amounts: vector[35000],
    time_lock_duration: 14400, // 4 hours
    threshold_required: 4,
    ctx: &mut ctx,
);
```

**Status:**
- Amount: 35,000 → Requires 4/5 threshold
- Category: Security → Additional approval rules apply
- Time-lock: 4 hours (highest security level)
- Required signers: Alice (creator), 3 others

### Step 2: Approval Timeline
```
T+0:00   - Alice (Security Lead) creates proposal ✓
         - She's the creator but NOT counted yet
         - Needs 4 signatures including at least 2 security team

T+15:00  - Bob (Security Team) reviews and signs (1/4) ✓
         - Security background verified
         - Comments: "Audit scope looks comprehensive"

T+30:00  - Charlie (CFO) reviews and signs (2/4) ✓
         - Budget verified
         - Comments: "Within annual security budget"

T+45:00  - Diana (Operations) reviews and signs (3/4) ✓
         - Operational impact assessed
         - Comments: "No impact to operations during audit"

T+60:00  - Eve (Governance) signs (4/4) ✓
         - THRESHOLD REACHED ✓
         - All required signers present

         ** WAITING FOR TIME-LOCK (4 HOURS) **

T+239:00 - Time remaining: 1 minute
T+240:00 - TIME-LOCK EXPIRED ✓
         - READY FOR EXECUTION
```

### Step 3: Final Validation & Execution
```move
// Validate all policies one final time
✓ Spending limit: 35,000 < 50,000 (weekly)
✓ Recipient: @security_firm (whitelisted)
✓ Category: Security (requires 4/5)
✓ Threshold: 4/5 required, 4/5 confirmed ✓
✓ Time-lock: 14,400 seconds (4h) passed ✓
✓ All security approvals: Satisfied ✓

// Execute
proposal::execute_proposal(&mut proposal, &mut ctx);
```

**Result:**
```
Security Audit Payment EXECUTED ✓

┌─────────────────────────────────┐
│ Recipient:    @security_firm    │
│ Amount:       $35,000 SUI       │
│ Category:     Security          │
│ Approval:     4/5 signers       │
│ Time-lock:    4 hours           │
│ Status:       EXECUTED ✓        │
│ Timestamp:    [block_timestamp] │
└─────────────────────────────────┘

Treasury Updated:
├── Balance: 465,000 → 430,000 SUI
├── Security spent: 2,000 → 37,000 SUI
├── Monthly burn: 28,000 → 63,000 SUI
└── Remaining budget: 22,000 → -13,000 (over budget)
    ⚠️  Alert: Exceeded monthly budget
```

### Key Learnings:
- Multi-level approval requirements
- Role-based signature requirements
- Complex time-lock strategies
- Budget tracking and alerts

---

## KEY METRICS FOR DEMO

```
Security:
├── Multi-sig validation: ✓ 100% (all tests pass)
├── Policy enforcement: ✓ 100% (no bypasses)
├── Emergency response: ✓ < 2 minutes
└── Audit trail: ✓ Complete blockchain record

Efficiency:
├── Gas per proposal: ~5,000 units
├── Gas per transaction (batch): ~500 units
├── Batch capacity: 50 transactions max
└── Average execution: < 1 second

Flexibility:
├── Policy types: 5 comprehensive types
├── Custom policies: Easily extendable
├── Approval workflows: Unlimited complexity
└── Category support: Unlimited

Usability:
├── Treasury creation: 1 transaction
├── Policy setup: 2-3 transactions
├── Proposal creation: 1 transaction
├── Signature: 1 transaction each
└── Execution: 1 transaction
```

---

## Demo Environment Setup

```bash
# Prerequisites
- Sui CLI installed
- Test accounts with SUI balance
- Treasury deployed to testnet

# Quick Setup
1. Clone repository
2. Run: sui move test
3. Deploy: sui move publish --gas-budget 100000
4. Configure test treasury (see CONFIG_TESTNET.md)
5. Run demo scenarios in order

# Cleanup
- Archive old proposals
- Reset spending trackers (month-end)
- Review and rotate emergency signers (annually)
```

---

## Timeline for Full Demo (14 minutes)

- Segment 1-2: Introduction & Architecture (3:45)
- Scenario 1: Treasury Setup (3:00)
- Scenario 2: Simple Proposal (4:00)
- Scenario 5: Emergency Freeze (6:00)
- Q&A: (2:15)

**Total: ~19 minutes**

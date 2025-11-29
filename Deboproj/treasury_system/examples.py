"""
Example usage of the Multi-Signature Treasury system
"""

from datetime import datetime, timedelta
from .treasury import Treasury
from .policies import (
    SpendingLimitPolicy, WhitelistPolicy, CategoryPolicy,
    TimeLockPolicy, AmountThresholdPolicy, ApprovalPolicy, PeriodType
)
from .models import Transaction, TransactionType, Category


def example_basic_treasury():
    print("=" * 60)
    print("EXAMPLE 1: Basic Treasury Setup and Operations")
    print("=" * 60)

    signers = {"alice", "bob", "charlie", "diana", "eve"}
    treasury = Treasury(
        treasury_id="dao_treasury_001",
        signers=signers,
        threshold=3,
        emergency_threshold=2,
        emergency_signers={"alice", "eve"}
    )

    print(f"\n✓ Treasury created with {len(signers)} signers")
    print(f"  Threshold: 3/5 required for execution")
    print(f"  Emergency threshold: 2/2")

    treasury.deposit("SUI", 100000.0, "alice")
    print(f"\n✓ Deposited 100,000 SUI")
    print(f"  Treasury balance: {treasury.get_all_balances()}")

    return treasury


def example_spending_policies(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 2: Setting Up Spending Limit Policies")
    print("=" * 60)

    spending_policy = SpendingLimitPolicy(
        policy_id="daily_limits",
        period_type=PeriodType.DAILY,
        global_limit=10000.0,
        max_per_transaction=5000.0
    )
    spending_policy.limit_per_category[Category.OPERATIONS] = 5000.0
    spending_policy.limit_per_category[Category.MARKETING] = 3000.0
    spending_policy.limit_per_category[Category.DEVELOPMENT] = 7000.0

    treasury.policy_manager.add_policy(spending_policy)
    print(f"\n✓ Added spending limit policy:")
    print(f"  Daily global limit: 10,000 SUI")
    print(f"  Max per transaction: 5,000 SUI")
    print(f"  Operations: 5,000 SUI/day")
    print(f"  Marketing: 3,000 SUI/day")
    print(f"  Development: 7,000 SUI/day")

    return treasury


def example_whitelist_policy(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 3: Whitelist Policy")
    print("=" * 60)

    whitelist_policy = WhitelistPolicy(policy_id="approved_recipients")
    whitelist_policy.add_recipient("0x1234567890abcdef")
    whitelist_policy.add_recipient("0xfedcba0987654321")

    temp_recipient = "0xtemp_address_001"
    expiry = datetime.now() + timedelta(days=30)
    whitelist_policy.add_temporary_recipient(temp_recipient, expiry)

    treasury.policy_manager.add_policy(whitelist_policy)
    print(f"\n✓ Added whitelist policy:")
    print(f"  Permanent recipients: 2")
    print(f"  Temporary recipients: 1 (expires in 30 days)")

    return treasury


def example_category_thresholds(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 4: Category-Based Thresholds")
    print("=" * 60)

    amount_threshold_policy = AmountThresholdPolicy(policy_id="amount_thresholds")
    amount_threshold_policy.add_threshold_range(0, 1000, 2)
    amount_threshold_policy.add_threshold_range(1000, 10000, 3)
    amount_threshold_policy.add_threshold_range(10000, float('inf'), 4)

    treasury.policy_manager.add_policy(amount_threshold_policy)
    print(f"\n✓ Added amount threshold policy:")
    print(f"  < 1,000 SUI: 2/5 signatures required")
    print(f"  1,000 - 10,000 SUI: 3/5 signatures required")
    print(f"  > 10,000 SUI: 4/5 signatures required")

    return treasury


def example_timelock_policy(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 5: Time-Lock Policy")
    print("=" * 60)

    timelock_policy = TimeLockPolicy(policy_id="timelocks", amount_factor=1000.0)
    timelock_policy.base_lock_duration[Category.OPERATIONS] = 3600
    timelock_policy.base_lock_duration[Category.MARKETING] = 7200
    timelock_policy.base_lock_duration[Category.DEVELOPMENT] = 1800

    treasury.policy_manager.add_policy(timelock_policy)
    print(f"\n✓ Added time-lock policy:")
    print(f"  Operations: 1 hour base + (amount / 1000 hours)")
    print(f"  Marketing: 2 hours base + (amount / 1000 hours)")
    print(f"  Development: 30 min base + (amount / 1000 hours)")

    return treasury


def example_proposal_workflow(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 6: Proposal Creation and Execution Workflow")
    print("=" * 60)

    current_time = datetime.now()

    transaction = Transaction(
        tx_id="txn_001",
        tx_type=TransactionType.TRANSFER,
        recipient="0x1234567890abcdef",
        amount=2500.0,
        coin_type="SUI",
        description="Monthly operations budget"
    )

    proposal_id = treasury.create_proposal(
        creator="alice",
        transactions=[transaction],
        category=Category.OPERATIONS,
        description="Q1 Operations Budget Request",
        current_time=current_time
    )

    print(f"\n✓ Proposal created: {proposal_id}")
    proposal = treasury.get_proposal(proposal_id)
    print(f"  Status: {proposal.status.value}")
    print(f"  Time-lock duration: {proposal.time_lock_duration} seconds")
    print(f"  Signatures required: {proposal.threshold_required}/5")

    treasury.sign_proposal(proposal_id, "alice", "sig_alice", current_time)
    treasury.sign_proposal(proposal_id, "bob", "sig_bob", current_time)
    treasury.sign_proposal(proposal_id, "charlie", "sig_charlie", current_time)

    print(f"\n✓ Signatures collected: 3/3 required")

    execution_time = current_time + timedelta(seconds=proposal.time_lock_duration + 1)
    treasury.execute_proposal(proposal_id, "alice", execution_time)

    print(f"\n✓ Proposal executed successfully")
    proposal = treasury.get_proposal(proposal_id)
    print(f"  Status: {proposal.status.value}")
    print(f"  Treasury balance: {treasury.get_all_balances()}")

    return treasury


def example_batch_transactions(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 7: Batch Transaction Execution")
    print("=" * 60)

    current_time = datetime.now()

    transactions = [
        Transaction(
            tx_id=f"batch_tx_{i}",
            tx_type=TransactionType.TRANSFER,
            recipient=f"0x{i:016d}",
            amount=500.0,
            coin_type="SUI",
            description=f"Batch payment {i+1}"
        )
        for i in range(5)
    ]
    
    for tx in transactions:
        for policy in treasury.policy_manager.policies.values():
            if hasattr(policy, 'add_recipient'):
                policy.add_recipient(tx.recipient)

    proposal_id = treasury.create_proposal(
        creator="bob",
        transactions=transactions,
        category=Category.MARKETING,
        description="Batch payment to partners",
        current_time=current_time
    )

    print(f"\n✓ Batch proposal created with {len(transactions)} transactions")
    print(f"  Total amount: {sum(t.amount for t in transactions)} SUI")

    for signer in ["bob", "charlie", "diana"]:
        treasury.sign_proposal(proposal_id, signer, f"sig_{signer}", current_time)

    execution_time = current_time + timedelta(seconds=7200)
    treasury.execute_proposal(proposal_id, "bob", execution_time)

    print(f"\n✓ Batch proposal executed")
    print(f"  Treasury balance: {treasury.get_all_balances()}")

    return treasury


def example_approval_policy(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 8: Approval Policy with Required Signers")
    print("=" * 60)

    approval_policy = ApprovalPolicy(policy_id="critical_approvals")
    approval_policy.add_required_signer(Category.DEVELOPMENT, "alice")
    approval_policy.add_veto_signer("eve")

    treasury.policy_manager.add_policy(approval_policy)

    print(f"\n✓ Added approval policy:")
    print(f"  Development proposals require: alice's signature")
    print(f"  Veto signers: eve (can block any proposal)")

    return treasury


def example_emergency_procedures(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 9: Emergency Freeze Procedures")
    print("=" * 60)

    current_time = datetime.now()

    print(f"\n✓ Treasury status:")
    print(f"  Frozen: {treasury.frozen}")

    action_id = treasury.trigger_emergency_freeze(
        initiator="alice",
        reason="Detected suspicious activity",
        current_time=current_time
    )

    print(f"\n✓ Emergency freeze initiated: {action_id}")

    treasury.sign_emergency_action(action_id, "alice", "sig_alice", current_time)
    treasury.sign_emergency_action(action_id, "eve", "sig_eve", current_time)

    print(f"✓ Emergency signatures collected (2/2)")

    treasury.execute_emergency_action(action_id, "alice", current_time)

    print(f"\n✓ Emergency freeze executed")
    print(f"  Treasury frozen: {treasury.frozen}")

    return treasury


def example_audit_trail(treasury):
    print("\n" + "=" * 60)
    print("EXAMPLE 10: Audit Trail and Logging")
    print("=" * 60)

    logs = treasury.get_audit_logs()
    print(f"\n✓ Total audit log entries: {len(logs)}")

    action_types = {}
    for log in logs:
        action_types[log.action] = action_types.get(log.action, 0) + 1

    print(f"\n  Action breakdown:")
    for action, count in sorted(action_types.items()):
        print(f"    {action}: {count}")

    print(f"\n  Recent actions:")
    for log in logs[-5:]:
        print(f"    {log.timestamp.strftime('%H:%M:%S')} - {log.action} by {log.actor}")

    return treasury


def run_all_examples():
    print("\n")
    print("╔" + "═" * 58 + "╗")
    print("║" + "MULTI-SIGNATURE TREASURY SYSTEM - EXAMPLES".center(58) + "║")
    print("╚" + "═" * 58 + "╝")

    treasury = example_basic_treasury()
    treasury = example_spending_policies(treasury)
    treasury = example_whitelist_policy(treasury)
    treasury = example_category_thresholds(treasury)
    treasury = example_timelock_policy(treasury)
    treasury = example_proposal_workflow(treasury)
    treasury = example_batch_transactions(treasury)
    treasury = example_approval_policy(treasury)
    treasury = example_emergency_procedures(treasury)
    example_audit_trail(treasury)

    print("\n" + "=" * 60)
    print("FINAL TREASURY STATE")
    print("=" * 60)
    state = treasury.get_treasury_state()
    print(f"\n✓ Treasury ID: {state['treasury_id']}")
    print(f"  Signers: {len(state['signers'])}")
    print(f"  Threshold: {state['threshold']}")
    print(f"  Frozen: {state['frozen']}")
    print(f"  Balances: {state['balances']}")
    print(f"  Total Spending: {state['total_spending']}")
    print(f"  Active Proposals: {state['active_proposals']}")
    print(f"  Policies Configured: {len(state['policies'])}")

    print("\n✓ All examples completed successfully!\n")


if __name__ == "__main__":
    run_all_examples()

import unittest
from datetime import datetime, timedelta
from .models import (
    Transaction, TransactionType, Category, Proposal, ProposalStatus,
    TreasuryBalance, PeriodType
)
from .policies import (
    SpendingLimitPolicy, WhitelistPolicy, CategoryPolicy, TimeLockPolicy,
    AmountThresholdPolicy, ApprovalPolicy, PolicyViolation, PolicyManager
)
from .treasury import Treasury
from .emergency import EmergencyModule


class TestTreasuryCreation(unittest.TestCase):
    def setUp(self):
        self.signers = {"signer1", "signer2", "signer3", "signer4", "signer5"}
        self.treasury = Treasury(
            treasury_id="test_treasury",
            signers=self.signers,
            threshold=3,
            emergency_threshold=3
        )

    def test_create_treasury_valid(self):
        self.assertEqual(self.treasury.config.threshold, 3)
        self.assertEqual(len(self.treasury.config.signers), 5)

    def test_create_treasury_invalid_threshold(self):
        with self.assertRaises(ValueError):
            Treasury(
                treasury_id="invalid",
                signers={"s1", "s2"},
                threshold=5
            )

    def test_deposit_funds(self):
        self.treasury.deposit("SUI", 1000.0, "signer1")
        self.assertEqual(self.treasury.get_balance("SUI"), 1000.0)

    def test_deposit_negative_amount(self):
        with self.assertRaises(ValueError):
            self.treasury.deposit("SUI", -100.0, "signer1")

    def test_multiple_coin_types(self):
        self.treasury.deposit("SUI", 1000.0, "signer1")
        self.treasury.deposit("USDC", 5000.0, "signer1")
        self.assertEqual(self.treasury.get_balance("SUI"), 1000.0)
        self.assertEqual(self.treasury.get_balance("USDC"), 5000.0)


class TestProposalCreation(unittest.TestCase):
    def setUp(self):
        self.signers = {"signer1", "signer2", "signer3", "signer4", "signer5"}
        self.treasury = Treasury(
            treasury_id="test_treasury",
            signers=self.signers,
            threshold=3
        )
        self.treasury.deposit("SUI", 10000.0, "signer1")

        self.transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

    def test_create_proposal_valid(self):
        proposal_id = self.treasury.create_proposal(
            creator="signer1",
            transactions=[self.transaction],
            category=Category.OPERATIONS,
            description="Test proposal"
        )
        self.assertIsNotNone(proposal_id)
        self.assertEqual(self.treasury.get_proposal(proposal_id).status, ProposalStatus.TIME_LOCKED)

    def test_create_proposal_non_signer(self):
        with self.assertRaises(PermissionError):
            self.treasury.create_proposal(
                creator="non_signer",
                transactions=[self.transaction],
                category=Category.OPERATIONS,
                description="Test proposal"
            )

    def test_create_proposal_empty_transactions(self):
        with self.assertRaises(ValueError):
            self.treasury.create_proposal(
                creator="signer1",
                transactions=[],
                category=Category.OPERATIONS,
                description="Test proposal"
            )

    def test_create_proposal_too_many_transactions(self):
        transactions = [
            Transaction(
                tx_id=f"tx{i}",
                tx_type=TransactionType.TRANSFER,
                recipient=f"recipient{i}",
                amount=10.0,
                coin_type="SUI"
            )
            for i in range(51)
        ]

        with self.assertRaises(ValueError):
            self.treasury.create_proposal(
                creator="signer1",
                transactions=transactions,
                category=Category.OPERATIONS,
                description="Test proposal"
            )


class TestMultiSig(unittest.TestCase):
    def setUp(self):
        self.signers = {"signer1", "signer2", "signer3", "signer4", "signer5"}
        self.treasury = Treasury(
            treasury_id="test_treasury",
            signers=self.signers,
            threshold=3
        )
        self.treasury.deposit("SUI", 10000.0, "signer1")

        self.transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        self.proposal_id = self.treasury.create_proposal(
            creator="signer1",
            transactions=[self.transaction],
            category=Category.OPERATIONS,
            description="Test proposal"
        )

    def test_sign_proposal(self):
        self.treasury.sign_proposal(
            proposal_id=self.proposal_id,
            signer="signer1",
            signature="sig1"
        )
        proposal = self.treasury.get_proposal(self.proposal_id)
        self.assertEqual(len(proposal.signatures), 1)

    def test_sign_proposal_non_signer(self):
        with self.assertRaises(PermissionError):
            self.treasury.sign_proposal(
                proposal_id=self.proposal_id,
                signer="non_signer",
                signature="sig1"
            )

    def test_sign_proposal_duplicate_signature(self):
        self.treasury.sign_proposal(
            proposal_id=self.proposal_id,
            signer="signer1",
            signature="sig1"
        )
        with self.assertRaises(ValueError):
            self.treasury.sign_proposal(
                proposal_id=self.proposal_id,
                signer="signer1",
                signature="sig2"
            )

    def test_execute_proposal_before_threshold(self):
        self.treasury.sign_proposal(
            proposal_id=self.proposal_id,
            signer="signer1",
            signature="sig1"
        )
        self.treasury.sign_proposal(
            proposal_id=self.proposal_id,
            signer="signer2",
            signature="sig2"
        )

        with self.assertRaises(ValueError):
            self.treasury.execute_proposal(
                proposal_id=self.proposal_id,
                executor="signer1"
            )

    def test_execute_proposal_success(self):
        current_time = datetime.now()
        proposal_id = self.treasury.create_proposal(
            creator="signer1",
            transactions=[self.transaction],
            category=Category.OPERATIONS,
            description="Test proposal",
            current_time=current_time
        )

        self.treasury.sign_proposal(
            proposal_id=proposal_id,
            signer="signer1",
            signature="sig1",
            current_time=current_time
        )
        self.treasury.sign_proposal(
            proposal_id=proposal_id,
            signer="signer2",
            signature="sig2",
            current_time=current_time
        )
        self.treasury.sign_proposal(
            proposal_id=proposal_id,
            signer="signer3",
            signature="sig3",
            current_time=current_time
        )

        execution_time = current_time + timedelta(seconds=3700)
        self.treasury.execute_proposal(
            proposal_id=proposal_id,
            executor="signer1",
            current_time=execution_time
        )

        proposal = self.treasury.get_proposal(proposal_id)
        self.assertEqual(proposal.status, ProposalStatus.EXECUTED)
        self.assertEqual(self.treasury.get_balance("SUI"), 9900.0)


class TestSpendingLimitPolicy(unittest.TestCase):
    def setUp(self):
        self.policy = SpendingLimitPolicy(
            policy_id="limit1",
            period_type=PeriodType.DAILY,
            global_limit=5000.0,
            max_per_transaction=1000.0
        )
        self.policy.limit_per_category[Category.OPERATIONS] = 2000.0
        self.policy.limit_per_category[Category.MARKETING] = 1000.0

    def test_max_per_transaction_validation(self):
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=1500.0,
            coin_type="SUI"
        )

        with self.assertRaises(PolicyViolation):
            self.policy.validate(
                transaction,
                {"category": Category.OPERATIONS, "current_time": datetime.now()}
            )

    def test_category_limit_validation(self):
        from .models import SpendingRecord
        current_time = datetime.now()
        transaction1 = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=1500.0,
            coin_type="SUI"
        )
        transaction2 = Transaction(
            tx_id="tx2",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient2",
            amount=800.0,
            coin_type="SUI"
        )

        record1 = SpendingRecord(
            amount=1500.0,
            timestamp=current_time,
            category=Category.OPERATIONS,
            proposal_id="p1",
            tx_hash="hash1"
        )
        self.policy.add_spending_record(record1)

        with self.assertRaises(PolicyViolation):
            self.policy.validate(
                transaction2,
                {"category": Category.OPERATIONS, "current_time": current_time}
            )

    def test_global_limit_validation(self):
        from .models import SpendingRecord
        current_time = datetime.now()
        record1 = SpendingRecord(
            amount=4500.0,
            timestamp=current_time,
            category=Category.OPERATIONS,
            proposal_id="p1",
            tx_hash="hash1"
        )
        self.policy.add_spending_record(record1)

        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=700.0,
            coin_type="SUI"
        )

        with self.assertRaises(PolicyViolation):
            self.policy.validate(
                transaction,
                {"category": Category.OPERATIONS, "current_time": current_time}
            )


class TestWhitelistPolicy(unittest.TestCase):
    def setUp(self):
        self.policy = WhitelistPolicy(policy_id="whitelist1")
        self.policy.add_recipient("recipient1")
        self.policy.add_recipient("recipient2")

    def test_approved_recipient_validation(self):
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        self.policy.validate(transaction, {"current_time": datetime.now()})

    def test_unapproved_recipient_validation(self):
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="unknown_recipient",
            amount=100.0,
            coin_type="SUI"
        )

        with self.assertRaises(PolicyViolation):
            self.policy.validate(transaction, {"current_time": datetime.now()})

    def test_temporary_recipient_validation(self):
        current_time = datetime.now()
        expiry = current_time + timedelta(hours=1)
        self.policy.add_temporary_recipient("temp_recipient", expiry)

        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="temp_recipient",
            amount=100.0,
            coin_type="SUI"
        )

        self.policy.validate(transaction, {"current_time": current_time})

    def test_blacklist_validation(self):
        self.policy.blacklist_recipient("recipient1")

        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        with self.assertRaises(PolicyViolation):
            self.policy.validate(transaction, {"current_time": datetime.now()})


class TestCategoryPolicy(unittest.TestCase):
    def setUp(self):
        self.policy = CategoryPolicy(policy_id="category1")
        self.policy.required_categories = {Category.OPERATIONS, Category.MARKETING}

    def test_valid_category_validation(self):
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        self.policy.validate(
            transaction,
            {"category": Category.OPERATIONS}
        )

    def test_invalid_category_validation(self):
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        with self.assertRaises(PolicyViolation):
            self.policy.validate(
                transaction,
                {"category": Category.RESEARCH}
            )

    def test_missing_category_validation(self):
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        with self.assertRaises(PolicyViolation):
            self.policy.validate(transaction, {})


class TestTimeLockPolicy(unittest.TestCase):
    def setUp(self):
        self.policy = TimeLockPolicy(policy_id="timelock1")
        self.policy.base_lock_duration[Category.OPERATIONS] = 3600
        self.policy.base_lock_duration[Category.MARKETING] = 7200
        self.policy.amount_factor = 1000.0

    def test_calculate_lock_duration_small_amount(self):
        duration = self.policy.calculate_lock_duration(500.0, Category.OPERATIONS)
        self.assertEqual(duration, 3600)

    def test_calculate_lock_duration_large_amount(self):
        duration = self.policy.calculate_lock_duration(5000.0, Category.OPERATIONS)
        expected = 3600 + (5000 / 1000) * 3600
        self.assertEqual(duration, int(expected))


class TestAmountThresholdPolicy(unittest.TestCase):
    def setUp(self):
        self.policy = AmountThresholdPolicy(policy_id="threshold1")
        self.policy.add_threshold_range(0, 1000, 2)
        self.policy.add_threshold_range(1000, 10000, 3)
        self.policy.add_threshold_range(10000, float('inf'), 4)

    def test_threshold_for_small_amount(self):
        threshold = self.policy.get_required_threshold(500.0)
        self.assertEqual(threshold, 2)

    def test_threshold_for_medium_amount(self):
        threshold = self.policy.get_required_threshold(5000.0)
        self.assertEqual(threshold, 3)

    def test_threshold_for_large_amount(self):
        threshold = self.policy.get_required_threshold(50000.0)
        self.assertEqual(threshold, 4)


class TestApprovalPolicy(unittest.TestCase):
    def setUp(self):
        self.policy = ApprovalPolicy(policy_id="approval1")
        self.policy.add_required_signer(Category.OPERATIONS, "signer1")
        self.policy.add_required_signer(Category.OPERATIONS, "signer2")
        self.policy.add_veto_signer("veto_signer")

    def test_required_signers_validation_success(self):
        from .models import Signature
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        signatures = {
            "signer1": Signature("signer1", "sig1", datetime.now(), "hash1"),
            "signer2": Signature("signer2", "sig2", datetime.now(), "hash1")
        }

        self.policy.validate(
            transaction,
            {"category": Category.OPERATIONS, "signatures": signatures}
        )

    def test_required_signers_validation_failure(self):
        from .models import Signature
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        signatures = {
            "signer1": Signature("signer1", "sig1", datetime.now(), "hash1")
        }

        with self.assertRaises(PolicyViolation):
            self.policy.validate(
                transaction,
                {"category": Category.OPERATIONS, "signatures": signatures}
            )

    def test_veto_signer_validation(self):
        from .models import Signature
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        signatures = {
            "veto_signer": Signature("veto_signer", "sig1", datetime.now(), "hash1")
        }

        with self.assertRaises(PolicyViolation):
            self.policy.validate(
                transaction,
                {"category": Category.OPERATIONS, "signatures": signatures}
            )


class TestEmergencyModule(unittest.TestCase):
    def setUp(self):
        self.emergency_signers = {"esigner1", "esigner2", "esigner3"}
        self.emergency = EmergencyModule(
            emergency_threshold=2,
            emergency_signers=self.emergency_signers
        )

    def test_create_emergency_action(self):
        action_id = self.emergency.create_emergency_action(
            initiator="esigner1",
            action_type="freeze",
            reason="Critical security issue",
            current_time=datetime.now()
        )
        self.assertIsNotNone(action_id)
        self.assertIn(action_id, self.emergency.actions)

    def test_sign_emergency_action(self):
        action_id = self.emergency.create_emergency_action(
            initiator="esigner1",
            action_type="freeze",
            reason="Critical security issue",
            current_time=datetime.now()
        )

        self.emergency.sign_emergency_action(
            action_id=action_id,
            signer="esigner2",
            signature="sig1",
            current_time=datetime.now()
        )

        action = self.emergency.get_action(action_id)
        self.assertEqual(len(action.signatures), 1)

    def test_can_execute_action(self):
        action_id = self.emergency.create_emergency_action(
            initiator="esigner1",
            action_type="freeze",
            reason="Critical security issue",
            current_time=datetime.now()
        )

        self.assertFalse(self.emergency.can_execute_action(action_id))

        self.emergency.sign_emergency_action(
            action_id=action_id,
            signer="esigner1",
            signature="sig1",
            current_time=datetime.now()
        )

        self.emergency.sign_emergency_action(
            action_id=action_id,
            signer="esigner2",
            signature="sig2",
            current_time=datetime.now()
        )

        self.assertTrue(self.emergency.can_execute_action(action_id))


class TestEmergencyWorkflow(unittest.TestCase):
    def setUp(self):
        self.signers = {"signer1", "signer2", "signer3", "signer4", "signer5"}
        self.treasury = Treasury(
            treasury_id="test_treasury",
            signers=self.signers,
            threshold=3,
            emergency_threshold=2,
            emergency_signers={"esigner1", "esigner2", "esigner3"}
        )
        self.treasury.deposit("SUI", 10000.0, "signer1")

    def test_trigger_emergency_freeze(self):
        current_time = datetime.now()
        action_id = self.treasury.trigger_emergency_freeze(
            initiator="esigner1",
            reason="Critical issue",
            current_time=current_time
        )
        self.assertIsNotNone(action_id)

    def test_execute_emergency_freeze(self):
        current_time = datetime.now()
        action_id = self.treasury.trigger_emergency_freeze(
            initiator="esigner1",
            reason="Critical issue",
            current_time=current_time
        )

        self.treasury.sign_emergency_action(
            action_id=action_id,
            signer="esigner1",
            signature="sig1",
            current_time=current_time
        )

        self.treasury.sign_emergency_action(
            action_id=action_id,
            signer="esigner2",
            signature="sig2",
            current_time=current_time
        )

        self.treasury.execute_emergency_action(
            action_id=action_id,
            executor="esigner1",
            current_time=current_time
        )

        self.assertTrue(self.treasury.frozen)

    def test_cannot_create_proposal_when_frozen(self):
        current_time = datetime.now()
        action_id = self.treasury.trigger_emergency_freeze(
            initiator="esigner1",
            reason="Critical issue",
            current_time=current_time
        )

        self.treasury.sign_emergency_action(
            action_id=action_id,
            signer="esigner1",
            signature="sig1",
            current_time=current_time
        )

        self.treasury.sign_emergency_action(
            action_id=action_id,
            signer="esigner2",
            signature="sig2",
            current_time=current_time
        )

        self.treasury.execute_emergency_action(
            action_id=action_id,
            executor="esigner1",
            current_time=current_time
        )

        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )

        with self.assertRaises(RuntimeError):
            self.treasury.create_proposal(
                creator="signer1",
                transactions=[transaction],
                category=Category.OPERATIONS,
                description="Test",
                current_time=current_time
            )


class TestSignerManagement(unittest.TestCase):
    def setUp(self):
        self.signers = {"signer1", "signer2", "signer3"}
        self.treasury = Treasury(
            treasury_id="test_treasury",
            signers=self.signers,
            threshold=2
        )

    def test_add_signer(self):
        self.treasury.add_signer("signer4", "signer1")
        self.assertIn("signer4", self.treasury.config.signers)

    def test_add_signer_by_non_signer(self):
        with self.assertRaises(PermissionError):
            self.treasury.add_signer("signer4", "non_signer")

    def test_remove_signer_success(self):
        self.treasury.add_signer("signer4", "signer1")
        self.treasury.remove_signer("signer4", "signer1")
        self.assertNotIn("signer4", self.treasury.config.signers)

    def test_remove_signer_below_threshold(self):
        self.treasury.remove_signer("signer2", "signer1")
        self.assertNotIn("signer2", self.treasury.config.signers)
        with self.assertRaises(ValueError):
            self.treasury.remove_signer("signer3", "signer1")


class TestAuditLog(unittest.TestCase):
    def setUp(self):
        self.signers = {"signer1", "signer2", "signer3"}
        self.treasury = Treasury(
            treasury_id="test_treasury",
            signers=self.signers,
            threshold=2
        )

    def test_audit_log_deposit(self):
        self.treasury.deposit("SUI", 1000.0, "signer1")
        logs = self.treasury.get_audit_logs()
        self.assertTrue(any(log.action == "deposit" for log in logs))

    def test_audit_log_create_proposal(self):
        self.treasury.deposit("SUI", 1000.0, "signer1")
        transaction = Transaction(
            tx_id="tx1",
            tx_type=TransactionType.TRANSFER,
            recipient="recipient1",
            amount=100.0,
            coin_type="SUI"
        )
        self.treasury.create_proposal(
            creator="signer1",
            transactions=[transaction],
            category=Category.OPERATIONS,
            description="Test"
        )
        logs = self.treasury.get_audit_logs()
        self.assertTrue(any(log.action == "create_proposal" for log in logs))


class TestPolicyManager(unittest.TestCase):
    def setUp(self):
        self.manager = PolicyManager()

    def test_add_policy(self):
        policy = SpendingLimitPolicy(
            policy_id="limit1",
            period_type=PeriodType.DAILY,
            global_limit=5000.0
        )
        self.manager.add_policy(policy)
        self.assertIn("limit1", self.manager.list_policies())

    def test_remove_policy(self):
        policy = SpendingLimitPolicy(
            policy_id="limit1",
            period_type=PeriodType.DAILY,
            global_limit=5000.0
        )
        self.manager.add_policy(policy)
        self.manager.remove_policy("limit1")
        self.assertNotIn("limit1", self.manager.list_policies())

    def test_get_policy(self):
        policy = SpendingLimitPolicy(
            policy_id="limit1",
            period_type=PeriodType.DAILY,
            global_limit=5000.0
        )
        self.manager.add_policy(policy)
        retrieved = self.manager.get_policy("limit1")
        self.assertEqual(retrieved.policy_id, "limit1")


if __name__ == "__main__":
    unittest.main()

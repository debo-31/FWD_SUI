from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Set, Tuple
from .models import Category, Transaction, PeriodType, SpendingRecord


class PolicyViolation(Exception):
    def __init__(self, policy_name: str, message: str):
        self.policy_name = policy_name
        self.message = message
        super().__init__(f"{policy_name}: {message}")


class BasePolicy(ABC):
    def __init__(self, policy_id: str, enabled: bool = True):
        self.policy_id = policy_id
        self.enabled = enabled

    @abstractmethod
    def validate(self, transaction: Transaction, context: Dict) -> None:
        pass

    @abstractmethod
    def get_policy_type(self) -> str:
        pass


class SpendingLimitPolicy(BasePolicy):
    def __init__(self, policy_id: str, period_type: PeriodType, limit_per_category=None, 
                 global_limit=None, max_per_transaction=None, enabled=True):
        super().__init__(policy_id, enabled)
        self.period_type = period_type
        self.limit_per_category = limit_per_category or {}
        self.global_limit = global_limit
        self.max_per_transaction = max_per_transaction
        self.spending_history = []

    def get_policy_type(self) -> str:
        return "spending_limit"

    def add_spending_record(self, record: SpendingRecord) -> None:
        self.spending_history.append(record)

    def get_period_start(self, current_time: datetime) -> datetime:
        if self.period_type == PeriodType.DAILY:
            return current_time.replace(hour=0, minute=0, second=0, microsecond=0)
        elif self.period_type == PeriodType.WEEKLY:
            days_since_monday = current_time.weekday()
            return (current_time - timedelta(days=days_since_monday)).replace(
                hour=0, minute=0, second=0, microsecond=0)
        elif self.period_type == PeriodType.MONTHLY:
            return current_time.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    def get_current_spending(self, category: Category, current_time: datetime) -> float:
        period_start = self.get_period_start(current_time)
        return sum(
            record.amount for record in self.spending_history
            if record.category == category and record.timestamp >= period_start
        )

    def get_global_spending(self, current_time: datetime) -> float:
        period_start = self.get_period_start(current_time)
        return sum(
            record.amount for record in self.spending_history
            if record.timestamp >= period_start
        )

    def validate(self, transaction: Transaction, context: Dict) -> None:
        if not self.enabled:
            return

        category = context.get("category", Category.OTHER)
        current_time = context.get("current_time", datetime.now())

        if self.max_per_transaction and transaction.amount > self.max_per_transaction:
            raise PolicyViolation(
                self.policy_id,
                f"Transaction amount {transaction.amount} exceeds max per transaction {self.max_per_transaction}"
            )

        if category in self.limit_per_category:
            current_spending = self.get_current_spending(category, current_time)
            limit = self.limit_per_category[category]
            if current_spending + transaction.amount > limit:
                raise PolicyViolation(
                    self.policy_id,
                    f"Spending limit exceeded for category {category.value}: "
                    f"current {current_spending} + {transaction.amount} > {limit}"
                )

        if self.global_limit:
            global_spending = self.get_global_spending(current_time)
            if global_spending + transaction.amount > self.global_limit:
                raise PolicyViolation(
                    self.policy_id,
                    f"Global spending limit exceeded: "
                    f"{global_spending} + {transaction.amount} > {self.global_limit}"
                )


class WhitelistPolicy(BasePolicy):
    def __init__(self, policy_id: str, enabled=True):
        super().__init__(policy_id, enabled)
        self.approved_recipients = set()
        self.blacklisted_recipients = set()
        self.temporary_entries = {}

    def get_policy_type(self) -> str:
        return "whitelist"

    def add_recipient(self, recipient: str) -> None:
        if recipient in self.blacklisted_recipients:
            raise ValueError(f"Recipient {recipient} is blacklisted")
        self.approved_recipients.add(recipient)

    def add_temporary_recipient(self, recipient: str, expires_at: datetime) -> None:
        if recipient in self.blacklisted_recipients:
            raise ValueError(f"Recipient {recipient} is blacklisted")
        self.temporary_entries[recipient] = expires_at

    def remove_recipient(self, recipient: str) -> None:
        self.approved_recipients.discard(recipient)
        self.temporary_entries.pop(recipient, None)

    def blacklist_recipient(self, recipient: str) -> None:
        self.approved_recipients.discard(recipient)
        self.temporary_entries.pop(recipient, None)
        self.blacklisted_recipients.add(recipient)

    def is_recipient_approved(self, recipient: str, current_time: datetime) -> bool:
        if recipient in self.blacklisted_recipients:
            return False

        if recipient in self.approved_recipients:
            return True

        if recipient in self.temporary_entries:
            expires_at = self.temporary_entries[recipient]
            if current_time < expires_at:
                return True
            else:
                del self.temporary_entries[recipient]

        return False

    def validate(self, transaction: Transaction, context: Dict) -> None:
        if not self.enabled:
            return

        current_time = context.get("current_time", datetime.now())

        if not self.is_recipient_approved(transaction.recipient, current_time):
            raise PolicyViolation(
                self.policy_id,
                f"Recipient {transaction.recipient} is not whitelisted"
            )


class CategoryPolicy(BasePolicy):
    def __init__(self, policy_id: str, enabled=True):
        super().__init__(policy_id, enabled)
        self.required_categories = set()
        self.category_thresholds = {}

    def get_policy_type(self) -> str:
        return "category"

    def set_category_threshold(self, category: Category, threshold: int) -> None:
        self.category_thresholds[category] = threshold

    def validate(self, transaction: Transaction, context: Dict) -> None:
        if not self.enabled:
            return

        category = context.get("category")

        if not category:
            raise PolicyViolation(
                self.policy_id,
                "Transaction must have a category assigned"
            )

        if self.required_categories and category not in self.required_categories:
            raise PolicyViolation(
                self.policy_id,
                f"Category {category.value} is not allowed. Allowed: "
                f"{[c.value for c in self.required_categories]}"
            )


class TimeLockPolicy(BasePolicy):
    def __init__(self, policy_id: str, amount_factor: float = 1000.0, enabled=True):
        super().__init__(policy_id, enabled)
        self.base_lock_duration = {}
        self.amount_factor = amount_factor

    def get_policy_type(self) -> str:
        return "timelock"

    def calculate_lock_duration(self, amount: float, category: Category) -> int:
        base = self.base_lock_duration.get(category, 3600)
        additional = int(amount / self.amount_factor) * 3600
        return base + additional

    def validate(self, transaction: Transaction, context: Dict) -> None:
        if not self.enabled:
            return

        category = context.get("category", Category.OTHER)
        lock_duration = self.calculate_lock_duration(transaction.amount, category)
        context["required_time_lock"] = max(
            context.get("required_time_lock", 0),
            lock_duration
        )


class AmountThresholdPolicy(BasePolicy):
    def __init__(self, policy_id: str, enabled=True):
        super().__init__(policy_id, enabled)
        self.thresholds = []

    def get_policy_type(self) -> str:
        return "amount_threshold"

    def add_threshold_range(self, min_amount: float, max_amount: float, required_threshold: int) -> None:
        self.thresholds.append((min_amount, max_amount, required_threshold))
        self.thresholds.sort(key=lambda x: x[0])

    def get_required_threshold(self, amount: float) -> int:
        for min_amt, max_amt, threshold in self.thresholds:
            if min_amt <= amount < max_amt:
                return threshold
        return self.thresholds[-1][2] if self.thresholds else 2

    def validate(self, transaction: Transaction, context: Dict) -> None:
        if not self.enabled:
            return

        required_threshold = self.get_required_threshold(transaction.amount)
        context["required_threshold"] = max(
            context.get("required_threshold", 0),
            required_threshold
        )


class ApprovalPolicy(BasePolicy):
    def __init__(self, policy_id: str, enabled=True):
        super().__init__(policy_id, enabled)
        self.required_signers_by_category = {}
        self.veto_signers = set()
        self.multi_tier_signers = {}

    def get_policy_type(self) -> str:
        return "approval"

    def add_required_signer(self, category: Category, signer: str) -> None:
        if category not in self.required_signers_by_category:
            self.required_signers_by_category[category] = set()
        self.required_signers_by_category[category].add(signer)

    def add_veto_signer(self, signer: str) -> None:
        self.veto_signers.add(signer)

    def set_multi_tier(self, signer: str, tier_level: int) -> None:
        self.multi_tier_signers[signer] = tier_level

    def validate(self, transaction: Transaction, context: Dict) -> None:
        if not self.enabled:
            return

        category = context.get("category", Category.OTHER)
        signatures = context.get("signatures", {})

        if category in self.required_signers_by_category:
            required = self.required_signers_by_category[category]
            if not required.issubset(set(signatures.keys())):
                missing = required - set(signatures.keys())
                raise PolicyViolation(
                    self.policy_id,
                    f"Missing required signers: {missing}"
                )

        for veto_signer in self.veto_signers:
            if veto_signer in signatures:
                raise PolicyViolation(
                    self.policy_id,
                    f"Veto signer {veto_signer} cannot approve this proposal"
                )


class PolicyManager:
    def __init__(self):
        self.policies: Dict[str, BasePolicy] = {}

    def add_policy(self, policy: BasePolicy) -> None:
        self.policies[policy.policy_id] = policy

    def remove_policy(self, policy_id: str) -> None:
        self.policies.pop(policy_id, None)

    def get_policy(self, policy_id: str) -> Optional[BasePolicy]:
        return self.policies.get(policy_id)

    def validate_transaction(self, transaction: Transaction, context: Dict) -> None:
        for policy in self.policies.values():
            policy.validate(transaction, context)

    def validate_all_transactions(self, transactions: List[Transaction], context: Dict) -> None:
        for transaction in transactions:
            self.validate_transaction(transaction, context)

    def get_required_time_lock(self, transactions: List[Transaction], category: Category) -> int:
        context = {"category": category, "required_time_lock": 0}
        for transaction in transactions:
            for policy in self.policies.values():
                if isinstance(policy, TimeLockPolicy):
                    policy.validate(transaction, context)
        return context.get("required_time_lock", 0)

    def get_required_threshold(self, transactions: List[Transaction]) -> int:
        context = {"required_threshold": 0}
        for transaction in transactions:
            max_amount = max(t.amount for t in transactions) if transactions else 0
            if max_amount > 0:
                for policy in self.policies.values():
                    if isinstance(policy, AmountThresholdPolicy):
                        policy.validate(transaction, context)
        return context.get("required_threshold", 2)

    def list_policies(self) -> List[str]:
        return list(self.policies.keys())

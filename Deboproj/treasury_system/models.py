from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Set
from datetime import datetime, timedelta
import hashlib
import json


class Category(str, Enum):
    OPERATIONS = "operations"
    MARKETING = "marketing"
    DEVELOPMENT = "development"
    RESEARCH = "research"
    SECURITY = "security"
    OTHER = "other"


class ProposalStatus(str, Enum):
    PENDING = "pending"
    TIME_LOCKED = "time_locked"
    READY_TO_EXECUTE = "ready_to_execute"
    EXECUTED = "executed"
    CANCELLED = "cancelled"
    FAILED = "failed"


class TransactionType(str, Enum):
    TRANSFER = "transfer"
    BURN = "burn"
    MINT = "mint"


class PeriodType(str, Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"


@dataclass
class Transaction:
    tx_id: str
    tx_type: TransactionType
    recipient: str
    amount: float
    coin_type: str = "SUI"
    description: str = ""
    metadata: Dict = field(default_factory=dict)

    def to_dict(self) -> Dict:
        return {
            "tx_id": self.tx_id,
            "tx_type": self.tx_type.value,
            "recipient": self.recipient,
            "amount": self.amount,
            "coin_type": self.coin_type,
            "description": self.description,
            "metadata": self.metadata
        }

    def compute_hash(self) -> str:
        data = json.dumps(self.to_dict(), sort_keys=True)
        return hashlib.sha256(data.encode()).hexdigest()


@dataclass
class Signature:
    signer: str
    signature: str
    timestamp: datetime
    tx_hash: str

    def verify_signature(self) -> bool:
        return len(self.signature) > 0 and len(self.signer) > 0


@dataclass
class Proposal:
    proposal_id: str
    creator: str
    transactions: List[Transaction]
    category: Category
    description: str
    threshold_required: int
    created_at: datetime
    time_lock_duration: int
    status: ProposalStatus = ProposalStatus.PENDING
    signatures: Dict[str, Signature] = field(default_factory=dict)
    executed_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None

    def can_execute(self, current_time: datetime) -> bool:
        time_locked_at = self.created_at + timedelta(seconds=self.time_lock_duration)
        return (current_time >= time_locked_at and
                len(self.signatures) >= self.threshold_required and
                self.status in [ProposalStatus.PENDING, ProposalStatus.TIME_LOCKED])

    def get_signature_count(self) -> int:
        return len(self.signatures)

    def is_signed_by(self, signer: str) -> bool:
        return signer in self.signatures


@dataclass
class SpendingRecord:
    amount: float
    timestamp: datetime
    category: Category
    proposal_id: str
    tx_hash: str


@dataclass
class TreasuryBalance:
    coin_type: str
    amount: float
    last_updated: datetime

    def deposit(self, amount: float) -> None:
        if amount <= 0:
            raise ValueError("Deposit amount must be positive")
        self.amount += amount
        self.last_updated = datetime.now()

    def withdraw(self, amount: float) -> bool:
        if amount <= 0:
            raise ValueError("Withdrawal amount must be positive")
        if amount > self.amount:
            return False
        self.amount -= amount
        self.last_updated = datetime.now()
        return True


@dataclass
class EmergencyAction:
    action_id: str
    action_type: str
    initiated_by: str
    initiated_at: datetime
    reason: str
    signatures: Dict[str, Signature] = field(default_factory=dict)
    executed: bool = False
    executed_at: Optional[datetime] = None


@dataclass
class TreasuryConfig:
    treasury_id: str
    signers: Set[str]
    threshold: int
    emergency_threshold: int
    emergency_signers: Set[str]
    emergency_cooldown: int = 86400
    last_emergency_at: Optional[datetime] = None

    def is_valid_signer(self, signer: str) -> bool:
        return signer in self.signers

    def can_trigger_emergency(self, current_time: datetime) -> bool:
        if self.last_emergency_at is None:
            return True
        elapsed = (current_time - self.last_emergency_at).total_seconds()
        return elapsed >= self.emergency_cooldown

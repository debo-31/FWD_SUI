from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Set
import uuid
from .models import (
    TreasuryBalance, TreasuryConfig, Proposal, Transaction,
    ProposalStatus, Category, Signature, SpendingRecord,
    EmergencyAction, PeriodType
)
from .policies import PolicyManager, PolicyViolation
from .emergency import EmergencyModule


@dataclass
class TreasuryAuditLog:
    timestamp: datetime
    action: str
    actor: str
    proposal_id: Optional[str] = None
    details: Dict = field(default_factory=dict)


class Treasury:
    def __init__(
        self,
        treasury_id: str,
        signers: Set[str],
        threshold: int,
        emergency_threshold: int = None,
        emergency_signers: Set[str] = None
    ):
        if threshold > len(signers):
            raise ValueError("Threshold cannot exceed number of signers")

        self.treasury_id = treasury_id
        self.config = TreasuryConfig(
            treasury_id=treasury_id,
            signers=signers,
            threshold=threshold,
            emergency_threshold=emergency_threshold or (len(signers) // 2 + 1),
            emergency_signers=emergency_signers or signers
        )

        self.balances: Dict[str, TreasuryBalance] = {}
        self.proposals: Dict[str, Proposal] = {}
        self.policy_manager = PolicyManager()
        self.emergency_module = EmergencyModule(
            emergency_threshold=self.config.emergency_threshold,
            emergency_signers=self.config.emergency_signers
        )
        self.spending_records: List[SpendingRecord] = []
        self.audit_logs: List[TreasuryAuditLog] = []
        self.frozen = False

    def add_signer(self, new_signer: str, authorizer: str) -> None:
        if authorizer not in self.config.signers:
            raise PermissionError(f"{authorizer} is not an authorized signer")

        self.config.signers.add(new_signer)
        self._audit_log("add_signer", authorizer, details={"new_signer": new_signer})

    def remove_signer(self, signer_to_remove: str, authorizer: str) -> None:
        if authorizer not in self.config.signers:
            raise PermissionError(f"{authorizer} is not an authorized signer")

        if len(self.config.signers) <= self.config.threshold:
            raise ValueError("Cannot remove signer when it would drop below threshold")

        self.config.signers.discard(signer_to_remove)
        self.config.emergency_signers.discard(signer_to_remove)
        self._audit_log("remove_signer", authorizer, details={"removed_signer": signer_to_remove})

    def deposit(self, coin_type: str, amount: float, depositor: str) -> None:
        if amount <= 0:
            raise ValueError("Deposit amount must be positive")

        if coin_type not in self.balances:
            self.balances[coin_type] = TreasuryBalance(
                coin_type=coin_type,
                amount=0.0,
                last_updated=datetime.now()
            )

        self.balances[coin_type].deposit(amount)
        self._audit_log("deposit", depositor, details={"coin_type": coin_type, "amount": amount})

    def get_balance(self, coin_type: str) -> float:
        if coin_type not in self.balances:
            return 0.0
        return self.balances[coin_type].amount

    def get_all_balances(self) -> Dict[str, float]:
        return {coin_type: balance.amount for coin_type, balance in self.balances.items()}

    def create_proposal(
        self,
        creator: str,
        transactions: List[Transaction],
        category: Category,
        description: str,
        current_time: Optional[datetime] = None
    ) -> str:
        if creator not in self.config.signers:
            raise PermissionError(f"{creator} is not an authorized signer")

        if self.frozen:
            raise RuntimeError("Treasury is frozen. Cannot create proposals.")

        if not transactions:
            raise ValueError("Proposal must contain at least one transaction")

        if len(transactions) > 50:
            raise ValueError("Maximum 50 transactions per proposal")

        current_time = current_time or datetime.now()

        for transaction in transactions:
            try:
                context = {
                    "category": category,
                    "current_time": current_time,
                    "signatures": {}
                }
                self.policy_manager.validate_transaction(transaction, context)
            except PolicyViolation as e:
                raise PolicyViolation(e.policy_name, f"Proposal validation failed: {e.message}")

        proposal_id = str(uuid.uuid4())
        time_lock_duration = self.policy_manager.get_required_time_lock(transactions, category)
        required_threshold = max(
            self.config.threshold,
            self.policy_manager.get_required_threshold(transactions)
        )

        proposal = Proposal(
            proposal_id=proposal_id,
            creator=creator,
            transactions=transactions,
            category=category,
            description=description,
            threshold_required=required_threshold,
            created_at=current_time,
            time_lock_duration=time_lock_duration,
            status=ProposalStatus.TIME_LOCKED
        )

        self.proposals[proposal_id] = proposal
        self._audit_log("create_proposal", creator, proposal_id, {
            "transactions": len(transactions),
            "category": category.value,
            "time_lock_duration": time_lock_duration,
            "threshold": required_threshold
        })

        return proposal_id

    def sign_proposal(self, proposal_id: str, signer: str, signature: str, current_time: Optional[datetime] = None) -> None:
        if proposal_id not in self.proposals:
            raise ValueError(f"Proposal {proposal_id} not found")

        if signer not in self.config.signers:
            raise PermissionError(f"{signer} is not an authorized signer")

        proposal = self.proposals[proposal_id]

        if proposal.status not in [ProposalStatus.PENDING, ProposalStatus.TIME_LOCKED]:
            raise ValueError(f"Cannot sign proposal in status {proposal.status.value}")

        if signer in proposal.signatures:
            raise ValueError(f"{signer} has already signed this proposal")

        current_time = current_time or datetime.now()
        tx_hash = self._compute_proposal_hash(proposal)

        proposal.signatures[signer] = Signature(
            signer=signer,
            signature=signature,
            timestamp=current_time,
            tx_hash=tx_hash
        )

        self._audit_log("sign_proposal", signer, proposal_id, {
            "signature_count": len(proposal.signatures)
        })

    def execute_proposal(self, proposal_id: str, executor: str, current_time: Optional[datetime] = None) -> None:
        if proposal_id not in self.proposals:
            raise ValueError(f"Proposal {proposal_id} not found")

        current_time = current_time or datetime.now()
        proposal = self.proposals[proposal_id]

        if not proposal.can_execute(current_time):
            time_locked_until = proposal.created_at + timedelta(seconds=proposal.time_lock_duration)
            raise ValueError(
                f"Proposal cannot execute. Time lock until {time_locked_until}, "
                f"threshold {proposal.get_signature_count()}/{proposal.threshold_required}"
            )

        try:
            for transaction in proposal.transactions:
                context = {
                    "category": proposal.category,
                    "current_time": current_time,
                    "signatures": proposal.signatures
                }
                self.policy_manager.validate_transaction(transaction, context)

                if transaction.coin_type not in self.balances:
                    raise ValueError(f"No balance for coin type {transaction.coin_type}")

                if not self.balances[transaction.coin_type].withdraw(transaction.amount):
                    raise ValueError(f"Insufficient balance for {transaction.coin_type}")

                spending_record = SpendingRecord(
                    amount=transaction.amount,
                    timestamp=current_time,
                    category=proposal.category,
                    proposal_id=proposal_id,
                    tx_hash=transaction.compute_hash()
                )
                self.spending_records.append(spending_record)

            proposal.status = ProposalStatus.EXECUTED
            proposal.executed_at = current_time
            self._audit_log("execute_proposal", executor, proposal_id, {
                "transactions": len(proposal.transactions),
                "total_amount": sum(t.amount for t in proposal.transactions)
            })

        except Exception as e:
            proposal.status = ProposalStatus.FAILED
            self._audit_log("execute_proposal_failed", executor, proposal_id, {"error": str(e)})
            raise

    def cancel_proposal(self, proposal_id: str, canceller: str, current_time: Optional[datetime] = None) -> None:
        if proposal_id not in self.proposals:
            raise ValueError(f"Proposal {proposal_id} not found")

        proposal = self.proposals[proposal_id]

        if proposal.creator != canceller and canceller not in proposal.signatures:
            raise PermissionError(f"{canceller} cannot cancel this proposal")

        if proposal.status == ProposalStatus.EXECUTED:
            raise ValueError("Cannot cancel an executed proposal")

        if proposal.status == ProposalStatus.CANCELLED:
            raise ValueError("Proposal already cancelled")

        current_time = current_time or datetime.now()
        proposal.status = ProposalStatus.CANCELLED
        proposal.cancelled_at = current_time
        self._audit_log("cancel_proposal", canceller, proposal_id)

    def get_proposal(self, proposal_id: str) -> Optional[Proposal]:
        return self.proposals.get(proposal_id)

    def list_proposals(self, status: Optional[ProposalStatus] = None) -> List[str]:
        if status is None:
            return list(self.proposals.keys())
        return [pid for pid, p in self.proposals.items() if p.status == status]

    def get_spending_history(self, category: Optional[Category] = None) -> List[SpendingRecord]:
        if category is None:
            return self.spending_records
        return [r for r in self.spending_records if r.category == category]

    def trigger_emergency_freeze(self, initiator: str, reason: str, current_time: Optional[datetime] = None) -> str:
        if initiator not in self.config.emergency_signers:
            raise PermissionError(f"{initiator} is not an emergency signer")

        current_time = current_time or datetime.now()

        if not self.config.can_trigger_emergency(current_time):
            raise RuntimeError("Emergency cooldown period still active")

        action_id = self.emergency_module.create_emergency_action(initiator, "freeze", reason, current_time)
        self._audit_log("emergency_freeze_initiated", initiator, details={"action_id": action_id, "reason": reason})
        return action_id

    def sign_emergency_action(self, action_id: str, signer: str, signature: str, current_time: Optional[datetime] = None) -> None:
        if signer not in self.config.emergency_signers:
            raise PermissionError(f"{signer} is not an emergency signer")

        current_time = current_time or datetime.now()
        self.emergency_module.sign_emergency_action(action_id, signer, signature, current_time)
        self._audit_log("emergency_action_signed", signer, details={"action_id": action_id})

    def execute_emergency_action(self, action_id: str, executor: str, current_time: Optional[datetime] = None) -> None:
        if action_id not in self.emergency_module.actions:
            raise ValueError(f"Emergency action {action_id} not found")

        action = self.emergency_module.actions[action_id]

        if len(action.signatures) < self.config.emergency_threshold:
            raise ValueError(
                f"Insufficient signatures: {len(action.signatures)}/{self.config.emergency_threshold}"
            )

        current_time = current_time or datetime.now()

        if action.action_type == "freeze":
            self.frozen = True
            self.config.last_emergency_at = current_time
            action.executed = True
            action.executed_at = current_time
            self._audit_log("emergency_action_executed", executor, details={"action_id": action_id, "type": "freeze"})

    def unfreeze_treasury(self, signer: str, reason: str, current_time: Optional[datetime] = None) -> None:
        if signer not in self.config.emergency_signers:
            raise PermissionError(f"{signer} is not an emergency signer")

        if not self.frozen:
            raise ValueError("Treasury is not frozen")

        current_time = current_time or datetime.now()
        self.frozen = False
        self._audit_log("treasury_unfrozen", signer, details={"reason": reason})

    def _compute_proposal_hash(self, proposal: Proposal) -> str:
        tx_hashes = [tx.compute_hash() for tx in proposal.transactions]
        return hash((proposal.proposal_id, tuple(tx_hashes), proposal.category.value))

    def _audit_log(
        self,
        action: str,
        actor: str,
        proposal_id: Optional[str] = None,
        details: Optional[Dict] = None
    ) -> None:
        log = TreasuryAuditLog(
            timestamp=datetime.now(),
            action=action,
            actor=actor,
            proposal_id=proposal_id,
            details=details or {}
        )
        self.audit_logs.append(log)

    def get_audit_logs(self) -> List[TreasuryAuditLog]:
        return self.audit_logs

    def get_treasury_state(self) -> Dict:
        return {
            "treasury_id": self.treasury_id,
            "signers": list(self.config.signers),
            "threshold": self.config.threshold,
            "emergency_threshold": self.config.emergency_threshold,
            "frozen": self.frozen,
            "balances": self.get_all_balances(),
            "active_proposals": len(self.list_proposals(ProposalStatus.TIME_LOCKED)),
            "total_spending": sum(r.amount for r in self.spending_records),
            "policies": self.policy_manager.list_policies()
        }

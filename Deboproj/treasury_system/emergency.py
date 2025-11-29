from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, Optional, Set
import uuid
from .models import EmergencyAction, Signature


class EmergencyModule:
    def __init__(self, emergency_threshold: int, emergency_signers: Set[str]):
        self.emergency_threshold = emergency_threshold
        self.emergency_signers = emergency_signers
        self.actions: Dict[str, EmergencyAction] = {}

    def create_emergency_action(
        self,
        initiator: str,
        action_type: str,
        reason: str,
        current_time: datetime
    ) -> str:
        if initiator not in self.emergency_signers:
            raise PermissionError(f"{initiator} is not an emergency signer")

        action_id = str(uuid.uuid4())
        action = EmergencyAction(
            action_id=action_id,
            action_type=action_type,
            initiated_by=initiator,
            initiated_at=current_time,
            reason=reason
        )
        self.actions[action_id] = action
        return action_id

    def sign_emergency_action(
        self,
        action_id: str,
        signer: str,
        signature: str,
        current_time: datetime
    ) -> None:
        if action_id not in self.actions:
            raise ValueError(f"Emergency action {action_id} not found")

        if signer not in self.emergency_signers:
            raise PermissionError(f"{signer} is not an emergency signer")

        action = self.actions[action_id]

        if signer in action.signatures:
            raise ValueError(f"{signer} has already signed this action")

        if action.executed:
            raise ValueError("Cannot sign an executed emergency action")

        action.signatures[signer] = Signature(
            signer=signer,
            signature=signature,
            timestamp=current_time,
            tx_hash=action.action_id
        )

    def get_action(self, action_id: str) -> Optional[EmergencyAction]:
        return self.actions.get(action_id)

    def can_execute_action(self, action_id: str) -> bool:
        if action_id not in self.actions:
            return False

        action = self.actions[action_id]
        return (len(action.signatures) >= self.emergency_threshold and
                not action.executed)

    def add_emergency_signer(self, signer: str) -> None:
        self.emergency_signers.add(signer)

    def remove_emergency_signer(self, signer: str) -> None:
        if len(self.emergency_signers) <= self.emergency_threshold:
            raise ValueError("Cannot remove signer when it would drop below threshold")
        self.emergency_signers.discard(signer)

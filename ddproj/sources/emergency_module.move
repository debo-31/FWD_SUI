module multi_sig_treasury::emergency_module {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::event;
    use std::string::String;
    use std::vector;

    const E_NOT_EMERGENCY_SIGNER: u64 = 1;
    const E_INSUFFICIENT_SIGNATURES: u64 = 2;
    const E_COOLDOWN_ACTIVE: u64 = 3;
    const E_INVALID_EMERGENCY_ACTION: u64 = 4;
    const E_NOT_AUTHORIZED: u64 = 5;

    const ACTION_FREEZE: u8 = 1;
    const ACTION_EMERGENCY_WITHDRAWAL: u8 = 2;
    const ACTION_PAUSE_PROPOSALS: u8 = 3;

    struct EmergencyModule has key {
        id: UID,
        emergency_signers: vector<address>,
        threshold: u64,
        cooldown_period: u64,
        last_emergency_time: u64,
        paused: bool,
        emergency_actions: Table<u64, EmergencyAction>,
        action_counter: u64,
    }

    struct EmergencyAction has store {
        action_id: u64,
        action_type: u8,
        creator: address,
        description: String,
        signatures: Table<address, bool>,
        signature_count: u64,
        created_at: u64,
        executed: bool,
        cancelled: bool,
    }

    struct EmergencyFroze has copy, drop {
        reason: String,
        frozen_by: address,
        timestamp: u64,
    }

    struct EmergencyWithdrawal has copy, drop {
        amount: u64,
        recipient: address,
        justification: String,
        timestamp: u64,
    }

    struct EmergencyActionCreated has copy, drop {
        action_id: u64,
        action_type: u8,
        creator: address,
        timestamp: u64,
    }

    struct EmergencyActionSigned has copy, drop {
        action_id: u64,
        signer: address,
        signature_count: u64,
        timestamp: u64,
    }

    struct EmergencyActionExecuted has copy, drop {
        action_id: u64,
        action_type: u8,
        timestamp: u64,
    }

    struct PausedProposals has copy, drop {
        paused: bool,
        reason: String,
        timestamp: u64,
    }

    public fun create_emergency_module(
        emergency_signers: vector<address>,
        threshold: u64,
        cooldown_period: u64,
        ctx: &mut TxContext,
    ): EmergencyModule {
        assert!(threshold > 0 && threshold <= vector::length(&emergency_signers), E_INVALID_EMERGENCY_ACTION);

        EmergencyModule {
            id: object::new(ctx),
            emergency_signers,
            threshold,
            cooldown_period,
            last_emergency_time: 0,
            paused: false,
            emergency_actions: table::new(ctx),
            action_counter: 0,
        }
    }

    public fun create_freeze_action(
        module: &mut EmergencyModule,
        creator: address,
        reason: String,
        ctx: &mut TxContext,
    ) {
        assert!(vector::contains(&module.emergency_signers, &creator), E_NOT_EMERGENCY_SIGNER);

        let action_id = module.action_counter;
        module.action_counter = module.action_counter + 1;

        let action = EmergencyAction {
            action_id,
            action_type: ACTION_FREEZE,
            creator,
            description: reason,
            signatures: table::new(ctx),
            signature_count: 0,
            created_at: tx_context::epoch(ctx),
            executed: false,
            cancelled: false,
        };

        table::add(&mut module.emergency_actions, action_id, action);

        event::emit(EmergencyActionCreated {
            action_id,
            action_type: ACTION_FREEZE,
            creator,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun create_emergency_withdrawal_action(
        module: &mut EmergencyModule,
        creator: address,
        amount: u64,
        recipient: address,
        justification: String,
        ctx: &mut TxContext,
    ) {
        assert!(vector::contains(&module.emergency_signers, &creator), E_NOT_EMERGENCY_SIGNER);

        let action_id = module.action_counter;
        module.action_counter = module.action_counter + 1;

        let action = EmergencyAction {
            action_id,
            action_type: ACTION_EMERGENCY_WITHDRAWAL,
            creator,
            description: justification,
            signatures: table::new(ctx),
            signature_count: 0,
            created_at: tx_context::epoch(ctx),
            executed: false,
            cancelled: false,
        };

        table::add(&mut module.emergency_actions, action_id, action);

        event::emit(EmergencyActionCreated {
            action_id,
            action_type: ACTION_EMERGENCY_WITHDRAWAL,
            creator,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun sign_emergency_action(
        module: &mut EmergencyModule,
        action_id: u64,
        signer: address,
        ctx: &mut TxContext,
    ) {
        assert!(vector::contains(&module.emergency_signers, &signer), E_NOT_EMERGENCY_SIGNER);
        assert!(table::contains(&module.emergency_actions, action_id), E_INVALID_EMERGENCY_ACTION);

        let action = table::borrow_mut(&mut module.emergency_actions, action_id);
        assert!(!action.executed, E_INVALID_EMERGENCY_ACTION);
        assert!(!action.cancelled, E_INVALID_EMERGENCY_ACTION);
        assert!(!table::contains(&action.signatures, signer), E_INVALID_EMERGENCY_ACTION);

        table::add(&mut action.signatures, signer, true);
        action.signature_count = action.signature_count + 1;

        event::emit(EmergencyActionSigned {
            action_id,
            signer,
            signature_count: action.signature_count,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun can_execute_emergency_action(module: &EmergencyModule, action_id: u64): bool {
        if (!table::contains(&module.emergency_actions, action_id)) {
            return false
        };

        let action = table::borrow(&module.emergency_actions, action_id);
        action.signature_count >= module.threshold && !action.executed && !action.cancelled
    }

    public fun execute_emergency_action(
        module: &mut EmergencyModule,
        action_id: u64,
        ctx: &mut TxContext,
    ) {
        let current_time = tx_context::epoch(ctx);
        
        assert!(
            current_time >= (module.last_emergency_time + module.cooldown_period),
            E_COOLDOWN_ACTIVE
        );

        assert!(table::contains(&module.emergency_actions, action_id), E_INVALID_EMERGENCY_ACTION);

        let action = table::borrow_mut(&mut module.emergency_actions, action_id);
        assert!(action.signature_count >= module.threshold, E_INSUFFICIENT_SIGNATURES);
        assert!(!action.executed, E_INVALID_EMERGENCY_ACTION);
        assert!(!action.cancelled, E_INVALID_EMERGENCY_ACTION);

        action.executed = true;
        module.last_emergency_time = current_time;

        event::emit(EmergencyActionExecuted {
            action_id,
            action_type: action.action_type,
            timestamp: current_time,
        });
    }

    public fun cancel_emergency_action(
        module: &mut EmergencyModule,
        action_id: u64,
        canceller: address,
        ctx: &mut TxContext,
    ) {
        assert!(vector::contains(&module.emergency_signers, &canceller), E_NOT_EMERGENCY_SIGNER);
        assert!(table::contains(&module.emergency_actions, action_id), E_INVALID_EMERGENCY_ACTION);

        let action = table::borrow_mut(&mut module.emergency_actions, action_id);
        assert!(!action.executed, E_INVALID_EMERGENCY_ACTION);

        action.cancelled = true;
    }

    public fun toggle_pause(
        module: &mut EmergencyModule,
        paused: bool,
        reason: String,
        ctx: &mut TxContext,
    ) {
        module.paused = paused;

        event::emit(PausedProposals {
            paused,
            reason,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun is_paused(module: &EmergencyModule): bool {
        module.paused
    }

    public fun get_emergency_signers(module: &EmergencyModule): &vector<address> {
        &module.emergency_signers
    }

    public fun get_emergency_threshold(module: &EmergencyModule): u64 {
        module.threshold
    }

    public fun get_action_status(
        module: &EmergencyModule,
        action_id: u64,
    ): (u64, bool, bool) {
        if (!table::contains(&module.emergency_actions, action_id)) {
            return (0, false, false)
        };

        let action = table::borrow(&module.emergency_actions, action_id);
        (action.signature_count, action.executed, action.cancelled)
    }

    public fun is_emergency_signer(module: &EmergencyModule, address: address): bool {
        vector::contains(&module.emergency_signers, &address)
    }

    public fun get_cooldown_period(module: &EmergencyModule): u64 {
        module.cooldown_period
    }

    public fun get_last_emergency_time(module: &EmergencyModule): u64 {
        module.last_emergency_time
    }
}

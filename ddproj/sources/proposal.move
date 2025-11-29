module multi_sig_treasury::proposal {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::event;
    use std::string::String;
    use std::vector;
    use std::option::{Self, Option};

    const E_INVALID_PROPOSAL: u64 = 1;
    const E_INSUFFICIENT_SIGNATURES: u64 = 2;
    const E_TIMELOCK_NOT_READY: u64 = 3;
    const E_NOT_AUTHORIZED: u64 = 4;
    const E_ALREADY_EXECUTED: u64 = 5;
    const E_ALREADY_CANCELLED: u64 = 6;
    const E_INVALID_SIGNATURE: u64 = 7;

    struct Proposal has key {
        id: UID,
        creator: address,
        description: String,
        category: String,
        total_amount: u64,
        recipients: vector<address>,
        amounts: vector<u64>,
        creation_time: u64,
        time_lock_until: u64,
        signatures: Table<address, bool>,
        signature_count: u64,
        executed: bool,
        cancelled: bool,
        threshold_required: u64,
    }

    struct Transaction has store, copy, drop {
        recipient: address,
        amount: u64,
    }

    struct ProposalCreated has copy, drop {
        proposal_id: address,
        creator: address,
        total_amount: u64,
        category: String,
        transaction_count: u64,
        time_lock_until: u64,
    }

    struct ProposalSigned has copy, drop {
        proposal_id: address,
        signer: address,
        signature_count: u64,
    }

    struct ProposalExecuted has copy, drop {
        proposal_id: address,
        transaction_count: u64,
        total_amount: u64,
        timestamp: u64,
    }

    struct ProposalCancelled has copy, drop {
        proposal_id: address,
        cancelled_by: address,
        timestamp: u64,
    }

    public fun create_proposal(
        creator: address,
        description: String,
        category: String,
        recipients: vector<address>,
        amounts: vector<u64>,
        time_lock_duration: u64,
        threshold_required: u64,
        ctx: &mut TxContext,
    ): Proposal {
        assert!(vector::length(&recipients) == vector::length(&amounts), E_INVALID_PROPOSAL);
        assert!(vector::length(&recipients) > 0, E_INVALID_PROPOSAL);
        assert!(vector::length(&recipients) <= 50, E_INVALID_PROPOSAL);

        let total_amount = calculate_total_amount(&amounts);
        let creation_time = tx_context::epoch(ctx);
        let time_lock_until = creation_time + time_lock_duration;

        let id = object::new(ctx);
        let proposal_id = object::uid_to_address(&id);

        event::emit(ProposalCreated {
            proposal_id,
            creator,
            total_amount,
            category,
            transaction_count: vector::length(&recipients),
            time_lock_until,
        });

        Proposal {
            id,
            creator,
            description,
            category,
            total_amount,
            recipients,
            amounts,
            creation_time,
            time_lock_until,
            signatures: table::new(ctx),
            signature_count: 0,
            executed: false,
            cancelled: false,
            threshold_required,
        }
    }

    public fun sign_proposal(
        proposal: &mut Proposal,
        signer: address,
        signers_list: &vector<address>,
        ctx: &mut TxContext,
    ) {
        assert!(!proposal.executed, E_ALREADY_EXECUTED);
        assert!(!proposal.cancelled, E_ALREADY_CANCELLED);
        assert!(vector::contains(signers_list, &signer), E_NOT_AUTHORIZED);
        assert!(!table::contains(&proposal.signatures, signer), E_INVALID_SIGNATURE);

        table::add(&mut proposal.signatures, signer, true);
        proposal.signature_count = proposal.signature_count + 1;

        let proposal_id = object::uid_to_address(&proposal.id);
        event::emit(ProposalSigned {
            proposal_id,
            signer,
            signature_count: proposal.signature_count,
        });
    }

    public fun can_execute(proposal: &Proposal, current_time: u64): bool {
        !proposal.executed && 
        !proposal.cancelled && 
        proposal.signature_count >= proposal.threshold_required &&
        current_time >= proposal.time_lock_until
    }

    public fun execute_proposal(
        proposal: &mut Proposal,
        ctx: &mut TxContext,
    ) {
        assert!(!proposal.executed, E_ALREADY_EXECUTED);
        assert!(!proposal.cancelled, E_ALREADY_CANCELLED);
        assert!(proposal.signature_count >= proposal.threshold_required, E_INSUFFICIENT_SIGNATURES);

        let current_time = tx_context::epoch(ctx);
        assert!(current_time >= proposal.time_lock_until, E_TIMELOCK_NOT_READY);

        proposal.executed = true;

        let proposal_id = object::uid_to_address(&proposal.id);
        event::emit(ProposalExecuted {
            proposal_id,
            transaction_count: vector::length(&proposal.recipients),
            total_amount: proposal.total_amount,
            timestamp: current_time,
        });
    }

    public fun cancel_proposal(
        proposal: &mut Proposal,
        canceller: address,
        ctx: &mut TxContext,
    ) {
        assert!(!proposal.executed, E_ALREADY_EXECUTED);
        assert!(!proposal.cancelled, E_ALREADY_CANCELLED);
        assert!(
            canceller == proposal.creator || proposal.signature_count == vector::length(&vector::empty()),
            E_NOT_AUTHORIZED
        );

        proposal.cancelled = true;

        let proposal_id = object::uid_to_address(&proposal.id);
        event::emit(ProposalCancelled {
            proposal_id,
            cancelled_by: canceller,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun get_proposal_info(proposal: &Proposal): (
        address,
        String,
        u64,
        u64,
        u64,
        u64,
        bool,
        bool,
    ) {
        (
            proposal.creator,
            proposal.category,
            proposal.total_amount,
            proposal.signature_count,
            proposal.threshold_required,
            proposal.time_lock_until,
            proposal.executed,
            proposal.cancelled,
        )
    }

    public fun get_recipients(proposal: &Proposal): &vector<address> {
        &proposal.recipients
    }

    public fun get_amounts(proposal: &Proposal): &vector<u64> {
        &proposal.amounts
    }

    public fun has_signed(proposal: &Proposal, signer: &address): bool {
        table::contains(&proposal.signatures, *signer)
    }

    public fun get_signature_count(proposal: &Proposal): u64 {
        proposal.signature_count
    }

    fun calculate_total_amount(amounts: &vector<u64>): u64 {
        let total = 0u64;
        let i = 0;
        while (i < vector::length(amounts)) {
            total = total + *vector::borrow(amounts, i);
            i = i + 1;
        };
        total
    }
}

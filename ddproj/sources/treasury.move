module multi_sig_treasury::treasury {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::vec_map::{Self, VecMap};
    use std::string::String;
    use std::vector;

    const E_INVALID_THRESHOLD: u64 = 1;
    const E_INVALID_SIGNERS: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INVALID_CATEGORY: u64 = 5;

    struct Treasury<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        signers: vector<address>,
        threshold: u64,
        total_supply: u64,
        spending_tracker: Table<String, u64>,
        categories: vector<String>,
        policies: VecMap<String, PolicyConfig>,
        frozen: bool,
        emergency_signers: vector<address>,
        emergency_threshold: u64,
    }

    struct PolicyConfig has store, copy {
        daily_limit: u64,
        weekly_limit: u64,
        monthly_limit: u64,
        enabled: bool,
    }

    struct Proposal has store, copy {
        id: u64,
        creator: address,
        description: String,
        category: String,
        amount: u64,
        recipient: address,
        signatures: u64,
        time_lock_until: u64,
        executed: bool,
        cancelled: bool,
    }

    struct TreasuryCreated has copy, drop {
        treasury_id: address,
        initial_signers: u64,
        threshold: u64,
        timestamp: u64,
    }

    struct DepositMade has copy, drop {
        treasury_id: address,
        amount: u64,
        timestamp: u64,
    }

    struct PolicyUpdated has copy, drop {
        treasury_id: address,
        policy_name: String,
        daily_limit: u64,
        timestamp: u64,
    }

    public fun create_treasury<T>(
        signers: vector<address>,
        threshold: u64,
        emergency_signers: vector<address>,
        emergency_threshold: u64,
        categories: vector<String>,
        ctx: &mut TxContext,
    ): Treasury<T> {
        assert!(threshold > 0 && threshold <= vector::length(&signers), E_INVALID_THRESHOLD);
        assert!(vector::length(&signers) > 0, E_INVALID_SIGNERS);
        assert!(
            emergency_threshold > 0 && emergency_threshold <= vector::length(&emergency_signers),
            E_INVALID_THRESHOLD
        );

        let id = object::new(ctx);
        let treasury_id = object::uid_to_address(&id);

        event::emit(TreasuryCreated {
            treasury_id,
            initial_signers: vector::length(&signers),
            threshold,
            timestamp: tx_context::epoch(ctx),
        });

        Treasury {
            id,
            balance: balance::zero(),
            signers,
            threshold,
            total_supply: 0,
            spending_tracker: table::new(ctx),
            categories,
            policies: vec_map::empty(),
            frozen: false,
            emergency_signers,
            emergency_threshold,
        }
    }

    public fun deposit<T>(
        treasury: &mut Treasury<T>,
        coin: Coin<T>,
        ctx: &mut TxContext,
    ) {
        assert!(!treasury.frozen, E_NOT_AUTHORIZED);
        
        let amount = coin::value(&coin);
        let treasury_id = object::uid_to_address(&treasury.id);

        balance::join(&mut treasury.balance, coin::into_balance(coin));
        treasury.total_supply = treasury.total_supply + amount;

        event::emit(DepositMade {
            treasury_id,
            amount,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun get_balance<T>(treasury: &Treasury<T>): u64 {
        balance::value(&treasury.balance)
    }

    public fun get_signers<T>(treasury: &Treasury<T>): &vector<address> {
        &treasury.signers
    }

    public fun get_threshold<T>(treasury: &Treasury<T>): u64 {
        treasury.threshold
    }

    public fun get_categories<T>(treasury: &Treasury<T>): &vector<String> {
        &treasury.categories
    }

    public fun is_frozen<T>(treasury: &Treasury<T>): bool {
        treasury.frozen
    }

    public fun freeze<T>(
        treasury: &mut Treasury<T>,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&treasury.emergency_signers, &sender), E_NOT_AUTHORIZED);
        treasury.frozen = true;
    }

    public fun unfreeze<T>(
        treasury: &mut Treasury<T>,
        signatures: u64,
        ctx: &mut TxContext,
    ) {
        assert!(signatures >= treasury.emergency_threshold, E_NOT_AUTHORIZED);
        treasury.frozen = false;
    }

    public fun add_policy<T>(
        treasury: &mut Treasury<T>,
        policy_name: String,
        daily_limit: u64,
        weekly_limit: u64,
        monthly_limit: u64,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&treasury.signers, &sender), E_NOT_AUTHORIZED);

        let policy = PolicyConfig {
            daily_limit,
            weekly_limit,
            monthly_limit,
            enabled: true,
        };

        vec_map::insert(&mut treasury.policies, policy_name, policy);

        let treasury_id = object::uid_to_address(&treasury.id);
        event::emit(PolicyUpdated {
            treasury_id,
            policy_name,
            daily_limit,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun get_policy<T>(
        treasury: &Treasury<T>,
        policy_name: &String,
    ): Option<PolicyConfig> {
        vec_map::try_get(&treasury.policies, policy_name)
    }

    public fun validate_category<T>(treasury: &Treasury<T>, category: &String): bool {
        vector::contains(&treasury.categories, category)
    }

    public fun update_spending_tracker<T>(
        treasury: &mut Treasury<T>,
        category: String,
        amount: u64,
    ) {
        if (table::contains(&treasury.spending_tracker, category)) {
            let current = table::borrow_mut(&mut treasury.spending_tracker, category);
            *current = *current + amount;
        } else {
            table::add(&mut treasury.spending_tracker, category, amount);
        }
    }

    public fun get_spending<T>(treasury: &Treasury<T>, category: &String): u64 {
        if (table::contains(&treasury.spending_tracker, *category)) {
            *table::borrow(&treasury.spending_tracker, *category)
        } else {
            0
        }
    }
}

module multi_sig_treasury::policy_manager {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use sui::event;
    use std::string::String;
    use std::vector;

    const E_POLICY_VIOLATED: u64 = 1;
    const E_INVALID_POLICY: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_LIMIT_EXCEEDED: u64 = 4;
    const E_ADDRESS_BLACKLISTED: u64 = 5;

    struct PolicyManager has key {
        id: UID,
        policies: VecMap<String, PolicyData>,
        whitelist: Table<address, bool>,
        blacklist: Table<address, bool>,
        category_thresholds: VecMap<String, ThresholdConfig>,
        spending_history: Table<String, PeriodSpending>,
        time_lock_policies: VecMap<String, TimeLockPolicy>,
    }

    struct PolicyData has store {
        policy_type: u8,
        daily_limit: u64,
        weekly_limit: u64,
        monthly_limit: u64,
        per_transaction_cap: u64,
        enabled: bool,
    }

    struct ThresholdConfig has store, copy {
        min_amount: u64,
        max_amount: u64,
        required_threshold: u64,
    }

    struct TimeLockPolicy has store, copy {
        category: String,
        base_duration: u64,
        amount_factor: u64,
    }

    struct PeriodSpending has store {
        daily_total: u64,
        weekly_total: u64,
        monthly_total: u64,
        last_reset: u64,
    }

    struct PolicyViolation has copy, drop {
        policy_type: String,
        reason: String,
        timestamp: u64,
    }

    struct WhitelistUpdated has copy, drop {
        address: address,
        whitelisted: bool,
        timestamp: u64,
    }

    struct ThresholdPolicyAdded has copy, drop {
        category: String,
        min_amount: u64,
        max_amount: u64,
        required_threshold: u64,
        timestamp: u64,
    }

    const POLICY_TYPE_SPENDING_LIMIT: u8 = 1;
    const POLICY_TYPE_WHITELIST: u8 = 2;
    const POLICY_TYPE_CATEGORY: u8 = 3;
    const POLICY_TYPE_TIME_LOCK: u8 = 4;
    const POLICY_TYPE_AMOUNT_THRESHOLD: u8 = 5;

    public fun create_policy_manager(ctx: &mut TxContext): PolicyManager {
        PolicyManager {
            id: object::new(ctx),
            policies: vec_map::empty(),
            whitelist: table::new(ctx),
            blacklist: table::new(ctx),
            category_thresholds: vec_map::empty(),
            spending_history: table::new(ctx),
            time_lock_policies: vec_map::empty(),
        }
    }

    public fun add_spending_limit_policy(
        pm: &mut PolicyManager,
        policy_name: String,
        daily_limit: u64,
        weekly_limit: u64,
        monthly_limit: u64,
        per_transaction_cap: u64,
        ctx: &mut TxContext,
    ) {
        let policy = PolicyData {
            policy_type: POLICY_TYPE_SPENDING_LIMIT,
            daily_limit,
            weekly_limit,
            monthly_limit,
            per_transaction_cap,
            enabled: true,
        };

        vec_map::insert(&mut pm.policies, policy_name, policy);
    }

    public fun add_whitelist_entry(
        pm: &mut PolicyManager,
        address: address,
        ctx: &mut TxContext,
    ) {
        assert!(!table::contains(&pm.blacklist, address), E_ADDRESS_BLACKLISTED);
        table::add(&mut pm.whitelist, address, true);

        event::emit(WhitelistUpdated {
            address,
            whitelisted: true,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun remove_whitelist_entry(
        pm: &mut PolicyManager,
        address: address,
        ctx: &mut TxContext,
    ) {
        if (table::contains(&pm.whitelist, address)) {
            table::remove(&mut pm.whitelist, address);
        };

        event::emit(WhitelistUpdated {
            address,
            whitelisted: false,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun add_blacklist_entry(
        pm: &mut PolicyManager,
        address: address,
        ctx: &mut TxContext,
    ) {
        if (table::contains(&pm.whitelist, address)) {
            table::remove(&mut pm.whitelist, address);
        };
        table::add(&mut pm.blacklist, address, true);
    }

    public fun add_category_threshold(
        pm: &mut PolicyManager,
        category: String,
        min_amount: u64,
        max_amount: u64,
        required_threshold: u64,
        ctx: &mut TxContext,
    ) {
        let config = ThresholdConfig {
            min_amount,
            max_amount,
            required_threshold,
        };

        vec_map::insert(&mut pm.category_thresholds, category, config);

        event::emit(ThresholdPolicyAdded {
            category,
            min_amount,
            max_amount,
            required_threshold,
            timestamp: tx_context::epoch(ctx),
        });
    }

    public fun add_time_lock_policy(
        pm: &mut PolicyManager,
        category: String,
        base_duration: u64,
        amount_factor: u64,
    ) {
        let policy = TimeLockPolicy {
            category,
            base_duration,
            amount_factor,
        };

        vec_map::insert(&mut pm.time_lock_policies, category, policy);
    }

    public fun validate_spending_limit(
        pm: &PolicyManager,
        policy_name: &String,
        amount: u64,
    ): bool {
        if (!vec_map::contains(&pm.policies, policy_name)) {
            return true
        };

        let policy = vec_map::get(&pm.policies, policy_name);
        amount <= policy.per_transaction_cap
    }

    public fun validate_whitelist(
        pm: &PolicyManager,
        recipient: address,
    ): bool {
        if (table::contains(&pm.blacklist, recipient)) {
            return false
        };

        if (table::is_empty(&pm.whitelist)) {
            return true
        };

        table::contains(&pm.whitelist, recipient)
    }

    public fun calculate_time_lock(
        pm: &PolicyManager,
        category: &String,
        amount: u64,
    ): u64 {
        if (!vec_map::contains(&pm.time_lock_policies, category)) {
            return 0
        };

        let policy = vec_map::get(&pm.time_lock_policies, category);
        let calculated_duration = amount / policy.amount_factor;
        policy.base_duration + calculated_duration
    }

    public fun get_threshold_for_amount(
        pm: &PolicyManager,
        category: &String,
        amount: u64,
    ): u64 {
        if (!vec_map::contains(&pm.category_thresholds, category)) {
            return 2
        };

        let config = vec_map::get(&pm.category_thresholds, category);
        
        if (amount >= config.min_amount && amount <= config.max_amount) {
            config.required_threshold
        } else if (amount < config.min_amount) {
            2
        } else {
            config.required_threshold
        }
    }

    public fun record_spending(
        pm: &mut PolicyManager,
        category: String,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        if (!table::contains(&pm.spending_history, category)) {
            table::add(&mut pm.spending_history, category, PeriodSpending {
                daily_total: amount,
                weekly_total: amount,
                monthly_total: amount,
                last_reset: tx_context::epoch(ctx),
            });
        } else {
            let spending = table::borrow_mut(&mut pm.spending_history, category);
            spending.daily_total = spending.daily_total + amount;
            spending.weekly_total = spending.weekly_total + amount;
            spending.monthly_total = spending.monthly_total + amount;
        };
    }

    public fun get_spending_for_category(
        pm: &PolicyManager,
        category: &String,
    ): (u64, u64, u64) {
        if (!table::contains(&pm.spending_history, *category)) {
            return (0, 0, 0)
        };

        let spending = table::borrow(&pm.spending_history, *category);
        (spending.daily_total, spending.weekly_total, spending.monthly_total)
    }

    public fun policy_exists(pm: &PolicyManager, policy_name: &String): bool {
        vec_map::contains(&pm.policies, policy_name)
    }

    public fun is_policy_enabled(pm: &PolicyManager, policy_name: &String): bool {
        if (!vec_map::contains(&pm.policies, policy_name)) {
            return false
        };

        vec_map::get(&pm.policies, policy_name).enabled
    }
}

#[cfg(test)]
module multi_sig_treasury::policy_manager_tests {
    use multi_sig_treasury::policy_manager;
    use sui::tx_context;
    use std::string::{Self, String};

    #[test]
    fun test_create_policy_manager() {
        let mut ctx = tx_context::dummy();
        let pm = policy_manager::create_policy_manager(&mut ctx);
        
        let policy_name = string::utf8(b"test_policy");
        assert!(!policy_manager::policy_exists(&pm, &policy_name));
    }

    #[test]
    fun test_add_spending_limit_policy() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let policy_name = string::utf8(b"daily_limit");
        policy_manager::add_spending_limit_policy(
            &mut pm,
            policy_name,
            1000,
            5000,
            20000,
            1000,
            &mut ctx,
        );

        assert!(policy_manager::policy_exists(&pm, &policy_name));
        assert!(policy_manager::is_policy_enabled(&pm, &policy_name));
    }

    #[test]
    fun test_validate_spending_limit() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let policy_name = string::utf8(b"daily_limit");
        policy_manager::add_spending_limit_policy(
            &mut pm,
            policy_name,
            1000,
            5000,
            20000,
            1000,
            &mut ctx,
        );

        assert!(policy_manager::validate_spending_limit(&pm, &policy_name, 500));
        assert!(policy_manager::validate_spending_limit(&pm, &policy_name, 1000));
        assert!(!policy_manager::validate_spending_limit(&pm, &policy_name, 1001));
    }

    #[test]
    fun test_add_whitelist_entry() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let address = @0x1;
        policy_manager::add_whitelist_entry(&mut pm, address, &mut ctx);

        assert!(policy_manager::validate_whitelist(&pm, address));
    }

    #[test]
    fun test_remove_whitelist_entry() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let address = @0x1;
        policy_manager::add_whitelist_entry(&mut pm, address, &mut ctx);
        assert!(policy_manager::validate_whitelist(&pm, address));

        policy_manager::remove_whitelist_entry(&mut pm, address, &mut ctx);
        assert!(!policy_manager::validate_whitelist(&pm, address));
    }

    #[test]
    fun test_add_blacklist_entry() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let address = @0x1;
        policy_manager::add_blacklist_entry(&mut pm, address, &mut ctx);

        assert!(!policy_manager::validate_whitelist(&pm, address));
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_whitelist_blacklisted_address() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let address = @0x1;
        policy_manager::add_blacklist_entry(&mut pm, address, &mut ctx);
        policy_manager::add_whitelist_entry(&mut pm, address, &mut ctx);
    }

    #[test]
    fun test_add_category_threshold() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let category = string::utf8(b"Operations");
        policy_manager::add_category_threshold(
            &mut pm,
            category,
            0,
            1000,
            2,
            &mut ctx,
        );

        let threshold = policy_manager::get_threshold_for_amount(&pm, &category, 500);
        assert!(threshold == 2);
    }

    #[test]
    fun test_get_threshold_for_amount() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let category = string::utf8(b"Operations");
        policy_manager::add_category_threshold(
            &mut pm,
            category,
            0,
            1000,
            2,
            &mut ctx,
        );
        policy_manager::add_category_threshold(
            &mut pm,
            string::utf8(b"Large"),
            1001,
            10000,
            3,
            &mut ctx,
        );

        let threshold1 = policy_manager::get_threshold_for_amount(&pm, &category, 500);
        assert!(threshold1 == 2);

        let threshold2 = policy_manager::get_threshold_for_amount(&pm, &string::utf8(b"Large"), 5000);
        assert!(threshold2 == 3);
    }

    #[test]
    fun test_add_time_lock_policy() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let category = string::utf8(b"Operations");
        policy_manager::add_time_lock_policy(
            &mut pm,
            category,
            3600,
            1000,
        );

        let time_lock = policy_manager::calculate_time_lock(&pm, &category, 5000);
        assert!(time_lock == 3600 + 5);
    }

    #[test]
    fun test_calculate_time_lock_with_amount() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let category = string::utf8(b"Ops");
        policy_manager::add_time_lock_policy(&mut pm, category, 1000, 100);

        let time_lock1 = policy_manager::calculate_time_lock(&pm, &category, 100);
        assert!(time_lock1 == 1001);

        let time_lock2 = policy_manager::calculate_time_lock(&pm, &category, 1000);
        assert!(time_lock2 == 1010);
    }

    #[test]
    fun test_record_spending() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let category = string::utf8(b"Operations");
        policy_manager::record_spending(&mut pm, category, 100, &mut ctx);

        let (daily, weekly, monthly) = policy_manager::get_spending_for_category(&pm, &category);
        assert!(daily == 100);
        assert!(weekly == 100);
        assert!(monthly == 100);
    }

    #[test]
    fun test_record_spending_multiple_times() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);
        
        let category = string::utf8(b"Operations");
        policy_manager::record_spending(&mut pm, category, 100, &mut ctx);
        policy_manager::record_spending(&mut pm, category, 50, &mut ctx);

        let (daily, weekly, monthly) = policy_manager::get_spending_for_category(&pm, &category);
        assert!(daily == 150);
        assert!(weekly == 150);
        assert!(monthly == 150);
    }

    #[test]
    fun test_get_spending_nonexistent_category() {
        let mut ctx = tx_context::dummy();
        let pm = policy_manager::create_policy_manager(&mut ctx);
        
        let category = string::utf8(b"NonExistent");
        let (daily, weekly, monthly) = policy_manager::get_spending_for_category(&pm, &category);
        
        assert!(daily == 0);
        assert!(weekly == 0);
        assert!(monthly == 0);
    }

    #[test]
    fun test_validate_whitelist_empty() {
        let mut ctx = tx_context::dummy();
        let pm = policy_manager::create_policy_manager(&mut ctx);
        
        assert!(policy_manager::validate_whitelist(&pm, @0x1));
        assert!(policy_manager::validate_whitelist(&pm, @0x2));
    }
}

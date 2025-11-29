#[cfg(test)]
module multi_sig_treasury::integration_tests {
    use multi_sig_treasury::treasury;
    use multi_sig_treasury::proposal;
    use multi_sig_treasury::policy_manager;
    use multi_sig_treasury::emergency_module;
    use sui::tx_context;
    use std::string::{Self, String};
    use std::vector;

    struct TestCoin {}

    #[test]
    fun test_complete_proposal_lifecycle() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2, @0x3];

        let _treasury = treasury::create_treasury<TestCoin>(
            signers,
            2,
            vector[@0x1],
            1,
            vector[string::utf8(b"Operations")],
            &mut ctx,
        );

        let mut prop = proposal::create_proposal(
            @0x1,
            string::utf8(b"Proposal 1"),
            string::utf8(b"Operations"),
            vector[@0x4, @0x5],
            vector[100, 200],
            0,
            2,
            &mut ctx,
        );

        proposal::sign_proposal(&mut prop, @0x1, &signers, &mut ctx);
        proposal::sign_proposal(&mut prop, @0x2, &signers, &mut ctx);

        assert!(proposal::can_execute(&prop, tx_context::epoch(&ctx)));

        proposal::execute_proposal(&mut prop, &mut ctx);

        let (_creator, _category, total_amount, _sig_count, _threshold, _time_lock, executed, _cancelled) =
            proposal::get_proposal_info(&prop);

        assert!(total_amount == 300);
        assert!(executed);
    }

    #[test]
    fun test_policy_validation_workflow() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);

        let ops = string::utf8(b"Operations");

        policy_manager::add_spending_limit_policy(
            &mut pm,
            ops,
            1000,
            5000,
            20000,
            500,
            &mut ctx,
        );

        policy_manager::add_category_threshold(
            &mut pm,
            ops,
            0,
            1000,
            2,
            &mut ctx,
        );

        policy_manager::add_whitelist_entry(&mut pm, @0x1, &mut ctx);
        policy_manager::add_whitelist_entry(&mut pm, @0x2, &mut ctx);

        policy_manager::record_spending(&mut pm, ops, 100, &mut ctx);

        assert!(policy_manager::validate_spending_limit(&pm, &ops, 400));
        assert!(!policy_manager::validate_spending_limit(&pm, &ops, 600));

        assert!(policy_manager::validate_whitelist(&pm, @0x1));
        assert!(policy_manager::validate_whitelist(&pm, @0x2));
        assert!(!policy_manager::validate_whitelist(&pm, @0x3));

        let (daily, _weekly, _monthly) = policy_manager::get_spending_for_category(&pm, &ops);
        assert!(daily == 100);
    }

    #[test]
    fun test_emergency_freeze_workflow() {
        let mut ctx = tx_context::dummy();

        let mut treasury = treasury::create_treasury<TestCoin>(
            vector[@0x1, @0x2],
            2,
            vector[@0x1, @0x2, @0x3],
            2,
            vector[string::utf8(b"Operations")],
            &mut ctx,
        );

        assert!(!treasury::is_frozen(&treasury));

        tx_context::set_sender(&mut ctx, @0x1);
        treasury::freeze(&mut treasury, &mut ctx);

        assert!(treasury::is_frozen(&treasury));

        treasury::unfreeze(&mut treasury, 2, &mut ctx);
        assert!(!treasury::is_frozen(&treasury));
    }

    #[test]
    fun test_multi_category_spending_tracking() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);

        let ops = string::utf8(b"Operations");
        let marketing = string::utf8(b"Marketing");
        let dev = string::utf8(b"Development");

        policy_manager::record_spending(&mut pm, ops, 100, &mut ctx);
        policy_manager::record_spending(&mut pm, marketing, 200, &mut ctx);
        policy_manager::record_spending(&mut pm, dev, 300, &mut ctx);

        let (ops_daily, _, _) = policy_manager::get_spending_for_category(&pm, &ops);
        let (mark_daily, _, _) = policy_manager::get_spending_for_category(&pm, &marketing);
        let (dev_daily, _, _) = policy_manager::get_spending_for_category(&pm, &dev);

        assert!(ops_daily == 100);
        assert!(mark_daily == 200);
        assert!(dev_daily == 300);
    }

    #[test]
    fun test_dynamic_threshold_based_on_amount() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);

        let category = string::utf8(b"Operations");

        policy_manager::add_category_threshold(
            &mut pm,
            string::utf8(b"Small"),
            0,
            1000,
            2,
            &mut ctx,
        );

        policy_manager::add_category_threshold(
            &mut pm,
            string::utf8(b"Medium"),
            1001,
            10000,
            3,
            &mut ctx,
        );

        policy_manager::add_category_threshold(
            &mut pm,
            string::utf8(b"Large"),
            10001,
            100000,
            4,
            &mut ctx,
        );

        let small_threshold = policy_manager::get_threshold_for_amount(
            &pm,
            &category,
            500,
        );
        let medium_threshold = policy_manager::get_threshold_for_amount(
            &pm,
            &category,
            5000,
        );
        let large_threshold = policy_manager::get_threshold_for_amount(
            &pm,
            &category,
            50000,
        );

        assert!(small_threshold == 2);
        assert!(medium_threshold == 3);
        assert!(large_threshold == 4);
    }

    #[test]
    fun test_timelock_calculation_with_amount() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);

        let category = string::utf8(b"Operations");
        policy_manager::add_time_lock_policy(&mut pm, category, 3600, 1000);

        let small_lock = policy_manager::calculate_time_lock(&pm, &category, 1000);
        let large_lock = policy_manager::calculate_time_lock(&pm, &category, 10000);
        let huge_lock = policy_manager::calculate_time_lock(&pm, &category, 100000);

        assert!(small_lock == 3601);
        assert!(large_lock == 3610);
        assert!(huge_lock == 3700);
    }

    #[test]
    fun test_proposal_with_multiple_transactions() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];

        let recipients = vector[@0x3, @0x4, @0x5, @0x6, @0x7];
        let amounts = vector[100, 200, 300, 400, 500];

        let mut prop = proposal::create_proposal(
            @0x1,
            string::utf8(b"Batch payment"),
            string::utf8(b"Operations"),
            recipients,
            amounts,
            0,
            2,
            &mut ctx,
        );

        let (_creator, _category, total_amount, _sig, _thresh, _lock, _exec, _canc) =
            proposal::get_proposal_info(&prop);

        assert!(total_amount == 1500);
        assert!(vector::length(proposal::get_recipients(&prop)) == 5);
        assert!(vector::length(proposal::get_amounts(&prop)) == 5);

        proposal::sign_proposal(&mut prop, @0x1, &signers, &mut ctx);
        proposal::sign_proposal(&mut prop, @0x2, &signers, &mut ctx);
        proposal::execute_proposal(&mut prop, &mut ctx);
    }

    #[test]
    fun test_emergency_action_lifecycle() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2, @0x3];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            2,
            0,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Critical issue detected"),
            &mut ctx,
        );

        emergency_module::sign_emergency_action(&mut module, 0, @0x1, &mut ctx);
        assert!(!emergency_module::can_execute_emergency_action(&module, 0));

        emergency_module::sign_emergency_action(&mut module, 0, @0x2, &mut ctx);
        assert!(emergency_module::can_execute_emergency_action(&module, 0));

        emergency_module::execute_emergency_action(&mut module, 0, &mut ctx);

        let (_sig_count, executed, _cancelled) = emergency_module::get_action_status(&module, 0);
        assert!(executed);
    }

    #[test]
    fun test_blacklist_whitelist_interaction() {
        let mut ctx = tx_context::dummy();
        let mut pm = policy_manager::create_policy_manager(&mut ctx);

        let trusted_addr = @0x1;
        let suspicious_addr = @0x2;
        let neutral_addr = @0x3;

        policy_manager::add_whitelist_entry(&mut pm, trusted_addr, &mut ctx);
        policy_manager::add_blacklist_entry(&mut pm, suspicious_addr, &mut ctx);

        assert!(policy_manager::validate_whitelist(&pm, trusted_addr));
        assert!(!policy_manager::validate_whitelist(&pm, suspicious_addr));
        assert!(!policy_manager::validate_whitelist(&pm, neutral_addr));
    }

    #[test]
    fun test_emergency_pause_proposals() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            3600,
            &mut ctx,
        );

        assert!(!emergency_module::is_paused(&module));

        emergency_module::toggle_pause(
            &mut module,
            true,
            string::utf8(b"System maintenance"),
            &mut ctx,
        );

        assert!(emergency_module::is_paused(&module));
    }
}

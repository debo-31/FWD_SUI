#[cfg(test)]
module multi_sig_treasury::treasury_tests {
    use multi_sig_treasury::treasury;
    use sui::object;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::test_utils;
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};
    use std::vector;

    struct TestCoin {}

    #[test]
    fun test_create_treasury_valid_params() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2, @0x3];
        let threshold = 2;
        let emergency_signers = vector[@0x1, @0x2];
        let emergency_threshold = 2;
        let categories = vector[
            string::utf8(b"Operations"),
            string::utf8(b"Marketing"),
            string::utf8(b"Development"),
        ];

        let treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        assert!(treasury::get_threshold(&treasury) == 2);
        assert!(treasury::get_balance(&treasury) == 0);
        assert!(vector::length(treasury::get_signers(&treasury)) == 3);
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_create_treasury_empty_signers() {
        let mut ctx = tx_context::dummy();
        let signers = vector[];
        let threshold = 1;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[];

        let _treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_create_treasury_invalid_threshold() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];
        let threshold = 5;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[];

        let _treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );
    }

    #[test]
    fun test_validate_category() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];
        let threshold = 2;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[
            string::utf8(b"Operations"),
            string::utf8(b"Marketing"),
        ];

        let treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        let ops = string::utf8(b"Operations");
        let invalid = string::utf8(b"Invalid");

        assert!(treasury::validate_category(&treasury, &ops));
        assert!(!treasury::validate_category(&treasury, &invalid));
    }

    #[test]
    fun test_treasury_freeze_unfreeze() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];
        let threshold = 2;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[];

        let mut treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        assert!(!treasury::is_frozen(&treasury));

        tx_context::set_sender(&mut ctx, @0x1);
        treasury::freeze(&mut treasury, &mut ctx);
        assert!(treasury::is_frozen(&treasury));

        treasury::unfreeze(&mut treasury, 1, &mut ctx);
        assert!(!treasury::is_frozen(&treasury));
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_freeze_non_emergency_signer() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];
        let threshold = 2;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[];

        let mut treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        tx_context::set_sender(&mut ctx, @0x99);
        treasury::freeze(&mut treasury, &mut ctx);
    }

    #[test]
    fun test_add_policy() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];
        let threshold = 2;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[];

        let mut treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        tx_context::set_sender(&mut ctx, @0x1);
        let policy_name = string::utf8(b"daily_limit");
        treasury::add_policy(
            &mut treasury,
            policy_name,
            1000,
            5000,
            20000,
            &mut ctx,
        );
    }

    #[test]
    fun test_update_spending_tracker() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1];
        let threshold = 1;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[];

        let mut treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        let category = string::utf8(b"Operations");
        treasury::update_spending_tracker(&mut treasury, category, 100);
        
        assert!(treasury::get_spending(&treasury, &category) == 100);

        treasury::update_spending_tracker(&mut treasury, category, 50);
        assert!(treasury::get_spending(&treasury, &category) == 150);
    }

    #[test]
    fun test_get_signers() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2, @0x3];
        let threshold = 2;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[];

        let treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        assert!(vector::length(treasury::get_signers(&treasury)) == 3);
    }

    #[test]
    fun test_get_categories() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1];
        let threshold = 1;
        let emergency_signers = vector[@0x1];
        let emergency_threshold = 1;
        let categories = vector[
            string::utf8(b"Cat1"),
            string::utf8(b"Cat2"),
        ];

        let treasury = treasury::create_treasury<TestCoin>(
            signers,
            threshold,
            emergency_signers,
            emergency_threshold,
            categories,
            &mut ctx,
        );

        assert!(vector::length(treasury::get_categories(&treasury)) == 2);
    }
}

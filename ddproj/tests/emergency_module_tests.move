#[cfg(test)]
module multi_sig_treasury::emergency_module_tests {
    use multi_sig_treasury::emergency_module;
    use sui::tx_context;
    use std::string::{Self, String};
    use std::vector;

    #[test]
    fun test_create_emergency_module() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2, @0x3];
        let threshold = 2;
        let cooldown = 3600;

        let module = emergency_module::create_emergency_module(
            emergency_signers,
            threshold,
            cooldown,
            &mut ctx,
        );

        assert!(emergency_module::get_emergency_threshold(&module) == 2);
        assert!(vector::length(emergency_module::get_emergency_signers(&module)) == 3);
        assert!(emergency_module::get_cooldown_period(&module) == 3600);
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_create_emergency_module_invalid_threshold() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];
        let threshold = 5;
        let cooldown = 3600;

        let _module = emergency_module::create_emergency_module(
            emergency_signers,
            threshold,
            cooldown,
            &mut ctx,
        );
    }

    #[test]
    fun test_is_emergency_signer() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            3600,
            &mut ctx,
        );

        assert!(emergency_module::is_emergency_signer(&module, @0x1));
        assert!(emergency_module::is_emergency_signer(&module, @0x2));
        assert!(!emergency_module::is_emergency_signer(&module, @0x99));
    }

    #[test]
    fun test_create_freeze_action() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            3600,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Critical vulnerability"),
            &mut ctx,
        );
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_create_freeze_action_not_emergency_signer() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            3600,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x99,
            string::utf8(b"Critical vulnerability"),
            &mut ctx,
        );
    }

    #[test]
    fun test_create_emergency_withdrawal_action() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            3600,
            &mut ctx,
        );

        emergency_module::create_emergency_withdrawal_action(
            &mut module,
            @0x1,
            1000,
            @0x3,
            string::utf8(b"Emergency withdrawal"),
            &mut ctx,
        );
    }

    #[test]
    fun test_sign_emergency_action() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            2,
            3600,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze"),
            &mut ctx,
        );

        emergency_module::sign_emergency_action(&mut module, 0, @0x1, &mut ctx);
        
        let (sig_count, _, _) = emergency_module::get_action_status(&module, 0);
        assert!(sig_count == 1);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_sign_emergency_action_not_emergency_signer() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            2,
            3600,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze"),
            &mut ctx,
        );

        emergency_module::sign_emergency_action(&mut module, 0, @0x99, &mut ctx);
    }

    #[test]
    fun test_can_execute_emergency_action() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            2,
            3600,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze"),
            &mut ctx,
        );

        assert!(!emergency_module::can_execute_emergency_action(&module, 0));

        emergency_module::sign_emergency_action(&mut module, 0, @0x1, &mut ctx);
        assert!(!emergency_module::can_execute_emergency_action(&module, 0));

        emergency_module::sign_emergency_action(&mut module, 0, @0x2, &mut ctx);
        assert!(emergency_module::can_execute_emergency_action(&module, 0));
    }

    #[test]
    fun test_execute_emergency_action() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            0,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze"),
            &mut ctx,
        );

        emergency_module::sign_emergency_action(&mut module, 0, @0x1, &mut ctx);
        emergency_module::execute_emergency_action(&mut module, 0, &mut ctx);

        let (_sig_count, executed, _cancelled) = emergency_module::get_action_status(&module, 0);
        assert!(executed);
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_execute_emergency_action_insufficient_signatures() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            2,
            0,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze"),
            &mut ctx,
        );

        emergency_module::sign_emergency_action(&mut module, 0, @0x1, &mut ctx);
        emergency_module::execute_emergency_action(&mut module, 0, &mut ctx);
    }

    #[test]
    fun test_cancel_emergency_action() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1, @0x2];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            2,
            3600,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze"),
            &mut ctx,
        );

        emergency_module::cancel_emergency_action(&mut module, 0, @0x2, &mut ctx);

        let (_sig_count, _executed, cancelled) = emergency_module::get_action_status(&module, 0);
        assert!(cancelled);
    }

    #[test]
    fun test_toggle_pause() {
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
            string::utf8(b"Security incident"),
            &mut ctx,
        );
        assert!(emergency_module::is_paused(&module));

        emergency_module::toggle_pause(
            &mut module,
            false,
            string::utf8(b"Resolved"),
            &mut ctx,
        );
        assert!(!emergency_module::is_paused(&module));
    }

    #[test]
    fun test_get_last_emergency_time() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1];

        let module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            3600,
            &mut ctx,
        );

        assert!(emergency_module::get_last_emergency_time(&module) == 0);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_cooldown_period_enforcement() {
        let mut ctx = tx_context::dummy();
        let emergency_signers = vector[@0x1];

        let mut module = emergency_module::create_emergency_module(
            emergency_signers,
            1,
            1000000,
            &mut ctx,
        );

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze 1"),
            &mut ctx,
        );

        emergency_module::sign_emergency_action(&mut module, 0, @0x1, &mut ctx);
        emergency_module::execute_emergency_action(&mut module, 0, &mut ctx);

        emergency_module::create_freeze_action(
            &mut module,
            @0x1,
            string::utf8(b"Test freeze 2"),
            &mut ctx,
        );

        emergency_module::sign_emergency_action(&mut module, 1, @0x1, &mut ctx);
        emergency_module::execute_emergency_action(&mut module, 1, &mut ctx);
    }
}

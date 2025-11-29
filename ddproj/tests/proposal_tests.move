#[cfg(test)]
module multi_sig_treasury::proposal_tests {
    use multi_sig_treasury::proposal;
    use sui::tx_context;
    use std::string::{Self, String};
    use std::vector;

    #[test]
    fun test_create_proposal() {
        let mut ctx = tx_context::dummy();
        let creator = @0x1;
        let description = string::utf8(b"Test proposal");
        let category = string::utf8(b"Operations");
        let recipients = vector[@0x2, @0x3];
        let amounts = vector[100, 200];
        let time_lock_duration = 3600;
        let threshold_required = 2;

        let prop = proposal::create_proposal(
            creator,
            description,
            category,
            recipients,
            amounts,
            time_lock_duration,
            threshold_required,
            &mut ctx,
        );

        let (creator_out, cat_out, total_amt, sig_count, thresh, _time_lock, exec, canc) = 
            proposal::get_proposal_info(&prop);

        assert!(creator_out == creator);
        assert!(total_amt == 300);
        assert!(sig_count == 0);
        assert!(thresh == threshold_required);
        assert!(!exec);
        assert!(!canc);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_create_proposal_mismatched_recipients_amounts() {
        let mut ctx = tx_context::dummy();
        let creator = @0x1;
        let description = string::utf8(b"Test proposal");
        let category = string::utf8(b"Operations");
        let recipients = vector[@0x2, @0x3];
        let amounts = vector[100];
        let time_lock_duration = 3600;
        let threshold_required = 2;

        let _prop = proposal::create_proposal(
            creator,
            description,
            category,
            recipients,
            amounts,
            time_lock_duration,
            threshold_required,
            &mut ctx,
        );
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_create_proposal_too_many_transactions() {
        let mut ctx = tx_context::dummy();
        let creator = @0x1;
        let description = string::utf8(b"Test proposal");
        let category = string::utf8(b"Operations");
        
        let mut recipients = vector[];
        let mut amounts = vector[];
        let mut i = 0;
        while (i < 51) {
            vector::push_back(&mut recipients, @0x2);
            vector::push_back(&mut amounts, 100);
            i = i + 1;
        };

        let _prop = proposal::create_proposal(
            creator,
            description,
            category,
            recipients,
            amounts,
            3600,
            2,
            &mut ctx,
        );
    }

    #[test]
    fun test_sign_proposal() {
        let mut ctx = tx_context::dummy();
        let creator = @0x1;
        let signer = @0x2;
        let signers = vector[@0x1, @0x2, @0x3];

        let mut prop = proposal::create_proposal(
            creator,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            vector[@0x4],
            vector[100],
            3600,
            2,
            &mut ctx,
        );

        proposal::sign_proposal(&mut prop, signer, &signers, &mut ctx);
        assert!(proposal::get_signature_count(&prop) == 1);
        assert!(proposal::has_signed(&prop, &signer));
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_sign_proposal_not_authorized() {
        let mut ctx = tx_context::dummy();
        let creator = @0x1;
        let non_signer = @0x99;
        let signers = vector[@0x1, @0x2];

        let mut prop = proposal::create_proposal(
            creator,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            vector[@0x3],
            vector[100],
            3600,
            2,
            &mut ctx,
        );

        proposal::sign_proposal(&mut prop, non_signer, &signers, &mut ctx);
    }

    #[test]
    fun test_can_execute_proposal() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2, @0x3];

        let mut prop = proposal::create_proposal(
            @0x1,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            vector[@0x4],
            vector[100],
            0,
            2,
            &mut ctx,
        );

        assert!(!proposal::can_execute(&prop, tx_context::epoch(&ctx)));

        proposal::sign_proposal(&mut prop, @0x1, &signers, &mut ctx);
        assert!(!proposal::can_execute(&prop, tx_context::epoch(&ctx)));

        proposal::sign_proposal(&mut prop, @0x2, &signers, &mut ctx);
        assert!(proposal::can_execute(&prop, tx_context::epoch(&ctx)));
    }

    #[test]
    fun test_execute_proposal() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];

        let mut prop = proposal::create_proposal(
            @0x1,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            vector[@0x3],
            vector[100],
            0,
            2,
            &mut ctx,
        );

        proposal::sign_proposal(&mut prop, @0x1, &signers, &mut ctx);
        proposal::sign_proposal(&mut prop, @0x2, &signers, &mut ctx);

        proposal::execute_proposal(&mut prop, &mut ctx);
        
        let (_,_,_,_,_,_,executed,_) = proposal::get_proposal_info(&prop);
        assert!(executed);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_execute_proposal_timelock_not_ready() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];

        let mut prop = proposal::create_proposal(
            @0x1,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            vector[@0x3],
            vector[100],
            1000000,
            2,
            &mut ctx,
        );

        proposal::sign_proposal(&mut prop, @0x1, &signers, &mut ctx);
        proposal::sign_proposal(&mut prop, @0x2, &signers, &mut ctx);

        proposal::execute_proposal(&mut prop, &mut ctx);
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_execute_proposal_insufficient_signatures() {
        let mut ctx = tx_context::dummy();
        let signers = vector[@0x1, @0x2];

        let mut prop = proposal::create_proposal(
            @0x1,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            vector[@0x3],
            vector[100],
            0,
            2,
            &mut ctx,
        );

        proposal::sign_proposal(&mut prop, @0x1, &signers, &mut ctx);
        proposal::execute_proposal(&mut prop, &mut ctx);
    }

    #[test]
    fun test_cancel_proposal_by_creator() {
        let mut ctx = tx_context::dummy();
        let creator = @0x1;

        let mut prop = proposal::create_proposal(
            creator,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            vector[@0x3],
            vector[100],
            0,
            2,
            &mut ctx,
        );

        proposal::cancel_proposal(&mut prop, creator, &mut ctx);
        
        let (_,_,_,_,_,_,_,cancelled) = proposal::get_proposal_info(&prop);
        assert!(cancelled);
    }

    #[test]
    fun test_get_recipients_and_amounts() {
        let mut ctx = tx_context::dummy();
        let recipients = vector[@0x2, @0x3, @0x4];
        let amounts = vector[100, 200, 300];

        let prop = proposal::create_proposal(
            @0x1,
            string::utf8(b"Test"),
            string::utf8(b"Ops"),
            recipients,
            amounts,
            0,
            2,
            &mut ctx,
        );

        assert!(vector::length(proposal::get_recipients(&prop)) == 3);
        assert!(vector::length(proposal::get_amounts(&prop)) == 3);
    }
}

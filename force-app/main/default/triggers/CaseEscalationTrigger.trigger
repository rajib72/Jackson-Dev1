trigger CaseEscalationTrigger on Case (
    after insert,
    after update
) {

    /* =========================================================
       EXISTING: CASE INSERT
       ========================================================= */

    if (Trigger.isAfter && Trigger.isInsert) {

        CaseL1EscalationHandler.handleAfterInsert(
            Trigger.new
        );
    }

    /* =========================================================
       EXISTING: CASE UPDATE
       ========================================================= */

    if (Trigger.isAfter && Trigger.isUpdate) {

        // Existing L1 escalation logic - unchanged.

        CaseL1EscalationHandler.handleAfterUpdate(
            Trigger.new,
            Trigger.oldMap
        );

        /* =====================================================
           NEW: SEND WHATSAPP WHEN CASE BECOMES RESOLVED
           ===================================================== */

        SRT_ResolvedWhatsAppService.handleAfterUpdate(
            Trigger.new,
            Trigger.oldMap
        );
    }
}
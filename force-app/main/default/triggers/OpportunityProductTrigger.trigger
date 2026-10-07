trigger OpportunityProductTrigger on OpportunityLineItem (
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (Trigger.isAfter) {
        OpportunityProductTriggerHandler.updateOpportunityExpectedCapacity(
            Trigger.isDelete ? null : Trigger.new,
            Trigger.isInsert || Trigger.isUndelete ? null : Trigger.old
        );
    }
}
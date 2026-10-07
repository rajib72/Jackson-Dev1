trigger LeadProductTrigger on Lead_Product__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (Trigger.isAfter) {
        LeadProductTriggerHandler.updateLeadExpectedCapacity(
            Trigger.isDelete ? null : Trigger.new,
            Trigger.isInsert || Trigger.isUndelete ? null : Trigger.old
        );
    }
}
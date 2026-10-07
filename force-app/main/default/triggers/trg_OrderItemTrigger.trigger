trigger trg_OrderItemTrigger on OrderItem (after insert, after update) {
    Set<Id> orderItemIds = new Set<Id>();

    if (Trigger.isAfter) {
        for (OrderItem oi : Trigger.new) {
            Boolean shouldCall = false;

            if (Trigger.isInsert) {
                if (oi.Fetch_Item_Category__c == true) {
                    shouldCall = true;
                }
            }

            if (Trigger.isUpdate) {
                OrderItem oldOi = Trigger.oldMap.get(oi.Id);

                // Fire only when checkbox changes from false to true
                if (oi.Fetch_Item_Category__c == true && oldOi.Fetch_Item_Category__c != true) {
                    shouldCall = true;
                }
            }

            if (shouldCall) {
                orderItemIds.add(oi.Id);
            }
        }

        if (!orderItemIds.isEmpty()) {
            System.enqueueJob(new API_QU_OrderItemCategoryQueueable (new List<Id>(orderItemIds)));
        }
    }
}
public with sharing class Ctrl_AddOrderReasonToServiceOrder {
    @AuraEnabled(cacheable=true)
    public static List<Order_Reason_Master__c> getOrderReasons() {
        // Fetching the Master records
        return [SELECT Id, Order_Reason_Details__c, ORDER_REASON__c 
                FROM Order_Reason_Master__c 
                ORDER BY Order_Reason_Details__c ASC];
    }
}
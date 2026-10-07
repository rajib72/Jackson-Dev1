public with sharing class SAPDeliveryLWCController {

    // (Leave fetchDeliveryData exactly as it was)
    @AuraEnabled
    public static List<API_ctrl_SAPDeliveryInfoController.DeliveryInfoWrapper> fetchDeliveryData(Id orderId) {
        // ... Keep your existing fetchDeliveryData code here ...
        try {
            if (String.isBlank(orderId)) {
                throw new AuraHandledException('Order ID is missing or component has not fully loaded.');
            }
            List<Order> orderList = [SELECT Id, Sales_Order__c, Service_Order__c FROM Order WHERE Id = :orderId LIMIT 1];
            if (orderList.isEmpty()) {
                throw new AuraHandledException('Could not find the Order record or you do not have access.');
            }
            
            Order currentOrder = orderList[0];
            String orderNumber = '';

            if (String.isNotBlank(currentOrder.Service_Order__c)) {
                orderNumber = currentOrder.Service_Order__c;
            } else if (String.isNotBlank(currentOrder.Sales_Order__c)) {
                orderNumber = currentOrder.Sales_Order__c;
            } else {
                throw new AuraHandledException('Both Sales Order and Service Order are blank on this Order.');
            }
            
            return API_ctrl_SAPDeliveryInfoController.getDeliveryInformation(
                'salesOrder', null, null, orderNumber
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // 1. Create a wrapper to return the counts
    public class SaveResult {
        @AuraEnabled public Integer addedCount { get; set; }
        @AuraEnabled public Integer skippedCount { get; set; }
    }

    // 2. Update the return type from void to SaveResult
    @AuraEnabled
    public static SaveResult saveDeliveryRecords(Id orderId, String deliveryDataJson) {
        SaveResult result = new SaveResult();
        result.addedCount = 0;
        result.skippedCount = 0;

        try {
            List<API_ctrl_SAPDeliveryInfoController.DeliveryInfoWrapper> wrappers = 
                (List<API_ctrl_SAPDeliveryInfoController.DeliveryInfoWrapper>) JSON.deserialize(
                    deliveryDataJson, 
                    List<API_ctrl_SAPDeliveryInfoController.DeliveryInfoWrapper>.class
                );

            if (wrappers.isEmpty()) { return result; }

            Set<String> incomingDeliveryNos = new Set<String>();
            for (API_ctrl_SAPDeliveryInfoController.DeliveryInfoWrapper wrap : wrappers) {
                if (String.isNotBlank(wrap.deliveryNo)) {
                    incomingDeliveryNos.add(wrap.deliveryNo);
                }
            }

            Set<String> existingDeliveryNos = new Set<String>();
            for (Delivery_Information__c existingRecord : [
                SELECT SAP_Delivery_No__c 
                FROM Delivery_Information__c 
                WHERE Order__c = :orderId AND SAP_Delivery_No__c IN :incomingDeliveryNos
            ]) {
                existingDeliveryNos.add(existingRecord.SAP_Delivery_No__c);
            }

            List<Delivery_Information__c> recordsToInsert = new List<Delivery_Information__c>();

            for (API_ctrl_SAPDeliveryInfoController.DeliveryInfoWrapper wrap : wrappers) {
                if (!existingDeliveryNos.contains(wrap.deliveryNo)) {
                    Delivery_Information__c newRecord = new Delivery_Information__c();
                    newRecord.Order__c = orderId;
                    newRecord.SAP_Delivery_No__c = wrap.deliveryNo;
                    
                    recordsToInsert.add(newRecord);
                } else {
                    // Increment skipped count if it already exists
                    result.skippedCount++;
                }
            }

            if (!recordsToInsert.isEmpty()) {
                insert recordsToInsert;
                // Set the added count
                result.addedCount = recordsToInsert.size();
            }

            return result; // Return the counts back to the LWC

        } catch (Exception e) {
            throw new AuraHandledException('Error saving records: ' + e.getMessage());
        }
    }
}
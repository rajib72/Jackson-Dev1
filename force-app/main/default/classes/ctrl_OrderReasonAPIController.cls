public with sharing class ctrl_OrderReasonAPIController {

    public class OrderReasonItem {
        public String ORDER_REASON;
        public String DESCRIPTION;
    }

    public class ResultWrapper {
        public List<OrderReasonItem> item;
    }

    public class ResponseWrapper {
        public ResultWrapper RESULT;
    }

    public class ProcessedRecord {
        @AuraEnabled public String orderReason;
        @AuraEnabled public String description;
        @AuraEnabled public String action;
        @AuraEnabled public String message;
        @AuraEnabled public Boolean success;
    }

    public class SyncResponse {
        @AuraEnabled public Integer totalReceived = 0;
        @AuraEnabled public Integer created = 0;
        @AuraEnabled public Integer updated = 0;
        @AuraEnabled public Integer errors = 0;
        @AuraEnabled public List<ProcessedRecord> records = new List<ProcessedRecord>();
    }

    private class PendingDml {
        public Order_Reason_Master__c recordValue;
        public ProcessedRecord rowValue;

        public PendingDml(Order_Reason_Master__c recordValue, ProcessedRecord rowValue) {
            this.recordValue = recordValue;
            this.rowValue = rowValue;
        }
    }

    @AuraEnabled
    public static SyncResponse syncOrderReasons() {

        SyncResponse summary = new SyncResponse();

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:sap_MM/orderReason');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{}');

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('Status Code ==> ' + res.getStatusCode());
        System.debug('Response Body ==> ' + res.getBody());

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'API Error : ' +
                res.getStatusCode() +
                ' - ' +
                res.getBody()
            );
        }

        String responseBody = res.getBody();
        if (String.isBlank(responseBody)) {
            return summary;
        }

        ResponseWrapper responseObj =
            (ResponseWrapper) JSON.deserialize(responseBody, ResponseWrapper.class);

        if (responseObj == null ||
            responseObj.RESULT == null ||
            responseObj.RESULT.item == null ||
            responseObj.RESULT.item.isEmpty()) {
            return summary;
        }

        processOrderReasons(responseObj.RESULT.item, summary);
        return summary;
    }

    private static void processOrderReasons(
        List<OrderReasonItem> apiRecords,
        SyncResponse summary
    ) {
        summary.totalReceived = apiRecords.size();

        Map<String, OrderReasonItem> uniqueApiMap = new Map<String, OrderReasonItem>();
        for (OrderReasonItem item : apiRecords) {
            if (String.isBlank(item.ORDER_REASON)) {
                continue;
            }
            uniqueApiMap.put(item.ORDER_REASON.trim(), item);
        }

        if (uniqueApiMap.isEmpty()) {
            return;
        }

        Set<String> reasonCodes = uniqueApiMap.keySet();

        Map<String, Order_Reason_Master__c> existingMap = new Map<String, Order_Reason_Master__c>();
        for (Order_Reason_Master__c rec : [
            SELECT Id, ORDER_REASON__c, DESCRIPTION__c
            FROM Order_Reason_Master__c
            WHERE ORDER_REASON__c IN :reasonCodes
        ]) {
            existingMap.put(rec.ORDER_REASON__c, rec);
        }

        List<PendingDml> insertContexts = new List<PendingDml>();
        List<PendingDml> updateContexts = new List<PendingDml>();

        for (String code : uniqueApiMap.keySet()) {
            OrderReasonItem item = uniqueApiMap.get(code);

            ProcessedRecord row = new ProcessedRecord();
            row.orderReason = code;
            row.description = item.DESCRIPTION;

            if (existingMap.containsKey(code)) {
                Order_Reason_Master__c existingRec = existingMap.get(code);

                if (existingRec.DESCRIPTION__c == item.DESCRIPTION) {
                    row.action = 'No Change';
                    row.success = true;
                    row.message = 'No changes needed';
                    summary.records.add(row);
                } else {
                    existingRec.DESCRIPTION__c = item.DESCRIPTION;
                    row.action = 'Updated';
                    row.success = true;
                    row.message = 'Pending';
                    updateContexts.add(new PendingDml(existingRec, row));
                    summary.records.add(row);
                }
            } else {
                Order_Reason_Master__c newRec = new Order_Reason_Master__c(
                    ORDER_REASON__c = code,
                    DESCRIPTION__c = item.DESCRIPTION
                );

                row.action = 'Created';
                row.success = true;
                row.message = 'Pending';
                insertContexts.add(new PendingDml(newRec, row));
                summary.records.add(row);
            }
        }

        if (!insertContexts.isEmpty()) {
            List<Order_Reason_Master__c> insertList = new List<Order_Reason_Master__c>();
            for (PendingDml ctx : insertContexts) {
                insertList.add(ctx.recordValue);
            }

            Database.SaveResult[] results = Database.insert(insertList, false);

            for (Integer i = 0; i < results.size(); i++) {
                ProcessedRecord row = insertContexts[i].rowValue;
                if (results[i].isSuccess()) {
                    summary.created++;
                    row.action = 'Created';
                    row.success = true;
                    row.message = 'Created successfully';
                } else {
                    summary.errors++;
                    row.action = 'Error';
                    row.success = false;
                    row.message = results[i].getErrors()[0].getMessage();
                }
            }
        }

        if (!updateContexts.isEmpty()) {
            List<Order_Reason_Master__c> updateList = new List<Order_Reason_Master__c>();
            for (PendingDml ctx : updateContexts) {
                updateList.add(ctx.recordValue);
            }

            Database.SaveResult[] results = Database.update(updateList, false);

            for (Integer i = 0; i < results.size(); i++) {
                ProcessedRecord row = updateContexts[i].rowValue;
                if (results[i].isSuccess()) {
                    summary.updated++;
                    row.action = 'Updated';
                    row.success = true;
                    row.message = 'Updated successfully';
                } else {
                    summary.errors++;
                    row.action = 'Error';
                    row.success = false;
                    row.message = results[i].getErrors()[0].getMessage();
                }
            }
        }
    }
}
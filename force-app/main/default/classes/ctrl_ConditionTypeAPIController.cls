public with sharing class ctrl_ConditionTypeAPIController {

    public class ConditionTypeItem {
        public String CONDITION_TYPE;
        public String DESCRIPTION;
    }

    public class ResultWrapper {
        public List<ConditionTypeItem> item;
    }

    public class ResponseWrapper {
        public ResultWrapper RESULT;
    }

    public static void syncConditionTypes() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:sap_MM/conditionType');
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
                'API Error: ' + res.getStatusCode() + ' - ' + res.getBody()
            );
        }

        String responseBody = res.getBody();
        if (String.isBlank(responseBody)) {
            System.debug('Empty response received from conditionType API');
            return;
        }

        ResponseWrapper responseObj =
            (ResponseWrapper) JSON.deserialize(responseBody, ResponseWrapper.class);

        if (responseObj == null ||
            responseObj.RESULT == null ||
            responseObj.RESULT.item == null ||
            responseObj.RESULT.item.isEmpty()) {
            System.debug('No condition types found in response');
            return;
        }

        syncRecords(responseObj.RESULT.item);
    }

    private static void syncRecords(List<ConditionTypeItem> apiRecords) {
        Set<String> conditionTypes = new Set<String>();
        for (ConditionTypeItem item : apiRecords) {
            if (String.isNotBlank(item.CONDITION_TYPE)) {
                conditionTypes.add(item.CONDITION_TYPE.trim());
            }
        }

        if (conditionTypes.isEmpty()) {
            return;
        }

        Map<String, Condition_Type_Master__c> existingMap = new Map<String, Condition_Type_Master__c>();
        for (Condition_Type_Master__c rec : [
            SELECT Id, CONDITION_TYPE__c, DESCRIPTION__c
            FROM Condition_Type_Master__c
            WHERE CONDITION_TYPE__c IN :conditionTypes
        ]) {
            existingMap.put(rec.CONDITION_TYPE__c, rec);
        }

        List<Condition_Type_Master__c> recordsToUpsert = new List<Condition_Type_Master__c>();

        for (ConditionTypeItem item : apiRecords) {
            if (String.isBlank(item.CONDITION_TYPE)) {
                continue;
            }

            String code = item.CONDITION_TYPE.trim();

            Condition_Type_Master__c rec;
            if (existingMap.containsKey(code)) {
                rec = existingMap.get(code);
                rec.DESCRIPTION__c = item.DESCRIPTION;
            } else {
                rec = new Condition_Type_Master__c();
                rec.CONDITION_TYPE__c = code;
                rec.DESCRIPTION__c = item.DESCRIPTION;
            }

            recordsToUpsert.add(rec);
        }

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert;
            System.debug('Total Condition Types Processed : ' + recordsToUpsert.size());
        }
    }
}
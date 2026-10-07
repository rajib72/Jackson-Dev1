public with sharing class Ctrl_FetchConditionType {
    
    @AuraEnabled
    public static String fetchConditionTypesFromSAP(Id orderItemId) {
        try {
            // 1. Fetch OrderItem and related Order fields for the payload
            OrderItem oi = [
                SELECT Sales_Org__c, Order.Distribution_Channel__c, Order.Division__c 
                FROM OrderItem 
                WHERE Id = :orderItemId 
                LIMIT 1
            ];

            // 2. Prepare the JSON request body
            Map<String, String> requestBody = new Map<String, String>{
                'SALES_ORG' => oi.Sales_Org__c,
                'DIST_CHAN' => oi.Order.Distribution_Channel__c,
                'DIVISION'  => oi.Order.Division__c
            };

            // 3. Make the HTTP Callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint('Callout:NC_SAP_API/http/conditionType');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000); 
            req.setBody(JSON.serialize(requestBody));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                throw new CalloutException('Failed to fetch data from SAP. Status Code: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
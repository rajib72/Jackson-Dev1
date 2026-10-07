public class API_QU_OrderItemCategoryQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> orderItemIds;

    public API_QU_OrderItemCategoryQueueable(List<Id> orderItemIds) {
        this.orderItemIds = orderItemIds;
    }

    public void execute(QueueableContext context) {
        List<OrderItem> items = [
            SELECT Id,
                   Order_Type__c,
                   Material_Code__c,
                   Sales_Org__c,
                   Item_Category__c,
                   Fetch_Item_Category__c,
                   Item_Category_API_Status__c
            FROM OrderItem
            WHERE Id IN :orderItemIds
        ];

        List<OrderItem> itemsToUpdate = new List<OrderItem>();

        for (OrderItem oi : items) {
            String requestJson = null;

            try {
                if (String.isBlank(oi.Order_Type__c) ||
                    String.isBlank(oi.Material_Code__c) ||
                    String.isBlank(oi.Sales_Org__c)) {

                    Map<String, Object> missingFieldRequest = new Map<String, Object>{
                        'ORDER_TYPE' => oi.Order_Type__c,
                        'MATERIAL'   => oi.Material_Code__c,
                        'SALES_ORG'  => oi.Sales_Org__c
                    };

                    logIntegrationError(
                        'Item Category API',
                        'MISSING_INPUT',
                        'Order Type, Material Code, or Sales Org is blank.',
                        'POST',
                        JSON.serialize(missingFieldRequest),
                        'callout:NC_SAP_API/http/itemCatgMast',
                        'SAP',
                        null,
                        null
                    );
                    continue;
                }

                Map<String, Object> requestBody = new Map<String, Object>{
                    'ORDER_TYPE' => oi.Order_Type__c,
                    'MATERIAL'   => oi.Material_Code__c,
                    'SALES_ORG'  => oi.Sales_Org__c
                };

                requestJson = JSON.serialize(requestBody);

                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:NC_SAP_API/http/itemCatgMast');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(120000);
                req.setBody(requestJson);

                Http http = new Http();
                HttpResponse res = http.send(req);

                Integer statusCode = res.getStatusCode();
                String responseBody = res.getBody();

                System.debug('Request Endpoint: ' + req.getEndpoint());
                System.debug('Request Body: ' + requestJson);
                System.debug('Response Status Code: ' + statusCode);
                System.debug('SAP API Output: ' + responseBody);

                if (statusCode >= 200 && statusCode < 300) {
                    String itemCategory = parseItemCategory(responseBody);

                    OrderItem updateOi = new OrderItem(
                        Id = oi.Id,
                        Item_Category__c = itemCategory,
                        Item_Category_API_Status__c = String.isBlank(itemCategory) ? 'Not Found' : 'Found'
                        
                    );
                    itemsToUpdate.add(updateOi);
                } else {
                    logIntegrationError(
                        'Item Category API',
                        String.valueOf(statusCode),
                        'Non-success response from API',
                        'POST',
                        requestJson,
                        'callout:NC_SAP_API/http/itemCatgMast',
                        'SAP',
                        responseBody,
                        String.valueOf(statusCode)
                    );
                }

            } catch (Exception e) {
                logIntegrationError(
                    'Item Category API',
                    e.getTypeName(),
                    e.getMessage(),
                    'POST',
                    requestJson,
                    'callout:NC_SAP_API/http/itemCatgMast',
                    'SAP',
                    e.getStackTraceString(),
                    null
                );
            }
        }

        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
    }

    private static String parseItemCategory(String responseBody) {
        if (String.isBlank(responseBody)) {
            return null;
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        if (responseMap.containsKey('ITEM_CATAGORY')) {
            Object outerObj = responseMap.get('ITEM_CATAGORY');

            if (outerObj instanceof List<Object>) {
                List<Object> itemList = (List<Object>) outerObj;

                if (!itemList.isEmpty() && itemList[0] instanceof Map<String, Object>) {
                    Map<String, Object> firstRow = (Map<String, Object>) itemList[0];

                    if (firstRow.containsKey('ITEM_CATAGORY')) {
                        Object val = firstRow.get('ITEM_CATAGORY');
                        return val == null ? null : String.valueOf(val).trim();
                    }
                }
            }
        }

        return null;
    }

    private static void logIntegrationError(
        String apiName,
        String errorCode,
        String errorMessage,
        String httpMethod,
        String requestParams,
        String requestUri,
        String sourceSystem,
        String stackTrace,
        String statusCode
    ) {
        try {
            Integration_Error_Log__c logRec = new Integration_Error_Log__c();
            logRec.API_Name__c = apiName;
            logRec.Error_Code__c = errorCode;
            logRec.Error_Message__c = errorMessage;
            logRec.Http_Method__c = httpMethod;
            logRec.Logged_On__c = String.ValueOf(System.now());
            logRec.Request_Parameters__c = requestParams;
            logRec.Request_URI__c = requestUri;
            logRec.Source_System__c = sourceSystem;
            logRec.Stack_Trace__c = stackTrace;
            logRec.Status_Code__c = Decimal.valueOf(statusCode);

            insert logRec;
        } catch (Exception ex) {
            System.debug('Error while inserting Integration_Error_Log__c: ' + ex.getMessage());
        }
    }
}
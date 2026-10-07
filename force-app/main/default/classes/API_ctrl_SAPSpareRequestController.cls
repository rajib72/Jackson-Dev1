public with sharing class API_ctrl_SAPSpareRequestController {

    private static final String API_NAME = 'SAP Spare Request API';
    private static final String SOURCE_SYSTEM = 'SAP';
    private static final String HTTP_METHOD = 'POST';
    private static final String ENDPOINT = 'callout:NC_SAP_API/http/rfcSpareStock';

    // Property names match SAP JSON response keys exactly
    public class SpareStockRow {
        @AuraEnabled public String MATERIAL_CODE { get; set; }
        @AuraEnabled public String MATERIAL_DESCRIPTION { get; set; }
        @AuraEnabled public String PLANT { get; set; }
        @AuraEnabled public String PLANT_DESCRIPTION { get; set; }
        @AuraEnabled public String STORAGE_LOCATION { get; set; }
        @AuraEnabled public String STORAGE_LOCATION_DESCRIPTION { get; set; }
        @AuraEnabled public String UOM { get; set; }
        @AuraEnabled public String BATCH_NUMBER { get; set; }
        @AuraEnabled public String QUANTITY { get; set; }
        @AuraEnabled public String STANDARD_PRICE { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static List<SpareStockRow> fetchSpareRequestData(String materialCode, String plant) {
        if (String.isBlank(materialCode) || String.isBlank(plant)) {
            throw new AuraHandledException('Both Material Code and Plant are required.');
        }

        // Generates: {"PLANT": "...", "MATERIAL_CODE": "..."}
        Map<String, String> requestPayload = new Map<String, String>{
            'PLANT' => plant.trim(),
            'MATERIAL_CODE' => materialCode.trim()
        };
        String requestBody = JSON.serialize(requestPayload);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod(HTTP_METHOD);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(requestBody);

        HttpResponse res;
        try {
            Http http = new Http();
            res = http.send(req);

            Integer statusCode = res.getStatusCode();
            if (statusCode < 200 || statusCode >= 300) {
                throw new AuraHandledException('SAP API call failed. Status Code: ' + statusCode);
            }

            String body = res.getBody();
            res = null; // Free HTTP response heap memory immediately

            if (String.isBlank(body)) {
                return new List<SpareStockRow>();
            }

            // Direct deserialization to typed list
            List<SpareStockRow> records = (List<SpareStockRow>) JSON.deserialize(
                body, 
                List<SpareStockRow>.class
            );
            body = null; // Free payload string memory

            return records;

        } catch (Exception e) {
            logError(
                API_NAME,
                'EXCEPTION',
                e.getMessage(),
                HTTP_METHOD,
                requestBody,
                ENDPOINT,
                SOURCE_SYSTEM,
                e.getStackTraceString(),
                (res != null ? String.valueOf(res.getStatusCode()) : '500')
            );
            throw new AuraHandledException('Error while processing SAP data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String updateSelectedPrice(Id recordId, Decimal selectedPrice) {
        if (recordId == null || selectedPrice == null) {
            throw new AuraHandledException('Record ID and Price are required.');
        }

        try {
            update new ProductRequestLineItem(
                Id = recordId,
                Price__c = selectedPrice
            );
            return 'Price updated successfully.';
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update Price: ' + e.getMessage());
        }
    }

    private static void logError(String apiName, String errorCode, String errorMessage, 
                                 String httpMethod, String requestParameters, String requestUri, 
                                 String sourceSystem, String stackTrace, String statusCode) {
        try {
            insert new Integration_Error_Log__c(
                API_Name__c = apiName,
                Error_Code__c = errorCode,
                Error_Message__c = errorMessage,
                Http_Method__c = httpMethod,
                Logged_On__c = String.valueOf(System.now()),
                Request_Parameters__c = requestParameters,
                Request_URI__c = requestUri,
                Source_System__c = sourceSystem,
                Stack_Trace__c = stackTrace,
                Status_Code__c = String.isNotBlank(statusCode) ? Decimal.valueOf(statusCode) : null
            );
        } catch (Exception ex) {
            System.debug('Logging failed: ' + ex.getMessage());
        }
    }
}
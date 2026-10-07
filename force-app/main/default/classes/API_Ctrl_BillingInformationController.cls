public with sharing class API_Ctrl_BillingInformationController {

    private static final String BILLING_ENDPOINT = 'callout:NC_SAP_API/http/rfcBillInf';
    private static final String HTTP_METHOD = 'POST';
    private static final String SOURCE_SYSTEM = 'SAP';
    private static final String API_NAME = 'Billing Information API';

    public class BillingInfoRow {
        @AuraEnabled public String billingDocument;
        @AuraEnabled public String billingLineItemNo;
        @AuraEnabled public String billingDocumentDate;
        @AuraEnabled public String billingDocumentAmount;
        @AuraEnabled public String deliveryNumber;
        @AuraEnabled public String salesOrderNo;
    }

    public class BillingInfoResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer count;
        @AuraEnabled public List<BillingInfoRow> records;
    }

    @AuraEnabled(cacheable=false)
    public static BillingInfoResponse fetchBillingInformation(
        String filterType,
        Date fromDate,
        Date toDate,
        String deliveryNumber
    ) {
        BillingInfoResponse responseWrapper = new BillingInfoResponse();
        responseWrapper.success = false;
        responseWrapper.records = new List<BillingInfoRow>();
        responseWrapper.count = 0;

        String requestBody;
        HttpRequest req = new HttpRequest();
        HttpResponse res;

        try {
            validateInputs(filterType, fromDate, toDate, deliveryNumber);

            requestBody = buildRequestBody(filterType, fromDate, toDate, deliveryNumber);

            req.setEndpoint(BILLING_ENDPOINT);
            req.setMethod(HTTP_METHOD);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBody);

            System.debug('Billing API Request Endpoint: ' + req.getEndpoint());
            System.debug('Billing API Request Body: ' + requestBody);

            Http http = new Http();
            res = http.send(req);

            System.debug('Billing API Status Code: ' + res.getStatusCode());
            System.debug('Billing API Response Body: ' + res.getBody());

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                responseWrapper.records = parseResponse(res.getBody());
                responseWrapper.count = responseWrapper.records.size();
                responseWrapper.success = true;
                responseWrapper.message = responseWrapper.count > 0
                    ? 'Records fetched successfully.'
                    : 'No records found.';
            } else {
                responseWrapper.success = false;
                responseWrapper.message = 'API call failed with status code: ' + res.getStatusCode();

                logIntegrationError(
                    API_NAME,
                    String.valueOf(res.getStatusCode()),
                    res.getBody(),
                    HTTP_METHOD,
                    requestBody,
                    BILLING_ENDPOINT,
                    SOURCE_SYSTEM,
                    null,
                    String.valueOf(res.getStatusCode())
                );
            }

        } catch (Exception e) {
            responseWrapper.success = false;
            responseWrapper.message = e.getMessage();

            logIntegrationError(
                API_NAME,
                'EXCEPTION',
                e.getMessage(),
                HTTP_METHOD,
                requestBody,
                BILLING_ENDPOINT,
                SOURCE_SYSTEM,
                e.getStackTraceString(),
                res != null ? String.valueOf(res.getStatusCode()) : null
            );
        }

        return responseWrapper;
    }

    private static void validateInputs(
        String filterType,
        Date fromDate,
        Date toDate,
        String deliveryNumber
    ) {
        if (String.isBlank(filterType)) {
            throw new AuraHandledException('Please select a filter type.');
        }

        if (filterType == 'DATE') {
            if (fromDate == null || toDate == null) {
                throw new AuraHandledException('Please select both From Date and To Date.');
            }
            if (fromDate > toDate) {
                throw new AuraHandledException('From Date cannot be greater than To Date.');
            }
        } else if (filterType == 'DELIVERY') {
            if (String.isBlank(deliveryNumber)) {
                throw new AuraHandledException('Please enter Delivery Number.');
            }
        } else {
            throw new AuraHandledException('Invalid filter type selected.');
        }
    }

    private static String buildRequestBody(
        String filterType,
        Date fromDate,
        Date toDate,
        String deliveryNumber
    ) {
        Map<String, Object> requestBody = new Map<String, Object>();

        if (filterType == 'DATE') {
            requestBody.put('CREATION_FROM_DATE', formatDateYYYYMMDD(fromDate));
            requestBody.put('CREATION_TO_DATE', formatDateYYYYMMDD(toDate));
        } else if (filterType == 'DELIVERY') {
            requestBody.put('DELIVERY_NUMBER', new List<Object>{
                new Map<String, Object>{
                    'DELIVERY' => deliveryNumber
                }
            });
        }

        return JSON.serialize(requestBody);
    }

    private static String formatDateYYYYMMDD(Date inputDate) {
        String monthStr = inputDate.month() < 10 ? '0' + String.valueOf(inputDate.month()) : String.valueOf(inputDate.month());
        String dayStr   = inputDate.day() < 10 ? '0' + String.valueOf(inputDate.day()) : String.valueOf(inputDate.day());
        return String.valueOf(inputDate.year()) + monthStr + dayStr;
    }

    private static List<BillingInfoRow> parseResponse(String responseBody) {
        List<BillingInfoRow> records = new List<BillingInfoRow>();

        if (String.isBlank(responseBody)) {
            return records;
        }

        Object rawObj = JSON.deserializeUntyped(responseBody);

        if (rawObj instanceof List<Object>) {
            List<Object> responseList = (List<Object>) rawObj;

            for (Object item : responseList) {
                Map<String, Object> rowMap = (Map<String, Object>) item;
                BillingInfoRow row = new BillingInfoRow();

                row.billingDocument       = getStringValue(rowMap, 'BILLING_DOCUMENT');
                row.billingLineItemNo     = getStringValue(rowMap, 'BILLING_LINE_ITEM_NO');
                row.billingDocumentDate   = getStringValue(rowMap, 'BILLING_DOCUMENT_DATE');
                row.billingDocumentAmount = getStringValue(rowMap, 'BILLING_DOCUMENT_AMOUNT');
                row.deliveryNumber        = getStringValue(rowMap, 'DELIVERY_NUMBER');
                row.salesOrderNo          = getStringValue(rowMap, 'SALES_ORDER_NO');

                records.add(row);
            }
        } else {
            throw new AuraHandledException('Unexpected response format received from SAP API.');
        }

        return records;
    }

    private static String getStringValue(Map<String, Object> dataMap, String key) {
        return dataMap != null && dataMap.containsKey(key) && dataMap.get(key) != null
            ? String.valueOf(dataMap.get(key))
            : '';
    }

    private static void logIntegrationError(
        String apiName,
        String errorCode,
        String errorMessage,
        String httpMethod,
        String requestParameters,
        String requestUri,
        String sourceSystem,
        String stackTrace,
        String statusCode
    ) {
        try {
            Integration_Error_Log__c logRecord = new Integration_Error_Log__c();
            logRecord.API_Name__c = apiName;
            logRecord.Error_Code__c = errorCode;
            logRecord.Error_Message__c = truncateValue(errorMessage, 255);
            logRecord.Http_Method__c = httpMethod;
            logRecord.Logged_On__c = string.valueOf(System.now());
            logRecord.Request_Parameters__c = requestParameters;
            logRecord.Request_URI__c = requestUri;
            logRecord.Source_System__c = sourceSystem;
            logRecord.Stack_Trace__c = stackTrace;
            logRecord.Status_Code__c = Decimal.valueOf(statusCode);

            insert logRecord;
        } catch (Exception logEx) {
            System.debug('Error while logging Integration_Error_Log__c: ' + logEx.getMessage());
        }
    }

    private static String truncateValue(String input, Integer maxLength) {
        if (String.isBlank(input)) {
            return input;
        }
        return input.length() > maxLength ? input.substring(0, maxLength) : input;
    }
}
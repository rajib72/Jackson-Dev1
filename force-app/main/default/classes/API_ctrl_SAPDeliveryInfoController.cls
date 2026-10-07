public with sharing class API_ctrl_SAPDeliveryInfoController {

    private static final String API_NAME = 'SAP Delivery Information API';
    private static final String HTTP_METHOD = 'POST';
    private static final String SOURCE_SYSTEM = 'SAP';
    private static final String ENDPOINT = 'callout:NC_SAP_API/http/rfcDelvInf';

    public class DeliveryInfoWrapper {
        @AuraEnabled public String deliveryNo {get; set;}
        @AuraEnabled public String deliveryLineItemNo {get; set;}
        @AuraEnabled public String salesOrderNo {get; set;}
        @AuraEnabled public String salesOrderLineItem {get; set;}
        @AuraEnabled public String deliveryItem {get; set;}
        @AuraEnabled public String deliveryItemDescription {get; set;}
        @AuraEnabled public String deliveryDate {get; set;}
        @AuraEnabled public String deliveryQuantity {get; set;}
        @AuraEnabled public String plant {get; set;}
        @AuraEnabled public String storageLocation {get; set;}
        @AuraEnabled public String netPrice {get; set;}
        @AuraEnabled public String netValue {get; set;}
    }

    @AuraEnabled
    public static List<DeliveryInfoWrapper> getDeliveryInformation(
        String filterType,
        Date fromDate,
        Date toDate,
        String salesOrderNumber
    ) {
        List<DeliveryInfoWrapper> resultList = new List<DeliveryInfoWrapper>();
        String requestBody = '';
        HttpRequest req = new HttpRequest();
        HttpResponse res;
        
        try {
            if (String.isBlank(filterType)) {
                throw new AuraHandledException('Please select a filter type.');
            }

            Map<String, Object> requestMap = new Map<String, Object>();

            if (filterType == 'date') {
                if (fromDate == null || toDate == null) {
                    throw new AuraHandledException('Please enter From Date and To Date.');
                }
                if (fromDate > toDate) {
                    throw new AuraHandledException('From Date cannot be greater than To Date.');
                }
                
                Integer dayDiff = fromDate.daysBetween(toDate);
                if (dayDiff > 7) {
                    throw new AuraHandledException('Date range cannot be greater than 7 days.');
                }

                String fromFormattedDate = formatDateYYYYMMDD(fromDate);
                String toFormattedDate   = formatDateYYYYMMDD(toDate);

                requestMap.put('CREATION_FROM_DATE', fromFormattedDate);
                requestMap.put('CREATION_TO_DATE', toFormattedDate);

            } else if (filterType == 'salesOrder') {
                if (String.isBlank(salesOrderNumber)) {
                    throw new AuraHandledException('Please enter Sales Order Number.');
                }

                requestMap.put(
                    'SALES_ORDER',
                    new List<Object>{
                        new Map<String, Object>{
                            'VBELN' => salesOrderNumber.trim()
                        }
                    }
                );
            } else {
                throw new AuraHandledException('Invalid filter type selected.');
            }

            requestBody = JSON.serialize(requestMap);

            req.setEndpoint(ENDPOINT);
            req.setMethod(HTTP_METHOD);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBody);

            Http http = new Http();
            res = http.send(req);

            System.debug('Delivery API Status Code: ' + res.getStatusCode());
            System.debug('Delivery API Response: ' + res.getBody());

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                if (String.isBlank(res.getBody())) {
                    return resultList;
                }

                Object rawResponse = JSON.deserializeUntyped(res.getBody());

                if (rawResponse instanceof List<Object>) {
                    List<Object> responseList = (List<Object>) rawResponse;

                    for (Object obj : responseList) {
                        if (obj instanceof Map<String, Object>) {
                            Map<String, Object> row = (Map<String, Object>) obj;
                            DeliveryInfoWrapper wrap = new DeliveryInfoWrapper();

                            wrap.deliveryNo = getStringValue(row, 'DELIVERY_NO');
                            wrap.deliveryLineItemNo = getStringValue(row, 'DELIVERY_LINE_ITEM_NO');
                            wrap.salesOrderNo = getStringValue(row, 'SALES_ORDER_NO');
                            wrap.salesOrderLineItem = getStringValue(row, 'SALES_ORDER_LINE_ITEM');
                            wrap.deliveryItem = getStringValue(row, 'DELIVERY_ITEM');
                            wrap.deliveryItemDescription = getStringValue(row, 'DELIVERY_ITEM_DESCRIPTION');
                            wrap.deliveryDate = getStringValue(row, 'DELIVERY_DATE');
                            wrap.deliveryQuantity = getStringValue(row, 'DELIVERY_QUANTITY');
                            wrap.plant = getStringValue(row, 'PLANT');
                            wrap.storageLocation = getStringValue(row, 'STORAGE_LOCATION');
                            wrap.netPrice = getStringValue(row, 'NET_PRICE');
                            wrap.netValue = getStringValue(row, 'NET_VALUE');

                            resultList.add(wrap);
                        }
                    }
                } else {
                    logIntegrationError(
                        requestBody,
                        ENDPOINT,
                        HTTP_METHOD,
                        'Unexpected response format received from SAP.',
                        '',
                        'INVALID_RESPONSE_FORMAT',
                        res.getStatusCode()
                    );
                    throw new AuraHandledException('Unexpected response format received from SAP.');
                }

                return resultList;

            } else {
                logIntegrationError(
                    requestBody,
                    ENDPOINT,
                    HTTP_METHOD,
                    res.getBody(),
                    '',
                    'HTTP_ERROR',
                    res.getStatusCode()
                );
                throw new AuraHandledException('SAP API call failed. Status Code: ' + res.getStatusCode());
            }

        } catch (AuraHandledException ex) {
            throw ex;

        } catch (Exception ex) {
            Integer statusCode = (res != null) ? res.getStatusCode() : null;

            logIntegrationError(
                requestBody,
                ENDPOINT,
                HTTP_METHOD,
                ex.getMessage(),
                ex.getStackTraceString(),
                ex.getTypeName(),
                statusCode
            );

            throw new AuraHandledException('Error while fetching Delivery Information: ' + ex.getMessage());
        }
    }

    private static String formatDateYYYYMMDD(Date inputDate) {
        String monthStr = (inputDate.month() < 10 ? '0' : '') + String.valueOf(inputDate.month());
        String dayStr   = (inputDate.day() < 10 ? '0' : '') + String.valueOf(inputDate.day());
        return String.valueOf(inputDate.year()) + monthStr + dayStr;
    }

    private static String getStringValue(Map<String, Object> row, String key) {
        return row.containsKey(key) && row.get(key) != null ? String.valueOf(row.get(key)) : '';
    }

    private static void logIntegrationError(
        String requestParams,
        String requestUri,
        String httpMethod,
        String errorMessage,
        String stackTrace,
        String errorCode,
        Integer statusCode
    ) {
        try {
            Integration_Error_Log__c logRec = new Integration_Error_Log__c();
            logRec.API_Name__c = API_NAME;
            logRec.Error_Code__c = errorCode;
            logRec.Error_Message__c = errorMessage != null ? errorMessage.left(255) : null;
            logRec.Http_Method__c = httpMethod;
            logRec.Logged_On__c = string.valueOf(System.now());
            logRec.Request_Parameters__c = requestParams;
            logRec.Request_URI__c = requestUri;
            logRec.Source_System__c = SOURCE_SYSTEM;
            logRec.Stack_Trace__c = stackTrace;
            logRec.Status_Code__c = statusCode != null ? Decimal.valueOf(statusCode) : null;
            insert logRec;
        } catch (Exception loggingEx) {
            System.debug('Failed to log integration error: ' + loggingEx.getMessage());
        }
    }
}
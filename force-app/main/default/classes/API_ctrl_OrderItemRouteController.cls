public with sharing class API_ctrl_OrderItemRouteController {

    private static final String API_NAME = 'Route Master API';
    private static final String HTTP_METHOD = 'POST';
    private static final String REQUEST_URI = 'callout:NC_SAP_API/http/routeMast';
    private static final String SOURCE_SYSTEM = 'SAP';

    public class RouteOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public String route;
        @AuraEnabled public String routeDescription;

        public RouteOption() {}

        public RouteOption(String route, String routeDescription) {
            this.route = route;
            this.routeDescription = routeDescription;
            this.value = route + ' | ' + routeDescription;
            this.label = route + ' - ' + routeDescription;
        }
    }

    public class RouteResponseWrapper {
        @AuraEnabled public List<RouteOption> options = new List<RouteOption>();
        @AuraEnabled public String rawResponse;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=false)
    public static RouteResponseWrapper getRouteOptions(Id orderItemId) {
        RouteResponseWrapper result = new RouteResponseWrapper();
        String requestBodyString = '';

        try {
            if (orderItemId == null) {
                throw new AuraHandledException('Order Item Id is required.');
            }

            OrderItem oi = [
                SELECT Id, Sold_to_party__c, Material_Code__c
                FROM OrderItem
                WHERE Id = :orderItemId
                LIMIT 1
            ];

            Map<String, Object> requestBody = new Map<String, Object>{
                'SOLD_TO_PARTY' => oi.Sold_to_party__c,
                'MATERIAL'      => oi.Material_Code__c
            };

            requestBodyString = JSON.serialize(requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(REQUEST_URI);
            req.setMethod(HTTP_METHOD);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBodyString);

            Http http = new Http();
            HttpResponse res = http.send(req);

            result.rawResponse = res.getBody();

            Integer statusCode = res.getStatusCode();

            if (statusCode >= 200 && statusCode < 300) {
                result.options = parseRouteOptions(res.getBody());
                result.success = true;
                result.message = result.options.isEmpty()
                    ? 'No route values found from API.'
                    : 'Route values fetched successfully.';
            } else {
                logIntegrationError(
                    API_NAME,
                    String.valueOf(statusCode),
                    res.getStatus(),
                    HTTP_METHOD,
                    requestBodyString,
                    REQUEST_URI,
                    SOURCE_SYSTEM,
                    null,
                    String.valueOf(statusCode)
                );

                throw new AuraHandledException('API call failed. Status Code: ' + statusCode + ', Response: ' + res.getBody());
            }

            return result;

        } catch (Exception e) {
            logIntegrationError(
                API_NAME,
                'EXCEPTION',
                e.getMessage(),
                HTTP_METHOD,
                requestBodyString,
                REQUEST_URI,
                SOURCE_SYSTEM,
                e.getStackTraceString(),
                null
            );
            throw new AuraHandledException('Error while fetching route values: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveSelectedRoute(Id orderItemId, String selectedValue) {
        try {
            if (orderItemId == null) {
                throw new AuraHandledException('Order Item Id is required.');
            }

            if (String.isBlank(selectedValue)) {
                throw new AuraHandledException('Please select a route value.');
            }

            OrderItem oiToUpdate = new OrderItem(
                Id = orderItemId,
                Route_Description__c = selectedValue
            );
            update oiToUpdate;

            return 'Route value saved successfully.';
        } catch (Exception e) {
            logIntegrationError(
                API_NAME,
                'SAVE_EXCEPTION',
                e.getMessage(),
                'UPDATE',
                'orderItemId=' + String.valueOf(orderItemId) + ', selectedValue=' + selectedValue,
                'OrderItem Update',
                'Salesforce',
                e.getStackTraceString(),
                null
            );
            throw new AuraHandledException('Error while saving selected route: ' + e.getMessage());
        }
    }

    private static List<RouteOption> parseRouteOptions(String responseBody) {
        List<RouteOption> options = new List<RouteOption>();

        if (String.isBlank(responseBody)) {
            return options;
        }

        Object rawObj = JSON.deserializeUntyped(responseBody);

        if (!(rawObj instanceof Map<String, Object>)) {
            return options;
        }

        Map<String, Object> responseMap = (Map<String, Object>) rawObj;

        /*
         Handles possible API structures like:
         {
             "ROUTE": [
                 {
                     "ROUTE": "R001",
                     "ROUTE_DESCRIPTION": "Kolkata Route"
                 }
             ]
         }

         or
         {
             "DATA": [
                 {
                     "ROUTE": "R001",
                     "ROUTE_DESCRIPTION": "Kolkata Route"
                 }
             ]
         }
        */

        List<Object> dataList = new List<Object>();

        if (responseMap.containsKey('ROUTE') && responseMap.get('ROUTE') instanceof List<Object>) {
            dataList = (List<Object>) responseMap.get('ROUTE');
        } else if (responseMap.containsKey('DATA') && responseMap.get('DATA') instanceof List<Object>) {
            dataList = (List<Object>) responseMap.get('DATA');
        } else if (responseMap.containsKey('d') && responseMap.get('d') instanceof List<Object>) {
            dataList = (List<Object>) responseMap.get('d');
        }

        for (Object rowObj : dataList) {
            if (rowObj instanceof Map<String, Object>) {
                Map<String, Object> row = (Map<String, Object>) rowObj;

                String route = '';
                String routeDescription = '';

                if (row.containsKey('ROUTE')) {
                    route = String.valueOf(row.get('ROUTE'));
                } else if (row.containsKey('Route')) {
                    route = String.valueOf(row.get('Route'));
                }

                if (row.containsKey('ROUTE_DESCRIPTION')) {
                    routeDescription = String.valueOf(row.get('ROUTE_DESCRIPTION'));
                } else if (row.containsKey('ROUTE_DESC')) {
                    routeDescription = String.valueOf(row.get('ROUTE_DESC'));
                } else if (row.containsKey('RouteDescription')) {
                    routeDescription = String.valueOf(row.get('RouteDescription'));
                }

                if (!String.isBlank(route) || !String.isBlank(routeDescription)) {
                    options.add(new RouteOption(route, routeDescription));
                }
            }
        }

        return options;
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
            Integration_Error_Log__c logRec = new Integration_Error_Log__c();
            logRec.API_Name__c = apiName;
            logRec.Error_Code__c = errorCode;
            logRec.Error_Message__c = errorMessage;
            logRec.Http_Method__c = httpMethod;
            logRec.Logged_On__c = String.valueOf(System.now());
            logRec.Request_Parameters__c = requestParameters;
            logRec.Request_URI__c = requestUri;
            logRec.Source_System__c = sourceSystem;
            logRec.Stack_Trace__c = stackTrace;
            logRec.Status_Code__c = Decimal.valueOf(statusCode);

            insert logRec;
        } catch (Exception ex) {
            System.debug('Failed to log integration error: ' + ex.getMessage());
        }
    }
}
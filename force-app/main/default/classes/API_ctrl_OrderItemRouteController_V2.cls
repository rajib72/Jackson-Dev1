public with sharing class API_ctrl_OrderItemRouteController_V2 {

    private static final String API_NAME =
        'Route Master API';

    private static final String HTTP_METHOD =
        'POST';

    private static final String REQUEST_URI =
        'callout:NC_SAP_API/http/routeMast';

    private static final String SOURCE_SYSTEM =
        'SAP';

    /**
     * One Route option returned to the LWC.
     */
    public class RouteOption {
        @AuraEnabled
        public String value;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String route;

        @AuraEnabled
        public String routeDescription;

        public RouteOption() {
        }

        public RouteOption(
            String route,
            String routeDescription
        ) {
            this.route = route;
            this.routeDescription = routeDescription;
            this.value = route;

            this.label = String.isBlank(routeDescription)
                ? route
                : route + ' - ' + routeDescription;
        }
    }

    /**
     * Complete response returned to the LWC.
     */
    public class RouteResponseWrapper {
        @AuraEnabled
        public List<RouteOption> options =
            new List<RouteOption>();

        @AuraEnabled
        public String rawResponse;

        @AuraEnabled
        public Boolean success = false;

        @AuraEnabled
        public String message;
    }

    /**
     * Fetch available Route values from SAP.
     */
    @AuraEnabled(cacheable=false)
    public static RouteResponseWrapper getRouteOptions(
        Id orderItemId
    ) {
        RouteResponseWrapper result =
            new RouteResponseWrapper();

        String requestBodyString = '';
        Integer responseStatusCode;
        String responseStatus;

        try {
            if (orderItemId == null) {
                throw new AuraHandledException(
                    'Order Item Id is required.'
                );
            }

            OrderItem orderItemRecord = [
                SELECT
                    Id,
                    Sold_to_party__c,
                    Material_Code__c
                FROM OrderItem
                WHERE Id = :orderItemId
                LIMIT 1
            ];

            Map<String, Object> requestBody =
                new Map<String, Object>{
                    'SOLD_TO_PARTY' =>
                        orderItemRecord.Sold_to_party__c,

                    'MATERIAL' =>
                        orderItemRecord.Material_Code__c
                };

            requestBodyString =
                JSON.serialize(requestBody);

            HttpRequest request =
                new HttpRequest();

            request.setEndpoint(REQUEST_URI);
            request.setMethod(HTTP_METHOD);

            request.setHeader(
                'Content-Type',
                'application/json'
            );

            request.setTimeout(120000);
            request.setBody(requestBodyString);

            Http http = new Http();

            HttpResponse response =
                http.send(request);

            responseStatusCode =
                response.getStatusCode();

            responseStatus =
                response.getStatus();

            result.rawResponse =
                response.getBody();

            if (
                responseStatusCode >= 200 &&
                responseStatusCode < 300
            ) {
                result.options =
                    parseRouteOptions(
                        response.getBody()
                    );

                result.success = true;

                result.message =
                    result.options.isEmpty()
                        ? 'No route values found from API.'
                        : 'Route values fetched successfully.';

                return result;
            }

            throw new AuraHandledException(
                'API call failed. Status Code: ' +
                responseStatusCode +
                ', Status: ' +
                responseStatus +
                ', Response: ' +
                response.getBody()
            );

        } catch (Exception exceptionRecord) {
            String statusCodeText =
                responseStatusCode == null
                    ? null
                    : String.valueOf(responseStatusCode);

            String errorCode =
                responseStatusCode == null
                    ? 'EXCEPTION'
                    : statusCodeText;

            logIntegrationError(
                API_NAME,
                errorCode,
                exceptionRecord.getMessage(),
                HTTP_METHOD,
                requestBodyString,
                REQUEST_URI,
                SOURCE_SYSTEM,
                exceptionRecord.getStackTraceString(),
                statusCodeText
            );

            throw new AuraHandledException(
                'Error while fetching route values: ' +
                exceptionRecord.getMessage()
            );
        }
    }

    /**
     * Save selected Route and Route Description
     * on the Order Item.
     */
    @AuraEnabled
    public static String saveSelectedRoute(
        Id orderItemId,
        String route,
        String routeDescription
    ) {
        try {
            if (orderItemId == null) {
                throw new AuraHandledException(
                    'Order Item Id is required.'
                );
            }

            if (String.isBlank(route)) {
                throw new AuraHandledException(
                    'Please select a route.'
                );
            }

            OrderItem orderItemToUpdate =
                new OrderItem(
                    Id = orderItemId,
                    Route__c = route.trim(),
                    Route_Description__c =
                        String.isBlank(routeDescription)
                            ? null
                            : routeDescription.trim()
                );

            update orderItemToUpdate;

            return
                'Route and Route Description saved successfully.';

        } catch (Exception exceptionRecord) {
            logIntegrationError(
                API_NAME,
                'SAVE_EXCEPTION',
                exceptionRecord.getMessage(),
                'UPDATE',
                'orderItemId=' +
                    String.valueOf(orderItemId) +
                    ', route=' +
                    route +
                    ', routeDescription=' +
                    routeDescription,
                'OrderItem Update',
                'Salesforce',
                exceptionRecord.getStackTraceString(),
                null
            );

            throw new AuraHandledException(
                'Error while saving selected route: ' +
                exceptionRecord.getMessage()
            );
        }
    }

    /**
     * Parse Route values from the SAP response.
     */
    private static List<RouteOption> parseRouteOptions(
        String responseBody
    ) {
        List<RouteOption> options =
            new List<RouteOption>();

        if (String.isBlank(responseBody)) {
            return options;
        }

        Object rawResponse =
            JSON.deserializeUntyped(responseBody);

        if (
            !(rawResponse instanceof Map<String, Object>)
        ) {
            return options;
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) rawResponse;

        List<Object> dataList =
            extractRouteDataList(responseMap);

        Set<String> existingOptionKeys =
            new Set<String>();

        for (Object rowObject : dataList) {
            if (
                !(rowObject instanceof Map<String, Object>)
            ) {
                continue;
            }

            Map<String, Object> row =
                (Map<String, Object>) rowObject;

            String route =
                getFirstAvailableString(
                    row,
                    new List<String>{
                        'ROUTE',
                        'Route',
                        'route'
                    }
                );

            String routeDescription =
                getFirstAvailableString(
                    row,
                    new List<String>{
                        'ROUTE_DESCRIPTION',
                        'ROUTE_DESC',
                        'RouteDescription',
                        'routeDescription',
                        'DESCRIPTION',
                        'Description'
                    }
                );

            /*
             * Ignore completely blank rows.
             */
            if (
                String.isBlank(route) &&
                String.isBlank(routeDescription)
            ) {
                continue;
            }

            /*
             * Prevent duplicate dropdown options.
             */
            String optionKey =
                String.valueOf(route).toLowerCase() +
                '|' +
                String.valueOf(routeDescription).toLowerCase();

            if (existingOptionKeys.contains(optionKey)) {
                continue;
            }

            existingOptionKeys.add(optionKey);

            options.add(
                new RouteOption(
                    route,
                    routeDescription
                )
            );
        }

        return options;
    }

    /**
     * Extract the list of Route records from supported
     * SAP response structures.
     */
    private static List<Object> extractRouteDataList(
        Map<String, Object> responseMap
    ) {
        List<String> possibleListKeys =
            new List<String>{
                'ROUTE',
                'DATA',
                'data',
                'd',
                'RESULT',
                'result'
            };

        for (String keyName : possibleListKeys) {
            if (!responseMap.containsKey(keyName)) {
                continue;
            }

            Object candidate =
                responseMap.get(keyName);

            if (candidate instanceof List<Object>) {
                return (List<Object>) candidate;
            }

            /*
             * Support a nested wrapper, for example:
             *
             * {
             *     "d": {
             *         "results": [...]
             *     }
             * }
             */
            if (
                candidate instanceof Map<String, Object>
            ) {
                Map<String, Object> nestedMap =
                    (Map<String, Object>) candidate;

                List<String> nestedListKeys =
                    new List<String>{
                        'results',
                        'RESULTS',
                        'ROUTE',
                        'DATA',
                        'data'
                    };

                for (
                    String nestedKey :
                    nestedListKeys
                ) {
                    if (
                        nestedMap.containsKey(nestedKey) &&
                        nestedMap.get(nestedKey)
                            instanceof List<Object>
                    ) {
                        return (List<Object>)
                            nestedMap.get(nestedKey);
                    }
                }
            }
        }

        return new List<Object>();
    }

    /**
     * Return the first nonblank String value found
     * using the supplied possible keys.
     */
    private static String getFirstAvailableString(
        Map<String, Object> sourceMap,
        List<String> possibleKeys
    ) {
        for (String keyName : possibleKeys) {
            if (!sourceMap.containsKey(keyName)) {
                continue;
            }

            Object rawValue =
                sourceMap.get(keyName);

            if (rawValue == null) {
                continue;
            }

            String stringValue =
                String.valueOf(rawValue).trim();

            if (
                String.isNotBlank(stringValue) &&
                stringValue.toLowerCase() != 'null'
            ) {
                return stringValue;
            }
        }

        return '';
    }

    /**
     * Create an Integration Error Log record.
     */
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
            Integration_Error_Log__c logRecord =
                new Integration_Error_Log__c();

            logRecord.API_Name__c =
                apiName;

            logRecord.Error_Code__c =
                errorCode;

            logRecord.Error_Message__c =
                errorMessage;

            logRecord.Http_Method__c =
                httpMethod;

            logRecord.Logged_On__c =
                String.valueOf(System.now());

            logRecord.Request_Parameters__c =
                requestParameters;

            logRecord.Request_URI__c =
                requestUri;

            logRecord.Source_System__c =
                sourceSystem;

            logRecord.Stack_Trace__c =
                stackTrace;

            /*
             * Avoid Decimal.valueOf(null) errors.
             */
            if (String.isNotBlank(statusCode)) {
                try {
                    logRecord.Status_Code__c =
                        Decimal.valueOf(statusCode);
                } catch (Exception statusException) {
                    System.debug(
                        'Unable to convert status code: ' +
                        statusCode
                    );
                }
            }

            insert logRecord;

        } catch (Exception logException) {
            System.debug(
                'Failed to log integration error: ' +
                logException.getMessage()
            );
        }
    }
}
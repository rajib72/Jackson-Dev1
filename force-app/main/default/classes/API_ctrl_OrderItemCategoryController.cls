public with sharing class API_ctrl_OrderItemCategoryController {

    private static final String API_NAME =
        'Item Category API';

    private static final String ENDPOINT =
        'callout:NC_SAP_API/http/itemCatgMast';

    private static final String HTTP_METHOD =
        'POST';

    private static final String SOURCE_SYSTEM =
        'SAP';

    /**
     * One Item Category option returned to the LWC.
     */
    public class ItemCategoryWrapper {
        @AuraEnabled
        public String label;

        @AuraEnabled
        public String value;

        public ItemCategoryWrapper() {
        }

        public ItemCategoryWrapper(
            String label,
            String value
        ) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * Complete response returned to the LWC.
     */
    public class ResponseWrapper {
        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public String message;

        @AuraEnabled
        public List<ItemCategoryWrapper> options;

        public ResponseWrapper() {
            this.success = false;
            this.options =
                new List<ItemCategoryWrapper>();
        }

        public ResponseWrapper(
            Boolean success,
            String message,
            List<ItemCategoryWrapper> options
        ) {
            this.success = success;
            this.message = message;

            this.options = options == null
                ? new List<ItemCategoryWrapper>()
                : options;
        }
    }

    /**
     * Fetch Item Categories from SAP.
     */
    @AuraEnabled(cacheable=false)
    public static ResponseWrapper fetchItemCategories(
        Id orderItemId
    ) {
        String requestBody = '';
        Integer statusCode;
        String responseBody = '';

        try {
            if (orderItemId == null) {
                throw new AuraHandledException(
                    'Order Item Id is required.'
                );
            }

            OrderItem orderItemRecord = [
                SELECT
                    Id,
                    Order_Type__c,
                    Material_Code__c,
                    Sales_Org__c
                FROM OrderItem
                WHERE Id = :orderItemId
                LIMIT 1
            ];

            Map<String, Object> requestMap =
                new Map<String, Object>{
                    'ORDER_TYPE' =>
                        orderItemRecord.Order_Type__c,

                    'MATERIAL' =>
                        orderItemRecord.Material_Code__c,

                    'SALES_ORG' =>
                        orderItemRecord.Sales_Org__c
                };

            requestBody =
                JSON.serialize(requestMap);

            System.debug(
                '===== ITEM CATEGORY REQUEST BODY ===== ' +
                requestBody
            );

            HttpRequest request =
                new HttpRequest();

            request.setEndpoint(ENDPOINT);
            request.setMethod(HTTP_METHOD);

            request.setHeader(
                'Content-Type',
                'application/json'
            );

            request.setTimeout(120000);
            request.setBody(requestBody);

            Http http =
                new Http();

            HttpResponse response =
                http.send(request);

            statusCode =
                response.getStatusCode();

            responseBody =
                response.getBody();

            System.debug(
                '===== ITEM CATEGORY STATUS CODE ===== ' +
                statusCode
            );

            System.debug(
                '===== ITEM CATEGORY RESPONSE BODY ===== ' +
                responseBody
            );

            if (
                statusCode < 200 ||
                statusCode >= 300
            ) {
                logIntegrationError(
                    API_NAME,
                    String.valueOf(statusCode),
                    'SAP API returned a non-success status code. Response: ' +
                        responseBody,
                    HTTP_METHOD,
                    requestBody,
                    ENDPOINT,
                    SOURCE_SYSTEM,
                    null,
                    statusCode
                );

                return new ResponseWrapper(
                    false,
                    'SAP API failed. Status Code: ' +
                        statusCode,
                    new List<ItemCategoryWrapper>()
                );
            }

            List<ItemCategoryWrapper> options =
                parseItemCategories(
                    responseBody
                );

            if (options.isEmpty()) {
                return new ResponseWrapper(
                    false,
                    'No Item Category found from SAP.',
                    new List<ItemCategoryWrapper>()
                );
            }

            return new ResponseWrapper(
                true,
                'Item Categories fetched successfully.',
                options
            );

        } catch (Exception exceptionRecord) {
            System.debug(
                '===== ITEM CATEGORY ERROR ===== ' +
                exceptionRecord.getMessage()
            );

            System.debug(
                '===== ITEM CATEGORY STACK TRACE ===== ' +
                exceptionRecord.getStackTraceString()
            );

            logIntegrationError(
                API_NAME,
                exceptionRecord.getTypeName(),
                exceptionRecord.getMessage(),
                HTTP_METHOD,
                requestBody,
                ENDPOINT,
                SOURCE_SYSTEM,
                exceptionRecord.getStackTraceString(),
                statusCode
            );

            throw new AuraHandledException(
                'Error while fetching Item Category: ' +
                exceptionRecord.getMessage()
            );
        }
    }

    /**
     * Save the selected Item Category on Order Item.
     */
    @AuraEnabled
    public static String saveItemCategory(
        Id orderItemId,
        String selectedItemCategory
    ) {
        try {
            if (orderItemId == null) {
                throw new AuraHandledException(
                    'Order Item Id is required.'
                );
            }

            if (
                String.isBlank(
                    selectedItemCategory
                )
            ) {
                throw new AuraHandledException(
                    'Please select an Item Category.'
                );
            }

            String cleanedItemCategory =
                selectedItemCategory.trim();

            OrderItem orderItemToUpdate =
                new OrderItem(
                    Id = orderItemId,
                    Item_Category__c =
                        cleanedItemCategory
                );

            update orderItemToUpdate;

            return
                'Item Category saved successfully on Order Item.';

        } catch (Exception exceptionRecord) {
            logIntegrationError(
                'Item Category Save',
                exceptionRecord.getTypeName(),
                exceptionRecord.getMessage(),
                'DML',
                'OrderItemId: ' +
                    String.valueOf(orderItemId) +
                    ', Selected Item Category: ' +
                    selectedItemCategory,
                'OrderItem Update',
                'Salesforce',
                exceptionRecord.getStackTraceString(),
                null
            );

            throw new AuraHandledException(
                'Error while saving Item Category: ' +
                exceptionRecord.getMessage()
            );
        }
    }

    /**
     * Parse Item Categories returned by SAP.
     */
    private static List<ItemCategoryWrapper>
        parseItemCategories(
            String responseBody
        ) {
        List<ItemCategoryWrapper> options =
            new List<ItemCategoryWrapper>();

        if (String.isBlank(responseBody)) {
            return options;
        }

        Object rawObject =
            JSON.deserializeUntyped(
                responseBody
            );

        if (
            !(rawObject instanceof
                Map<String, Object>)
        ) {
            return options;
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) rawObject;

        /*
         * SAP currently returns:
         *
         * {
         *     "ITEM_CATAGORY": [
         *         {
         *             "ITEM_CATAGORY": "TANN"
         *         }
         *     ]
         * }
         *
         * The misspelled ITEM_CATAGORY key is supported,
         * along with the correctly spelled ITEM_CATEGORY key.
         */
        Object itemCategoryObject =
            getFirstAvailableValue(
                responseMap,
                new List<String>{
                    'ITEM_CATAGORY',
                    'ITEM_CATEGORY',
                    'item_catagory',
                    'item_category'
                }
            );

        if (
            itemCategoryObject == null ||
            !(itemCategoryObject
                instanceof List<Object>)
        ) {
            return options;
        }

        List<Object> itemCategoryList =
            (List<Object>) itemCategoryObject;

        Set<String> normalizedUniqueValues =
            new Set<String>();

        for (
            Object rowObject :
            itemCategoryList
        ) {
            String categoryValue = '';

            /*
             * Support an object structure:
             *
             * {
             *     "ITEM_CATAGORY": "TANN"
             * }
             */
            if (
                rowObject instanceof
                    Map<String, Object>
            ) {
                Map<String, Object> rowMap =
                    (Map<String, Object>)
                        rowObject;

                categoryValue =
                    getFirstAvailableString(
                        rowMap,
                        new List<String>{
                            'ITEM_CATAGORY',
                            'ITEM_CATEGORY',
                            'item_catagory',
                            'item_category'
                        }
                    );
            }

            /*
             * Also support a simple list:
             *
             * {
             *     "ITEM_CATAGORY": [
             *         "TANN",
             *         "TAN"
             *     ]
             * }
             */
            else if (rowObject != null) {
                categoryValue =
                    String.valueOf(
                        rowObject
                    ).trim();
            }

            if (
                String.isBlank(
                    categoryValue
                )
            ) {
                continue;
            }

            String normalizedValue =
                categoryValue
                    .trim()
                    .toLowerCase();

            /*
             * Prevent duplicate values, including duplicates
             * with different letter casing.
             */
            if (
                normalizedUniqueValues.contains(
                    normalizedValue
                )
            ) {
                continue;
            }

            normalizedUniqueValues.add(
                normalizedValue
            );

            String cleanedValue =
                categoryValue.trim();

            options.add(
                new ItemCategoryWrapper(
                    cleanedValue,
                    cleanedValue
                )
            );
        }

        return options;
    }

    /**
     * Return the first available object value from a map.
     */
    private static Object getFirstAvailableValue(
        Map<String, Object> sourceMap,
        List<String> possibleKeys
    ) {
        for (String keyName : possibleKeys) {
            if (
                sourceMap.containsKey(
                    keyName
                ) &&
                sourceMap.get(keyName) != null
            ) {
                return sourceMap.get(
                    keyName
                );
            }
        }

        return null;
    }

    /**
     * Return the first nonblank String value.
     */
    private static String getFirstAvailableString(
        Map<String, Object> sourceMap,
        List<String> possibleKeys
    ) {
        for (String keyName : possibleKeys) {
            if (
                !sourceMap.containsKey(
                    keyName
                )
            ) {
                continue;
            }

            Object rawValue =
                sourceMap.get(keyName);

            if (rawValue == null) {
                continue;
            }

            String stringValue =
                String.valueOf(
                    rawValue
                ).trim();

            if (
                String.isNotBlank(
                    stringValue
                ) &&
                stringValue.toLowerCase() !=
                    'null'
            ) {
                return stringValue;
            }
        }

        return '';
    }

    /**
     * Save an Integration Error Log record.
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
        Integer statusCode
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
                String.valueOf(
                    System.now()
                );

            logRecord.Request_Parameters__c =
                requestParameters;

            logRecord.Request_URI__c =
                requestUri;

            logRecord.Source_System__c =
                sourceSystem;

            logRecord.Stack_Trace__c =
                stackTrace;

            if (statusCode != null) {
                logRecord.Status_Code__c =
                    Decimal.valueOf(
                        String.valueOf(
                            statusCode
                        )
                    );
            }

            insert logRecord;

        } catch (Exception logException) {
            System.debug(
                '===== ERROR LOG INSERT FAILED ===== ' +
                logException.getMessage()
            );
        }
    }
}
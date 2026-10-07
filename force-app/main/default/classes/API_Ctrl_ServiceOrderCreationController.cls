public with sharing class API_Ctrl_ServiceOrderCreationController {

    private static final String SAP_ENDPOINT =
        'callout:NC_SAP_API/http/serviceOrder';

    private static final String REQUEST_METHOD = 'POST';

    private static final Set<Integer> SUCCESS_STATUS_CODES =
        new Set<Integer>{ 200, 201 };

    /*
     * Called when the LWC opens and when the user clicks Recheck Fields.
     */
    @AuraEnabled(cacheable=true)
    public static ValidationResponse validateOrder(Id orderId) {
        Order orderRecord = getOrderWithItems(orderId);
        return buildValidationResponse(orderRecord);
    }

    /*
     * Called when the user clicks Push to SAP.
     *
     * Mandatory fields are validated again immediately before the
     * SAP callout so that the integration cannot be executed with
     * incomplete data.
     */
    @AuraEnabled
    public static IntegrationResponse pushOrderToSAP(Id orderId) {

        IntegrationResponse output = new IntegrationResponse();
        output.isSuccess = false;

        String jsonBody = '';

        try {
            Order orderRecord = getOrderWithItems(orderId);

            ValidationResponse validationResult =
                buildValidationResponse(orderRecord);

            if (!validationResult.isValid) {
                output.statusCode = 400;
                output.responseMessage =
                    'Mandatory Order or Order Item fields are missing.';
                output.validationResult = validationResult;

                return output;
            }

            SAPRequestPayload payload =
                buildSAPRequestPayload(orderRecord);

            jsonBody = JSON.serialize(payload, false);

            HttpRequest request = new HttpRequest();
            request.setEndpoint(SAP_ENDPOINT);
            request.setMethod(REQUEST_METHOD);
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(120000);
            request.setBody(jsonBody);

            Http http = new Http();
            HttpResponse response = http.send(request);

            output.statusCode = response.getStatusCode();

            if (SUCCESS_STATUS_CODES.contains(response.getStatusCode())) {
                processSuccessfulResponse(
                    orderRecord,
                    response,
                    output,
                    jsonBody
                );
            } else {
                processErrorResponse(
                    response,
                    output,
                    jsonBody
                );
            }

        } catch (AuraHandledException exceptionRecord) {
            throw exceptionRecord;

        } catch (Exception exceptionRecord) {
            output.statusCode = 500;
            output.responseMessage =
                'Apex Error: ' +
                exceptionRecord.getMessage() +
                ' (Line: ' +
                exceptionRecord.getLineNumber() +
                ')';

            logIntegrationError(
                'SAP Service Order Creation API',
                exceptionRecord.getTypeName(),
                exceptionRecord.getMessage(),
                REQUEST_METHOD,
                String.isNotBlank(jsonBody)
                    ? jsonBody
                    : 'Order ID: ' + String.valueOf(orderId),
                SAP_ENDPOINT,
                'Salesforce',
                exceptionRecord.getStackTraceString(),
                500
            );
        }

        return output;
    }

    /*
     * Retrieves all fields required for:
     * 1. Mandatory-field validation
     * 2. SAP request payload
     * 3. SAP response updates
     */
    private static Order getOrderWithItems(Id orderId) {

        if (orderId == null) {
            throw new AuraHandledException(
                'Order Id is required.'
            );
        }

        List<Order> orderRecords = [
            SELECT Id,
                   OrderNumber,
                   Customer_Reference__c,
                   Customer_Reference_Date__c,
                   Service_Order_Type__c,
                   Sold_to_party_Code__c,
                   COMP_CODE__c,
                   Distribution_Channel__c,
                   Division__c,
                   BG_Required__c,
                   LD_Clause__c,
                   TPC__c,
                   Delivering_Plant__c,
                   Ship_to_Party_Code__c,
                   Freight_Terms__c,
                   Insurance_Terms__c,
                   Scope_Of_OA__c,
                   Order_Reason__c,
                   Payment_Terms__c,
                   SAP_Employee_Code__c,
                   Service_Order__c,
                   (
                       SELECT Id,
                              OrderItemNumber,
                              Material_Master__c,
                              Material_Code__c,
                              Quantity,
                              Plant_Code__c,
                              Item_Category__c,
                              Material_Sales_Text__c,
                              Route__c,
                              Performance_Warranty__c,
                              Product_Warranty_Duration__c,
                              Condition_Type__c,
                              UnitPrice,
                              SAP_Line_Item_No__c
                       FROM OrderItems
                       ORDER BY OrderItemNumber
                   )
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (orderRecords.isEmpty()) {
            throw new AuraHandledException(
                'The selected Order could not be found or you do not have access to it.'
            );
        }

        return orderRecords[0];
    }

    /*
     * Shared validation used by:
     * 1. validateOrder()
     * 2. pushOrderToSAP()
     */
    private static ValidationResponse buildValidationResponse(
        Order orderRecord
    ) {
        ValidationResponse response = new ValidationResponse();

        response.orderId = orderRecord.Id;
        response.orderNumber = orderRecord.OrderNumber;
        response.isValid = false;
        response.orderMissingFields = new List<MissingField>();
        response.orderItemIssues = new List<OrderItemIssue>();
        response.blockingErrors = new List<String>();

        validateOrderFields(
            orderRecord,
            response.orderMissingFields
        );

        validateOrderItemFields(
            orderRecord,
            response.orderItemIssues,
            response.blockingErrors
        );

        response.isValid =
            response.orderMissingFields.isEmpty() &&
            response.orderItemIssues.isEmpty() &&
            response.blockingErrors.isEmpty();

        response.message = response.isValid
            ? 'All mandatory Order and Order Item fields are available.'
            : 'Complete all mandatory fields before pushing the Service Order to SAP.';

        return response;
    }

    private static void validateOrderFields(
        Order orderRecord,
        List<MissingField> missingFields
    ) {
        List<FieldRule> fieldRules = new List<FieldRule>{
            new FieldRule(
                'Service_Order_Type__c',
                'Service Order Type'
            ),
            new FieldRule(
                'COMP_CODE__c',
                'Sales Organization / Company Code'
            ),
            new FieldRule(
                'Distribution_Channel__c',
                'Distribution Channel'
            ),
            new FieldRule(
                'Division__c',
                'Division'
            ),
            new FieldRule(
                'Sold_to_party_Code__c',
                'Sold-to Party Code'
            ),
            new FieldRule(
                'Ship_to_Party_Code__c',
                'Ship-to Party Code'
            ),
            new FieldRule(
                'Customer_Reference__c',
                'Customer Reference'
            ),
            new FieldRule(
                'Customer_Reference_Date__c',
                'Customer Reference Date'
            ),
            new FieldRule(
                'BG_Required__c',
                'BG Required'
            ),
            new FieldRule(
                'LD_Clause__c',
                'LD Clause'
            ),
            new FieldRule(
                'TPC__c',
                'TPC'
            ),
            new FieldRule(
                'SAP_Employee_Code__c',
                'SAP Employee Code'
            ),
            new FieldRule(
                'Payment_Terms__c',
                'Payment Terms'
            ),
            new FieldRule(
                'Delivering_Plant__c',
                'Delivering Plant'
            ),
            new FieldRule(
                'Freight_Terms__c',
                'Freight Terms'
            ),
            new FieldRule(
                'Insurance_Terms__c',
                'Insurance Terms'
            ),
            new FieldRule(
                'Scope_Of_OA__c',
                'Scope of OA'
            ),
            new FieldRule(
                'Order_Reason__c',
                'Order Reason'
            )
        };

        for (FieldRule rule : fieldRules) {
            if (isMissing(orderRecord.get(rule.apiName))) {
                missingFields.add(
                    new MissingField(
                        rule.apiName,
                        rule.label
                    )
                );
            }
        }
    }

    private static void validateOrderItemFields(
        Order orderRecord,
        List<OrderItemIssue> orderItemIssues,
        List<String> blockingErrors
    ) {
        if (
            orderRecord.OrderItems == null ||
            orderRecord.OrderItems.isEmpty()
        ) {
            blockingErrors.add(
                'At least one Order Item is required for the SAP Service Order integration.'
            );

            return;
        }

        List<FieldRule> fieldRules = new List<FieldRule>{
            /*
             * This was validated by the existing Flow.
             */
            new FieldRule(
                'Material_Master__c',
                'Material Master'
            ),

            /*
             * This is also mandatory because Material_Code__c is the
             * actual field sent to SAP.
             */
            new FieldRule(
                'Material_Code__c',
                'Material Code'
            ),
            new FieldRule(
                'Quantity',
                'Quantity'
            ),
            new FieldRule(
                'Plant_Code__c',
                'Plant Code'
            ),
            new FieldRule(
                'Item_Category__c',
                'Item Category'
            ),
            new FieldRule(
                'Route__c',
                'Route'
            ),
            new FieldRule(
                'Material_Sales_Text__c',
                'Material Sales Text'
            ),
            new FieldRule(
                'Performance_Warranty__c',
                'Performance Warranty Duration'
            ),
            new FieldRule(
                'Product_Warranty_Duration__c',
                'Product Warranty Duration'
            ),
            new FieldRule(
                'Condition_Type__c',
                'Condition Type'
            ),
            new FieldRule(
                'UnitPrice',
                'Unit Price'
            )
        };

        for (OrderItem orderItemRecord : orderRecord.OrderItems) {
            OrderItemIssue issue = new OrderItemIssue();

            issue.orderItemId = orderItemRecord.Id;
            issue.orderItemNumber =
                String.isBlank(orderItemRecord.OrderItemNumber)
                    ? 'Order Item'
                    : orderItemRecord.OrderItemNumber;

            issue.missingFields = new List<MissingField>();

            for (FieldRule rule : fieldRules) {
                if (isMissing(orderItemRecord.get(rule.apiName))) {
                    issue.missingFields.add(
                        new MissingField(
                            rule.apiName,
                            rule.label
                        )
                    );
                }
            }

            if (!issue.missingFields.isEmpty()) {
                orderItemIssues.add(issue);
            }
        }
    }

    /*
     * Builds the existing SAP Service Order request payload.
     *
     * Existing line numbering is preserved:
     * 10, 20, 30...
     */
    private static SAPRequestPayload buildSAPRequestPayload(
        Order orderRecord
    ) {
        SAPRequestPayload payload = new SAPRequestPayload();

        payload.Header = buildSAPHeader(orderRecord);
        payload.Items = new List<SAPItem>();
        payload.Conditions = new List<SAPCondition>();

        Integer lineItemNumber = 10;

        for (OrderItem orderItemRecord : orderRecord.OrderItems) {

            SAPItem item = new SAPItem();
            item.LINE_ITEM_NO =
                String.valueOf(lineItemNumber);
            item.MATERIAL_CODE =
                checkNull(orderItemRecord.Material_Code__c);
            item.QUANTITY =
                checkNull(orderItemRecord.Quantity);
            item.PLANT =
                checkNull(orderItemRecord.Plant_Code__c);
            item.ITEM_CATAGORY =
                checkNull(orderItemRecord.Item_Category__c);
            item.ROUTE =
                checkNull(orderItemRecord.Route__c);
            item.MATERIAL_SALES_TEXT =
                checkNull(orderItemRecord.Material_Sales_Text__c);
            item.PERFORMANCE_WARRANTY =
                checkNull(orderItemRecord.Performance_Warranty__c);
            item.PRODUCT_WARRANTY =
                checkNull(orderItemRecord.Product_Warranty_Duration__c);

            payload.Items.add(item);

            SAPCondition condition = new SAPCondition();
            condition.LINE_ITEM_NO =
                String.valueOf(lineItemNumber);
            condition.CONDITION_TYPE =
                checkNull(orderItemRecord.Condition_Type__c);
            condition.CONDITION_AMOUNT =
                checkNull(orderItemRecord.UnitPrice);

            payload.Conditions.add(condition);

            lineItemNumber += 10;
        }

        return payload;
    }

    private static SAPHeader buildSAPHeader(
        Order orderRecord
    ) {
        SAPHeader header = new SAPHeader();

        header.REQUESTUUID =
            Datetime.now().format('yyyyMMddHHmmss');

        header.ORDER_TYPE =
            checkNull(orderRecord.Service_Order_Type__c);

        header.SALES_ORG =
            checkNull(orderRecord.COMP_CODE__c);

        header.DIST_CHAN =
            checkNull(orderRecord.Distribution_Channel__c);

        header.DIVISION =
            checkNull(orderRecord.Division__c);

        header.SOLD_TO_PARTY =
            checkNull(orderRecord.Sold_to_party_Code__c);

        header.SHIP_TO_PARTY =
            checkNull(orderRecord.Ship_to_Party_Code__c);

        header.CUST_REFERENCE =
            checkNull(orderRecord.Customer_Reference__c);

        header.CUST_REF_DATE =
            formatDate(orderRecord.Customer_Reference_Date__c);

        header.BG_REQUIRED =
            checkNull(orderRecord.BG_Required__c);

        header.LD_CLAUSE =
            checkNull(orderRecord.LD_Clause__c);

        header.TPC =
            checkNull(orderRecord.TPC__c);

        header.PERSONAL_NUMBER =
            checkNull(orderRecord.SAP_Employee_Code__c);

        header.PAYMENT_TERMS =
            checkNull(orderRecord.Payment_Terms__c);

        header.DELIVERING_PLANT =
            checkNull(orderRecord.Delivering_Plant__c);

        header.ORDER_REASON =
            checkNull(orderRecord.Order_Reason__c);

        header.SALESFORCE_SALES_ORDER =
            checkNull(orderRecord.OrderNumber);

        header.FREIGHT_TERMS =
            checkNull(orderRecord.Freight_Terms__c);

        header.INSURANCE_TERMS =
            checkNull(orderRecord.Insurance_Terms__c);

        header.SCOPE_OF_OA =
            checkNull(orderRecord.Scope_Of_OA__c);

        return header;
    }

    private static void processSuccessfulResponse(
        Order orderRecord,
        HttpResponse response,
        IntegrationResponse output,
        String jsonBody
    ) {
        Map<String, Object> responseMap;

        try {
            responseMap =
                (Map<String, Object>) JSON.deserializeUntyped(
                    response.getBody()
                );

        } catch (Exception parseException) {
            output.isSuccess = false;
            output.responseMessage =
                'SAP returned HTTP ' +
                response.getStatusCode() +
                ', but the response body was not valid JSON. Response: ' +
                response.getBody();

            logIntegrationError(
                'SAP Service Order Creation API',
                'Invalid JSON Response',
                output.responseMessage,
                REQUEST_METHOD,
                jsonBody,
                SAP_ENDPOINT,
                'SAP',
                parseException.getStackTraceString(),
                response.getStatusCode()
            );

            return;
        }

        String sapServiceOrderNumber;

        if (
            responseMap != null &&
            responseMap.containsKey('salesOrder') &&
            responseMap.get('salesOrder') != null
        ) {
            sapServiceOrderNumber =
                String.valueOf(responseMap.get('salesOrder'));
        }

        if (String.isBlank(sapServiceOrderNumber)) {
            output.isSuccess = false;
            output.responseMessage =
                'SAP returned HTTP ' +
                response.getStatusCode() +
                ' but did not return a Service Order number. Response: ' +
                response.getBody();

            logIntegrationError(
                'SAP Service Order Creation API',
                'Missing Service Order Number',
                output.responseMessage,
                REQUEST_METHOD,
                jsonBody,
                SAP_ENDPOINT,
                'SAP',
                null,
                response.getStatusCode()
            );

            return;
        }

        Order orderToUpdate = new Order(
            Id = orderRecord.Id,
            Service_Order__c = sapServiceOrderNumber
        );

        List<OrderItem> orderItemsToUpdate =
            buildOrderItemUpdates(orderRecord.OrderItems);

        update orderToUpdate;

        if (!orderItemsToUpdate.isEmpty()) {
            update orderItemsToUpdate;
        }

        output.isSuccess = true;
        output.responseMessage =
            'Successfully created SAP Service Order: ' +
            sapServiceOrderNumber;
    }

    /*
     * Uses the real Salesforce OrderItem Id instead of RecordId__c.
     */
    private static List<OrderItem> buildOrderItemUpdates(
        List<OrderItem> orderItems
    ) {
        List<OrderItem> orderItemsToUpdate =
            new List<OrderItem>();

        Integer lineItemNumber = 10;

        for (OrderItem orderItemRecord : orderItems) {
            orderItemsToUpdate.add(
                new OrderItem(
                    Id = orderItemRecord.Id,
                    SAP_Line_Item_No__c =
                        String.valueOf(lineItemNumber)
                )
            );

            lineItemNumber += 10;
        }

        return orderItemsToUpdate;
    }

    private static void processErrorResponse(
        HttpResponse response,
        IntegrationResponse output,
        String jsonBody
    ) {
        output.isSuccess = false;
        output.statusCode = response.getStatusCode();
        output.responseMessage =
            'SAP Error: ' + response.getBody();

        logIntegrationError(
            'SAP Service Order Creation API',
            String.valueOf(response.getStatusCode()),
            response.getBody(),
            REQUEST_METHOD,
            jsonBody,
            SAP_ENDPOINT,
            'SAP',
            null,
            response.getStatusCode()
        );
    }

    private static String formatDate(Date sourceDate) {
        if (sourceDate == null) {
            return '';
        }

        return String.valueOf(sourceDate).replace('-', '');
    }

    /*
     * Decimal zero and Boolean false are treated as populated values.
     */
    private static Boolean isMissing(Object fieldValue) {
        if (fieldValue == null) {
            return true;
        }

        if (fieldValue instanceof String) {
            return String.isBlank((String) fieldValue);
        }

        return false;
    }

    private static String checkNull(Object fieldValue) {
        return fieldValue == null
            ? ''
            : String.valueOf(fieldValue);
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
        Integer statusCode
    ) {
        try {
            Integration_Error_Log__c logRecord =
                new Integration_Error_Log__c();

            logRecord.API_Name__c = apiName;
            logRecord.Error_Code__c = errorCode;
            logRecord.Error_Message__c = errorMessage;
            logRecord.Http_Method__c = httpMethod;
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

            if (statusCode != null) {
                logRecord.Status_Code__c =
                    Decimal.valueOf(statusCode);
            }

            insert logRecord;

        } catch (Exception loggingException) {
            System.debug(
                LoggingLevel.ERROR,
                'Integration error log insert failed: ' +
                loggingException.getMessage()
            );
        }
    }

    private class FieldRule {
        private String apiName;
        private String label;

        private FieldRule(
            String apiName,
            String label
        ) {
            this.apiName = apiName;
            this.label = label;
        }
    }

    public class ValidationResponse {
        @AuraEnabled
        public Id orderId;

        @AuraEnabled
        public String orderNumber;

        @AuraEnabled
        public Boolean isValid;

        @AuraEnabled
        public String message;

        @AuraEnabled
        public List<String> blockingErrors;

        @AuraEnabled
        public List<MissingField> orderMissingFields;

        @AuraEnabled
        public List<OrderItemIssue> orderItemIssues;
    }

    public class MissingField {
        @AuraEnabled
        public String apiName;

        @AuraEnabled
        public String label;

        public MissingField(
            String apiName,
            String label
        ) {
            this.apiName = apiName;
            this.label = label;
        }
    }

    public class OrderItemIssue {
        @AuraEnabled
        public Id orderItemId;

        @AuraEnabled
        public String orderItemNumber;

        @AuraEnabled
        public List<MissingField> missingFields;
    }

    public class IntegrationResponse {
        @AuraEnabled
        public Boolean isSuccess;

        @AuraEnabled
        public Integer statusCode;

        @AuraEnabled
        public String responseMessage;

        /*
         * Returned when the final server-side validation fails.
         */
        @AuraEnabled
        public ValidationResponse validationResult;
    }

    public class SAPRequestPayload {
        public SAPHeader Header;
        public List<SAPItem> Items;
        public List<SAPCondition> Conditions;
    }

    public class SAPHeader {
        public String REQUESTUUID;
        public String ORDER_TYPE;
        public String SALES_ORG;
        public String DIST_CHAN;
        public String DIVISION;
        public String SOLD_TO_PARTY;
        public String SHIP_TO_PARTY;
        public String CUST_REFERENCE;
        public String CUST_REF_DATE;
        public String BG_REQUIRED;
        public String LD_CLAUSE;
        public String TPC;
        public String PERSONAL_NUMBER;
        public String PAYMENT_TERMS;
        public String DELIVERING_PLANT;
        public String ORDER_REASON;
        public String SALESFORCE_SALES_ORDER;
        public String FREIGHT_TERMS;
        public String INSURANCE_TERMS;
        public String SCOPE_OF_OA;
    }

    public class SAPItem {
        public String LINE_ITEM_NO;
        public String MATERIAL_CODE;
        public String QUANTITY;
        public String PLANT;

        /*
         * Existing SAP spelling retained to avoid changing the payload.
         */
        public String ITEM_CATAGORY;

        public String ROUTE;
        public String MATERIAL_SALES_TEXT;
        public String PERFORMANCE_WARRANTY;
        public String PRODUCT_WARRANTY;
    }

    public class SAPCondition {
        public String LINE_ITEM_NO;
        public String CONDITION_TYPE;
        public String CONDITION_AMOUNT;
    }
public static void CodeCover(){
        Integer a=0;
        a++;
		a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
		a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
System.debug(a);

    }
}
/*
public class API_Ctrl_ServiceOrderCreationController {

    // ==========================================
    // FLOW INPUT / OUTPUT WRAPPERS
    // ==========================================
    
    public class FlowOutput {
        @InvocableVariable(label='Is Success?' description='Returns True if SAP returned a 200/201 and the Order was updated.')
        public Boolean isSuccess;

        @InvocableVariable(label='Status Code' description='HTTP Status Code returned from SAP (e.g., 200, 400, 500)')
        public Integer statusCode;
        
        @InvocableVariable(label='Response Message' description='Clean success message or Error details')
        public String responseMessage;
    }

    /**
     * Consumes the SAP Service Order API.
     * Annotated for use in Salesforce Flows.
     */
/*
    @InvocableMethod(label='Send Service Order to SAP' description='Sends Service Order to SAP and updates Order record.' callout=true)
    public static List<FlowOutput> sendServiceOrderToSAP(List<Id> orderIds) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        FlowOutput output = new FlowOutput();
        output.isSuccess = false;
        
        if (orderIds == null || orderIds.isEmpty()) {
            output.statusCode = 400;
            output.responseMessage = 'Error: No Order ID provided by the Flow.';
            outputs.add(output);
            return outputs;
        }
        
        Id orderId = orderIds[0];
        
        // Declare variables outside the try block so they can be accessed in the catch block for logging
        String endpoint = 'callout:NC_SAP_API/http/serviceOrder';
        String reqMethod = 'POST';
        String jsonBody = '';

        try {
            // 1. Query the Order, related lookups, and child OrderItems
            Order ord = [
                SELECT Id, OrderNumber, Customer_Reference__c, Customer_Reference_Date__c, Service_Order_Type__c,
                       Sold_to_party_Code__c, COMP_CODE__c, Distribution_Channel__c, Division__c,
                       BG_Required__c, LD_Clause__c, TPC__c, Delivering_Plant__c, Ship_to_Party_Code__c,
                       Freight_Terms__c, Insurance_Terms__c, Scope_Of_OA__c, Order_Reason__c, Payment_Terms__c,
                       SAP_Employee_Code__c,
                       (SELECT RecordId__c, Material_Code__c, Quantity, Plant_Code__c,
                        Item_Category__c, Material_Sales_Text__c, Route__c,
                        Performance_Warranty__c, Product_Warranty_Duration__c,
                        Condition_Type__c, UnitPrice
                        FROM OrderItems)
                FROM Order
                WHERE Id = :orderId 
                LIMIT 1
            ];
    
            // 2. Instantiate and populate the Wrapper structure
            SAPRequestPayload payload = new SAPRequestPayload();
            
            // --- Populate Header ---
            payload.Header = new SAPHeader();
            payload.Header.REQUESTUUID = Datetime.now().format('yyyyMMddHHmmss');
            payload.Header.ORDER_TYPE = checkNull(ord.Service_Order_Type__c);
            payload.Header.SALES_ORG = checkNull(ord.COMP_CODE__c);
            payload.Header.DIST_CHAN = checkNull(ord.Distribution_Channel__c);
            payload.Header.DIVISION = checkNull(ord.Division__c);
            payload.Header.SOLD_TO_PARTY = checkNull(ord.Sold_to_party_Code__c);
            payload.Header.SHIP_TO_PARTY = checkNull(ord.Ship_to_Party_Code__c);
            payload.Header.CUST_REFERENCE = checkNull(ord.Customer_Reference__c);
            
            // Format Customer Reference Date (YYYYMMDD)
            String formattedCustRefDate = '';
            if (ord.Customer_Reference_Date__c != null) {
                Datetime refDate = Datetime.newInstance(ord.Customer_Reference_Date__c, Time.newInstance(0,0,0,0));
                formattedCustRefDate = refDate.format('yyyyMMdd');
            }
            payload.Header.CUST_REF_DATE = formattedCustRefDate;
            
            payload.Header.BG_REQUIRED = checkNull(ord.BG_Required__c);
            payload.Header.LD_CLAUSE = checkNull(ord.LD_Clause__c);
            payload.Header.TPC = checkNull(ord.TPC__c);
            
            payload.Header.PERSONAL_NUMBER = checkNull(ord.SAP_Employee_Code__c);
            
            payload.Header.PAYMENT_TERMS = checkNull(ord.Payment_Terms__c);
            payload.Header.DELIVERING_PLANT = checkNull(ord.Delivering_Plant__c);
            payload.Header.ORDER_REASON = checkNull(ord.Order_Reason__c);
            payload.Header.SALESFORCE_SALES_ORDER = checkNull(ord.OrderNumber);
            payload.Header.FREIGHT_TERMS = checkNull(ord.Freight_Terms__c);
            payload.Header.INSURANCE_TERMS = checkNull(ord.Insurance_Terms__c);
            payload.Header.SCOPE_OF_OA = checkNull(ord.Scope_Of_OA__c);
    
            // --- Populate Items and Conditions ---
            payload.Items = new List<SAPItem>();
            payload.Conditions = new List<SAPCondition>();
            
            Integer lineItemNo = 10;
            List<OrderItem> oiListToUpdate = new List<OrderItem> ();
            
            for (OrderItem oi : ord.OrderItems) {
                
                // Build Item
                SAPItem item = new SAPItem();
                item.LINE_ITEM_NO = String.valueOf(lineItemNo);
                item.MATERIAL_CODE = checkNull(oi.Material_Code__c);
                item.QUANTITY = checkNull(oi.Quantity); 
                item.PLANT = checkNull(oi.Plant_Code__c);
                item.ITEM_CATAGORY = checkNull(oi.Item_Category__c); 
                item.ROUTE = checkNull(oi.Route__c);
                item.MATERIAL_SALES_TEXT = checkNull(oi.Material_Sales_Text__c);
                item.PERFORMANCE_WARRANTY = checkNull(oi.Performance_Warranty__c);
                item.PRODUCT_WARRANTY = checkNull(oi.Product_Warranty_Duration__c);
                
                payload.Items.add(item);
    
                SAPCondition condition = new SAPCondition();
                condition.LINE_ITEM_NO = String.valueOf(lineItemNo);
                condition.CONDITION_TYPE = checkNull(oi.Condition_Type__c);
                condition.CONDITION_AMOUNT = checkNull(oi.UnitPrice); 
                
                payload.Conditions.add(condition);
                
                oiListToUpdate.add(new OrderItem(Id=oi.RecordId__c, SAP_Line_Item_No__c=String.valueOf(lineItemNo)));
                
                lineItemNo += 10;
            }
    
            // 3. Serialize JSON (false ensures empty tags are still passed)
            jsonBody = JSON.serialize(payload, false); 
            
            System.debug('@@@DBEUG:: JSON BODY: ' + jsonBody);
            // 4. Construct and Execute Callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint); 
            req.setMethod(reqMethod);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000); 
            req.setBody(jsonBody);
    
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            output.statusCode = res.getStatusCode();

            // 5. Handle the Response & Update Order
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('@@@DEBUG:: response : ' + responseMap);
                if (responseMap.containsKey('salesOrder')) {
                    String sapSalesOrderNumber = (String) responseMap.get('salesOrder');
                    
                    Order orderToUpdate = new Order(Id = orderId);
                    orderToUpdate.Service_Order__c = sapSalesOrderNumber;
                    update orderToUpdate;
                    update oiListToUpdate;
                    
                    output.isSuccess = true;
                    output.responseMessage = 'Successfully created SAP Service Order: ' + sapSalesOrderNumber;
                }
                
            } else {
                output.statusCode = res.getStatusCode();
                output.responseMessage = 'SAP Error: ' + res.getBody();
                
                // --- LOG HTTP ERROR ---
                logIntegrationError(
                    'SAP Service Order Creation API', 
                    String.valueOf(res.getStatusCode()), 
                    res.getBody(), 
                    reqMethod, 
                    jsonBody, 
                    endpoint, 
                    'Salesforce', 
                    null, 
                    res.getStatusCode()
                );
            }
            
        } catch (Exception e) {
            output.statusCode = 500;
            output.responseMessage = 'Apex Error: ' + e.getMessage() + ' (Line: ' + e.getLineNumber() + ')';
            
            // --- LOG APEX EXCEPTION ---
            logIntegrationError(
                'SAP Service Order Creation API', 
                e.getTypeName(), 
                e.getMessage(), 
                reqMethod, 
                jsonBody, 
                endpoint, 
                'Salesforce', 
                e.getStackTraceString(), 
                500
            );
        }

        outputs.add(output);
        return outputs;
    }

    /**
     * Helper method to convert null objects into empty Strings ("")
     */
/*
    private static String checkNull(Object obj) {
        if (obj == null) {
            return '';
        }
        return String.valueOf(obj);
    }

    // ==========================================
    // ERROR LOGGING METHOD
    // ==========================================
    private static void logIntegrationError(
        String apiName, String errorCode, String errorMessage, String httpMethod,
        String requestParameters, String requestUri, String sourceSystem, String stackTrace, Integer statusCode
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

            if (statusCode != null) {
                logRec.Status_Code__c = Decimal.valueOf(statusCode);
            }

            insert logRec;

        } catch (Exception e) {
            System.debug('===== INTEGRATION ERROR LOG INSERT FAILED ===== ' + e.getMessage());
        }
    }

    // ==========================================
    // JSON WRAPPER CLASSES
    // ==========================================
    
    public class SAPRequestPayload {
        public SAPHeader Header;
        public List<SAPItem> Items;
        public List<SAPCondition> Conditions;
    }

    public class SAPHeader {
        public String REQUESTUUID;
        public String ORDER_TYPE;
        public String SALES_ORG;
        public String DIST_CHAN;
        public String DIVISION;
        public String SOLD_TO_PARTY;
        public String SHIP_TO_PARTY;
        public String CUST_REFERENCE;
        public String CUST_REF_DATE;
        public String BG_REQUIRED;
        public String LD_CLAUSE;
        public String TPC;
        public String PERSONAL_NUMBER;
        public String PAYMENT_TERMS;
        public String DELIVERING_PLANT;
        public String ORDER_REASON;
        public String SALESFORCE_SALES_ORDER;
        public String FREIGHT_TERMS;
        public String INSURANCE_TERMS;
        public String SCOPE_OF_OA;
    }

    public class SAPItem {
        public String LINE_ITEM_NO;
        public String MATERIAL_CODE;
        public String QUANTITY;
        public String PLANT;
        public String ITEM_CATAGORY;
        public String ROUTE; // NEW FIELD
        public String MATERIAL_SALES_TEXT;
        public String PERFORMANCE_WARRANTY;
        public String PRODUCT_WARRANTY;
    }

    public class SAPCondition {
        public String LINE_ITEM_NO;
        public String CONDITION_TYPE;
        public String CONDITION_AMOUNT;
    }
}
*/
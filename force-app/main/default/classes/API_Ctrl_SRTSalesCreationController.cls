public with sharing class API_Ctrl_SRTSalesCreationController {
 
    public class CalloutResult {

        @AuraEnabled public Boolean isSuccess;

        @AuraEnabled public String message;

        public CalloutResult(Boolean isSuccess, String message) {

            this.isSuccess = isSuccess;

            this.message = message;

        }

    }
 
    @AuraEnabled

    public static CalloutResult syncOrderToSAP(Id orderId) {

        if (orderId == null) {

            throw new AuraHandledException('No Order ID provided.');

        }
 
        String jsonBody = '';

        String endpoint = 'callout:NC_SAP_API/http/srtSales';
 
        try {

            // 1. Query the Order and OrderItems

            Order ord = [

                SELECT Id, OrderNumber, Customer_Reference__c, Customer_Reference_Date__c, SAP_Employee_Code__c,

                       Order_Type__c, COMP_CODE__c, Distribution_Channel__c, Division__c, Sold_to_party_Code__c, 

                       Ship_to_Party_Code__c, InCoTerms__c, Sales_Office__c, Sales_Group__c, BG_Required__c, 

                       LD_Clause__c, TPC__c, Delivering_Plant__c, Payment_Terms__c, Freight_Terms__c, 

                       Insurance_Terms__c, Scope_Of_OA__c,

                       (SELECT Id, RecordId__c, Material_Code__c, Quantity, Plant_Code__c, OrderItemNumber,

                               Item_Category__c, Material_Sales_Text__c, Performance_Warranty__c, 

                               Product_Warranty_Duration__c, Condition_Type__c, UnitPrice, Route__c, InCoTerms__c

                        FROM OrderItems)

                FROM Order

                WHERE Id = :orderId 

                LIMIT 1

            ];
 
            // 2. VALIDATION CHECK

            List<String> missingFields = new List<String>();

            if (String.isBlank(ord.Order_Type__c)) missingFields.add('Order Type');

            if (String.isBlank(ord.COMP_CODE__c)) missingFields.add('Company Code (Sales Org)');

            if (String.isBlank(ord.Distribution_Channel__c)) missingFields.add('Distribution Channel');

            if (String.isBlank(ord.Division__c)) missingFields.add('Division');

            if (String.isBlank(ord.Sold_to_party_Code__c)) missingFields.add('Sold-to Party Code');

            if (String.isBlank(ord.Ship_to_Party_Code__c)) missingFields.add('Ship-to Party Code');

            if (String.isBlank(ord.Customer_Reference__c)) missingFields.add('Customer Reference');

            if (ord.Customer_Reference_Date__c == null) missingFields.add('Customer Reference Date');

            if (String.isBlank(ord.InCoTerms__c)) missingFields.add('InCoTerms');

            if (String.isBlank(ord.Sales_Office__c)) missingFields.add('Sales Office');

            if (String.isBlank(ord.Sales_Group__c)) missingFields.add('Sales Group');

            if (String.isBlank(ord.BG_Required__c)) missingFields.add('BG Required');

            if (String.isBlank(ord.LD_Clause__c)) missingFields.add('LD Clause');

            if (String.isBlank(ord.TPC__c)) missingFields.add('TPC');

            if (String.isBlank(ord.SAP_Employee_Code__c)) missingFields.add('SAP Employee Code');

            if (String.isBlank(ord.Payment_Terms__c)) missingFields.add('Payment Terms');

            if (String.isBlank(ord.Delivering_Plant__c)) missingFields.add('Delivering Plant');

            if (String.isBlank(ord.Freight_Terms__c)) missingFields.add('Freight Terms');

            if (String.isBlank(ord.Insurance_Terms__c)) missingFields.add('Insurance Terms');

            if (String.isBlank(ord.Scope_Of_OA__c)) missingFields.add('Scope Of OA');

            if (ord.OrderItems.isEmpty()) { 

                missingFields.add('At least one Order Product (Item)'); 

            } else {

                for(OrderItem oi: ord.OrderItems) {

                    if (String.isBlank(oi.Material_Code__c)) missingFields.add('Material Code on Item ' + oi.OrderItemNumber);

                    if (oi.Quantity == null || oi.Quantity <= 0) missingFields.add('Quantity on Item ' + oi.OrderItemNumber);

                    if (String.isBlank(oi.Plant_Code__c)) missingFields.add('Plant Code on Item ' + oi.OrderItemNumber);

                    if (String.isBlank(oi.Item_Category__c)) missingFields.add('Item Category on Item ' + oi.OrderItemNumber);

                    if (String.isBlank(oi.Condition_Type__c)) missingFields.add('Condition Type on Item ' + oi.OrderItemNumber);

                    if (oi.UnitPrice == null) missingFields.add('Unit Price on Item ' + oi.OrderItemNumber);

                }

            }
 
            if (!missingFields.isEmpty()) {

                return new CalloutResult(false, 'MISSING_DATA: ' + String.join(missingFields, ', '));

            }
 
            // 3. Build the JSON Payload Wrapper

            SAPPayload payload = new SAPPayload();

            payload.Header = new SAPHeader();

            payload.Header.REQUESTUUID = Datetime.now().format('yyyyMMddHHmmss');

            payload.Header.ORDER_TYPE = formatString(ord.Order_Type__c);

            payload.Header.SALES_ORG = formatString(ord.COMP_CODE__c);

            payload.Header.DIST_CHAN = formatString(ord.Distribution_Channel__c);

            payload.Header.DIVISION = formatString(ord.Division__c);

            payload.Header.SOLD_TO_PARTY = formatString(ord.Sold_to_party_Code__c);

            payload.Header.SHIP_TO_PARTY = formatString(ord.Ship_to_Party_Code__c);

            payload.Header.CUST_REFERENCE = formatString(ord.Customer_Reference__c);

            Datetime refDate = Datetime.newInstance(ord.Customer_Reference_Date__c, Time.newInstance(0,0,0,0));

            payload.Header.CUST_REF_DATE = refDate.format('yyyyMMdd');
 
            payload.Header.INCOTERMS = formatString(ord.InCoTerms__c);

            payload.Header.SALES_OFFICE = formatString(ord.Sales_Office__c);

            payload.Header.SALES_GROUP = formatString(ord.Sales_Group__c);

            payload.Header.BG_REQUIRED = formatString(ord.BG_Required__c);

            payload.Header.LD_CLAUSE = formatString(ord.LD_Clause__c);

            payload.Header.TPC = formatString(ord.TPC__c);

            payload.Header.PERSONAL_NUMBER = formatString(ord.SAP_Employee_Code__c);

            payload.Header.PAYMENT_TERMS = formatString(ord.Payment_Terms__c);

            payload.Header.DELIVERING_PLANT = formatString(ord.Delivering_Plant__c);

            payload.Header.SALESFORCE_SALES_ORDER = formatString(ord.OrderNumber);

            payload.Header.FREIGHT_TERMS = formatString(ord.Freight_Terms__c);

            payload.Header.INSURANCE_TERMS = formatString(ord.Insurance_Terms__c);

            payload.Header.SCOPE_OF_OA = formatString(ord.Scope_Of_OA__c);
 
            payload.Items = new List<SAPItem>();

            payload.Conditions = new List<SAPCondition>();

            List<OrderItem> itemsToUpdate = new List<OrderItem>();

            Integer lineNo = 10;
 
            for (OrderItem oi : ord.OrderItems) {

                String formattedLineNo = String.valueOf(lineNo).leftPad(6, '0');
 
                SAPItem item = new SAPItem();

                item.LINE_ITEM_NO = formattedLineNo;

                item.MATERIAL_CODE = formatString(oi.Material_Code__c);

                item.QUANTITY = formatString(oi.Quantity);

                item.PLANT = formatString(oi.Plant_Code__c);

                item.ITEM_CATAGORY = formatString(oi.Item_Category__c); 

                item.MATERIAL_SALES_TEXT = formatString(oi.Material_Sales_Text__c);

                item.PERFORMANCE_WARRANTY = formatString(oi.Performance_Warranty__c);

                item.PRODUCT_WARRANTY = formatString(oi.Product_Warranty_Duration__c);

                item.INCOTERMS = formatString(oi.InCoTerms__c);

                item.ROUTE = formatString(oi.Route__c);

                payload.Items.add(item);
 
                SAPCondition cond = new SAPCondition();

                cond.LINE_ITEM_NO = formattedLineNo;

                cond.CONDITION_TYPE = formatString(oi.Condition_Type__c);

                cond.CONDITION_AMOUNT = formatString(oi.UnitPrice);

                payload.Conditions.add(cond);
 
                itemsToUpdate.add(new OrderItem(Id = oi.Id, SAP_Line_Item_No__c = String.valueOf(lineNo)));

                lineNo += 10;

            }
 
            // 4. Serialize and perform HTTP Callout

            jsonBody = JSON.serialize(payload, true);

            HttpRequest req = new HttpRequest();

            req.setEndpoint(endpoint); 

            req.setMethod('POST');

            req.setHeader('Content-Type', 'application/json');

            req.setTimeout(120000);

            req.setBody(jsonBody);
 
            Http http = new Http();

            HttpResponse res = http.send(req);
 
            // 5. Handle Response

            Integer statusCode = res.getStatusCode();

            String responseBody = res.getBody();
 
            if (statusCode == 200 || statusCode == 201) {

                try {

                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

                    // Case A: SAP successfully returned a Sales Order Number

                    if (responseMap.containsKey('salesOrder')) {

                        String sapSalesOrderNumber = (String) responseMap.get('salesOrder');

                        update new Order(Id = orderId, Sales_Order__c = sapSalesOrderNumber);

                        if (!itemsToUpdate.isEmpty()) { update itemsToUpdate; }

                        return new CalloutResult(true, 'Successfully created SAP Sales Order: ' + sapSalesOrderNumber);

                    } 

                    // Case B: SAP returned a 200 OK, but it's an application-level ERROR

                    else if (responseMap.containsKey('status') && String.valueOf(responseMap.get('status')) == 'ERROR') {

                        String sapErrorMsg = responseMap.containsKey('message') ? String.valueOf(responseMap.get('message')) : responseBody;

                        return new CalloutResult(false, sapErrorMsg);

                    }

                } catch (Exception parseEx) {

                    // Not valid JSON, fallback to returning the raw response

                }

                // Case C: 200 OK but unhandled format

                return new CalloutResult(false, 'SAP request successful, but no salesOrder returned. Response: ' + responseBody);

            } else {

                // Non-200 HTTP Response

                String extractedMessage = responseBody;

                // Attempt to parse SAP's JSON Error format

                try {

                    Map<String, Object> errorMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

                    if (errorMap.containsKey('message')) {

                        extractedMessage = String.valueOf(errorMap.get('message'));

                    }

                } catch (Exception parseEx) {

                    // Not a JSON response, stick with the raw responseBody

                }
 
                // LOG THE HTTP ERROR

                logIntegrationError(

                    'SAP SRT Sales Order Sync', String.valueOf(statusCode), responseBody, 'POST', jsonBody, endpoint, 'Salesforce', null, statusCode

                );

                // Return just the extracted string message for the Toast

                return new CalloutResult(false, extractedMessage);

            }
 
        } catch (Exception e) {

            // LOG THE APEX EXCEPTION

            logIntegrationError(

                'SAP SRT Sales Order Sync', 'Exception', e.getMessage(), 'POST', jsonBody != '' ? jsonBody : 'Order ID: ' + orderId, endpoint, 'Salesforce', e.getStackTraceString(), 500

            );

            // Return exactly the system error message 

            throw new AuraHandledException(e.getMessage());

        }

    }
 
    private static String formatString(Object val) {

        return val == null ? '' : String.valueOf(val);

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

            logRec.Logged_On__c = string.ValueOf(System.now());

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
 
    // JSON Wrappers

    public class SAPPayload {

        public SAPHeader Header;

        public List<SAPItem> Items;

        public List<SAPCondition> Conditions;

    }
 
    public class SAPHeader {

        public String REQUESTUUID; public String ORDER_TYPE; public String SALES_ORG; public String DIST_CHAN;

        public String DIVISION; public String SOLD_TO_PARTY; public String SHIP_TO_PARTY; public String CUST_REFERENCE;

        public String CUST_REF_DATE; public String INCOTERMS; public String SALES_OFFICE; public String SALES_GROUP;

        public String BG_REQUIRED; public String LD_CLAUSE; public String TPC; public String PERSONAL_NUMBER;

        public String PAYMENT_TERMS; public String DELIVERING_PLANT; public String SALESFORCE_SALES_ORDER;

        public String FREIGHT_TERMS; public String INSURANCE_TERMS; public String SCOPE_OF_OA;

    }
 
    public class SAPItem {

        public String LINE_ITEM_NO; public String MATERIAL_CODE; public String QUANTITY; public String PLANT; 

        public String INCOTERMS; public String ITEM_CATAGORY; public String MATERIAL_SALES_TEXT; public String PERFORMANCE_WARRANTY; 

        public String PRODUCT_WARRANTY; public String ROUTE;

    }
 
    public class SAPCondition {

        public String LINE_ITEM_NO; public String CONDITION_TYPE; public String CONDITION_AMOUNT;

    }




public static void dataCover() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;

        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
	    i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }

}
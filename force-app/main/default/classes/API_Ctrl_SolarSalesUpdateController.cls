public with sharing class API_Ctrl_SolarSalesUpdateController {
    
    // Wrapper to send a clean response back to the LWC
    public class LWCResponse {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static LWCResponse updateOrderInSAP(Id orderId) {
        LWCResponse response = new LWCResponse();
        response.isSuccess = false;

        try {
            // 1. Query the Order and child OrderItems
            Order ord = [
                SELECT Id, OrderNumber, Sales_Order__c, Customer_Reference__c, Customer_Reference_Date__c, 
                       SAP_Employee_Code__c, COMP_CODE__c, Distribution_Channel__c, Division__c, 
                       Sold_to_party_Code__c, Ship_to_Party_Code__c, BG_Required__c, LD_Clause__c, 
                       TPC__c, Delivering_Plant__c, Payment_Terms__c,
                       (SELECT RecordId__c, Material_Code__c, Quantity, Plant_Code__c,
                               Item_Category__c, Material_Sales_Text__c,
                               Performance_Warranty__c, Product_Warranty_Duration__c,
                               Condition_Type__c, UnitPrice
                        FROM OrderItems)
                FROM Order 
                WHERE Id = :orderId 
                LIMIT 1
            ];

            // Ensure the Salesforce Order already has an SAP Sales Order number to update
            if (String.isBlank(ord.Sales_Order__c)) {
                response.message = 'Error: No SAP Sales Order number (Sales_Order__c) found on this record.';
                return response;
            }

            // 2. Instantiate and populate the Wrapper structure
            SAPUpdatePayload payload = new SAPUpdatePayload();
            
            // --- Populate Header ---  
            payload.Header = new SAPUpdateHeader();
            payload.Header.SALESDOCUMENT = checkNull(ord.Sales_Order__c);
            payload.Header.SALES_ORG = checkNull(ord.COMP_CODE__c);
            payload.Header.DIST_CHAN = checkNull(ord.Distribution_Channel__c);
            payload.Header.DIVISION = checkNull(ord.Division__c);
            payload.Header.SOLD_TO_PARTY = checkNull(ord.Sold_to_party_Code__c);
            payload.Header.SHIP_TO_PARTY = checkNull(ord.Ship_to_Party_Code__c);
            payload.Header.CUST_REFERENCE = checkNull(ord.Customer_Reference__c);
            
            String formattedCustRefDate = '';
            if (ord.Customer_Reference_Date__c != null) {
                Datetime refDate = Datetime.newInstance(ord.Customer_Reference_Date__c, Time.newInstance(0,0,0,0));
                formattedCustRefDate = refDate.format('yyyyMMdd');
            }
            payload.Header.CUST_REF_DATE = formattedCustRefDate;
            
            // Fields missing from original mapping mapped as "" per requirements
            payload.Header.INCOTERMS = '';
            payload.Header.SALES_OFFICE = '';
            payload.Header.SALES_GROUP = '';
            
            payload.Header.BG_REQUIRED = checkNull(ord.BG_Required__c);
            payload.Header.LD_CLAUSE = checkNull(ord.LD_Clause__c);
            payload.Header.TPC = checkNull(ord.TPC__c);
            payload.Header.PERSONAL_NUMBER = checkNull(ord.SAP_Employee_Code__c);
            payload.Header.PAYMENT_TERMS = checkNull(ord.Payment_Terms__c);
            payload.Header.DELIVERING_PLANT = checkNull(ord.Delivering_Plant__c);
            payload.Header.SALESFORCE_SALES_ORDER = checkNull(ord.OrderNumber);

            // --- Populate Items and Conditions ---
            payload.Items = new List<SAPUpdateItem>();
            payload.Conditions = new List<SAPUpdateCondition>();
            
            Integer lineItemNo = 10;
            for (OrderItem oi : ord.OrderItems) {
                
                // Formats integer to string with leading zeros e.g. "000010" as seen in your JSON
                String formattedLineItem = String.valueOf(lineItemNo).leftPad(6, '0');
                
                // Build Item
                SAPUpdateItem item = new SAPUpdateItem();
                item.LINE_ITEM_NO = formattedLineItem;
                item.QUANTITY = checkNull(oi.Quantity);
                item.PLANT = checkNull(oi.Plant_Code__c);
                item.MATERIAL_CODE = checkNull(oi.Material_Code__c);
                item.ITEM_CATAGORY = checkNull(oi.Item_Category__c); 
                item.MATERIAL_SALES_TEXT = checkNull(oi.Material_Sales_Text__c);
                item.PERFORMANCE_WARRANTY = checkNull(oi.Performance_Warranty__c);
                item.PRODUCT_WARRANTY = checkNull(oi.Product_Warranty_Duration__c);
                payload.Items.add(item);

                // Build Condition
                SAPUpdateCondition condition = new SAPUpdateCondition();
                condition.LINE_ITEM_NO = formattedLineItem;
                condition.CONDITION_TYPE = checkNull(oi.Condition_Type__c);
                condition.CONDITION_AMOUNT = checkNull(oi.UnitPrice); 
                payload.Conditions.add(condition);
                
                lineItemNo += 10;
            }

            // 3. Serialize JSON 
            String jsonBody = JSON.serialize(payload, false); 
            
            // 4. Construct and Execute Callout using Named Credential
            HttpRequest req = new HttpRequest();
            // Assuming use of your existing Named Credential setup for security
            req.setEndpoint('callout:NC_SAP_API/http/salesOrderUpdate'); 
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000); // 2 minute timeout
            req.setBody(jsonBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            // 5. Handle the Response
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (responseMap.containsKey('MESSAGE')) {
                    response.isSuccess = true;
                    response.message = (String) responseMap.get('MESSAGE');
                } else {
                    response.isSuccess = true;
                    response.message = 'Successfully Updated in SAP (No specific message returned)';
                }
            } else {
                response.message = 'SAP Error (' + res.getStatusCode() + '): ' + res.getBody();
            }
            
        } catch (Exception e) {
            response.message = 'Apex Error: ' + e.getMessage() + ' (Line: ' + e.getLineNumber() + ')';
        }

        return response;
    }

    /**
     * Helper method to convert null objects into empty Strings ("")
     */
    private static String checkNull(Object obj) {
        if (obj == null) {
            return '';
        }
        return String.valueOf(obj);
    }

    // ==========================================
    // JSON WRAPPER CLASSES
    // ==========================================
    
    public class SAPUpdatePayload {
        public SAPUpdateHeader Header;
        public List<SAPUpdateItem> Items;
        public List<SAPUpdateCondition> Conditions;
    }

    public class SAPUpdateHeader {
        public String SALESDOCUMENT;
        public String SALES_ORG;
        public String DIST_CHAN;
        public String DIVISION;
        public String SOLD_TO_PARTY;
        public String SHIP_TO_PARTY;
        public String CUST_REFERENCE;
        public String CUST_REF_DATE;
        public String INCOTERMS;
        public String SALES_OFFICE;
        public String SALES_GROUP;
        public String BG_REQUIRED;
        public String LD_CLAUSE;
        public String TPC;
        public String PERSONAL_NUMBER;
        public String PAYMENT_TERMS;
        public String DELIVERING_PLANT;
        public String SALESFORCE_SALES_ORDER;
    }

    public class SAPUpdateItem {
        public String LINE_ITEM_NO;
        public String QUANTITY;
        public String PLANT;
        public String MATERIAL_CODE;
        public String ITEM_CATAGORY;
        public String MATERIAL_SALES_TEXT;
        public String PERFORMANCE_WARRANTY;
        public String PRODUCT_WARRANTY;
    }

    public class SAPUpdateCondition {
        public String LINE_ITEM_NO;
        public String CONDITION_TYPE;
        public String CONDITION_AMOUNT;
    }
}
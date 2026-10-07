public with sharing class ProductRequestActionController {
    
    // NEW: Inner class to hold Line Item warranty data from LWC
    public class LineItemPayload {
        public Id id;
        public Decimal productWarranty;
        public Decimal performanceWarranty;
    }

    public class OrderPayload {
        public Id recordId;
        public String orderType;
        public String orderReason; 
        public String salesOrg;
        public String distChannel;
        public String division;
        public String poNumber;
        public Date poDate;
        public String bgRequired;
        public String ldClause;
        public String tpc;
        public String paymentTerms;
        public String deliveryPlant;
        public String freightTerms;
        public String insuranceTerms;
        public String scopeOfOA;
        // NEW: List of line items from LWC
        public List<LineItemPayload> lineItems; 
    }

    @AuraEnabled(cacheable=true)
    public static ProductRequest getRequestDetails(Id recordId) {
        return [
            SELECT Id, ProductRequestNumber, Status, ShipmentType, NeedByDate, Product_Request_Type__c,
                   Total_Amount__c, Final_Amount_to_be_paid__c,
                   WorkOrder.AccountId, WorkOrder.Account.Name, WorkOrder.Account.Sales_Org__c, 
                   WorkOrder.Account.Distribution_Channel__c, WorkOrder.Account.Division__c, WorkOrder.Account.Payment_Terms__c,
                   WorkOrder.ContactId, WorkOrder.Contact.Name,
                   Ship_To_Party__c, Ship_To_Party__r.Name, Ship_To_Party__r.SAP_Account_Number__c,
                   ShipToStreet, ShipToCity, ShipToState, ShipToPostalCode, ShipToCountry,
                   (
                       SELECT Id, ProductRequestLineItemNumber, ParentId, Product2Id,
                              Material_Code__c, Material_Description__c,
                              Material_Master__c,
                              Material_Master__r.Plant__c,
                              QuantityRequested, QuantityUnitOfMeasure,
                              NeedByDate, Price__c
                       FROM ProductRequestLineItems
                   )
            FROM ProductRequest
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static String createOrder(String payloadStr) {
        try {
            OrderPayload payload = (OrderPayload)JSON.deserialize(payloadStr, OrderPayload.class);
            Id reqId = payload.recordId;

            // Build a map of LineItemPayload for easy fetching during OrderItem creation
            Map<Id, LineItemPayload> itemPayloadMap = new Map<Id, LineItemPayload>();
            if (payload.lineItems != null) {
                for (LineItemPayload li : payload.lineItems) {
                    itemPayloadMap.put(li.id, li);
                }
            }

            ProductRequest pr = [
                SELECT Id, ProductRequestNumber, Product_Request_Type__c,
                       WorkOrder.AccountId, WorkOrder.ContactId, Ship_To_Party__c,
                       ShipToStreet, ShipToCity, ShipToState, ShipToPostalCode, ShipToCountry,
                       (SELECT Id, QuantityRequested, Price__c, Product2Id, Material_Master__c FROM ProductRequestLineItems WHERE Product2Id != null)
                FROM ProductRequest
                WHERE Id = :reqId
                LIMIT 1
            ];

            Id pricebookId;
            if(Test.isRunningTest()) {
                pricebookId = Test.getStandardPricebookId();
            } else {
                List<Pricebook2> standardPbs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1];
                if (!standardPbs.isEmpty()) {
                    pricebookId = standardPbs[0].Id;
                } else {
                    List<Pricebook2> activePbs = [SELECT Id FROM Pricebook2 WHERE IsActive = true LIMIT 1];
                    if (!activePbs.isEmpty()) {
                        pricebookId = activePbs[0].Id;
                    }
                }
            }

            Id autoContractId = null;
            if (pr.WorkOrder.AccountId != null) {
                List<Contract> contracts = [SELECT Id FROM Contract WHERE AccountId = :pr.WorkOrder.AccountId AND Status = 'Activated' LIMIT 1];
                if (!contracts.isEmpty()) {
                    autoContractId = contracts[0].Id;
                } else {
                    List<Contract> fallbackContracts = [SELECT Id FROM Contract WHERE AccountId = :pr.WorkOrder.AccountId LIMIT 1];
                    if (!fallbackContracts.isEmpty()) {
                        autoContractId = fallbackContracts[0].Id;
                    }
                }
            }

            Order newOrder = new Order();
            newOrder.Name = pr.ProductRequestNumber;
            newOrder.AccountId = pr.WorkOrder.AccountId;
            newOrder.Contact__c = pr.WorkOrder.ContactId;
            newOrder.ContractId = autoContractId;
            newOrder.Pricebook2Id = pricebookId; 
            newOrder.EffectiveDate = Date.today();
            newOrder.Product_Request__c = pr.Id;
            newOrder.Status = 'Draft'; 
            
            newOrder.Bill_To__c = pr.Ship_To_Party__c;
            newOrder.Ship_To__c = pr.Ship_To_Party__c;
            
            newOrder.Service_Order_Type__c = payload.orderType;
            newOrder.Order_Reason__c = payload.orderReason; 
            newOrder.Customer_Reference__c = payload.poNumber;
            newOrder.Customer_Reference_Date__c = payload.poDate;
            newOrder.BG_Required__c = payload.bgRequired;
            newOrder.LD_Clause__c = payload.ldClause;
            newOrder.TPC__c = payload.tpc;
            newOrder.Delivering_Plant__c = payload.deliveryPlant;
            newOrder.Freight_Terms__c = payload.freightTerms;
            newOrder.Insurance_Terms__c = payload.insuranceTerms;
            newOrder.Scope_Of_OA__c = payload.scopeOfOA;
                        
            newOrder.BillingStreet = pr.ShipToStreet;
            newOrder.BillingCity = pr.ShipToCity;
            newOrder.BillingState = pr.ShipToState;
            newOrder.BillingPostalCode = pr.ShipToPostalCode;
            newOrder.BillingCountry = pr.ShipToCountry;

            newOrder.ShippingStreet = pr.ShipToStreet;
            newOrder.ShippingCity = pr.ShipToCity;
            newOrder.ShippingState = pr.ShipToState;
            newOrder.ShippingPostalCode = pr.ShipToPostalCode;
            newOrder.ShippingCountry = pr.ShipToCountry;

            newOrder.Type__c = 'Service (Service)';

            insert newOrder;
            
            if (pr.ProductRequestLineItems != null && !pr.ProductRequestLineItems.isEmpty() && pricebookId != null) {
                Set<Id> productIds = new Set<Id>();
                for (ProductRequestLineItem prli : pr.ProductRequestLineItems) {
                    productIds.add(prli.Product2Id);
                }
                
                Map<Id, Id> productToPricebookEntryMap = new Map<Id, Id>();
                for (PricebookEntry pbe : [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND Product2Id IN :productIds AND IsActive = true]) {
                    productToPricebookEntryMap.put(pbe.Product2Id, pbe.Id);
                }

                List<OrderItem> orderItemsToInsert = new List<OrderItem>();
                for (ProductRequestLineItem prli : pr.ProductRequestLineItems) {
                    if (productToPricebookEntryMap.containsKey(prli.Product2Id)) {
                        OrderItem item = new OrderItem();
                        item.OrderId = newOrder.Id;
                        item.PricebookEntryId = productToPricebookEntryMap.get(prli.Product2Id); 
                        item.Quantity = prli.QuantityRequested != null ? prli.QuantityRequested : 1;
                        item.UnitPrice = prli.Price__c != null ? prli.Price__c : 0.0;
                        item.Material_Master__c = prli.Material_Master__c;

                        // NEW: Map the user-entered warranty data from the LWC map based on explicit instruction
                        if (itemPayloadMap.containsKey(prli.Id)) {
                            LineItemPayload liPayload = itemPayloadMap.get(prli.Id);
                            // "Product Warrenty (Years)" value to "OrderItem.Performance_Warranty__c"
                            item.Performance_Warranty__c = liPayload.productWarranty;
                            // "Performance Warranty (Years)" value to "OrderItem.Product_Warranty_Duration__c"
                            item.Product_Warranty_Duration__c = liPayload.performanceWarranty;
                        }
                        
                        orderItemsToInsert.add(item);
                    }
                }
                
                if (!orderItemsToInsert.isEmpty()) {
                    insert orderItemsToInsert;
                }
            }
            
            return newOrder.Id;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception in createOrder: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}
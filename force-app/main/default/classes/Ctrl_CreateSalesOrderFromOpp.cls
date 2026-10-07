public with sharing class Ctrl_CreateSalesOrderFromOpp {
    
    public class InitialLoadWrapper {
        @AuraEnabled public Opportunity oppRecord { get; set; }
        @AuraEnabled public List<OpportunityLineItem> oppLineItems { get; set; }
        @AuraEnabled public List<Quote> acceptedQuotes { get; set; }
    }

    public class QuoteLoadWrapper {
        @AuraEnabled public Quote quoteRecord { get; set; }
        @AuraEnabled public List<QuoteLineItem> quoteLineItems { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static InitialLoadWrapper getInitialDetails(Id oppId) {
        InitialLoadWrapper wrapper = new InitialLoadWrapper();
        
        wrapper.acceptedQuotes = [SELECT Id, Name, QuoteNumber FROM Quote WHERE OpportunityId = :oppId AND Status = 'Accepted'];
        
        // ADDED: Account.SAP_Account_Number__c and Account Address Fields
        wrapper.oppRecord = [
            SELECT Id, Name, 
                   AccountId, Account.Name, Account.Customer_Account_Group__c, Account.SAP_Account_Number__c,
                   Account.Distribution_Channel__c, Account.Sales_Org__c, Account.Division__c,
                   Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                   Account.ShippingStreet, Account.ShippingCity, Account.ShippingState, Account.ShippingPostalCode, Account.ShippingCountry,
                   Contact__c, Contact__r.Name, Business_Segment__c
            FROM Opportunity 
            WHERE Id = :oppId LIMIT 1
        ];
        
        wrapper.oppLineItems = [
            SELECT Id, Product2Id, Quantity, UnitPrice,
                   Material_Master__c, Material_Code__c, Plant_Code__c,
                   Product_Warranty__c, Performance_Warranty__c
            FROM OpportunityLineItem WHERE OpportunityId = :oppId
        ];
        
        return wrapper;
    }

    @AuraEnabled
    public static QuoteLoadWrapper getQuoteDetails(Id quoteId) {
        QuoteLoadWrapper wrapper = new QuoteLoadWrapper();
        
        wrapper.quoteRecord = [
            SELECT Id, Name, AccountId, Account.Name, Account.Customer_Account_Group__c, 
                   Account.Distribution_Channel__c, Account.Sales_Org__c, Account.Division__c,
                   OpportunityId, Opportunity.Name, ContactId, Contact.Name, Business_Segment__c, 
                   Bill_To_Party__c, Bill_To_Party__r.Name, Bill_To_Party__r.SAP_Account_Number__c,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   Ship_To_Party__c, Ship_To_Party__r.Name, Ship_To_Party__r.SAP_Account_Number__c,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM Quote WHERE Id = :quoteId LIMIT 1
        ];
        
        wrapper.quoteLineItems = [
            SELECT Id, LineNumber, Material_Master__c, Material_Code__c, Plant_Code__c, 
                   Quantity, Quantity_Remained__c, Quantity_Ordered__c, Product_Warranty__c, Performance_Warranty__c, 
                   Material_Sales_Text__c, UnitPrice
            FROM QuoteLineItem WHERE QuoteId = :quoteId
        ];
        
        return wrapper;
    }

    // ============================================================================
    // EXACT ORIGINAL METHOD FOR QUOTES
    // ============================================================================
    @AuraEnabled
    public static String createOrderFromQuote(Id quoteId, Map<String, Object> formData, Map<Id, Decimal> orderedQuantities) {
        Savepoint sp = Database.setSavepoint();
        try {
            Quote q = [SELECT AccountId, Bill_To_Party__c, BillingCity, BillingCountry, BillingPostalCode, BillingState, BillingStreet,
                              ContactId, OpportunityId, Ship_To_Party__c, ShippingCity, ShippingCountry, ShippingPostalCode, ShippingState, ShippingStreet
                       FROM Quote WHERE Id = :quoteId LIMIT 1];

            Pricebook2 standardPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Standard Price Book' OR IsStandard = true LIMIT 1];
            Product2 stdProduct = [SELECT Id FROM Product2 WHERE Name = 'Standard Product' LIMIT 1];
            PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPb.Id AND Product2Id = :stdProduct.Id LIMIT 1];

            Order newOrder = new Order();
            newOrder.AccountId = q.AccountId;
            newOrder.QuoteId = quoteId;
            newOrder.OpportunityId = q.OpportunityId;
            newOrder.Contact__c = q.ContactId;
            newOrder.Status = 'Draft';
            newOrder.EffectiveDate = Date.today();
            newOrder.Pricebook2Id = standardPb.Id;
            
            newOrder.Bill_To__c = q.Bill_To_Party__c;
            newOrder.Ship_To__c = q.Ship_To_Party__c;
            
            newOrder.BillingStreet = q.BillingStreet;
            newOrder.BillingCity = q.BillingCity;
            newOrder.BillingState = q.BillingState;
            newOrder.BillingPostalCode = q.BillingPostalCode;
            newOrder.BillingCountry = q.BillingCountry;
            
            newOrder.ShippingStreet = q.ShippingStreet;
            newOrder.ShippingCity = q.ShippingCity;
            newOrder.ShippingState = q.ShippingState;
            newOrder.ShippingPostalCode = q.ShippingPostalCode;
            newOrder.ShippingCountry = q.ShippingCountry;

            newOrder.BG_Required__c = (String)formData.get('bgRequired');
            newOrder.TPC__c = (String)formData.get('tpc');
            newOrder.Customer_Reference__c = (String)formData.get('poNo');
            newOrder.Customer_Reference_Date__c = Date.valueOf((String)formData.get('poDate'));
            newOrder.LD_Clause__c = (String)formData.get('ldClause');
            newOrder.Freight_Terms__c = (String)formData.get('freightTerms');
            newOrder.Scope_Of_OA__c = (String)formData.get('scopeOfOA');
            newOrder.Insurance_Terms__c = (String)formData.get('insuranceTerms');
            
            newOrder.Type__c = 'Sales (Sales)';

            insert newOrder;

            List<QuoteLineItem> qlis = [SELECT Id, Material_Master__c, Material_Sales_Text__c, UnitPrice, 
                                               Product_Warranty__c, Performance_Warranty__c, Quantity_Ordered__c 
                                        FROM QuoteLineItem 
                                        WHERE Id IN :orderedQuantities.keySet()];

            List<OrderItem> orderItemsToInsert = new List<OrderItem>();
            List<QuoteLineItem> qlisToUpdate = new List<QuoteLineItem>();

            for(QuoteLineItem qli : qlis) {
                Decimal uiOrderedQty = orderedQuantities.get(qli.Id);
                
                OrderItem oi = new OrderItem();
                oi.OrderId = newOrder.Id;
                oi.QuoteLineItemId = qli.Id;
                oi.PricebookEntryId = pbe.Id;
                oi.Product2Id = stdProduct.Id;
                oi.Quantity = uiOrderedQty;
                oi.UnitPrice = qli.UnitPrice;
                oi.Material_Master__c = qli.Material_Master__c;
                oi.Material_Sales_Text__c = qli.Material_Sales_Text__c;
                oi.Product_Warranty_Duration__c = qli.Product_Warranty__c;
                oi.Performance_Warranty__c = qli.Performance_Warranty__c;
                orderItemsToInsert.add(oi);

                QuoteLineItem updateQli = new QuoteLineItem(Id = qli.Id);
                Decimal existingOrdered = qli.Quantity_Ordered__c != null ? qli.Quantity_Ordered__c : 0;
                updateQli.Quantity_Ordered__c = existingOrdered + uiOrderedQty;
                qlisToUpdate.add(updateQli);
            }
            
            if(!orderItemsToInsert.isEmpty()) {
                insert orderItemsToInsert;
            }
            
            if(!qlisToUpdate.isEmpty()) {
                update qlisToUpdate;
            }

            return newOrder.Id;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Failed to create Order from Quote: ' + e.getMessage());
        }
    }

    // ============================================================================
    // METHOD STRICTLY FOR OPPORTUNITIES
    // ============================================================================
    @AuraEnabled
    public static String createOrderFromOpp(Id oppId, Map<String, Object> formData, Map<Id, Decimal> orderedQuantities) {
        Savepoint sp = Database.setSavepoint();
        try {
            // ADDED: Account Addresses and SAP Account Number mapping query
            Opportunity o = [SELECT AccountId, Contact__c, Account.SAP_Account_Number__c,
                                    Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                                    Account.ShippingStreet, Account.ShippingCity, Account.ShippingState, Account.ShippingPostalCode, Account.ShippingCountry
                             FROM Opportunity WHERE Id = :oppId LIMIT 1];

            Pricebook2 standardPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Standard Price Book' OR IsStandard = true LIMIT 1];
            Product2 stdProduct = [SELECT Id FROM Product2 WHERE Name = 'Standard Product' LIMIT 1];
            PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPb.Id AND Product2Id = :stdProduct.Id LIMIT 1];

            Order newOrder = new Order();
            newOrder.AccountId = o.AccountId;
            newOrder.OpportunityId = oppId;
            newOrder.Contact__c = o.Contact__c;
            newOrder.Status = 'Draft';
            newOrder.EffectiveDate = Date.today();
            newOrder.Pricebook2Id = standardPb.Id;
            
            // --- MAPPING ACCOUNT ID TO BILL TO & SHIP TO ---
            newOrder.Bill_To__c = o.AccountId;
            newOrder.Ship_To__c = o.AccountId;
            
            // --- MAPPING ACCOUNT ADDRESSES TO ORDER ADDRESSES ---
            newOrder.BillingStreet = o.Account.BillingStreet;
            newOrder.BillingCity = o.Account.BillingCity;
            newOrder.BillingState = o.Account.BillingState;
            newOrder.BillingPostalCode = o.Account.BillingPostalCode;
            newOrder.BillingCountry = o.Account.BillingCountry;

            newOrder.ShippingStreet = o.Account.ShippingStreet;
            newOrder.ShippingCity = o.Account.ShippingCity;
            newOrder.ShippingState = o.Account.ShippingState;
            newOrder.ShippingPostalCode = o.Account.ShippingPostalCode;
            newOrder.ShippingCountry = o.Account.ShippingCountry;

            newOrder.BG_Required__c = (String)formData.get('bgRequired');
            newOrder.TPC__c = (String)formData.get('tpc');
            newOrder.Customer_Reference__c = (String)formData.get('poNo');
            newOrder.Customer_Reference_Date__c = Date.valueOf((String)formData.get('poDate'));
            newOrder.LD_Clause__c = (String)formData.get('ldClause');
            newOrder.Freight_Terms__c = (String)formData.get('freightTerms');
            newOrder.Scope_Of_OA__c = (String)formData.get('scopeOfOA');
            newOrder.Insurance_Terms__c = (String)formData.get('insuranceTerms');
            newOrder.Type__c = 'Sales (Sales)';

            insert newOrder;

            List<OpportunityLineItem> olis = [SELECT Id, UnitPrice, Material_Master__c, Product_Warranty__c, Performance_Warranty__c
                                              FROM OpportunityLineItem WHERE Id IN :orderedQuantities.keySet()];

            List<OrderItem> orderItemsToInsert = new List<OrderItem>();

            for(OpportunityLineItem oli : olis) {
                Decimal uiOrderedQty = orderedQuantities.get(oli.Id);
                    OrderItem oi = new OrderItem(
                    OrderId = newOrder.Id,
                    PricebookEntryId = pbe.Id,
                    Product2Id = stdProduct.Id,
                    Quantity = uiOrderedQty,
                    UnitPrice = oli.UnitPrice,
                    Material_Master__c = oli.Material_Master__c,
                    Product_Warranty_Duration__c = oli.Product_Warranty__c,
                    Performance_Warranty__c = oli.Performance_Warranty__c
                );
                orderItemsToInsert.add(oi);
            }
            insert orderItemsToInsert;

            return newOrder.Id;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Failed to create Order from Opportunity: ' + e.getMessage());
        }
    }
}
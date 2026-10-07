public class ReviseQuoteController {
    
    private static final String QLI_UOM_FIELD_API = 'UOM__c';
    
    public class IncotermOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public IncotermOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class UomOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public UomOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class QuoteLineItemRow {
        @AuraEnabled public Id rowId;
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Id product2Id;
        
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal subtotal;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public String uom;
        @AuraEnabled public Id incoTermsId;
        
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        
        @AuraEnabled public String moduleType;
        @AuraEnabled public String cellType;
        @AuraEnabled public String moduleTechnology;
        @AuraEnabled public String productRatingBin;
        @AuraEnabled public String productSubType;
        @AuraEnabled public String warranty;
        @AuraEnabled public String cableLength;
        
        @AuraEnabled public Decimal projectCapacity;
        
        @AuraEnabled public Boolean alreadyAdded;
        @AuraEnabled public Boolean missingPricebookEntry;
        @AuraEnabled public Id opportunityProductId;
    }
    
    public class QuoteLineItemInitResponse {
        @AuraEnabled public List<QuoteLineItemRow> lineItems;
        @AuraEnabled public List<IncotermOption> incotermOptions;
        @AuraEnabled public List<UomOption> uomOptions;
        @AuraEnabled public Decimal gstPercent;
    }
    
    private static Decimal getGstPercentFromMetadata() {
        List<GST__mdt> gstList = [
            SELECT DeveloperName, GST__c
            FROM GST__mdt
            WHERE DeveloperName = 'JAKSON_GST'
            LIMIT 1
        ];
        
        System.debug('GST Metadata Records: ' + gstList);
        
        if (!gstList.isEmpty() && gstList[0].GST__c != null) {
            System.debug('GST Value Found: ' + gstList[0].GST__c);
            return gstList[0].GST__c;
        }
        
        System.debug('GST Value not found, returning 0');
        return 0;
    }
    
    public class ContactOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public ContactOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Quote getQuoteDetails(Id quoteId) {
        return [
            SELECT Id, Name, QuoteNumber, OpportunityId, Opportunity.Name, AccountId, Account.Name,
            ExpirationDate, Version__c, Internal_Business_Team__c, Business_Segment__c,
            Description, CurrencyIsoCode,
            GST__c, Payment_Terms__c, Claims_Damages__c, Unloading__c,
            Packing_Forwarding__c, Third_Party_Insurance__c, In_Co_terms__c,
            Change_in_Tax_Rate_Law__c, Project_Capacity__c, Commercial_offer_for__c,
            QAP__c, Certificates__c, Limitation_of_Liability__c, Cable_Length__c,
            Offer_Validity__c, Warranty__c, Storage_Charges__c,
            Governing_Law_Jurisdiction__c, Deemed_MDCC__c,
            BillingName, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
            ShippingName, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
            ContactId, Contact.Name, Contact.Email, Contact.Phone,
            Parent_Quote__c, Parent_Quote__r.Name,
            Subtotal, Discount, TotalPrice, GrandTotal,
            Tax, ShippingHandling,
            CreatedDate, CreatedBy.Name,
            LastModifiedDate, LastModifiedBy.Name
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ContactOption> getAccountContacts(Id quoteId) {
        Quote q = [
            SELECT Id, AccountId, ContactId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        List<ContactOption> options = new List<ContactOption>();
        if (q.AccountId == null) {
            return options;
        }
        
        for (Contact con : [
            SELECT Id, Name
            FROM Contact
            WHERE AccountId = :q.AccountId
            ORDER BY Name
        ]) {
            options.add(new ContactOption(con.Name, con.Id));
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static QuoteLineItemInitResponse getQuoteLineItems(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        
        Quote qt = [
            SELECT Id, Pricebook2Id, OpportunityId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        List<QuoteLineItem> qliList = [
            SELECT Id,
            PricebookEntryId,
            PricebookEntry.Product2Id,
            Opportunity_Product__c,
            Quantity,
            Nos__c,
            UnitPrice,
            Total__c,
            Grand_Total__c,
            UOM__c,
            IncoTerms__c,
            Product2.Name,
            Product2.ProductCode,
            Module_Type__c,
            Cell_Type__c,
            Module_Technology__c,
            Product_Rating_BIN__c,
            Product_Sub_Type__c,
            Warranty__c,
            Cable_Length__c,
            Product_Capacity__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ];
        
        List<QuoteLineItemRow> rows = new List<QuoteLineItemRow>();
        
        for (QuoteLineItem qli : qliList) {
            QuoteLineItemRow row = new QuoteLineItemRow();
            row.rowId = qli.Id;
            row.pricebookEntryId = qli.PricebookEntryId;
            row.product2Id = qli.PricebookEntry != null ? qli.PricebookEntry.Product2Id : null;
            
            row.quantity = qli.Nos__c;
            row.unitPrice = qli.UnitPrice;
            row.subtotal = qli.Total__c;
            row.grandTotal = qli.Grand_Total__c;
            row.uom = qli.UOM__c;
            row.incoTermsId = qli.IncoTerms__c;
            
            row.productName = qli.Product2 != null ? qli.Product2.Name : '';
            row.productCode = qli.Product2 != null ? qli.Product2.ProductCode : '';
            
            row.moduleType = qli.Module_Type__c;
            row.cellType = qli.Cell_Type__c;
            row.moduleTechnology = qli.Module_Technology__c;
            row.productRatingBin = qli.Product_Rating_BIN__c;
            row.productSubType = qli.Product_Sub_Type__c;
            row.warranty = qli.Warranty__c != null ? String.valueOf(qli.Warranty__c) : '';
            row.cableLength = qli.Cable_Length__c != null ? String.valueOf(qli.Cable_Length__c) : '';
            row.projectCapacity = qli.Product_Capacity__c;
            
            row.alreadyAdded = false;
            row.missingPricebookEntry = (qli.PricebookEntryId == null);
            row.opportunityProductId = qli.Opportunity_Product__c;
            
            rows.add(row);
        }
        
        QuoteLineItemInitResponse response = new QuoteLineItemInitResponse();
        response.lineItems = rows;
        response.incotermOptions = getIncotermOptions();
        response.uomOptions = getUomOptions();
        response.gstPercent = getGstPercentFromMetadata();
        return response;
    }
    
    @AuraEnabled
    public static Id cloneQuoteAndItems(
        Quote newQuote,
        List<QuoteLineItem> updatedItems,
        Id oldQuoteId,
        Map<String, String> selectedBillingAddress,
        Map<String, String> selectedShippingAddress
    ) {
        try {
            Quote oldQuote = [
                SELECT Id, Name, Status, Version__c, OpportunityId,
                BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
                FROM Quote
                WHERE Id = :oldQuoteId
                LIMIT 1
            ];
            Map<Id, QuoteLineItem> oldQliMap = new Map<Id, QuoteLineItem>();
            
            for (QuoteLineItem oldQli : [
                SELECT Id,
                OpportunityLineItemId,
                PricebookEntryId,
                Module_Type__c,
                Module_Technology__c,
                Product_Rating_BIN__c
                FROM QuoteLineItem
                WHERE QuoteId = :oldQuoteId
            ]) {
                oldQliMap.put(oldQli.Id, oldQli);
            }
            
            oldQuote.Status = 'Denied';
            update oldQuote;
            
            Decimal currentVersion = oldQuote.Version__c != null ? oldQuote.Version__c : 1;
            Integer nextVersion = Integer.valueOf(currentVersion) + 1;
            
            newQuote.Id = null;
            newQuote.Status = 'Draft';
            newQuote.Parent_Quote__c = oldQuote.Id;
            newQuote.Version__c = nextVersion;
            newQuote.OpportunityId = oldQuote.OpportunityId;
            
            String baseQuoteName = String.isBlank(oldQuote.Name) ? 'Quote' : oldQuote.Name;
            baseQuoteName = baseQuoteName.replaceAll('_Version\\s*\\(\\d+\\)$', '');
            newQuote.Name = baseQuoteName + '_Version (' + String.valueOf(nextVersion) + ')';
            
            if (selectedBillingAddress != null && !selectedBillingAddress.isEmpty()) {
                newQuote.BillingStreet = selectedBillingAddress.get('street');
                newQuote.BillingCity = selectedBillingAddress.get('city');
                newQuote.BillingState = selectedBillingAddress.get('state');
                newQuote.BillingPostalCode = selectedBillingAddress.get('postalCode');
                newQuote.BillingCountry = selectedBillingAddress.get('country');
            } else {
                newQuote.BillingStreet = oldQuote.BillingStreet;
                newQuote.BillingCity = oldQuote.BillingCity;
                newQuote.BillingState = oldQuote.BillingState;
                newQuote.BillingPostalCode = oldQuote.BillingPostalCode;
                newQuote.BillingCountry = oldQuote.BillingCountry;
            }
            
            if (selectedShippingAddress != null && !selectedShippingAddress.isEmpty()) {
                newQuote.ShippingStreet = selectedShippingAddress.get('street');
                newQuote.ShippingCity = selectedShippingAddress.get('city');
                newQuote.ShippingState = selectedShippingAddress.get('state');
                newQuote.ShippingPostalCode = selectedShippingAddress.get('postalCode');
                newQuote.ShippingCountry = selectedShippingAddress.get('country');
            } else {
                newQuote.ShippingStreet = oldQuote.ShippingStreet;
                newQuote.ShippingCity = oldQuote.ShippingCity;
                newQuote.ShippingState = oldQuote.ShippingState;
                newQuote.ShippingPostalCode = oldQuote.ShippingPostalCode;
                newQuote.ShippingCountry = oldQuote.ShippingCountry;
            }
            
            insert newQuote;
            
            List<QuoteLineItem> newLineItems = new List<QuoteLineItem>();
            for (QuoteLineItem item : updatedItems) {
                QuoteLineItem newItem = new QuoteLineItem();
                newItem.QuoteId = newQuote.Id;
                newItem.Quantity = 1;
                newItem.PricebookEntryId = item.PricebookEntryId;
                newItem.UnitPrice = item.UnitPrice;
                newItem.UOM__c = item.UOM__c;
                newItem.IncoTerms__c = item.IncoTerms__c;
                newItem.Product_Capacity__c = item.Product_Capacity__c;
                
                newItem.Module_Type__c = item.Module_Type__c;
                newItem.Cell_Type__c = item.Cell_Type__c;
                newItem.Module_Technology__c = item.Module_Technology__c;
                newItem.Product_Rating_BIN__c = item.Product_Rating_BIN__c;
                newItem.Product_Sub_Type__c = item.Product_Sub_Type__c;
                newItem.Warranty__c = item.Warranty__c;
                newItem.Cable_Length__c = item.Cable_Length__c;
                newItem.Opportunity_Product__c = item.Opportunity_Product__c;
                
                newLineItems.add(newItem);
            }
            
            if (!newLineItems.isEmpty()) {
                insert newLineItems;
            }
            
            return newQuote.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error while revising quote: ' + e.getMessage());
        }
    }
    
    private static List<IncotermOption> getIncotermOptions() {
        List<IncotermOption> options = new List<IncotermOption>();
        for (IncoTerms__c inc : [
            SELECT Id, Name, Description__c
            FROM IncoTerms__c
            ORDER BY Name ASC
        ]) {
            String label = inc.Name;
            if (String.isNotBlank(inc.Description__c)) {
                label += ' - ' + inc.Description__c;
            }
            options.add(new IncotermOption(label, inc.Id));
        }
        return options;
    }
    
    private static List<UomOption> getUomOptions() {
        List<UomOption> options = new List<UomOption>();
        Schema.DescribeFieldResult dfr = getUomFieldDescribe();
        
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new UomOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }
    
    private static Schema.DescribeFieldResult getUomFieldDescribe() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.QuoteLineItem.fields.getMap();
        
        if (!fieldMap.containsKey(QLI_UOM_FIELD_API)) {
            throw new AuraHandledException(
                'Quote Line Item UOM field not found. Please update QLI_UOM_FIELD_API in ReviseQuoteController.'
            );
        }
        
        Schema.DescribeFieldResult dfr = fieldMap.get(QLI_UOM_FIELD_API).getDescribe();
        
        if (dfr.getType() != Schema.DisplayType.Picklist) {
            throw new AuraHandledException('Configured UOM field on Quote Line Item must be a Picklist.');
        }
        
        return dfr;
    }
}
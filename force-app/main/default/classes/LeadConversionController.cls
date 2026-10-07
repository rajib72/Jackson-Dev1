public with sharing class LeadConversionController {
    
    @AuraEnabled(cacheable=true)
    public static Account fetchAccountDetails(String accountId) {
        if (String.isBlank(accountId)) {
            return null;
        }
        
        List<Account> accList = [
            SELECT Id, PAN__c, Billing_GST_No__c, Shipping_GST_No__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        return accList.isEmpty() ? null : accList[0];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> fetchMatchingAccounts(
        String accountName,
        String lastName,
        Id lastId,
        Integer pageSize
    ) {
        if (String.isBlank(accountName) || accountName.trim().length() < 2) {
            return new List<Account>();
        }

        String searchTerm = '%' + accountName.trim() + '%';
        Integer resultLimit = normalizePageSize(pageSize);

        if (String.isBlank(lastName) || lastId == null) {
            return [
                SELECT Id, Name, PAN__c, Billing_GST_No__c, Shipping_GST_No__c
                FROM Account
                WHERE Name LIKE :searchTerm
                ORDER BY Name, Id
                LIMIT :resultLimit
            ];
        }

        return [
            SELECT Id, Name, PAN__c, Billing_GST_No__c, Shipping_GST_No__c
            FROM Account
            WHERE Name LIKE :searchTerm
            AND (Name > :lastName OR (Name = :lastName AND Id > :lastId))
            ORDER BY Name, Id
            LIMIT :resultLimit
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Contact> fetchMatchingContacts(
        String selectedAccountId,
        String contactName,
        String lastName,
        Id lastId,
        Integer pageSize
    ) {
        if (String.isBlank(selectedAccountId) || String.isBlank(contactName) || contactName.trim().length() < 2) {
            return new List<Contact>();
        }
        
        String searchTerm = '%' + contactName.trim() + '%';
        Integer resultLimit = normalizePageSize(pageSize);

        if (String.isBlank(lastName) || lastId == null) {
            return [
                SELECT Id, Name, FirstName, LastName, AccountId
                FROM Contact
                WHERE AccountId = :selectedAccountId
                AND Name LIKE :searchTerm
                ORDER BY Name, Id
                LIMIT :resultLimit
            ];
        }

        return [
            SELECT Id, Name, FirstName, LastName, AccountId
            FROM Contact
            WHERE AccountId = :selectedAccountId
            AND Name LIKE :searchTerm
            AND (Name > :lastName OR (Name = :lastName AND Id > :lastId))
            ORDER BY Name, Id
            LIMIT :resultLimit
        ];
    }
    
    @AuraEnabled
    public static Boolean checkIfAccountExists(String accountName) {
        if (String.isBlank(accountName) || accountName.trim().length() < 2) {
            return false;
        }
        
        List<Account> accList = [
            SELECT Id
            FROM Account
            WHERE Name LIKE :accountName
            LIMIT 1
        ];
        return !accList.isEmpty();
    }
    
    @AuraEnabled
    public static Boolean checkIfContactExists(String contactName) {
        if (String.isBlank(contactName) || accountNameOrContactTooShort(contactName)) {
            return false;
        }
        
        List<Contact> conList = [
            SELECT Id
            FROM Contact
            WHERE Name LIKE :contactName
            LIMIT 1
        ];
        return !conList.isEmpty();
    }
    
    @AuraEnabled(cacheable=true)
    public static List<RecordType> getOpportunityRecordTypes() {
        return [
            SELECT Id, Name, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Opportunity'
            AND IsActive = true
            ORDER BY Name
        ];
    }
    
    @AuraEnabled
    public static String convertLead(
        Id leadId,
        Boolean accountExists,
        Boolean contactExists,
        String accountName,
        String contactName,
        String contactFirstName,
        String opportunityName,
        Id recordTypeId,
        Id accountId,
        String panNumber,
        String billingGstNumber,
        String shippingGstNumber
    ) {
        try {
            if (leadId == null) {
                throw new AuraHandledException('Lead Id is required.');
            }
            
            Lead leadRecord = [
                SELECT Id,
                Company,
                FirstName,
                LastName,
                Street,
                City,
                State,
                PostalCode,
                Country,
                Description,
                CurrencyIsoCode,
                UOM__c,
                Email,
                Business_Segment__c,
                Business_Sub_Segment__c,
                Expected_Capacity__c,
                Industry,
                LeadSource,
                MobilePhone,
                Phone,
                Rating,
                Internal_Business_Team__c,
                Expected_Closure_Date__c,
                Lead_Reference_Number__c,
                Estimated_Tender_Value__c,Tender_Details__c,Tender_Due_Date__c,Tender_ID__c,
                Tender_Name__c,Tender_Source__c,Tender_Type__c,Lead_Source_Others__c,Market_Segment__c,
                Market_Segment_Others__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            validateRequiredLeadFields(leadRecord);
            
            Account accountToUse;
            
            /* ---------------- ACCOUNT CREATE / UPDATE ---------------- */
            if (accountExists == true && accountId != null) {
                accountToUse = [
                    SELECT Id,
                    Name,
                    CurrencyIsoCode,
                    PAN__c,
                    Billing_GST_No__c,
                    Shipping_GST_No__c,
                    BillingStreet,
                    BillingCity,
                    BillingState,
                    BillingPostalCode,
                    BillingCountry,
                    ShippingStreet,
                    ShippingCity,
                    ShippingState,
                    ShippingPostalCode,
                    ShippingCountry,
                    Description,
                    Rating,
                    Industry,
                    Phone,
                    Email__c,
                    Status__c
                    FROM Account
                    WHERE Id = :accountId
                    LIMIT 1
                ];
                
                accountToUse.PAN__c = panNumber;
                accountToUse.Billing_GST_No__c = billingGstNumber;
                accountToUse.Shipping_GST_No__c = shippingGstNumber;
                
                accountToUse.BillingStreet = leadRecord.Street;
                accountToUse.BillingCity = leadRecord.City;
                accountToUse.BillingState = leadRecord.State;
                accountToUse.BillingPostalCode = leadRecord.PostalCode;
                accountToUse.BillingCountry = leadRecord.Country;
                
                accountToUse.ShippingStreet = leadRecord.Street;
                accountToUse.ShippingCity = leadRecord.City;
                accountToUse.ShippingState = leadRecord.State;
                accountToUse.ShippingPostalCode = leadRecord.PostalCode;
                accountToUse.ShippingCountry = leadRecord.Country;
                
                accountToUse.Description = leadRecord.Description;
                accountToUse.CurrencyIsoCode = leadRecord.CurrencyIsoCode;
                accountToUse.Rating = leadRecord.Rating;
                accountToUse.Industry = leadRecord.Industry;
                accountToUse.Email__c = leadRecord.Email;
                
                if (String.isNotBlank(leadRecord.Phone)) {
                    accountToUse.Phone = leadRecord.Phone;
                } else if (String.isNotBlank(leadRecord.MobilePhone)) {
                    accountToUse.Phone = leadRecord.MobilePhone;
                }
                
                update accountToUse;
                
            } else {
                if (String.isBlank(accountName)) {
                    throw new AuraHandledException('Account Name is required.');
                }
                
                accountToUse = new Account(
                    Name = accountName,
                    PAN__c = panNumber,
                    Billing_GST_No__c = billingGstNumber,
                    Shipping_GST_No__c = shippingGstNumber,
                    BillingStreet = leadRecord.Street,
                    BillingCity = leadRecord.City,
                    BillingState = leadRecord.State,
                    BillingPostalCode = leadRecord.PostalCode,
                    BillingCountry = leadRecord.Country,
                    ShippingStreet = leadRecord.Street,
                    ShippingCity = leadRecord.City,
                    ShippingState = leadRecord.State,
                    ShippingPostalCode = leadRecord.PostalCode,
                    ShippingCountry = leadRecord.Country,
                    Description = leadRecord.Description,
                    CurrencyIsoCode = leadRecord.CurrencyIsoCode,
                    Rating = leadRecord.Rating,
                    Industry = leadRecord.Industry,
                    Active__c = 'Yes',
                    Email__c = leadRecord.Email,
                    Status__c = 'Draft',
                    Phone = String.isNotBlank(leadRecord.Phone) ? leadRecord.Phone : leadRecord.MobilePhone
                );
                insert accountToUse;
            }
            
            /* ---------------- CONTACT CREATE / USE EXISTING ---------------- */
            Contact newContact;
            
            if (contactExists == true && String.isNotBlank(contactName)) {
                List<Contact> existingContacts = [
                    SELECT Id, Name, FirstName, LastName, AccountId
                    FROM Contact
                    WHERE AccountId = :accountToUse.Id
                    AND FirstName = :contactFirstName
                    AND LastName = :contactName
                    LIMIT 1
                ];
                
                if (!existingContacts.isEmpty()) {
                    newContact = existingContacts[0];
                }
            }
            
            if (newContact == null) {
                String finalLastName = String.isNotBlank(contactName) ? contactName : leadRecord.LastName;
                
                if (String.isBlank(finalLastName)) {
                    throw new AuraHandledException('Contact Last Name is required.');
                }
                
                newContact = new Contact(
                    AccountId = accountToUse.Id,
                    FirstName = String.isNotBlank(contactFirstName) ? contactFirstName : leadRecord.FirstName,
                    LastName = finalLastName,
                    MobilePhone = leadRecord.MobilePhone,
                    Phone = leadRecord.Phone,
                    Email = leadRecord.Email
                );
                insert newContact;
            }
            
            /* ---------------- OPPORTUNITY RECORD TYPE ---------------- */
            RecordType oppRT;
            
            if (recordTypeId != null) {
                List<RecordType> rtList = [
                    SELECT Id, DeveloperName, Name
                    FROM RecordType
                    WHERE Id = :recordTypeId
                    LIMIT 1
                ];
                
                if (rtList.isEmpty()) {
                    throw new AuraHandledException('Selected Opportunity Record Type not found.');
                }
                
                oppRT = rtList[0];
            } else {
                List<RecordType> rtByBusinessSegment = [
                    SELECT Id, DeveloperName, Name
                    FROM RecordType
                    WHERE SObjectType = 'Opportunity'
                    AND DeveloperName = :leadRecord.Business_Segment__c
                    AND IsActive = true
                    LIMIT 1
                ];
                
                if (!rtByBusinessSegment.isEmpty()) {
                    oppRT = rtByBusinessSegment[0];
                } else {
                    List<RecordType> defaultRt = [
                        SELECT Id, DeveloperName, Name
                        FROM RecordType
                        WHERE SObjectType = 'Opportunity'
                        AND IsActive = true
                        ORDER BY Name
                        LIMIT 1
                    ];
                    
                    if (defaultRt.isEmpty()) {
                        throw new AuraHandledException('No active Opportunity Record Type found.');
                    }
                    oppRT = defaultRt[0];
                }
            }
            
            /* ---------------- OPPORTUNITY CREATE ---------------- */
            Opportunity newOpportunity;
            
            Id standardPricebookId = getStandardPricebookId();
            Product2 standardProduct = getStandardProduct();
            PricebookEntry standardPbe = getStandardProductPricebookEntry(standardProduct.Id, standardPricebookId);
            
            if (String.isNotBlank(opportunityName)) {
                newOpportunity = new Opportunity(
                    Name = opportunityName,
                    AccountId = accountToUse.Id,
                    StageName = 'Qualification',
                    CloseDate = System.today().addMonths(1),
                    RecordTypeId = oppRT.Id,
                    CurrencyIsoCode = leadRecord.CurrencyIsoCode,
                    Pricebook2Id = standardPricebookId,
                    Type = 'New Business',
                    LeadSource = leadRecord.LeadSource,
                    Expected_Capacity__c = leadRecord.Expected_Capacity__c,
                    Business_Segment__c = leadRecord.Business_Segment__c,
                    UOM__c = leadRecord.UOM__c,
                    Product_Added__c=True,
                    Description = leadRecord.Description,
                    Internal_Business_Team__c = leadRecord.Internal_Business_Team__c,
                    Key_Account_Opp_Stages__c = (oppRT.DeveloperName == 'KAM') ? 'Qualification' : null,
                    Institutional_Opp_Stages__c = (oppRT.DeveloperName == 'Institutional') ? 'Qualification' : null,
                    Retail_Opp_Stages__c = (oppRT.DeveloperName == 'Retail') ? 'Qualification' : null,
                    Estimated_Tender_Value_CR__c= leadRecord.Estimated_Tender_Value__c,
                    Tender_Details__c = leadRecord.Tender_Details__c,
                    Tender_Due_Date__c= leadRecord.Tender_Due_Date__c,
                    Tender_ID__c = leadRecord.Tender_ID__c,
                    Tender_Name__c = leadRecord.Tender_Name__c,
                    Tender_Source__c = leadRecord.Tender_Source__c,
                    Tender_Type__c = leadRecord.Tender_Type__c,
                    Business_Sub_Segment__c = leadRecord.Business_Sub_Segment__c,
                    //LeadSource = leadRecord.LeadSource,
                    Opportunity_Source_Others__c = leadRecord.Lead_Source_Others__c,
                    Market_Segment__c = leadRecord.Market_Segment__c,
                    Market_Segment_Others__c = leadRecord.Market_Segment_Others__c,
                    Expected_Closure_Date__c = leadRecord.Expected_Closure_Date__c,
                    Rating__c = leadRecord.Rating,
                    Lead_Reference_Number__c = leadRecord.Lead_Reference_Number__c,
                    Contact__c = newContact.Id
                );
                insert newOpportunity;
            }
            
            /* ---------------- COPY LEAD PRODUCT TO CUSTOM OPPORTUNITY PRODUCT ---------------- */
            if (newOpportunity != null) {
                List<Lead_Product__c> leadProducts = [
                    SELECT Id,
                    Warranty__c,
                    Cable_Length__c,
                    Module_Type__c,
                    Cell_Type__c,
                    Module_Technology__c,
                    Product_Rating_BIN__c,
                    Product_Sub_Type__c,
                    Project_Capacity__c,
                    UOM__c
                    FROM Lead_Product__c
                    WHERE Lead__c = :leadId
                ];
                
                if (!leadProducts.isEmpty()) {
                    List<OpportunityLineItem> oppProductList = new List<OpportunityLineItem>();
                    
                    for (Lead_Product__c lp : leadProducts) {
                        OpportunityLineItem oppProd = new OpportunityLineItem();
                        oppProd.OpportunityId = newOpportunity.Id;
                        oppProd.PricebookEntryId = standardPbe.Id;
                        oppProd.Quantity = 1;
                        oppProd.UnitPrice = standardPbe.UnitPrice;
                        
                        oppProd.Warranty__c = lp.Warranty__c;
                        oppProd.Cable_Length__c = lp.Cable_Length__c;
                        oppProd.Module_Type__c = lp.Module_Type__c;
                        oppProd.Cell_Type__c = lp.Cell_Type__c;
                        oppProd.Module_Technology__c = lp.Module_Technology__c;
                        oppProd.Product_Rating_BIN__c = lp.Product_Rating_BIN__c;
                        oppProd.Product_Sub_Type__c = lp.Product_Sub_Type__c;
                        oppProd.Project_Capacity__c= lp.Project_Capacity__c;
                        oppProd.UOM__c= lp.UOM__c;
                        
                        oppProductList.add(oppProd);
                    }
                    
                    if (!oppProductList.isEmpty()) {
                        insert oppProductList;
                    }
                }
            }
            
            /* ---------------- LEAD CONVERSION ---------------- */
            LeadStatus convertStatus = [
                SELECT MasterLabel
                FROM LeadStatus
                WHERE IsConverted = true
                LIMIT 1
            ];
            
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);
            lc.setConvertedStatus(convertStatus.MasterLabel);
            lc.setAccountId(accountToUse.Id);
            lc.setContactId(newContact.Id);
            lc.setDoNotCreateOpportunity(true);
            
            Database.LeadConvertResult lcr = Database.convertLead(lc);
            
            if (!lcr.isSuccess()) {
                String errMsg = 'Lead conversion failed.';
                if (lcr.getErrors() != null && !lcr.getErrors().isEmpty()) {
                    errMsg = lcr.getErrors()[0].getMessage();
                }
                throw new AuraHandledException(errMsg);
            }
            
            return (newOpportunity != null) ? newOpportunity.Id : accountToUse.Id;
            
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    private static Boolean accountNameOrContactTooShort(String valueToCheck) {
        return String.isBlank(valueToCheck) || valueToCheck.trim().length() < 2;
    }

    private static Integer normalizePageSize(Integer pageSize) {
        return pageSize == null ? 20 : Math.max(1, Math.min(pageSize, 50));
    }

    private static void validateRequiredLeadFields(Lead leadRecord) {
        List<String> missingFields = new List<String>();

        if (String.isBlank(leadRecord.Rating)) missingFields.add('Rating');
        if (String.isBlank(leadRecord.Internal_Business_Team__c)) missingFields.add('Internal Business Team');
        if (String.isBlank(leadRecord.Business_Segment__c)) missingFields.add('Business Segment');
        if (String.isBlank(leadRecord.Business_Sub_Segment__c)) missingFields.add('Business Sub Segment');
        if (String.isBlank(leadRecord.Market_Segment__c)) missingFields.add('Market Segment');
        if (leadRecord.Market_Segment__c == 'Others' && String.isBlank(leadRecord.Market_Segment_Others__c)) {
            missingFields.add('Market Segment Others');
        }
        if (leadRecord.LeadSource == 'Others' && String.isBlank(leadRecord.Lead_Source_Others__c)) {
            missingFields.add('Lead Source Others');
        }
        if (leadRecord.Expected_Closure_Date__c == null) {
            missingFields.add('Expected Closure Date');
        } else if (leadRecord.Expected_Closure_Date__c < System.today()) {
            missingFields.add('Expected Closure Date cannot be in the past');
        }
        if (String.isBlank(leadRecord.City)) missingFields.add('City');
        if (String.isBlank(leadRecord.State)) missingFields.add('State');
        if (String.isBlank(leadRecord.Country)) missingFields.add('Country');
        if (String.isBlank(leadRecord.PostalCode)) missingFields.add('Pincode');
        if ([SELECT COUNT() FROM Lead_Product__c WHERE Lead__c = :leadRecord.Id] == 0) {
            missingFields.add('at least one Product');
        }

        if (!missingFields.isEmpty()) {
            throw new AuraHandledException(
                'Please complete these Lead requirements before conversion: ' +
                String.join(missingFields, ', ') +
                '. After completing them, you can convert the Lead.'
            );
        }
    }
    
    private static Id getStandardPricebookId() {
        List<Pricebook2> stdPbList = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];
        
        if (stdPbList.isEmpty()) {
            throw new AuraHandledException('Standard Price Book not found.');
        }
        
        return stdPbList[0].Id;
    }
    
    private static Product2 getStandardProduct() {
        List<Product2> productList = [
            SELECT Id, Name, IsActive
            FROM Product2
            WHERE Name = 'Standard Product'
            AND IsActive = true
            LIMIT 1
        ];
        
        if (productList.isEmpty()) {
            throw new AuraHandledException('Active product "Standard Product" not found.');
        }
        
        return productList[0];
    }
    
    private static PricebookEntry getStandardProductPricebookEntry(Id productId, Id pricebookId) {
        List<PricebookEntry> pbeList = [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive
            FROM PricebookEntry
            WHERE Product2Id = :productId
            AND Pricebook2Id = :pricebookId
            AND IsActive = true
            LIMIT 1
        ];
        
        if (pbeList.isEmpty()) {
            throw new AuraHandledException(
                'Active Standard Price Book entry not found for product "Standard Product".'
            );
        }
        
        return pbeList[0];
    }
}
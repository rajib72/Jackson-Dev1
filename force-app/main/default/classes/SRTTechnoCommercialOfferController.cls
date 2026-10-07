public with sharing class SRTTechnoCommercialOfferController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialData(Id oppId) {

        Opportunity opp = [
            SELECT Id, Name, AccountId, Internal_Business_Team__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        Account acc = [
            SELECT Id, Name,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM Account
            WHERE Id = :opp.AccountId
            LIMIT 1
        ];

        List<Contact> contacts = [
            SELECT Id, Name
            FROM Contact
            WHERE AccountId = :acc.Id
        ];

        return new Map<String, Object>{
            'opportunity' => opp,
            'account' => acc,
            'contacts' => contacts
        };
    }

    @AuraEnabled
    public static Id createQuote(
        Id opportunityId,
        Id accountId,
        Id contactId,
        String name,
        Date expirationDate,
        String description,
        String billingStreet,
        String billingCity,
        String billingState,
        String billingPostalCode,
        String billingCountry,
        String shippingStreet,
        String shippingCity,
        String shippingState,
        String shippingPostalCode,
        String shippingCountry
    ) {

        Opportunity opp = [
            SELECT Id, Internal_Business_Team__c
            FROM Opportunity
            WHERE Id = :opportunityId
        ];

        Quote q = new Quote();

        q.Account__c = accountId;
        q.OpportunityId = opportunityId;
        q.ContactId = contactId;
        q.Name = name;
        q.ExpirationDate = expirationDate;
        q.Description = description;

        q.BillingStreet = billingStreet;
        q.BillingCity = billingCity;
        q.BillingState = billingState;
        q.BillingPostalCode = billingPostalCode;
        q.BillingCountry = billingCountry;

        q.ShippingStreet = shippingStreet;
        q.ShippingCity = shippingCity;
        q.ShippingState = shippingState;
        q.ShippingPostalCode = shippingPostalCode;
        q.ShippingCountry = shippingCountry;

        if(opp.Internal_Business_Team__c == 'SRT Sales'){
            q.Internal_Business_Team__c = 'SRT Sales';
        }

        insert q;

        // 🔥 NEW LOGIC → Mark Offer Created = TRUE
        Opportunity updateOpp = new Opportunity(
            Id = opportunityId,
            Is_KAM_SRT_Offer_Cretaed__c = true
        );
        update updateOpp;

        return q.Id;
    }
}
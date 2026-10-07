public with sharing class ctrl_ServiceAppointmentController {

    // Wrapper class to hold concatenated label and individual payload values
    public class AddressOption {
        @AuraEnabled public String label; // Concatenated: Site, Street, Postal Code
        @AuraEnabled public String value; // Used as the unique key in the combobox
        @AuraEnabled public String siteName;
        @AuraEnabled public String street;
        @AuraEnabled public String postalCode;
    }

    public class WorkOrderDefaults {
        @AuraEnabled public String workOrderId;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id serviceTerritoryId;
        @AuraEnabled public Id workTypeId;
        @AuraEnabled public String street;
        @AuraEnabled public String postalCode;
        
        // Consolidated address options list
        @AuraEnabled public List<AddressOption> addressOptions;
    }

    public class LookupOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        public LookupOption(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }

    public class SaveRequest {
        @AuraEnabled public String workOrderId {get;set;}
        @AuraEnabled public String subject {get;set;}
        @AuraEnabled public String status {get;set;}
        @AuraEnabled public Id serviceTerritoryId {get;set;}
        @AuraEnabled public Id workTypeId {get;set;}
        @AuraEnabled public Id shipToAccountId {get;set;}
        @AuraEnabled public String siteName {get;set;}
        @AuraEnabled public String street {get;set;}
        @AuraEnabled public String postalCode {get;set;}
        @AuraEnabled public String description {get;set;}
    }

    @AuraEnabled(cacheable=true)
    public static WorkOrderDefaults getWorkOrderDefaults(Id workOrderId) {
        if (workOrderId == null) throw new AuraHandledException('Work Order Id is required.');

        WorkOrder wo = [
            SELECT Id, WorkOrderNumber, Subject, AccountId, Account.Name,
                   ServiceTerritoryId, WorkTypeId, Street, PostalCode
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        WorkOrderDefaults res = new WorkOrderDefaults();
        res.workOrderId = wo.Id;
        res.workOrderNumber = wo.WorkOrderNumber;
        res.subject = wo.Subject;
        res.accountId = wo.AccountId;
        res.accountName = wo.Account != null ? wo.Account.Name : null;
        res.serviceTerritoryId = wo.ServiceTerritoryId;
        res.workTypeId = wo.WorkTypeId;
        res.street = wo.Street;
        res.postalCode = wo.PostalCode;

        // Map to deduplicate identical addresses across multiple assets
        Map<String, AddressOption> uniqueAddresses = new Map<String, AddressOption>();

        for (WorkOrderLineItem woli : [
            SELECT Asset.Site_Name__c, Asset.Address__c, Asset.Pin_Code__c
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrderId 
            AND AssetId != null
        ]) {
            List<String> addressParts = new List<String>();
            
            String site = String.isNotBlank(woli.Asset.Site_Name__c) ? woli.Asset.Site_Name__c : '';
            String street = String.isNotBlank(woli.Asset.Address__c) ? woli.Asset.Address__c : '';
            String postal = String.isNotBlank(woli.Asset.Pin_Code__c) ? woli.Asset.Pin_Code__c : '';
            
            if (String.isNotBlank(site)) addressParts.add(site);
            if (String.isNotBlank(street)) addressParts.add(street);
            if (String.isNotBlank(postal)) addressParts.add(postal);
            
            // Only add if at least one piece of address information exists
            if (!addressParts.isEmpty()) {
                String concatenatedLabel = String.join(addressParts, ', ');
                
                if (!uniqueAddresses.containsKey(concatenatedLabel)) {
                    AddressOption opt = new AddressOption();
                    opt.label = concatenatedLabel;
                    opt.value = concatenatedLabel; // Unique identifier for the combobox
                    opt.siteName = site;
                    opt.street = street;
                    opt.postalCode = postal;
                    
                    uniqueAddresses.put(concatenatedLabel, opt);
                }
            }
        }

        res.addressOptions = uniqueAddresses.values();
        return res;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> searchAccounts(String searchKey) {
        String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
        List<LookupOption> options = new List<LookupOption>();
        for (Account acc : [SELECT Id, Name FROM Account WHERE Name LIKE :key ORDER BY Name LIMIT 10]) {
            options.add(new LookupOption(acc.Id, acc.Name));
        }
        return options;
    }

    @AuraEnabled
    public static Id createServiceAppointment(SaveRequest req) {
        if (req == null || String.isBlank(req.workOrderId)) {
            throw new AuraHandledException('Work Order Id is required.');
        }

        ServiceAppointment sa = new ServiceAppointment();
        sa.ParentRecordId = req.workOrderId;
        sa.Subject = req.subject;
        sa.Status = req.status;

        // Custom and Standard Field Mapping
        sa.Site_Name__c = req.siteName; 
        sa.Street = req.street;
        sa.PostalCode = req.postalCode;
        sa.Description = req.description;

        if (req.serviceTerritoryId != null) sa.ServiceTerritoryId = req.serviceTerritoryId;
        if (req.workTypeId != null) sa.WorkTypeId = req.workTypeId;

        try {
            insert sa;
            return sa.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
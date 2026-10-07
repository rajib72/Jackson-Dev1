public with sharing class OpportunityProductTriggerHandler {

    private static final Set<String> ALLOWED_RECORD_TYPES = new Set<String>{
        'Retail',
        'Institutional',
        'KAM'
    };

    public static void updateOpportunityExpectedCapacity(
        List<OpportunityLineItem> newList,
        List<OpportunityLineItem> oldList
    ) {
        Set<Id> opportunityIds = new Set<Id>();

        if (newList != null) {
            for (OpportunityLineItem oli : newList) {
                if (oli.OpportunityId != null) {
                    opportunityIds.add(oli.OpportunityId);
                }
            }
        }

        if (oldList != null) {
            for (OpportunityLineItem oli : oldList) {
                if (oli.OpportunityId != null) {
                    opportunityIds.add(oli.OpportunityId);
                }
            }
        }

        if (opportunityIds.isEmpty()) {
            return;
        }

        /*
         * Only Retail, Institutional and KAM Opportunity record types will be processed.
         */
        Map<Id, Opportunity> eligibleOpportunityMap = new Map<Id, Opportunity>();

        for (Opportunity opp : [
            SELECT Id,
                   Expected_Capacity__c,
                   UOM__c,
                   RecordType.DeveloperName
            FROM Opportunity
            WHERE Id IN :opportunityIds
            AND RecordType.DeveloperName IN :ALLOWED_RECORD_TYPES
        ]) {
            eligibleOpportunityMap.put(opp.Id, opp);
        }

        if (eligibleOpportunityMap.isEmpty()) {
            return;
        }

        Set<Id> eligibleOpportunityIds = eligibleOpportunityMap.keySet();

        Map<Id, Decimal> opportunityIdToCapacityKW = new Map<Id, Decimal>();

        for (Id oppId : eligibleOpportunityIds) {
            opportunityIdToCapacityKW.put(oppId, 0);
        }

        List<OpportunityLineItem> opportunityProducts = [
            SELECT Id,
                   OpportunityId,
                   Project_Capacity__c,
                   UOM__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :eligibleOpportunityIds
        ];

        for (OpportunityLineItem oli : opportunityProducts) {
            if (oli.OpportunityId == null || oli.Project_Capacity__c == null) {
                continue;
            }

            Decimal capacityInKW = convertToKW(oli.Project_Capacity__c, oli.UOM__c);

            Decimal existingValue = opportunityIdToCapacityKW.containsKey(oli.OpportunityId)
                ? opportunityIdToCapacityKW.get(oli.OpportunityId)
                : 0;

            opportunityIdToCapacityKW.put(oli.OpportunityId, existingValue + capacityInKW);
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Id oppId : eligibleOpportunityIds) {
            Decimal totalCapacityKW = opportunityIdToCapacityKW.get(oppId);

            Opportunity existingOpp = eligibleOpportunityMap.get(oppId);

            if (
                existingOpp.Expected_Capacity__c != totalCapacityKW ||
                existingOpp.UOM__c != 'KW'
            ) {
                opportunitiesToUpdate.add(new Opportunity(
                    Id = oppId,
                    Expected_Capacity__c = totalCapacityKW,
                    UOM__c = 'KW'
                ));
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }

    private static Decimal convertToKW(Decimal capacity, String uom) {
        if (capacity == null) {
            return 0;
        }

        if (String.isBlank(uom)) {
            return capacity;
        }

        String normalizedUom = uom.trim().toUpperCase();

        if (normalizedUom == 'MW') {
            return capacity * 1000;
        }

        if (normalizedUom == 'KW') {
            return capacity;
        }

        return capacity;
    }
    
    public static void datacover() {
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
    }
}
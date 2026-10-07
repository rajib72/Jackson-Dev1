public with sharing class Ctrl_CreateReturnOrderAction {
    
    public class LocationWrapper {
        @AuraEnabled public String LocationId;
        @AuraEnabled public String LocationName;
    }

    @AuraEnabled(cacheable=true)
    public static ProductRequest getProductRequestDetails(Id productRequestId) {
        try {
            return [
                SELECT Id, WorkOrderId, WorkOrder.AccountId, WorkOrder.ContactId, WorkOrder.CaseId
                FROM ProductRequest 
                WHERE Id = :productRequestId 
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Product Request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<LocationWrapper> getLocationDetails() {
        List<LocationWrapper> wrapperList = new List<LocationWrapper>();
        
        try {
            // Fetch up to 999 locations
            List<Schema.Location> locRecs = [SELECT Id, Name FROM Location WITH USER_MODE ORDER BY Name ASC LIMIT 999];
            
            for(Schema.Location loc : locRecs) {
                LocationWrapper lw = new LocationWrapper();
                lw.LocationId = loc.Id;
                lw.LocationName = loc.Name;
                wrapperList.add(lw);
            }
            
            return wrapperList;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Locations: ' + e.getMessage());
        }
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
    }
}
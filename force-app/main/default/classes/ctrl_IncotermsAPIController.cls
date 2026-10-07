public with sharing class ctrl_IncotermsAPIController {

    // --- External API Wrappers ---
    public class IncotermItem {
        public String INCOTERMS;
        public String DESCRIPTION;
    }

    public class ResultWrapper {
        public List<IncotermItem> item;
    }

    public class ResponseWrapper {
        public ResultWrapper RESULT;
    }

    // --- LWC UI Wrappers ---
    public class SyncResult {
        @AuraEnabled public Integer totalReceived { get; set; }
        @AuraEnabled public Integer totalCreated { get; set; }
        @AuraEnabled public Integer totalUpdated { get; set; }
        @AuraEnabled public Integer totalErrors { get; set; }
        @AuraEnabled public List<ProcessedRecord> processedRecords { get; set; }
        
        public SyncResult() {
            this.totalReceived = 0;
            this.totalCreated = 0;
            this.totalUpdated = 0;
            this.totalErrors = 0;
            this.processedRecords = new List<ProcessedRecord>();
        }
    }

    public class ProcessedRecord {
        @AuraEnabled public String incoterm { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String action { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    @AuraEnabled
    public static SyncResult syncIncoterms() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:sap_MM/incoterms');
            req.setMethod('POST');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                throw new CalloutException('API Error : ' + res.getStatusCode() + ' - ' + res.getBody());
            }

            String responseBody = res.getBody();

            if (String.isBlank(responseBody)) {
                throw new CalloutException('Empty response received from API');
            }

            ResponseWrapper responseObj = (ResponseWrapper) JSON.deserialize(responseBody, ResponseWrapper.class);

            if (responseObj == null || responseObj.RESULT == null || responseObj.RESULT.item == null) {
                return new SyncResult(); // Return empty result gracefully
            }

            return processAndUpsertIncoterms(responseObj.RESULT.item);

        } catch (Exception e) {
            // Throwing AuraHandledException ensures the LWC can read the error message
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static SyncResult processAndUpsertIncoterms(List<IncotermItem> apiRecords) {
        SyncResult result = new SyncResult();
        result.totalReceived = apiRecords.size();

        Set<String> incotermCodes = new Set<String>();
        for (IncotermItem item : apiRecords) {
            if (String.isNotBlank(item.INCOTERMS)) {
                incotermCodes.add(item.INCOTERMS);
            }
        }

        Map<String, Incoterms_Master__c> existingRecords = new Map<String, Incoterms_Master__c>();
        for (Incoterms_Master__c rec : [
            SELECT Id, INCOTERMS__c, DESCRIPTION__c 
            FROM Incoterms_Master__c 
            WHERE INCOTERMS__c IN :incotermCodes
        ]) {
            existingRecords.put(rec.INCOTERMS__c, rec);
        }

        List<Incoterms_Master__c> recordsToUpsert = new List<Incoterms_Master__c>();
        List<ProcessedRecord> trackingList = new List<ProcessedRecord>();

        for (IncotermItem item : apiRecords) {
            Incoterms_Master__c record;
            if (existingRecords.containsKey(item.INCOTERMS)) {
                record = existingRecords.get(item.INCOTERMS);
                record.DESCRIPTION__c = item.DESCRIPTION;
            } else {
                record = new Incoterms_Master__c();
                record.INCOTERMS__c = item.INCOTERMS;
                record.DESCRIPTION__c = item.DESCRIPTION;
            }
            recordsToUpsert.add(record);

            // Create a tracking record aligned with the DML list
            ProcessedRecord pr = new ProcessedRecord();
            pr.incoterm = item.INCOTERMS;
            pr.description = item.DESCRIPTION;
            trackingList.add(pr);
        }

        if (!recordsToUpsert.isEmpty()) {
            // opt_allOrNone = false allows partial success processing
            Database.UpsertResult[] upsertResults = Database.upsert(recordsToUpsert, false);

            for (Integer i = 0; i < upsertResults.size(); i++) {
                ProcessedRecord pr = trackingList[i];
                Database.UpsertResult sr = upsertResults[i];

                if (sr.isSuccess()) {
                    if (sr.isCreated()) {
                        result.totalCreated++;
                        pr.action = 'Created';
                    } else {
                        result.totalUpdated++;
                        pr.action = 'Updated';
                    }
                    pr.message = 'Processed successfully';
                } else {
                    result.totalErrors++;
                    pr.action = 'Error';
                    pr.message = sr.getErrors()[0].getMessage(); 
                }
                result.processedRecords.add(pr);
            }
        }

        return result;
    }
}
public with sharing class MaterialMasterController {
    
    /*
    Wrapper class for SAP Response
         */
    public class MaterialWrapper {
        
        @AuraEnabled public String MATERIAL_CODE { get; set; }
        @AuraEnabled public String MATERIAL_DESCRIPTION { get; set; }
        @AuraEnabled public String CREATED_ON { get; set; }
        @AuraEnabled public String CREATED_BY { get; set; }
        @AuraEnabled public String MATERIAL_GROUP { get; set; }
        @AuraEnabled public String MATERIAL_GROUP_DESCRIPTION { get; set; }
        @AuraEnabled public String UNIT_OF_MEASURE { get; set; }
        @AuraEnabled public String MATERIAL_TYPE { get; set; }
        @AuraEnabled public String MATERIAL_TYPE_DESCRIPTION { get; set; }
        @AuraEnabled public String PLANT { get; set; }
        @AuraEnabled public String PLANT_DESCRIPTION { get; set; }
        @AuraEnabled public String SALES_ORG { get; set; }
        @AuraEnabled public String DISTRIBUTION_CHANNEL { get; set; }
        @AuraEnabled public String DIVISION { get; set; }
        @AuraEnabled public String STORAGE_LOCATION { get; set; } 
        @AuraEnabled public String STORAGE_LOCATION_DESCRIPTION { get; set; }
        
    }
    
    
    /*
    Fetch Materials From SAP
         */
    @AuraEnabled
    public static List<MaterialWrapper> fetchMaterials(String requestType, Date fromDate, Date toDate){
        
        try{
            
            if(fromDate == null || toDate == null){
                throw new AuraHandledException('From Date and To Date are required');
            }
            
            String fromDateFormatted = formatDate(fromDate);
            String toDateFormatted = formatDate(toDate);
            
            Map<String,Object> requestBody = new Map<String,Object>();
            
            if(requestType == 'CREATION'){
                
                requestBody.put('CREATION_FROM_DATE', fromDateFormatted);
                requestBody.put('CREATION_TO_DATE', toDateFormatted);
                
            }else{
                
                requestBody.put('CHANGED_FROM_DATE', fromDateFormatted);
                requestBody.put('CHANGED_TO_DATE', toDateFormatted);
                
            }
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:sap_MM/rfcMatMast');
            req.setMethod('POST');
            req.setHeader('Content-Type','application/json');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(requestBody));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if(res.getStatusCode() == 200){
                
                List<MaterialWrapper> materials =
                    (List<MaterialWrapper>) JSON.deserialize(res.getBody(), List<MaterialWrapper>.class);
                
                return materials;
                
            }else{
                
                throw new AuraHandledException('SAP API Error: ' + res.getBody());
                
            }
            
        }catch(Exception ex){
            
            logIntegrationError(ex);
            throw new AuraHandledException('Error fetching materials from SAP.');
            
        }
    }
    
    
    
    /*
    Save Materials into Salesforce
         */
    @AuraEnabled
    public static String saveMaterials(List<MaterialWrapper> materials){
        
        try{
            
            if(materials == null || materials.isEmpty()){
                return 'No records received from SAP';
            }
            
            Database.executeBatch(
                new MaterialMasterBatch(materials, UserInfo.getUserId()),
                200
            );
            
            return 'Material processing started. You will receive an email after completion.';
            
        }catch(Exception ex){
            
            logIntegrationError(ex);
            throw new AuraHandledException('Error starting material processing.');
            
        }
    }
    
    
    
    /*
    Generate Composite Unique Key
         */
    public static String generateUniqueKey(MaterialWrapper m){
        
        List<String> parts = new List<String>();
        
        parts.add(m.MATERIAL_CODE);
        parts.add(m.PLANT);
        parts.add(m.SALES_ORG);
        parts.add(m.DISTRIBUTION_CHANNEL);
        parts.add(m.DIVISION);
        parts.add(m.STORAGE_LOCATION);
        
        return String.join(parts,'|');
    }
    
    
    
    /*
    Convert Date to SAP Format YYYYMMDD
         */
    public static String formatDate(Date d){
        
        String year = String.valueOf(d.year());
        
        String month =
            d.month() < 10 ? '0'+String.valueOf(d.month()) : String.valueOf(d.month());
        
        String day =
            d.day() < 10 ? '0'+String.valueOf(d.day()) : String.valueOf(d.day());
        
        return year + month + day;
    }
    public static void logIntegrationError(Exception ex){
        
        try{
            Integration_Error_Log__c log = new Integration_Error_Log__c();
            
            log.Error_Message__c = ex.getMessage();
            log.Stack_Trace__c = ex.getStackTraceString();
            log.Source_System__c = 'MaterialMasterController';
            log.Logged_On__c = String.valueOf(System.now());
            
            insert log;
            
        }catch(Exception loggingException){
            System.debug('Failed to log integration error: ' + loggingException.getMessage());
        }
    }
    
}
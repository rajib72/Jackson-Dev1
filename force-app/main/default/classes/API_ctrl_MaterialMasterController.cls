public with sharing class API_ctrl_MaterialMasterController {

    public class ResponseWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer totalReceived;
        @AuraEnabled public Integer createdCount;
        @AuraEnabled public Integer updatedCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<ResultRow> results;
    }

    public class ResultRow {
        @AuraEnabled public String materialCode;
        @AuraEnabled public String plant;
        @AuraEnabled public String storageLocation;
        @AuraEnabled public String uniqueKey;
        @AuraEnabled public String action;
        @AuraEnabled public String message;
    }

    public class SapMaterialDTO {
        public String MATERIAL_CODE;
        public String MATERIAL_DESCRIPTION;
        public String CREATED_ON;
        public String CREATED_BY;
        public String MATERIAL_GROUP;
        public String MATERIAL_GROUP_DESCRIPTION;
        public String UNIT_OF_MEASURE;
        public String MATERIAL_TYPE;
        public String MATERIAL_TYPE_DESCRIPTION;
        public String PLANT;
        public String PLANT_DESCRIPTION;
        public String STORAGE_LOCATION;
        public String STORAGE_LOCATION_DESCRIPTION;
        public String SALES_ORG;
        public String DISTRIBUTION_CHANNEL;
        public String DISTTRIBUTION_CHANNEL_DESC;
        public String DIVISION;
        public String DIVISION_DESCRIPTION;
    }

    @AuraEnabled
    public static ResponseWrapper fetchAndStoreMaterialMaster(String filterType, Date fromDate, Date toDate, String materialCode) {
        ResponseWrapper response = new ResponseWrapper();
        response.success = false;
        response.message = '';
        response.totalReceived = 0;
        response.createdCount = 0;
        response.updatedCount = 0;
        response.errorCount = 0;
        response.results = new List<ResultRow>();

        // Backend Validation based on filter type
        if (filterType == 'DateRange') {
            if (fromDate == null || toDate == null) {
                response.message = 'From Date and To Date are required.';
                return response;
            }
            if (fromDate > toDate) {
                response.message = 'From Date cannot be greater than To Date.';
                return response;
            }
        } else if (filterType == 'MaterialCode') {
            if (String.isBlank(materialCode)) {
                response.message = 'Material Code is required.';
                return response;
            }
        }

        String endpointName = 'callout:NC_SAP_API/http/rfcMatMast';
        String httpMethod = 'POST';
        String requestBodyString = '';
        Integer statusCode;
        String responseBody = '';

        try {
            Map<String, Object> requestBody = new Map<String, Object>();
            
            // Build dynamic JSON body based on selection
            if (filterType == 'DateRange') {
                String fromFormattedDate = formatDateYYYYMMDD(fromDate);
                String toFormattedDate   = formatDateYYYYMMDD(toDate);
                requestBody.put('CREATION_FROM_DATE', fromFormattedDate);
                requestBody.put('CREATION_TO_DATE', toFormattedDate);
            } else if (filterType == 'MaterialCode') {
                requestBody.put('MATERIAL_CODE', materialCode.trim());
            }

            requestBodyString = JSON.serialize(requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpointName);
            req.setMethod(httpMethod);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBodyString);

            Http http = new Http();
            HttpResponse res = http.send(req);

            statusCode = res.getStatusCode();
            responseBody = res.getBody();
            
            System.debug('statusCode----'+statusCode);
            System.debug('responseBody----'+responseBody);

            if (statusCode != 200) {
                logIntegrationError(
                    'SAP Material Master API',
                    'HTTP_' + statusCode,
                    'Non-success response received from SAP API.',
                    httpMethod,
                    requestBodyString,
                    endpointName,
                    'SAP',
                    null,
                    String.valueOf(statusCode)
                );

                response.message = 'SAP API returned non-success status: ' + statusCode;
                return response;
            }

            if (String.isBlank(responseBody)) {
                logIntegrationError(
                    'SAP Material Master API',
                    'EMPTY_RESPONSE',
                    'Empty response received from SAP API.',
                    httpMethod,
                    requestBodyString,
                    endpointName,
                    'SAP',
                    null,
                    String.valueOf(statusCode)
                );

                response.message = 'SAP API returned an empty response.';
                return response;
            }

            List<SapMaterialDTO> sapRecords = (List<SapMaterialDTO>) JSON.deserialize(responseBody, List<SapMaterialDTO>.class);
            response.totalReceived = sapRecords != null ? sapRecords.size() : 0;
            
            Integer recordCount = (sapRecords == null) ? 0 : sapRecords.size();
            System.debug('Total output records from SAP API: ' + recordCount);

            if (sapRecords == null || sapRecords.isEmpty()) {
                response.success = true;
                response.message = 'No data received from SAP for the selected criteria.';
                return response;
            }

            Set<String> uniqueKeys = new Set<String>();
            for (SapMaterialDTO dto : sapRecords) {
                uniqueKeys.add(generateUniqueKey(dto));
            }

            Map<String, Material_Master__c> existingMap = new Map<String, Material_Master__c>();
            for (Material_Master__c mm : [
                SELECT Id, Unique_Key__c
                FROM Material_Master__c
                WHERE Unique_Key__c IN :uniqueKeys
            ]) {
                existingMap.put(mm.Unique_Key__c, mm);
            }

            List<Material_Master__c> recordsToInsert = new List<Material_Master__c>();
            List<Material_Master__c> recordsToUpdate = new List<Material_Master__c>();

            for (SapMaterialDTO dto : sapRecords) {
                String uniqueKey = generateUniqueKey(dto);

                Material_Master__c materialRec;
                Boolean isUpdate = false;

                if (existingMap.containsKey(uniqueKey)) {
                    materialRec = existingMap.get(uniqueKey);
                    isUpdate = true;
                } else {
                    materialRec = new Material_Master__c();
                }

                materialRec.Name = safeValue(dto.MATERIAL_CODE);
                materialRec.Unique_Key__c = uniqueKey;
                materialRec.Created_By__c = safeValue(dto.CREATED_BY);
                materialRec.Created_On__c = dto.CREATED_ON;
                materialRec.Distribution_Channel__c = safeValue(dto.DISTRIBUTION_CHANNEL);
                materialRec.Division__c = safeValue(dto.DIVISION);
                materialRec.Material_Description__c = safeValue(dto.MATERIAL_DESCRIPTION);
                materialRec.Material_Group__c = safeValue(dto.MATERIAL_GROUP);
                materialRec.Material_Group_Description__c = safeValue(dto.MATERIAL_GROUP_DESCRIPTION);
                materialRec.Material_Type__c = safeValue(dto.MATERIAL_TYPE);
                materialRec.Material_Type_Description__c = safeValue(dto.MATERIAL_TYPE_DESCRIPTION);
                materialRec.Plant__c = safeValue(dto.PLANT);
                materialRec.Plant_Description__c = safeValue(dto.PLANT_DESCRIPTION);
                materialRec.Sales_Org__c = safeValue(dto.SALES_ORG);
                materialRec.Storage_Location__c = safeValue(dto.STORAGE_LOCATION);
                materialRec.Storage_Location_Description__c = safeValue(dto.STORAGE_LOCATION_DESCRIPTION);
                materialRec.Unit_of_Measure__c = safeValue(dto.UNIT_OF_MEASURE);

                if (isUpdate) {
                    recordsToUpdate.add(materialRec);
                } else {
                    recordsToInsert.add(materialRec);
                }
            }

            if (!recordsToInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(recordsToInsert, false);
                handleSaveResults(insertResults, recordsToInsert, 'Created', response);
            }

            if (!recordsToUpdate.isEmpty()) {
                Database.SaveResult[] updateResults = Database.update(recordsToUpdate, false);
                handleSaveResults(updateResults, recordsToUpdate, 'Updated', response);
            }

            response.success = (response.errorCount == 0);
            response.message =
                'Processed successfully. Total Received: ' + response.totalReceived +
                ', Created: ' + response.createdCount +
                ', Updated: ' + response.updatedCount +
                ', Errors: ' + response.errorCount;

            return response;

        } catch (Exception ex) {
            logIntegrationError(
                'SAP Material Master API',
                ex.getTypeName(),
                ex.getMessage(),
                httpMethod,
                requestBodyString,
                endpointName,
                'SAP',
                ex.getStackTraceString(),
                statusCode != null ? String.valueOf(statusCode) : null
            );

            response.success = false;
            response.message = 'Error while processing SAP API: ' + ex.getMessage();
            return response;
        }
    }

    private static void handleSaveResults(
        Database.SaveResult[] saveResults,
        List<Material_Master__c> records,
        String actionName,
        ResponseWrapper response
    ) {
        for (Integer i = 0; i < saveResults.size(); i++) {
            Material_Master__c rec = records[i];
            ResultRow row = new ResultRow();
            row.materialCode = rec.Name;
            row.plant = rec.Plant__c;
            row.storageLocation = rec.Storage_Location__c;
            row.uniqueKey = rec.Unique_Key__c;

            if (saveResults[i].isSuccess()) {
                row.action = actionName;
                row.message = actionName + ' successfully';
                response.results.add(row);

                if (actionName == 'Created') {
                    response.createdCount++;
                } else if (actionName == 'Updated') {
                    response.updatedCount++;
                }
            } else {
                String errMsg = '';
                String errCode = '';

                for (Database.Error err : saveResults[i].getErrors()) {
                    errMsg += err.getMessage() + ' ';
                    errCode += String.valueOf(err.getStatusCode()) + ' ';
                }

                row.action = 'Error';
                row.message = errMsg;
                response.results.add(row);
                response.errorCount++;

                logIntegrationError(
                    'SAP Material Master API',
                    errCode,
                    errMsg,
                    'DML',
                    rec.Unique_Key__c,
                    'Material_Master__c',
                    'Salesforce',
                    '',
                    ''
                );
            }
        }
    }

    private static String formatDateYYYYMMDD(Date inputDate) {
        String monthStr = (inputDate.month() < 10 ? '0' : '') + String.valueOf(inputDate.month());
        String dayStr   = (inputDate.day() < 10 ? '0' : '') + String.valueOf(inputDate.day());
        return String.valueOf(inputDate.year()) + monthStr + dayStr;
    }

    private static Date parseDate(String dateStr) {
        if (String.isBlank(dateStr)) {
            return null;
        }
        try {
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            return null;
        }
    }

    private static String generateUniqueKey(SapMaterialDTO dto) {
        return safeValue(dto.MATERIAL_CODE) + '|' +
               safeValue(dto.PLANT) + '|' +
               safeValue(dto.STORAGE_LOCATION) + '|' +
               safeValue(dto.SALES_ORG) + '|' +
               safeValue(dto.DISTRIBUTION_CHANNEL) + '|' +
               safeValue(dto.DIVISION);
    }

    private static String safeValue(String input) {
        return input == null ? '' : input.trim();
    }

    private static void logIntegrationError(
        String apiName,
        String errorCode,
        String errorMessage,
        String httpMethod,
        String requestParameters,
        String requestUri,
        String sourceSystem,
        String stackTrace,
        String statusCode
    ) {
        try {
            Integration_Error_Log__c logRec = new Integration_Error_Log__c();
            logRec.API_Name__c = apiName;
            logRec.Error_Code__c = errorCode;
            logRec.Error_Message__c = errorMessage;
            logRec.Http_Method__c = httpMethod;
            logRec.Logged_On__c = String.valueOf(System.now());
            logRec.Request_Parameters__c = requestParameters;
            logRec.Request_URI__c = requestUri;
            logRec.Source_System__c = sourceSystem;
            logRec.Stack_Trace__c = stackTrace;
            logRec.Status_Code__c = Decimal.valueOf(statusCode);
            insert logRec;
        } catch (Exception e) {
            System.debug('Failed to log integration error: ' + e.getMessage());
        }
    }
}
public with sharing class Ctrl_fetchAssetSerialNo {
    
    @AuraEnabled
    public static String fetchAndSaveSerialNumber(Id assetId) {
        try {
            // 1. Query the Asset to get the Invoice Number
            Asset targetAsset = [SELECT Id, Invoice_Number__c FROM Asset WHERE Id = :assetId LIMIT 1];
            
            if (String.isBlank(targetAsset.Invoice_Number__c)) {
                throw new CustomException('Invoice Number is missing on this Asset. Cannot fetch Serial Number.');
            }

            // 2. Prepare the HTTP Callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:NC_SAP_API/http/serialNumber');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            
            // 3. Construct the Request Body
            Map<String, String> requestBody = new Map<String, String>{
                'INVOICE' => targetAsset.Invoice_Number__c
            };
            req.setBody(JSON.serialize(requestBody));

            // 4. Send the Request
            Http http = new Http();
            HttpResponse res = http.send(req);

            // 5. Process the Response
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                String responseBody = res.getBody();
                
                // Check if the response is completely empty or just returns empty quotes
                if (String.isBlank(responseBody) || responseBody.trim() == '""') {
                    throw new CustomException('The API returned an empty response body.');
                }
                
                ResponseWrapper responseObj;
                try {
                    // Try to deserialize the JSON
                    responseObj = (ResponseWrapper) JSON.deserialize(responseBody, ResponseWrapper.class);
                } catch (JSONException e) {
                    // Catch malformed JSON errors specifically
                    throw new CustomException('No Serial Number Found Against The Invoice Number: ' + targetAsset.Invoice_Number__c);
                }
                
                String fetchedSerialNo = responseObj?.SERIAL_NUMBER?.item?.SERIAL_NUMBER;
                
                if (String.isNotBlank(fetchedSerialNo)) {
                    
                    // 6. Check for existing Asset Serial No record to prevent duplicates
                    List<Asset_Serial_No__c> existingRecords = [
                        SELECT Id 
                        FROM Asset_Serial_No__c 
                        WHERE Name = :fetchedSerialNo 
                        AND Asset__c = :assetId 
                        LIMIT 1
                    ];
                    
                    // 7. Prepare record for Upsert
                    Asset_Serial_No__c serialRecord = new Asset_Serial_No__c();
                    serialRecord.Name = fetchedSerialNo;
                    serialRecord.Asset__c = assetId; 
                    
                    // If it exists, set the Id to perform an update instead of an insert
                    if (!existingRecords.isEmpty()) {
                        serialRecord.Id = existingRecords[0].Id;
                    }
                    
                    // Upsert uses the Id if it's present, otherwise inserts a new record
                    upsert serialRecord;
                    
                    return 'Serial Number (' + fetchedSerialNo + ') fetched successfully.';
                } else {
                    throw new CustomException('Serial Number was not found in the API response.');
                }
            } else {
                throw new CustomException('API Callout failed. Status: ' + res.getStatus() + ' Code: ' + res.getStatusCode() + ' Body: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Custom Exception Class for better error handling visibility in LWC
    public class CustomException extends Exception {}

    // Wrapper classes to handle the specific JSON Response structure
    public class ResponseWrapper {
        public SerialNumberNode SERIAL_NUMBER;
    }
    public class SerialNumberNode {
        public ItemNode item;
    }
    public class ItemNode {
        public String SERIAL_NUMBER;
    }
}
@RestResource(urlMapping='/WarrantyRequestFile/Create')
global with sharing class ctrl_warrantyRequestFileAPI {

    @HttpPost
    global static ApiResponse createWarrantyRequest() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        ApiResponse response = new ApiResponse();
        Savepoint sp = Database.setSavepoint();

        try {
            if (req == null || req.requestBody == null || String.isBlank(req.requestBody.toString())) {
                res.statusCode = 400;
                response.success = false;
                response.statusCode = 400;
                response.message = 'Request body is missing.';
                response.errorCode = 'ERR_400_INVALID_REQUEST';
                return response;
            }

            warrantyRequestParameters parameters =
                (warrantyRequestParameters) JSON.deserialize(
                    req.requestBody.toString(),
                    warrantyRequestParameters.class
                );

            if (parameters == null || String.isBlank(parameters.serialNumber)) {
                res.statusCode = 400;
                response.success = false;
                response.statusCode = 400;
                response.message = 'Please enter serial number.';
                response.errorCode = 'ERR_400_SERIAL_NO_MISSING';
                return response;
            }

            List<Warranty_Request__c> existingList = [
                SELECT Id, Name, Serial_Number__c
                FROM Warranty_Request__c
                WHERE Serial_Number__c = :parameters.serialNumber
                LIMIT 1
            ];

            if (!existingList.isEmpty()) {
                res.statusCode = 409;
                response.success = false;
                response.statusCode = 409;
                response.message = 'Warranty Request already exists for this serial number.';
                response.errorCode = 'ERR_409_DUPLICATE_SERIAL_NO';
                response.recordId = existingList[0].Id;
                response.warrantyRequestNo = existingList[0].Name;
                response.serialNumber = existingList[0].Serial_Number__c;
                return response;
            }

            Warranty_Request__c wrToInsert = new Warranty_Request__c();
            wrToInsert.Address__c           = parameters.address;
            wrToInsert.Customer_Name__c     = parameters.customerName;
            wrToInsert.Mobile_No__c         = parameters.mobileNumber;
            wrToInsert.Email__c             = parameters.emailId;
            wrToInsert.City__c              = parameters.city;
            wrToInsert.State__c             = parameters.state;
            wrToInsert.Invoice_number__c    = parameters.invNumber;
            wrToInsert.Invoice_Date__c      = parameters.invDate;
            wrToInsert.Product_Model__c     = parameters.productModel;
            wrToInsert.Serial_Number__c     = parameters.serialNumber;
            wrToInsert.Qty__c               = parameters.qty;
            wrToInsert.Dealer_Name__c       = parameters.dealerName;
            wrToInsert.Dealer_Address__c    = parameters.dealerAddress;
            wrToInsert.Status__c            = 'Draft';

            insert wrToInsert;

            Integer uploadedFileCount = 0;
            List<String> uploadedFileNames = new List<String>();

            if (parameters.files != null && !parameters.files.isEmpty()) {
                FileSaveResult fileResult = saveFilesOnRecord(parameters.files, wrToInsert.Id);
                uploadedFileCount = fileResult.fileCount;
                uploadedFileNames = fileResult.fileNames;
            }

            Warranty_Request__c savedWR = [
                SELECT Id, Name, Serial_Number__c, Customer_Name__c
                FROM Warranty_Request__c
                WHERE Id = :wrToInsert.Id
                LIMIT 1
            ];

            res.statusCode = 201;
            response.success = true;
            response.statusCode = 201;
            response.message = 'Warranty Request Record Successfully Created.';
            response.errorCode = null;
            response.recordId = savedWR.Id;
            response.warrantyRequestNo = savedWR.Name;
            response.serialNumber = savedWR.Serial_Number__c;
            response.customerName = savedWR.Customer_Name__c;
            response.filesUploaded = uploadedFileCount;
            response.fileNames = uploadedFileNames;

            return response;
        }
        catch (System.JSONException e) {
            Database.rollback(sp);
            res.statusCode = 400;
            response.success = false;
            response.statusCode = 400;
            response.message = 'Invalid JSON payload.';
            response.errorCode = 'ERR_400_INVALID_JSON';
            response.debugMessage = e.getMessage();
            return response;
        }
        catch (Exception e) {
            Database.rollback(sp);
            res.statusCode = 500;
            response.success = false;
            response.statusCode = 500;
            response.message = 'Unexpected server error.';
            response.errorCode = 'ERR_500_SERVER_ERROR';
            response.debugMessage = e.getMessage();
            return response;
        }
    }

    private static FileSaveResult saveFilesOnRecord(List<FileWrapper> files, Id parentRecordId) {
        FileSaveResult result = new FileSaveResult();
        result.fileCount = 0;
        result.fileNames = new List<String>();

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();

        for (FileWrapper fileObj : files) {
            if (fileObj == null || String.isBlank(fileObj.base64Data)) {
                continue;
            }

            String finalFileName = String.isBlank(fileObj.fileName)
                ? 'Warranty_File_' + String.valueOf(Datetime.now().getTime()) + '.bin'
                : fileObj.fileName;

            ContentVersion cv = new ContentVersion();
            cv.Title = getFileTitle(finalFileName);
            cv.PathOnClient = '/' + finalFileName;
            cv.VersionData = EncodingUtil.base64Decode(fileObj.base64Data);

            versionsToInsert.add(cv);
            result.fileNames.add(finalFileName);
        }

        if (versionsToInsert.isEmpty()) {
            return result;
        }

        insert versionsToInsert;

        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : versionsToInsert) {
            versionIds.add(cv.Id);
        }

        List<ContentVersion> insertedVersions = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versionIds
        ];

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (ContentVersion cv : insertedVersions) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = parentRecordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            linksToInsert.add(cdl);
        }

        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
        }

        result.fileCount = linksToInsert.size();
        return result;
    }

    private static String getFileTitle(String fileName) {
        if (String.isBlank(fileName)) {
            return 'Warranty_File';
        }

        Integer dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
            return fileName.substring(0, dotIndex);
        }
        return fileName;
    }

    global class warrantyRequestParameters {
        //global String batchNumber;
        global String customerName;
        global String emailId;
        global String mobileNumber;
        global String address;
        global String city;
        global String state;
        global String productModel;
        global Decimal qty;
        global String serialNumber;
        //global String installationDate;
        //global String installerType;
        global String invNumber;
        global String invDate;
        global String dealerName;
        global String dealerAddress;
                
        global List<FileWrapper> files;
    }

    global class FileWrapper {
        global String fileName;
        global String contentType;
        global String base64Data;
    }

    global class ApiResponse {
        global Boolean success;
        global Integer statusCode;
        global String message;
        global String errorCode;
        global String debugMessage;
        global String recordId;
        global String warrantyRequestNo;
        global String serialNumber;
        global String customerName;
        global Integer filesUploaded;
        global List<String> fileNames;
    }

    global class FileSaveResult {
        global Integer fileCount;
        global List<String> fileNames;
    }
}
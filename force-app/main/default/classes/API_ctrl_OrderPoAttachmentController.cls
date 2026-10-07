public with sharing class API_ctrl_OrderPoAttachmentController {

    private static final String ENDPOINT = 'callout:NC_SAP_API/http/poAttach';
    private static final Integer TIMEOUT_MS = 120000;
    private static final Integer MAX_FILE_SIZE_BYTES = 4000000;

    public class SapPoAttachmentResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String dmsDocumentNo;
        @AuraEnabled public String statusCode;
        @AuraEnabled public String fileName;
        @AuraEnabled public String soDescription;
        @AuraEnabled public String soNumber;
    }

    @AuraEnabled
    public static SapPoAttachmentResponse uploadPoToSap(Id orderId, Id contentDocumentId) {
        String requestLog = null;
        String responseBody = null;
        Integer statusCode = null;

        try {
            if (orderId == null) {
                throw new AuraHandledException('Order Id is required.');
            }

            if (contentDocumentId == null) {
                throw new AuraHandledException('Uploaded file Id is required.');
            }

            Order ord = [
                SELECT Id, SAP_Order_ID__c
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            if (String.isBlank(ord.SAP_Order_ID__c)) {
                throw new AuraHandledException('SAP Order Id is blank on this Order.');
            }

            ContentVersion cv = [
                SELECT Id, Title, FileExtension, ContentDocumentId, VersionData, ContentSize
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true
                LIMIT 1
            ];

            if (cv.ContentSize != null && cv.ContentSize > MAX_FILE_SIZE_BYTES) {
                throw new AuraHandledException(
                    'File size is too large for SAP upload. Please upload a file below 4 MB.'
                );
            }

            String sapSoNumber = ord.SAP_Order_ID__c;
            String soDescription = 'SO NUMBER ' + sapSoNumber;

            String fileBase64 = EncodingUtil.base64Encode(cv.VersionData);

            // This will always send file name without extension.
            String fileNameWithoutExtension = getFileNameWithoutExtension(cv.Title, cv.FileExtension);

            // As per your SAP sample, MIME_TYPE expects PDF, not application/pdf.
            String mimeType = String.isNotBlank(cv.FileExtension)
                ? cv.FileExtension.toUpperCase()
                : 'PDF';

            String requestBody =
                '<n0:ZRFC_PO_ATTACH xmlns:n0="urn:sap-com:document:sap:rfc:functions">' +
                    '<FILE_CONTENT>' + fileBase64 + '</FILE_CONTENT>' +
                    '<DESCRIPTION>' + escapeXmlText(soDescription) + '</DESCRIPTION>' +
                    '<FILE_NAME>' + escapeXmlText(fileNameWithoutExtension) + '</FILE_NAME>' +
                    '<MIME_TYPE>' + escapeXmlText(mimeType) + '</MIME_TYPE>' +
                    '<SO>' + escapeXmlText(sapSoNumber) + '</SO>' +
                '</n0:ZRFC_PO_ATTACH>';

            requestLog =
                'OrderId=' + String.valueOf(orderId) +
                ', SAP_Order_ID__c=' + sapSoNumber +
                ', ContentDocumentId=' + String.valueOf(contentDocumentId) +
                ', FILE_NAME=' + fileNameWithoutExtension +
                ', MIME_TYPE=' + mimeType +
                ', DESCRIPTION=' + soDescription +
                ', SO=' + sapSoNumber;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/xml');
            req.setTimeout(TIMEOUT_MS);
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            statusCode = res.getStatusCode();
            responseBody = res.getBody();

            if (statusCode < 200 || statusCode >= 300) {
                logIntegrationError(
                    'SAP PO Attachment API',
                    String.valueOf(statusCode),
                    'Non-success response from SAP PO Attachment API',
                    'POST',
                    requestLog,
                    ENDPOINT,
                    'SAP',
                    responseBody,
                    String.valueOf(statusCode)
                );

                throw new AuraHandledException(
                    'SAP upload failed. Status Code: ' + String.valueOf(statusCode)
                );
            }

            SapPoAttachmentResponse output = new SapPoAttachmentResponse();
            output.success = true;
            output.statusCode = String.valueOf(statusCode);
            output.message = getXmlNodeValue(responseBody, 'MESSAGE');
            output.dmsDocumentNo = getXmlNodeValue(responseBody, 'DMS_DOCUMENT_NO');
            output.fileName = fileNameWithoutExtension;
            output.soDescription = soDescription;
            output.soNumber = sapSoNumber;

            if (String.isBlank(output.message)) {
                output.message = 'PO document uploaded to SAP successfully.';
            }

            return output;

        } catch (AuraHandledException ahe) {
            throw ahe;

        } catch (Exception e) {
            logIntegrationError(
                'SAP PO Attachment API',
                null,
                e.getMessage(),
                'POST',
                requestLog,
                ENDPOINT,
                'SAP',
                e.getStackTraceString() + '\n\nSAP Response:\n' + responseBody,
                statusCode != null ? String.valueOf(statusCode) : null
            );

            throw new AuraHandledException('Error while uploading PO document to SAP: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void removeUploadedFile(Id orderId, Id contentDocumentId) {
        try {
            if (orderId == null) {
                throw new AuraHandledException('Order Id is required.');
            }

            if (contentDocumentId == null) {
                throw new AuraHandledException('File Id is required.');
            }

            List<ContentDocumentLink> links = [
                SELECT Id, ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
                AND LinkedEntityId = :orderId
            ];

            if (links.isEmpty()) {
                throw new AuraHandledException('This file is not attached to the current Order.');
            }

            delete links;

            Integer remainingLinks = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentDocumentId
            ];

            if (remainingLinks == 0) {
                delete [
                    SELECT Id
                    FROM ContentDocument
                    WHERE Id = :contentDocumentId
                    LIMIT 1
                ];
            }

        } catch (AuraHandledException ahe) {
            throw ahe;

        } catch (Exception e) {
            throw new AuraHandledException('Unable to remove selected file: ' + e.getMessage());
        }
    }

    private static String getFileNameWithoutExtension(String title, String extension) {
        if (String.isBlank(title)) {
            return 'PO_ATTACHMENT';
        }

        String cleanTitle = title.trim();

        if (String.isBlank(extension)) {
            Integer lastDotIndex = cleanTitle.lastIndexOf('.');
            if (lastDotIndex > 0) {
                return cleanTitle.substring(0, lastDotIndex);
            }
            return cleanTitle;
        }

        String dotExtension = '.' + extension;

        if (cleanTitle.toLowerCase().endsWith(dotExtension.toLowerCase())) {
            return cleanTitle.substring(0, cleanTitle.length() - dotExtension.length());
        }

        return cleanTitle;
    }

    private static String escapeXmlText(String input) {
        if (input == null) {
            return '';
        }

        return input
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;');
    }

    private static String getXmlNodeValue(String xmlBody, String nodeName) {
        try {
            if (String.isBlank(xmlBody) || String.isBlank(nodeName)) {
                return null;
            }

            Dom.Document doc = new Dom.Document();
            doc.load(xmlBody);

            return findNodeValue(doc.getRootElement(), nodeName);

        } catch (Exception e) {
            return null;
        }
    }

    private static String findNodeValue(Dom.XmlNode node, String nodeName) {
        if (node == null) {
            return null;
        }

        if (node.getName() == nodeName) {
            return node.getText();
        }

        for (Dom.XmlNode child : node.getChildElements()) {
            String result = findNodeValue(child, nodeName);
            if (result != null) {
                return result;
            }
        }

        return null;
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

            if (String.isNotBlank(statusCode)) {
                logRec.Status_Code__c = Decimal.valueOf(statusCode);
            }

            insert logRec;

        } catch (Exception ex) {
            System.debug('Failed to insert Integration_Error_Log__c: ' + ex.getMessage());
        }
    }
}
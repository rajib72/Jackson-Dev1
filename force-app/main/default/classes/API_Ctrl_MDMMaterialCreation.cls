public with sharing class API_Ctrl_MDMMaterialCreation {

    private static final String MATERIAL_TYPE = 'FG';

    @AuraEnabled
    public static List<OpportunityLineItem> getOpportunityProducts(Id opportunityId) {
        return [
            SELECT Id,
                   Name,
                   Material_Type__c,
                   Material_Description__c,
                   Tried_To_Tag_Material_Master__c,
                   Sent_To_MDM__c,
                   Material_Master__c
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
        ];
    }

    @AuraEnabled
    public static String createMaterialDrafts(List<Map<String, String>> materials) {
        String endpoint = '';
        String finalResult = 'Success';
        List<OpportunityLineItem> olisToUpdate = new List<OpportunityLineItem>();

        try {
            endpoint = System.Label.MDM_Domain_URL;

            HttpRequest authReq = new HttpRequest();
            authReq.setEndpoint(endpoint + '/login');
            authReq.setMethod('POST');
            authReq.setHeader('Content-Type', 'application/json');

            Map<String, String> authBody = new Map<String, String>{
                'UserId' => System.Label.MDM_UserId,
                'Password' => System.Label.MDM_Password
            };

            authReq.setBody(JSON.serialize(authBody));

            Http http = new Http();
            HttpResponse authRes = http.send(authReq);

            if (authRes.getStatusCode() != 200) {
                String errMsg = 'Error: Authentication request failed. ' + authRes.getBody();

                logIntegrationError(
                    'MDM Login',
                    'HTTP_ERROR',
                    errMsg,
                    'POST',
                    authReq.getBody(),
                    authReq.getEndpoint(),
                    'Salesforce',
                    null,
                    authRes.getStatusCode()
                );

                return errMsg;
            }

            Map<String, Object> authResponseMap =
                (Map<String, Object>) JSON.deserializeUntyped(authRes.getBody());

            Boolean authStatus = (Boolean) authResponseMap.get('Status');

            if (authStatus != true) {
                String errMsg =
                    'Error: Authentication failed. ' +
                    String.valueOf(authResponseMap.get('Message'));

                logIntegrationError(
                    'MDM Login',
                    'API_ERROR',
                    errMsg,
                    'POST',
                    authReq.getBody(),
                    authReq.getEndpoint(),
                    'Salesforce',
                    null,
                    authRes.getStatusCode()
                );

                return errMsg;
            }

            String token = (String) authResponseMap.get('Token');

            for (Map<String, String> mat : materials) {
                HttpRequest draftReq = new HttpRequest();
                draftReq.setEndpoint(endpoint + '/CreateMaterialDraft');
                draftReq.setMethod('POST');
                draftReq.setHeader('Authorization', 'Bearer ' + token);
                draftReq.setHeader('Content-Type', 'application/json');

                Map<String, String> draftBody = new Map<String, String>{
                    'MaterialType' => MATERIAL_TYPE,
                    'Material_Desc' => mat.get('Material_Desc')
                };

                draftReq.setBody(JSON.serialize(draftBody));

                HttpResponse draftRes = http.send(draftReq);

                Map<String, Object> draftResponseMap =
                    (Map<String, Object>) JSON.deserializeUntyped(draftRes.getBody());

                if (draftRes.getStatusCode() != 200) {
                    String errMsg =
                        'Error creating draft for ' +
                        mat.get('Material_Desc') +
                        ' : ' +
                        String.valueOf(draftResponseMap.get('Message'));

                    logIntegrationError(
                        'MDM CreateMaterialDraft',
                        'HTTP_ERROR',
                        errMsg,
                        'POST',
                        draftReq.getBody(),
                        draftReq.getEndpoint(),
                        'Salesforce',
                        null,
                        draftRes.getStatusCode()
                    );

                    finalResult = errMsg;
                    break;
                }

                Boolean draftStatus = (Boolean) draftResponseMap.get('Status');

                if (draftStatus != true) {
                    String errMsg =
                        'Error from MDM for ' +
                        mat.get('Material_Desc') +
                        ': ' +
                        String.valueOf(draftResponseMap.get('Message'));

                    logIntegrationError(
                        'MDM CreateMaterialDraft',
                        'API_ERROR',
                        errMsg,
                        'POST',
                        draftReq.getBody(),
                        draftReq.getEndpoint(),
                        'Salesforce',
                        null,
                        draftRes.getStatusCode()
                    );

                    finalResult = errMsg;
                    break;
                }

                olisToUpdate.add(
                    new OpportunityLineItem(
                        Id = mat.get('Id'),
                        Material_Type__c = MATERIAL_TYPE,
                        Sent_To_MDM__c = true
                    )
                );
            }

        } catch (Exception e) {
            String errMsg = 'Exception: ' + e.getMessage();

            logIntegrationError(
                'MDM Integration',
                'EXCEPTION',
                errMsg,
                'POST',
                JSON.serialize(materials),
                endpoint,
                'Salesforce',
                e.getStackTraceString(),
                null
            );

            finalResult = errMsg;
        }

        if (!olisToUpdate.isEmpty()) {
            try {
                update olisToUpdate;
            } catch (Exception ex) {
                System.debug('Failed to update SF records: ' + ex.getMessage());
            }
        }

        return finalResult;
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
        Integer statusCode
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

            if (statusCode != null) {
                logRec.Status_Code__c = Decimal.valueOf(statusCode);
            }

            insert logRec;

        } catch (Exception e) {
            System.debug(
                '===== INTEGRATION ERROR LOG INSERT FAILED ===== ' +
                e.getMessage()
            );
        }
    }
}
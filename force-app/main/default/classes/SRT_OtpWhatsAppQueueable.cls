public with sharing class SRT_OtpWhatsAppQueueable
    implements Queueable, Database.AllowsCallouts {

    private Id caseId;
    private Id logId;

    public SRT_OtpWhatsAppQueueable(
        Id caseId,
        Id logId
    ) {
        this.caseId = caseId;
        this.logId = logId;
    }

    public void execute(QueueableContext context) {

        Integer httpStatus;
        String messageId;
        String status = 'Unknown';
        String failureReason;

        try {

            Case c = [
                SELECT Id, OTP__c,
                       OTP_Expiry_Date_Time__c,
                       OTP_Verified__c,
                       SRT_Case_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            Whatsapp_Messages__c logRec = [
                SELECT Id, Recipient_Number__c,
                       Campaign_Name__c, Status__c
                FROM Whatsapp_Messages__c
                WHERE Id = :logId
                LIMIT 1
            ];

            if (logRec.Status__c != 'Pending') {
                return;
            }

            if (String.isBlank(c.OTP__c) ||
                c.OTP_Verified__c == true ||
                c.OTP_Expiry_Date_Time__c == null ||
                c.OTP_Expiry_Date_Time__c <= System.now() ||
                c.SRT_Case_Status__c != 'Happy Code Pending') {

                status = 'Failed';
                failureReason =
                    'OTP is expired, verified or unavailable.';

            } else if (
                String.isBlank(logRec.Recipient_Number__c) ||
                logRec.Campaign_Name__c != 'Otpequest'
            ) {

                status = 'Failed';
                failureReason =
                    'Invalid WhatsApp recipient or campaign.';

            } else {

                Map<String, Object> body =
                    new Map<String, Object>{

                        'apiKey' =>
                            '{!$Credential.Go2Market_External.ApiKey}',

                        'campaignName' =>
                            'Otpequest',

                        'destination' =>
                            logRec.Recipient_Number__c,

                        'type' =>
                            'template',

                        'mediatype' =>
                            'OTP',

                        'templateParams' =>
                            new List<String>{ c.OTP__c }
                    };

                HttpRequest request = new HttpRequest();

                request.setEndpoint(
                    'callout:Go2Market/v2/api/clouds3/send'
                );

                request.setMethod('POST');

                request.setHeader(
                    'Content-Type',
                    'application/json'
                );

                request.setHeader(
                    'Accept',
                    'application/json'
                );

                request.setTimeout(30000);

                request.setBody(
                    JSON.serialize(body)
                );

                HttpResponse response =
                    new Http().send(request);

                httpStatus = response.getStatusCode();

                if (httpStatus >= 200 && httpStatus < 300) {

                    try {

                        Map<String, Object> responseBody =
                            (Map<String, Object>)
                            JSON.deserializeUntyped(
                                response.getBody()
                            );

                        if (responseBody != null &&
                            responseBody.get('MsgId') != null) {

                            messageId = String.valueOf(
                                responseBody.get('MsgId')
                            );
                        }

                        if (String.isNotBlank(messageId)) {

                            status = 'Accepted';

                        } else {

                            status = 'Unknown';
                            failureReason =
                                'HTTP success but no MsgId returned.';
                        }

                    } catch (Exception parseError) {

                        status = 'Unknown';
                        failureReason =
                            'Unable to parse provider response.';
                    }

                } else {

                    status = 'Failed';
                    failureReason =
                        'Go2Market returned HTTP ' +
                        httpStatus + '.';
                }
            }

        } catch (Exception e) {

            status = 'Unknown';
            failureReason =
                'WhatsApp processing error: ' +
                e.getMessage();
        }

        // All callouts finish before updating Salesforce.

        if (failureReason != null &&
            failureReason.length() > 32768) {

            failureReason =
                failureReason.substring(0, 32768);
        }

        Whatsapp_Messages__c updateRec =
            new Whatsapp_Messages__c(
                Id = logId,
                Status__c = status,
                HTTP_Status_Code__c = httpStatus,
                Message_Id__c = messageId,
                Failure_Reason__c = failureReason
            );

        if (status == 'Accepted') {
            updateRec.Accepted_At__c = System.now();
        }

        Database.SaveResult result =
            Database.update(updateRec, false);

        if (!result.isSuccess()) {

            System.debug(
                LoggingLevel.ERROR,
                'OTP WhatsApp log update failed: ' +
                result.getErrors()[0].getMessage()
            );
        }
    }
}
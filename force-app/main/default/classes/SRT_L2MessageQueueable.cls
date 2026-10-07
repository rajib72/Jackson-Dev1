public with sharing class SRT_L2MessageQueueable
    implements Queueable, Database.AllowsCallouts {

    private Id caseId;
    private String destination;
    private String campaignName;
    private List<String> templateParams;
    private Id logId;

    public SRT_L2MessageQueueable(
        Id caseId,
        String destination,
        String campaignName,
        List<String> templateParams,
        Id logId
    ) {
        this.caseId = caseId;
        this.destination = destination;
        this.campaignName = campaignName;
        this.templateParams = templateParams;
        this.logId = logId;
    }

    public void execute(QueueableContext context) {

        Integer httpStatus;
        String messageId;
        String status = 'Unknown';
        String failureReason;

        // Callout FIRST; updating Whatsapp_Messages__c comes afterwards.
        try {
            Map<String, Object> body = new Map<String, Object>{
                'apiKey' => '{!$Credential.Go2Market_External.ApiKey}',
                'campaignName' => campaignName,
                'destination' => destination,
                'type' => 'template',
                'mediatype' => 'TEXT',
                'templateParams' => templateParams
            };

            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:Go2Market/v2/api/clouds3/send');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/json');
            request.setTimeout(30000);
            request.setBody(JSON.serialize(body));

            HttpResponse response = new Http().send(request);
            httpStatus = response.getStatusCode();

            if (httpStatus >= 200 && httpStatus < 300) {
                try {
                    Map<String, Object> responseBody =
                        (Map<String, Object>) JSON.deserializeUntyped(
                            response.getBody()
                        );

                    if (responseBody != null &&
                        responseBody.get('MsgId') != null) {
                        messageId =
                            String.valueOf(responseBody.get('MsgId'));
                    }

                    if (String.isNotBlank(messageId)) {
                        status = 'Accepted';
                    } else {
                        failureReason =
                            'HTTP success, but Go2Market did not return MsgId.';
                    }
                } catch (Exception parseError) {
                    failureReason =
                        'HTTP success, but Go2Market response could not be parsed.';
                }
            } else {
                status = 'Failed';
                failureReason =
                    'Go2Market returned HTTP ' + httpStatus + '.';
            }

        } catch (Exception calloutError) {
            // A timeout is ambiguous: the provider might have accepted it.
            status = 'Unknown';
            failureReason = 'Go2Market callout error: ' +
                calloutError.getMessage();
        }

        // Persist the provider acknowledgement against THIS recipient.
        // Accepted != Delivered; delivery needs the provider status API.
        Whatsapp_Messages__c logUpdate =
            new Whatsapp_Messages__c(Id = logId);
        logUpdate.Status__c = status;
        logUpdate.Message_Id__c = messageId;
        logUpdate.HTTP_Status_Code__c = httpStatus;
        logUpdate.Failure_Reason__c = truncate(failureReason);

        if (status == 'Accepted') {
            logUpdate.Accepted_At__c = System.now();
        }

        update logUpdate;

        System.debug(
            LoggingLevel.INFO,
            'L2 WhatsApp API result. Case=' + caseId +
            ', Campaign=' + campaignName +
            ', HTTP=' + httpStatus +
            ', Status=' + status +
            ', LogId=' + logId +
            ', MessageId=' + messageId
        );
    }

    private static String truncate(String value) {
        if (value == null) return null;
        return value.length() > 32768 ? value.substring(0, 32768) : value;
    }
}
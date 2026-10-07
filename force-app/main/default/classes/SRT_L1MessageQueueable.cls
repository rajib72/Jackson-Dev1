public with sharing class SRT_L1MessageQueueable
    implements Queueable, Database.AllowsCallouts {

    private Id caseId;
    private String destination;
    private List<String> templateParams;
    private Id logId;


    /* =========================================================
       EXISTING CONSTRUCTOR
       Maintained for backward compatibility.
       ========================================================= */

    public SRT_L1MessageQueueable(
        Id caseId,
        String destination,
        List<String> templateParams
    ) {

        this.caseId = caseId;
        this.destination = destination;
        this.templateParams = templateParams;
        this.logId = null;
    }


    /* =========================================================
       NEW CONSTRUCTOR WITH WHATSAPP LOG ID
       ========================================================= */

    public SRT_L1MessageQueueable(
        Id caseId,
        String destination,
        List<String> templateParams,
        Id logId
    ) {

        this.caseId = caseId;
        this.destination = destination;
        this.templateParams = templateParams;
        this.logId = logId;
    }


    /* =========================================================
       EXECUTE QUEUEABLE
       ========================================================= */

    public void execute(QueueableContext context) {

        Integer httpStatusCode;
        String messageId;

        String messageStatus = 'Unknown';
        String failureReason;

        try {

            /* =============================================
               PREPARE API BODY
               ============================================= */

            Map<String, Object> body =
                new Map<String, Object>{

                    'apiKey' =>
                        '{!$Credential.Go2Market_External.ApiKey}',

                    'campaignName' =>
                        'Request',

                    'destination' =>
                        destination,

                    'type' =>
                        'template',

                    'mediatype' =>
                        'TEXT',

                    'templateParams' =>
                        templateParams
                };


            /* =============================================
               PREPARE HTTP REQUEST
               ============================================= */

            HttpRequest request =
                new HttpRequest();

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


            /* =============================================
               EXECUTE API CALLOUT
               ============================================= */

            HttpResponse response =
                new Http().send(request);

            httpStatusCode =
                response.getStatusCode();


            /* =============================================
               PROCESS API RESPONSE
               ============================================= */

            if (
                httpStatusCode >= 200 &&
                httpStatusCode < 300
            ) {

                try {

                    Map<String, Object> responseBody =
                        (Map<String, Object>)
                        JSON.deserializeUntyped(
                            response.getBody()
                        );

                    if (
                        responseBody != null &&
                        responseBody.containsKey('MsgId') &&
                        responseBody.get('MsgId') != null
                    ) {

                        messageId = String.valueOf(
                            responseBody.get('MsgId')
                        );
                    }

                    if (String.isNotBlank(messageId)) {

                        messageStatus = 'Accepted';

                    } else {

                        messageStatus = 'Unknown';

                        failureReason =
                            'HTTP success received, but no MsgId was returned.';
                    }

                } catch (Exception parseException) {

                    messageStatus = 'Unknown';

                    failureReason =
                        'HTTP success received, but the response could not be parsed.';
                }

            } else {

                messageStatus = 'Failed';

                failureReason =
                    'Go2Market returned HTTP status ' +
                    httpStatusCode;
            }

        } catch (Exception calloutException) {

            /*
             * A timeout may occur even when the
             * provider has already accepted the message.
             *
             * Mark Unknown rather than assuming failure.
             */

            messageStatus = 'Unknown';

            failureReason =
                'Callout exception: ' +
                calloutException.getMessage();
        }


        /* =========================================================
           UPDATE WHATSAPP MESSAGE LOG
           ========================================================= */

        if (logId != null) {

            Whatsapp_Messages__c logUpdate =
                new Whatsapp_Messages__c(
                    Id = logId
                );

            logUpdate.Status__c =
                messageStatus;

            logUpdate.HTTP_Status_Code__c =
                httpStatusCode;

            logUpdate.Message_Id__c =
                messageId;

            logUpdate.Failure_Reason__c =
                failureReason;

            if (messageStatus == 'Accepted') {

                logUpdate.Accepted_At__c =
                    System.now();
            }

            update logUpdate;
        }


        /* =========================================================
           DEBUG
           ========================================================= */

        System.debug(
            LoggingLevel.INFO,
            'L1 WhatsApp API Result. Case: ' +
            caseId +
            ', HTTP Status: ' +
            httpStatusCode +
            ', Message Status: ' +
            messageStatus +
            ', Message ID: ' +
            messageId
        );
    }
}
/**
 * Go2Market complaint-registration notification (dearcustomer01).
 * Runs AFTER the Case-creation transaction commits. Never marks HTTP 200
 * alone as delivered. Performs the callout BEFORE updating Salesforce logs.
 */
public with sharing class SRT_RegistrationWhatsAppQueueable
    implements Queueable, Database.AllowsCallouts {

    private Id caseId;
    private String destination;
    private String serviceRequestNumber;
    private Id logId;

    public SRT_RegistrationWhatsAppQueueable(
        Id caseId,
        String destination,
        String serviceRequestNumber,
        Id logId
    ) {
        this.caseId = caseId;
        this.destination = destination;
        this.serviceRequestNumber = serviceRequestNumber;
        this.logId = logId;
    }

    public void execute(QueueableContext context) {
        Integer httpStatusCode;
        String messageId;
        String status = 'Unknown';
        String failureReason;

        if (String.isBlank(destination) ||
            String.isBlank(serviceRequestNumber)) {
            status = 'Failed';
            failureReason = 'Recipient or Service Request number is missing.';
        } else {
            try {
                Map<String, Object> body = new Map<String, Object>{
                    // Requires the configured External Credential body formula.
                    'apiKey' => '{!$Credential.Go2Market_External.ApiKey}',
                    'campaignName' => 'customer_registered',
                    'destination' => destination,
                    'type' => 'template',
                    'mediatype' => 'TEXT',
                    'templateParams' => new List<String>{ serviceRequestNumber }
                };

                HttpRequest request = new HttpRequest();
                request.setEndpoint('callout:Go2Market/v2/api/clouds3/send');
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('Accept', 'application/json');
                request.setTimeout(30000);
                request.setBody(JSON.serialize(body));

                HttpResponse response = new Http().send(request);
                httpStatusCode = response.getStatusCode();

                if (httpStatusCode >= 200 && httpStatusCode < 300) {
                    try {
                        Map<String, Object> responseBody =
                            (Map<String, Object>) JSON.deserializeUntyped(
                                response.getBody()
                            );
                        if (responseBody != null &&
                            responseBody.get('MsgId') != null) {
                            messageId = String.valueOf(responseBody.get('MsgId'));
                        }
                        if (String.isNotBlank(messageId)) {
                            status = 'Accepted';
                        } else {
                            failureReason =
                                'HTTP success, but Go2Market returned no MsgId.';
                        }
                    } catch (Exception parsingError) {
                        failureReason =
                            'HTTP success, but the Go2Market response could not be parsed.';
                    }
                } else {
                    status = 'Failed';
                    failureReason =
                        'Go2Market returned HTTP ' + httpStatusCode + '.';
                }
            } catch (Exception calloutError) {
                // A timeout may occur after provider acceptance: status is unknown.
                status = 'Unknown';
                failureReason =
                    'Go2Market callout error: ' + calloutError.getMessage();
            }
        }

        // DML is intentionally AFTER the HTTP request to avoid an
        // "uncommitted work pending" callout error in this transaction.
        if (logId != null) {
            Whatsapp_Messages__c updateRec = new Whatsapp_Messages__c(
                Id = logId,
                Status__c = status,
                HTTP_Status_Code__c = httpStatusCode,
                Message_Id__c = messageId,
                Failure_Reason__c = truncate(failureReason)
            );
            if (status == 'Accepted') {
                updateRec.Accepted_At__c = System.now();
            }

            Database.SaveResult result = Database.update(updateRec, false);
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR,
                    'Registration WhatsApp log update failed. Log=' +
                    logId + ': ' + result.getErrors()[0].getMessage());
            }
        }

        System.debug(LoggingLevel.INFO,
            'Registration WhatsApp API result. Case=' + caseId +
            ', Log=' + logId + ', HTTP=' + httpStatusCode +
            ', Status=' + status + ', MsgId=' + messageId);
    }

    private static String truncate(String value) {
        if (value == null) return null;
        return value.length() > 32768 ? value.substring(0, 32768) : value;
    }
}
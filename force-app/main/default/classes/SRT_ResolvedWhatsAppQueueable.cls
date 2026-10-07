/**
 * Sends Complaint Resolved notifications through Go2Market.
 * IMPORTANT: Perform ALL HTTP callouts before updating message logs,
 * avoiding the Salesforce 'uncommitted work pending' error.
 */
public with sharing class SRT_ResolvedWhatsAppQueueable
    implements Queueable, Database.AllowsCallouts {

    private List<Id> logIds;

    public SRT_ResolvedWhatsAppQueueable(List<Id> logIds) {
        this.logIds = logIds == null ? new List<Id>() : new List<Id>(logIds);
    }

    public void execute(QueueableContext context) {
        if (logIds.isEmpty()) return;

        List<Whatsapp_Messages__c> pendingLogs = [
            SELECT Id, Case__c, Recipient_Number__c,
                   Campaign_Name__c, Message__c, Status__c
            FROM Whatsapp_Messages__c
            WHERE Id IN :logIds
              AND Status__c = 'Pending'
            ORDER BY CreatedDate ASC
        ];

        List<Whatsapp_Messages__c> updates = new List<Whatsapp_Messages__c>();

        for (Whatsapp_Messages__c logRec : pendingLogs) {
            Integer httpStatus;
            String messageId;
            String status = 'Unknown';
            String failureReason;
            String srNo;

            // Validate the stored payload before attempting any callout.
            try {
                Map<String, Object> stored =
                    (Map<String, Object>) JSON.deserializeUntyped(logRec.Message__c);
                List<Object> storedParams =
                    (List<Object>) stored.get('templateParams');
                if (storedParams != null && storedParams.size() == 1 &&
                    storedParams[0] != null) {
                    srNo = String.valueOf(storedParams[0]);
                }
            } catch (Exception parseError) {
                failureReason = 'Invalid stored WhatsApp template parameters.';
            }

            if (String.isBlank(srNo) ||
                String.isBlank(logRec.Recipient_Number__c) ||
                logRec.Campaign_Name__c != 'Customer_resolved') {
                status = 'Failed';
                failureReason = 'Invalid recipient, campaign or SR template parameter.';
            } else {
                try {
                    HttpRequest request = new HttpRequest();
                    request.setEndpoint('callout:Go2Market/v2/api/clouds3/send');
                    request.setMethod('POST');
                    request.setHeader('Content-Type', 'application/json');
                    request.setHeader('Accept', 'application/json');
                    request.setTimeout(30000);
                    request.setBody(JSON.serialize(new Map<String, Object>{
                        // Reuse the existing External Credential body formula.
                        'apiKey' => '{!$Credential.Go2Market_External.ApiKey}',
                        'campaignName' => 'Customer_resolved',
                        'destination' => logRec.Recipient_Number__c,
                        'type' => 'template',
                        'mediatype' => 'TEXT',
                        'templateParams' => new List<String>{srNo}
                    }));

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
                                messageId = String.valueOf(responseBody.get('MsgId'));
                            }
                            if (String.isNotBlank(messageId)) {
                                status = 'Accepted';
                            } else {
                                failureReason =
                                    'HTTP success, but Go2Market did not return a MsgId.';
                            }
                        } catch (Exception responseError) {
                            failureReason =
                                'HTTP success, but the provider response could not be parsed.';
                        }
                    } else {
                        status = 'Failed';
                        failureReason = 'Go2Market returned HTTP ' + httpStatus + '.';
                    }
                } catch (Exception calloutError) {
                    // Timeouts are ambiguous: do not claim definite failure.
                    status = 'Unknown';
                    failureReason = 'WhatsApp callout error: ' +
                        calloutError.getMessage();
                }
            }

            Whatsapp_Messages__c updateRec = new Whatsapp_Messages__c(
                Id = logRec.Id,
                Status__c = status,
                HTTP_Status_Code__c = httpStatus,
                Message_Id__c = messageId,
                Failure_Reason__c = truncate(failureReason)
            );
            if (status == 'Accepted') {
                updateRec.Accepted_At__c = System.now();
            }
            updates.add(updateRec);

            System.debug(LoggingLevel.INFO,
                'Resolved WhatsApp result: Case=' + logRec.Case__c +
                ', Log=' + logRec.Id + ', HTTP=' + httpStatus +
                ', Status=' + status + ', MsgId=' + messageId);
        }

        // All callouts are complete. DML now occurs once for this batch.
        if (!updates.isEmpty()) {
            Database.SaveResult[] results = Database.update(updates, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug(LoggingLevel.ERROR,
                        'Resolved WhatsApp log update failed for ' +
                        updates[i].Id + ': ' +
                        results[i].getErrors()[0].getMessage());
                }
            }
        }
    }

    private static String truncate(String value) {
        if (value == null) return null;
        return value.length() > 32768
            ? value.substring(0, 32768)
            : value;
    }
}
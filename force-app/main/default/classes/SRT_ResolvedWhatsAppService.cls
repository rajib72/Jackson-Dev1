/**
 * Called from the EXISTING Case trigger after update.
 * Sends only when SRT_Case_Status__c changes TO Resolved.
 * Logs each request on Whatsapp_Messages__c and queues Go2Market.
 * Does not require Flow, a button, or a second Case trigger.
 */
public with sharing class SRT_ResolvedWhatsAppService {

    private static final Integer MESSAGES_PER_JOB = 10;

    // Add one call in the existing Case trigger's after-update branch:
    // SRT_ResolvedWhatsAppService.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    public static void handleAfterUpdate(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap
    ) {
        if (newCases == null || newCases.isEmpty() ||
            oldCaseMap == null || oldCaseMap.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        for (Case newCase : newCases) {
            if (newCase == null || newCase.Id == null) continue;
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (oldCase != null &&
                newCase.SRT_Case_Status__c == 'Resolved' &&
                oldCase.SRT_Case_Status__c != 'Resolved') {
                caseIds.add(newCase.Id);
            }
        }
        if (caseIds.isEmpty()) return;

        createLogsAndQueue(caseIds);
    }

    private static void createLogsAndQueue(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) return;

        // The trigger detects the status transition. Recheck current status.
        Map<Id, Case> resolvedCases = new Map<Id, Case>([
            SELECT Id, CaseNumber, SRT_Case_No__c,
                   SRT_Case_Number__c, SRT_Case_Status__c,
                   ContactId, Contact.Phone
            FROM Case
            WHERE Id IN :caseIds
              AND SRT_Case_Status__c = 'Resolved'
        ]);

        List<Whatsapp_Messages__c> logs = new List<Whatsapp_Messages__c>();

        for (Id caseId : caseIds) {
            Case c = resolvedCases.get(caseId);
            if (c == null) continue;

            String srNo = String.isNotBlank(c.SRT_Case_No__c)
                ? c.SRT_Case_No__c.trim()
                : (String.isNotBlank(c.SRT_Case_Number__c)
                    ? c.SRT_Case_Number__c.trim()
                    : c.CaseNumber);
            if (!srNo.toUpperCase().startsWith('SR-')) {
                srNo = 'SR-' + srNo;
            }

            // Point 3: CUSTOMER recipient, specifically Case.Contact.Phone.
            // We do not use the Case owner, L1 User or L2 dealer's phone.
            String rawPhone = c.Contact == null ? null : c.Contact.Phone;
            String destination = normalizePhone(rawPhone);
            Boolean invalidPhone = destination == null;

            Whatsapp_Messages__c logRec = new Whatsapp_Messages__c();
            logRec.Case__c = c.Id;
            logRec.Campaign_Name__c = 'Customer_resolved';
            logRec.Recipient_Number__c = invalidPhone ? rawPhone : destination;
            logRec.Status__c = invalidPhone ? 'Failed' : 'Pending';
            logRec.Requested_At__c = System.now();

            // Store parameters sent to Go2Market, not an invented rendered
            // message. Never store the API key in the log.
            logRec.Message__c = JSON.serialize(new Map<String, Object>{
                'messageType' => 'Complaint Resolved',
                'campaignName' => 'Customer_resolved',
                'templateParams' => new List<String>{srNo}
            });

            if (invalidPhone) {
                logRec.Failure_Reason__c =
                    'Case.Contact.Phone is missing or not a valid 10-digit Indian mobile number.';
            }
            logs.add(logRec);
        }

        if (logs.isEmpty()) return;

        // A single invalid log must not prevent other Cases from sending.
        Database.SaveResult[] saved = Database.insert(logs, false);
        List<Id> pendingLogIds = new List<Id>();

        for (Integer i = 0; i < saved.size(); i++) {
            if (!saved[i].isSuccess()) {
                System.debug(LoggingLevel.ERROR,
                    'Resolved WhatsApp log creation failed for Case ' +
                    logs[i].Case__c + ': ' + saved[i].getErrors()[0].getMessage());
                continue;
            }
            if (logs[i].Status__c == 'Pending') {
                pendingLogIds.add(saved[i].getId());
            }
        }

        // Batch IDs to avoid one Queueable per Case and the 50-jobs-per-
        // transaction limit in ordinary bulk updates.
        for (Integer startIndex = 0;
             startIndex < pendingLogIds.size();
             startIndex += MESSAGES_PER_JOB) {

            List<Id> batchIds = new List<Id>();
            Integer endIndex = Math.min(
                startIndex + MESSAGES_PER_JOB,
                pendingLogIds.size()
            );
            for (Integer i = startIndex; i < endIndex; i++) {
                batchIds.add(pendingLogIds[i]);
            }

            try {
                System.enqueueJob(new SRT_ResolvedWhatsAppQueueable(batchIds));
            } catch (Exception enqueueError) {
                // Assignment/resolution must not be undone by a messaging
                // queue error. Record the failure for each affected message.
                List<Whatsapp_Messages__c> failedLogs =
                    new List<Whatsapp_Messages__c>();
                String reason = truncate(
                    'Could not enqueue resolved WhatsApp: ' +
                    enqueueError.getMessage()
                );
                for (Id logId : batchIds) {
                    failedLogs.add(new Whatsapp_Messages__c(
                        Id = logId,
                        Status__c = 'Failed',
                        Failure_Reason__c = reason
                    ));
                }
                Database.SaveResult[] failedUpdates =
                    Database.update(failedLogs, false);
                for (Database.SaveResult updateResult : failedUpdates) {
                    if (!updateResult.isSuccess()) {
                        System.debug(LoggingLevel.ERROR,
                            'Could not mark resolved WhatsApp log Failed: ' +
                            updateResult.getErrors()[0].getMessage());
                    }
                }
            }
        }
    }

    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return null;
        String digits = phone.replaceAll('[^0-9]', '');
        if (digits.length() == 14 && digits.startsWith('0091')) {
            digits = digits.substring(4);
        }
        if (digits.length() == 12 && digits.startsWith('91')) {
            digits = digits.substring(2);
        }
        if (digits.length() != 10 ||
            !Pattern.matches('[6-9][0-9]{9}', digits)) {
            return null;
        }
        return digits;
    }

    private static String truncate(String value) {
        if (value == null) return null;
        return value.length() > 32768
            ? value.substring(0, 32768)
            : value;
    }
}
/**
 * Complaint Registration (Point 1) - WhatsApp customer acknowledgement.
 * Called once by each of the two CaseCreationSearchController save methods,
 * after their Case/related records have been created.
 * Recipient: Case.Contact.Phone ONLY. Campaign: dearcustomer01.
 * The API key is never stored in Whatsapp_Messages__c.
 */
public with sharing class SRT_RegistrationWhatsAppService {

    public static String queueAfterCreate(Id caseId) {
        if (caseId == null) {
            return 'Registration WhatsApp not queued: Case Id is missing.';
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, SRT_Case_Number__c,
                   ContactId, Contact.Phone
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return 'Registration WhatsApp not queued: Case not found.';
        }

        Case c = cases[0];
        // This creation controller populates SRT_Case_Number__c (NOT SRT_Case_No__c).
        String srNo = String.isNotBlank(c.SRT_Case_Number__c)
            ? c.SRT_Case_Number__c.trim()
            : c.CaseNumber;
        if (String.isNotBlank(srNo) && !srNo.toUpperCase().startsWith('SR-')) {
            srNo = 'SR-' + srNo;
        }

        String rawPhone = c.Contact == null ? null : c.Contact.Phone;
        String destination = normalizePhone(rawPhone);
        String failureReason;
        if (c.ContactId == null) {
            failureReason = 'Case.ContactId is blank; no customer Contact is selected.';
        } else if (destination == null) {
            failureReason = 'Case.Contact.Phone is blank or not a valid 10-digit Indian mobile number.';
        } else if (String.isBlank(srNo)) {
            failureReason = 'Service Request number is missing.';
        }

        Whatsapp_Messages__c logRec = new Whatsapp_Messages__c();
        logRec.Case__c = c.Id;
        logRec.Campaign_Name__c = 'customer_registered';
        logRec.Recipient_Number__c = destination == null ? rawPhone : destination;
        logRec.Requested_At__c = System.now();
        logRec.Status__c = failureReason == null ? 'Pending' : 'Failed';
        logRec.Failure_Reason__c = failureReason;
        // Store exactly the one variable submitted to Go2Market.
        logRec.Message__c = JSON.serialize(new Map<String, Object>{
            'messageType' => 'Complaint Registration - Customer',
            'campaignName' => 'customer_registered',
            'templateParams' => new List<String>{ srNo }
        });

        // A logging failure must not cancel an otherwise successful Case save.
        try {
            insert logRec;
        } catch (Exception logError) {
            System.debug(LoggingLevel.ERROR,
                'Registration WhatsApp log creation failed for Case ' +
                c.Id + ': ' + logError.getMessage());
            return 'Registration WhatsApp not queued: could not create the message log.';
        }

        if (failureReason != null) {
            System.debug(LoggingLevel.WARN,
                'Registration WhatsApp skipped. Case=' + c.Id +
                ', Log=' + logRec.Id + ', Reason=' + failureReason);
            return 'Registration WhatsApp not queued: ' + failureReason;
        }

        try {
            Id jobId = System.enqueueJob(
                new SRT_RegistrationWhatsAppQueueable(
                    c.Id, destination, srNo, logRec.Id
                )
            );
            System.debug(LoggingLevel.INFO,
                'Registration WhatsApp queued. Case=' + c.Id +
                ', Log=' + logRec.Id + ', Job=' + jobId);
            return 'Registration WhatsApp queued. Job Id: ' + jobId;
        } catch (Exception queueError) {
            try {
                update new Whatsapp_Messages__c(
                    Id = logRec.Id,
                    Status__c = 'Failed',
                    Failure_Reason__c = truncate(
                        'Unable to enqueue registration WhatsApp: ' +
                        queueError.getMessage()
                    )
                );
            } catch (Exception updateError) {
                System.debug(LoggingLevel.ERROR,
                    'Registration WhatsApp log update failed. Log=' +
                    logRec.Id + ': ' + updateError.getMessage());
            }
            System.debug(LoggingLevel.ERROR,
                'Registration WhatsApp enqueue failed. Case=' + c.Id +
                ': ' + queueError.getMessage());
            return 'Registration WhatsApp not queued: Queueable error. Log: ' +
                logRec.Id;
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
        return Pattern.matches('[6-9][0-9]{9}', digits) ? digits : null;
    }

    @TestVisible
private static String truncate(String value) {

    if (value == null) {
        return null;
    }

    return value.length() > 32768
        ? value.substring(0, 32768)
        : value;
}
}
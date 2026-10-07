public with sharing class SRT_OtpWhatsAppService {

    public static String queueOtpMessage(Id caseId) {

        if (caseId == null) {
            return 'WhatsApp not queued: Case Id is missing.';
        }

        Case c = [
            SELECT Id, ContactId, Contact.Phone,
                   OTP__c, OTP_Expiry_Date_Time__c,
                   OTP_Verified__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (String.isBlank(c.OTP__c) ||
            c.OTP_Verified__c == true ||
            c.OTP_Expiry_Date_Time__c == null ||
            c.OTP_Expiry_Date_Time__c <= System.now()) {

            return 'WhatsApp not queued: No valid OTP available.';
        }

        String rawPhone = c.Contact == null
            ? null
            : c.Contact.Phone;

        String destination = normalizePhone(rawPhone);

        Whatsapp_Messages__c logRec =
            new Whatsapp_Messages__c();

        logRec.Case__c = caseId;
        logRec.Campaign_Name__c = 'Otpequest';
        logRec.Recipient_Number__c =
            destination == null ? rawPhone : destination;

        logRec.Requested_At__c = System.now();

        logRec.Status__c =
            destination == null ? 'Failed' : 'Pending';

        // Never store the actual OTP in the message log.
        logRec.Message__c = JSON.serialize(
            new Map<String, Object>{
                'messageType' => 'Customer OTP',
                'campaignName' => 'Otpequest',
                'templateParams' => new List<String>{'[REDACTED]'}
            }
        );

        if (destination == null) {
            logRec.Failure_Reason__c =
                'Contact.Phone is missing or invalid.';
        }

        try {
            insert logRec;
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'OTP WhatsApp log creation failed: ' +
                e.getMessage()
            );

            return 'WhatsApp not queued: Log creation failed.';
        }

        if (destination == null) {
            return 'WhatsApp not queued: Invalid Contact.Phone.';
        }

        try {

            System.enqueueJob(
                new SRT_OtpWhatsAppQueueable(
                    caseId,
                    logRec.Id
                )
            );

            return 'OTP WhatsApp queued successfully.';

        } catch (Exception e) {

            Database.update(
                new Whatsapp_Messages__c(
                    Id = logRec.Id,
                    Status__c = 'Failed',
                    Failure_Reason__c =
                        'Queue error: ' + e.getMessage()
                ),
                false
            );

            return 'WhatsApp not queued: Queue error.';
        }
    }

    private static String normalizePhone(String phone) {

        if (String.isBlank(phone)) {
            return null;
        }

        String digits = phone.replaceAll('[^0-9]', '');

        if (digits.length() == 14 &&
            digits.startsWith('0091')) {
            digits = digits.substring(4);
        }

        if (digits.length() == 12 &&
            digits.startsWith('91')) {
            digits = digits.substring(2);
        }

        return Pattern.matches(
            '[6-9][0-9]{9}',
            digits
        ) ? digits : null;
    }
}
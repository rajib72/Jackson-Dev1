public with sharing class FSROtpController {

    @AuraEnabled
    public static String generateAndSendOtp(Id fsrId) {
        if (fsrId == null) {
            throw new AuraHandledException('FSR record Id is required.');
        }

        Field_Service_Report_FSR__c fsr = [
            SELECT Id, Name, OTP__c, OTP_Expiry_Date_Time__c, Email_ID__c,OTP_Verified__c
            FROM Field_Service_Report_FSR__c
            WHERE Id = :fsrId
            LIMIT 1
        ];

        if (String.isBlank(fsr.Email_ID__c)) {
            throw new AuraHandledException('Email_ID__c is blank on this FSR record.');
        }
        
        if (fsr.OTP_Verified__c == true) {
            throw new AuraHandledException('OTP is already Verified.');
        }

        // Generate random 4-digit OTP
        Integer otpNumber = Math.round(Math.random() * 9000 + 1000);
        String otp = String.valueOf(otpNumber);

        // Expiry time = current time + 15 minutes
        Datetime expiryTime = System.now().addMinutes(15);

        // Update record
        fsr.OTP__c = otp;
        fsr.OTP_Expiry_Date_Time__c = expiryTime;
        update fsr;

        // Send email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ fsr.Email_ID__c });
        mail.setSubject('Your OTP for Field Service Report');
        mail.setPlainTextBody(
            'Dear User,\n\n' +
            'Your OTP is: ' + otp + '\n' +
            'This OTP is valid until: ' + String.valueOf(expiryTime) + '\n\n' +
            'Please do not share this OTP with anyone.\n\n' +
            'Regards,\n' +
            'Support Team'
        );

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { mail }
        );

        if (results == null || results.isEmpty() || !results[0].isSuccess()) {
            String errorMessage = 'OTP saved, but email sending failed.';
            if (results != null && !results.isEmpty() && results[0].getErrors() != null && !results[0].getErrors().isEmpty()) {
                errorMessage += ' ' + results[0].getErrors()[0].getMessage();
            }
            throw new AuraHandledException(errorMessage);
        }

        return 'OTP generated and sent successfully to ' + fsr.Email_ID__c;
    }
    
    @AuraEnabled
    public static String validateOtp(Id fsrId, String enteredOtp) {
        if (fsrId == null) {
            throw new AuraHandledException('FSR record Id is required.');
        }

        if (String.isBlank(enteredOtp)) {
            throw new AuraHandledException('Please enter OTP.');
        }

        Field_Service_Report_FSR__c fsr = [
            SELECT Id, Name, OTP__c, OTP_Expiry_Date_Time__c, OTP_Verified__c
            FROM Field_Service_Report_FSR__c
            WHERE Id = :fsrId
            LIMIT 1
        ];

        if (String.isBlank(fsr.OTP__c)) {
            throw new AuraHandledException('No OTP found on this record. Please generate OTP first.');
        }

        if (fsr.OTP_Expiry_Date_Time__c == null) {
            throw new AuraHandledException('OTP expiry time is missing.');
        }

        if (System.now() > fsr.OTP_Expiry_Date_Time__c) {
            throw new AuraHandledException('OTP has expired. Please generate a new OTP.');
        }

        if (fsr.OTP__c != enteredOtp.trim()) {
            throw new AuraHandledException('Invalid OTP.');
        }

        fsr.OTP_Verified__c = true;
        update fsr;

        return 'OTP verified successfully.';
    }
}
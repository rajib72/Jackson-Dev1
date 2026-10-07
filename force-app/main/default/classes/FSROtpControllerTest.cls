@IsTest
public class FSROtpControllerTest {

    private static WorkOrder createWorkOrder() {
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        WorkOrder wo = new WorkOrder(
            Subject = 'Test Work Order',
            AccountId = acc.Id,
            Status = 'New'
        );
        insert wo;

        return wo;
    }

    private static Field_Service_Report_FSR__c createFSR(String email, Boolean otpVerified) {
        WorkOrder wo = createWorkOrder();

        Field_Service_Report_FSR__c fsr = new Field_Service_Report_FSR__c();
        fsr.Work_Order__c = wo.Id;
        fsr.Email_ID__c = email;
        fsr.OTP_Verified__c = otpVerified;

        insert fsr;
        return fsr;
    }

    @IsTest
    static void testGenerateAndSendOtpSuccess() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        Test.startTest();
        String result = FSROtpController.generateAndSendOtp(fsr.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('OTP generated and sent successfully'));

        Field_Service_Report_FSR__c updatedFsr = [
            SELECT Id, OTP__c, OTP_Expiry_Date_Time__c, Email_ID__c, OTP_Verified__c
            FROM Field_Service_Report_FSR__c
            WHERE Id = :fsr.Id
            LIMIT 1
        ];

        System.assertNotEquals(null, updatedFsr.OTP__c);
        System.assertNotEquals(null, updatedFsr.OTP_Expiry_Date_Time__c);
        System.assertEquals(false, updatedFsr.OTP_Verified__c);
    }

    @IsTest
    static void testGenerateAndSendOtpBlankEmail() {
        Field_Service_Report_FSR__c fsr = createFSR(null, false);

        Test.startTest();
        try {
            FSROtpController.generateAndSendOtp(fsr.Id);
            System.assert(false, 'Exception should have been thrown for blank email.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGenerateAndSendOtpAlreadyVerified() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', true);

        Test.startTest();
        try {
            FSROtpController.generateAndSendOtp(fsr.Id);
            System.assert(false, 'Exception should have been thrown because OTP is already verified.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGenerateAndSendOtpNullId() {
        Test.startTest();
        try {
            FSROtpController.generateAndSendOtp(null);
            System.assert(false, 'Exception should have been thrown for null FSR Id.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateOtpSuccess() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        fsr.OTP__c = '1234';
        fsr.OTP_Expiry_Date_Time__c = System.now().addMinutes(15);
        update fsr;

        Test.startTest();
        String result = FSROtpController.validateOtp(fsr.Id, '1234');
        Test.stopTest();

        System.assertEquals('OTP verified successfully.', result);

        Field_Service_Report_FSR__c updatedFsr = [
            SELECT Id, OTP_Verified__c
            FROM Field_Service_Report_FSR__c
            WHERE Id = :fsr.Id
            LIMIT 1
        ];

        System.assertEquals(true, updatedFsr.OTP_Verified__c);
    }

    @IsTest
    static void testValidateOtpWithTrimSuccess() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        fsr.OTP__c = '5678';
        fsr.OTP_Expiry_Date_Time__c = System.now().addMinutes(15);
        update fsr;

        Test.startTest();
        String result = FSROtpController.validateOtp(fsr.Id, ' 5678 ');
        Test.stopTest();

        System.assertEquals('OTP verified successfully.', result);
    }

    @IsTest
    static void testValidateOtpNullId() {
        Test.startTest();
        try {
            FSROtpController.validateOtp(null, '1234');
            System.assert(false, 'Exception should have been thrown for null FSR Id.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateOtpBlankEnteredOtp() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        Test.startTest();
        try {
            FSROtpController.validateOtp(fsr.Id, '');
            System.assert(false, 'Exception should have been thrown for blank OTP.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateOtpNoOtpFound() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        Test.startTest();
        try {
            FSROtpController.validateOtp(fsr.Id, '1234');
            System.assert(false, 'Exception should have been thrown because OTP is missing.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateOtpExpiryMissing() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        fsr.OTP__c = '1234';
        fsr.OTP_Expiry_Date_Time__c = null;
        update fsr;

        Test.startTest();
        try {
            FSROtpController.validateOtp(fsr.Id, '1234');
            System.assert(false, 'Exception should have been thrown because expiry time is missing.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateOtpExpired() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        fsr.OTP__c = '1234';
        fsr.OTP_Expiry_Date_Time__c = System.now().addMinutes(-5);
        update fsr;

        Test.startTest();
        try {
            FSROtpController.validateOtp(fsr.Id, '1234');
            System.assert(false, 'Exception should have been thrown because OTP is expired.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateOtpInvalidOtp() {
        Field_Service_Report_FSR__c fsr = createFSR('test@example.com', false);

        fsr.OTP__c = '1234';
        fsr.OTP_Expiry_Date_Time__c = System.now().addMinutes(15);
        update fsr;

        Test.startTest();
        try {
            FSROtpController.validateOtp(fsr.Id, '9999');
            System.assert(false, 'Exception should have been thrown for invalid OTP.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
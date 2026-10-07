@IsTest
public class FSR_Signature_ExtensionTest {

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

    private static Field_Service_Report_FSR__c createFSR() {
        WorkOrder wo = createWorkOrder();

        Field_Service_Report_FSR__c fsr = new Field_Service_Report_FSR__c();
        fsr.Work_Order__c = wo.Id;
        fsr.Email_ID__c = 'test@example.com';
        fsr.OTP_Verified__c = false;

        insert fsr;
        return fsr;
    }

    private static Id createAndLinkFile(Id parentId, String fileTitle) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileTitle;
        cv.PathOnClient = fileTitle + '.png';
        cv.VersionData = Blob.valueOf('Test Signature File Body');
        cv.FirstPublishLocationId = parentId;
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        return insertedCv.Id;
    }

    @IsTest
    static void testConstructorWithCustomerAndEngineerSignature() {
        Field_Service_Report_FSR__c fsr = createFSR();

        Id customerContentVersionId = createAndLinkFile(fsr.Id, 'customer_signature_test');
        Id engineerContentVersionId = createAndLinkFile(fsr.Id, 'engineer_signature_test');

        Test.startTest();

        ApexPages.StandardController sc = new ApexPages.StandardController(fsr);
        FSR_Signature_Extension ext = new FSR_Signature_Extension(sc);

        Test.stopTest();

        System.assertEquals(
            customerContentVersionId,
            ext.customerSigId,
            'Customer signature ContentVersion Id should be assigned.'
        );

        System.assertEquals(
            engineerContentVersionId,
            ext.engineerSigId,
            'Engineer signature ContentVersion Id should be assigned.'
        );
    }

    @IsTest
    static void testConstructorWithNoFiles() {
        Field_Service_Report_FSR__c fsr = createFSR();

        Test.startTest();

        ApexPages.StandardController sc = new ApexPages.StandardController(fsr);
        FSR_Signature_Extension ext = new FSR_Signature_Extension(sc);

        Test.stopTest();

        System.assertEquals(
            null,
            ext.customerSigId,
            'Customer signature should be null when no file is attached.'
        );

        System.assertEquals(
            null,
            ext.engineerSigId,
            'Engineer signature should be null when no file is attached.'
        );
    }

    @IsTest
    static void testConstructorWithOtherFileTitle() {
        Field_Service_Report_FSR__c fsr = createFSR();

        createAndLinkFile(fsr.Id, 'normal_file_test');

        Test.startTest();

        ApexPages.StandardController sc = new ApexPages.StandardController(fsr);
        FSR_Signature_Extension ext = new FSR_Signature_Extension(sc);

        Test.stopTest();

        System.assertEquals(
            null,
            ext.customerSigId,
            'Customer signature should be null because file title does not match.'
        );

        System.assertEquals(
            null,
            ext.engineerSigId,
            'Engineer signature should be null because file title does not match.'
        );
    }
}
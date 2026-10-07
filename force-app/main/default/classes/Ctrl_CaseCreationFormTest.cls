@IsTest
public class Ctrl_CaseCreationFormTest {

    private static String getPickVal(Schema.SObjectField fieldRef, String fallbackVal) {
        List<Schema.PicklistEntry> vals = fieldRef.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry p : vals) {
            if (p.isActive()) {
                return p.getValue();
            }
        }
        return fallbackVal;
    }

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Customer Account',
            Phone = '9876543210',
            BillingCity = 'Kolkata',
            BillingState = 'West Bengal'
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id,
            Phone = '9876543210',
            MobilePhone = '9876543210',
            Email = 'testcontact@example.com'
        );
        insert con;

        Asset ast = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id,
            ContactId = con.Id,
            SerialNumber = 'SERIAL-12345'
        );

        ast.put('Invoice_Number__c', 'INV-12345');

        insert ast;
    }

    @IsTest
    static void testGetInitData() {

        Test.startTest();
        Ctrl_CaseCreationForm.getInitData();
        Test.stopTest();
    }

    @IsTest
    static void testSearchByAccountName() {

        Test.startTest();
        Ctrl_CaseCreationForm.search('Test Customer');
        Test.stopTest();
    }

    @IsTest
    static void testSearchByContactPhone() {

        Test.startTest();
        Ctrl_CaseCreationForm.search('9876543210');
        Test.stopTest();
    }

    @IsTest
    static void testSearchByAssetSerial() {

        Test.startTest();
        Ctrl_CaseCreationForm.search('SERIAL-12345');
        Test.stopTest();
    }

    @IsTest
    static void testLoadByAccountId() {

        Account acc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Customer Account'
            LIMIT 1
        ];

        Test.startTest();
        Ctrl_CaseCreationForm.loadByAccountId(acc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testCreateCaseWithExistingAccountContactAndMultipleAssets() {

        Account acc = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Customer Account'
            LIMIT 1
        ];

        Contact con = [
            SELECT Id
            FROM Contact
            WHERE AccountId = :acc.Id
            LIMIT 1
        ];

        Asset ast = [
            SELECT Id
            FROM Asset
            WHERE AccountId = :acc.Id
            LIMIT 1
        ];

        String statusVal = getPickVal(Case.Status, 'New');
        String originVal = getPickVal(Case.Origin, 'Phone');

        Ctrl_CaseCreationForm.CaseCreateRequest req =
            new Ctrl_CaseCreationForm.CaseCreateRequest();

        req.accountId = acc.Id;
        req.contactId = con.Id;
        req.assetId = ast.Id;
        req.assetIds = new List<Id>{ ast.Id };
        req.subject = 'Test Case Subject';
        req.description = 'Test Case Description';
        req.status = statusVal;
        req.origin = originVal;

        Test.startTest();
        Ctrl_CaseCreationForm.createCase(req);
        Test.stopTest();
    }

    @IsTest
    static void testCreateCaseWithNewAccountContactUsingWrapper() {

        String statusVal = getPickVal(Case.Status, 'New');
        String originVal = getPickVal(Case.Origin, 'Phone');

        Test.startTest();

        Ctrl_CaseCreationForm.createCase2(
            null,
            null,
            null,
            null,
            'New Customer Case',
            'Case created with new Account and Contact',
            null,
            statusVal,
            originVal,
            null,
            null,
            null,
            null,
            null,
            null,
            null,

            true,
            'Draft Test Account',
            '9000000000',
            'Kolkata',
            'West Bengal',
            'Test Street',
            '700001',
            'India',
            'New',
            'Customer',
            '9000000000',
            '9000000000',
            'newcustomer@example.com',
            'Service',
            'Manager'
        );

        Test.stopTest();
    }

    @IsTest
    static void testValidationSubjectRequired() {

        String originVal = getPickVal(Case.Origin, 'Phone');

        Ctrl_CaseCreationForm.CaseCreateRequest req =
            new Ctrl_CaseCreationForm.CaseCreateRequest();

        req.subject = null;
        req.description = 'Description';
        req.origin = originVal;

        Test.startTest();

        try {
            Ctrl_CaseCreationForm.createCase(req);
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @IsTest
    static void testValidationSearchTermTooSmall() {

        Test.startTest();

        try {
            Ctrl_CaseCreationForm.search('a');
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    @IsTest
    static void testEmptySearchResponse() {

        Test.startTest();
        Ctrl_CaseCreationForm.search('NoMatchingAccountXYZ987');
        Test.stopTest();
    }
}
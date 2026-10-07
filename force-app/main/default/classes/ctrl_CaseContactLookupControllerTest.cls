@IsTest
private class ctrl_CaseContactLookupControllerTest {
    @TestSetup
    static void setupData() {
        Account account1 = new Account(
            Name = 'Test Account 1'
        );
        Account account2 = new Account(
            Name = 'Test Account 2'
        );
        insert new List<Account>{account1, account2};

        Contact contact1 = new Contact(
            FirstName = 'Amit',
            LastName = 'Banerjee',
            Email = 'amit@test.com',
            Phone = '9876543210',
            AccountId = account1.Id
        );
        Contact contact2 = new Contact(
            FirstName = 'Rajesh',
            LastName = 'Sharma',
            Email = 'rajesh@test.com',
            Phone = '9876543211',
            AccountId = account1.Id
        );
        Contact contact3 = new Contact(
            FirstName = 'Suman',
            LastName = 'Das',
            Email = 'suman@test.com',
            Phone = '9876543212',
            AccountId = account2.Id
        );
        insert new List<Contact>{contact1, contact2, contact3};
    }

    @IsTest
    static void testSearchContactsWithNullAccount() {
        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(null, '');
        Test.stopTest();
    }

    @IsTest
    static void testSearchContactsWithBlankSearchTerm() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account 1'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(accountRecord.Id, '');
        Test.stopTest();
    }

    @IsTest
    static void testSearchContactsWithNullSearchTerm() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account 1'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(accountRecord.Id, null);
        Test.stopTest();
    }

    @IsTest
    static void testSearchContactsWithMatchingSearchTerm() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account 1'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(accountRecord.Id, 'Amit');
        Test.stopTest();
    }

    @IsTest
    static void testSearchContactsWithPartialSearchTerm() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account 1'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(accountRecord.Id, 'Raj');
        Test.stopTest();
    }

    @IsTest
    static void testSearchContactsWithNoMatchingContact() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account 1'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(accountRecord.Id, 'XYZ');
        Test.stopTest();
    }

    @IsTest
    static void testSearchContactsWithDifferentAccount() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account 2'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(accountRecord.Id, '');
        Test.stopTest();
    }

    @IsTest
    static void testSearchContactsWithSpacesInSearchTerm() {
        Account accountRecord = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account 1'
            LIMIT 1
        ];

        Test.startTest();
        List<ctrl_CaseContactLookupController.ContactResult> results = ctrl_CaseContactLookupController.searchContacts(accountRecord.Id, '  Amit  ');
        Test.stopTest();
    }
}
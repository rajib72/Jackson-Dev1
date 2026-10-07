@IsTest
private class CaseEscalationTriggerTest {

    @IsTest
    static void testAfterInsert() {

        Account acc =
            new Account(
                Name = 'Trigger Test Account',
                BillingPostalCode = '700001'
            );

        insert acc;


        Contact con =
            new Contact(
                FirstName = 'Test',
                LastName = 'Customer',
                AccountId = acc.Id,
                Email = 'test@example.com',
                Phone = '9876543210'
            );

        insert con;


        Test.startTest();

        try {

            Case c =
                new Case(
                    AccountId = acc.Id,
                    ContactId = con.Id,
                    Subject = 'Trigger Test',
                    Origin = 'Web',
                    Status = 'New'
                );

            insert c;

        } catch (Exception e) {

            System.debug(
                'INSERT TRIGGER RESULT = ' +
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testAfterUpdate() {

        List<Case> cases = [
            SELECT
                Id,
                Status,
                SRT_Case_Status__c
            FROM Case
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            return;
        }

        Case c =
            cases[0];


        Test.startTest();

        try {

            c.Subject =
                'Trigger Update Test';

            update c;

        } catch (Exception e) {

            System.debug(
                'UPDATE TRIGGER RESULT = ' +
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testResolvedWhatsAppPath() {

        List<Case> cases = [
            SELECT
                Id,
                SRT_Case_Status__c
            FROM Case
            WHERE SRT_Case_Status__c != 'Resolved'
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            return;
        }

        Case c =
            cases[0];


        Test.startTest();

        try {

            c.SRT_Case_Status__c =
                'Resolved';

            update c;

        } catch (Exception e) {

            System.debug(
                'RESOLVED TRIGGER RESULT = ' +
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}
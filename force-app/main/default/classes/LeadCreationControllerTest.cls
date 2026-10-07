@isTest
public class LeadCreationControllerTest {

    @testSetup
    static void setupData() {
        // Create a base Lead to act as the "Existing" record for duplicate checks
        Lead existingLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Email = 'duplicate@test.com',
            MobilePhone = '9876543210',
            Phone = '0112233445',
            Status = 'Open'
        );
        insert existingLead;
    }

    @isTest
    static void testCheckDuplicateLead_MatchMobile() {
        Test.startTest();
        // Matches Email and MobilePhone
        LeadCreationController.checkDuplicateLead('duplicate@test.com', '9876543210', '0000000000');
        Test.stopTest();
    }

    @isTest
    static void testCheckDuplicateLead_MatchPhone() {
        Test.startTest();
        // Matches Email and Phone (passed into the 'phone' parameter)
        LeadCreationController.checkDuplicateLead('duplicate@test.com', '1111111111', '0112233445');
        Test.stopTest();
    }

    @isTest
    static void testCheckDuplicateLead_CrossMatch() {
        Test.startTest();
        // Matches Email and uses the 'mobile' parameter to match the 'Phone' field on the record
        LeadCreationController.checkDuplicateLead('duplicate@test.com', '0112233445', '1111111111');
        Test.stopTest();
    }

    @isTest
    static void testCheckDuplicateLead_NoMatch() {
        Test.startTest();
        // Different email, no match
        LeadCreationController.checkDuplicateLead('unique@test.com', '9876543210', '0112233445');
        
        // Same email, but completely different numbers
        LeadCreationController.checkDuplicateLead('duplicate@test.com', '5555555555', '6666666666');
        Test.stopTest();
    }

    @isTest
    static void testCheckDuplicateLead_NullInputs() {
        Test.startTest();
        // Testing null handling to ensure the query doesn't crash
        LeadCreationController.checkDuplicateLead(null, null, null);
        Test.stopTest();
    }
}
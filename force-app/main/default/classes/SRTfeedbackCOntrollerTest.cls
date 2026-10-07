@isTest
private class SRTfeedbackCOntrollerTest {

    /* =========================================================
       HELPERS
       ========================================================= */

    private static Contact createContact() {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact',
            Phone     = '9999999999',
            Email     = 'test.contact@example.com'
        );
        insert con;
        return con;
    }

    private static Case createCase(Id contactId) {
        Case c = new Case(
            ContactId            = contactId,
            Subject              = 'Test Case for Feedback',
            Feedback_Received__c = false
        );
        insert c;

        return [
            SELECT Id, SRT_Case_No__c, ContactId, Feedback_Received__c
            FROM Case
            WHERE Id = :c.Id
        ];
    }

    // Some orgs reject Cases without a Contact on insert, so create with one and clear it.
    // Returns null if the org blocks that as well.
    private static Case createCaseWithoutContact() {
        Contact con = createContact();
        Case c = createCase(con.Id);
        c.ContactId = null;
        Database.SaveResult sr = Database.update(c, false);
        if (!sr.isSuccess()) {
            System.debug(LoggingLevel.ERROR,
                'TEST SKIPPED - cannot clear Contact on Case: ' + sr.getErrors()[0].getMessage());
            return null;
        }
        return c;
    }

    // saveFeedback has 11 parameters; contactName is the 3rd
    private static SRTfeedbackCOntroller.SaveResult callSave(
        Id caseId, Id contactId, String contactName, String contactPhone
    ) {
        return SRTfeedbackCOntroller.saveFeedback(
            caseId,
            contactId,
            contactName,
            contactPhone,
            Date.today(),
            '5',    // overallSatisfaction
            '5',    // recommendJakson
            'Yes',  // issueResolved
            '5',    // engineerBehaviour
            '5',    // responseExperience
            'Great service'
        );
    }

    /* =========================================================
       getCaseDetails
       ========================================================= */

    @isTest
    static void getCaseDetails_nullCaseId_returnsEmptyWrapper() {
        Test.startTest();
        SRTfeedbackCOntroller.CaseWrapper cw = SRTfeedbackCOntroller.getCaseDetails(null);
        Test.stopTest();

        System.assertEquals(null, cw.caseId);
        System.assertEquals(null, cw.caseNumber);
    }

    @isTest
    static void getCaseDetails_caseNotFound_returnsEmptyWrapper() {
        Contact con = createContact();
        Case c = createCase(con.Id);
        Id caseId = c.Id;
        delete c;

        Test.startTest();
        SRTfeedbackCOntroller.CaseWrapper cw = SRTfeedbackCOntroller.getCaseDetails(caseId);
        Test.stopTest();

        System.assertEquals(null, cw.caseId, 'Deleted Case should not be found.');
    }

    @isTest
    static void getCaseDetails_withContact_populatesWrapper() {
        Contact con = createContact();
        Case c = createCase(con.Id);

        Test.startTest();
        SRTfeedbackCOntroller.CaseWrapper cw = SRTfeedbackCOntroller.getCaseDetails(c.Id);
        Test.stopTest();

        System.assertEquals(c.Id, cw.caseId);
        System.assertEquals(c.SRT_Case_No__c, cw.caseNumber);
        System.assertEquals(con.Id, cw.contactId);
        System.assertEquals('Test Contact', cw.contactName);
        System.assertEquals('9999999999', cw.contactPhone);
        System.assertEquals('test.contact@example.com', cw.contactEmail);
        System.assertEquals(false, cw.feedbackReceived);
    }

    @isTest
    static void getCaseDetails_withoutContact_blankContactFields() {
        Case c = createCaseWithoutContact();
        if (c == null) {
            return;
        }

        Test.startTest();
        SRTfeedbackCOntroller.CaseWrapper cw = SRTfeedbackCOntroller.getCaseDetails(c.Id);
        Test.stopTest();

        System.assertEquals(c.Id, cw.caseId);
        System.assertEquals('', cw.contactName);
        System.assertEquals('', cw.contactPhone);
        System.assertEquals('', cw.contactEmail);
    }

    /* =========================================================
       saveFeedback - failure paths
       ========================================================= */

    @isTest
    static void saveFeedback_nullCaseId_returnsFailure() {
        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result = callSave(null, null, null, null);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Case Id is required.', result.message);
    }

    @isTest
    static void saveFeedback_caseNotFound_returnsFailure() {
        Contact con = createContact();
        Case c = createCase(con.Id);
        Id deletedCaseId = c.Id;
        delete c;

        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result =
            callSave(deletedCaseId, con.Id, 'Test Contact', con.Phone);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Case not found.', result.message);
    }

    @isTest
    static void saveFeedback_alreadyReceived_returnsFailure() {
        Contact con = createContact();
        Case c = new Case(
            ContactId            = con.Id,
            Subject              = 'Already Feedback Submitted',
            Feedback_Received__c = true
        );
        insert c;

        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result =
            callSave(c.Id, con.Id, 'Test Contact', con.Phone);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Feedback has already been submitted.', result.message);
    }

    /* =========================================================
       saveFeedback - success paths
       ========================================================= */

    @isTest
    static void saveFeedback_success_updatesContactCaseAndCreatesFeedback() {
        Contact con = createContact();
        Case c = createCase(con.Id);

        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result =
            callSave(c.Id, con.Id, 'Updated Person', '8888888888');
        Test.stopTest();

        System.assertEquals(true, result.success,
            'Feedback save should succeed. Message = ' + result.message);
        System.assertNotEquals(null, result.recordId);
        System.assertEquals('Feedback submitted successfully.', result.message);

        // Contact updated (phone + name split on last space)
        Contact updatedCon = [
            SELECT Phone, FirstName, LastName FROM Contact WHERE Id = :con.Id
        ];
        System.assertEquals('8888888888', updatedCon.Phone);
        System.assertEquals('Updated', updatedCon.FirstName);
        System.assertEquals('Person', updatedCon.LastName);

        // Case updated
        System.assertEquals(true,
            [SELECT Feedback_Received__c FROM Case WHERE Id = :c.Id].Feedback_Received__c);

        // Feedback created
        Feedback_Form__c feedback = [
            SELECT Case__c, Service_Completion_Date__c, Overall_Satisfaction_CSAT__c,
                   Would_you_recommend_Jakson_NPS__c, Issue_resolved__c,
                   Engineer_behaviour_professionalism__c,
                   Response_turnaround_experience__c, Comments__c
            FROM Feedback_Form__c
            WHERE Id = :result.recordId
        ];
        System.assertEquals(c.Id, feedback.Case__c);
        System.assertEquals(Date.today(), feedback.Service_Completion_Date__c);
        System.assertEquals('5', feedback.Overall_Satisfaction_CSAT__c);
        System.assertEquals('5', feedback.Would_you_recommend_Jakson_NPS__c);
        System.assertEquals('Yes', feedback.Issue_resolved__c);
        System.assertEquals('5', feedback.Engineer_behaviour_professionalism__c);
        System.assertEquals('5', feedback.Response_turnaround_experience__c);
        System.assertEquals('Great service', feedback.Comments__c);
    }

    @isTest
    static void saveFeedback_success_singleWordName_setsLastNameOnly() {
        Contact con = createContact();
        Case c = createCase(con.Id);

        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result =
            callSave(c.Id, con.Id, 'Madonna', '8888888888');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Message = ' + result.message);

        Contact updatedCon = [SELECT FirstName, LastName FROM Contact WHERE Id = :con.Id];
        System.assertEquals(null, updatedCon.FirstName);
        System.assertEquals('Madonna', updatedCon.LastName);
    }

    @isTest
    static void saveFeedback_success_blankName_keepsExistingName() {
        Contact con = createContact();
        Case c = createCase(con.Id);

        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result =
            callSave(c.Id, con.Id, '   ', '7777777777');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Message = ' + result.message);

        Contact updatedCon = [SELECT Phone, FirstName, LastName FROM Contact WHERE Id = :con.Id];
        System.assertEquals('7777777777', updatedCon.Phone);
        System.assertEquals('Test', updatedCon.FirstName);
        System.assertEquals('Contact', updatedCon.LastName);
    }

    @isTest
    static void saveFeedback_success_withoutContactId_skipsContactUpdate() {
        Contact con = createContact();
        Case c = createCase(con.Id);
        String originalPhone = con.Phone;

        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result =
            callSave(c.Id, null, 'Anyone', '7777777777');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Message = ' + result.message);

        System.assertEquals(originalPhone,
            [SELECT Phone FROM Contact WHERE Id = :con.Id].Phone,
            'Phone should not update when contactId is null.');

        System.assertEquals(true,
            [SELECT Feedback_Received__c FROM Case WHERE Id = :c.Id].Feedback_Received__c);

        System.assertEquals(1,
            [SELECT COUNT() FROM Feedback_Form__c WHERE Case__c = :c.Id]);
    }

    /* =========================================================
       Exception / catch block
       ========================================================= */

    @isTest
    static void saveFeedback_exceptionDuringSave_returnsFailureWithMessage() {
        Contact con = createContact();
        Case c = createCase(con.Id);

        // A Case Id used as contactId makes "new Contact(Id = contactId)" throw,
        // which the controller's catch block turns into a failure result.
        Test.startTest();
        SRTfeedbackCOntroller.SaveResult result =
            callSave(c.Id, c.Id, 'Test Contact', '5555555555');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Controller should catch exception.');
        System.assertNotEquals(null, result.message);
        System.assert(result.message.length() > 0);
    }
}
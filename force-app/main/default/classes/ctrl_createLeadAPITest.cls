@IsTest
public class ctrl_createLeadAPITest {

    @IsTest
    static void testCreateLeadAPI() {

        // Prepare request body (JSON)
        ctrl_createLeadAPI_JaksonGroup.leadParameters params =
            new ctrl_createLeadAPI_JaksonGroup.leadParameters();

        params.leadName = 'Test Lead';
        params.lemail = 'testlead@example.com';
        params.lmobile = '9999999999';
        params.location = 'Kolkata';
        params.companyName = 'Test Company';
        params.contactReason = 'Inquiry';
        params.leadSource = 'Website';
        params.description = 'Test Description';

        String requestBody = JSON.serialize(params);

        // Set RestContext
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/jaksonGroup/lead/Create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();

        // Call API
        List<String> response =
            ctrl_createLeadAPI_JaksonGroup.createJaksonGroupLead();

        Test.stopTest();
    }


    // -------------------------------------------------
    // TEST WITH MINIMAL DATA (NULL/BLANK SCENARIO)
    // -------------------------------------------------
    @IsTest
    static void testCreateLeadAPI_BlankValues() {

        ctrl_createLeadAPI_JaksonGroup.leadParameters params =
            new ctrl_createLeadAPI_JaksonGroup.leadParameters();

        params.leadName = 'Test Lead 2';
        params.lmobile = '8888888888';

        String requestBody = JSON.serialize(params);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/jaksonGroup/lead/Create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();

        ctrl_createLeadAPI_JaksonGroup.createJaksonGroupLead();

        Test.stopTest();
    }
}
@IsTest
private class ctrl_createLeadAPI_Call_Center_Test {

    @IsTest
    static void testCreateNewIvrLead() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/ivrlead/callCenter/Create';
        req.httpMethod = 'POST';

        String requestBody = JSON.serialize(new Map<String, Object>{
            'callernumber'     => '9876543210',
            'cdate'            => '2026-06-04',
            'ctime'            => '10:30 AM',
            'agentnumber'      => 'AGENT001',
            'ivrduration'      => '30',
            'callduration'     => '120',
            'callstatus'       => 'Completed',
            'State'            => 'West Bengal',
            'ibizfonenumber'   => '03312345678',
            'calllogid'        => 'LOG001',
            'department'       => 'Support',
            'recordingurl'     => 'https://example.com/recording.mp3'
        });

        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        List<String> responseList = ctrl_createLeadAPI_Call_Center.createivrLead();
        Test.stopTest();

        List<Lead> insertedLeads = [
            SELECT Id, Name, Phone, MobilePhone, LastName, Company, LeadSource
            FROM Lead
            WHERE MobilePhone = '9876543210'
            LIMIT 1
        ];

        List<Task> insertedTasks = [
            SELECT Id,
                   WhoId,
                   Subject,
                   Status,
                   Priority,
                   recordingurl__c,
                   Description,
                   ActivityDate,
                   Calling_Date__c,
                   Calling_Time__c,
                   Agent_Number__c,
                   callduration__c,
                   calllogid__c,
                   callstatus__c,
                   department__c,
                   ibizfonenumber__c,
                   ivrduration__c,
                   state__c
            FROM Task
            WHERE WhoId = :insertedLeads[0].Id
            LIMIT 1
        ];
    }

    @IsTest
    static void testUpdateExistingIvrLead() {

        Lead existingLead = new Lead(
            LastName = 'Existing IVR Lead',
            Company = 'Test Company',
            Phone = '9123456780',
            MobilePhone = '9123456780',
            LeadSource = 'IVR'
        );
        insert existingLead;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/ivrlead/callCenter/Create';
        req.httpMethod = 'POST';

        String requestBody = JSON.serialize(new Map<String, Object>{
            'callernumber'     => '9123456780',
            'cdate'            => '2026-06-04',
            'ctime'            => '11:00 AM',
            'agentnumber'      => 'AGENT002',
            'ivrduration'      => '45',
            'callduration'     => '180',
            'callstatus'       => 'Completed',
            'State'            => 'West Bengal',
            'ibizfonenumber'   => '03387654321',
            'calllogid'        => 'LOG002',
            'department'       => 'Sales',
            'recordingurl'     => 'https://example.com/existing-recording.mp3'
        });

        req.requestBody = Blob.valueOf(requestBody);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        List<String> responseList = ctrl_createLeadAPI_Call_Center.createivrLead();
        Test.stopTest();

        List<Lead> existingLeads = [
            SELECT Id, Name, Phone, MobilePhone, LastName, Company, LeadSource
            FROM Lead
            WHERE Id = :existingLead.Id
            LIMIT 1
        ];

        List<Task> insertedTasks = [
            SELECT Id,
                   WhoId,
                   Subject,
                   Status,
                   Priority,
                   recordingurl__c,
                   Description,
                   ActivityDate,
                   Calling_Date__c,
                   Calling_Time__c,
                   Agent_Number__c,
                   callduration__c,
                   calllogid__c,
                   callstatus__c,
                   department__c,
                   ibizfonenumber__c,
                   ivrduration__c,
                   state__c
            FROM Task
            WHERE WhoId = :existingLead.Id
            LIMIT 1
        ];
    }
}
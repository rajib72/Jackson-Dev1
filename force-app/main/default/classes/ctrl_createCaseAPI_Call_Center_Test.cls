@IsTest
private class ctrl_createCaseAPI_Call_Center_Test {

    @IsTest
    static void testCreateIvrCaseSuccess() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/ivrCase/callCenter/Create';
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
        List<String> responseList = ctrl_createCaseAPI_Call_Center.createivrCase();
        Test.stopTest();

        List<Case> insertedCases = [
            SELECT Id, CaseNumber, SuppliedPhone, Priority, Status, States__c, Origin, IVR_Call_Recording__c
            FROM Case
            WHERE SuppliedPhone = '9876543210'
            LIMIT 1
        ];

        List<Task> insertedTasks = [
            SELECT Id,
                   WhatId,
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
            WHERE WhatId = :insertedCases[0].Id
            LIMIT 1
        ];
    }
}
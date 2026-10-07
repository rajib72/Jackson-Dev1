@RestResource(urlMapping='/ivrCase/callCenter/Create')
global with sharing class ctrl_createCaseAPI_Call_Center
{ 
    @HttpPost
    global static List<String> createivrCase()
    {
        //rest context objects for request and response
        RestRequest req = RestContext.request;
                 
        //wrapper for accepting parameters passed in and deserialize parameters into wrapper
        caseParameters parameters = (caseParameters)JSON.deserialize(req.requestBody.toString(), caseParameters.Class);
         
        //create case list to store newly created case
        List<Case> caseList = new List<Case>();
        
        //create String list to store response data
        List<String> returnResponse = new List<String>();
        
        //instantiate new Case object
        Case caseToInsert = new Case();  
        
        //Create Task against a Case
        List<Task> tasksToInsert = new List<Task>();   

        Datetime currentDT = System.now();
        String formattedDateTime = currentDT.format('dd-MM-yyyy HH:mm:ss');
        System.debug('Formatted DateTime: ' + formattedDateTime); 
        
        //populate values on caseToInsert from deserialized parameters
            
        caseToInsert.SuppliedPhone = parameters.callernumber;
        caseToInsert.Priority = 'Medium';
        caseToInsert.Status = 'New';
        caseToInsert.States__c = parameters.State;
        caseToInsert.Origin = 'IVR';
        caseToInsert.IVR_Call_Recording__c = parameters.recordingurl;
        caseToInsert.Internal_Business_Team__c = parameters.intBuTeam;
        
        try
        {
            insert caseToInsert;
            
            // Create a follow-up task for each new lead                
            Task t = new Task
            (                   
                //WhatId = leadToInsert.Id,    // Related to Lead
                WhatId = caseToInsert.Id,   // Assign to Case
                Subject = 'Query Related To -- '+ parameters.department+ '/ Logged In - ' + formattedDateTime,
                Status = 'Completed',
                Priority = 'Normal',
                recordingurl__c = parameters.recordingurl,
                Description = parameters.recordingurl,            
                ActivityDate = System.today(), // Due date Today
                Calling_Date__c = parameters.cdate,
                Calling_Time__c = parameters.ctime,
                Agent_Number__c= parameters.agentnumber,
                callduration__c= parameters.callduration,
                calllogid__c= parameters.calllogid,
                callstatus__c= parameters.callstatus,
                department__c= parameters.department,
                ibizfonenumber__c= parameters.ibizfonenumber,
                ivrduration__c= parameters.ivrduration,
                state__c= parameters.state
            );
            tasksToInsert.add(t);
            
            if(!tasksToInsert.isEmpty())
            {
                insert tasksToInsert;
            }
            
            Case qtdt = [Select id,CaseNumber,SuppliedPhone from Case Where id=:caseToInsert.id LIMIT 1];
            returnResponse.add('Calling Number: ' + qtdt.SuppliedPhone);
            returnResponse.add('Case Number: ' + qtdt.CaseNumber); 
            returnResponse.add('Record ID: ' + caseToInsert.id);
            returnResponse.add('Record Successfully Created.');
        } 
        catch (dmlexception e)
        {            
            returnResponse.add('400 Error: ' + e.getMessage());
        }
        
        return returnResponse;
    }
    
    global class caseParameters
    {
        global String callernumber;
        global String cdate;
        global String ctime;
        global String agentnumber;
        global String ivrduration;
        global String callduration;
        global String callstatus;
        global String State;
        global String ibizfonenumber;
        global String calllogid;
        global String department;
        global String recordingurl;
        global String intBuTeam;
    }
}
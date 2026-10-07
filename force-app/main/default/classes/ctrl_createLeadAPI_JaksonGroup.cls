@RestResource(urlMapping='/jaksonGroup/lead/Create')
global with sharing class ctrl_createLeadAPI_JaksonGroup
{ 
    @HttpPost
    global static List<String> createJaksonGroupLead()
    {
        //rest context objects for request and response
        RestRequest req = RestContext.request;
                 
        //wrapper for accepting parameters passed in and deserialize parameters into wrapper
        leadParameters parameters = (leadParameters)JSON.deserialize(req.requestBody.toString(), leadParameters.Class);
         
        //create Lead list to store newly created Lead
        List<Lead> leadList = new List<Lead>();
        
        //create String list to store response data
        List<String> returnResponse = new List<String>();
        
        //instantiate new Lead object
        Lead leadToInsert = new Lead();  
        
        //search existing Lead
        List<Lead> ldexistList = new List<Lead>();
        
        //Create Task against a Lead
        List<Task> tasksToInsert = new List<Task>();   
        
        // Check Same Contact Number Exist or Not        
        if(parameters.lmobile != null && (!String.isEmpty(parameters.lmobile)) && (!String.isBlank(parameters.lmobile)))
        {
            ldexistList = [SELECT id,name,Phone,MobilePhone,LastName,Company,LeadSource,CreatedDate
                          FROM Lead WHERE ((MobilePhone =: parameters.lmobile) OR (Phone =: parameters.lmobile)) ORDER BY CreatedDate ASC];
        }
        
        Datetime currentDT = System.now();
        String formattedDateTime = currentDT.format('dd-MM-yyyy HH:mm:ss');
        System.debug('Formatted DateTime: ' + formattedDateTime); 
        
        // If the lead is exist
        /*if(ldexistList.size() > 0)
        {
            //Create a follow-up task for each new lead             
            Task t = new Task
            (                   
                //WhatId = ldexistList[0].Id,    // Related to Lead
                WhoId  = ldexistList[0].Id,   // Assign to Lead
                Subject = 'Query Related To -- '+ parameters.department+ '/ Logged In - ' + formattedDateTime,
                Status = 'Completed',
                Priority = 'Normal',
                recordingurl__c = parameters.recordingurl,
                Description = parameters.recordingurl,            
                ActivityDate = System.today(), // Due date Today
                Calling_Date__c = parameters.cdate,
                Calling_Time__c = parameters.ctime,
                Agent_Number__c = parameters.agentnumber,
                callduration__c = parameters.callduration,
                calllogid__c= parameters.calllogid,
                callstatus__c= parameters.callstatus,
                department__c= parameters.department,
                ibizfonenumber__c= parameters.ibizfonenumber,
                ivrduration__c= parameters.ivrduration,
                state__c= parameters.state
            );
            tasksToInsert.add(t);
            
            try
            {               
                if(!tasksToInsert.isEmpty())
                {
                    insert tasksToInsert;
                }
                
                Lead qtdt = [Select id,Name,MobilePhone from Lead Where id=:ldexistList[0].id LIMIT 1];
                returnResponse.add('Calling Number: ' + qtdt.MobilePhone); 
                returnResponse.add('Record ID: ' + ldexistList[0].id);
                returnResponse.add('Record Successfully Updated.');
            }
            
            catch (dmlexception e)
            {            
                returnResponse.add('400 Error: ' + e.getMessage());
            }           
        }*/

        //populate values on leadToInsert from deserialized parameters
        
        leadToInsert.Phone = parameters.lmobile;
        leadToInsert.MobilePhone = parameters.lmobile;
        leadToInsert.LastName = parameters.leadName;
        if(parameters.companyName != null && (!String.isEmpty(parameters.companyName)) && (!String.isBlank(parameters.companyName)))
        {
            leadToInsert.Company = parameters.companyName;
        }
        else
        {
            leadToInsert.Company = 'Blank';
        }
        leadToInsert.Description = parameters.description;
        leadToInsert.Email = parameters.lemail;
        leadToInsert.Reason_for_Contact__c = parameters.contactReason;
        leadToInsert.Location__c = parameters.location;
        leadToInsert.LeadSource = 'Website';
        leadToInsert.Jakson_Group__c = true;
        
            try
            {
                insert leadToInsert;
                
                // Create a follow-up task for each new lead                
                Task t = new Task
                (                   
                    //WhatId = leadToInsert.Id,    // Related to Lead
                    WhoId  = leadToInsert.Id,   // Assign to Lead
                    Subject = 'Query Related To -- '+ parameters.contactReason+ '/ Logged In - ' + formattedDateTime,
                    Status = 'Completed',
                    Priority = 'Normal',
                    Description = parameters.description,            
                    ActivityDate = System.today() // Due date Today
                );
                
                tasksToInsert.add(t);
                
                if(!tasksToInsert.isEmpty())
                {
                    insert tasksToInsert;
                }
                
                Lead qtdt = [Select id,Name,MobilePhone from Lead Where id=:leadToInsert.id LIMIT 1];
                returnResponse.add('Mobile: ' + qtdt.MobilePhone); 
                returnResponse.add('Record ID: ' + leadToInsert.id);
                returnResponse.add('Record Successfully Created.');
            } 
            catch (dmlexception e)
            {            
                returnResponse.add('400 Error: ' + e.getMessage());
            }
        
        return returnResponse;
    }
    
    global class leadParameters
    {
        global String leadName;
        global String lemail;
        global String lmobile;
        global String location;
        global String companyName;
        global String contactReason;
        global String leadSource;
        global String description;
    }
}
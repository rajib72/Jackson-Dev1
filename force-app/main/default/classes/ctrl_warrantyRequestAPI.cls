@RestResource(urlMapping='/WarrantyRequest/Create')
global with sharing class ctrl_warrantyRequestAPI
{ 
    @HttpPost
    global static List<String> createWarrantyRequest()
    {
        //rest context objects for request and response
        RestRequest req = RestContext.request;
                 
        //wrapper for accepting parameters passed in and deserialize parameters into wrapper
        warrantyRequestParameters parameters = (warrantyRequestParameters)JSON.deserialize(req.requestBody.toString(), warrantyRequestParameters.Class);
         
        //create Warranty Request list to store newly created Warranty Request
        List<Warranty_Request__c> wrList = new List<Warranty_Request__c>();
        
        //create String list to store response data
        List<String> returnResponse = new List<String>();
        
        //instantiate new WR object
        Warranty_Request__c wrToInsert = new Warranty_Request__c();  
        
        //search existing WR
        List<Warranty_Request__c> wrexistList = new List<Warranty_Request__c>();
        
        //Create Task against a WR
        List<Warranty_Request__c> tasksToInsert = new List<Warranty_Request__c>();   
        
         // Check Serial Number blank      
        if(parameters.serialNumber == null && (String.isEmpty(parameters.serialNumber)) && (String.isBlank(parameters.serialNumber)))
        {
            returnResponse.add('ERR_400_Serial_No_Missing, Please enter serial number!');          
        }
        
        // Check Same Serial Number Exist or Not        
        if(parameters.serialNumber != null && (!String.isEmpty(parameters.serialNumber)) && (!String.isBlank(parameters.serialNumber)))
        {
            wrexistList = [SELECT id,name,Batch_Number__c,Customer_Name__c,Email__c,Installation_Date__c,Invoice_number__c,Serial_Number__c,Mobile_No__c
                          FROM Warranty_Request__c WHERE ((Serial_Number__c =: parameters.serialNumber)) ORDER BY CreatedDate ASC];
        }
        
        Datetime currentDT = System.now();
        String formattedDateTime = currentDT.format('dd-MM-yyyy HH:mm:ss');
        System.debug('Formatted DateTime: ' + formattedDateTime); 
        
        if(wrexistList.size() == 0)
        {           
            //populate values on leadToInsert from deserialized parameters
            
            wrToInsert.Batch_Number__c = parameters.batchNumber;
            wrToInsert.Customer_Name__c = parameters.customerName;
            wrToInsert.Email__c = parameters.emailId;
            wrToInsert.Installation_Date__c = parameters.installationDate;
            wrToInsert.Installer_Type__c = parameters.installerType;
            wrToInsert.Invoice_number__c = parameters.invNumber;
            wrToInsert.Mobile_No__c = parameters.mobileNumber;
            wrToInsert.Product_Model__c = parameters.productModel;
            wrToInsert.Serial_Number__c = parameters.serialNumber;
            wrToInsert.Status__c = 'Draft';
            
            try
            {
                insert wrToInsert;               
                
                Warranty_Request__c qtdt = [Select id,Name,Serial_Number__c,Customer_Name__c from Warranty_Request__c Where id=:wrToInsert.id LIMIT 1];
                returnResponse.add('Serial Number: ' + qtdt.Serial_Number__c); 
                returnResponse.add('Warranty Request No: ' + qtdt.Name); 
                returnResponse.add('Record ID: ' + wrToInsert.id);
                returnResponse.add('Warranty Request Record Successfully Created.');
            } 
            catch (dmlexception e)
            {            
                returnResponse.add('400 Error: ' + e.getMessage());
            }
        }
        
        return returnResponse;
    }
    
    global class warrantyRequestParameters
    {
        global String batchNumber;
        global String customerName;
        global String emailId;
        global String installationDate;
        global String installerType;
        global String invNumber;
        global String mobileNumber;
        global String productModel;
        global String serialNumber;
    }
}
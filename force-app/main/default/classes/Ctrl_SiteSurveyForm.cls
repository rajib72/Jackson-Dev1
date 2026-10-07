public class Ctrl_SiteSurveyForm {

    // Method to fetch Site Survey details
    @AuraEnabled(cacheable=true)
    public static Site_Survey__c getSiteSurveyDetails(Id recordId) {
        return [
            SELECT Customer_Name__c,
                   Street__c,
                   City__c,
                   Pincode__c,
                   State__c,
                   Country__c,
                   Nearest_Airport_Railway_station__c,
                   Contact_Person_Phone__c,
                   Contact_Person_Name__c,
                   Contact_Person_Mobile__c,
                   Contact_Person_Email__c,
                   Latitude_deg__c,
                   Longitude_deg__c
            FROM Site_Survey__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
    @AuraEnabled(cacheable=true)
public static List<Contact> getContactsByAccount(Id accountId){

    if(accountId == null){
        return new List<Contact>();
    }

    return [
        SELECT Id, Name
        FROM Contact
        WHERE AccountId = :accountId
        ORDER BY Name
    ];
}


    // Method to upload file to the record
    @AuraEnabled
    public static String uploadFile(String fileName, String base64Data, Id recordId) {

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        return 'File Uploaded Successfully';
    }
    
@AuraEnabled
public static void markSurveyCompleted(Id opportunityId){

    if(opportunityId == null){
        return;
    }

    Opportunity opp = new Opportunity(
        Id = opportunityId,
        Is_Site_Survey_Completed__c = true
    );

    update opp;
}
    

}
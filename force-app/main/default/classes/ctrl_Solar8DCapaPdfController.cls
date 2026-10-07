public with sharing class ctrl_Solar8DCapaPdfController {

    public Solar_CAPA__c capaRec { get; set; }
    public List<Solar_CAPA_Action__c> actionList { get; set; }

    public ctrl_Solar8DCapaPdfController (ApexPages.StandardController stdController) {
        Id recordId = stdController.getId();

        capaRec = [
            SELECT Id,
                   Name,                  
                   Verification_Result__c
            FROM Solar_CAPA__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        actionList = [
            SELECT Id,
                   Name,
                   Action_Detail__c,
                   Owner_Name__c,
                   Target_Date__c,
                   Status__c,
                   Remarks__c
            FROM Solar_CAPA_Action__c
            WHERE Solar_CAPA__c = :recordId
            ORDER BY CreatedDate ASC
        ];
    }
}
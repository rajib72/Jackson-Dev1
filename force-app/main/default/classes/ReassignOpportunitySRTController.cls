public with sharing class ReassignOpportunitySRTController {

    @AuraEnabled
    public static void reassignOpportunity(Id opportunityId) {

        if (opportunityId == null) {
            throw new AuraHandledException('Invalid Opportunity.');
        }

        Opportunity opp = [
            SELECT Id,
                   KAM_SRT_Opp_Sub_Stages__c,
                   ReassignCheckForTest1__c,
                   Sales_Team_Assigned_DateTime__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        // 🔹 Reset Sub Stage
        opp.KAM_SRT_Opp_Sub_Stages__c = 'None';

        // 🔹 Allow editing of Test1
        opp.ReassignCheckForTest1__c = true;

        // 🔹 Restart Sales Team 24-hour TAT
        opp.Sales_Team_Assigned_DateTime__c = System.now();

        update opp;
    }
}
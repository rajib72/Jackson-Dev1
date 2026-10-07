public with sharing class UpdateKamSRTOpportunityStageController {

    @AuraEnabled
    public static void updateStageAndCreateRemark(
        Id opportunityId,
        String selectedStage,
        String remarksText,
        Boolean qualificationChecked,
        Boolean test1Checked,
        String offerProcessValue,
        Boolean poReceivedChecked
    ) {

        if(opportunityId == null){
            throw new AuraHandledException('Invalid Opportunity.');
        }

        Opportunity opp = [
            SELECT Id,
                   KAM_SRT_Opp_Stages__c,
                   KAM_SRT_Opp_Sub_Stages__c,
                   Qualification_To_SalesTeam__c,
                   Test1__c,
                   Offer_Management_Process__c,
                   Is_KAM_SRT_Offer_Cretaed__c,
                   PO_Received__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        String oldStage = opp.KAM_SRT_Opp_Stages__c;

        /* 🔵 Qualification → Assign to Sales Team */
        if(oldStage == 'Qualification' &&
           selectedStage == 'Assign to Sales Team') {

            opp.Qualification_To_SalesTeam__c = qualificationChecked;
            opp.Sales_Team_Assigned_DateTime__c = System.now();
        }

        /* 🟢 Sales Team → Assign to Pre Design */
        if(oldStage == 'Assign to Sales Team' &&
           selectedStage == 'Assign to Pre Design Team') {

            opp.Test1__c = test1Checked;
            opp.Pre_Design_Assigned_DateTime__c = System.now();
        }

        /* 🟣 Pre Design → Techno Commercial */
        if(oldStage == 'Assign to Pre Design Team' &&
           selectedStage == 'Techno Commercial Offer') {

            if(!opp.Is_KAM_SRT_Offer_Cretaed__c){
                throw new AuraHandledException(
                    'Please Create a Techno-Commercial offer first'
                );
            }

            opp.Offer_Management_Process__c = offerProcessValue;

            if(offerProcessValue == 'Direct move to BU Head approval'){
                opp.KAM_SRT_Opp_Sub_Stages__c =
                    'Submitted for BU Head for Final Commercial Approval';
            }
            else if(offerProcessValue == 'Move via Sales Head approval'){
                opp.KAM_SRT_Opp_Sub_Stages__c =
                    'Submitted for Sales Head Approval';
            }
        }

        /* 🔴 PO Received */
        if(selectedStage == 'PO Received') {

            if(!poReceivedChecked){
                throw new AuraHandledException(
                    'Please Check the PO Received and upload file'
                );
            }

            opp.PO_Received__c = poReceivedChecked;
        }

        /* 🔵 Update Stage */
        opp.KAM_SRT_Opp_Stages__c = selectedStage;

        update opp;

        /* 📝 Insert Remark */
        if(!String.isBlank(remarksText)){
            insert new Remarks__c(
                Opportunity__c = opportunityId,
                Remarks__c = remarksText,
                Remarks_Type__c = 'SRT Sales',
                Stage_Name__c = selectedStage,
                OwnerId = UserInfo.getUserId()
            );
        }
    }
}
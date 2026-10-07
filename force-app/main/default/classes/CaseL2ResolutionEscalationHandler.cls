public class CaseL2ResolutionEscalationHandler implements Schedulable {


    private static final Integer L2_RESOLUTION_HOURS = 24;


    /*
     * Scheduler Entry
     */
    public void execute(SchedulableContext sc) {

        processL2ResolutionEscalations();

    }



    /*
     * Find cases where L2 Dealer could not resolve
     * within 24 hours
     */
    public static void processL2ResolutionEscalations() {


        Datetime cutoffTime =
            System.now()
            .addHours(
                -L2_RESOLUTION_HOURS
            );


        List<Case> casesToEscalate = [

            SELECT
                Id,
                CaseNumber,
                SRT_Case_Number__c,
                Subject,

                L2_Assigned__c,
                L2_Assigned__r.Name,
                L2_Assigned__r.Email__c,

                L2_Assigned_At__c,

                // L3 Details Added
                L3_Assigned__c,
                L3_Assigned_At__c,

                L2_Resolution_Escalation_Sent__c,

                SRT_Case_Status__c,
                Buisness_Segment__c


            FROM Case


            WHERE

                Buisness_Segment__c = 'SRT'

                AND L2_Assigned__c != null

                AND L2_Assigned_At__c != null

                AND L2_Assigned_At__c <= :cutoffTime

                AND L2_Resolution_Escalation_Sent__c = false


                // Do not escalate L2 if L3 is already assigned
                AND L3_Assigned__c = null


                AND
                (
                    SRT_Case_Status__c = null

                    OR
                    (
                        SRT_Case_Status__c != 'Resolved'
                        AND
                        SRT_Case_Status__c != 'Closed'
                    )
                )

            LIMIT 200
        ];



        if(casesToEscalate.isEmpty()) {
            return;
        }


        sendDealerEscalation(
            casesToEscalate
        );

    }







    private static void sendDealerEscalation(
        List<Case> caseList
    ) {


        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();


        List<Id> caseIds =
            new List<Id>();


        Map<Id,Case> caseMap =
            new Map<Id,Case>();



        for(Case caseRecord : caseList) {



            if(
                caseRecord.L2_Assigned__r == null
                ||
                String.isBlank(
                    caseRecord.L2_Assigned__r.Email__c
                )

                // Safety check
                ||
                caseRecord.L3_Assigned__c != null
            ){
                continue;
            }




            String srNumber =
                String.isNotBlank(
                    caseRecord.SRT_Case_Number__c
                )
                ?
                caseRecord.SRT_Case_Number__c
                :
                caseRecord.CaseNumber;



            String dealerName =
                caseRecord.L2_Assigned__r.Name;



            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();



            mail.setToAddresses(
                new List<String>{
                    caseRecord.L2_Assigned__r.Email__c
                }
            );


            mail.setSubject(
                'Escalation: Case Resolution Pending - '
                +
                srNumber
            );


            mail.setPlainTextBody(

                'Dear '
                +
                dealerName
                +
                ',\n\n'

                +

                'Service Request '
                +
                srNumber
                +
                ' has not been resolved within 24 hours '
                +
                'after L2 assignment.\n\n'

                +

                'Please review the case and provide '
                +
                'necessary resolution updates.\n\n'

                +

                'Regards,\n'
                +
                'Jakson Customer Service'

            );



            emails.add(mail);

            caseIds.add(
                caseRecord.Id
            );

            caseMap.put(
                caseRecord.Id,
                caseRecord
            );

        }



        if(emails.isEmpty()) {
            return;
        }



        Messaging.SendEmailResult[] results =
            Messaging.sendEmail(
                emails,
                false
            );



        User currentUser = [

            SELECT
                Name,
                Email

            FROM User

            WHERE Id =
                :UserInfo.getUserId()

            LIMIT 1

        ];



        List<EmailMessage> emailMessages =
            new List<EmailMessage>();


        List<Case> updates =
            new List<Case>();



        Datetime sentTime =
            System.now();



        for(
            Integer i = 0;
            i < results.size();
            i++
        ){


            Case caseRecord =
                caseMap.get(
                    caseIds[i]
                );



            if(results[i].isSuccess()) {



                EmailMessage em =
                    new EmailMessage();



                em.ParentId =
                    caseRecord.Id;



                em.Subject =
                    'Escalation: Case Resolution Pending - '
                    +
                    caseRecord.CaseNumber;



                em.TextBody =
                    'L2 Dealer resolution pending beyond 24 hours.';



                em.ToAddress =
                    caseRecord
                    .L2_Assigned__r
                    .Email__c;



                em.FromAddress =
                    currentUser.Email;



                em.FromName =
                    currentUser.Name;



                em.Status =
                    '3';



                em.Incoming =
                    false;



                em.MessageDate =
                    sentTime;



                emailMessages.add(em);




                updates.add(
                    new Case(

                        Id =
                            caseRecord.Id,

                        L2_Resolution_Escalation_Sent__c =
                            true,

                        L2_Resolution_Escalation_Sent_At__c =
                            sentTime
                    )
                );

            }

        }



        if(!emailMessages.isEmpty()){

            insert emailMessages;

        }



        if(!updates.isEmpty()){

            update updates;

        }

    }

}
public class CaseL1EscalationHandler implements Schedulable {

    private static final Integer L1_ESCALATION_MINUTES = 30;


    /* =========================================================
       AFTER INSERT
       ========================================================= */

    public static void handleAfterInsert(
        List<Case> newCases
    ) {

        if (
            newCases == null ||
            newCases.isEmpty()
        ) {
            return;
        }

        /*
         * No DML is required here.
         *
         * L1_Escalation_Sent__c should have
         * Default Value = false.
         *
         * The scheduled Apex process checks eligible
         * Cases after 30 minutes.
         */
    }


    /* =========================================================
       AFTER UPDATE
       ========================================================= */

    public static void handleAfterUpdate(
        List<Case> newCases,
        Map<Id, Case> oldCaseMap
    ) {

        if (
            newCases == null ||
            newCases.isEmpty() ||
            oldCaseMap == null
        ) {
            return;
        }

        for (Case caseRecord : newCases) {

            Case oldCaseRecord =
                oldCaseMap.get(
                    caseRecord.Id
                );

            if (oldCaseRecord == null) {
                continue;
            }

            /*
             * L1 Assignment button updates:
             *
             * L1_User_Assigned__c
             * L1_User_Assigned_At__c
             *
             * Once either field is populated,
             * the Case automatically stops qualifying
             * for the L1 escalation.
             *
             * If SRT Case Status becomes Closed,
             * the Case also stops qualifying.
             */
        }
    }


    /* =========================================================
       SCHEDULER ENTRY POINT
       ========================================================= */

    public void execute(
    SchedulableContext sc
) {

    /*
     * 30-minute check:
     * L1 has not been assigned.
     */
    processL1Escalations();


    /*
     * 4-hour check:
     * L1 assigned but Case not resolved.
     */
    processL1ResolutionEscalations();
}


    /* =========================================================
       CHECK L1 ESCALATIONS
       ========================================================= */

    public static void processL1Escalations() {

        Datetime escalationCutoff =
            System.now().addMinutes(
                -L1_ESCALATION_MINUTES
            );


        List<Case> casesForEscalation = [

            SELECT
                Id,
                CaseNumber,
                SRT_Case_Number__c,
                Subject,
                CreatedDate,

                OwnerId,
                Owner.Name,
                Owner.Email,

                L1_User_Assigned__c,
                L1_User_Assigned_At__c,
                L1_Escalation_Sent__c,

                SRT_Case_Status__c,
                Buisness_Segment__c

            FROM Case

            WHERE
                CreatedDate <= :escalationCutoff

                AND Buisness_Segment__c = 'SRT'

                AND (
                    SRT_Case_Status__c = null
                    OR SRT_Case_Status__c != 'Closed'
                )

                AND L1_User_Assigned__c = null

                AND L1_User_Assigned_At__c = null

                AND L1_Escalation_Sent__c = false

            LIMIT 200
        ];


        if (casesForEscalation.isEmpty()) {
            return;
        }


        sendEscalation(
            casesForEscalation
        );
    }
    
    /* =========================================================
   CHECK L1 RESOLUTION ESCALATION - 4 HOURS
   ========================================================= */

public static void processL1ResolutionEscalations() {

    Datetime escalationCutoff =
        System.now().addHours(-4);


    List<Case> casesForEscalation = [
        
        SELECT
        Id,
        CaseNumber,
        SRT_Case_Number__c,
        Subject,
        
        L1_User_Assigned__c,
        L1_User_Assigned__r.Name,
        L1_User_Assigned__r.Email,
        L1_User_Assigned_At__c,
        
        L2_Assigned__c,
        L2_Assigned_At__c,
        
        L1_Resolution_Escalation_Sent__c,
        L1_Resolution_Escalation_Sent_At__c,
        
        SRT_Case_Status__c,
        Buisness_Segment__c
        
        FROM Case
        
        WHERE
        
        Buisness_Segment__c = 'SRT'
        
        AND L1_User_Assigned__c != null
        
        AND L1_User_Assigned_At__c != null
        
        AND L1_User_Assigned_At__c <= :escalationCutoff
        
        
        /*
* Do not send L1 escalation
* if L2 already handled the case
*/
        AND L2_Assigned__c = null
        
        
        AND L1_Resolution_Escalation_Sent__c = false
        
        
        AND (
            SRT_Case_Status__c = null
            OR (
                SRT_Case_Status__c != 'Resolved'
                AND
                SRT_Case_Status__c != 'Closed'
            )
        )
        
        LIMIT 200
    ];


    if (casesForEscalation.isEmpty()) {
        return;
    }


    sendL1ResolutionEscalation(
        casesForEscalation
    );
}


    /* =========================================================
       SEND L1 ESCALATION
       ========================================================= */

    private static void sendEscalation(
        List<Case> caseRecords
    ) {

        if (
            caseRecords == null ||
            caseRecords.isEmpty()
        ) {
            return;
        }


        /* =====================================================
           EMAIL COLLECTIONS
           ===================================================== */

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();


        /*
         * Keeps Case Id aligned with its corresponding email.
         */
        List<Id> caseIdsForEmails =
            new List<Id>();


        /*
         * Keeps all required Case information
         * available after Messaging.sendEmail().
         */
        Map<Id, Case> casesById =
            new Map<Id, Case>();


        /* =====================================================
           CUSTOM NOTIFICATION TYPE
           ===================================================== */

        List<CustomNotificationType> notificationTypes = [

            SELECT Id

            FROM CustomNotificationType

            WHERE DeveloperName =
                'SRT_Case_Escalation'

            LIMIT 1
        ];


        Id notificationTypeId =
            notificationTypes.isEmpty()
                ? null
                : notificationTypes[0].Id;


        /* =====================================================
           PREPARE EMAILS + NOTIFICATIONS
           ===================================================== */

        for (Case caseRecord : caseRecords) {


            /*
             * Safety check.
             *
             * Do not process if:
             *
             * 1. L1 is assigned
             * 2. L1 assignment time exists
             * 3. Escalation already sent
             * 4. Case is Closed
             */
            if (
                caseRecord.L1_User_Assigned__c != null ||
                caseRecord.L1_User_Assigned_At__c != null ||
                caseRecord.L1_Escalation_Sent__c ||
                caseRecord.SRT_Case_Status__c == 'Closed'
            ) {
                continue;
            }


            /*
             * Case Owner can be:
             *
             * User  = 005...
             * Queue = 00G...
             *
             * Current requirement sends escalation
             * only when Case Owner is a User.
             */
            Boolean ownerIsUser =
                caseRecord.OwnerId != null &&
                caseRecord.OwnerId.getSObjectType() ==
                    User.SObjectType;


            if (!ownerIsUser) {
                continue;
            }


            /*
             * Owner must have an email address.
             */
            if (
                caseRecord.Owner == null ||
                String.isBlank(
                    caseRecord.Owner.Email
                )
            ) {
                continue;
            }


            String serviceRequestNumber =
                String.isNotBlank(
                    caseRecord.SRT_Case_Number__c
                )
                    ? caseRecord.SRT_Case_Number__c
                    : caseRecord.CaseNumber;


            String ownerName =
                String.isNotBlank(
                    caseRecord.Owner.Name
                )
                    ? caseRecord.Owner.Name
                    : 'User';


            String emailSubject =
                'Escalation: L1 Assignment Pending - ' +
                serviceRequestNumber;


            String emailBody =
                'Dear ' +
                ownerName +
                ',\n\n' +

                'Service Request ' +
                serviceRequestNumber +
                ' has not been assigned to an L1 user ' +
                'within 30 minutes of Case creation.\n\n' +

                'Please review the Case and take the ' +
                'necessary action.\n\n' +

                'Regards,\n' +
                'Jakson Customer Service';


            /* =================================================
               SALESFORCE CUSTOM NOTIFICATION
               ================================================= */

            if (notificationTypeId != null) {

                try {

                    Messaging.CustomNotification notification =
                        new Messaging.CustomNotification();


                    notification.setTitle(
                        'L1 Assignment Pending'
                    );


                    notification.setBody(
                        'Service Request ' +
                        serviceRequestNumber +
                        ' has not been assigned to L1 ' +
                        'within 30 minutes of Case creation.'
                    );


                    notification.setNotificationTypeId(
                        notificationTypeId
                    );


                    /*
                     * Opens Case after notification click.
                     */
                    notification.setTargetId(
                        caseRecord.Id
                    );


                    /*
                     * Notification recipient =
                     * current Case Owner.
                     */
                    notification.send(
                        new Set<String>{
                            String.valueOf(
                                caseRecord.OwnerId
                            )
                        }
                    );

                } catch (Exception notificationException) {

                    /*
                     * Notification failure should NOT prevent
                     * escalation email from being sent.
                     */
                    System.debug(
                        LoggingLevel.ERROR,
                        'L1 Escalation Notification Failed for Case ' +
                        caseRecord.Id +
                        ': ' +
                        notificationException.getMessage()
                    );
                }
            }


            /* =================================================
               EMAIL TO CASE OWNER
               ================================================= */

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();


            mail.setToAddresses(
                new List<String>{
                    caseRecord.Owner.Email
                }
            );


            mail.setSubject(
                emailSubject
            );


            mail.setPlainTextBody(
                emailBody
            );


            emails.add(
                mail
            );


            caseIdsForEmails.add(
                caseRecord.Id
            );


            casesById.put(
                caseRecord.Id,
                caseRecord
            );
        }


        /* =====================================================
           NOTHING TO SEND
           ===================================================== */

        if (emails.isEmpty()) {
            return;
        }


        /* =====================================================
           SEND EMAILS
           ===================================================== */

        Messaging.SendEmailResult[] emailResults =
            Messaging.sendEmail(
                emails,
                false
            );


        /* =====================================================
           CURRENT USER / EMAIL SENDER
           ===================================================== */

        User currentUser = [

            SELECT
                Id,
                Name,
                Email

            FROM User

            WHERE Id =
                :UserInfo.getUserId()

            LIMIT 1
        ];


        /* =====================================================
           SUCCESSFUL CASES
           ===================================================== */

        List<Case> casesToUpdate =
            new List<Case>();


        /*
         * These EmailMessage records allow the
         * escalation email to appear against
         * the Case in the Emails related list.
         */
        List<EmailMessage> emailMessagesToInsert =
            new List<EmailMessage>();


        /* =====================================================
           PROCESS EMAIL RESULTS
           ===================================================== */

        for (
            Integer i = 0;
            i < emailResults.size();
            i++
        ) {

            Id relatedCaseId =
                caseIdsForEmails[i];


            Case relatedCase =
                casesById.get(
                    relatedCaseId
                );


            if (relatedCase == null) {
                continue;
            }


            /* =================================================
               EMAIL SUCCESS
               ================================================= */

            if (emailResults[i].isSuccess()) {


                String serviceRequestNumber =
                    String.isNotBlank(
                        relatedCase.SRT_Case_Number__c
                    )
                        ? relatedCase.SRT_Case_Number__c
                        : relatedCase.CaseNumber;


                String ownerName =
                    String.isNotBlank(
                        relatedCase.Owner.Name
                    )
                        ? relatedCase.Owner.Name
                        : 'User';


                String emailSubject =
                    'Escalation: L1 Assignment Pending - ' +
                    serviceRequestNumber;


                String emailBody =
                    'Dear ' +
                    ownerName +
                    ',\n\n' +

                    'Service Request ' +
                    serviceRequestNumber +
                    ' has not been assigned to an L1 user ' +
                    'within 30 minutes of Case creation.\n\n' +

                    'Please review the Case and take the ' +
                    'necessary action.\n\n' +

                    'Regards,\n' +
                    'Jakson Customer Service';


                /* =============================================
                   STORE EMAIL AGAINST CASE
                   ============================================= */

                EmailMessage emailMessage =
                    new EmailMessage();


                /*
                 * Relate email to the Case.
                 */
                emailMessage.ParentId =
                    relatedCase.Id;


                emailMessage.Subject =
                    emailSubject;


                emailMessage.TextBody =
                    emailBody;


                emailMessage.ToAddress =
                    relatedCase.Owner.Email;


                emailMessage.FromAddress =
                    currentUser.Email;


                emailMessage.FromName =
                    currentUser.Name;


                emailMessage.MessageDate =
                    System.now();


                /*
                 * false = outgoing email
                 */
                emailMessage.Incoming =
                    false;


                /*
                 * Status 3 = Sent
                 */
                emailMessage.Status =
                    '3';


                emailMessagesToInsert.add(
                    emailMessage
                );


                /* =============================================
                   PREVENT DUPLICATE ESCALATION
                   ============================================= */

                casesToUpdate.add(
                    new Case(
                        Id =
                            relatedCase.Id,

                        L1_Escalation_Sent__c =
                            true
                    )
                );

            }


            /* =================================================
               EMAIL FAILURE
               ================================================= */

            else {

                for (
                    Messaging.SendEmailError emailError :
                    emailResults[i].getErrors()
                ) {

                    System.debug(
                        LoggingLevel.ERROR,
                        'L1 Escalation Email Failed for Case ' +
                        relatedCaseId +
                        ': ' +
                        emailError.getStatusCode() +
                        ' - ' +
                        emailError.getMessage()
                    );
                }
            }
        }


        /* =====================================================
           INSERT EMAILMESSAGE RECORDS
           ===================================================== */

        if (!emailMessagesToInsert.isEmpty()) {

            Database.SaveResult[] emailMessageResults =
                Database.insert(
                    emailMessagesToInsert,
                    false
                );


            /*
             * Log EmailMessage insertion errors,
             * but don't resend the actual escalation email.
             */
            for (
                Integer i = 0;
                i < emailMessageResults.size();
                i++
            ) {

                if (
                    !emailMessageResults[i].isSuccess()
                ) {

                    for (
                        Database.Error databaseError :
                        emailMessageResults[i].getErrors()
                    ) {

                        System.debug(
                            LoggingLevel.ERROR,
                            'Unable to save L1 escalation EmailMessage: ' +
                            databaseError.getStatusCode() +
                            ' - ' +
                            databaseError.getMessage()
                        );
                    }
                }
            }
        }


        /* =====================================================
           MARK L1 ESCALATION AS SENT
           ===================================================== */

        if (!casesToUpdate.isEmpty()) {

            Database.update(
                casesToUpdate,
                false
            );
        }
    }
    
    /* =========================================================
   SEND 4-HOUR L1 RESOLUTION ESCALATION
   ========================================================= */

private static void sendL1ResolutionEscalation(
    List<Case> caseRecords
) {

    if (
        caseRecords == null ||
        caseRecords.isEmpty()
    ) {
        return;
    }


    List<Messaging.SingleEmailMessage> emails =
        new List<Messaging.SingleEmailMessage>();


    List<Id> caseIdsForEmails =
        new List<Id>();


    Map<Id, Case> casesById =
        new Map<Id, Case>();


    /* =====================================================
       PREPARE EMAILS
       ===================================================== */

    for (Case caseRecord : caseRecords) {


        /*
         * Final safety check.
         */
        if (
            caseRecord.L1_User_Assigned__c == null ||
            caseRecord.L1_User_Assigned_At__c == null ||
            caseRecord.L1_Resolution_Escalation_Sent__c ||
            
            // L2 already assigned, no need to escalate L1
            caseRecord.L2_Assigned__c != null ||
            
            caseRecord.SRT_Case_Status__c == 'Resolved' ||
            caseRecord.SRT_Case_Status__c == 'Closed'
        )
        {
            continue;
        }

        /*
         * L1 Assigned User must have an email.
         */
        if (
            caseRecord.L1_User_Assigned__r == null ||
            String.isBlank(
                caseRecord.L1_User_Assigned__r.Email
            )
        ) {
            continue;
        }


        String serviceRequestNumber =
            String.isNotBlank(
                caseRecord.SRT_Case_Number__c
            )
                ? caseRecord.SRT_Case_Number__c
                : caseRecord.CaseNumber;


        String l1UserName =
            String.isNotBlank(
                caseRecord.L1_User_Assigned__r.Name
            )
                ? caseRecord.L1_User_Assigned__r.Name
                : 'User';


        String emailSubject =
            'Escalation: L1 Resolution Pending - ' +
            serviceRequestNumber;


        String emailBody =
            'Dear ' +
            l1UserName +
            ',\n\n' +

            'Service Request ' +
            serviceRequestNumber +
            ' has not been resolved within 4 hours ' +
            'of L1 assignment.\n\n' +

            'Please review the Case and take the ' +
            'necessary action for resolution.\n\n' +

            'Regards,\n' +
            'Jakson Customer Service';


        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();


        /*
         * Send directly to the L1 Assigned User.
         */
        mail.setToAddresses(
            new List<String>{
                caseRecord
                    .L1_User_Assigned__r
                    .Email
            }
        );


        mail.setSubject(
            emailSubject
        );


        mail.setPlainTextBody(
            emailBody
        );


        emails.add(
            mail
        );


        caseIdsForEmails.add(
            caseRecord.Id
        );


        casesById.put(
            caseRecord.Id,
            caseRecord
        );
    }


    if (emails.isEmpty()) {
        return;
    }


    /* =====================================================
       SEND EMAILS
       ===================================================== */

    Messaging.SendEmailResult[] emailResults =
        Messaging.sendEmail(
            emails,
            false
        );


    /* =====================================================
       EMAIL SENDER INFORMATION
       ===================================================== */

    User currentUser = [

        SELECT
            Id,
            Name,
            Email

        FROM User

        WHERE Id =
            :UserInfo.getUserId()

        LIMIT 1
    ];


    List<EmailMessage> emailMessagesToInsert =
        new List<EmailMessage>();


    List<Case> casesToUpdate =
        new List<Case>();


    Datetime sentAt =
        System.now();


    /* =====================================================
       PROCESS RESULTS
       ===================================================== */

    for (
        Integer i = 0;
        i < emailResults.size();
        i++
    ) {

        Id relatedCaseId =
            caseIdsForEmails[i];


        Case relatedCase =
            casesById.get(
                relatedCaseId
            );


        if (relatedCase == null) {
            continue;
        }


        /* =================================================
           EMAIL SUCCESS
           ================================================= */

        if (emailResults[i].isSuccess()) {


            String serviceRequestNumber =
                String.isNotBlank(
                    relatedCase.SRT_Case_Number__c
                )
                    ? relatedCase.SRT_Case_Number__c
                    : relatedCase.CaseNumber;


            String l1UserName =
                String.isNotBlank(
                    relatedCase
                        .L1_User_Assigned__r
                        .Name
                )
                    ? relatedCase
                        .L1_User_Assigned__r
                        .Name
                    : 'User';


            String emailSubject =
                'Escalation: L1 Resolution Pending - ' +
                serviceRequestNumber;


            String emailBody =
                'Dear ' +
                l1UserName +
                ',\n\n' +

                'Service Request ' +
                serviceRequestNumber +
                ' has not been resolved within 4 hours ' +
                'of L1 assignment.\n\n' +

                'Please review the Case and take the ' +
                'necessary action for resolution.\n\n' +

                'Regards,\n' +
                'Jakson Customer Service';


            /* =============================================
               STORE EMAIL AGAINST CASE
               ============================================= */

            EmailMessage emailMessage =
                new EmailMessage();


            emailMessage.ParentId =
                relatedCase.Id;


            emailMessage.Subject =
                emailSubject;


            emailMessage.TextBody =
                emailBody;


            emailMessage.ToAddress =
                relatedCase
                    .L1_User_Assigned__r
                    .Email;


            emailMessage.FromAddress =
                currentUser.Email;


            emailMessage.FromName =
                currentUser.Name;


            emailMessage.MessageDate =
                sentAt;


            emailMessage.Incoming =
                false;


            /*
             * Status 3 = Sent
             */
            emailMessage.Status =
                '3';


            emailMessagesToInsert.add(
                emailMessage
            );


            /* =============================================
               PREVENT DUPLICATE 4-HOUR EMAIL
               ============================================= */

            casesToUpdate.add(
                new Case(
                    Id =
                        relatedCase.Id,

                    L1_Resolution_Escalation_Sent__c =
                        true,

                    L1_Resolution_Escalation_Sent_At__c =
                        sentAt
                )
            );
        }


        /* =================================================
           EMAIL FAILURE
           ================================================= */

        else {

            for (
                Messaging.SendEmailError emailError :
                emailResults[i].getErrors()
            ) {

                System.debug(
                    LoggingLevel.ERROR,

                    'L1 Resolution Escalation Email Failed for Case ' +
                    relatedCaseId +
                    ': ' +
                    emailError.getStatusCode() +
                    ' - ' +
                    emailError.getMessage()
                );
            }
        }
    }


    /* =====================================================
       SAVE EMAILS AGAINST CASE
       ===================================================== */

    if (!emailMessagesToInsert.isEmpty()) {

        Database.insert(
            emailMessagesToInsert,
            false
        );
    }


    /* =====================================================
       MARK ESCALATION SENT
       ===================================================== */

    if (!casesToUpdate.isEmpty()) {

        Database.update(
            casesToUpdate,
            false
        );
    }
}
}
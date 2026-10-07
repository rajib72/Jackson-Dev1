public with sharing class CaseL2AssignmentController {



    private static final String DEALER_TYPE =

        'Dealer';



    /*

     * You already use this Custom Notification Type

     * for SRT escalation notifications.

     *

     * If you create a separate notification type for L2,

     * simply replace this Developer Name.

     */

    private static final String NOTIFICATION_TYPE_NAME =

        'SRT_Case_Escalation';





    /* =========================================================

       SEARCH DEALERS

       ========================================================= */



    @AuraEnabled(cacheable=true)

    public static List<DealerOption> searchDealers(

        String searchTerm,
        Id caseId

    ) {



        if (caseId == null) {
    return new List<DealerOption>();
}





        if (caseId == null) {
            return new List<DealerOption>();
        }

        List<Case> matchingCases = [
            SELECT Id, Product__c, Account.State__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (matchingCases.isEmpty() ||
            String.isBlank(matchingCases[0].Product__c) ||
            matchingCases[0].Account == null ||
            String.isBlank(matchingCases[0].Account.State__c)) {
            return new List<DealerOption>();
        }

        String caseProduct = matchingCases[0].Product__c;
        String caseState = matchingCases[0].Account.State__c;

        String normalizedSearch = String.isBlank(searchTerm)
    ? null
    : '%' + searchTerm.trim() + '%';





        String dealerObjectApiName =

            getDealerObjectApiName();





        String dealerType =

            DEALER_TYPE;




String productFilter = String.escapeSingleQuotes(caseProduct);
String stateFilter = String.escapeSingleQuotes(caseState);

String queryString =
    'SELECT Id, Name, Code__c, Contact_Person__c, ' +
    'Email__c, Mobile_Number__c, City__c, State__c, Vendor_Type__c ' +
    'FROM ' + dealerObjectApiName + ' ' +
    'WHERE Vendor_Type__c = :dealerType ' +
    'AND Product__c INCLUDES (\'' + productFilter + '\') ' +
    'AND State__c INCLUDES (\'' + stateFilter + '\') ';

if (String.isNotBlank(normalizedSearch)) {
    queryString +=
        'AND (' +
        'Name LIKE :normalizedSearch ' +
        'OR Code__c LIKE :normalizedSearch ' +
        'OR Contact_Person__c LIKE :normalizedSearch ' +
        'OR Email__c LIKE :normalizedSearch ' +
        'OR Mobile_Number__c LIKE :normalizedSearch ' +
        'OR City__c LIKE :normalizedSearch' +
        ') ';
}

queryString += 'ORDER BY Name LIMIT 200';







        List<SObject> dealerRecords =

            Database.query(

                queryString

            );





        List<DealerOption> results =

            new List<DealerOption>();





        for (

            SObject dealerRecord :

            dealerRecords

        ) {



            DealerOption option =

                new DealerOption();





            option.id =

                (Id) dealerRecord.get(

                    'Id'

                );





            option.name =

                getStringValue(

                    dealerRecord,

                    'Name'

                );





            option.code =

                getStringValue(

                    dealerRecord,

                    'Code__c'

                );





            option.contactPerson =

                getStringValue(

                    dealerRecord,

                    'Contact_Person__c'

                );





            option.email =

                getStringValue(

                    dealerRecord,

                    'Email__c'

                );





            option.mobile =

                getStringValue(

                    dealerRecord,

                    'Mobile_Number__c'

                );





            option.city =

                getStringValue(

                    dealerRecord,

                    'City__c'

                );





            option.state =

                getStringValue(

                    dealerRecord,

                    'State__c'

                );





            results.add(

                option

            );

        }





        return results;

    }





    /* =========================================================

       ESCALATE CASE TO L2

       ========================================================= */



    @AuraEnabled

    public static L2EscalationResult escalateToL2(

        Id caseId,

        Id dealerId,

        String escalationRemarks

    ) {



        /* =====================================================

           VALIDATION

           ===================================================== */



        if (caseId == null) {



            throw new AuraHandledException(

                'Case Id is required.'

            );

        }





        if (dealerId == null) {



            throw new AuraHandledException(

                'Please select a Dealer.'

            );

        }





        if (

            String.isBlank(

                escalationRemarks

            )

        ) {



            throw new AuraHandledException(

                'Please enter L2 Escalation Remarks.'

            );

        }





        /* =====================================================

           GET AND VALIDATE DEALER

           ===================================================== */



        DealerAssignmentInfo dealer =

            getDealerAssignmentInfo(

                dealerId

            );





        /* =====================================================

           FIELD ACCESS

           ===================================================== */



        if (

            !Case.L2_Assigned__c

                .getDescribe()

                .isUpdateable() ||



            !Case.L2_Assigned_At__c

                .getDescribe()

                .isUpdateable() ||



            !Case.L2_Escalated_By__c

                .getDescribe()

                .isUpdateable() ||



            !Case.L2_Escalation_Remarks_c__c

                .getDescribe()

                .isUpdateable() ||



            !Case.L2_Assigned_Visibility_checkbox__c

                .getDescribe()

                .isUpdateable() ||



            !Case.SRT_Case_Status__c

                .getDescribe()

                .isUpdateable()

        ) {



            throw new AuraHandledException(

                'You do not have permission to update the required L2 escalation fields.'

            );

        }





        /* =====================================================

           GET CASE

           ===================================================== */



        List<Case> caseRecords = [



            SELECT

                Id,

                CaseNumber,

                SRT_Case_Number__c,

                Subject,
                Description,

                Priority,

                SRT_Case_Status__c,



                Product__c,
                Account.State__c,
                L2_Assigned__c,

                L2_Assigned_At__c,

                L2_Escalated_By__c,

                L2_Escalation_Remarks_c__c,

                L2_Assigned_Visibility_checkbox__c



            FROM Case



            WHERE Id = :caseId



            LIMIT 1



            FOR UPDATE

        ];





        if (

            caseRecords.isEmpty()

        ) {



            throw new AuraHandledException(

                'Case could not be found.'

            );

        }





        Case caseRecord =

            caseRecords[0];





        /* =====================================================

           CLOSED CASE VALIDATION

           ===================================================== */



        if (

            caseRecord.SRT_Case_Status__c ==

            'Closed'

        ) {



            throw new AuraHandledException(

                'A Closed Case cannot be escalated to L2.'

            );

        }





        /* =====================================================

           DUPLICATE L2 VALIDATION

           ===================================================== */



        if (

            caseRecord.L2_Assigned__c != null ||

            caseRecord.L2_Assigned_At__c != null

        ) {



            throw new AuraHandledException(

                'This Case has already been escalated to L2.'

            );

        }





        // Enforce Product + Account State eligibility on submission.
        // Search filtering alone does not protect direct Apex requests.
        String accountState = caseRecord.Account == null
            ? null : caseRecord.Account.State__c;
        if (!multiSelectContains(dealer.product, caseRecord.Product__c) ||
            !multiSelectContains(dealer.state, accountState)) {
            throw new AuraHandledException(
                'The selected Dealer does not match this Case Product and Account State.'
            );
        }

        Datetime assignedAt =

            System.now();





        /* =====================================================

           UPDATE CASE

           ===================================================== */



        caseRecord.L2_Assigned__c =

            dealerId;





        caseRecord.L2_Assigned_At__c =

            assignedAt;





        caseRecord.L2_Escalated_By__c =

            UserInfo.getUserId();





        caseRecord.L2_Escalation_Remarks_c__c =

            escalationRemarks.trim();





        caseRecord

            .L2_Assigned_Visibility_checkbox__c =

            true;





        caseRecord.SRT_Case_Status__c =

            'L2 Assigned';





        try {



            update caseRecord;



        } catch (

            DmlException ex

        ) {



            throw new AuraHandledException(

                'Unable to escalate the Case to L2: ' +

                ex.getDmlMessage(0)

            );

        }





        /* =====================================================

           COMMUNICATION

           ===================================================== */



        Boolean notificationSent =

            false;



        Boolean emailSent =

            false;





        /*

         * Notification/email failure should not undo

         * an already completed L2 assignment.

         */

        try {



            notificationSent =

                sendL2Notification(

                    caseRecord,

                    dealer

                );



        } catch (

            Exception notificationException

        ) {



            System.debug(

                LoggingLevel.ERROR,

                'L2 notification failed: ' +

                notificationException.getMessage()

            );

        }





        try {



            emailSent =

                sendL2Email(

                    caseRecord,

                    dealer,

                    escalationRemarks.trim(),

                    assignedAt

                );



        } catch (

            Exception emailException

        ) {



            System.debug(

                LoggingLevel.ERROR,

                'L2 email failed: ' +

                emailException.getMessage()

            );

        }





        /* =====================================================

           WHATSAPP: CUSTOMER FSE VISIT + L2 DEALER ASSIGNMENT



           Customer -> Case.Contact.Phone -> dearcustomer02

           Dealer   -> Dealer_Supplier_Master__c.Mobile_Number__c

                       -> service_requests

           A separate Whatsapp_Messages__c record is created per

           recipient. No Salesforce User is needed for the dealer.

           ===================================================== */



        String customerWhatsAppStatus = 'Not attempted';

        String dealerWhatsAppStatus = 'Not attempted';



        try {

            Map<String, String> whatsAppResults =

                SRT_L2MessageService.queueL2Messages(

                    caseRecord.Id,

                    dealerId

                );



            customerWhatsAppStatus = whatsAppResults.get('customer');

            dealerWhatsAppStatus = whatsAppResults.get('dealer');



        } catch (Exception whatsappException) {

            System.debug(

                LoggingLevel.ERROR,

                'L2 WhatsApp preparation failed. Case: ' +

                caseRecord.Id + ', Error: ' +

                whatsappException.getMessage()

            );

            customerWhatsAppStatus = 'Preparation error; check debug logs.';

            dealerWhatsAppStatus = 'Preparation error; check debug logs.';

        }



        /* =====================================================

           RESPONSE

           ===================================================== */



        L2EscalationResult result =

            new L2EscalationResult();





        result.success =

            true;





        result.caseId =

            caseRecord.Id;





        result.dealerId =

            dealerId;





        result.assignedAt =

            assignedAt;





        result.status =

            caseRecord.SRT_Case_Status__c;





        result.l2Visibility =

            caseRecord

                .L2_Assigned_Visibility_checkbox__c;





        result.notificationSent =

            notificationSent;





        result.emailSent =

            emailSent;



        result.customerWhatsAppStatus = customerWhatsAppStatus;

        result.dealerWhatsAppStatus = dealerWhatsAppStatus;



        return result;

    }





    /* =========================================================

       GET DEALER DETAILS

       ========================================================= */



    private static DealerAssignmentInfo

        getDealerAssignmentInfo(

            Id dealerId

        ) {



        String dealerObjectApiName =

            getDealerObjectApiName();





        String dealerType =

            DEALER_TYPE;





        String queryString =

            'SELECT ' +

                'Id, ' +

                'Name, ' +

                'Email__c, ' +

                'User__c, ' +

                'Contact_Person__c, ' +

                'City__c, ' +
'State__c, ' +
'Product__c, ' +
'Vendor_Type__c ' +

            'FROM ' +

                dealerObjectApiName +

            ' WHERE ' +

                'Id = :dealerId ' +

                'AND Vendor_Type__c = :dealerType ' +

            'LIMIT 1';





        List<SObject> records =

            Database.query(

                queryString

            );





        if (

            records.isEmpty()

        ) {



            throw new AuraHandledException(

                'Only Dealer records can be selected for L2 escalation.'

            );

        }





        SObject dealerRecord =

            records[0];





        DealerAssignmentInfo result =

            new DealerAssignmentInfo();





        result.id =

            (Id) dealerRecord.get(

                'Id'

            );





        result.name =

            getStringValue(

                dealerRecord,

                'Name'

            );





        result.email =

            getStringValue(

                dealerRecord,

                'Email__c'

            );





        result.userId =

            (Id) dealerRecord.get(

                'User__c'

            );





        result.contactPerson =

            getStringValue(

                dealerRecord,

                'Contact_Person__c'

            );





        result.city =

            getStringValue(

                dealerRecord,

                'City__c'

            );





        result.state =

            getStringValue(

                dealerRecord,

                'State__c'

            );





        result.product = getStringValue(dealerRecord, 'Product__c');

        return result;

    }





    /* =========================================================

       SEND SALESFORCE NOTIFICATION

       ========================================================= */



    private static Boolean sendL2Notification(

        Case caseRecord,

        DealerAssignmentInfo dealer

    ) {



        /*

         * Salesforce Custom Notifications can only

         * be sent to Salesforce Users.

         *

         * Dealer Supplier Master.User__c is used

         * as the mapped Salesforce recipient.

         */

        if (

            dealer == null ||

            dealer.userId == null

        ) {



            System.debug(

                LoggingLevel.WARN,

                'L2 notification skipped because Dealer User__c is blank.'

            );



            return false;

        }





        List<CustomNotificationType>

            notificationTypes = [



                SELECT Id



                FROM CustomNotificationType



                WHERE

                    DeveloperName =

                        :NOTIFICATION_TYPE_NAME



                LIMIT 1

            ];





        if (

            notificationTypes.isEmpty()

        ) {



            System.debug(

                LoggingLevel.WARN,

                'L2 notification skipped because Custom Notification Type was not found.'

            );



            return false;

        }





        String serviceRequestNumber =

            getServiceRequestNumber(

                caseRecord

            );





        Messaging.CustomNotification

            notification =

                new Messaging.CustomNotification();





        notification.setTitle(

            'New L2 Case Assignment'

        );





        notification.setBody(

            'Service Request ' +

            serviceRequestNumber +

            ' has been assigned to you for L2 support.'

        );





        notification.setNotificationTypeId(

            notificationTypes[0].Id

        );





        /*

         * Clicking the notification opens the Case.

         */

        notification.setTargetId(

            caseRecord.Id

        );





        notification.send(

            new Set<String>{

                String.valueOf(

                    dealer.userId

                )

            }

        );





        return true;

    }





    /* =========================================================

       SEND DEALER EMAIL

       ========================================================= */



    private static Boolean sendL2Email(

        Case caseRecord,

        DealerAssignmentInfo dealer,

        String escalationRemarks,

        Datetime assignedAt

    ) {



        if (

            dealer == null ||

            String.isBlank(

                dealer.email

            )

        ) {



            System.debug(

                LoggingLevel.WARN,

                'L2 email skipped because Dealer Email__c is blank.'

            );



            return false;

        }





        String serviceRequestNumber =

            getServiceRequestNumber(

                caseRecord

            );





        String dealerName =

            String.isNotBlank(

                dealer.contactPerson

            )

                ? dealer.contactPerson

                : dealer.name;





        if (

            String.isBlank(

                dealerName

            )

        ) {



            dealerName =

                'Dealer';

        }





        String subject =

            'L2 Assignment - Service Request ' +

            serviceRequestNumber;





        String body =

            'Dear ' +

            dealerName +

            ',\n\n' +



            'Service Request ' +

            serviceRequestNumber +

            ' has been escalated to you for L2 support.\n\n' +



            'Case Number: ' +

            serviceRequestNumber +

            '\n' +



            'Description: ' +

            (

                String.isNotBlank(

                    caseRecord.Description

                )

                    ? caseRecord.Description

                    : '-'

            ) +

            '\n' +



            'Priority: ' +

            (

                String.isNotBlank(

                    caseRecord.Priority

                )

                    ? caseRecord.Priority

                    : '-'

            ) +

            '\n' +



            'Escalation Details: ' +

            escalationRemarks +

            '\n\n' +



            'Please review the complaint and coordinate ' +

            'with the Jakson Service Team for further action.\n\n' +



            'Regards,\n' +

            'Jakson SmartCare\n'+

            '1800-103-2600';





        /* =====================================================

           SEND EMAIL

           ===================================================== */



        Messaging.SingleEmailMessage mail =

            new Messaging.SingleEmailMessage();





        mail.setToAddresses(

            new List<String>{

                dealer.email

            }

        );





        mail.setSubject(

            subject

        );





        mail.setPlainTextBody(

            body

        );





        mail.setUseSignature(

            false

        );





        /*

         * We create the EmailMessage ourselves below

         * after successful delivery so that the Case

         * Email related list has exactly one entry.

         */

        mail.setSaveAsActivity(

            false

        );





        Messaging.SendEmailResult[]

            emailResults =

                Messaging.sendEmail(

                    new List<

                        Messaging.SingleEmailMessage

                    >{

                        mail

                    },

                    false

                );





        if (

            emailResults == null ||

            emailResults.isEmpty() ||

            !emailResults[0].isSuccess()

        ) {



            if (

                emailResults != null &&

                !emailResults.isEmpty()

            ) {



                for (

                    Messaging.SendEmailError error :

                    emailResults[0].getErrors()

                ) {



                    System.debug(

                        LoggingLevel.ERROR,

                        'L2 Dealer email failed: ' +

                        error.getStatusCode() +

                        ' - ' +

                        error.getMessage()

                    );

                }

            }





            return false;

        }





        /* =====================================================

           STORE IN CASE EMAIL RELATED LIST

           ===================================================== */



        createCaseEmailLog(

            caseRecord.Id,

            dealer.email,

            subject,

            body,

            assignedAt

        );





        return true;

    }





    /* =========================================================

       CREATE EMAILMESSAGE RECORD

       ========================================================= */



    private static void createCaseEmailLog(

        Id caseId,

        String toAddress,

        String subject,

        String body,

        Datetime messageDate

    ) {



        if (

            caseId == null ||

            String.isBlank(

                toAddress

            )

        ) {



            return;

        }





        User currentUser = [



            SELECT

                Id,

                Name,

                Email



            FROM User



            WHERE

                Id = :UserInfo.getUserId()



            LIMIT 1

        ];





        EmailMessage emailLog =

            new EmailMessage();





        /*

         * ParentId specifically associates EmailMessage

         * with the Case.

         */

        emailLog.ParentId =

            caseId;





        /*

         * RelatedToId provides the Enhanced Email

         * relationship as well.

         */

        emailLog.RelatedToId =

            caseId;





        emailLog.Subject =

            subject;





        emailLog.TextBody =

            body;





        emailLog.ToAddress =

            toAddress;





        emailLog.FromAddress =

            currentUser.Email;





        emailLog.FromName =

            currentUser.Name;





        emailLog.Incoming =

            false;





        /*

         * EmailMessage Status = 3 means Sent.

         */

        emailLog.Status =

            '3';





        emailLog.MessageDate =

            messageDate != null

                ? messageDate

                : System.now();





        insert emailLog;

    }





    /* =========================================================

       SERVICE REQUEST NUMBER

       ========================================================= */



    private static String getServiceRequestNumber(

        Case caseRecord

    ) {



        if (

            caseRecord == null

        ) {



            return '';

        }





        if (

            String.isNotBlank(

                caseRecord.SRT_Case_Number__c

            )

        ) {



            return caseRecord

                .SRT_Case_Number__c;

        }





        return caseRecord.CaseNumber;

    }





    /* =========================================================

       GET DEALER OBJECT FROM LOOKUP

       ========================================================= */



    private static String

        getDealerObjectApiName() {



        List<Schema.SObjectType>

            referenceTypes =

                Case.L2_Assigned__c

                    .getDescribe()

                    .getReferenceTo();





        if (

            referenceTypes == null ||

            referenceTypes.isEmpty()

        ) {



            throw new AuraHandledException(

                'Unable to identify Dealer Supplier Master.'

            );

        }





        return referenceTypes[0]

            .getDescribe()

            .getName();

    }





    /* =========================================================

       NULL SAFE STRING

       ========================================================= */



    private static String getStringValue(

        SObject recordValue,

        String fieldName

    ) {



        Object fieldValue =

            recordValue.get(

                fieldName

            );





        return fieldValue == null

            ? null

            : String.valueOf(

                fieldValue

            );

    }





    /* =========================================================

       INTERNAL DEALER DETAILS

       ========================================================= */



    // Complete-value matching for semicolon-separated multi-selects.
    private static Boolean multiSelectContains(String selections, String target) {
        if (String.isBlank(selections) || String.isBlank(target)) {
            return false;
        }
        for (String selected : selections.split(';')) {
            if (selected.trim().equalsIgnoreCase(target.trim())) {
                return true;
            }
        }
        return false;
    }

    private class DealerAssignmentInfo {

        public String product;



        public Id id;



        public Id userId;



        public String name;



        public String email;



        public String contactPerson;



        public String city;



        public String state;

    }





    /* =========================================================

       DEALER SEARCH WRAPPER

       ========================================================= */



    public class DealerOption {



        @AuraEnabled

        public Id id {

            get;

            set;

        }





        @AuraEnabled

        public String name {

            get;

            set;

        }





        @AuraEnabled

        public String code {

            get;

            set;

        }





        @AuraEnabled

        public String contactPerson {

            get;

            set;

        }





        @AuraEnabled

        public String email {

            get;

            set;

        }





        @AuraEnabled

        public String mobile {

            get;

            set;

        }





        @AuraEnabled

        public String city {

            get;

            set;

        }





        @AuraEnabled

        public String state {

            get;

            set;

        }

    }





    /* =========================================================

       RESULT WRAPPER

       ========================================================= */



    public class L2EscalationResult {



        @AuraEnabled

        public Boolean success {

            get;

            set;

        }





        @AuraEnabled

        public Id caseId {

            get;

            set;

        }





        @AuraEnabled

        public Id dealerId {

            get;

            set;

        }





        @AuraEnabled

        public Datetime assignedAt {

            get;

            set;

        }





        @AuraEnabled

        public String status {

            get;

            set;

        }





        @AuraEnabled

        public Boolean l2Visibility {

            get;

            set;

        }





        @AuraEnabled

        public Boolean notificationSent {

            get;

            set;

        }





        @AuraEnabled

        public Boolean emailSent {

            get;

            set;

        }



        @AuraEnabled

        public String customerWhatsAppStatus {

            get;

            set;

        }



        @AuraEnabled

        public String dealerWhatsAppStatus {

            get;

            set;

        }

    }

}
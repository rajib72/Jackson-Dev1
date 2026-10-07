public with sharing class CaseL3AssignmentController {


    /*
     * =========================================================
     * SUPPLIER SEARCH
     * =========================================================
     */
@AuraEnabled(cacheable=true)
public static List<SupplierWrapper> searchSuppliers(
    String searchKey,
    Id caseId
) {
    List<SupplierWrapper> result = new List<SupplierWrapper>();

    if (caseId == null) {
        return result;
    }

    List<Case> cases = [
        SELECT Id, Product__c, Account.State__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];

    if (
        cases.isEmpty() ||
        String.isBlank(cases[0].Product__c) ||
        cases[0].Account == null ||
        String.isBlank(cases[0].Account.State__c)
    ) {
        return result;
    }

    String caseProduct = String.escapeSingleQuotes(
        cases[0].Product__c
    );

    String caseState = String.escapeSingleQuotes(
        cases[0].Account.State__c
    );

    String searchValue = String.isBlank(searchKey)
        ? null
        : '%' + searchKey.trim() + '%';

    String supplierType = 'Supplier';

    String queryString =
        'SELECT Id, Name, Code__c, Contact_Person__c, ' +
        'Email__c, Alternate_Email__c, Mobile_Number__c, ' +
        'City__c, State__c, Product__c, User__c ' +
        'FROM Dealer_Supplier_Master__c ' +
        'WHERE Vendor_Type__c = :supplierType ' +
        'AND Product__c INCLUDES (\'' + caseProduct + '\') ' +
        'AND State__c INCLUDES (\'' + caseState + '\') ';

    if (String.isNotBlank(searchValue)) {
        queryString +=
            'AND (' +
            'Name LIKE :searchValue ' +
            'OR Code__c LIKE :searchValue ' +
            'OR Contact_Person__c LIKE :searchValue ' +
            'OR Email__c LIKE :searchValue ' +
            'OR Alternate_Email__c LIKE :searchValue ' +
            'OR Mobile_Number__c LIKE :searchValue ' +
            'OR City__c LIKE :searchValue' +
            ') ';
    }

    queryString += 'ORDER BY Name LIMIT 200';

    List<Dealer_Supplier_Master__c> suppliers =
        Database.query(queryString);

    for (Dealer_Supplier_Master__c supplier : suppliers) {
        result.add(new SupplierWrapper(supplier));
    }

    return result;
}






    /*
     * =========================================================
     * ASSIGN L3 SUPPLIER
     * =========================================================
     */
    @AuraEnabled
    public static void escalateToL3(
        Id caseId,
        Id supplierId,
        String remarks
    ){


        if(
            caseId == null ||
            supplierId == null
        ){

            throw new AuraHandledException(
                'Case and Supplier are required.'
            );

        }



        Dealer_Supplier_Master__c supplier = [

            SELECT

                Id,
                Name,
                Email__c,
                User__c,
                Product__c, State__c, Vendor_Type__c

            FROM Dealer_Supplier_Master__c

            WHERE Id = :supplierId

            LIMIT 1

        ];





        Case caseRecord = [

            SELECT

                Id,
                CaseNumber,
                Subject,
                L3_Assigned__c,
                SRT_Case_Status__c,
                Product__c,
Account.State__c

            FROM Case

            WHERE Id = :caseId

            LIMIT 1

        ];

        String accountState = caseRecord.Account == null
    ? null
    : caseRecord.Account.State__c;

if (
    supplier.Vendor_Type__c != 'Supplier' ||
    !multiSelectContains(supplier.Product__c, caseRecord.Product__c) ||
    !multiSelectContains(supplier.State__c, accountState)
) {
    throw new AuraHandledException(
        'The selected Supplier does not match this Case Product and Account State.'
    );
}





        caseRecord.L3_Assigned__c =
            supplier.Id;


        caseRecord.L3_Assigned_At__c =
            System.now();


        caseRecord.L3_Escalated_By__c =
            UserInfo.getUserId();


        caseRecord.L3_Escalation_Remarks__c =
            remarks;


        caseRecord.L3_Assigned_Visibility_checkbox__c =
            true;

        caseRecord.SRT_Case_Status__c =
            'L3 Assigned';




        update caseRecord;




        /*
         * Supplier Email
         */
        if(
            String.isNotBlank(
                supplier.Email__c
            )
        ){

            sendSupplierEmail(
                caseRecord,
                supplier,
                remarks
            );

        }




        /*
         * Salesforce Notification
         */
        if(
            supplier.User__c != null
        ){

            sendCustomNotification(
                caseRecord,
                supplier.User__c
            );

        }


    }


    private static Boolean multiSelectContains(
    String selections,
    String target
) {
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

        /*
     * =========================================================
     * SEND SUPPLIER EMAIL + STORE IN CASE EMAIL RELATED LIST
     * =========================================================
     */
    private static void sendSupplierEmail(
        Case caseRecord,
        Dealer_Supplier_Master__c supplier,
        String remarks
    ){


        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();



        mail.setToAddresses(
            new List<String>{
                supplier.Email__c
            }
        );



        mail.setSubject(
            'L3 Escalation - Case '
            + caseRecord.CaseNumber
        );



        mail.setPlainTextBody(

            'Dear '
            + supplier.Name
            + ',\n\n'

            + 'A case has been escalated to L3.\n\n'

            + 'Case Number : '
            + caseRecord.CaseNumber

            + '\nSubject : '
            + caseRecord.Subject

            + '\n\nEscalation Remarks : '
            + remarks

            + '\n\nPlease review the case and provide resolution.'

            + '\n\nRegards,\nJakson SmartCare\n1800-103-2600'

        );




        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{
                mail
            }
        );





        /*
         * Store Email in Case Related List
         */
        EmailMessage emailRecord =
            new EmailMessage();



        emailRecord.ParentId =
            caseRecord.Id;



        emailRecord.Subject =
            mail.getSubject();



        emailRecord.TextBody =
            mail.getPlainTextBody();



        emailRecord.ToAddress =
            supplier.Email__c;



        emailRecord.Status =
            '3';



        emailRecord.Incoming =
            false;



        emailRecord.MessageDate =
            System.now();

            User currentUser = [
            SELECT Name, Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];


        emailRecord.FromAddress =
            currentUser.Email;

            insert emailRecord;

        }







    /*
     * =========================================================
     * CUSTOM NOTIFICATION TO SUPPLIER USER
     * =========================================================
     */
    private static void sendCustomNotification(
        Case caseRecord,
        Id userId
    ){



        CustomNotificationType notificationType = [

            SELECT Id

            FROM CustomNotificationType

            WHERE DeveloperName =
                'Case_Escalation_Notification'

            LIMIT 1

        ];




        Messaging.CustomNotification notification =
            new Messaging.CustomNotification();




        notification.setTitle(
            'New L3 Escalation'
        );



        notification.setBody(

            'Case '
            + caseRecord.CaseNumber
            + ' has been assigned to you.'

        );



        notification.setNotificationTypeId(
            notificationType.Id
        );



        notification.setTargetId(
            caseRecord.Id
        );



        notification.send(
            new Set<String>{
                userId
            }
        );

    }







    /*
     * =========================================================
     * SUPPLIER WRAPPER
     * =========================================================
     */
    public class SupplierWrapper {



        @AuraEnabled
        public Id id;



        @AuraEnabled
        public String name;



        @AuraEnabled
        public String email;



        @AuraEnabled
        public String city;



        @AuraEnabled
        public String state;



        @AuraEnabled
        public String code;



        @AuraEnabled
        public String contactPerson;



        @AuraEnabled
        public String mobile;





        public SupplierWrapper(
            Dealer_Supplier_Master__c supplier
        ){


            id =
                supplier.Id;



            name =
                supplier.Name;



            email =
                supplier.Email__c;



            city =
                supplier.City__c;



            code =
                supplier.Code__c;



            contactPerson =
                supplier.Contact_Person__c;



            mobile =
                supplier.Mobile_Number__c;

                state = supplier.State__c;


        }


    }

}
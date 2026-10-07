public with sharing class SRT_L1MessageService {

    public static String prepareL1Message(
        Id caseId,
        Id userId
    ) {

        if (caseId == null || userId == null) {
            return 'WhatsApp not queued: Case or User is missing.';
        }

        /* =========================================================
           1. GET THE ASSIGNED L1 SALESFORCE USER

           L1 is a User, not a Dealer Supplier Master record.
           ========================================================= */

        List<User> l1Users = [
            SELECT Id, MobilePhone, Phone, IsActive, UserType
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        if (l1Users.isEmpty()) {
            return 'WhatsApp not queued: Selected L1 Salesforce User was not found.';
        }

        User l1User = l1Users[0];

        if (!l1User.IsActive || l1User.UserType != 'Standard') {
            return 'WhatsApp not queued: L1 must be an active internal Salesforce User.';
        }

        /* =========================================================
           2. L1 RECIPIENT: USER MOBILEPHONE, FALLBACK TO USER PHONE

           Normalize the selected User number to 10 digits.
           Never look up Dealer_Supplier_Master__c for L1.
           ========================================================= */

        String destination = normalizePhone(l1User.MobilePhone);

        if (destination == null) {
            destination = normalizePhone(l1User.Phone);
        }

        if (destination == null) {
            return 'WhatsApp not queued: L1 User MobilePhone/Phone is blank or invalid.';
        }

        /* =========================================================
           3. LOAD CASE, ACCOUNT AND CONTACT
           ========================================================= */

        Case c = [
            SELECT Id,
                   CaseNumber,
                   SRT_Case_No__c,
                   L1_User_Assigned__c,
                   Product__c,
                   Product_Categories__c,
                   Product_Category__c,

                   AccountId,
                   Account.Name,
                   Account.Building_Street__c,
                   Account.District__c,
                   Account.BillingPostalCode,

                   ContactId,
                   Contact.Name,
                   Contact.Phone,
                   Contact.MobilePhone,

                   AssetId

            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.L1_User_Assigned__c != userId) {
            return 'WhatsApp not queued: L1 assignment does not match the selected User.';
        }

        /* =========================================================
           4. IDENTIFY THE ASSET
           ========================================================= */

        Id assetId = c.AssetId;

        if (assetId == null) {

            List<Case_Related_Assets__c> links = [
                SELECT Asset__c
                FROM Case_Related_Assets__c
                WHERE Case__c = :caseId
                AND Asset__c != null
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];

            if (!links.isEmpty()) {
                assetId = links[0].Asset__c;
            }
        }

        Asset assetRec;

        if (assetId != null) {

            List<Asset> assets = [
                SELECT Id,
                       Product2.Name,
                       Warranty_Status__c
                FROM Asset
                WHERE Id = :assetId
                LIMIT 1
            ];

            if (!assets.isEmpty()) {
                assetRec = assets[0];
            }
        }

        /* =========================================================
           5. SERVICE REQUEST NUMBER
           ========================================================= */

        String srNo = String.isNotBlank(c.SRT_Case_No__c)
            ? c.SRT_Case_No__c.trim()
            : c.CaseNumber;

        if (!srNo.toUpperCase().startsWith('SR-')) {
            srNo = 'SR-' + srNo;
        }

        /* =========================================================
           6. PRODUCT
           ========================================================= */

        String product = c.Product__c;

        if (
            String.isBlank(product) &&
            assetRec != null &&
            assetRec.Product2 != null
        ) {
            product = assetRec.Product2.Name;
        }

        product = fallback(product);

        /* =========================================================
           7. PRODUCT CATEGORY
           ========================================================= */

        String category = String.isNotBlank(
            c.Product_Categories__c
        )
            ? c.Product_Categories__c
            : c.Product_Category__c;

        category = fallback(category);

        /* =========================================================
           8. CUSTOMER NAME
           ========================================================= */

        String customerName = c.Contact != null
            ? c.Contact.Name
            : null;

        if (
            String.isBlank(customerName) &&
            c.Account != null
        ) {
            customerName = c.Account.Name;
        }

        customerName = fallback(customerName);

        /* =========================================================
           9. CUSTOMER CONTACT NUMBER
           REMOVE COUNTRY CODE
           ========================================================= */

        String contactNumber;

        if (c.Contact != null) {

            contactNumber = normalizePhone(
                c.Contact.Phone
            );

            if (contactNumber == null) {

                contactNumber = normalizePhone(
                    c.Contact.MobilePhone
                );
            }
        }

        contactNumber = fallback(contactNumber);

        /* =========================================================
           10. LOCATION - CASE ACCOUNT ADDRESS
           ========================================================= */

        List<String> locationParts = new List<String>();

        if (c.Account != null) {

            // Building / Street

            if (
                String.isNotBlank(
                    c.Account.Building_Street__c
                )
            ) {
                locationParts.add(
                    c.Account.Building_Street__c.trim()
                );
            }

            // District

            if (
                String.isNotBlank(
                    c.Account.District__c
                )
            ) {
                locationParts.add(
                    c.Account.District__c.trim()
                );
            }

            // Pincode

            if (
                String.isNotBlank(
                    c.Account.BillingPostalCode
                )
            ) {
                locationParts.add(
                    c.Account.BillingPostalCode.trim()
                );
            }
        }

        String location = locationParts.isEmpty()
            ? 'N/A'
            : String.join(locationParts, ', ');

        /* =========================================================
           11. WARRANTY
           ========================================================= */

        String warranty = 'Validation Pending';

        if (assetRec != null) {

            String status = assetRec.Warranty_Status__c;

            if (String.isNotBlank(status)) {

                status = status.trim().toLowerCase();

                if (
                    new Set<String>{
                        'yes',
                        'active',
                        'valid',
                        'in warranty',
                        'under warranty'
                    }.contains(status)
                ) {
                    warranty = 'Yes';

                } else if (
                    new Set<String>{
                        'no',
                        'expired',
                        'inactive',
                        'out of warranty'
                    }.contains(status)
                ) {
                    warranty = 'No';
                }
            }
        }

        /* =========================================================
           12. PREPARE SEVEN TEMPLATE PARAMETERS

           1 - Service Request Number
           2 - Product
           3 - Product Category
           4 - Customer Name
           5 - Customer Mobile (10 digits)
           6 - Account Address
           7 - Warranty
           ========================================================= */

        List<String> params = new List<String>{
            srNo,
            product,
            category,
            customerName,
            contactNumber,
            location,
            warranty
        };

        /* =========================================================
           13. CREATE WHATSAPP MESSAGE LOG

           Object: Whatsapp_Messages__c

           Initial Status: Pending
           ========================================================= */

        Whatsapp_Messages__c whatsappLog =
            new Whatsapp_Messages__c();

        // Associate message with Case

        whatsappLog.Case__c = caseId;

        // Assigned L1 Salesforce User mobile number

        whatsappLog.Recipient_Number__c =
            destination;

        // Existing Go2Market campaign

        whatsappLog.Campaign_Name__c =
    'Request';

        // Initial message status

        whatsappLog.Status__c =
            'Pending';

        // Request timestamp

        whatsappLog.Requested_At__c =
            System.now();

        /* =========================================================
           14. STORE MESSAGE PARAMETERS

           Store the actual campaign parameters.

           Do not store the API key.

           ========================================================= */

        Map<String, Object> messageDetails =
            new Map<String, Object>{

                'messageType' => 'L1 Assignment',

               'campaignName' => 'Request',

                'destination' => destination,

                'templateParams' => params
            };

        whatsappLog.Message__c =
            JSON.serialize(messageDetails);

        /* =========================================================
           15. INSERT WHATSAPP LOG
           ========================================================= */

        insert whatsappLog;

        System.debug(
            LoggingLevel.INFO,
            'L1 WhatsApp Log Created. Log Id: ' +
            whatsappLog.Id +
            ', Case Id: ' +
            caseId
        );

        /* =========================================================
           16. QUEUE WHATSAPP API REQUEST
           ========================================================= */

        try {

            Id jobId = System.enqueueJob(
                new SRT_L1MessageQueueable(
                    caseId,
                    destination,
                    params,
                    whatsappLog.Id
                )
            );

            System.debug(
                LoggingLevel.INFO,
                'L1 WhatsApp Queueable Created. Job Id: ' +
                jobId +
                ', Log Id: ' +
                whatsappLog.Id
            );

            return 'L1 WhatsApp request queued successfully. ' +
                'Job Id: ' + jobId;

        } catch (Exception queueException) {

            /* =====================================================
               UPDATE LOG IF QUEUEING FAILS
               ===================================================== */

            whatsappLog.Status__c =
                'Failed';

            String failureMessage =
                'Unable to queue WhatsApp message: ' +
                queueException.getMessage();

            whatsappLog.Failure_Reason__c =
                failureMessage.length() > 32768
                    ? failureMessage.substring(0, 32768)
                    : failureMessage;

            update whatsappLog;

            System.debug(
                LoggingLevel.ERROR,
                'L1 WhatsApp Queue Failed. Case: ' +
                caseId +
                ', Log: ' +
                whatsappLog.Id +
                ', Error: ' +
                queueException.getMessage()
            );

            return 'L1 assignment completed, but WhatsApp ' +
                'could not be queued. Check the WhatsApp Message Log.';
        }
    }

    /* =========================================================
       PHONE NUMBER NORMALIZATION

       +919876543210   -> 9876543210
       919876543210    -> 9876543210
       00919876543210 -> 9876543210
       9876543210      -> 9876543210

       OUTPUT: 10 DIGITS ONLY
       ========================================================= */

    private static String normalizePhone(String phone) {

        if (String.isBlank(phone)) {
            return null;
        }

        String digits = phone.replaceAll(
            '[^0-9]',
            ''
        );

        // Remove 0091

        if (
            digits.length() == 14 &&
            digits.startsWith('0091')
        ) {
            digits = digits.substring(4);
        }

        // Remove 91

        if (
            digits.length() == 12 &&
            digits.startsWith('91')
        ) {
            digits = digits.substring(2);
        }

        // Validate 10-digit Indian mobile number

        if (
            digits.length() != 10 ||
            !Pattern.matches(
                '[6-9][0-9]{9}',
                digits
            )
        ) {
            return null;
        }

        return digits;
    }

    /* =========================================================
       FALLBACK VALUE
       ========================================================= */

    private static String fallback(String value) {

        return String.isBlank(value)
            ? 'N/A'
            : value.trim();
    }
}
public with sharing class CaseL1AssignmentController {
    
    private static final String L1_NOTIFICATION_TYPE =
        'L1_Assignment_Notification';
    
    
    /* =========================================================
GET ASSIGNMENT CONTEXT
========================================================= */
    
    @AuraEnabled(cacheable=true)
    public static String getAssignmentContext(Id caseId) {
        
        if (caseId == null) {
            throw new AuraHandledException(
                'Case Id is required.'
            );
        }
        
        Case caseRec = [
            SELECT Id,
            CaseNumber,
            SRT_Case_No__c,
            SRT_Case_Status__c,
            Subject,
            Priority,
            AccountId,
            Account.Name,
            Account.BillingState,
            Product__c,
            ContactId,
            Contact.Name,
            AssetId,
            OwnerId,
            Owner.Name,
            L1_User_Assigned__c,
            L1_User_Assigned_At__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        /* =========================================================
GET CASE RELATED ASSETS
========================================================= */
        
        List<Case_Related_Assets__c> caseAssetLinks = [
            SELECT Id,
            Asset__c
            FROM Case_Related_Assets__c
            WHERE Case__c = :caseId
            ORDER BY CreatedDate ASC
        ];
        
        Set<Id> assetIds =
            new Set<Id>();
        
        if (caseRec.AssetId != null) {
            assetIds.add(
                caseRec.AssetId
            );
        }
        
        for (
            Case_Related_Assets__c link :
            caseAssetLinks
        ) {
            
            if (link.Asset__c != null) {
                
                assetIds.add(
                    link.Asset__c
                );
            }
        }
        
        List<AssetInfo> assetInfoList =
            new List<AssetInfo>();
        
        if (!assetIds.isEmpty()) {
            
            for (
                Asset assetRec :
                [
                    SELECT Id,
                    Name,
                    Site_Name__c,
                    PV_Module_Rating_Model_No__c
                    FROM Asset
                    WHERE Id IN :assetIds
                    ORDER BY Name
                ]
            ) {
                
                AssetInfo info =
                    new AssetInfo();
                
                info.assetId =
                    assetRec.Id;
                
                info.assetName =
                    assetRec.Name;
                
                info.siteName =
                    assetRec.Site_Name__c;
                
                info.pvModuleRatingModel =
                    assetRec.PV_Module_Rating_Model_No__c;
                
                assetInfoList.add(
                    info
                );
            }
        }
        
        
        /* =========================================================
ACTIVE INTERNAL USERS
========================================================= */
        
        List<UserInfo> userInfoList =
            new List<UserInfo>();

        
        for (
            User userRec :
            [
                SELECT Id,
                Name,
                Email,
                Profile.Name,
                Product__c,
                State__c
                FROM User
                WHERE IsActive = true
                AND UserType = 'Standard'
                ORDER BY Name
            ]
        ) {
            // Only display users matching both the Case product and Account state.
            if (!isUserEligible(
                caseRec.Product__c,
                caseRec.Account != null ? caseRec.Account.BillingState : null,
                userRec.Product__c,
                userRec.State__c
            )) {
                continue;
            }

            UserInfo info =
                new UserInfo();
            
            info.userId =
                userRec.Id;
            
            info.name =
                userRec.Name;
            
            info.email =
                userRec.Email;
            
            info.profileName =
                userRec.Profile != null
                ? userRec.Profile.Name
                : null;
            
            if (userInfoList.size() < 500) {
                userInfoList.add(info);
            }
        }
        
        
        /* =========================================================
RESPONSE
========================================================= */
        
        AssignmentContext context =
            new AssignmentContext();
        
        context.caseId =
            caseRec.Id;
        
        context.caseNumber =
            caseRec.CaseNumber;
        
        context.srtCaseNumber =
            caseRec.SRT_Case_No__c;
        
        context.subject =
            caseRec.Subject;
        
        context.status =
            caseRec.SRT_Case_Status__c;
        
        context.priority =
            caseRec.Priority;
        
        context.accountName =
            caseRec.Account != null
            ? caseRec.Account.Name
            : null;
        
        context.contactName =
            caseRec.Contact != null
            ? caseRec.Contact.Name
            : null;
        
        context.ownerName =
            caseRec.Owner != null
            ? caseRec.Owner.Name
            : null;
        
        context.l1UserAssignedId =
            caseRec.L1_User_Assigned__c;
        
        context.l1UserAssignedAt =
            caseRec.L1_User_Assigned_At__c;
        
        context.assets =
            assetInfoList;
        
        context.users =
            userInfoList;
        
        return JSON.serialize(
            context
        );
    }
    
    
    /* =========================================================
ASSIGN L1 USER
========================================================= */
    
    @AuraEnabled
    public static String assignL1(
        Id caseId,
        Id userId
    ) {
        
        if (caseId == null) {
            throw new AuraHandledException(
                'Case Id is required.'
            );
        }
        
        if (userId == null) {
            throw new AuraHandledException(
                'Please select a User.'
            );
        }
        
        String currentStep =
            'Validating selected User';
        
        Savepoint sp =
            Database.setSavepoint();
        
        try {
            
            /* =========================================================
SELECTED USER
========================================================= */
            
            User selectedUser = [
                SELECT Id,
                Name,
                Email,
                IsActive,
                UserType,
                Product__c,
                State__c
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];
            
            if (!selectedUser.IsActive) {
                
                throw new L1AssignmentException(
                    'The selected User is inactive.'
                );
            }
            
            if (selectedUser.UserType != 'Standard') {
                
                throw new L1AssignmentException(
                    'Please select an internal Salesforce User.'
                );
            }
            
            
            /* =========================================================
CASE
========================================================= */
            
            currentStep =
                'Loading Case';
            
            Case caseRec = [
                SELECT Id,
                CaseNumber,
                SRT_Case_No__c,
                SRT_Case_Status__c,
                Subject,
                Priority,
                AccountId,
                Account.Name,
                Account.BillingState,
                Product__c,
                OwnerId,
                AssetId,
                L1_User_Assigned__c,
                L1_User_Assigned_At__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
                FOR UPDATE
            ];

            currentStep = 'Validating Product and State';
            if (!isUserEligible(
                caseRec.Product__c,
                caseRec.Account != null ? caseRec.Account.BillingState : null,
                selectedUser.Product__c,
                selectedUser.State__c
            )) {
                throw new L1AssignmentException(
                    'The selected User does not match the Case Product and Account State.'
                );
            }

            /* Store previous L1 User to avoid duplicate SMS */

Id previousL1UserId =
    caseRec.L1_User_Assigned__c;
            
            
            /* =========================================================
SHARE CASE
========================================================= */
            
            currentStep =
                'Sharing Case';
            
            if (caseRec.OwnerId != userId) {
                
                grantCaseEditAccess(
                    caseId,
                    userId
                );
            }
            
            
            /* =========================================================
CASE RELATED ASSETS
========================================================= */
            
            currentStep =
                'Loading Case Related Assets';
            
            List<Case_Related_Assets__c>
                caseAssetRecords = [
                    SELECT Id,
                    OwnerId,
                    Asset__c
                    FROM Case_Related_Assets__c
                    WHERE Case__c = :caseId
                ];
            
            Set<Id> caseAssetIds =
                new Set<Id>();
            
            Set<Id> caseAssetIdsToShare =
                new Set<Id>();
            
            Set<Id> assetIds =
                new Set<Id>();
            
            if (caseRec.AssetId != null) {
                
                assetIds.add(
                    caseRec.AssetId
                );
            }
            
            for (
                Case_Related_Assets__c record :
                caseAssetRecords
            ) {
                
                caseAssetIds.add(
                    record.Id
                );
                
                if (record.OwnerId != userId) {
                    
                    caseAssetIdsToShare.add(
                        record.Id
                    );
                }
                
                if (record.Asset__c != null) {
                    
                    assetIds.add(
                        record.Asset__c
                    );
                }
            }
            
            
            /* =========================================================
SHARE CASE RELATED ASSETS
========================================================= */
            
            currentStep =
                'Sharing Case Related Assets';
            
            grantCustomEditAccess(
                'Case_Related_Assets__c',
                caseAssetIdsToShare,
                userId
            );
            
            
            /* =========================================================
SHARE ASSETS
========================================================= */
            
            currentStep =
                'Sharing Assets';
            
            if (!assetIds.isEmpty()) {
                
                List<Asset> assets = [
                    SELECT Id,
                    OwnerId
                    FROM Asset
                    WHERE Id IN :assetIds
                ];
                
                Set<Id> assetsToShare =
                    new Set<Id>();
                
                for (
                    Asset assetRec :
                    assets
                ) {
                    
                    if (assetRec.OwnerId != userId) {
                        
                        assetsToShare.add(
                            assetRec.Id
                        );
                    }
                }
                
                grantAssetEditAccess(
                    assetsToShare,
                    userId
                );
            }
            
            
            /* =========================================================
CASE RELATED SERIAL NUMBERS
========================================================= */
            
            currentStep =
                'Loading Case Related Asset Serial Numbers';
            
            List<Case_Related_Assets_Serial_No__c>
                caseSerialRecords =
                new List<Case_Related_Assets_Serial_No__c>();
            
            if (!caseAssetIds.isEmpty()) {
                
                caseSerialRecords = [
                    SELECT Id,
                    OwnerId,
                    Asset_Serial_No__c
                    FROM Case_Related_Assets_Serial_No__c
                    WHERE Case_Related_Assets__c
                    IN :caseAssetIds
                ];
            }
            
            Set<Id> caseSerialIdsToShare =
                new Set<Id>();
            
            Set<Id> assetSerialIds =
                new Set<Id>();
            
            for (
                Case_Related_Assets_Serial_No__c record :
                caseSerialRecords
            ) {
                
                if (record.OwnerId != userId) {
                    
                    caseSerialIdsToShare.add(
                        record.Id
                    );
                }
                
                if (
                    record.Asset_Serial_No__c != null
                ) {
                    
                    assetSerialIds.add(
                        record.Asset_Serial_No__c
                    );
                }
            }
            
            
            /* =========================================================
SHARE CASE RELATED SERIAL NUMBERS
========================================================= */
            
            currentStep =
                'Sharing Case Related Asset Serial Numbers';
            
            grantCustomEditAccess(
                'Case_Related_Assets_Serial_No__c',
                caseSerialIdsToShare,
                userId
            );
            
            
            /* =========================================================
SHARE ASSET SERIAL NUMBERS
========================================================= */
            
            currentStep =
                'Sharing Asset Serial Numbers';
            
            if (!assetSerialIds.isEmpty()) {
                
                List<Asset_Serial_No__c>
                    assetSerialRecords = [
                        SELECT Id,
                        OwnerId
                        FROM Asset_Serial_No__c
                        WHERE Id IN :assetSerialIds
                    ];
                
                Set<Id> serialIdsToShare =
                    new Set<Id>();
                
                for (
                    Asset_Serial_No__c serialRec :
                    assetSerialRecords
                ) {
                    
                    if (serialRec.OwnerId != userId) {
                        
                        serialIdsToShare.add(
                            serialRec.Id
                        );
                    }
                }
                
                grantCustomEditAccess(
                    'Asset_Serial_No__c',
                    serialIdsToShare,
                    userId
                );
            }
            
            
            /* =========================================================
CASE RELATED WARRANTIES
========================================================= */
            
            currentStep =
                'Loading Case Related Asset Warranties';
            
            List<Case_Related_Asset_Warranty__c>
                caseWarrantyRecords = [
                    SELECT Id,
                    OwnerId,
                    Asset_Warranty__c
                    FROM Case_Related_Asset_Warranty__c
                    WHERE Case__c = :caseId
                ];
            
            Set<Id> caseWarrantyIdsToShare =
                new Set<Id>();
            
            for (
                Case_Related_Asset_Warranty__c record :
                caseWarrantyRecords
            ) {
                
                if (record.OwnerId != userId) {
                    
                    caseWarrantyIdsToShare.add(
                        record.Id
                    );
                }
            }
            
            
            /* =========================================================
SHARE CASE RELATED WARRANTIES
========================================================= */
            
            currentStep =
                'Sharing Case Related Asset Warranties';
            
            grantCustomEditAccess(
                'Case_Related_Asset_Warranty__c',
                caseWarrantyIdsToShare,
                userId
            );
            
            
            /* =========================================================
UPDATE CASE L1 ASSIGNMENT FIELDS
========================================================= */
            
            currentStep =
                'Updating L1 Assignment Details';
            
            caseRec.L1_User_Assigned__c =
                userId;
            
            caseRec.L1_User_Assigned_At__c =
                System.now();
            
            /*
* SRT Case lifecycle status.
* Standard Case.Status is intentionally not modified.
*/
            caseRec.SRT_Case_Status__c =
                'L1 Assigned';
            
            update caseRec;
            
            
            /* =========================================================
SEND SALESFORCE NOTIFICATION
========================================================= */
            
            currentStep =
                'Sending L1 Assignment Notification';
            
            sendL1AssignmentNotification(
                caseRec,
                userId
            );
            
            
            /* =========================================================
SEND EMAIL + LOG EMAIL
========================================================= */
            
            currentStep =
                'Sending and Logging L1 Assignment Email';
            
            sendL1AssignmentEmail(
                caseRec,
                selectedUser
            );

            /* =========================================================
   SEND L1 ASSIGNMENT SMS
   ========================================================= */

String smsStatus =
    'SMS not queued: L1 User is already assigned.';

if (previousL1UserId != userId) {

    try {

        smsStatus = sendL1AssignmentMessage(
            caseRec.Id,
            userId
        );

    } catch (Exception smsException) {

        System.debug(
            LoggingLevel.ERROR,
            'L1 SMS preparation failed. Case: ' +
            caseRec.Id +
            ', Error: ' +
            smsException.getMessage()
        );

        smsStatus =
            'SMS could not be queued. Check Salesforce logs.';
    }
}
            
            
            /* =========================================================
RESULT
========================================================= */
            
            currentStep =
                'Preparing Assignment Result';
            
            AssignmentResult result =
                new AssignmentResult();
            
            result.success =
                true;
            
            result.userId =
                selectedUser.Id;
            
            result.userName =
                selectedUser.Name;
            
            result.assignedAt =
                caseRec.L1_User_Assigned_At__c;
            
            result.caseRelatedAssetCount =
                caseAssetRecords.size();
            
            result.caseRelatedSerialCount =
                caseSerialRecords.size();
            
            result.caseRelatedWarrantyCount =
                caseWarrantyRecords.size();
            
            result.message =
    'L1 User ' +
    selectedUser.Name +
    ' has been assigned successfully with Edit access. ' +
    'Notification and email have been sent. ' +
    smsStatus;
            
            return JSON.serialize(
                result
            );
            
        } catch (Exception e) {
            
            Database.rollback(
                sp
            );
            
            throw new AuraHandledException(
                'L1 Assignment failed during [' +
                currentStep +
                ']. Error: ' +
                e.getMessage()
            );
        }
    }

    /* =========================================================
   SEND L1 ASSIGNMENT SMS
   ========================================================= */

private static String sendL1AssignmentMessage(
    Id caseId,
    Id userId
) {

    return SRT_L1MessageService.prepareL1Message(
        caseId,
        userId
    );
}
    
    
    /* =========================================================
SEND L1 ASSIGNMENT NOTIFICATION
========================================================= */


    
    private static void sendL1AssignmentNotification(
        Case caseRec,
        Id userId
    ) {
        
        List<CustomNotificationType>
            notificationTypes = [
                SELECT Id,
                DeveloperName
                FROM CustomNotificationType
                WHERE DeveloperName =
                :L1_NOTIFICATION_TYPE
                LIMIT 1
            ];
        
        if (notificationTypes.isEmpty()) {
            
            throw new L1AssignmentException(
                'Custom Notification Type "' +
                L1_NOTIFICATION_TYPE +
                '" was not found.'
            );
        }
        
        CustomNotificationType notificationType =
            notificationTypes[0];
        
        Messaging.CustomNotification notification =
            new Messaging.CustomNotification();
        
        notification.setTitle(
            'New L1 Case Assignment'
        );
        
        String notificationBody =
            'Case ' +
            caseRec.CaseNumber;
        
        if (
            String.isNotBlank(
                caseRec.SRT_Case_No__c
            )
        ) {
            
            notificationBody +=
                ' (' +
                caseRec.SRT_Case_No__c +
                ')';
        }
        
        notificationBody +=
            ' has been assigned to you for L1 action.';
        
        notification.setBody(
            notificationBody
        );
        
        notification.setNotificationTypeId(
            String.valueOf(
                notificationType.Id
            )
        );
        
        notification.setTargetId(
            String.valueOf(
                caseRec.Id
            )
        );
        
        Set<String> recipientIds =
            new Set<String>{
                String.valueOf(
                    userId
                )
                    };
                        
                        notification.send(
                            recipientIds
                        );
    }
    
    
    /* =========================================================
SEND L1 ASSIGNMENT EMAIL
========================================================= */
    
    
private static void sendL1AssignmentEmail(
    Case caseRec,
    User selectedUser
) {

    if (
        selectedUser == null ||
        String.isBlank(selectedUser.Email)
    ) {
        throw new L1AssignmentException(
            'The selected L1 User does not have an email address.'
        );
    }


    /* =========================================================
       LOAD EMAIL DETAILS
       ========================================================= */

    Case emailCase = [
        SELECT Id,
            CaseNumber,
            SRT_Case_No__c,
            Product__c,
            Product_Categories__c,
            AccountId,
            Account.Name,
            Account.BillingStreet,
            Account.BillingCity,
            Account.BillingState,
            Account.BillingPostalCode,
            Account.BillingCountry,
            ContactId,
            Contact.Phone,
            Contact.MobilePhone,
            AssetId
        FROM Case
        WHERE Id = :caseRec.Id
        LIMIT 1
    ];


    /* =========================================================
       GET ALL RELATED ASSETS
       ========================================================= */

    Set<Id> assetIds = new Set<Id>();

    if (emailCase.AssetId != null) {
        assetIds.add(
            emailCase.AssetId
        );
    }


    for (
        Case_Related_Assets__c caseAsset :
        [
            SELECT Asset__c
            FROM Case_Related_Assets__c
            WHERE Case__c = :emailCase.Id
        ]
    ) {

        if (caseAsset.Asset__c != null) {
            assetIds.add(
                caseAsset.Asset__c
            );
        }
    }


    List<Asset> relatedAssets =
        new List<Asset>();

    if (!assetIds.isEmpty()) {

        relatedAssets = [
            SELECT Id,
                Name,
                Warranty_Status__c
            FROM Asset
            WHERE Id IN :assetIds
            ORDER BY Name
        ];
    }


    /* =========================================================
       SERVICE REQUEST NUMBER
       ========================================================= */

    String rawServiceRequestNumber =
        String.isNotBlank(
            emailCase.SRT_Case_No__c
        )
        ? emailCase.SRT_Case_No__c
        : emailCase.CaseNumber;


    String serviceRequestNumber =
        rawServiceRequestNumber != null &&
        rawServiceRequestNumber
        .toUpperCase()
        .startsWith('SR-')
        ? rawServiceRequestNumber
        : 'SR-' +
            rawServiceRequestNumber;


    /* =========================================================
       CUSTOMER
       ========================================================= */

    String customerName =
        emailCase.Account != null &&
        String.isNotBlank(
            emailCase.Account.Name
        )
        ? emailCase.Account.Name
        : 'N/A';


    /* =========================================================
       CONTACT NUMBER
       ========================================================= */

    String contactNumber = 'N/A';

    if (emailCase.Contact != null) {

        if (
            String.isNotBlank(
                emailCase.Contact.MobilePhone
            )
        ) {
            contactNumber =
                emailCase.Contact.MobilePhone;

        } else if (
            String.isNotBlank(
                emailCase.Contact.Phone
            )
        ) {
            contactNumber =
                emailCase.Contact.Phone;
        }
    }


    /* =========================================================
       PRODUCT
       Case.Product__c
       ========================================================= */

    String productDisplay =
        String.isNotBlank(
            emailCase.Product__c
        )
        ? emailCase.Product__c
        : 'N/A';


    /* =========================================================
       PRODUCT CATEGORY
       Case.Product_Categories__c
       ========================================================= */

    String productCategoryDisplay =
        String.isNotBlank(
            emailCase.Product_Categories__c
        )
        ? emailCase.Product_Categories__c
        : 'N/A';


    /* =========================================================
       LOCATION
       CASE ACCOUNT BILLING ADDRESS
       ========================================================= */

    List<String> locationParts =
        new List<String>();

    if (emailCase.Account != null) {

        if (
            String.isNotBlank(
                emailCase.Account.BillingStreet
            )
        ) {
            locationParts.add(
                emailCase.Account.BillingStreet
            );
        }

        if (
            String.isNotBlank(
                emailCase.Account.BillingCity
            )
        ) {
            locationParts.add(
                emailCase.Account.BillingCity
            );
        }

        if (
            String.isNotBlank(
                emailCase.Account.BillingState
            )
        ) {
            locationParts.add(
                emailCase.Account.BillingState
            );
        }

        if (
            String.isNotBlank(
                emailCase.Account.BillingPostalCode
            )
        ) {
            locationParts.add(
                emailCase.Account.BillingPostalCode
            );
        }

        if (
            String.isNotBlank(
                emailCase.Account.BillingCountry
            )
        ) {
            locationParts.add(
                emailCase.Account.BillingCountry
            );
        }
    }


    String locationDisplay =
        !locationParts.isEmpty()
        ? String.join(
            locationParts,
            ', '
        )
        : 'N/A';


    /* =========================================================
       WARRANTY

       Existing Asset based logic retained.
       ========================================================= */

    List<String> warrantyValues =
        new List<String>();


    for (Asset assetRec : relatedAssets) {

        String warrantyValue =
            getWarrantyEmailValue(
                assetRec.Warranty_Status__c
            );

        if (
            !warrantyValues.contains(
                warrantyValue
            )
        ) {
            warrantyValues.add(
                warrantyValue
            );
        }
    }


    String warrantyDisplay =
        !warrantyValues.isEmpty()
        ? String.join(
            warrantyValues,
            ', '
        )
        : 'Validation Pending';


    /* =========================================================
       EMAIL SUBJECT
       ========================================================= */

    String emailSubject =
        'SERVICE REQUEST : [' +
        serviceRequestNumber +
        ']';


    /* =========================================================
       PLAIN TEXT EMAIL BODY
       ========================================================= */

    String plainTextBody =
        'SERVICE REQUEST : [' +
        serviceRequestNumber +
        ']\n\n' +

        'Product: ' +
        productDisplay +
        ' | Product Category: ' +
        productCategoryDisplay +
        '\n' +

        'Customer: ' +
        customerName +
        '\n' +

        'Contact: ' +
        contactNumber +
        '\n' +

        'Location: ' +
        locationDisplay +
        '\n' +

        'Warranty: ' +
        warrantyDisplay +
        '\n\n' +

        'Action Required: ' +
        'Please contact the customer and arrange the service visit.' +
        '\n\n' +

        '– Jakson SmartCare' +
        '\n\n' +

        '1800-103-2600';


    /* =========================================================
       HTML EMAIL BODY
       ========================================================= */

    String htmlBody =
        '<html>' +

        '<body style="' +
        'font-family:Arial,sans-serif;' +
        'font-size:14px;' +
        'color:#181818;' +
        'line-height:1.6;' +
        '">' +

        '<p>' +
        '<strong>SERVICE REQUEST : [' +
        escapeHtml(
            serviceRequestNumber
        ) +
        ']</strong>' +
        '</p>' +

        '<p>' +

        '<strong>Product:</strong> ' +
        escapeHtml(
            productDisplay
        ) +

        ' &nbsp;|&nbsp; ' +

        '<strong>Product Category:</strong> ' +
        escapeHtml(
            productCategoryDisplay
        ) +

        '</p>' +

        '<p>' +
        '<strong>Customer:</strong> ' +
        escapeHtml(
            customerName
        ) +
        '</p>' +

        '<p>' +
        '<strong>Contact:</strong> ' +
        escapeHtml(
            contactNumber
        ) +
        '</p>' +

        '<p>' +
        '<strong>Location:</strong> ' +
        escapeHtml(
            locationDisplay
        ) +
        '</p>' +

        '<p>' +
        '<strong>Warranty:</strong> ' +
        escapeHtml(
            warrantyDisplay
        ) +
        '</p>' +

        '<br/>' +

        '<p>' +
        '<strong>Action Required:</strong> ' +
        'Please contact the customer and arrange the service visit.' +
        '</p>' +

        '<br/>' +

        '<p>' +
        '<strong>Jakson SmartCare</strong>' +
        '</p>' +

        '<p>' +
        '<strong>1800-103-2600</strong>' +
        '</p>' +

        '</body>' +

        '</html>';


    /* =========================================================
       PREPARE EMAIL
       ========================================================= */

    Messaging.SingleEmailMessage mail =
        new Messaging.SingleEmailMessage();

    mail.setToAddresses(
        new List<String>{
            selectedUser.Email
        }
    );

    mail.setSubject(
        emailSubject
    );

    mail.setPlainTextBody(
        plainTextBody
    );

    mail.setHtmlBody(
        htmlBody
    );

    /*
     * Existing explicit EmailMessage logging
     * is retained below.
     */
    mail.setSaveAsActivity(
        false
    );


    /* =========================================================
       SEND EMAIL
       ========================================================= */

    Messaging.SendEmailResult[] emailResults =
        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[]{
                mail
            }
        );


    if (
        emailResults == null ||
        emailResults.isEmpty()
    ) {
        throw new L1AssignmentException(
            'No response was received while sending the L1 Assignment email.'
        );
    }


    if (!emailResults[0].isSuccess()) {

        String errorMessage =
            'Unable to send L1 Assignment email.';

        if (
            emailResults[0].getErrors() != null &&
            !emailResults[0]
            .getErrors()
            .isEmpty()
        ) {
            errorMessage +=
                ' ' +
                emailResults[0]
                .getErrors()[0]
                .getMessage();
        }

        throw new L1AssignmentException(
            errorMessage
        );
    }


    /* =========================================================
       LOG EMAIL AGAINST CASE
       ========================================================= */

    logEmailOnCase(
        caseRec,
        selectedUser,
        emailSubject,
        plainTextBody,
        htmlBody
    );
}
    
    /* =========================================================
WARRANTY DISPLAY VALUE
========================================================= */
    
    private static String getWarrantyEmailValue(
        String warrantyStatus
    ) {
        
        if (String.isBlank(warrantyStatus)) {
            return 'Validation Pending';
        }
        
        String normalizedStatus =
            warrantyStatus
            .trim()
            .toLowerCase();
        
        
        if (
            normalizedStatus == 'yes' ||
            normalizedStatus == 'active' ||
            normalizedStatus == 'valid' ||
            normalizedStatus == 'in warranty' ||
            normalizedStatus == 'under warranty'
        ) {
            return 'Yes';
        }
        
        
        if (
            normalizedStatus == 'no' ||
            normalizedStatus == 'expired' ||
            normalizedStatus == 'inactive' ||
            normalizedStatus == 'out of warranty'
        ) {
            return 'No';
        }
        
        
        return 'Validation Pending';
    }
    
    
    /* =========================================================
LOG EMAIL ON CASE
========================================================= */
    
    private static void logEmailOnCase(
        Case caseRec,
        User selectedUser,
        String emailSubject,
        String plainTextBody,
        String htmlBody
    ) {
        
        EmailMessage emailLog =
            new EmailMessage();
        
        emailLog.ParentId =
            caseRec.Id;
        
        emailLog.Subject =
            emailSubject;
        
        emailLog.ToAddress =
            selectedUser.Email;
        
        /*
* IMPORTANT:
* Use System.UserInfo because this controller
* already contains an inner class called UserInfo.
*/
        emailLog.FromAddress =
            System.UserInfo.getUserEmail();
        
        emailLog.TextBody =
            plainTextBody;
        
        emailLog.HtmlBody =
            htmlBody;
        
        emailLog.Incoming =
            false;
        
        /*
* 3 = Sent
*/
        emailLog.Status =
            '3';
        
        emailLog.MessageDate =
            System.now();
        
        insert emailLog;
    }
    
    
    /* =========================================================
HTML ESCAPE
========================================================= */
    
    private static String escapeHtml(
        String value
    ) {
        
        if (value == null) {
            return '';
        }
        
        String escapedValue =
            value;
        
        escapedValue =
            escapedValue.replace(
                '&',
                '&amp;'
            );
        
        escapedValue =
            escapedValue.replace(
                '<',
                '&lt;'
            );
        
        escapedValue =
            escapedValue.replace(
                '>',
                '&gt;'
            );
        
        escapedValue =
            escapedValue.replace(
                '"',
                '&quot;'
            );
        
        return escapedValue;
    }
    
    
    /* =========================================================
CASE SHARE
========================================================= */
    
    private static void grantCaseEditAccess(
        Id caseId,
        Id userId
    ) {
        
        Set<Id> requestedIds =
            new Set<Id>{
                caseId
                    };
                        
                        Set<Id> idsWithoutEdit =
                        getIdsWithoutEditAccess(
                            requestedIds,
                            userId
                        );
        
        if (idsWithoutEdit.isEmpty()) {
            return;
        }
        
        
        List<CaseShare> existingShares = [
            SELECT Id,
            CaseAccessLevel
            FROM CaseShare
            WHERE CaseId = :caseId
            AND UserOrGroupId = :userId
            AND RowCause = 'Manual'
        ];
        
        
        if (!existingShares.isEmpty()) {
            
            List<SObject> sharesToDelete =
                new List<SObject>();
            
            for (
                CaseShare shareRec :
                existingShares
            ) {
                
                sharesToDelete.add(
                    shareRec
                );
            }
            
            Database.DeleteResult[] deleteResults =
                Database.delete(
                    sharesToDelete,
                    false
                );
            
            checkDeleteResults(
                deleteResults,
                'CaseShare'
            );
        }
        
        
        CaseShare shareRecord =
            new CaseShare();
        
        shareRecord.CaseId =
            caseId;
        
        shareRecord.UserOrGroupId =
            userId;
        
        shareRecord.CaseAccessLevel =
            'Edit';
        
        shareRecord.RowCause =
            Schema.CaseShare.RowCause.Manual;
        
        
        Database.SaveResult result =
            Database.insert(
                shareRecord,
                false
            );
        
        
        if (!result.isSuccess()) {
            
            Database.Error error =
                result.getErrors()[0];
            
            throw new L1AssignmentException(
                'CaseShare creation failed. ' +
                'Case Id: ' +
                String.valueOf(
                    caseId
                ) +
                ', User Id: ' +
                String.valueOf(
                    userId
                ) +
                ', Status: ' +
                String.valueOf(
                    error.getStatusCode()
                ) +
                ', Message: ' +
                error.getMessage()
            );
        }
    }
    
    
    /* =========================================================
ASSET SHARE
========================================================= */
    
    private static void grantAssetEditAccess(
        Set<Id> assetIds,
        Id userId
    ) {
        
        if (
            assetIds == null ||
            assetIds.isEmpty()
        ) {
            return;
        }
        
        
        Set<Id> idsWithoutEdit =
            getIdsWithoutEditAccess(
                assetIds,
                userId
            );
        
        
        if (idsWithoutEdit.isEmpty()) {
            return;
        }
        
        
        List<AssetShare> existingShares = [
            SELECT Id,
            AssetId,
            AssetAccessLevel
            FROM AssetShare
            WHERE AssetId IN :idsWithoutEdit
            AND UserOrGroupId = :userId
            AND RowCause = 'Manual'
        ];
        
        
        if (!existingShares.isEmpty()) {
            
            List<SObject> sharesToDelete =
                new List<SObject>();
            
            for (
                AssetShare shareRec :
                existingShares
            ) {
                
                sharesToDelete.add(
                    shareRec
                );
            }
            
            Database.DeleteResult[] deleteResults =
                Database.delete(
                    sharesToDelete,
                    false
                );
            
            checkDeleteResults(
                deleteResults,
                'AssetShare'
            );
        }
        
        
        List<SObject> sharesToInsert =
            new List<SObject>();
        
        
        for (
            Id assetId :
            idsWithoutEdit
        ) {
            
            AssetShare shareRec =
                new AssetShare();
            
            shareRec.AssetId =
                assetId;
            
            shareRec.UserOrGroupId =
                userId;
            
            shareRec.AssetAccessLevel =
                'Edit';
            
            shareRec.RowCause =
                Schema.AssetShare.RowCause.Manual;
            
            sharesToInsert.add(
                shareRec
            );
        }
        
        
        Database.SaveResult[] results =
            Database.insert(
                sharesToInsert,
                false
            );
        
        
        checkSaveResults(
            results,
            'AssetShare'
        );
    }
    
    
    /* =========================================================
CUSTOM OBJECT SHARE
========================================================= */
    
    private static void grantCustomEditAccess(
        String objectApiName,
        Set<Id> recordIds,
        Id userId
    ) {
        
        if (
            String.isBlank(
                objectApiName
            ) ||
            recordIds == null ||
            recordIds.isEmpty()
        ) {
            return;
        }
        
        
        Set<Id> idsWithoutEdit =
            getIdsWithoutEditAccess(
                recordIds,
                userId
            );
        
        
        if (idsWithoutEdit.isEmpty()) {
            return;
        }
        
        
        if (!objectApiName.endsWith('__c')) {
            return;
        }
        
        
        String shareApiName =
            objectApiName.substring(
                0,
                objectApiName.length() - 3
            ) +
            '__Share';
        
        
        Schema.SObjectType shareType =
            Schema.getGlobalDescribe().get(
                shareApiName
            );
        
        
        if (shareType == null) {
            
            throw new L1AssignmentException(
                'Unable to share ' +
                objectApiName +
                '. Share object ' +
                shareApiName +
                ' is not available.'
            );
        }
        
        
        Set<Id> parentIds =
            new Set<Id>(
                idsWithoutEdit
            );
        
        Id targetUserId =
            userId;
        
        
        String query =
            'SELECT Id, ParentId, AccessLevel ' +
            'FROM ' +
            shareApiName +
            ' ' +
            'WHERE ParentId IN :parentIds ' +
            'AND UserOrGroupId = :targetUserId ' +
            'AND RowCause = \'Manual\'';
        
        
        List<SObject> existingShares =
            Database.query(
                query
            );
        
        
        if (!existingShares.isEmpty()) {
            
            Database.DeleteResult[] deleteResults =
                Database.delete(
                    existingShares,
                    false
                );
            
            checkDeleteResults(
                deleteResults,
                shareApiName
            );
        }
        
        
        List<SObject> sharesToInsert =
            new List<SObject>();
        
        
        for (
            Id recordId :
            idsWithoutEdit
        ) {
            
            SObject shareRec =
                shareType.newSObject();
            
            shareRec.put(
                'ParentId',
                recordId
            );
            
            shareRec.put(
                'UserOrGroupId',
                userId
            );
            
            shareRec.put(
                'AccessLevel',
                'Edit'
            );
            
            shareRec.put(
                'RowCause',
                'Manual'
            );
            
            sharesToInsert.add(
                shareRec
            );
        }
        
        
        if (sharesToInsert.isEmpty()) {
            return;
        }
        
        
        Database.SaveResult[] results =
            Database.insert(
                sharesToInsert,
                false
            );
        
        
        checkSaveResults(
            results,
            shareApiName
        );
    }
    
    
    /* =========================================================
CHECK USER RECORD ACCESS
========================================================= */
    
    private static Set<Id> getIdsWithoutEditAccess(
        Set<Id> recordIds,
        Id userId
    ) {
        
        Set<Id> result =
            new Set<Id>();
        
        
        if (
            recordIds == null ||
            recordIds.isEmpty()
        ) {
            return result;
        }
        
        
        List<Id> allIds =
            new List<Id>(
                recordIds
            );
        
        
        Integer batchSize =
            200;
        
        
        for (
            Integer startIndex = 0;
            startIndex < allIds.size();
            startIndex += batchSize
        ) {
            
            Integer endIndex =
                Math.min(
                    startIndex + batchSize,
                    allIds.size()
                );
            
            
            List<Id> batchIds =
                new List<Id>();
            
            
            for (
                Integer index = startIndex;
                index < endIndex;
                index++
            ) {
                
                batchIds.add(
                    allIds[index]
                );
            }
            
            
            Set<Id> idsWithEdit =
                new Set<Id>();
            
            
            for (
                UserRecordAccess accessRec :
                [
                    SELECT RecordId,
                    HasEditAccess
                    FROM UserRecordAccess
                    WHERE UserId = :userId
                    AND RecordId IN :batchIds
                ]
            ) {
                
                if (accessRec.HasEditAccess) {
                    
                    idsWithEdit.add(
                        accessRec.RecordId
                    );
                }
            }
            
            
            for (
                Id recordId :
                batchIds
            ) {
                
                if (
                    !idsWithEdit.contains(
                        recordId
                    )
                ) {
                    
                    result.add(
                        recordId
                    );
                }
            }
        }
        
        
        return result;
    }
    
    
    /* =========================================================
CHECK INSERT RESULTS
========================================================= */
    
    private static void checkSaveResults(
        Database.SaveResult[] results,
        String shareObjectName
    ) {
        
        if (
            results == null ||
            results.isEmpty()
        ) {
            return;
        }
        
        
        List<String> errorMessages =
            new List<String>();
        
        
        for (
            Integer i = 0;
            i < results.size();
            i++
        ) {
            
            Database.SaveResult result =
                results[i];
            
            
            if (result.isSuccess()) {
                continue;
            }
            
            
            for (
                Database.Error error :
                result.getErrors()
            ) {
                
                errorMessages.add(
                    'Row ' +
                    String.valueOf(
                        i + 1
                    ) +
                    ': ' +
                    String.valueOf(
                        error.getStatusCode()
                    ) +
                    ' - ' +
                    error.getMessage()
                );
            }
        }
        
        
        if (!errorMessages.isEmpty()) {
            
            throw new L1AssignmentException(
                shareObjectName +
                ' creation failed. ' +
                String.join(
                    errorMessages,
                    ' | '
                )
            );
        }
    }
    
    
    /* =========================================================
CHECK DELETE RESULTS
========================================================= */
    
    private static void checkDeleteResults(
        Database.DeleteResult[] results,
        String shareObjectName
    ) {
        
        if (
            results == null ||
            results.isEmpty()
        ) {
            return;
        }
        
        
        List<String> errorMessages =
            new List<String>();
        
        
        for (
            Integer i = 0;
            i < results.size();
            i++
        ) {
            
            Database.DeleteResult result =
                results[i];
            
            
            if (result.isSuccess()) {
                continue;
            }
            
            
            for (
                Database.Error error :
                result.getErrors()
            ) {
                
                errorMessages.add(
                    'Row ' +
                    String.valueOf(
                        i + 1
                    ) +
                    ': ' +
                    String.valueOf(
                        error.getStatusCode()
                    ) +
                    ' - ' +
                    error.getMessage()
                );
            }
        }
        
        
        if (!errorMessages.isEmpty()) {
            
            throw new L1AssignmentException(
                shareObjectName +
                ' cleanup failed. ' +
                String.join(
                    errorMessages,
                    ' | '
                )
            );
        }
    }
    
    
    /* =========================================================
CUSTOM EXCEPTION
========================================================= */
    
    private class L1AssignmentException
        extends Exception {
        }
    
    
    /* =========================================================
RESPONSE CLASSES
========================================================= */
    
    private class AssignmentContext {
        
        public Id caseId;
        
        public String caseNumber;
        public String srtCaseNumber;
        
        public String subject;
        public String status;
        public String priority;
        
        public String accountName;
        public String contactName;
        public String ownerName;
        
        public Id l1UserAssignedId;
        public Datetime l1UserAssignedAt;
        
        public List<AssetInfo> assets;
        public List<UserInfo> users;
    }
    
    
    private class AssetInfo {
        
        public Id assetId;
        
        public String assetName;
        public String siteName;
        public String pvModuleRatingModel;
    }
    
    
    private class UserInfo {
        
        public Id userId;
        
        public String name;
        public String email;
        public String profileName;
    }
    
    
    private class AssignmentResult {
        
        public Boolean success;
        
        public Id userId;
        public String userName;
        
        public Datetime assignedAt;
        
        public Integer caseRelatedAssetCount;
        public Integer caseRelatedSerialCount;
        public Integer caseRelatedWarrantyCount;
        
        public String message;
    }

    // Multiselect values are semicolon-delimited. Match whole values only.
    private static Boolean isUserEligible(
        String caseProduct,
        String caseState,
        String userProducts,
        String userStates
    ) {
        return multiselectContains(userProducts, caseProduct)
            && multiselectContains(userStates, caseState);
    }

    private static Boolean multiselectContains(String selections, String target) {
        if (String.isBlank(selections) || String.isBlank(target)) {
            return false;
        }
        for (String item : selections.split(';')) {
            if (item.trim().equalsIgnoreCase(target.trim())) {
                return true;
            }
        }
        return false;
    }
}
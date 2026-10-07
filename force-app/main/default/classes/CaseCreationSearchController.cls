public with sharing class CaseCreationSearchController {

private static final Integer MAX_CHILD_RESULT_SIZE = 200;
private static final Integer MAX_SUGGESTION_SIZE = 10;
private static final Integer SUGGESTION_QUERY_SIZE = 50;
private static final String SEARCH_TYPE_SERIAL = 'SERIAL';
private static final String SEARCH_TYPE_MOBILE = 'MOBILE';
private static final String SEARCH_TYPE_CUSTOMER = 'CUSTOMER';

/**
    * Supports three independent search modes:
    * 1. Contact.Phone OR Contact.MobilePhone
    * 2. Asset_Serial_No__c.Name
    * 3. Account.Name
    *
    * Only one criterion can be supplied in a request.
    */
@AuraEnabled(cacheable=true)
public static AssetSerialSearchResult searchAssetDetails(
    String mobileNo,
    String serialNumber,
    String customerName
) {
    return executeSearch(
        mobileNo,
        serialNumber,
        customerName,
        null
    );
}

/**
    * Search entry point used by the typeahead-enabled LWC.
    * The selected record Id makes duplicate names/numbers deterministic.
    */
@AuraEnabled(cacheable=true)
public static AssetSerialSearchResult searchAssetDetailsBySelection(
    String mobileNo,
    String serialNumber,
    String customerName,
    Id selectedRecordId
) {
    return executeSearch(
        mobileNo,
        serialNumber,
        customerName,
        selectedRecordId
    );
}

/**
    * Returns typeahead suggestions for:
    * 1. Contact.Phone OR Contact.MobilePhone
    * 2. Asset_Serial_No__c.Name
    * 3. Account.Name
    */
@AuraEnabled(cacheable=true)
public static List<SearchSuggestion> getSearchSuggestions(
    String searchType,
    String searchTerm
) {
    searchType = normalizeSearchValue(searchType);
    searchTerm = normalizeSearchValue(searchTerm);

    if (
        String.isBlank(searchType) ||
        String.isBlank(searchTerm)
    ) {
        return new List<SearchSuggestion>();
    }

    searchType = searchType.toUpperCase();

    try {
        if (searchType == SEARCH_TYPE_MOBILE) {
            return findPhoneSuggestions(searchTerm);
        }

        if (searchType == SEARCH_TYPE_SERIAL) {
            return findSerialNumberSuggestions(searchTerm);
        }

        if (searchType == SEARCH_TYPE_CUSTOMER) {
            return findCustomerNameSuggestions(searchTerm);
        }

        throw new AuraHandledException(
            'Unsupported search suggestion type.'
        );

    } catch (AuraHandledException handledException) {
        throw handledException;

    } catch (Exception exceptionRecord) {
        System.debug(
            LoggingLevel.ERROR,
            'Search suggestion retrieval failed: ' +
            exceptionRecord.getTypeName() +
            ' - ' +
            exceptionRecord.getMessage() +
            '\n' +
            exceptionRecord.getStackTraceString()
        );

        throw new AuraHandledException(
            'Unable to load search suggestions: ' +
            exceptionRecord.getMessage()
        );
    }
}

private static Id resolveProductCategory(
    String selectedCategory
) {
    selectedCategory =
        normalizeSearchValue(selectedCategory);

    if (String.isBlank(selectedCategory)) {
        return null;
    }

    List<Product_Category__c> categories = [
        SELECT Id, Name, Category_Name__c
        FROM Product_Category__c
        WHERE Category_Name__c = :selectedCategory
        LIMIT 2
    ];

    if (categories.isEmpty()) {
        throw new AuraHandledException(
            'No matching Product Category record was found for "' +
            selectedCategory + '".'
        );
    }

    if (categories.size() > 1) {
        throw new AuraHandledException(
            'Multiple Product Category records were found for "' +
            selectedCategory + '".'
        );
    }

    return categories[0].Id;
}

/**
    * Creates the Case and all selected Asset, Serial Number, and Warranty
    * relationship records in one transaction.
    */
@AuraEnabled
public static CaseCreationSaveResult createCaseWithRelatedRecords(
    CaseCreationSaveRequest request
) {
    if (request == null) {
        throw new AuraHandledException(
            'The Case creation request is required.'
        );
    }

    if (request.accountId == null) {
        throw new AuraHandledException(
            'An Account must be selected.'
        );
    }

    if (String.isBlank(request.product)) {
    throw new AuraHandledException(
        'Product is required.'
    );
}

if (String.isBlank(request.productCategory)) {
    throw new AuraHandledException(
        'Product Category is required.'
    );
}

    if (String.isBlank(request.origin)) {
        throw new AuraHandledException(
            'Case Origin is required.'
        );
    }

    if (String.isBlank(request.srtCaseStatus)) {
throw new AuraHandledException(
    'SRT Case Status is required.'
);
}

    if (String.isBlank(request.priority)) {
        throw new AuraHandledException(
            'Priority is required.'
        );
    }

    if (String.isBlank(request.description)) {
        throw new AuraHandledException(
            'Description is required.'
        );
    }

    Savepoint savePointRecord =
        Database.setSavepoint();

    try {
        /*
            * Asset Serial Number selection is optional.
            * Normalize a null request list to an empty list so the Case
            * can still be created when no Asset/Serial/Warranty is chosen.
            */
        List<CaseRelatedSelectionInput> selectedRecords =
            request.selectedRecords == null
                ? new List<CaseRelatedSelectionInput>()
                : request.selectedRecords;

        Set<Id> selectedSerialIds =
            new Set<Id>();

        Set<Id> requestedWarrantyIds =
            new Set<Id>();

        /*
            * Preserves the relationship selected in the UI:
            * selected Asset Serial Number -> its displayed warranties.
            */
        Map<Id, Set<Id>> warrantyIdsBySerialId =
            new Map<Id, Set<Id>>();

        for (
            CaseRelatedSelectionInput selectionRecord :
            selectedRecords
        ) {
            if (
                selectionRecord == null ||
                selectionRecord.assetSerialNumberId == null
            ) {
                throw new AuraHandledException(
                    'Every selected record must contain an Asset Serial Number.'
                );
            }

            Id selectedSerialId =
                selectionRecord.assetSerialNumberId;

            selectedSerialIds.add(
                selectedSerialId
            );

            if (
                !warrantyIdsBySerialId.containsKey(
                    selectedSerialId
                )
            ) {
                warrantyIdsBySerialId.put(
                    selectedSerialId,
                    new Set<Id>()
                );
            }

            if (
                selectionRecord.assetWarrantyIds != null
            ) {
                requestedWarrantyIds.addAll(
                    selectionRecord.assetWarrantyIds
                );

                warrantyIdsBySerialId.get(
                    selectedSerialId
                ).addAll(
                    selectionRecord.assetWarrantyIds
                );
            }
        }

        Map<Id, Asset_Serial_No__c> serialRecordsById =
            querySelectedSerialRecords(
                selectedSerialIds
            );

        if (
            serialRecordsById.size() !=
            selectedSerialIds.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Asset Serial Numbers could not be found or are not accessible.'
            );
        }

        Set<Id> selectedAssetIds =
            new Set<Id>();

        Map<Id, Id> assetIdBySerialId =
            new Map<Id, Id>();

        Map<Id, Id> productIdByAssetId =
            new Map<Id, Id>();

        for (
            Asset_Serial_No__c serialRecord :
            serialRecordsById.values()
        ) {
            if (serialRecord.Asset__c == null) {
                throw new AuraHandledException(
                    'A selected Asset Serial Number is not linked to an Asset.'
                );
            }

            if (
                serialRecord.Asset__r != null &&
                serialRecord.Asset__r.AccountId != null &&
                serialRecord.Asset__r.AccountId !=
                    request.accountId
            ) {
                throw new AuraHandledException(
                    'A selected Asset does not belong to the selected Account.'
                );
            }

            selectedAssetIds.add(
                serialRecord.Asset__c
            );

            assetIdBySerialId.put(
                serialRecord.Id,
                serialRecord.Asset__c
            );

            if (
                serialRecord.Asset__r != null &&
                serialRecord.Asset__r.Product2Id != null
            ) {
                productIdByAssetId.put(
                    serialRecord.Asset__c,
                    serialRecord.Asset__r.Product2Id
                );
            }
        }

        validateSelectedContact(
            request.contactId,
            request.accountId
        );

        Map<Id, AssetWarranty> warrantyRecordsById =
            querySelectedWarrantyRecords(
                requestedWarrantyIds
            );

        if (
            warrantyRecordsById.size() !=
            requestedWarrantyIds.size()
        ) {
            throw new AuraHandledException(
                'One or more selected Asset Warranties could not be found or are not accessible.'
            );
        }

        /*
            * Validate each warranty against the serial card under which
            * the user selected it.
            */
        for (
            Id selectedSerialId :
            warrantyIdsBySerialId.keySet()
        ) {
            Id selectedAssetId =
                assetIdBySerialId.get(
                    selectedSerialId
                );

            for (
                Id warrantyId :
                warrantyIdsBySerialId.get(
                    selectedSerialId
                )
            ) {
                AssetWarranty warrantyRecord =
                    warrantyRecordsById.get(
                        warrantyId
                    );

                if (warrantyRecord == null) {
                    throw new AuraHandledException(
                        'A selected Asset Warranty could not be found or is not accessible.'
                    );
                }

                if (
                    warrantyRecord.Asset_Serial_No__c != null &&
                    warrantyRecord.Asset_Serial_No__c !=
                        selectedSerialId
                ) {
                    throw new AuraHandledException(
                        'An Asset Warranty was selected under a different Asset Serial Number.'
                    );
                }

                if (
                    warrantyRecord.AssetId != null &&
                    warrantyRecord.AssetId !=
                        selectedAssetId
                ) {
                    throw new AuraHandledException(
                        'An Asset Warranty does not belong to the Asset of the selected Serial Number.'
                    );
                }
            }
        }

        String generatedSrtCaseNumber =
            generateNextSrtCaseNumber();

        Case caseRecord =
            new Case();
        
        caseRecord.OwnerId =
            UserInfo.getUserId();
        
        /*
            * Standard Case.CaseNumber is Salesforce controlled and cannot
            * be assigned from Apex. Store the required business number in
            * SRT_Case_Number__c instead.
            */
        caseRecord.SRT_Case_Number__c =
            generatedSrtCaseNumber;

        /*
            * Cases created through this Complaint Registration component
            * always belong to the SRT business segment.
            */
        caseRecord.Buisness_Segment__c =
            'SRT';

            caseRecord.Customer_Type__c =
    normalizeSearchValue(
        request.customerType
    );

caseRecord.Stock_Type__c =
    request.customerType == 'Dealer'
        ? normalizeSearchValue(
            request.stockType
        )
        : 'Sold';

        caseRecord.Dealer_Name__c =
    request.customerType == 'Dealer'
        ? normalizeSearchValue(request.dealerName)
        : null;

caseRecord.Dealer_Contact_No__c =
    request.customerType == 'Dealer'
        ? normalizeSearchValue(request.dealerContactNo)
        : null;


        caseRecord.Subject =
    generateCaseSubject();

caseRecord.Product__c =
    normalizeSearchValue(
        request.product
    );

caseRecord.Product_Categories__c =
    normalizeSearchValue(
        request.productCategory
    );

caseRecord.ProductId =
    resolveCaseLookupByName(
        'ProductId',
        request.product,
        'Product'
    );

caseRecord.Product_Category_2__c =
    resolveProductCategory(
        request.productCategory
    );

        caseRecord.Origin =
            request.origin;

        caseRecord.SRT_Case_Status__c =
request.srtCaseStatus;

caseRecord.Priority =
request.priority;

caseRecord.Description =
request.description;

caseRecord.Complaint_Type_SRT__c =
request.complaintTypeSrt;

caseRecord.Complaint_Sub_Type_SRT__c =
request.complaintSubTypeSrt;

caseRecord.Complaint_Reason__c =
request.complaintReason;

// caseRecord.Failure_Category__c =
// request.failureCategory;

// caseRecord.Closure_Reason__c =
// request.closureReason;

        caseRecord.AccountId =
            request.accountId;

        caseRecord.ContactId =
            request.contactId;

        /*
            * The standard Case fields support one Asset and one Asset
            * Warranty. Populate them only when exactly one corresponding
            * record exists. The custom relationship objects preserve all
            * selected records.
            */
        /*if (selectedAssetIds.size() == 1) {
            Id onlyAssetId =
                new List<Id>(
                    selectedAssetIds
                )[0];

            caseRecord.AssetId =
                onlyAssetId;

            caseRecord.ProductId =
                productIdByAssetId.get(
                    onlyAssetId
                );
        }*/

        if (selectedAssetIds.size() == 1) {

    Id onlyAssetId =
        new List<Id>(
            selectedAssetIds
        )[0];

    caseRecord.AssetId =
        onlyAssetId;
}

        if (requestedWarrantyIds.size() == 1) {
            caseRecord.AssetWarrantyId =
                new List<Id>(
                    requestedWarrantyIds
                )[0];
        }

        Case insertedCase =
            (Case) insertCreatableRecord(
                caseRecord,
                'Case'
            );

        Map<Id, Id> relatedAssetIdByAssetId =
            createCaseRelatedAssets(
                insertedCase.Id,
                selectedAssetIds
            );

        /*
            * Asset Serial Number tagging is handled directly by this
            * component for Case Related Asset records created with
            * Complaint_Registration_Form_Component__c = true.
            */
        Map<Id, Id> relatedSerialIdBySerialId =
            createCaseRelatedSerialNumbers(
                serialRecordsById,
                relatedAssetIdByAssetId
            );

        Integer relatedWarrantyCount =
createCaseRelatedWarranties(
    insertedCase.Id,
    selectedRecords,
    warrantyRecordsById,
    serialRecordsById,
    relatedAssetIdByAssetId,
    relatedSerialIdBySerialId,
    productIdByAssetId
);

        Case savedCase =
            querySavedCase(
                insertedCase.Id
            );

            /*
* Send Case acknowledgement email to selected Contact.
*/
sendCaseRegistrationEmail(
savedCase.Id,
request.contactId,
savedCase.SRT_Case_Number__c
);

        // NEW (Point 1): Contact.Phone receives dearcustomer01.
        // Messaging errors are logged; they do not cancel Case creation.
        try {
            String whatsAppResult =
                SRT_RegistrationWhatsAppService.queueAfterCreate(savedCase.Id);
            System.debug(LoggingLevel.INFO, whatsAppResult);
        } catch (Exception whatsAppError) {
            System.debug(LoggingLevel.ERROR,
                'Registration WhatsApp preparation failed. Case=' +
                savedCase.Id + ': ' + whatsAppError.getMessage());
        }

        return new CaseCreationSaveResult(
            savedCase,
            relatedAssetIdByAssetId.size(),
            relatedSerialIdBySerialId.size(),
            relatedWarrantyCount
        );

    } catch (AuraHandledException handledException) {
        Database.rollback(
            savePointRecord
        );
        throw handledException;

    } catch (Exception exceptionRecord) {
        Database.rollback(
            savePointRecord
        );

        System.debug(
            LoggingLevel.ERROR,
            'Case and related record creation failed: ' +
            exceptionRecord.getTypeName() +
            ' - ' +
            exceptionRecord.getMessage() +
            '\n' +
            exceptionRecord.getStackTraceString()
        );

        throw new AuraHandledException(
            'Unable to create the Case and related records: ' +
            exceptionRecord.getMessage()
        );
    }
}


/**
    * Fallback flow used when Phone/Mobile Number or Asset Serial Number
    * does not already exist. Creates Account -> Contact -> Case in one
    * transaction. No Asset, Serial Number, or Warranty is created here.
    */
@AuraEnabled
public static NewCustomerCaseSaveResult createNewAccountContactAndCase(
    NewCustomerCaseSaveRequest request
) {
    if (request == null) {
        throw new AuraHandledException(
            'The new customer Case request is required.'
        );
    }

    if (String.isBlank(request.accountName)) {
        throw new AuraHandledException(
            'Account Name is required.'
        );
    }

    // Primary Mobile Number must be available for both Account and Contact.
    // The registration WhatsApp recipient is Case.Contact.Phone.
    String primaryMobile = normalizeSearchValue(request.accountPhone);
    if (String.isBlank(primaryMobile) ||
        !Pattern.matches('^[6-9][0-9]{9}$', primaryMobile)) {
        throw new AuraHandledException(
            'A valid 10-digit Primary Mobile Number is required to create the new customer and Case.'
        );
    }

    // Prevent duplicate Account creation using Primary Phone Number
Account existingAccount =
    findExistingAccountByPrimaryPhone(
        primaryMobile
    );

if (existingAccount != null) {

    throw new AuraHandledException(
        'An Account already exists with this Primary Phone Number. ' +
        'Please search for this phone number and select the existing Account instead of creating a new customer.'
    );
}

    // Use the Account email for both Account.Email__c and Contact.Email.
    String primaryEmail = normalizeSearchValue(request.accountEmail);

    if (String.isBlank(request.contactLastName)) {
        throw new AuraHandledException(
            'Contact Last Name is required.'
        );
    }

    if (String.isBlank(request.billingPostalCode)) {
    throw new AuraHandledException(
        'Pincode is required.'
    );
}

    if (!Pattern.matches(
    '^[0-9]{6}$',
    request.billingPostalCode.trim()
)) {
    throw new AuraHandledException(
        'Pincode must contain exactly 6 digits.'
    );
}

    // if (String.isBlank(request.contactEmail)) {
    //     throw new AuraHandledException(
    //         'Contact Email is required.'
    //     );
    // }
    if (String.isBlank(request.product)) {
    throw new AuraHandledException(
        'Product is required.'
    );
}

if (String.isBlank(request.productCategory)) {
    throw new AuraHandledException(
        'Product Category is required.'
    );
}
    if (String.isBlank(request.origin)) {
        throw new AuraHandledException(
            'Case Origin is required.'
        );
    }

    // if (String.isBlank(request.srtCaseStatus)) {
    //     throw new AuraHandledException(
    //         'Status is required.'
    //     );
    // }

    if (String.isBlank(request.priority)) {
        throw new AuraHandledException(
            'Priority is required.'
        );
    }

    if (String.isBlank(request.description)) {
        throw new AuraHandledException(
            'Description is required.'
        );
    }

    Savepoint savePointRecord =
        Database.setSavepoint();

    try {
        Account accountRecord =
            new Account(
                Name =
                    request.accountName.trim(),
                Phone = primaryMobile,
                    Alternate_mobile_no__c=
                    normalizeSearchValue(
                        request.accountMobile
                    ),
                        Email__c = primaryEmail,
               Building_Street__c =
    normalizeSearchValue(
        request.buildingStreet
    ),

District__c =
    normalizeSearchValue(
        request.district
    ),

BillingCity =
    normalizeSearchValue(
        request.billingCity
    ),

State__c =
    normalizeSearchValue(
        request.billingState
    ),

BillingState =
    normalizeSearchValue(
        request.billingState
    ),

BillingPostalCode =
    normalizeSearchValue(
        request.billingPostalCode
    )
            );

        Account insertedAccount =
            (Account) insertCreatableRecord(
                accountRecord,
                'Account'
            );

        Contact contactRecord =
            new Contact(
                AccountId =
                    insertedAccount.Id,
                FirstName =
                    normalizeSearchValue(
                        request.contactFirstName
                    ),
                LastName =
                    request.contactLastName.trim(),
                // Contact.Phone always receives Account's primary mobile.
                Phone = primaryMobile,
                // Save the Account email on the new Contact as well.
                Email = primaryEmail,
                MobilePhone =
                    normalizeSearchValue(
                        request.contactMobilePhone
                    )
                    
                
            );

        Contact insertedContact =
            (Contact) insertCreatableRecord(
                contactRecord,
                'Contact'
            );

        String generatedSrtCaseNumber =
            generateNextSrtCaseNumber();

        Case caseRecord =
new Case(
    OwnerId =
            UserInfo.getUserId(),
    
    AccountId =
        insertedAccount.Id,

    ContactId =
        insertedContact.Id,

    SRT_Case_Number__c =
        generatedSrtCaseNumber,

    Buisness_Segment__c =
        'SRT',

        // Saved on Case
Customer_Type__c =
    normalizeSearchValue(
        request.customerType
    ),

    Dealer_Name__c =
    normalizeSearchValue(
        request.dealerName
    ),

Dealer_Contact_No__c =
    normalizeSearchValue(
        request.dealerContactNo
    ),

// Dealer: selected value
// Others: always Sold
Stock_Type__c =
    request.customerType == 'Dealer'
        ? normalizeSearchValue(
            request.stockType
        )
        : 'Sold',

    Subject =
    generateCaseSubject(),

Product__c =
    normalizeSearchValue(
        request.product
    ),

Product_Categories__c =
    normalizeSearchValue(
        request.productCategory
    ),

ProductId =
    resolveCaseLookupByName(
        'ProductId',
        request.product,
        'Product'
    ),

Product_Category_2__c =
    resolveProductCategory(
        request.productCategory
    ),

    Origin =
        request.origin,

    SRT_Case_Status__c ='New',

    Priority =
        request.priority,

    Description =
        request.description,

    Complaint_Type_SRT__c =
        request.complaintTypeSrt,

    Complaint_Sub_Type_SRT__c =
        request.complaintSubTypeSrt,

    Complaint_Reason__c =
        request.complaintReason

    // Failure_Category__c =
    //     request.failureCategory,

    // Closure_Reason__c =
    //     request.closureReason
);
        Case insertedCase =
            (Case) insertCreatableRecord(
                caseRecord,
                'Case'
            );

        Case savedCase =
            querySavedCase(
                insertedCase.Id
            );

        /* =========================================================
           SEND REGISTRATION EMAIL TO THE NEWLY CREATED CONTACT
           The existing-customer path already invokes this method.
           Keep email errors independent of Case creation.
           ========================================================= */
        try {
            sendCaseRegistrationEmail(
                savedCase.Id,
                insertedContact.Id,
                savedCase.SRT_Case_Number__c
            );
        } catch (Exception emailError) {
            System.debug(
                LoggingLevel.ERROR,
                'New customer registration email failed. Case=' +
                savedCase.Id + ': ' + emailError.getMessage()
            );
        }

        // NEW (Point 1): also send for the new Account + Contact path.
        // Recipient comes from the saved Case's Contact.Phone.
        try {
            String whatsAppResult =
                SRT_RegistrationWhatsAppService.queueAfterCreate(savedCase.Id);
            System.debug(LoggingLevel.INFO, whatsAppResult);
        } catch (Exception whatsAppError) {
            System.debug(LoggingLevel.ERROR,
                'Registration WhatsApp preparation failed. Case=' +
                savedCase.Id + ': ' + whatsAppError.getMessage());
        }

        return new NewCustomerCaseSaveResult(
            savedCase,
            insertedAccount.Id,
            insertedContact.Id
        );

    } catch (AuraHandledException handledException) {
        Database.rollback(
            savePointRecord
        );
        throw handledException;

    } catch (Exception exceptionRecord) {
        Database.rollback(
            savePointRecord
        );

        System.debug(
            LoggingLevel.ERROR,
            'New Account, Contact and Case creation failed: ' +
            exceptionRecord.getTypeName() +
            ' - ' +
            exceptionRecord.getMessage() +
            '\n' +
            exceptionRecord.getStackTraceString()
        );

        throw new AuraHandledException(
            'Unable to create the Account, Contact and Case: ' +
            exceptionRecord.getMessage()
        );
    }
}

private static Account findExistingAccountByPrimaryPhone(
    String phoneNumber
) {

    String normalizedPhone =
        normalizePhoneDigits(
            phoneNumber
        );

    if (String.isBlank(normalizedPhone)) {
        return null;
    }

    String phonePattern =
        buildPhoneLikePattern(
            normalizedPhone
        );

    List<Account> accountRecords = [
        SELECT
            Id,
            Name,
            Phone
        FROM Account
        WHERE Phone LIKE :phonePattern
        LIMIT 50
    ];

    for (Account accountRecord : accountRecords) {

        if (
            phoneNumbersMatch(
                normalizedPhone,
                normalizePhoneDigits(
                    accountRecord.Phone
                )
            )
        ) {

            return accountRecord;
        }
    }

    return null;
}

/**
    * Generates the next business Case number from Case_SRT_Auto_No__c.
    *
    * Custom Setting:
    * Name__c        = prefix, for example DEB
    * Auto_Number__c = last used sequence number
    *
    * Example output: DEB-2026-000001
    *
    * FOR UPDATE locks the single counter row during generation so
    * concurrent saves cannot receive the same number.
    */
/*private static String generateNextSrtCaseNumber() {
    List<Case_SRT_Auto_No__c> configurationRecords = [
        SELECT Id, Auto_Number__c, Name__c
        FROM Case_SRT_Auto_No__c
        LIMIT 2
        FOR UPDATE
    ];

    if (configurationRecords.isEmpty()) {
        throw new AuraHandledException(
            'Case SRT Auto Number configuration is missing. Create one Case_SRT_Auto_No__c record with Name__c = DEB.'
        );
    }

    if (configurationRecords.size() > 1) {
        throw new AuraHandledException(
            'Multiple Case SRT Auto Number configuration records were found. Keep only one counter record.'
        );
    }

    Case_SRT_Auto_No__c configurationRecord =
        configurationRecords[0];

    String prefix =
        String.isBlank(configurationRecord.Name__c)
            ? 'DEB'
            : configurationRecord.Name__c.trim().toUpperCase();

    Long currentNumber =
        configurationRecord.Auto_Number__c == null
            ? 0
            : configurationRecord.Auto_Number__c.longValue();

    Long nextNumber =
        currentNumber + 1;

    if (nextNumber > 999999) {
        throw new AuraHandledException(
            'Case SRT Auto Number has exceeded the supported six-digit sequence.'
        );
    }

    configurationRecord.Auto_Number__c =
        Decimal.valueOf(
            String.valueOf(nextNumber)
        );

    update configurationRecord;

    String paddedNumber =
        String.valueOf(nextNumber)
            .leftPad(6, '0');

    return
        prefix +
        '-' +
        String.valueOf(Date.today().year()) +
        '-' +
        paddedNumber;
}*/

private static String generateNextSrtCaseNumber() {

List<Case_SRT_Auto_No__c> configurationRecords = [
    SELECT Id, Auto_Number__c, Name__c
    FROM Case_SRT_Auto_No__c
    LIMIT 2
    FOR UPDATE
];

if (configurationRecords.isEmpty()) {
    throw new AuraHandledException(
        'Case SRT Auto Number configuration is missing.'
    );
}

if (configurationRecords.size() > 1) {
    throw new AuraHandledException(
        'Multiple Case SRT Auto Number configuration records were found. Keep only one counter record.'
    );
}

Case_SRT_Auto_No__c configurationRecord =
    configurationRecords[0];

Date todayDate =
    Date.today();

String yearPart =
    String.valueOf(todayDate.year())
        .right(2);

String monthPart =
    String.valueOf(todayDate.month())
        .leftPad(2, '0');

String dayPart =
    String.valueOf(todayDate.day())
        .leftPad(2, '0');

String datePrefix =
    yearPart +
    monthPart +
    dayPart;

String todayPattern =
    datePrefix + '%';

List<Case> todayCases = [
    SELECT Id, SRT_Case_Number__c
    FROM Case
    WHERE SRT_Case_Number__c LIKE :todayPattern
    ORDER BY SRT_Case_Number__c DESC
    LIMIT 1
];

Integer nextNumber = 1;

if (!todayCases.isEmpty()) {

    String previousNumber =
        todayCases[0].SRT_Case_Number__c;

    if (
        String.isNotBlank(previousNumber) &&
        previousNumber.startsWith(datePrefix) &&
        previousNumber.length() == 9
    ) {
        String sequencePart =
            previousNumber.substring(6);

        nextNumber =
            Integer.valueOf(sequencePart) + 1;
    }
}

if (nextNumber > 999) {
    throw new AuraHandledException(
        'Maximum SRT Case sequence of 999 has been reached for today.'
    );
}

configurationRecord.Auto_Number__c =
    nextNumber;

update configurationRecord;

String sequencePart =
    String.valueOf(nextNumber)
        .leftPad(3, '0');

return
    datePrefix +
    sequencePart;
}

private static Map<Id, Asset_Serial_No__c>
    querySelectedSerialRecords(
        Set<Id> serialIds
    ) {
    Map<Id, Asset_Serial_No__c> recordsById =
        new Map<Id, Asset_Serial_No__c>();

    if (
        serialIds == null ||
        serialIds.isEmpty()
    ) {
        return recordsById;
    }

    String queryString =
        'SELECT ' +
            'Id, ' +
            'Asset__c, ' +
            'Asset__r.AccountId, ' +
            'Asset__r.Product2Id ' +
        'FROM Asset_Serial_No__c ' +
        'WHERE Id IN :serialIds';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'serialIds' => serialIds
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    for (SObject queriedRecord : queriedRecords) {
        Asset_Serial_No__c serialRecord =
            (Asset_Serial_No__c) queriedRecord;

        recordsById.put(
            serialRecord.Id,
            serialRecord
        );
    }

    return recordsById;
}

private static Map<Id, AssetWarranty>
    querySelectedWarrantyRecords(
        Set<Id> warrantyIds
    ) {
    Map<Id, AssetWarranty> recordsById =
        new Map<Id, AssetWarranty>();

    if (
        warrantyIds == null ||
        warrantyIds.isEmpty()
    ) {
        return recordsById;
    }

    String queryString =
        'SELECT ' +
            'Id, ' +
            'AssetId, ' +
            'Asset_Serial_No__c ' +
        'FROM AssetWarranty ' +
        'WHERE Id IN :warrantyIds';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'warrantyIds' => warrantyIds
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    for (SObject queriedRecord : queriedRecords) {
        AssetWarranty warrantyRecord =
            (AssetWarranty) queriedRecord;

        recordsById.put(
            warrantyRecord.Id,
            warrantyRecord
        );
    }

    return recordsById;
}

private static void validateSelectedContact(
    Id contactId,
    Id accountId
) {
    if (contactId == null) {
        return;
    }

    String queryString =
        'SELECT Id, AccountId ' +
        'FROM Contact ' +
        'WHERE Id = :contactId ' +
        'LIMIT 1';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'contactId' => contactId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    if (queriedRecords.isEmpty()) {
        throw new AuraHandledException(
            'The selected Contact could not be found or is not accessible.'
        );
    }

    Contact contactRecord =
        (Contact) queriedRecords[0];

    if (contactRecord.AccountId != accountId) {
        throw new AuraHandledException(
            'The selected Contact does not belong to the selected Account.'
        );
    }
}

private static void setFieldIfAvailable(
SObject record,
String fieldName,
Object fieldValue
) {
if (
    record == null ||
    String.isBlank(fieldName)
) {
    return;
}

Map<String, Schema.SObjectField> fieldMap =
    record.getSObjectType()
        .getDescribe()
        .fields
        .getMap();

if (!fieldMap.containsKey(fieldName)) {
    return;
}

Schema.DescribeFieldResult fieldDescribe =
    fieldMap
        .get(fieldName)
        .getDescribe();

/*
    * Never try to write into a Formula / Calculated field.
    */
if (!fieldDescribe.isUpdateable()) {
    return;
}

/*
    * Null is a valid value for optional fields, but we don't
    * need to explicitly put null into the record.
    */
if (fieldValue == null) {
    return;
}

record.put(
    fieldName,
    fieldValue
);
}

private static Map<Id, Id> createCaseRelatedAssets(
Id caseId,
Set<Id> assetIds
) {
List<SObject> recordsToInsert =
    new List<SObject>();

List<Id> orderedAssetIds =
    new List<Id>(
        assetIds
    );

orderedAssetIds.sort();

/*
    * IMPORTANT:
    *
    * We are using the already-saved Asset as the source of truth.
    * No UI values are being changed.
    * No existing search or selection logic is being changed.
    */
Map<Id, Asset> assetRecordsById =
    new Map<Id, Asset>();

if (
    assetIds != null &&
    !assetIds.isEmpty()
) {
    String queryString =
        buildAssetSelectClause() +
        'WHERE Id IN :assetIds';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'assetIds' => assetIds
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    for (SObject queriedRecord : queriedRecords) {
        Asset assetRecord =
            (Asset) queriedRecord;

        assetRecordsById.put(
            assetRecord.Id,
            assetRecord
        );
    }
}

for (Id assetId : orderedAssetIds) {

    Asset assetRecord =
        assetRecordsById.get(
            assetId
        );

    if (assetRecord == null) {
        throw new AuraHandledException(
            'The selected Asset could not be found or is not accessible.'
        );
    }

    Case_Related_Assets__c relatedAsset =
        new Case_Related_Assets__c();

    /*
        * EXISTING LOGIC
        */
    relatedAsset.Case__c =
        caseId;

    relatedAsset.Asset__c =
        assetId;

    relatedAsset.Complaint_Registration_Form_Component__c =
        true;


    /*
        * =========================================================
        * PRODUCT INFORMATION
        * =========================================================
        *
        * Product comes from the already-saved Asset.
        *
        * Asset.Product2Id
        */
    setCaseRelatedAssetProduct(
        relatedAsset,
        assetRecord
    );


    /*
        * =========================================================
        * PRODUCT / WARRANTY INFORMATION
        * =========================================================
        *
        * These values are copied from Asset.
        *
        * We do NOT recalculate them here.
        * We do NOT use values from the LWC.
        */
    setFieldIfAvailable(
        relatedAsset,
        'Product_Warranty_Duration__c',
        assetRecord.Product_Warranty_Duration__c
    );

    setFieldIfAvailable(
        relatedAsset,
        'Product_Warranty_End_Date__c',
        assetRecord.Product_Warranty_End_Date__c
    );

    setFieldIfAvailable(
        relatedAsset,
        'Performance_Warranty_Duration__c',
        assetRecord.Performance_Warranty_Duration__c
    );

    setFieldIfAvailable(
        relatedAsset,
        'Performance_Warranty_End_Date__c',
        assetRecord.Performance_Warranty_End_Date__c
    );


    /*
        * =========================================================
        * PRODUCT / PURCHASE INFORMATION
        * =========================================================
        */

    setFieldIfAvailable(
        relatedAsset,
        'Product_Model_No__c',
        assetRecord.PV_Module_Rating_Model_No__c
    );

    setFieldIfAvailable(
        relatedAsset,
        'Date_of_Purchase__c',
        assetRecord.PurchaseDate
    );

    setFieldIfAvailable(
        relatedAsset,
        'Invoice_Date__c',
        assetRecord.Invoice_Date__c
    );

    Date warrantyEndDate;
String warrantyStatus;

if (
assetRecord.Invoice_Date__c != null &&
assetRecord.Product_Warranty_Duration__c != null &&
assetRecord.Product_Warranty_Duration__c > 0
) {
Integer duration =
    Integer.valueOf(
        String.valueOf(
            assetRecord.Product_Warranty_Duration__c
        )
    );

warrantyEndDate =
    assetRecord.Invoice_Date__c
        .addYears(duration)
        .addDays(-1);

if (Date.today() <= warrantyEndDate) {
    warrantyStatus = 'Active';
} else {
    warrantyStatus = 'Expired';
}
} else {
warrantyStatus = 'Validation Required';
}

setFieldIfAvailable(
relatedAsset,
'End_Date__c',
warrantyEndDate
);

setFieldIfAvailable(
relatedAsset,
'Warranty_Status__c',
warrantyStatus
);


    String invoiceNumber =
        String.isNotBlank(
            assetRecord.Invoice_Number__c
        )
            ? assetRecord.Invoice_Number__c
            : assetRecord.Invoice_No__c;

    setFieldIfAvailable(
        relatedAsset,
        'Invoice_Number__c',
        invoiceNumber
    );


    /*
        * Product serial number is taken from the Asset's
        * standard SerialNumber when available.
        */
    setFieldIfAvailable(
        relatedAsset,
        'Product_Serial_No__c',
        assetRecord.SerialNumber
    );


    /*
        * =========================================================
        * ADDITIONAL WARRANTY INFORMATION
        * =========================================================
        *
        * These fields are copied only if the corresponding fields
        * have been created on Case_Related_Assets__c.
        *
        * This keeps the existing controller safe.
        */

    setFieldIfAvailable(
        relatedAsset,
        'Warranty_Start_Date__c',
        assetRecord.Invoice_Date__c
    );

    setFieldIfAvailable(
        relatedAsset,
        'Warranty_End_Date__c',
        assetRecord.Product_Warranty_End_Date__c
    );


    /*
        * Preserve the existing Order Product relationship if the
        * field already exists and is populated by the current
        * process.
        *
        * We are intentionally NOT changing its existing behavior.
        */


    recordsToInsert.add(
        relatedAsset
    );
}

List<SObject> insertedRecords =
    insertCreatableRecords(
        recordsToInsert,
        'Case Related Asset'
    );

Map<Id, Id> relatedAssetIdByAssetId =
    new Map<Id, Id>();

for (
    Integer indexValue = 0;
    indexValue < insertedRecords.size();
    indexValue++
) {
    Case_Related_Assets__c relatedAsset =
        (Case_Related_Assets__c)
            insertedRecords[indexValue];

    relatedAssetIdByAssetId.put(
        orderedAssetIds[indexValue],
        relatedAsset.Id
    );
}

return relatedAssetIdByAssetId;
}
private static void setCaseRelatedAssetProduct(
Case_Related_Assets__c relatedAsset,
Asset assetRecord
) {
if (
    relatedAsset == null ||
    assetRecord == null ||
    assetRecord.Product2Id == null
) {
    return;
}

Map<String, Schema.SObjectField> fieldMap =
    Schema.SObjectType.Case_Related_Assets__c
        .fields
        .getMap();

if (!fieldMap.containsKey('Product__c')) {
    return;
}

Schema.DescribeFieldResult fieldDescribe =
    fieldMap
        .get('Product__c')
        .getDescribe();

Schema.DisplayType fieldType =
    fieldDescribe.getType();

/*
    * If Product__c is a Lookup / Master-Detail to Product2,
    * store Product2Id.
    */
if (
    fieldType == Schema.DisplayType.REFERENCE
) {
    relatedAsset.put(
        'Product__c',
        assetRecord.Product2Id
    );

    return;
}

/*
    * If Product__c was configured as Text/Picklist,
    * store the Product Name instead.
    */
if (
    fieldType == Schema.DisplayType.STRING ||
    fieldType == Schema.DisplayType.PICKLIST ||
    fieldType == Schema.DisplayType.TEXTAREA
) {
    if (assetRecord.Product2 != null) {
        relatedAsset.put(
            'Product__c',
            assetRecord.Product2.Name
        );
    }
}
}

/**
    * Creates one Case_Related_Assets_Serial_No__c record for every
    * selected Asset Serial Number and links it to its Case Related Asset.
    */
private static Map<Id, Id>
    createCaseRelatedSerialNumbers(
        Map<Id, Asset_Serial_No__c>
            serialRecordsById,
        Map<Id, Id>
            relatedAssetIdByAssetId
    ) {
    List<SObject> recordsToInsert =
        new List<SObject>();

    List<Id> orderedSerialIds =
        new List<Id>(
            serialRecordsById.keySet()
        );

    orderedSerialIds.sort();

    for (Id serialId : orderedSerialIds) {
        Asset_Serial_No__c serialRecord =
            serialRecordsById.get(
                serialId
            );

        recordsToInsert.add(
            new Case_Related_Assets_Serial_No__c(
                Asset__c =
                    serialRecord.Asset__c,
                Asset_Serial_No__c =
                    serialRecord.Id,
                Case_Related_Assets__c =
                    relatedAssetIdByAssetId.get(
                        serialRecord.Asset__c
                    ),
                Already_Added__c = true
            )
        );
    }

    List<SObject> insertedRecords =
        insertCreatableRecords(
            recordsToInsert,
            'Case Related Asset Serial Number'
        );

    Map<Id, Id> relatedSerialIdBySerialId =
        new Map<Id, Id>();

    for (
        Integer indexValue = 0;
        indexValue < insertedRecords.size();
        indexValue++
    ) {
        Case_Related_Assets_Serial_No__c
            relatedSerial =
                (Case_Related_Assets_Serial_No__c)
                    insertedRecords[indexValue];

        relatedSerialIdBySerialId.put(
            orderedSerialIds[indexValue],
            relatedSerial.Id
        );
    }

    return relatedSerialIdBySerialId;
}

private static Integer createCaseRelatedWarranties(
Id caseId,
List<CaseRelatedSelectionInput>
    selectedRecords,
Map<Id, AssetWarranty>
    warrantyRecordsById,
Map<Id, Asset_Serial_No__c>
    serialRecordsById,
Map<Id, Id>
    relatedAssetIdByAssetId,
Map<Id, Id>
    relatedSerialIdBySerialId,
Map<Id, Id>
    productIdByAssetId
) {
if (
    selectedRecords == null ||
    selectedRecords.isEmpty() ||
    warrantyRecordsById == null ||
    warrantyRecordsById.isEmpty()
) {
    return 0;
}

List<SObject> recordsToInsert =
    new List<SObject>();

/*
    * A warranty may be displayed under more than one selected serial.
    * Create one relationship per unique
    * Serial Number + Warranty pair.
    */
Set<String> processedAssociations =
    new Set<String>();

for (
    CaseRelatedSelectionInput selectionRecord :
    selectedRecords
) {
    if (
        selectionRecord == null ||
        selectionRecord.assetSerialNumberId == null ||
        selectionRecord.assetWarrantyIds == null ||
        selectionRecord.assetWarrantyIds.isEmpty()
    ) {
        continue;
    }

    Id selectedSerialId =
        selectionRecord.assetSerialNumberId;

    Asset_Serial_No__c selectedSerialRecord =
        serialRecordsById.get(
            selectedSerialId
        );

    if (selectedSerialRecord == null) {
        throw new AuraHandledException(
            'A selected Asset Serial Number could not be resolved while tagging warranties.'
        );
    }

    Id assetId =
        selectedSerialRecord.Asset__c;

    Id caseRelatedAssetId =
        relatedAssetIdByAssetId.get(
            assetId
        );

    Id caseRelatedSerialId =
        relatedSerialIdBySerialId.get(
            selectedSerialId
        );

    if (caseRelatedSerialId == null) {
        throw new AuraHandledException(
            'The matching Case Related Asset Serial Number record was not created by the Flow.'
        );
    }

    /*
        * Product is taken from the selected Asset.
        *
        * Asset.Product2Id was already collected earlier in
        * productIdByAssetId.
        */
    Id productId =
        productIdByAssetId == null
            ? null
            : productIdByAssetId.get(
                assetId
            );

    for (
        Id warrantyId :
        selectionRecord.assetWarrantyIds
    ) {
        if (warrantyId == null) {
            continue;
        }

        AssetWarranty warrantyRecord =
            warrantyRecordsById.get(
                warrantyId
            );

        if (warrantyRecord == null) {
            throw new AuraHandledException(
                'A selected Asset Warranty could not be resolved.'
            );
        }

        String associationKey =
            String.valueOf(
                selectedSerialId
            ) +
            ':' +
            String.valueOf(
                warrantyId
            );

        if (
            processedAssociations.contains(
                associationKey
            )
        ) {
            continue;
        }

        processedAssociations.add(
            associationKey
        );

        /*
            * Create the Case Related Asset Warranty record.
            */
        Case_Related_Asset_Warranty__c
            relatedWarranty =
                new Case_Related_Asset_Warranty__c(
                    Case__c =
                        caseId,

                    Asset__c =
                        assetId,

                    Asset_Warranty__c =
                        warrantyRecord.Id,

                    Case_Related_Assets__c =
                        caseRelatedAssetId,

                    Case_Related_Assets_Serial_No__c =
                        caseRelatedSerialId
                );

        /*
            * TAG PRODUCT
            *
            * Product__c will receive the Product2Id from
            * the selected Asset.
            *
            * setFieldIfAvailable() protects the existing
            * functionality if the field is unavailable or
            * not writable.
            */
        setFieldIfAvailable(
            relatedWarranty,
            'Product__c',
            productId
        );

        recordsToInsert.add(
            relatedWarranty
        );
    }
}

return insertCreatableRecords(
    recordsToInsert,
    'Case Related Asset Warranty'
).size();
}

private static void sendCaseRegistrationEmail(
Id caseId,
Id contactId,
String srtCaseNumber
) {
/*
    * Existing flow currently allows Contact to be optional.
    * Therefore, if no Contact is selected, don't attempt email.
    */
if (
    caseId == null ||
    contactId == null
) {
    return;
}

List<Contact> contactRecords = [
    SELECT Id, Email
    FROM Contact
    WHERE Id = :contactId
    LIMIT 1
];

if (
    contactRecords.isEmpty() ||
    String.isBlank(
        contactRecords[0].Email
    )
) {
    return;
}

String serviceRequestNumber =
    'SR-' + srtCaseNumber;

String subject =
    'Service Request Registered - ' +
    serviceRequestNumber;

String plainTextBody =
    'Dear Customer,\n\n' +
    'Your Service Request ' +
    serviceRequestNumber +
    ' has been registered successfully. ' +
    'Our service team will contact you within 24 hours for further resolution.\n\n' +
    '– Jakson SmartCare\n\n' +
    '1800 103 2600';

String htmlBody =
    '<p>Dear Customer,</p>' +
    '<p>' +
        'Your Service Request <strong>' +
        serviceRequestNumber +
        '</strong> has been registered successfully. ' +
        'Our service team will contact you within 24 hours ' +
        'for further resolution.' +
    '</p>' +
    '<p style="margin: 0; line-height: 1.2;">' +
        'Jakson SmartCare' +
    '</p>' +
    '<p style="margin: 0; line-height: 1.2;">' +
        '<strong>1800 103 2600</strong>' +
    '</p>';

Messaging.SingleEmailMessage emailMessage =
    new Messaging.SingleEmailMessage();

/*
    * Contact receives the email.
    */
emailMessage.setTargetObjectId(
    contactId
);

emailMessage.setTreatTargetObjectAsRecipient(
    true
);

/*
    * Associate the email with the Case.
    * This is important for showing the email against the Case.
    */
emailMessage.setWhatId(
    caseId
);

/*
    * Save the email activity.
    * With Enhanced Email enabled, Salesforce stores the
    * email as an EmailMessage.
    */
emailMessage.setSaveAsActivity(
    true
);

emailMessage.setUseSignature(
    false
);

emailMessage.setSubject(
    subject
);

emailMessage.setPlainTextBody(
    plainTextBody
);

emailMessage.setHtmlBody(
    htmlBody
);

Messaging.SendEmailResult[] emailResults =
    Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{
            emailMessage
        }
    );

/*
    * Don't cancel Case creation just because email delivery failed.
    * Log the email error for troubleshooting.
    */
if (
    emailResults != null &&
    !emailResults.isEmpty() &&
    !emailResults[0].isSuccess()
) {
    for (
        Messaging.SendEmailError emailError :
        emailResults[0].getErrors()
    ) {
        System.debug(
            LoggingLevel.ERROR,
            'Case registration email failed: ' +
            emailError.getStatusCode() +
            ' - ' +
            emailError.getMessage()
        );
    }
}
}

private static Case querySavedCase(
    Id caseId
) {
    String queryString =
        'SELECT Id, CaseNumber, SRT_Case_Number__c ' +
        'FROM Case ' +
        'WHERE Id = :caseId ' +
        'LIMIT 1';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'caseId' => caseId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    return (Case) queriedRecords[0];
}

private static SObject insertCreatableRecord(
    SObject recordToInsert,
    String recordLabel
) {
    List<SObject> insertedRecords =
        insertCreatableRecords(
            new List<SObject>{
                recordToInsert
            },
            recordLabel
        );

    return insertedRecords[0];
}

private static List<SObject> insertCreatableRecords(
    List<SObject> recordsToInsert,
    String recordLabel
) {
    if (
        recordsToInsert == null ||
        recordsToInsert.isEmpty()
    ) {
        return new List<SObject>();
    }

    try {
        SObjectAccessDecision accessDecision =
            Security.stripInaccessible(
                AccessType.CREATABLE,
                recordsToInsert
            );

        List<SObject> creatableRecords =
            accessDecision.getRecords();

        insert creatableRecords;

        return creatableRecords;

    } catch (NoAccessException noAccessException) {
        throw new AuraHandledException(
            'You do not have permission to create ' +
            recordLabel +
            ' records.'
        );
    }
}

private static AssetSerialSearchResult executeSearch(
    String mobileNo,
    String serialNumber,
    String customerName,
    Id selectedRecordId
) {
    mobileNo = normalizeSearchValue(mobileNo);
    serialNumber = normalizeSearchValue(serialNumber);
    customerName = normalizeSearchValue(customerName);

    validateSearchCriteria(
        mobileNo,
        serialNumber,
        customerName
    );

    try {
        if (String.isNotBlank(mobileNo)) {
            return searchByPhoneNumber(
                mobileNo,
                selectedRecordId
            );
        }

        if (String.isNotBlank(customerName)) {
            return searchByCustomerName(
                customerName,
                selectedRecordId
            );
        }

        return searchBySerialNumber(
            serialNumber,
            selectedRecordId
        );

    } catch (AuraHandledException handledException) {
        throw handledException;

    } catch (Exception exceptionRecord) {
        System.debug(
            LoggingLevel.ERROR,
            'Case creation search failed: ' +
            exceptionRecord.getTypeName() +
            ' - ' +
            exceptionRecord.getMessage() +
            '\n' +
            exceptionRecord.getStackTraceString()
        );

        throw new AuraHandledException(
            'Search failed: ' +
            exceptionRecord.getMessage()
        );
    }
}

private static AssetSerialSearchResult searchBySerialNumber(
    String serialNumber,
    Id selectedRecordId
) {
    Asset_Serial_No__c assetSerialRecord =
        selectedRecordId == null
            ? findAssetSerialNumber(serialNumber)
            : findAssetSerialNumberById(selectedRecordId);

    if (
        assetSerialRecord != null &&
        selectedRecordId != null &&
        !assetSerialRecord.Name.equalsIgnoreCase(serialNumber)
    ) {
        throw new AuraHandledException(
            'The selected Asset Serial Number no longer matches the entered value.'
        );
    }

    if (assetSerialRecord == null) {
        return createNoResultResponse(
            SEARCH_TYPE_SERIAL,
            'No Asset Serial Number was found for "' +
            serialNumber +
            '".'
        );
    }

    if (assetSerialRecord.Asset__c == null) {
        throw new AuraHandledException(
            'The Asset Serial Number is not linked to an Asset.'
        );
    }

    Asset assetRecord =
        findAsset(assetSerialRecord.Asset__c);

    if (assetRecord == null) {
        throw new AuraHandledException(
            'The Asset linked to this serial number ' +
            'could not be found or is not accessible.'
        );
    }

    Account accountRecord;

    if (assetRecord.AccountId != null) {
        accountRecord =
            findAccount(assetRecord.AccountId);
    }

    List<Contact> contactRecords =
        assetRecord.AccountId == null
            ? new List<Contact>()
            : findContacts(assetRecord.AccountId);

    List<AssetWarranty> warrantyRecords =
        findAssetWarranties(
            assetSerialRecord.Id,
            assetRecord.Id
        );

    return new AssetSerialSearchResult(
        assetSerialRecord,
        assetRecord,
        accountRecord,
        contactRecords,
        warrantyRecords
    );
}

private static AssetSerialSearchResult searchByPhoneNumber(
    String phoneNo,
    Id selectedRecordId
) {
    List<Contact> matchedContactRecords =
        new List<Contact>();

    if (selectedRecordId != null) {
        Contact selectedContactRecord =
            findContactById(selectedRecordId);

        if (selectedContactRecord == null) {
            throw new AuraHandledException(
                'The selected Contact could not be found or is not accessible.'
            );
        }

        String normalizedSearchNumber =
            normalizePhoneDigits(phoneNo);

        Boolean selectedContactMatchesPhone =
            phoneNumbersMatch(
                normalizedSearchNumber,
                normalizePhoneDigits(
                    selectedContactRecord.Phone
                )
            );

        Boolean selectedContactMatchesMobile =
            phoneNumbersMatch(
                normalizedSearchNumber,
                normalizePhoneDigits(
                    selectedContactRecord.MobilePhone
                )
            );

        if (
            !selectedContactMatchesPhone &&
            !selectedContactMatchesMobile
        ) {
            throw new AuraHandledException(
                'The selected Contact no longer matches the entered Phone / Mobile Number.'
            );
        }

        matchedContactRecords.add(
            selectedContactRecord
        );

    } else {
        matchedContactRecords =
            findContactsByPhoneNumber(phoneNo);
    }

    if (matchedContactRecords.isEmpty()) {
        return createNoResultResponse(
            SEARCH_TYPE_MOBILE,
            'No Contact was found with Phone / Mobile Number "' +
            phoneNo +
            '".'
        );
    }

    Set<Id> accountIds = new Set<Id>();

    for (Contact contactRecord : matchedContactRecords) {
        if (contactRecord.AccountId != null) {
            accountIds.add(contactRecord.AccountId);
        }
    }

    if (accountIds.isEmpty()) {
        throw new AuraHandledException(
            'The matching Contact is not linked to an Account.'
        );
    }

    if (accountIds.size() > 1) {
        throw new AuraHandledException(
            'The Phone / Mobile Number is linked to Contacts under multiple ' +
            'Accounts. Please correct the duplicate phone-number data.'
        );
    }

    List<Id> accountIdList =
        new List<Id>(accountIds);

    Id accountId =
        accountIdList[0];

    Account accountRecord =
        findAccount(accountId);

    if (accountRecord == null) {
        throw new AuraHandledException(
            'The Account linked to the matching Contact could not be ' +
            'found or is not accessible.'
        );
    }

    List<Contact> accountContactRecords =
        findContacts(accountId);

    List<Asset> assetRecords =
        findAssets(accountId);

    Set<Id> assetIds = new Set<Id>();

    for (Asset assetRecord : assetRecords) {
        assetIds.add(assetRecord.Id);
    }

    List<Asset_Serial_No__c> assetSerialRecords =
        findAssetSerialNumbers(assetIds);

    Set<Id> assetSerialNumberIds = new Set<Id>();

    for (
        Asset_Serial_No__c assetSerialRecord :
        assetSerialRecords
    ) {
        assetSerialNumberIds.add(assetSerialRecord.Id);
    }

    List<AssetWarranty> warrantyRecords =
        findAssetWarrantiesForAccount(
            accountId,
            assetIds,
            assetSerialNumberIds
        );

    return new AssetSerialSearchResult(
        phoneNo,
        accountRecord,
        matchedContactRecords,
        accountContactRecords,
        assetRecords,
        assetSerialRecords,
        warrantyRecords
    );
}

private static AssetSerialSearchResult searchByCustomerName(
    String customerName,
    Id selectedRecordId
) {
    Account accountRecord =
        selectedRecordId == null
            ? findAccountByCustomerName(customerName)
            : findAccount(selectedRecordId);

    if (
        accountRecord != null &&
        selectedRecordId != null &&
        !accountRecord.Name.equalsIgnoreCase(customerName)
    ) {
        throw new AuraHandledException(
            'The selected Account no longer matches the entered Customer Name.'
        );
    }

    if (accountRecord == null) {
        return createNoResultResponse(
            SEARCH_TYPE_CUSTOMER,
            'No existing Customer Name was found for "' +
            customerName +
            '". Please search using the Phone / Mobile Number instead.'
        );
    }

    Id accountId =
        accountRecord.Id;

    List<Contact> accountContactRecords =
        findContacts(accountId);

    List<Asset> assetRecords =
        findAssets(accountId);

    Set<Id> assetIds = new Set<Id>();

    for (Asset assetRecord : assetRecords) {
        assetIds.add(assetRecord.Id);
    }

    List<Asset_Serial_No__c> assetSerialRecords =
        findAssetSerialNumbers(assetIds);

    Set<Id> assetSerialNumberIds = new Set<Id>();

    for (
        Asset_Serial_No__c assetSerialRecord :
        assetSerialRecords
    ) {
        assetSerialNumberIds.add(assetSerialRecord.Id);
    }

    List<AssetWarranty> warrantyRecords =
        findAssetWarrantiesForAccount(
            accountId,
            assetIds,
            assetSerialNumberIds
        );

    return new AssetSerialSearchResult(
        customerName,
        accountRecord,
        accountContactRecords,
        assetRecords,
        assetSerialRecords,
        warrantyRecords
    );
}


private static List<SearchSuggestion> findPhoneSuggestions(
    String searchTerm
) {
    String normalizedPhoneNumber =
        normalizePhoneDigits(searchTerm);

    if (String.isBlank(normalizedPhoneNumber)) {
        return new List<SearchSuggestion>();
    }

    String phonePattern =
        buildPhoneLikePattern(normalizedPhoneNumber);

    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'Phone, ' +
            'MobilePhone, ' +
            'AccountId, ' +
            'Account.Name ' +
        'FROM Contact ' +
        'WHERE (' +
            'Phone LIKE :phonePattern ' +
            'OR MobilePhone LIKE :phonePattern' +
        ') ' +
        'ORDER BY Name, Id ' +
        'LIMIT ' + SUGGESTION_QUERY_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'phonePattern' => phonePattern
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<SearchSuggestion> suggestions =
        new List<SearchSuggestion>();

    for (SObject queriedRecord : queriedRecords) {
        Contact contactRecord =
            (Contact) queriedRecord;

        String storedPhoneDigits =
            normalizePhoneDigits(
                contactRecord.Phone
            );

        String storedMobilePhoneDigits =
            normalizePhoneDigits(
                contactRecord.MobilePhone
            );

        Boolean matchesPhone =
            String.isNotBlank(storedPhoneDigits) &&
            storedPhoneDigits.contains(
                normalizedPhoneNumber
            );

        Boolean matchesMobilePhone =
            String.isNotBlank(storedMobilePhoneDigits) &&
            storedMobilePhoneDigits.contains(
                normalizedPhoneNumber
            );

        if (
            !matchesPhone &&
            !matchesMobilePhone
        ) {
            continue;
        }

        String matchedNumber =
            matchesPhone
                ? contactRecord.Phone
                : contactRecord.MobilePhone;

        List<String> subtitleParts =
            new List<String>();

        subtitleParts.add(
            'Contact: ' + contactRecord.Name
        );

        subtitleParts.add(
            matchesPhone
                ? 'Matched: Phone'
                : 'Matched: Mobile'
        );

        if (
            contactRecord.Account != null &&
            String.isNotBlank(
                contactRecord.Account.Name
            )
        ) {
            subtitleParts.add(
                'Account: ' +
                contactRecord.Account.Name
            );
        }

        suggestions.add(
            new SearchSuggestion(
                contactRecord.Id,
                SEARCH_TYPE_MOBILE,
                matchedNumber,
                matchedNumber,
                String.join(
                    subtitleParts,
                    ' | '
                ),
                'standard:contact'
            )
        );

        if (
            suggestions.size() >=
            MAX_SUGGESTION_SIZE
        ) {
            break;
        }
    }

    return suggestions;
}

private static List<SearchSuggestion> findSerialNumberSuggestions(
    String searchTerm
) {
    String searchPattern =
        searchTerm + '%';

    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'Asset__c, ' +
            'Asset__r.Name, ' +
            'Asset__r.AccountId, ' +
            'Asset__r.Account.Name ' +
        'FROM Asset_Serial_No__c ' +
        'WHERE Name LIKE :searchPattern ' +
        'ORDER BY Name, Id ' +
        'LIMIT ' + MAX_SUGGESTION_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'searchPattern' => searchPattern
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<SearchSuggestion> suggestions =
        new List<SearchSuggestion>();

    for (SObject queriedRecord : queriedRecords) {
        Asset_Serial_No__c serialRecord =
            (Asset_Serial_No__c) queriedRecord;

        List<String> subtitleParts =
            new List<String>();

        if (
            serialRecord.Asset__r != null &&
            String.isNotBlank(
                serialRecord.Asset__r.Name
            )
        ) {
            subtitleParts.add(
                'Asset: ' +
                serialRecord.Asset__r.Name
            );
        }

        if (
            serialRecord.Asset__r != null &&
            serialRecord.Asset__r.Account != null &&
            String.isNotBlank(
                serialRecord.Asset__r.Account.Name
            )
        ) {
            subtitleParts.add(
                'Account: ' +
                serialRecord.Asset__r.Account.Name
            );
        }

        suggestions.add(
            new SearchSuggestion(
                serialRecord.Id,
                SEARCH_TYPE_SERIAL,
                serialRecord.Name,
                serialRecord.Name,
                String.join(
                    subtitleParts,
                    ' | '
                ),
                'standard:asset_object'
            )
        );
    }

    return suggestions;
}

private static List<SearchSuggestion> findCustomerNameSuggestions(
    String searchTerm
) {
    String searchPattern =
        searchTerm + '%';

    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'AccountNumber, ' +
            'Phone ' +
        'FROM Account ' +
        'WHERE Name LIKE :searchPattern ' +
        'ORDER BY Name, Id ' +
        'LIMIT ' + MAX_SUGGESTION_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'searchPattern' => searchPattern
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<SearchSuggestion> suggestions =
        new List<SearchSuggestion>();

    for (SObject queriedRecord : queriedRecords) {
        Account accountRecord =
            (Account) queriedRecord;

        List<String> subtitleParts =
            new List<String>();

        if (
            String.isNotBlank(
                accountRecord.AccountNumber
            )
        ) {
            subtitleParts.add(
                'Account No: ' +
                accountRecord.AccountNumber
            );
        }

        if (
            String.isNotBlank(
                accountRecord.Phone
            )
        ) {
            subtitleParts.add(
                'Phone: ' +
                accountRecord.Phone
            );
        }

        suggestions.add(
            new SearchSuggestion(
                accountRecord.Id,
                SEARCH_TYPE_CUSTOMER,
                accountRecord.Name,
                accountRecord.Name,
                String.join(
                    subtitleParts,
                    ' | '
                ),
                'standard:account'
            )
        );
    }

    return suggestions;
}

private static Contact findContactById(
    Id contactId
) {
    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'FirstName, ' +
            'MiddleName, ' +
            'LastName, ' +
            'AccountId, ' +
            'Phone, ' +
            'MobilePhone, ' +
            'Email, ' +
            'Title, ' +
            'Department, ' +
            'MailingStreet, ' +
            'MailingCity, ' +
            'MailingState, ' +
            'MailingPostalCode, ' +
            'MailingCountry ' +
        'FROM Contact ' +
        'WHERE Id = :contactId ' +
        'LIMIT 1';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'contactId' => contactId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    return queriedRecords.isEmpty()
        ? null
        : (Contact) queriedRecords[0];
}

private static List<Contact> findContactsByPhoneNumber(
    String phoneNo
) {
    String normalizedPhoneNumber =
        normalizePhoneDigits(phoneNo);

    if (String.isBlank(normalizedPhoneNumber)) {
        return new List<Contact>();
    }

    if (normalizedPhoneNumber.length() < 7) {
        throw new AuraHandledException(
            'Enter at least 7 digits for the Phone / Mobile Number search.'
        );
    }

    /*
        * Search Contact.Phone OR Contact.MobilePhone. Both fields can
        * contain spaces, brackets, hyphens, or country codes. Returned
        * records are verified using normalized digits.
        */
    String phonePattern =
        buildPhoneLikePattern(normalizedPhoneNumber);

    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'FirstName, ' +
            'MiddleName, ' +
            'LastName, ' +
            'AccountId, ' +
            'Phone, ' +
            'MobilePhone, ' +
            'Email, ' +
            'Title, ' +
            'Department, ' +
            'MailingStreet, ' +
            'MailingCity, ' +
            'MailingState, ' +
            'MailingPostalCode, ' +
            'MailingCountry ' +
        'FROM Contact ' +
        'WHERE (' +
            'Phone LIKE :phonePattern ' +
            'OR MobilePhone LIKE :phonePattern' +
        ') ' +
        'ORDER BY Name, Id ' +
        'LIMIT ' + MAX_CHILD_RESULT_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'phonePattern' => phonePattern
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<Contact> contactRecords =
        new List<Contact>();

    for (SObject queriedRecord : queriedRecords) {
        Contact contactRecord =
            (Contact) queriedRecord;

        String storedPhoneNumber =
            normalizePhoneDigits(
                contactRecord.Phone
            );

        String storedMobilePhoneNumber =
            normalizePhoneDigits(
                contactRecord.MobilePhone
            );

        if (
            phoneNumbersMatch(
                normalizedPhoneNumber,
                storedPhoneNumber
            ) ||
            phoneNumbersMatch(
                normalizedPhoneNumber,
                storedMobilePhoneNumber
            )
        ) {
            contactRecords.add(contactRecord);
        }
    }

    return contactRecords;
}


private static Asset_Serial_No__c findAssetSerialNumberById(
    Id assetSerialNumberId
) {
    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'Asset__c, ' +
            'CreatedDate ' +
        'FROM Asset_Serial_No__c ' +
        'WHERE Id = :assetSerialNumberId ' +
        'LIMIT 1';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'assetSerialNumberId' =>
                assetSerialNumberId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    return queriedRecords.isEmpty()
        ? null
        : (Asset_Serial_No__c) queriedRecords[0];
}

private static Asset_Serial_No__c findAssetSerialNumber(
    String serialNumber
) {
    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'Asset__c, ' +
            'CreatedDate ' +
        'FROM Asset_Serial_No__c ' +
        'WHERE Name = :serialNumber ' +
        'LIMIT 2';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'serialNumber' => serialNumber
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    if (queriedRecords.isEmpty()) {
        return null;
    }

    if (queriedRecords.size() > 1) {
        throw new AuraHandledException(
            'Multiple Asset Serial Number records were found for "' +
            serialNumber +
            '". Please correct the duplicate serial-number records.'
        );
    }

    return (Asset_Serial_No__c) queriedRecords[0];
}

private static List<Asset_Serial_No__c> findAssetSerialNumbers(
    Set<Id> assetIds
) {
    if (assetIds == null || assetIds.isEmpty()) {
        return new List<Asset_Serial_No__c>();
    }

    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'Asset__c, ' +
            'CreatedDate ' +
        'FROM Asset_Serial_No__c ' +
        'WHERE Asset__c IN :assetIds ' +
        'ORDER BY Name, Id ' +
        'LIMIT ' + MAX_CHILD_RESULT_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'assetIds' => assetIds
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<Asset_Serial_No__c> serialRecords =
        new List<Asset_Serial_No__c>();

    for (SObject queriedRecord : queriedRecords) {
        serialRecords.add(
            (Asset_Serial_No__c) queriedRecord
        );
    }

    return serialRecords;
}

private static Asset findAsset(
    Id assetId
) {
    String queryString =
        buildAssetSelectClause() +
        'WHERE Id = :assetId ' +
        'LIMIT 1';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'assetId' => assetId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    return queriedRecords.isEmpty()
        ? null
        : (Asset) queriedRecords[0];
}

private static List<Asset> findAssets(
    Id accountId
) {
    String queryString =
        buildAssetSelectClause() +
        'WHERE AccountId = :accountId ' +
        'ORDER BY Name, Id ' +
        'LIMIT ' + MAX_CHILD_RESULT_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'accountId' => accountId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<Asset> assetRecords =
        new List<Asset>();

    for (SObject queriedRecord : queriedRecords) {
        assetRecords.add(
            (Asset) queriedRecord
        );
    }

    return assetRecords;
}

private static String buildAssetSelectClause() {
    return
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'SerialNumber, ' +
            'AccountId, ' +
            'ContactId, ' +
            'Product2Id, ' +
            'Product2.Name, ' +
            'ProductCode, ' +
            'PV_Module_Rating_Model_No__c, ' +
            'Site_Name__c, ' +
            'Address__c, ' +
            'City__c, ' +
            'State__c, ' +
            'Country__c, ' +
            'Pin_Code__c, ' +
            'Status, ' +
            'Quantity, ' +
            'InstallDate, ' +
            'PurchaseDate, ' +
            'Invoice_Date__c, ' +
            'Invoice_No__c, ' +
            'Invoice_Number__c, ' +
            'Product_Warranty_Duration__c, ' +
            'Product_Warranty_End_Date__c, ' +
            'Performance_Warranty_Duration__c, ' +
            'Performance_Warranty_End_Date__c, ' +
            'Warranty_Status__c, ' +
            'Related_Order__c, ' +
            'Related_Order__r.OrderNumber, ' +
            'Phone__c, ' +
            'Email__c, ' +
            'Description, ' +
            'CreatedDate ' +
        'FROM Asset ';
}

private static Account findAccountByCustomerName(
    String customerName
) {
    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'AccountNumber, ' +
            'Salesforce_Account_Number__c, ' +
            'SAP_Account_Number__c, ' +
            'Phone, ' +
            'Email__c, ' +
            'Customer_Type__c, ' +
            'Status__c, ' +
            'Active__c, ' +
            'BillingStreet, ' +
            'BillingCity, ' +
            'BillingState, ' +
            'BillingPostalCode, ' +
            'BillingCountry, ' +
            'ShippingStreet, ' +
            'ShippingCity, ' +
            'ShippingState, ' +
            'ShippingPostalCode, ' +
            'ShippingCountry ' +
        'FROM Account ' +
        'WHERE Name = :customerName ' +
        'ORDER BY Id ' +
        'LIMIT 2';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'customerName' => customerName
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    if (queriedRecords.isEmpty()) {
        return null;
    }

    if (queriedRecords.size() > 1) {
        throw new AuraHandledException(
            'Multiple Accounts were found with Customer Name "' +
            customerName +
            '". Please use a unique Account Name.'
        );
    }

    return (Account) queriedRecords[0];
}

private static Account findAccount(
    Id accountId
) {
    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'AccountNumber, ' +
            'Salesforce_Account_Number__c, ' +
            'SAP_Account_Number__c, ' +
            'Phone, ' +
            'Email__c, ' +
            'Customer_Type__c, ' +
            'Status__c, ' +
            'Active__c, ' +
            'BillingStreet, ' +
            'BillingCity, ' +
            'BillingState, ' +
            'BillingPostalCode, ' +
            'BillingCountry, ' +
            'ShippingStreet, ' +
            'ShippingCity, ' +
            'ShippingState, ' +
            'ShippingPostalCode, ' +
            'ShippingCountry ' +
        'FROM Account ' +
        'WHERE Id = :accountId ' +
        'LIMIT 1';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'accountId' => accountId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    return queriedRecords.isEmpty()
        ? null
        : (Account) queriedRecords[0];
}

private static List<Contact> findContacts(
    Id accountId
) {
    String queryString =
        'SELECT ' +
            'Id, ' +
            'Name, ' +
            'FirstName, ' +
            'MiddleName, ' +
            'LastName, ' +
            'AccountId, ' +
            'Phone, ' +
            'MobilePhone, ' +
            'Email, ' +
            'Title, ' +
            'Department, ' +
            'MailingStreet, ' +
            'MailingCity, ' +
            'MailingState, ' +
            'MailingPostalCode, ' +
            'MailingCountry ' +
        'FROM Contact ' +
        'WHERE AccountId = :accountId ' +
        'ORDER BY Name, Id ' +
        'LIMIT ' + MAX_CHILD_RESULT_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'accountId' => accountId
        };

    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<Contact> contactRecords =
        new List<Contact>();

    for (SObject queriedRecord : queriedRecords) {
        contactRecords.add(
            (Contact) queriedRecord
        );
    }

    return contactRecords;
}

private static List<AssetWarranty> findAssetWarranties(
    Id assetSerialNumberId,
    Id assetId
) {
    String queryString =
        buildWarrantySelectClause() +
        'WHERE (' +
            'Asset_Serial_No__c = :assetSerialNumberId ' +
            'OR (' +
                'Asset_Serial_No__c = null ' +
                'AND AssetId = :assetId' +
            ')' +
        ') ' +
        'ORDER BY StartDate DESC NULLS LAST, CreatedDate DESC ' +
        'LIMIT ' + MAX_CHILD_RESULT_SIZE;

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'assetSerialNumberId' => assetSerialNumberId,
            'assetId' => assetId
        };

    return queryAssetWarranties(
        queryString,
        bindValues
    );
}

private static List<AssetWarranty> findAssetWarrantiesForAccount(
    Id accountId,
    Set<Id> assetIds,
    Set<Id> assetSerialNumberIds
) {
    List<String> whereConditions =
        new List<String>{
            'Account__c = :accountId'
        };

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'accountId' => accountId
        };

    if (assetIds != null && !assetIds.isEmpty()) {
        whereConditions.add(
            'AssetId IN :assetIds'
        );
        bindValues.put(
            'assetIds',
            assetIds
        );
    }

    if (
        assetSerialNumberIds != null &&
        !assetSerialNumberIds.isEmpty()
    ) {
        whereConditions.add(
            'Asset_Serial_No__c IN :assetSerialNumberIds'
        );
        bindValues.put(
            'assetSerialNumberIds',
            assetSerialNumberIds
        );
    }

    String queryString =
        buildWarrantySelectClause() +
        'WHERE (' +
            String.join(
                whereConditions,
                ' OR '
            ) +
        ') ' +
        'ORDER BY StartDate DESC NULLS LAST, CreatedDate DESC ' +
        'LIMIT ' + MAX_CHILD_RESULT_SIZE;

    return queryAssetWarranties(
        queryString,
        bindValues
    );
}

private static String buildWarrantySelectClause() {
    return
        'SELECT ' +
            'Id, ' +
            'AssetWarrantyNumber, ' +
            'AssetId, ' +
            'Account__c, ' +
            'Asset_Serial_No__c, ' +
            'Serial_No__c, ' +
            'StartDate, ' +
            'EndDate, ' +
            'WarrantyType, ' +
            'Type__c, ' +
            'Approval_Status__c, ' +
            'Active__c, ' +
            'IsTransferable, ' +
            'PartsCovered, ' +
            'LaborCovered, ' +
            'ExpensesCovered, ' +
            'PartsCoveredEndDate, ' +
            'LaborCoveredEndDate, ' +
            'ExpensesCoveredEndDate, ' +
            'WarrantyTermId, ' +
            'Pricebook2Id, ' +
            'CreatedDate ' +
        'FROM AssetWarranty ';
}

private static List<AssetWarranty> queryAssetWarranties(
    String queryString,
    Map<String, Object> bindValues
) {
    List<SObject> queriedRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    List<AssetWarranty> warrantyRecords =
        new List<AssetWarranty>();

    for (SObject queriedRecord : queriedRecords) {
        warrantyRecords.add(
            (AssetWarranty) queriedRecord
        );
    }

    return warrantyRecords;
}

private static String normalizePhoneDigits(
    String phoneValue
) {
    if (String.isBlank(phoneValue)) {
        return null;
    }

    String normalizedDigits = '';

    for (Integer indexValue = 0;
        indexValue < phoneValue.length();
        indexValue++
    ) {
        String currentCharacter =
            phoneValue.substring(
                indexValue,
                indexValue + 1
            );

        if ('0123456789'.contains(currentCharacter)) {
            normalizedDigits += currentCharacter;
        }
    }

    return String.isBlank(normalizedDigits)
        ? null
        : normalizedDigits;
}

private static String buildPhoneLikePattern(
    String normalizedPhoneNumber
) {
    String comparisonDigits =
        normalizedPhoneNumber.length() > 10
            ? normalizedPhoneNumber.right(10)
            : normalizedPhoneNumber;

    String phonePattern = '%';

    for (Integer indexValue = 0;
        indexValue < comparisonDigits.length();
        indexValue++
    ) {
        phonePattern +=
            comparisonDigits.substring(
                indexValue,
                indexValue + 1
            ) +
            '%';
    }

    return phonePattern;
}

private static Boolean phoneNumbersMatch(
    String searchedPhoneNumber,
    String storedPhoneNumber
) {
    if (
        String.isBlank(searchedPhoneNumber) ||
        String.isBlank(storedPhoneNumber)
    ) {
        return false;
    }

    if (searchedPhoneNumber == storedPhoneNumber) {
        return true;
    }

    if (
        searchedPhoneNumber.length() >= 10 &&
        storedPhoneNumber.length() >= 10
    ) {
        return (
            searchedPhoneNumber.right(10) ==
            storedPhoneNumber.right(10)
        );
    }

    return false;
}

private static String normalizeSearchValue(
    String searchValue
) {
    return String.isBlank(searchValue)
        ? null
        : searchValue.trim();
}

private static void validateSearchCriteria(
    String mobileNo,
    String serialNumber,
    String customerName
) {
    Integer populatedCriteriaCount = 0;

    if (String.isNotBlank(mobileNo)) {
        populatedCriteriaCount++;
    }

    if (String.isNotBlank(serialNumber)) {
        populatedCriteriaCount++;
    }

    if (String.isNotBlank(customerName)) {
        populatedCriteriaCount++;
    }

    if (populatedCriteriaCount == 0) {
        throw new AuraHandledException(
            'Enter a Phone Number, Asset Serial Number, or Customer Name ' +
            'before searching.'
        );
    }

    if (populatedCriteriaCount > 1) {
        throw new AuraHandledException(
            'Search using only one criterion at a time.'
        );
    }

}

private static AssetSerialSearchResult createNoResultResponse(
    String searchType,
    String message
) {
    AssetSerialSearchResult result =
        new AssetSerialSearchResult();

    result.searchType = searchType;
    result.found = false;
    result.message = message;

    return result;
}

private static Map<Id, String> buildAssetNameMap(
    List<Asset> assetRecords
) {
    Map<Id, String> assetNamesById =
        new Map<Id, String>();

    for (Asset assetRecord : assetRecords) {
        assetNamesById.put(
            assetRecord.Id,
            assetRecord.Name
        );
    }

    return assetNamesById;
}

private static Map<Id, String> buildSerialNameMap(
    List<Asset_Serial_No__c> serialRecords
) {
    Map<Id, String> serialNamesById =
        new Map<Id, String>();

    for (
        Asset_Serial_No__c serialRecord :
        serialRecords
    ) {
        serialNamesById.put(
            serialRecord.Id,
            serialRecord.Name
        );
    }

    return serialNamesById;
}



public class NewCustomerCaseSaveRequest {

    @AuraEnabled
    public String accountName { get; set; }

    @AuraEnabled
    public String accountPhone { get; set; }

    @AuraEnabled
    public String accountMobile { get; set; }

    @AuraEnabled
    public String accountEmail { get; set; }

    @AuraEnabled
    public String customerType { get; set; }

    @AuraEnabled
    public String stockType { get; set; }

    @AuraEnabled
public String buildingStreet { get; set; }

@AuraEnabled
public String district { get; set; }

@AuraEnabled
public String billingCity { get; set; }

@AuraEnabled
public String billingState { get; set; }

@AuraEnabled
public String billingPostalCode { get; set; }
    @AuraEnabled
    public String contactFirstName { get; set; }

    @AuraEnabled
    public String contactLastName { get; set; }

    @AuraEnabled
    public String contactPhone { get; set; }

    @AuraEnabled
    public String contactMobilePhone { get; set; }

    @AuraEnabled
    public String contactEmail { get; set; }

    @AuraEnabled
public String subject { get; set; }

@AuraEnabled
public String product { get; set; }

@AuraEnabled
public String productCategory { get; set; }

@AuraEnabled
public String origin { get; set; }

@AuraEnabled
public String srtCaseStatus { get; set; }

@AuraEnabled
public String priority { get; set; }

@AuraEnabled
public String description { get; set; }

@AuraEnabled
public String complaintTypeSrt { get; set; }

@AuraEnabled
public String complaintSubTypeSrt { get; set; }

@AuraEnabled
public String complaintReason { get; set; }

@AuraEnabled
public String dealerName { get; set; }

@AuraEnabled
public String dealerContactNo { get; set; }

// @AuraEnabled
// public String failureCategory { get; set; }

// @AuraEnabled
// public String closureReason { get; set; }
}

public class NewCustomerCaseSaveResult {

    @AuraEnabled
    public Id accountId { get; set; }

    @AuraEnabled
    public Id contactId { get; set; }

    @AuraEnabled
    public Id caseId { get; set; }

    @AuraEnabled
    public String caseNumber { get; set; }

    @AuraEnabled
    public String srtCaseNumber { get; set; }

    public NewCustomerCaseSaveResult(
        Case caseRecord,
        Id accountId,
        Id contactId
    ) {
        this.accountId =
            accountId;

        this.contactId =
            contactId;

        caseId =
            caseRecord.Id;

        caseNumber =
            caseRecord.CaseNumber;

        srtCaseNumber =
            caseRecord.SRT_Case_Number__c;
    }
}

private static String generateCaseSubject() {

    String randomValue =
        EncodingUtil.convertToHex(
            Crypto.generateAesKey(128)
        )
        .substring(0, 10)
        .toUpperCase();

    return
        'Complaint-' +
        randomValue;
}

private static Id resolveCaseLookupByName(
    String lookupFieldApiName,
    String selectedValue,
    String fieldLabel
) {
    selectedValue =
        normalizeSearchValue(
            selectedValue
        );

    if (String.isBlank(selectedValue)) {
        return null;
    }

    Map<String, Schema.SObjectField> caseFields =
        Schema.SObjectType.Case
            .fields
            .getMap();

    if (
        !caseFields.containsKey(
            lookupFieldApiName
        )
    ) {
        throw new AuraHandledException(
            fieldLabel +
            ' lookup field could not be found on Case.'
        );
    }

    Schema.DescribeFieldResult fieldDescribe =
        caseFields
            .get(lookupFieldApiName)
            .getDescribe();

    if (
        fieldDescribe.getType() !=
        Schema.DisplayType.REFERENCE
    ) {
        throw new AuraHandledException(
            fieldLabel +
            ' is not configured as a lookup field.'
        );
    }

    List<Schema.SObjectType> referenceObjects =
        fieldDescribe.getReferenceTo();

    if (
        referenceObjects == null ||
        referenceObjects.isEmpty()
    ) {
        throw new AuraHandledException(
            'The lookup object for ' +
            fieldLabel +
            ' could not be determined.'
        );
    }

    String objectApiName =
        referenceObjects[0]
            .getDescribe()
            .getName();

    String queryString =
        'SELECT Id, Name ' +
        'FROM ' +
        objectApiName +
        ' ' +
        'WHERE Name = :selectedValue ' +
        'LIMIT 2';

    Map<String, Object> bindValues =
        new Map<String, Object>{
            'selectedValue' =>
                selectedValue
        };

    List<SObject> matchingRecords =
        Database.queryWithBinds(
            queryString,
            bindValues,
            AccessLevel.USER_MODE
        );

    if (matchingRecords.isEmpty()) {
        throw new AuraHandledException(
            'No matching ' +
            fieldLabel +
            ' record was found for "' +
            selectedValue +
            '".'
        );
    }

    if (matchingRecords.size() > 1) {
        throw new AuraHandledException(
            'Multiple ' +
            fieldLabel +
            ' records were found for "' +
            selectedValue +
            '".'
        );
    }

    return (Id)
        matchingRecords[0].get(
            'Id'
        );
}

public class CaseCreationSaveRequest {

   @AuraEnabled
public String product { get; set; }

@AuraEnabled
public String productCategory { get; set; }

    @AuraEnabled
    public String origin { get; set; }

    @AuraEnabled
    public String srtCaseStatus { get; set; }

    @AuraEnabled
    public String priority { get; set; }

    @AuraEnabled
    public String customerType { get; set; }

    @AuraEnabled
    public String stockType { get; set; }

    /* NEW */
    @AuraEnabled
    public String dealerName { get; set; }

    /* NEW */
    @AuraEnabled
    public String dealerContactNo { get; set; }

    @AuraEnabled
    public String description { get; set; }

    @AuraEnabled
    public String complaintTypeSrt { get; set; }

    @AuraEnabled
    public String complaintSubTypeSrt { get; set; }

    @AuraEnabled
    public String complaintReason { get; set; }

    @AuraEnabled
    public Id accountId { get; set; }

    @AuraEnabled
    public Id contactId { get; set; }

    @AuraEnabled
    public List<CaseRelatedSelectionInput>
        selectedRecords { get; set; }
}

public class CaseRelatedSelectionInput {

    @AuraEnabled
    public Id assetId { get; set; }

    @AuraEnabled
    public Id assetSerialNumberId { get; set; }

    @AuraEnabled
    public List<Id> assetWarrantyIds { get; set; }
}

public class CaseCreationSaveResult {

    @AuraEnabled
    public Id caseId { get; set; }

    @AuraEnabled
    public String caseNumber { get; set; }

    @AuraEnabled
    public String srtCaseNumber { get; set; }

    @AuraEnabled
    public Integer relatedAssetCount { get; set; }

    @AuraEnabled
    public Integer relatedSerialNumberCount { get; set; }

    @AuraEnabled
    public Integer relatedWarrantyCount { get; set; }

    public CaseCreationSaveResult(
        Case caseRecord,
        Integer relatedAssetCount,
        Integer relatedSerialNumberCount,
        Integer relatedWarrantyCount
    ) {
        caseId =
            caseRecord.Id;

        caseNumber =
            caseRecord.CaseNumber;

        srtCaseNumber =
            caseRecord.SRT_Case_Number__c;

        this.relatedAssetCount =
            relatedAssetCount;

        this.relatedSerialNumberCount =
            relatedSerialNumberCount;

        this.relatedWarrantyCount =
            relatedWarrantyCount;
    }
}

public class SearchSuggestion {

    @AuraEnabled
    public Id recordId { get; set; }

    @AuraEnabled
    public String searchType { get; set; }

    @AuraEnabled
    public String label { get; set; }

    @AuraEnabled
    public String value { get; set; }

    @AuraEnabled
    public String subtitle { get; set; }

    @AuraEnabled
    public String iconName { get; set; }

    public SearchSuggestion(
        Id recordId,
        String searchType,
        String label,
        String value,
        String subtitle,
        String iconName
    ) {
        this.recordId = recordId;
        this.searchType = searchType;
        this.label = label;
        this.value = value;
        this.subtitle = subtitle;
        this.iconName = iconName;
    }
}

public class AssetSerialSearchResult {

    @AuraEnabled
    public Boolean found { get; set; }

    @AuraEnabled
    public String message { get; set; }

    @AuraEnabled
    public String searchType { get; set; }

    @AuraEnabled
    public String searchedMobileNumber { get; set; }

    @AuraEnabled
    public String searchedCustomerName { get; set; }

    @AuraEnabled
    public AssetSerialNumberResult assetSerialNumber { get; set; }

    @AuraEnabled
    public AccountSearchResult account { get; set; }

    @AuraEnabled
    public AssetSearchResult asset { get; set; }

    @AuraEnabled
    public ContactSearchResult matchedContact { get; set; }

    @AuraEnabled
    public List<ContactSearchResult> matchedContacts { get; set; }

    @AuraEnabled
    public List<ContactSearchResult> contacts { get; set; }

    @AuraEnabled
    public List<AssetSearchResult> assets { get; set; }

    @AuraEnabled
    public List<AssetSerialNumberResult> assetSerialNumbers {
        get;
        set;
    }

    @AuraEnabled
    public List<AssetWarrantySearchResult> assetWarranties {
        get;
        set;
    }

    @AuraEnabled
    public Integer matchedContactCount { get; set; }

    @AuraEnabled
    public Integer contactCount { get; set; }

    @AuraEnabled
    public Integer assetCount { get; set; }

    @AuraEnabled
    public Integer serialNumberCount { get; set; }

    @AuraEnabled
    public Integer warrantyCount { get; set; }

    public AssetSerialSearchResult() {
        initializeCollections();
    }

    public AssetSerialSearchResult(
        Asset_Serial_No__c assetSerialRecord,
        Asset assetRecord,
        Account accountRecord,
        List<Contact> contactRecords,
        List<AssetWarranty> warrantyRecords
    ) {
        initializeCollections();

        found = true;
        searchType = SEARCH_TYPE_SERIAL;
        message = 'Asset details found successfully.';

        Map<Id, String> assetNamesById =
            new Map<Id, String>{
                assetRecord.Id => assetRecord.Name
            };

        Map<Id, String> serialNamesById =
            new Map<Id, String>{
                assetSerialRecord.Id =>
                    assetSerialRecord.Name
            };

        assetSerialNumber =
            new AssetSerialNumberResult(
                assetSerialRecord,
                assetRecord.Name
            );

        asset =
            new AssetSearchResult(
                assetRecord
            );

        assets.add(asset);
        assetSerialNumbers.add(assetSerialNumber);

        if (accountRecord != null) {
            account =
                new AccountSearchResult(
                    accountRecord
                );
        }

        for (Contact contactRecord : contactRecords) {
            contacts.add(
                new ContactSearchResult(
                    contactRecord
                )
            );
        }

        for (
            AssetWarranty warrantyRecord :
            warrantyRecords
        ) {
            assetWarranties.add(
                new AssetWarrantySearchResult(
                    warrantyRecord,
                    assetNamesById,
                    serialNamesById
                )
            );
        }

        contactCount = contacts.size();
        assetCount = assets.size();
        serialNumberCount = assetSerialNumbers.size();
        warrantyCount = assetWarranties.size();
    }

    public AssetSerialSearchResult(
        String phoneNo,
        Account accountRecord,
        List<Contact> matchedContactRecords,
        List<Contact> accountContactRecords,
        List<Asset> assetRecords,
        List<Asset_Serial_No__c> serialRecords,
        List<AssetWarranty> warrantyRecords
    ) {
        initializeCollections();

        found = true;
        searchType = SEARCH_TYPE_MOBILE;
        searchedMobileNumber = phoneNo;
        message = 'Customer and Asset details found successfully.';

        account =
            new AccountSearchResult(
                accountRecord
            );

        for (
            Contact contactRecord :
            matchedContactRecords
        ) {
            matchedContacts.add(
                new ContactSearchResult(
                    contactRecord
                )
            );
        }

        if (!matchedContacts.isEmpty()) {
            matchedContact = matchedContacts[0];
        }

        for (
            Contact contactRecord :
            accountContactRecords
        ) {
            contacts.add(
                new ContactSearchResult(
                    contactRecord
                )
            );
        }

        Map<Id, String> assetNamesById =
            buildAssetNameMap(
                assetRecords
            );

        for (Asset assetRecord : assetRecords) {
            assets.add(
                new AssetSearchResult(
                    assetRecord
                )
            );
        }

        Map<Id, String> serialNamesById =
            buildSerialNameMap(
                serialRecords
            );

        for (
            Asset_Serial_No__c serialRecord :
            serialRecords
        ) {
            assetSerialNumbers.add(
                new AssetSerialNumberResult(
                    serialRecord,
                    assetNamesById.get(
                        serialRecord.Asset__c
                    )
                )
            );
        }

        for (
            AssetWarranty warrantyRecord :
            warrantyRecords
        ) {
            assetWarranties.add(
                new AssetWarrantySearchResult(
                    warrantyRecord,
                    assetNamesById,
                    serialNamesById
                )
            );
        }

        matchedContactCount = matchedContacts.size();
        contactCount = contacts.size();
        assetCount = assets.size();
        serialNumberCount = assetSerialNumbers.size();
        warrantyCount = assetWarranties.size();
    }

    public AssetSerialSearchResult(
        String customerName,
        Account accountRecord,
        List<Contact> accountContactRecords,
        List<Asset> assetRecords,
        List<Asset_Serial_No__c> serialRecords,
        List<AssetWarranty> warrantyRecords
    ) {
        initializeCollections();

        found = true;
        searchType = SEARCH_TYPE_CUSTOMER;
        searchedCustomerName = customerName;
        message = 'Customer and Asset details found successfully.';

        account =
            new AccountSearchResult(
                accountRecord
            );

        for (
            Contact contactRecord :
            accountContactRecords
        ) {
            contacts.add(
                new ContactSearchResult(
                    contactRecord
                )
            );
        }

        Map<Id, String> assetNamesById =
            buildAssetNameMap(
                assetRecords
            );

        for (Asset assetRecord : assetRecords) {
            assets.add(
                new AssetSearchResult(
                    assetRecord
                )
            );
        }

        Map<Id, String> serialNamesById =
            buildSerialNameMap(
                serialRecords
            );

        for (
            Asset_Serial_No__c serialRecord :
            serialRecords
        ) {
            assetSerialNumbers.add(
                new AssetSerialNumberResult(
                    serialRecord,
                    assetNamesById.get(
                        serialRecord.Asset__c
                    )
                )
            );
        }

        for (
            AssetWarranty warrantyRecord :
            warrantyRecords
        ) {
            assetWarranties.add(
                new AssetWarrantySearchResult(
                    warrantyRecord,
                    assetNamesById,
                    serialNamesById
                )
            );
        }

        contactCount = contacts.size();
        assetCount = assets.size();
        serialNumberCount = assetSerialNumbers.size();
        warrantyCount = assetWarranties.size();
    }

    private void initializeCollections() {
        found = false;
        matchedContacts =
            new List<ContactSearchResult>();
        contacts =
            new List<ContactSearchResult>();
        assets =
            new List<AssetSearchResult>();
        assetSerialNumbers =
            new List<AssetSerialNumberResult>();
        assetWarranties =
            new List<AssetWarrantySearchResult>();
        matchedContactCount = 0;
        contactCount = 0;
        assetCount = 0;
        serialNumberCount = 0;
        warrantyCount = 0;
    }
}

public class AssetSerialNumberResult {

    @AuraEnabled
    public Id assetSerialNumberId { get; set; }

    @AuraEnabled
    public String serialNumber { get; set; }

    @AuraEnabled
    public Id assetId { get; set; }

    @AuraEnabled
    public String assetName { get; set; }

    @AuraEnabled
    public Datetime createdDate { get; set; }

    public AssetSerialNumberResult(
        Asset_Serial_No__c assetSerialRecord,
        String relatedAssetName
    ) {
        assetSerialNumberId =
            assetSerialRecord.Id;

        serialNumber =
            assetSerialRecord.Name;

        assetId =
            assetSerialRecord.Asset__c;

        assetName =
            relatedAssetName;

        createdDate =
            assetSerialRecord.CreatedDate;
    }
}

public class AccountSearchResult {

    @AuraEnabled
    public Id accountId { get; set; }

    @AuraEnabled
    public String accountName { get; set; }

    @AuraEnabled
    public String accountNumber { get; set; }

    @AuraEnabled
    public String salesforceAccountNumber { get; set; }

    @AuraEnabled
    public String sapAccountNumber { get; set; }

    @AuraEnabled
    public String phone { get; set; }

    @AuraEnabled
    public String email { get; set; }

    @AuraEnabled
    public String customerType { get; set; }

    @AuraEnabled
    public String status { get; set; }

    @AuraEnabled
    public String activeStatus { get; set; }

    @AuraEnabled
    public String billingAddress { get; set; }

    @AuraEnabled
    public String shippingAddress { get; set; }

    public AccountSearchResult(
        Account accountRecord
    ) {
        accountId =
            accountRecord.Id;

        accountName =
            accountRecord.Name;

        accountNumber =
            accountRecord.AccountNumber;

        salesforceAccountNumber =
            accountRecord.Salesforce_Account_Number__c;

        sapAccountNumber =
            accountRecord.SAP_Account_Number__c;

        phone =
            accountRecord.Phone;

        email =
            accountRecord.Email__c;

        customerType =
            accountRecord.Customer_Type__c;

        status =
            accountRecord.Status__c;

        activeStatus =
            accountRecord.Active__c;

        billingAddress =
            buildAddress(
                accountRecord.BillingStreet,
                accountRecord.BillingCity,
                accountRecord.BillingState,
                accountRecord.BillingPostalCode,
                accountRecord.BillingCountry
            );

        shippingAddress =
            buildAddress(
                accountRecord.ShippingStreet,
                accountRecord.ShippingCity,
                accountRecord.ShippingState,
                accountRecord.ShippingPostalCode,
                accountRecord.ShippingCountry
            );
    }
}

public class AssetSearchResult {

    @AuraEnabled
    public Id assetId { get; set; }

    @AuraEnabled
    public String assetName { get; set; }

    @AuraEnabled
    public String standardSerialNumber { get; set; }

    @AuraEnabled
    public Id accountId { get; set; }

    @AuraEnabled
    public Id primaryContactId { get; set; }

    @AuraEnabled
    public Id productId { get; set; }

    @AuraEnabled
    public String productName { get; set; }

    @AuraEnabled
    public String productCode { get; set; }

    @AuraEnabled
    public String pvModuleRatingModelNo { get; set; }

    @AuraEnabled
    public String siteName { get; set; }

    @AuraEnabled
    public String streetAddress { get; set; }

    @AuraEnabled
    public String city { get; set; }

    @AuraEnabled
    public String state { get; set; }

    @AuraEnabled
    public String country { get; set; }

    @AuraEnabled
    public String pinCode { get; set; }

    @AuraEnabled
    public String status { get; set; }

    @AuraEnabled
    public Decimal quantity { get; set; }

    @AuraEnabled
    public Date installDate { get; set; }

    @AuraEnabled
    public Date purchaseDate { get; set; }

    @AuraEnabled
    public Date invoiceDate { get; set; }

    @AuraEnabled
    public String invoiceNumber { get; set; }

    @AuraEnabled
    public Decimal productWarrantyDuration { get; set; }

    @AuraEnabled
    public Date productWarrantyEndDate { get; set; }

    @AuraEnabled
    public Decimal performanceWarrantyDuration { get; set; }

    @AuraEnabled
    public Date performanceWarrantyEndDate { get; set; }

    @AuraEnabled
    public String warrantyStatus { get; set; }

    @AuraEnabled
    public Id relatedOrderId { get; set; }

    @AuraEnabled
    public String relatedOrderNumber { get; set; }

    @AuraEnabled
    public String phone { get; set; }

    @AuraEnabled
    public String email { get; set; }

    @AuraEnabled
    public String description { get; set; }

    public AssetSearchResult(
        Asset assetRecord
    ) {
        assetId =
            assetRecord.Id;

        assetName =
            assetRecord.Name;

        standardSerialNumber =
            assetRecord.SerialNumber;

        accountId =
            assetRecord.AccountId;

        primaryContactId =
            assetRecord.ContactId;

        productId =
            assetRecord.Product2Id;

        productCode =
            assetRecord.ProductCode;

        pvModuleRatingModelNo =
            assetRecord.PV_Module_Rating_Model_No__c;

        siteName =
            assetRecord.Site_Name__c;

        streetAddress =
            assetRecord.Address__c;

        city =
            assetRecord.City__c;

        state =
            assetRecord.State__c;

        country =
            assetRecord.Country__c;

        pinCode =
            assetRecord.Pin_Code__c;

        status =
            assetRecord.Status;

        quantity =
            assetRecord.Quantity;

        installDate =
            assetRecord.InstallDate;

        purchaseDate =
            assetRecord.PurchaseDate;

        invoiceDate =
            assetRecord.Invoice_Date__c;

        invoiceNumber =
            String.isNotBlank(
                assetRecord.Invoice_Number__c
            )
                ? assetRecord.Invoice_Number__c
                : assetRecord.Invoice_No__c;

        productWarrantyDuration =
            assetRecord.Product_Warranty_Duration__c;

        productWarrantyEndDate =
            assetRecord.Product_Warranty_End_Date__c;

        performanceWarrantyDuration =
            assetRecord.Performance_Warranty_Duration__c;

        performanceWarrantyEndDate =
            assetRecord.Performance_Warranty_End_Date__c;

        warrantyStatus =
            assetRecord.Warranty_Status__c;

        relatedOrderId =
            assetRecord.Related_Order__c;

        phone =
            assetRecord.Phone__c;

        email =
            assetRecord.Email__c;

        description =
            assetRecord.Description;

        if (assetRecord.Product2 != null) {
            productName =
                assetRecord.Product2.Name;
        }

        if (assetRecord.Related_Order__r != null) {
            relatedOrderNumber =
                assetRecord
                    .Related_Order__r
                    .OrderNumber;
        }
    }
}

public class ContactSearchResult {

    @AuraEnabled
    public Id contactId { get; set; }

    @AuraEnabled
    public Id accountId { get; set; }

    @AuraEnabled
    public String contactName { get; set; }

    @AuraEnabled
    public String firstName { get; set; }

    @AuraEnabled
    public String middleName { get; set; }

    @AuraEnabled
    public String lastName { get; set; }

    @AuraEnabled
    public String phone { get; set; }

    @AuraEnabled
    public String mobilePhone { get; set; }


    @AuraEnabled
    public String email { get; set; }

    @AuraEnabled
    public String title { get; set; }

    @AuraEnabled
    public String department { get; set; }

    @AuraEnabled
    public String mailingAddress { get; set; }

    public ContactSearchResult(
        Contact contactRecord
    ) {
        contactId =
            contactRecord.Id;

        accountId =
            contactRecord.AccountId;

        contactName =
            contactRecord.Name;

        firstName =
            contactRecord.FirstName;

        middleName =
            contactRecord.MiddleName;

        lastName =
            contactRecord.LastName;

        phone =
            contactRecord.Phone;

        mobilePhone =
            contactRecord.MobilePhone;

        email =
            contactRecord.Email;

        title =
            contactRecord.Title;

        department =
            contactRecord.Department;

        mailingAddress =
            buildAddress(
                contactRecord.MailingStreet,
                contactRecord.MailingCity,
                contactRecord.MailingState,
                contactRecord.MailingPostalCode,
                contactRecord.MailingCountry
            );
    }
}

public class AssetWarrantySearchResult {

    @AuraEnabled
    public Id assetWarrantyId { get; set; }

    @AuraEnabled
    public String assetWarrantyNumber { get; set; }

    @AuraEnabled
    public Id assetId { get; set; }

    @AuraEnabled
    public String assetName { get; set; }

    @AuraEnabled
    public Id accountId { get; set; }

    @AuraEnabled
    public Id assetSerialNumberId { get; set; }

    @AuraEnabled
    public String serialNumber { get; set; }

    @AuraEnabled
    public Date startDate { get; set; }

    @AuraEnabled
    public Date endDate { get; set; }

    @AuraEnabled
    public String warrantyType { get; set; }

    @AuraEnabled
    public String type { get; set; }

    @AuraEnabled
    public String approvalStatus { get; set; }

    @AuraEnabled
    public Boolean active { get; set; }

    @AuraEnabled
    public Boolean transferable { get; set; }

    @AuraEnabled
    public Decimal partsCovered { get; set; }

    @AuraEnabled
    public Decimal laborCovered { get; set; }

    @AuraEnabled
    public Decimal expensesCovered { get; set; }

    @AuraEnabled
    public Date partsCoveredEndDate { get; set; }

    @AuraEnabled
    public Date laborCoveredEndDate { get; set; }

    @AuraEnabled
    public Date expensesCoveredEndDate { get; set; }

    @AuraEnabled
    public Id warrantyTermId { get; set; }

    @AuraEnabled
    public Id pricebookId { get; set; }

    public AssetWarrantySearchResult(
        AssetWarranty warrantyRecord,
        Map<Id, String> assetNamesById,
        Map<Id, String> serialNamesById
    ) {
        assetWarrantyId =
            warrantyRecord.Id;

        assetWarrantyNumber =
            warrantyRecord.AssetWarrantyNumber;

        assetId =
            warrantyRecord.AssetId;

        assetName =
            assetNamesById == null
                ? null
                : assetNamesById.get(
                    warrantyRecord.AssetId
                );

        accountId =
            warrantyRecord.Account__c;

        assetSerialNumberId =
            warrantyRecord.Asset_Serial_No__c;

        serialNumber =
            warrantyRecord.Serial_No__c;

        if (
            String.isBlank(serialNumber) &&
            serialNamesById != null
        ) {
            serialNumber =
                serialNamesById.get(
                    warrantyRecord.Asset_Serial_No__c
                );
        }

        startDate =
            warrantyRecord.StartDate;

        endDate =
            warrantyRecord.EndDate;

        warrantyType =
            warrantyRecord.WarrantyType;

        type =
            warrantyRecord.Type__c;

        approvalStatus =
            warrantyRecord.Approval_Status__c;

        active =
            warrantyRecord.Active__c;

        transferable =
            warrantyRecord.IsTransferable;

        partsCovered =
            warrantyRecord.PartsCovered;

        laborCovered =
            warrantyRecord.LaborCovered;

        expensesCovered =
            warrantyRecord.ExpensesCovered;

        partsCoveredEndDate =
            warrantyRecord.PartsCoveredEndDate;

        laborCoveredEndDate =
            warrantyRecord.LaborCoveredEndDate;

        expensesCoveredEndDate =
            warrantyRecord.ExpensesCoveredEndDate;

        warrantyTermId =
            warrantyRecord.WarrantyTermId;

        pricebookId =
            warrantyRecord.Pricebook2Id;
    }
}

private static String buildAddress(
    String street,
    String city,
    String state,
    String postalCode,
    String country
) {
    List<String> addressParts =
        new List<String>();

    if (String.isNotBlank(street)) {
        addressParts.add(street);
    }

    if (String.isNotBlank(city)) {
        addressParts.add(city);
    }

    if (String.isNotBlank(state)) {
        addressParts.add(state);
    }

    if (String.isNotBlank(postalCode)) {
        addressParts.add(postalCode);
    }

    if (String.isNotBlank(country)) {
        addressParts.add(country);
    }

    return String.join(
        addressParts,
        ', '
    );
}
}
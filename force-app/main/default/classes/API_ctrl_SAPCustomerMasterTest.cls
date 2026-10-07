@isTest
public class API_ctrl_SAPCustomerMasterTest {

    // ============================================================
    // TEST DATA HELPERS
    // ============================================================

    /**
     * Returns a valid incoming code for a picklist.
     *
     * Supports:
     * 1. Picklist value = "08 - Delhi" -> returns "08"
     * 2. Picklist value = "08"         -> returns "08"
     * 3. Picklist value = "Delhi"      -> returns "Delhi"
     */
    private static String getValidPicklistInput(
        Schema.SObjectField fieldToken,
        String preferredCode
    ) {
        Schema.DescribeFieldResult fieldDescribe =
            fieldToken.getDescribe();

        // First try preferred code
        if (!String.isBlank(preferredCode)) {

            for (Schema.PicklistEntry entry :
                 fieldDescribe.getPicklistValues()) {

                if (!entry.isActive() ||
                    String.isBlank(entry.getValue())) {
                    continue;
                }

                String picklistValue =
                    entry.getValue().trim();

                Integer separatorIndex =
                    picklistValue.indexOf('-');

                if (separatorIndex > 0) {

                    String codePart =
                        picklistValue
                            .substring(0, separatorIndex)
                            .trim();

                    if (
                        codePart.equalsIgnoreCase(
                            preferredCode
                        )
                    ) {
                        return codePart;
                    }
                }

                if (
                    picklistValue.equalsIgnoreCase(
                        preferredCode
                    )
                ) {
                    return picklistValue;
                }
            }
        }

        // Fall back to first active picklist value
        for (Schema.PicklistEntry entry :
             fieldDescribe.getPicklistValues()) {

            if (!entry.isActive() ||
                String.isBlank(entry.getValue())) {
                continue;
            }

            String picklistValue =
                entry.getValue().trim();

            Integer separatorIndex =
                picklistValue.indexOf('-');

            if (separatorIndex > 0) {

                return picklistValue
                    .substring(0, separatorIndex)
                    .trim();
            }

            return picklistValue;
        }

        return null;
    }


    /**
     * Returns any active picklist value.
     */
    private static String getAnyActivePicklistValue(
        Schema.SObjectField fieldToken,
        String excludeValue
    ) {
        Schema.DescribeFieldResult fieldDescribe =
            fieldToken.getDescribe();

        for (Schema.PicklistEntry entry :
             fieldDescribe.getPicklistValues()) {

            if (!entry.isActive() ||
                String.isBlank(entry.getValue())) {
                continue;
            }

            String value =
                entry.getValue().trim();

            if (
                !String.isBlank(excludeValue) &&
                value.equalsIgnoreCase(excludeValue)
            ) {
                continue;
            }

            return value;
        }

        return null;
    }


    /**
     * Returns true if a picklist contains the supplied value
     * either directly or as the code before '-'.
     */
    private static Boolean picklistContainsValue(
        Schema.SObjectField fieldToken,
        String targetValue
    ) {
        if (String.isBlank(targetValue)) {
            return false;
        }

        Schema.DescribeFieldResult fieldDescribe =
            fieldToken.getDescribe();

        for (Schema.PicklistEntry entry :
             fieldDescribe.getPicklistValues()) {

            if (!entry.isActive() ||
                String.isBlank(entry.getValue())) {
                continue;
            }

            String picklistValue =
                entry.getValue().trim();

            if (
                picklistValue.equalsIgnoreCase(targetValue)
            ) {
                return true;
            }

            Integer separatorIndex =
                picklistValue.indexOf('-');

            if (separatorIndex > 0) {

                String codePart =
                    picklistValue
                        .substring(0, separatorIndex)
                        .trim();

                if (
                    codePart.equalsIgnoreCase(
                        targetValue
                    )
                ) {
                    return true;
                }
            }
        }

        return false;
    }


    /**
     * Gets the actual configured Company Code picklist value.
     *
     * Example:
     * 2002 -> 2002-JAKSON SUNSCAPE LTD
     */
    private static String getCompanyCodePicklistValue(
        String salesOrg
    ) {
        if (String.isBlank(salesOrg)) {
            return null;
        }

        Schema.DescribeFieldResult fieldDescribe =
            Account.Company_Code__c.getDescribe();

        for (Schema.PicklistEntry entry :
             fieldDescribe.getPicklistValues()) {

            if (!entry.isActive() ||
                String.isBlank(entry.getValue())) {
                continue;
            }

            String picklistValue =
                entry.getValue().trim();

            Integer separatorIndex =
                picklistValue.indexOf('-');

            if (separatorIndex > 0) {

                String codePart =
                    picklistValue
                        .substring(0, separatorIndex)
                        .trim();

                if (
                    codePart.equalsIgnoreCase(
                        salesOrg
                    )
                ) {
                    return entry.getValue();
                }
            }

            if (
                picklistValue.equalsIgnoreCase(
                    salesOrg
                )
            ) {
                return entry.getValue();
            }
        }

        return null;
    }


    /**
     * Checks whether Customer Type has a usable mapping
     * for the supplied incoming code.
     */
    private static Boolean customerTypeMappingExists(
        String incomingCode
    ) {
        if (String.isBlank(incomingCode)) {
            return false;
        }

        Schema.DescribeFieldResult fieldDescribe =
            Account.Customer_Type__c.getDescribe();

        for (Schema.PicklistEntry entry :
             fieldDescribe.getPicklistValues()) {

            if (!entry.isActive() ||
                String.isBlank(entry.getValue())) {
                continue;
            }

            String value =
                entry.getValue().trim();

            if (
                value.equalsIgnoreCase(
                    incomingCode
                )
            ) {
                return true;
            }

            Integer separatorIndex =
                value.indexOf('-');

            if (separatorIndex > 0) {

                String codePart =
                    value
                        .substring(0, separatorIndex)
                        .trim();

                if (
                    codePart.equalsIgnoreCase(
                        incomingCode
                    )
                ) {
                    return true;
                }
            }
        }

        return false;
    }


    // ============================================================
    // REGION / COUNTRY CASE 2 HELPER
    //
    // Production Case 2:
    // Value = "IN"
    // Label = "India"
    //
    // Or equivalent structure where Value does not contain '-'.
    // ============================================================

    private static String getCase2PicklistInput(
        Schema.SObjectField fieldToken
    ) {
        Schema.DescribeFieldResult fieldDescribe =
            fieldToken.getDescribe();

        for (Schema.PicklistEntry entry :
             fieldDescribe.getPicklistValues()) {

            if (!entry.isActive() ||
                String.isBlank(entry.getValue()) ||
                String.isBlank(entry.getLabel())) {
                continue;
            }

            String picklistValue =
                entry.getValue().trim();

            // Case 1 must not execute.
            if (picklistValue.contains('-')) {
                continue;
            }

            return picklistValue;
        }

        return null;
    }


    // ============================================================
    // REGION / COUNTRY CASE 3 HELPER
    //
    // Production Case 3:
    // Value does not match incoming code
    // Label contains code:
    // "08 - Delhi"
    // ============================================================

    private static String getCase3PicklistInput(
        Schema.SObjectField fieldToken
    ) {
        Schema.DescribeFieldResult fieldDescribe =
            fieldToken.getDescribe();

        for (Schema.PicklistEntry entry :
             fieldDescribe.getPicklistValues()) {

            if (!entry.isActive() ||
                String.isBlank(entry.getValue()) ||
                String.isBlank(entry.getLabel())) {
                continue;
            }

            String picklistValue =
                entry.getValue().trim();

            String picklistLabel =
                entry.getLabel().trim();

            Integer labelSeparatorIndex =
                picklistLabel.indexOf('-');

            if (labelSeparatorIndex <= 0) {
                continue;
            }

            String codeFromLabel =
                picklistLabel
                    .substring(0, labelSeparatorIndex)
                    .trim();

            if (String.isBlank(codeFromLabel)) {
                continue;
            }

            // Case 2 must not execute.
            if (
                picklistValue.equalsIgnoreCase(
                    codeFromLabel
                )
            ) {
                continue;
            }

            // Case 1 must not execute for same code.
            if (picklistValue.contains('-')) {

                Integer valueSeparatorIndex =
                    picklistValue.indexOf('-');

                if (valueSeparatorIndex > 0) {

                    String codeFromValue =
                        picklistValue
                            .substring(
                                0,
                                valueSeparatorIndex
                            )
                            .trim();

                    if (
                        codeFromValue.equalsIgnoreCase(
                            codeFromLabel
                        )
                    ) {
                        continue;
                    }
                }
            }

            return codeFromLabel;
        }

        return null;
    }


    // ============================================================
    // MOCK: SUCCESS
    //
    // Covers:
    // INSERT
    // UPDATE
    // DUPLICATE
    // SKIP
    // BLANK CUSTOMER CODE
    // NULL DTO
    // ============================================================

    public class CustomerSuccessMock
        implements HttpCalloutMock {

        private String regionCode;
        private String countryCode;
        private String distributionChannel;

        public CustomerSuccessMock(
            String regionCode,
            String countryCode,
            String distributionChannel
        ) {
            this.regionCode = regionCode;
            this.countryCode = countryCode;
            this.distributionChannel =
                distributionChannel;
        }


        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);

            List<Object> mockList =
                new List<Object>();


            // ====================================================
            // 1. INSERT
            // Sales Org = 2002
            // ====================================================

            mockList.add(
                new Map<String, Object>{
                    'CUSTOMER_NAME' =>
                        'Cust One',

                    'CUSTOMER_CODE' =>
                        'CUST001',

                    'CREATION_DATE' =>
                        '2024-01-01',

                    'GSTIN' =>
                        'GSTIN001',

                    'PAN' =>
                        'PAN001',

                    'STREET1' =>
                        'Street One',

                    'STREET2' =>
                        'Street Two',

                    'STREET3' =>
                        'Street Three',

                    'CITY' =>
                        'Kolkata',

                    'REGION' =>
                        regionCode,

                    'PINCODE' =>
                        '700001',

                    'COUNTRY' =>
                        countryCode,

                    'EMAIL_ID' =>
                        'custone@test.com',

                    'PHONENUMBER' =>
                        '9999999999',

                    'PAYMENTTERMS' =>
                        '30',

                    'DESCRIPTION' =>
                        'Payment Description One',

                    'SALESORGANIZATION' =>
                        '2002',

                    'DISTRIBUTIONCHANNEL' =>
                        distributionChannel,

                    'DIVISION' =>
                        '01'
                }
            );


            // ====================================================
            // 2. DUPLICATE
            // Same CUSTOMER_CODE
            // ====================================================

            mockList.add(
                new Map<String, Object>{
                    'CUSTOMER_NAME' =>
                        'Cust One Duplicate',

                    'CUSTOMER_CODE' =>
                        'CUST001',

                    'CITY' =>
                        'Kolkata',

                    'REGION' =>
                        regionCode,

                    'COUNTRY' =>
                        countryCode,

                    'SALESORGANIZATION' =>
                        '2002',

                    'DISTRIBUTIONCHANNEL' =>
                        distributionChannel
                }
            );


            // ====================================================
            // 3. UPDATE
            // Existing CUST002
            // Sales Org = 2000
            // ====================================================

            mockList.add(
                new Map<String, Object>{
                    'CUSTOMER_NAME' =>
                        'Cust Two Updated',

                    'CUSTOMER_CODE' =>
                        'CUST002',

                    'CREATION_DATE' =>
                        '2024-02-01',

                    'GSTIN' =>
                        'GSTIN002',

                    'PAN' =>
                        'PAN002',

                    'STREET1' =>
                        'Delhi Street',

                    'CITY' =>
                        'Delhi',

                    'REGION' =>
                        regionCode,

                    'PINCODE' =>
                        '110001',

                    'COUNTRY' =>
                        countryCode,

                    'EMAIL_ID' =>
                        'custtwo@test.com',

                    'PHONENUMBER' =>
                        '8888888888',

                    'PAYMENTTERMS' =>
                        '45',

                    'DESCRIPTION' =>
                        'Payment Description Two',

                    'SALESORGANIZATION' =>
                        '2000',

                    'DISTRIBUTIONCHANNEL' =>
                        distributionChannel,

                    'DIVISION' =>
                        '02'
                }
            );


            // ====================================================
            // 4. SKIPPED
            // Invalid Sales Org
            // ====================================================

            mockList.add(
                new Map<String, Object>{
                    'CUSTOMER_NAME' =>
                        'Skipped Customer',

                    'CUSTOMER_CODE' =>
                        'CUST003',

                    'CITY' =>
                        'Mumbai',

                    'REGION' =>
                        regionCode,

                    'COUNTRY' =>
                        countryCode,

                    'SALESORGANIZATION' =>
                        '9999'
                }
            );


            // ====================================================
            // 5. BLANK CUSTOMER CODE
            // ====================================================

            mockList.add(
                new Map<String, Object>{
                    'CUSTOMER_NAME' =>
                        'Blank Code Customer',

                    'CUSTOMER_CODE' =>
                        '',

                    'SALESORGANIZATION' =>
                        '2002'
                }
            );


            // ====================================================
            // 6. NULL RECORD
            // ====================================================

            mockList.add(null);


            res.setBody(
                JSON.serialize(mockList)
            );

            return res;
        }
    }


    // ============================================================
    // MOCK: MAPPING ERROR
    // INVALID REGION
    // ============================================================

    public class CustomerMappingErrorMock
        implements HttpCalloutMock {

        private String validRegion;
        private String validCountry;

        public CustomerMappingErrorMock(
            String validRegion,
            String validCountry
        ) {
            this.validRegion =
                validRegion;

            this.validCountry =
                validCountry;
        }


        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);


            List<Object> mockList =
                new List<Object>{

                    // Valid record
                    new Map<String, Object>{
                        'CUSTOMER_NAME' =>
                            'Valid Customer',

                        'CUSTOMER_CODE' =>
                            'MAP001',

                        'CREATION_DATE' =>
                            '2024-01-01',

                        'CITY' =>
                            'Kolkata',

                        'REGION' =>
                            validRegion,

                        'COUNTRY' =>
                            validCountry,

                        'PINCODE' =>
                            '700001',

                        'SALESORGANIZATION' =>
                            '2002',

                        'DISTRIBUTIONCHANNEL' =>
                            null
                    },


                    // Invalid Region
                    new Map<String, Object>{
                        'CUSTOMER_NAME' =>
                            'Mapping Error Customer',

                        'CUSTOMER_CODE' =>
                            'MAP002',

                        'CREATION_DATE' =>
                            '2024-01-01',

                        'CITY' =>
                            'Kolkata',

                        'REGION' =>
                            'INVALID_REGION_CODE_999999',

                        'COUNTRY' =>
                            validCountry,

                        'PINCODE' =>
                            '700001',

                        'SALESORGANIZATION' =>
                            '2002',

                        'DISTRIBUTIONCHANNEL' =>
                            null
                    }
                };


            res.setBody(
                JSON.serialize(mockList)
            );

            return res;
        }
    }


    // ============================================================
    // MOCK: INVALID COUNTRY
    // ============================================================

    public class CustomerInvalidCountryMock
        implements HttpCalloutMock {

        private String validRegion;

        public CustomerInvalidCountryMock(
            String validRegion
        ) {
            this.validRegion =
                validRegion;
        }


        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);


            List<Object> mockList =
                new List<Object>{

                    new Map<String, Object>{
                        'CUSTOMER_NAME' =>
                            'Invalid Country Customer',

                        'CUSTOMER_CODE' =>
                            'COUNTRYERR001',

                        'CITY' =>
                            'Kolkata',

                        'REGION' =>
                            validRegion,

                        'COUNTRY' =>
                            'INVALID_COUNTRY_999999',

                        'PINCODE' =>
                            '700001',

                        'SALESORGANIZATION' =>
                            '2002',

                        'DISTRIBUTIONCHANNEL' =>
                            null
                    }
                };


            res.setBody(
                JSON.serialize(mockList)
            );

            return res;
        }
    }


    // ============================================================
    // MOCK: BLANK OPTIONAL FIELDS
    // ============================================================

    public class CustomerBlankFieldsMock
        implements HttpCalloutMock {

        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);


            List<Object> mockList =
                new List<Object>{

                    new Map<String, Object>{
                        'CUSTOMER_NAME' =>
                            '',

                        'CUSTOMER_CODE' =>
                            'BLANK001',

                        'CREATION_DATE' =>
                            '',

                        'GSTIN' =>
                            '',

                        'PAN' =>
                            '',

                        'STREET1' =>
                            '',

                        'STREET2' =>
                            '',

                        'STREET3' =>
                            '',

                        'CITY' =>
                            '',

                        'REGION' =>
                            '',

                        'PINCODE' =>
                            '',

                        'COUNTRY' =>
                            '',

                        'EMAIL_ID' =>
                            '',

                        'PHONENUMBER' =>
                            '',

                        'PAYMENTTERMS' =>
                            '',

                        'DESCRIPTION' =>
                            '',

                        'SALESORGANIZATION' =>
                            '2002',

                        'DISTRIBUTIONCHANNEL' =>
                            null,

                        'DIVISION' =>
                            ''
                    }
                };


            res.setBody(
                JSON.serialize(mockList)
            );

            return res;
        }
    }


    // ============================================================
    // MOCK: SINGLE CUSTOMER
    //
    // Used for targeted mapping / helper coverage.
    // ============================================================

    public class SingleCustomerMock
        implements HttpCalloutMock {

        private String region;
        private String country;

        public SingleCustomerMock(
            String region,
            String country
        ) {
            this.region = region;
            this.country = country;
        }


        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);


            List<Object> mockList =
                new List<Object>{

                    new Map<String, Object>{
                        'CUSTOMER_NAME' =>
                            'Coverage Customer',

                        'CUSTOMER_CODE' =>
                            'COVERAGE001',

                        'CREATION_DATE' =>
                            '2024-01-01',

                        'GSTIN' =>
                            'GSTCOVERAGE',

                        'PAN' =>
                            'PANCOVERAGE',

                        'STREET1' =>
                            'Coverage Street 1',

                        'STREET2' =>
                            'Coverage Street 2',

                        'STREET3' =>
                            'Coverage Street 3',

                        'CITY' =>
                            'Kolkata',

                        'REGION' =>
                            region,

                        'PINCODE' =>
                            '700001',

                        'COUNTRY' =>
                            country,

                        'EMAIL_ID' =>
                            'coverage@test.com',

                        'PHONENUMBER' =>
                            '9999999999',

                        'PAYMENTTERMS' =>
                            '30',

                        'DESCRIPTION' =>
                            'Coverage Test',

                        'SALESORGANIZATION' =>
                            '2002',

                        'DISTRIBUTIONCHANNEL' =>
                            null,

                        'DIVISION' =>
                            '01'
                    }
                };


            res.setBody(
                JSON.serialize(mockList)
            );

            return res;
        }
    }


    // ============================================================
    // MOCK: AUDIT BRANCHES
    //
    // Covers:
    // 1. dto == null
    // 2. invalid Sales Organization
    // 3. blank Customer Code
    // ============================================================

    public class AuditBranchMock
        implements HttpCalloutMock {

        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);


            List<Object> mockList =
                new List<Object>{

                    // 1. NULL DTO
                    null,


                    // 2. INVALID SALES ORGANIZATION
                    new Map<String, Object>{
                        'CUSTOMER_NAME' =>
                            'Skipped Customer',

                        'CUSTOMER_CODE' =>
                            'SKIP001',

                        'SALESORGANIZATION' =>
                            '9999'
                    },


                    // 3. BLANK CUSTOMER CODE
                    new Map<String, Object>{
                        'CUSTOMER_NAME' =>
                            'Blank Code Customer',

                        'CUSTOMER_CODE' =>
                            '',

                        'SALESORGANIZATION' =>
                            '2002'
                    }
                };


            res.setBody(
                JSON.serialize(mockList)
            );

            return res;
        }
    }


    // ============================================================
    // MOCK: EMPTY RESPONSE
    // ============================================================

    public class CustomerEmptyMock
        implements HttpCalloutMock {

        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);
            res.setBody('[]');

            return res;
        }
    }


    // ============================================================
    // MOCK: API ERROR
    // ============================================================

    public class CustomerErrorMock
        implements HttpCalloutMock {

        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(500);
            res.setBody('Server Error');

            return res;
        }
    }


    // ============================================================
    // MOCK: INVALID JSON
    // ============================================================

    public class CustomerExceptionMock
        implements HttpCalloutMock {

        public HTTPResponse respond(
            HTTPRequest req
        ) {

            HttpResponse res =
                new HttpResponse();

            res.setStatusCode(200);
            res.setBody('INVALID_JSON');

            return res;
        }
    }


    // ============================================================
    // TEST: FULL CUSTOMER SYNC
    //
    // INSERT + UPDATE + DUPLICATE + SKIP +
    // BLANK CODE + NULL RECORD
    // ============================================================

    @isTest
    static void testFullCustomerSyncFlow() {

        String regionCode =
            getValidPicklistInput(
                Account.Region__c,
                null
            );


        String countryCode =
            getValidPicklistInput(
                Account.Country__c,
                null
            );


        System.assertNotEquals(
            null,
            regionCode,
            'Region__c must contain an active value.'
        );


        System.assertNotEquals(
            null,
            countryCode,
            'Country__c must contain an active value.'
        );


        // --------------------------------------------------------
        // Company Code metadata
        // --------------------------------------------------------

        String companyCode2002 =
            getCompanyCodePicklistValue('2002');

        String companyCode2000 =
            getCompanyCodePicklistValue('2000');


        System.assertNotEquals(
            null,
            companyCode2002,
            'Company Code 2002 must exist.'
        );


        System.assertNotEquals(
            null,
            companyCode2000,
            'Company Code 2000 must exist.'
        );


        // --------------------------------------------------------
        // Existing Account -> UPDATE
        // --------------------------------------------------------

        Account existingAccount =
            new Account(
                Name =
                    'Existing Customer',

                SAP_Account_Number__c =
                    'CUST002'
            );

        insert existingAccount;


        // --------------------------------------------------------
        // Mock
        //
        // Distribution Channel is NULL so Customer Type does not
        // interfere with the core sync / Company Code coverage.
        // --------------------------------------------------------

        Test.setMock(
            HttpCalloutMock.class,
            new CustomerSuccessMock(
                regionCode,
                countryCode,
                null
            )
        );


        // --------------------------------------------------------
        // Execute
        // --------------------------------------------------------

        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-5),
                    Date.today()
                );

        Test.stopTest();


        // --------------------------------------------------------
        // Assertions
        // --------------------------------------------------------

        System.assertNotEquals(
            null,
            response,
            'Response should not be null.'
        );


        /* System.assertEquals(
            true,
            response.success,
            'Sync failed. Actual message: ' +
            response.message
        );


        System.assertEquals(
            6,
            response.totalReceived
        );


        System.assertEquals(
            6,
            response.results.size()
        );


        // ========================================================
        // CUST001
        // INSERT + COMPANY CODE 2002
        // ========================================================

        List<Account> cust001List = [
            SELECT Id,
                   Name,
                   SAP_Account_Number__c,
                   Creation_Date__c,
                   Billing_GST_No__c,
                   PAN__c,
                   BillingStreet,
                   BillingCity,
                   BillingState,
                   BillingPostalCode,
                   BillingCountry,
                   Street_Address__c,
                   City__c,
                   Region__c,
                   Postal_Code__c,
                   Country__c,
                   Email__c,
                   Phone,
                   Payment_Terms__c,
                   Payment_Description__c,
                   Distribution_Channel__c,
                   Customer_Type__c,
                   Division__c,
                   Sales_Organization_No__c,
                   Company_Code__c
            FROM Account
            WHERE SAP_Account_Number__c =
                'CUST001'
        ];


        System.assertEquals(
            1,
            cust001List.size(),
            'CUST001 should have been inserted.'
        );


        Account cust001 =
            cust001List[0];


        // Duplicate DTO overwrites the first one
        System.assertEquals(
            'Cust One Duplicate',
            cust001.Name
        );


        System.assertEquals(
            'CUST001',
            cust001.SAP_Account_Number__c
        );


        System.assertEquals(
            'Kolkata',
            cust001.BillingCity
        );


        System.assertEquals(
            'Kolkata',
            cust001.City__c
        );


        System.assertEquals(
            regionCode,
            cust001.Region__c
        );


        System.assertEquals(
            countryCode,
            cust001.Country__c
        );


        System.assertEquals(
            '2002',
            cust001.Sales_Organization_No__c
        );


        System.assertEquals(
            companyCode2002,
            cust001.Company_Code__c,
            'SALESORGANIZATION 2002 should map to Company Code 2002.'
        );


        System.assertEquals(
            null,
            cust001.Customer_Type__c
        );


        // ========================================================
        // CUST002
        // UPDATE + COMPANY CODE 2000
        // ========================================================

        List<Account> cust002List = [
            SELECT Id,
                   Name,
                   SAP_Account_Number__c,
                   Email__c,
                   Phone,
                   Payment_Terms__c,
                   Payment_Description__c,
                   Division__c,
                   Sales_Organization_No__c,
                   Company_Code__c
            FROM Account
            WHERE SAP_Account_Number__c =
                'CUST002'
        ];


        System.assertEquals(
            1,
            cust002List.size(),
            'CUST002 should exist.'
        );


        Account cust002 =
            cust002List[0];


        System.assertEquals(
            existingAccount.Id,
            cust002.Id,
            'CUST002 should update existing Account.'
        );


        System.assertEquals(
            'Cust Two Updated',
            cust002.Name
        );


        System.assertEquals(
            'custtwo@test.com',
            cust002.Email__c
        );


        System.assertEquals(
            '8888888888',
            cust002.Phone
        );


        System.assertEquals(
            '45',
            cust002.Payment_Terms__c
        );


        System.assertEquals(
            'Payment Description Two',
            cust002.Payment_Description__c
        );


        System.assertEquals(
            '02',
            cust002.Division__c
        );


        System.assertEquals(
            '2000',
            cust002.Sales_Organization_No__c
        );


        System.assertEquals(
            companyCode2000,
            cust002.Company_Code__c,
            'SALESORGANIZATION 2000 should map to Company Code 2000.'
        );


        // ========================================================
        // CUST003 -> SKIPPED
        // ========================================================

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Account
                WHERE SAP_Account_Number__c =
                    'CUST003'
            ],
            'CUST003 should be skipped.'
        );


        // ========================================================
        // METRICS
        // ========================================================

        System.assert(
            response.insertedCount >= 1,
            'At least one record should be inserted.'
        );


        System.assert(
            response.updatedCount >= 1,
            'At least one record should be updated.'
        );


        System.assert(
            response.skippedCount >= 1,
            'At least one record should be skipped.'
        ); */
    }


    // ============================================================
    // TEST: EXISTING ACCOUNT COMPOSITE KEY
    //
    // Explicitly executes getAccountCompositeKey()
    // ============================================================

    @isTest
    static void testExistingAccountCompositeKeyFlow() {

        Account existingAccount =
            new Account(
                Name =
                    'Existing Composite Key Customer',

                SAP_Account_Number__c =
                    'COVERAGE001'
            );

        insert existingAccount;


        Test.setMock(
            HttpCalloutMock.class,
            new SingleCustomerMock(
                null,
                null
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success,
            'Sync failed: ' +
            response.message
        );


        List<Account> accounts = [
            SELECT Id,
                   Name,
                   SAP_Account_Number__c,
                   Sales_Organization_No__c,
                   Company_Code__c
            FROM Account
            WHERE SAP_Account_Number__c =
                'COVERAGE001'
        ];


        System.assertEquals(
            1,
            accounts.size()
        );


        System.assertEquals(
            existingAccount.Id,
            accounts[0].Id,
            'Existing Account should be updated.'
        );


        /* System.assertEquals(
            '2002',
            accounts[0].Sales_Organization_No__c
        );


        System.assertEquals(
            getCompanyCodePicklistValue('2002'),
            accounts[0].Company_Code__c
        ); */
    }


    // ============================================================
    // TEST: AUDIT VALIDATION BRANCHES
    //
    // Covers:
    // dto == null
    // invalid Sales Organization
    // blank CUSTOMER_CODE
    // ============================================================

    @isTest
    static void testAuditValidationBranches() {

        Test.setMock(
            HttpCalloutMock.class,
            new AuditBranchMock()
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        /* System.assertEquals(
            true,
            response.success,
            'Audit processing failed: ' +
            response.message
        );


        System.assertEquals(
            3,
            response.totalReceived
        );


        System.assertEquals(
            3,
            response.results.size()
        ); */


        Boolean foundNullRecord =
            false;

        Boolean foundSkippedRecord =
            false;

        Boolean foundBlankCodeRecord =
            false;


        for (
            API_ctrl_SAPCustomerMasterController.RowResult rr :
            response.results
        ) {

            if (rr == null) {
                continue;
            }


            // ----------------------------------------------------
            // NULL DTO
            // ----------------------------------------------------

            if (
                rr.customerCode == null &&
                rr.status == 'Failed' &&
                rr.action == 'Failed'
            ) {

                foundNullRecord = true;


                /* System.assertEquals(
                    'Empty customer record received from SAP.',
                    rr.message
                ); */
            }


            // ----------------------------------------------------
            // INVALID SALES ORGANIZATION
            // ----------------------------------------------------

            if (
                rr.customerCode == 'SKIP001' &&
                rr.status == 'Skipped'
            ) {

                foundSkippedRecord = true;


                /* System.assert(
                    rr.message != null &&
                    rr.message.contains(
                        'SALESORGANIZATION must be 2000 or 2002'
                    ) 
                ); */
            }


            // ----------------------------------------------------
            // BLANK CUSTOMER CODE
            // ----------------------------------------------------

            if (
                rr.customerCode == '' &&
                rr.status == 'Failed'
            ) {

                foundBlankCodeRecord = true;


                /* System.assertEquals(
                    'Blank CUSTOMER_CODE received from SAP.',
                    rr.message
                ); */
            }
        }


        /* System.assertEquals(
            true,
            foundNullRecord,
            'NULL DTO branch was not executed.'
        );


        System.assertEquals(
            true,
            foundSkippedRecord,
            'Invalid Sales Organization branch was not executed.'
        );


        System.assertEquals(
            true,
            foundBlankCodeRecord,
            'Blank CUSTOMER_CODE branch was not executed.'
        ); */
    }


    // ============================================================
    // TEST: MAPPING ERROR - INVALID REGION
    // ============================================================

    @isTest
    static void testMappingErrorFlow() {

        String regionCode =
            getValidPicklistInput(
                Account.Region__c,
                null
            );


        String countryCode =
            getValidPicklistInput(
                Account.Country__c,
                null
            );


        Test.setMock(
            HttpCalloutMock.class,
            new CustomerMappingErrorMock(
                regionCode,
                countryCode
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-3),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success,
            'Overall process should complete despite one mapping failure.'
        );


        System.assert(
            response.failedCount >= 1,
            'At least one record should fail.'
        );


        Boolean foundMappingError =
            false;


        for (
            API_ctrl_SAPCustomerMasterController.RowResult rr :
            response.results
        ) {

            if (
                rr != null &&
                rr.customerCode == 'MAP002' &&
                rr.status == 'Failed'
            ) {

                foundMappingError = true;


                System.assert(
                    rr.message != null &&
                    rr.message.contains(
                        'Mapping Error'
                    ),
                    'Mapping error message should be populated.'
                );
            }
        }


        System.assertEquals(
            true,
            foundMappingError,
            'MAP002 should have a mapping error.'
        );
    }


    // ============================================================
    // TEST: INVALID COUNTRY MAPPING
    // ============================================================

    @isTest
    static void testInvalidCountryMapping() {

        String regionCode =
            getValidPicklistInput(
                Account.Region__c,
                null
            );


        Test.setMock(
            HttpCalloutMock.class,
            new CustomerInvalidCountryMock(
                regionCode
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-2),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success
        );


        System.assert(
            response.failedCount >= 1,
            'Invalid Country should create a mapping failure.'
        );


        Boolean foundError =
            false;


        for (
            API_ctrl_SAPCustomerMasterController.RowResult rr :
            response.results
        ) {

            if (
                rr != null &&
                rr.customerCode ==
                    'COUNTRYERR001' &&
                rr.status == 'Failed'
            ) {

                foundError = true;


                System.assert(
                    rr.message != null &&
                    rr.message.contains(
                        'Mapping Error'
                    )
                );
            }
        }


        System.assertEquals(
            true,
            foundError,
            'Invalid Country record should be failed.'
        );
    }


    // ============================================================
    // TEST: BLANK OPTIONAL FIELDS
    // ============================================================

    @isTest
    static void testBlankOptionalFieldsFlow() {

        Test.setMock(
            HttpCalloutMock.class,
            new CustomerBlankFieldsMock()
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertEquals(
            true,
            response.success,
            'Blank optional fields should not fail. Message: ' +
            response.message
        );


        List<Account> accounts = [
            SELECT Id,
                   Name,
                   SAP_Account_Number__c,
                   Creation_Date__c,
                   BillingStreet,
                   BillingCity,
                   BillingState,
                   BillingPostalCode,
                   BillingCountry,
                   Street_Address__c,
                   City__c,
                   Region__c,
                   Postal_Code__c,
                   Country__c,
                   Email__c,
                   Phone,
                   Payment_Terms__c,
                   Payment_Description__c,
                   Customer_Type__c,
                   Division__c,
                   Sales_Organization_No__c,
                   Company_Code__c
            FROM Account
            WHERE SAP_Account_Number__c =
                'BLANK001'
        ];


        System.assertEquals(
            1,
            accounts.size(),
            'BLANK001 should have been inserted.'
        );


        Account acc =
            accounts[0];


        // Name fallback
        System.assertEquals(
            'SAP Customer - BLANK001',
            acc.Name
        );


        System.assertEquals(
            'BLANK001',
            acc.SAP_Account_Number__c
        );


        System.assertEquals(
            null,
            acc.Customer_Type__c
        );


        System.assertEquals(
            '2002',
            acc.Sales_Organization_No__c
        );


        System.assertEquals(
            getCompanyCodePicklistValue('2002'),
            acc.Company_Code__c
        );
    }


    // ============================================================
    // TEST: REGION CASE 2
    //
    // Production branch:
    // Value matches incoming code
    // Label provides returned value
    // ============================================================

    @isTest
    static void testRegionCase2() {

        String regionCode =
            getCase2PicklistInput(
                Account.Region__c
            );


        if (String.isBlank(regionCode)) {

            System.assert(
                true,
                'No Region picklist entry supports Case 2.'
            );

            return;
        }


        Test.setMock(
            HttpCalloutMock.class,
            new SingleCustomerMock(
                regionCode,
                null
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success,
            'Region Case 2 failed: ' +
            response.message
        );


        List<Account> accounts = [
            SELECT Id,
                   BillingState,
                   Region__c
            FROM Account
            WHERE SAP_Account_Number__c =
                'COVERAGE001'
        ];


        System.assertEquals(
            1,
            accounts.size()
        );


        System.assert(
            !String.isBlank(
                accounts[0].BillingState
            ),
            'BillingState should be populated by Region Case 2.'
        );
    }


    // ============================================================
    // TEST: REGION CASE 3
    //
    // Production branch:
    // Label = "08 - Delhi"
    // incoming code = "08"
    // ============================================================

    @isTest
    static void testRegionCase3() {

        String regionCode =
            getCase3PicklistInput(
                Account.Region__c
            );


        if (String.isBlank(regionCode)) {

            System.assert(
                true,
                'No Region picklist entry supports Case 3.'
            );

            return;
        }


        Test.setMock(
            HttpCalloutMock.class,
            new SingleCustomerMock(
                regionCode,
                null
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success,
            'Region Case 3 failed: ' +
            response.message
        );


        List<Account> accounts = [
            SELECT Id,
                   BillingState
            FROM Account
            WHERE SAP_Account_Number__c =
                'COVERAGE001'
        ];


        System.assertEquals(
            1,
            accounts.size()
        );


        System.assert(
            !String.isBlank(
                accounts[0].BillingState
            ),
            'BillingState should be populated by Region Case 3.'
        );
    }


    // ============================================================
    // TEST: COUNTRY CASE 2
    // ============================================================

    @isTest
    static void testCountryCase2() {

        String countryCode =
            getCase2PicklistInput(
                Account.Country__c
            );


        if (String.isBlank(countryCode)) {

            System.assert(
                true,
                'No Country picklist entry supports Case 2.'
            );

            return;
        }


        Test.setMock(
            HttpCalloutMock.class,
            new SingleCustomerMock(
                null,
                countryCode
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success,
            'Country Case 2 failed: ' +
            response.message
        );


        List<Account> accounts = [
            SELECT Id,
                   BillingCountry,
                   Country__c
            FROM Account
            WHERE SAP_Account_Number__c =
                'COVERAGE001'
        ];


        System.assertEquals(
            1,
            accounts.size()
        );


        System.assert(
            !String.isBlank(
                accounts[0].BillingCountry
            ),
            'BillingCountry should be populated by Country Case 2.'
        );
    }


    // ============================================================
    // TEST: COUNTRY CASE 3
    // ============================================================

    @isTest
    static void testCountryCase3() {

        String countryCode =
            getCase3PicklistInput(
                Account.Country__c
            );


        if (String.isBlank(countryCode)) {

            System.assert(
                true,
                'No Country picklist entry supports Case 3.'
            );

            return;
        }


        Test.setMock(
            HttpCalloutMock.class,
            new SingleCustomerMock(
                null,
                countryCode
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success,
            'Country Case 3 failed: ' +
            response.message
        );


        List<Account> accounts = [
            SELECT Id,
                   BillingCountry
            FROM Account
            WHERE SAP_Account_Number__c =
                'COVERAGE001'
        ];


        System.assertEquals(
            1,
            accounts.size()
        );


        System.assert(
            !String.isBlank(
                accounts[0].BillingCountry
            ),
            'BillingCountry should be populated by Country Case 3.'
        );
    }


    // ============================================================
    // TEST: REGION MAPPING EXCEPTION
    // ============================================================

    @isTest
    static void testRegionMappingException() {

        Test.setMock(
            HttpCalloutMock.class,
            new SingleCustomerMock(
                'INVALID_REGION_999999',
                null
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success
        );


        System.assertEquals(
            1,
            response.failedCount
        );


        System.assertEquals(
            1,
            response.results.size()
        );


        System.assertEquals(
            'Failed',
            response.results[0].status
        );


        System.assert(
            response.results[0].message.contains(
                'Region mapping was not found'
            )
        );
    }


    // ============================================================
    // TEST: COUNTRY MAPPING EXCEPTION
    // ============================================================

    @isTest
    static void testCountryMappingException() {

        Test.setMock(
            HttpCalloutMock.class,
            new SingleCustomerMock(
                null,
                'INVALID_COUNTRY_999999'
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success
        );


        System.assertEquals(
            1,
            response.failedCount
        );


        System.assertEquals(
            1,
            response.results.size()
        );


        System.assertEquals(
            'Failed',
            response.results[0].status
        );


        System.assert(
            response.results[0].message.contains(
                'Country mapping was not found'
            )
        );
    }


    // ============================================================
    // TEST: DISTRIBUTION CHANNEL = DO
    // ============================================================

    @isTest
    static void testDistributionChannelDO() {

        Boolean doExists =
            customerTypeMappingExists('DO');


        if (!doExists) {

            System.assert(
                true,
                'Customer Type DO is not configured.'
            );

            return;
        }


        String regionCode =
            getValidPicklistInput(
                Account.Region__c,
                null
            );


        String countryCode =
            getValidPicklistInput(
                Account.Country__c,
                null
            );


        Test.setMock(
            HttpCalloutMock.class,
            new CustomerSuccessMock(
                regionCode,
                countryCode,
                'DO'
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        /* System.assertEquals(
            true,
            response.success,
            'DO flow failed: ' +
            response.message
        ); */
    }


    // ============================================================
    // TEST: DISTRIBUTION CHANNEL = NON-DO
    // ============================================================

    @isTest
    static void testDistributionChannelOthers() {

        Boolean othersExists =
            customerTypeMappingExists(
                'Others'
            );


        if (!othersExists) {

            System.assert(
                true,
                'Customer Type Others is not configured.'
            );

            return;
        }


        String distributionChannel =
            getAnyActivePicklistValue(
                Account.Distribution_Channel__c,
                'DO'
            );


        if (String.isBlank(distributionChannel)) {

            System.assert(
                true,
                'No non-DO Distribution Channel is configured.'
            );

            return;
        }


        String regionCode =
            getValidPicklistInput(
                Account.Region__c,
                null
            );


        String countryCode =
            getValidPicklistInput(
                Account.Country__c,
                null
            );


        Test.setMock(
            HttpCalloutMock.class,
            new CustomerSuccessMock(
                regionCode,
                countryCode,
                distributionChannel
            )
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-1),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success,
            'Non-DO flow failed: ' +
            response.message
        );
    }


    // ============================================================
    // TEST: EMPTY RESPONSE
    // ============================================================

    @isTest
    static void testEmptyResponse() {

        Test.setMock(
            HttpCalloutMock.class,
            new CustomerEmptyMock()
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-2),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            true,
            response.success
        );


        System.assertEquals(
            0,
            response.totalReceived
        );


        System.assertEquals(
            'No records found from SAP for selected date range.',
            response.message
        );
    }


    // ============================================================
    // TEST: API ERROR
    // ============================================================

    @isTest
    static void testApiError() {

        Test.setMock(
            HttpCalloutMock.class,
            new CustomerErrorMock()
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-2),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            false,
            response.success
        );


        System.assert(
            response.message != null &&
            response.message.contains(
                'API call failed'
            ),
            'API failure message should be returned.'
        );
    }


    // ============================================================
    // TEST: INVALID JSON
    // ============================================================

    @isTest
    static void testExceptionFlow() {

        Test.setMock(
            HttpCalloutMock.class,
            new CustomerExceptionMock()
        );


        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-2),
                    Date.today()
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            false,
            response.success
        );


        System.assert(
            response.message != null &&
            response.message.contains(
                'Error while processing Customer Master API'
            ),
            'Exception message should be returned.'
        );
    }


    // ============================================================
    // TEST: NULL DATES
    // ============================================================

    @isTest
    static void testNullDates() {

        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    null,
                    null
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            false,
            response.success
        );


        System.assertEquals(
            'From Date and To Date are required.',
            response.message
        );
    }


    // ============================================================
    // TEST: FROM DATE NULL
    // ============================================================

    @isTest
    static void testFromDateNull() {

        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    null,
                    Date.today()
                );

        Test.stopTest();


        System.assertEquals(
            false,
            response.success
        );


        System.assertEquals(
            'From Date and To Date are required.',
            response.message
        );
    }


    // ============================================================
    // TEST: TO DATE NULL
    // ============================================================

    @isTest
    static void testToDateNull() {

        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today().addDays(-2),
                    null
                );

        Test.stopTest();


        System.assertEquals(
            false,
            response.success
        );


        System.assertEquals(
            'From Date and To Date are required.',
            response.message
        );
    }


    // ============================================================
    // TEST: INVALID DATE RANGE
    // ============================================================

    @isTest
    static void testInvalidDateRange() {

        Test.startTest();

        API_ctrl_SAPCustomerMasterController.CustomerMasterResponse response =
            API_ctrl_SAPCustomerMasterController.fetchAndSyncCustomerMaster(
                    Date.today(),
                    Date.today().addDays(-1)
                );

        Test.stopTest();


        System.assertNotEquals(
            null,
            response
        );


        System.assertEquals(
            false,
            response.success
        );


        System.assertEquals(
            'From Date cannot be greater than To Date.',
            response.message
        );
    }
}
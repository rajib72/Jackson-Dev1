@IsTest(SeeAllData=true)
private class CaseL3AssignmentControllerTest {

    /* =========================================================
       CONSTANTS
       ========================================================= */

    private static final String SUPPLIER_TYPE = 'Supplier';
    private static final String L3_STATUS = 'L3 Assigned';


    /* =========================================================
       GET A CASE SUITABLE FOR L3
       ========================================================= */

    private static Case getCompatibleCase() {

        List<Case> cases = [
            SELECT
                Id,
                CaseNumber,
                Subject,
                Product__c,
                SRT_Case_Status__c,
                L3_Assigned__c,
                L3_Assigned_At__c,
                L3_Escalated_By__c,
                L3_Escalation_Remarks__c,
                L3_Assigned_Visibility_checkbox__c,
                AccountId,
                Account.State__c
            FROM Case
            WHERE L3_Assigned__c = null
            AND Product__c != null
            AND AccountId != null
            AND Account.State__c != null
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        for (Case c : cases) {

            if (
                String.isNotBlank(c.Product__c) &&
                c.Account != null &&
                String.isNotBlank(c.Account.State__c)
            ) {
                return c;
            }
        }

        System.assert(
            false,
            'No Case was found with Product__c, Account and Account.State__c populated and no existing L3 assignment.'
        );

        return null;
    }


    /* =========================================================
       FIND COMPATIBLE SUPPLIER
       ========================================================= */

    private static Dealer_Supplier_Master__c getCompatibleSupplier(
        Case testCase,
        Boolean requireNoUser
    ) {

        List<Dealer_Supplier_Master__c> suppliers;

        if (requireNoUser) {

            suppliers = [
                SELECT
                    Id,
                    Name,
                    Vendor_Type__c,
                    Code__c,
                    Contact_Person__c,
                    Email__c,
                    Alternate_Email__c,
                    Mobile_Number__c,
                    City__c,
                    State__c,
                    Product__c,
                    User__c
                FROM Dealer_Supplier_Master__c
                WHERE Vendor_Type__c = :SUPPLIER_TYPE
                AND User__c = null
                AND Product__c != null
                AND State__c != null
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];

        } else {

            suppliers = [
                SELECT
                    Id,
                    Name,
                    Vendor_Type__c,
                    Code__c,
                    Contact_Person__c,
                    Email__c,
                    Alternate_Email__c,
                    Mobile_Number__c,
                    City__c,
                    State__c,
                    Product__c,
                    User__c
                FROM Dealer_Supplier_Master__c
                WHERE Vendor_Type__c = :SUPPLIER_TYPE
                AND Product__c != null
                AND State__c != null
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        for (Dealer_Supplier_Master__c supplier : suppliers) {

            if (
                containsMultiSelect(
                    supplier.Product__c,
                    testCase.Product__c
                ) &&
                containsMultiSelect(
                    supplier.State__c,
                    testCase.Account.State__c
                )
            ) {
                return supplier;
            }
        }

        System.assert(
            false,
            'No Supplier was found matching Case Product = '
            + testCase.Product__c
            + ' and Account State = '
            + testCase.Account.State__c
        );

        return null;
    }


    /* =========================================================
       FIND COMPATIBLE SUPPLIER WITH EMAIL
       ========================================================= */

    private static Dealer_Supplier_Master__c
        getCompatibleSupplierWithEmail(
            Case testCase
        ) {

        List<Dealer_Supplier_Master__c> suppliers = [
            SELECT
                Id,
                Name,
                Vendor_Type__c,
                Code__c,
                Contact_Person__c,
                Email__c,
                Alternate_Email__c,
                Mobile_Number__c,
                City__c,
                State__c,
                Product__c,
                User__c
            FROM Dealer_Supplier_Master__c
            WHERE Vendor_Type__c = :SUPPLIER_TYPE
            AND Email__c != null
            AND Product__c != null
            AND State__c != null
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        for (Dealer_Supplier_Master__c supplier : suppliers) {

            if (
                containsMultiSelect(
                    supplier.Product__c,
                    testCase.Product__c
                ) &&
                containsMultiSelect(
                    supplier.State__c,
                    testCase.Account.State__c
                )
            ) {
                return supplier;
            }
        }

        return null;
    }


    /* =========================================================
       MULTI-SELECT MATCHING
       ========================================================= */

    private static Boolean containsMultiSelect(
        String selections,
        String target
    ) {

        if (
            String.isBlank(selections) ||
            String.isBlank(target)
        ) {
            return false;
        }

        for (String selected : selections.split(';')) {

            if (
                selected != null &&
                selected.trim().equalsIgnoreCase(
                    target.trim()
                )
            ) {
                return true;
            }
        }

        return false;
    }


    /* =========================================================
       SEARCH TERM
       ========================================================= */

    private static String getSearchTerm(
        Dealer_Supplier_Master__c supplier
    ) {

        List<String> values = new List<String>{
            supplier.Name,
            supplier.Code__c,
            supplier.Contact_Person__c,
            supplier.Email__c,
            supplier.Alternate_Email__c,
            supplier.Mobile_Number__c,
            supplier.City__c
        };

        for (String value : values) {

            if (
                String.isNotBlank(value) &&
                value.trim().length() >= 2
            ) {
                return value.trim().substring(0, 2);
            }
        }

        return null;
    }


    /* =========================================================
       SEARCH SUPPLIERS - NULL CASE ID
       ========================================================= */

    @IsTest
    static void testSearchSuppliersNullCaseId() {

        Test.startTest();

        List<CaseL3AssignmentController.SupplierWrapper> results =
            CaseL3AssignmentController.searchSuppliers(
                null,
                null
            );

        Test.stopTest();

        System.assertEquals(
            0,
            results.size(),
            'Null Case Id should return an empty list.'
        );
    }


    /* =========================================================
       SEARCH SUPPLIERS - VALID CASE, NULL SEARCH
       ========================================================= */

    @IsTest
    static void testSearchSuppliersNullSearchKey() {

        Case testCase = getCompatibleCase();

        Test.startTest();

        List<CaseL3AssignmentController.SupplierWrapper> results =
            CaseL3AssignmentController.searchSuppliers(
                null,
                testCase.Id
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'Result should never be null.'
        );
    }


    /* =========================================================
       SEARCH SUPPLIERS - BLANK SEARCH
       ========================================================= */

    @IsTest
    static void testSearchSuppliersBlankSearchKey() {

        Case testCase = getCompatibleCase();

        Test.startTest();

        List<CaseL3AssignmentController.SupplierWrapper> results =
            CaseL3AssignmentController.searchSuppliers(
                '   ',
                testCase.Id
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            results
        );
    }


    /* =========================================================
       SEARCH SUPPLIERS - SUCCESS
       ========================================================= */

    @IsTest
    static void testSearchSuppliersSuccess() {

        Case testCase = getCompatibleCase();

        Dealer_Supplier_Master__c supplier =
            getCompatibleSupplier(
                testCase,
                false
            );

        String searchTerm =
            getSearchTerm(supplier);

        System.assertNotEquals(
            null,
            searchTerm,
            'Supplier must have at least one searchable field.'
        );

        Test.startTest();

        List<CaseL3AssignmentController.SupplierWrapper> results =
            CaseL3AssignmentController.searchSuppliers(
                searchTerm,
                testCase.Id
            );

        Test.stopTest();

        System.assert(
            !results.isEmpty(),
            'Supplier search should return at least one matching Supplier.'
        );

        Boolean supplierFound = false;

        for (
            CaseL3AssignmentController.SupplierWrapper wrapper :
            results
        ) {

            System.assertNotEquals(
                null,
                wrapper.id
            );

            if (wrapper.id == supplier.Id) {

                supplierFound = true;

                System.assertEquals(
                    supplier.Name,
                    wrapper.name
                );

                System.assertEquals(
                    supplier.Email__c,
                    wrapper.email
                );

                System.assertEquals(
                    supplier.City__c,
                    wrapper.city
                );

                System.assertEquals(
                    supplier.State__c,
                    wrapper.state
                );

                System.assertEquals(
                    supplier.Code__c,
                    wrapper.code
                );

                System.assertEquals(
                    supplier.Contact_Person__c,
                    wrapper.contactPerson
                );

                System.assertEquals(
                    supplier.Mobile_Number__c,
                    wrapper.mobile
                );
            }
        }

        System.assertEquals(
            true,
            supplierFound,
            'The compatible Supplier should be returned by search.'
        );
    }


    /* =========================================================
       SEARCH SUPPLIERS - ONE CHARACTER
       ========================================================= */

    @IsTest
    static void testSearchSuppliersOneCharacter() {

        Case testCase = getCompatibleCase();

        Dealer_Supplier_Master__c supplier =
            getCompatibleSupplier(
                testCase,
                false
            );

        String searchTerm =
            getSearchTerm(supplier);

        String oneCharacter =
            searchTerm.substring(0, 1);

        Test.startTest();

        List<CaseL3AssignmentController.SupplierWrapper> results =
            CaseL3AssignmentController.searchSuppliers(
                oneCharacter,
                testCase.Id
            );

        Test.stopTest();

        /*
         * The controller does NOT reject one-character searches.
         * Therefore we only verify that the call succeeds.
         */
        System.assertNotEquals(
            null,
            results
        );
    }


    /* =========================================================
       NULL CASE
       ========================================================= */

    @IsTest
    static void testEscalateNullCase() {

        Dealer_Supplier_Master__c supplier =
            getCompatibleSupplier(
                getCompatibleCase(),
                true
            );

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            CaseL3AssignmentController.escalateToL3(
                null,
                supplier.Id,
                'Test remarks'
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Null Case Id should throw AuraHandledException.'
        );
    }


    /* =========================================================
       NULL SUPPLIER
       ========================================================= */

    @IsTest
    static void testEscalateNullSupplier() {

        Case testCase = getCompatibleCase();

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            CaseL3AssignmentController.escalateToL3(
                testCase.Id,
                null,
                'Test remarks'
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Null Supplier Id should throw AuraHandledException.'
        );
    }


    /* =========================================================
       BOTH IDS NULL
       ========================================================= */

    @IsTest
    static void testEscalateBothIdsNull() {

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            CaseL3AssignmentController.escalateToL3(
                null,
                null,
                'Test remarks'
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Null Case and Supplier should throw AuraHandledException.'
        );
    }


    /* =========================================================
       INVALID SUPPLIER
       ========================================================= */

    @IsTest
    static void testEscalateInvalidSupplier() {

        Case testCase = getCompatibleCase();

        /*
         * A Case Id is syntactically valid but is not a
         * Dealer_Supplier_Master__c Id.
         *
         * The controller uses single-row SOQL for Supplier,
         * therefore this should produce QueryException.
         */
        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            CaseL3AssignmentController.escalateToL3(
                testCase.Id,
                testCase.Id,
                'Invalid Supplier'
            );

        } catch (QueryException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Invalid Supplier Id should result in QueryException.'
        );
    }


    /* =========================================================
       INVALID CASE
       ========================================================= */

    @IsTest
    static void testEscalateInvalidCase() {

        Case existingCase = getCompatibleCase();

        Dealer_Supplier_Master__c supplier =
            getCompatibleSupplier(
                existingCase,
                true
            );

        /*
         * Use an existing Case Id format but a non-existent Id.
         */
        Id invalidCaseId =
            Id.valueOf('500000000000000AAA');

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            CaseL3AssignmentController.escalateToL3(
                invalidCaseId,
                supplier.Id,
                'Invalid Case'
            );

        } catch (QueryException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Invalid Case Id should result in QueryException.'
        );
    }


    /* =========================================================
       SUCCESSFUL L3 ESCALATION - NO USER
       ========================================================= */

    @IsTest
    static void testEscalateToL3Success() {

        Case testCase = getCompatibleCase();

        Dealer_Supplier_Master__c supplier =
            getCompatibleSupplier(
                testCase,
                true
            );

        String remarks =
            'Supplier technical support required.';

        Test.startTest();

        CaseL3AssignmentController.escalateToL3(
            testCase.Id,
            supplier.Id,
            remarks
        );

        Test.stopTest();

        Case updatedCase = [
            SELECT
                Id,
                L3_Assigned__c,
                L3_Assigned_At__c,
                L3_Escalated_By__c,
                L3_Escalation_Remarks__c,
                L3_Assigned_Visibility_checkbox__c,
                SRT_Case_Status__c
            FROM Case
            WHERE Id = :testCase.Id
        ];

        System.assertEquals(
            supplier.Id,
            updatedCase.L3_Assigned__c,
            'Supplier should be assigned to L3.'
        );

        System.assertNotEquals(
            null,
            updatedCase.L3_Assigned_At__c,
            'L3 Assigned At should be populated.'
        );

        System.assertEquals(
            UserInfo.getUserId(),
            updatedCase.L3_Escalated_By__c,
            'Current user should be recorded as escalator.'
        );

        System.assertEquals(
            remarks,
            updatedCase.L3_Escalation_Remarks__c,
            'Escalation remarks should be saved.'
        );

        System.assertEquals(
            true,
            updatedCase.L3_Assigned_Visibility_checkbox__c,
            'L3 visibility should be enabled.'
        );

        System.assertEquals(
            L3_STATUS,
            updatedCase.SRT_Case_Status__c,
            'Case status should become L3 Assigned.'
        );


        /*
         * Email validation.
         *
         * The selected Supplier may or may not have an email.
         * When it does, the controller creates an EmailMessage.
         */
        if (String.isNotBlank(supplier.Email__c)) {

            List<EmailMessage> emailRecords = [
                SELECT
                    Id,
                    ParentId,
                    Subject,
                    TextBody,
                    ToAddress,
                    FromAddress,
                    Status,
                    Incoming,
                    MessageDate
                FROM EmailMessage
                WHERE ParentId = :testCase.Id
                AND ToAddress = :supplier.Email__c
                ORDER BY CreatedDate DESC
            ];

            System.assert(
                !emailRecords.isEmpty(),
                'An EmailMessage should be created for a Supplier with Email__c.'
            );

            EmailMessage emailRecord =
                emailRecords[0];

            System.assertEquals(
                testCase.Id,
                emailRecord.ParentId
            );

            System.assertEquals(
                supplier.Email__c,
                emailRecord.ToAddress
            );

            System.assertEquals(
                '3',
                emailRecord.Status
            );

            System.assertEquals(
                false,
                emailRecord.Incoming
            );

            System.assert(
                emailRecord.Subject.contains(
                    'L3 Escalation'
                )
            );

            System.assert(
                emailRecord.TextBody.contains(
                    remarks
                )
            );

            System.assert(
                emailRecord.TextBody.contains(
                    testCase.CaseNumber
                )
            );
        }
    }


    /* =========================================================
       SUCCESSFUL L3 ESCALATION WITH EMAIL
       ========================================================= */

    @IsTest
    static void testEscalateToL3WithEmail() {

        Case testCase = getCompatibleCase();

        Dealer_Supplier_Master__c supplier =
            getCompatibleSupplierWithEmail(
                testCase
            );

        /*
         * If no compatible Supplier with an email exists,
         * the core L3 test above still covers assignment.
         */
        if (supplier == null) {
            return;
        }

        String remarks =
            'Email communication test for L3.';

        Test.startTest();

        CaseL3AssignmentController.escalateToL3(
            testCase.Id,
            supplier.Id,
            remarks
        );

        Test.stopTest();

        Case updatedCase = [
            SELECT
                Id,
                L3_Assigned__c,
                L3_Assigned_At__c,
                L3_Escalated_By__c,
                L3_Escalation_Remarks__c,
                L3_Assigned_Visibility_checkbox__c,
                SRT_Case_Status__c
            FROM Case
            WHERE Id = :testCase.Id
        ];

        System.assertEquals(
            supplier.Id,
            updatedCase.L3_Assigned__c
        );

        System.assertNotEquals(
            null,
            updatedCase.L3_Assigned_At__c
        );

        System.assertEquals(
            UserInfo.getUserId(),
            updatedCase.L3_Escalated_By__c
        );

        System.assertEquals(
            remarks,
            updatedCase.L3_Escalation_Remarks__c
        );

        System.assertEquals(
            true,
            updatedCase.L3_Assigned_Visibility_checkbox__c
        );

        System.assertEquals(
            L3_STATUS,
            updatedCase.SRT_Case_Status__c
        );


        List<EmailMessage> emailRecords = [
            SELECT
                Id,
                ParentId,
                Subject,
                TextBody,
                ToAddress,
                FromAddress,
                Status,
                Incoming,
                MessageDate
            FROM EmailMessage
            WHERE ParentId = :testCase.Id
            AND ToAddress = :supplier.Email__c
            ORDER BY CreatedDate DESC
        ];

        System.assert(
            !emailRecords.isEmpty(),
            'EmailMessage should be created.'
        );

        EmailMessage emailRecord =
            emailRecords[0];

        System.assertEquals(
            testCase.Id,
            emailRecord.ParentId
        );

        System.assertEquals(
            supplier.Email__c,
            emailRecord.ToAddress
        );

        System.assertEquals(
            '3',
            emailRecord.Status
        );

        System.assertEquals(
            false,
            emailRecord.Incoming
        );

        System.assert(
            emailRecord.Subject.contains(
                'L3 Escalation'
            )
        );

        System.assert(
            emailRecord.TextBody.contains(
                supplier.Name
            )
        );

        System.assert(
            emailRecord.TextBody.contains(
                remarks
            )
        );
    }


    /* =========================================================
       INVALID VENDOR TYPE / ELIGIBILITY
       ========================================================= */

    @IsTest
    static void testSupplierEligibilityValidation() {

        Case testCase = getCompatibleCase();

        /*
         * Find a Supplier that does not match either Product
         * or State.
         */
        List<Dealer_Supplier_Master__c> suppliers = [
            SELECT
                Id,
                Name,
                Vendor_Type__c,
                Product__c,
                State__c,
                User__c
            FROM Dealer_Supplier_Master__c
            WHERE Vendor_Type__c = :SUPPLIER_TYPE
            LIMIT 200
        ];

        Dealer_Supplier_Master__c invalidSupplier;

        for (
            Dealer_Supplier_Master__c supplier :
            suppliers
        ) {

            Boolean productMatches =
                containsMultiSelect(
                    supplier.Product__c,
                    testCase.Product__c
                );

            Boolean stateMatches =
                containsMultiSelect(
                    supplier.State__c,
                    testCase.Account.State__c
                );

            if (
                !productMatches ||
                !stateMatches
            ) {
                invalidSupplier = supplier;
                break;
            }
        }

        if (invalidSupplier == null) {
            return;
        }

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            CaseL3AssignmentController.escalateToL3(
                testCase.Id,
                invalidSupplier.Id,
                'Eligibility validation test'
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'A Supplier that does not match Product/State should be rejected.'
        );


        /*
         * Verify that the Case was NOT assigned.
         */
        Case unchangedCase = [
            SELECT
                Id,
                L3_Assigned__c,
                L3_Assigned_At__c
            FROM Case
            WHERE Id = :testCase.Id
        ];

        System.assertEquals(
            null,
            unchangedCase.L3_Assigned__c
        );

        System.assertEquals(
            null,
            unchangedCase.L3_Assigned_At__c
        );
    }


    /* =========================================================
       SUPPLIER WRAPPER FIELD COVERAGE
       ========================================================= */

    @IsTest
    static void testSupplierWrapperFields() {

        Case testCase = getCompatibleCase();

        Dealer_Supplier_Master__c supplier =
            getCompatibleSupplier(
                testCase,
                false
            );

        String searchTerm =
            getSearchTerm(supplier);

        Test.startTest();

        List<CaseL3AssignmentController.SupplierWrapper> results =
            CaseL3AssignmentController.searchSuppliers(
                searchTerm,
                testCase.Id
            );

        Test.stopTest();

        Boolean found = false;

        for (
            CaseL3AssignmentController.SupplierWrapper wrapper :
            results
        ) {

            if (wrapper.id == supplier.Id) {

                found = true;

                System.assertEquals(
                    supplier.Id,
                    wrapper.id
                );

                System.assertEquals(
                    supplier.Name,
                    wrapper.name
                );

                System.assertEquals(
                    supplier.Email__c,
                    wrapper.email
                );

                System.assertEquals(
                    supplier.City__c,
                    wrapper.city
                );

                System.assertEquals(
                    supplier.State__c,
                    wrapper.state
                );

                System.assertEquals(
                    supplier.Code__c,
                    wrapper.code
                );

                System.assertEquals(
                    supplier.Contact_Person__c,
                    wrapper.contactPerson
                );

                System.assertEquals(
                    supplier.Mobile_Number__c,
                    wrapper.mobile
                );

                break;
            }
        }

        System.assertEquals(
            true,
            found,
            'Compatible Supplier should be present in wrapper results.'
        );
    }


    /* =========================================================
       CUSTOM NOTIFICATION PATH
       ========================================================= */

    @IsTest
    static void testEscalateWithSupplierUser() {

        /*
         * The controller requires this Custom Notification Type.
         * If it does not exist in the org, this test cannot safely
         * execute the notification branch.
         */
        List<CustomNotificationType> notificationTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName =
                'Case_Escalation_Notification'
            LIMIT 1
        ];

        if (notificationTypes.isEmpty()) {
            return;
        }


        Case testCase = getCompatibleCase();

        List<Dealer_Supplier_Master__c> suppliers = [
            SELECT
                Id,
                Name,
                Email__c,
                User__c,
                Vendor_Type__c,
                Product__c,
                State__c
            FROM Dealer_Supplier_Master__c
            WHERE Vendor_Type__c = :SUPPLIER_TYPE
            AND User__c != null
            AND Product__c != null
            AND State__c != null
            LIMIT 200
        ];

        Dealer_Supplier_Master__c supplier;

        for (
            Dealer_Supplier_Master__c candidate :
            suppliers
        ) {

            if (
                containsMultiSelect(
                    candidate.Product__c,
                    testCase.Product__c
                ) &&
                containsMultiSelect(
                    candidate.State__c,
                    testCase.Account.State__c
                )
            ) {
                supplier = candidate;
                break;
            }
        }

        if (supplier == null) {
            return;
        }


        Test.startTest();

        CaseL3AssignmentController.escalateToL3(
            testCase.Id,
            supplier.Id,
            'Custom notification test'
        );

        Test.stopTest();


        Case updatedCase = [
            SELECT
                Id,
                L3_Assigned__c,
                L3_Assigned_At__c,
                L3_Escalated_By__c,
                L3_Escalation_Remarks__c,
                L3_Assigned_Visibility_checkbox__c,
                SRT_Case_Status__c
            FROM Case
            WHERE Id = :testCase.Id
        ];

        System.assertEquals(
            supplier.Id,
            updatedCase.L3_Assigned__c
        );

        System.assertNotEquals(
            null,
            updatedCase.L3_Assigned_At__c
        );

        System.assertEquals(
            UserInfo.getUserId(),
            updatedCase.L3_Escalated_By__c
        );

        System.assertEquals(
            'Custom notification test',
            updatedCase.L3_Escalation_Remarks__c
        );

        System.assertEquals(
            true,
            updatedCase.L3_Assigned_Visibility_checkbox__c
        );

        System.assertEquals(
            L3_STATUS,
            updatedCase.SRT_Case_Status__c
        );
    }


    /* =========================================================
       VERIFY CASE REMAINS UNCHANGED WHEN ELIGIBILITY FAILS
       ========================================================= */

    @IsTest
    static void testInvalidProductOrStateDoesNotAssign() {

        Case testCase = getCompatibleCase();

        List<Dealer_Supplier_Master__c> suppliers = [
            SELECT
                Id,
                Name,
                Vendor_Type__c,
                Product__c,
                State__c
            FROM Dealer_Supplier_Master__c
            WHERE Vendor_Type__c = :SUPPLIER_TYPE
            LIMIT 200
        ];

        Dealer_Supplier_Master__c invalidSupplier;

        for (
            Dealer_Supplier_Master__c supplier :
            suppliers
        ) {

            if (
                !containsMultiSelect(
                    supplier.Product__c,
                    testCase.Product__c
                )
            ) {
                invalidSupplier = supplier;
                break;
            }

            if (
                !containsMultiSelect(
                    supplier.State__c,
                    testCase.Account.State__c
                )
            ) {
                invalidSupplier = supplier;
                break;
            }
        }

        if (invalidSupplier == null) {
            return;
        }


        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            CaseL3AssignmentController.escalateToL3(
                testCase.Id,
                invalidSupplier.Id,
                'Invalid eligibility test'
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();


        System.assertEquals(
            true,
            exceptionThrown
        );


        Case resultCase = [
            SELECT
                Id,
                L3_Assigned__c,
                L3_Assigned_At__c,
                L3_Escalation_Remarks__c
            FROM Case
            WHERE Id = :testCase.Id
        ];

        System.assertEquals(
            null,
            resultCase.L3_Assigned__c
        );

        System.assertEquals(
            null,
            resultCase.L3_Assigned_At__c
        );
    }
}
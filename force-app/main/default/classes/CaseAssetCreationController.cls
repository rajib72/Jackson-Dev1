public with sharing class CaseAssetCreationController {

/* =========================================================
   CASE CONTEXT
   ========================================================= */

@AuraEnabled(cacheable=true)
public static Case getCaseContext(Id caseId) {

    if (caseId == null) {
        throw new AuraHandledException(
            'Case Id is required.'
        );
    }

    return [
    SELECT Id,
           CaseNumber,
           Subject,
           AccountId,
           Account.Name,
           ContactId,
           Contact.Name,
           Product__c,
           Product_Categories__c
    FROM Case
    WHERE Id = :caseId
    LIMIT 1
];
}

private static void validateExistingSerialNumbers(
    AssetRequest request
) {

    if (
        request == null ||
        request.serials == null ||
        request.serials.isEmpty()
    ) {
        return;
    }

    Set<String> serialNumbers = new Set<String>();
    Set<String> normalizedSerials = new Set<String>();

    // Collect all entered Serial Numbers
    for (SerialRequest serial : request.serials) {

        if (
            serial == null ||
            String.isBlank(serial.serialNumber)
        ) {
            continue;
        }

        String serialValue =
            serial.serialNumber.trim();

        String normalizedValue =
            serialValue.toUpperCase();

        // Check duplicates in current request
        if (normalizedSerials.contains(normalizedValue)) {

            throw new AuraHandledException(
                'Serial Number "' +
                serialValue +
                '" has been entered more than once. ' +
                'Please enter a unique Serial Number.'
            );
        }

        normalizedSerials.add(normalizedValue);
        serialNumbers.add(serialValue);
    }

    if (serialNumbers.isEmpty()) {
        return;
    }

    // ==============================================
    // CHECK 1: ASSET SERIAL NUMBER
    // ==============================================

    List<Asset_Serial_No__c> existingAssetSerials = [
        SELECT Id, Name
        FROM Asset_Serial_No__c
        WHERE Name IN :serialNumbers
        LIMIT 1
    ];

    if (!existingAssetSerials.isEmpty()) {

        throw new AuraHandledException(
            'Serial Number "' +
            existingAssetSerials[0].Name +
            '" already exists in Asset Serial Number. ' +
            'Please enter a unique Serial Number.'
        );
    }

    // ==============================================
    // CHECK 2: CASE RELATED ASSET SERIAL NUMBER
    // ==============================================

    List<Case_Related_Assets_Serial_No__c>
        existingCaseSerials = [

        SELECT Id,
               Asset_Serial_No__c,
               Asset_Serial_No__r.Name

        FROM Case_Related_Assets_Serial_No__c

        WHERE Asset_Serial_No__r.Name
            IN :serialNumbers

        LIMIT 1
    ];

    if (!existingCaseSerials.isEmpty()) {

        throw new AuraHandledException(
            'Serial Number "' +
            existingCaseSerials[0].Asset_Serial_No__r.Name +
            '" already exists in Case Related Asset ' +
            'Serial Number. Please enter a unique Serial Number.'
        );
    }
}

private static Product2 resolveProduct(
    String selectedProduct
) {

    selectedProduct =
        String.isBlank(selectedProduct)
            ? null
            : selectedProduct.trim();


    if (String.isBlank(selectedProduct)) {

        return null;
    }


    List<Product2> products = [
        SELECT
            Id,
            Name,
            Warranty_Duration__c,
            Warranty_Duration_Unit__c
        FROM Product2
        WHERE Name = :selectedProduct
        LIMIT 2
    ];


    if (products.isEmpty()) {

        throw new AuraHandledException(
            'No matching Product record was found for "' +
            selectedProduct +
            '".'
        );
    }


    if (products.size() > 1) {

        throw new AuraHandledException(
            'Multiple Product records were found for "' +
            selectedProduct +
            '".'
        );
    }


    return products[0];
}
private static Product_Category__c resolveProductCategory(
    Id productId,
    String selectedCategory
) {

    selectedCategory =
        String.isBlank(selectedCategory)
            ? null
            : selectedCategory.trim();


    if (
        productId == null ||
        String.isBlank(selectedCategory)
    ) {

        return null;
    }


    List<Product_Category__c> categories = [
        SELECT
            Id,
            Name,
            Category_Name__c,
            Product__c
        FROM Product_Category__c
        WHERE Category_Name__c =
            :selectedCategory
        AND Product__c =
            :productId
        LIMIT 2
    ];


    if (categories.isEmpty()) {

        throw new AuraHandledException(
            'No matching Product Category record was found for "' +
            selectedCategory +
            '".'
        );
    }


    if (categories.size() > 1) {

        throw new AuraHandledException(
            'Multiple Product Category records were found for "' +
            selectedCategory +
            '".'
        );
    }


    return categories[0];
}

@AuraEnabled(cacheable=true)
public static ProductWarrantyDetails
    getProductWarrantyDetailsByName(
        String productName
    ) {

    Product2 productRec =
        resolveProduct(
            productName
        );


    if (productRec == null) {

        return null;
    }


    ProductWarrantyDetails result =
        new ProductWarrantyDetails();


    result.productId =
        productRec.Id;

    result.productName =
        productRec.Name;

    result.warrantyDuration =
        productRec.Warranty_Duration__c;

    result.warrantyDurationUnit =
        productRec.Warranty_Duration_Unit__c;


    return result;
}


/* =========================================================
   PRODUCT WARRANTY DETAILS
   ========================================================= */

@AuraEnabled(cacheable=true)
public static ProductWarrantyDetails getProductWarrantyDetails(
    Id productId
) {

    if (productId == null) {
        return null;
    }

    List<Product2> products = [
        SELECT Id,
               Name,
               Warranty_Duration__c,
               Warranty_Duration_Unit__c
        FROM Product2
        WHERE Id = :productId
        LIMIT 1
    ];

    if (products.isEmpty()) {
        throw new AuraHandledException(
            'Selected Product was not found.'
        );
    }

    Product2 productRec = products[0];

    ProductWarrantyDetails result =
        new ProductWarrantyDetails();

    result.productId =
        productRec.Id;

    result.productName =
        productRec.Name;

    result.warrantyDuration =
        productRec.Warranty_Duration__c;

    result.warrantyDurationUnit =
        productRec.Warranty_Duration_Unit__c;

    return result;
}


/* =========================================================
   CREATE ASSET BUNDLE
   ========================================================= */

@AuraEnabled
public static String createAssetBundle(
    Id caseId,
    String requestJson
) {

    if (caseId == null) {
        throw new AuraHandledException(
            'Case Id is required.'
        );
    }

    if (String.isBlank(requestJson)) {
        throw new AuraHandledException(
            'Asset details are required.'
        );
    }

    AssetRequest request;

    try {

        request =
            (AssetRequest)JSON.deserialize(
                requestJson,
                AssetRequest.class
            );

    } catch (Exception e) {

        throw new AuraHandledException(
            'Unable to process Asset details: ' +
            e.getMessage()
        );
    }

    validateRequest(request);

// NEW: Validate Serial Numbers against both objects
validateExistingSerialNumbers(request);

Savepoint sp =
    Database.setSavepoint();

    try {

        /* =====================================================
           CASE
           ===================================================== */

        Case caseRec = [
            SELECT Id,
                   AccountId,
                   ContactId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
            FOR UPDATE
        ];

        if (caseRec.AccountId == null) {

            throw new AuraHandledException(
                'Please tag a Customer Account on the Case before creating the Asset.'
            );
        }


        /* =====================================================
           ORDER PRODUCT
           ===================================================== */

        OrderItem orderProduct;

        if (request.orderProductId != null) {

            List<OrderItem> orderProducts = [
                SELECT Id,
                       OrderId,
                       Product2Id
                FROM OrderItem
                WHERE Id = :request.orderProductId
                LIMIT 1
            ];

            if (!orderProducts.isEmpty()) {
                orderProduct =
                    orderProducts[0];
            }
        }


        /* =====================================================
           PRODUCT
           ===================================================== */

        /* =====================================================
   PRODUCT
   ===================================================== */

Product2 productRec =
    resolveProduct(
        request.productName
    );


Id productId =
    productRec == null
        ? null
        : productRec.Id;


/*
 * Resolve Product Category record using:
 *
 * Product +
 * Category Name
 */
Product_Category__c
    productCategoryRec =
        resolveProductCategory(
            productId,
            request.productCategory
        );


Id productCategoryId =
    productCategoryRec == null
        ? null
        : productCategoryRec.Id;


        /* =====================================================
           WARRANTY CALCULATION
           ===================================================== */

        Date warrantyStartDate =
            request.invoiceDate;

        Date warrantyEndDate;

        String warrantyStatus =
            'Validation Required';

        if (
            productRec != null &&
            warrantyStartDate != null &&
            productRec.Warranty_Duration__c != null &&
            String.isNotBlank(
                productRec.Warranty_Duration_Unit__c
            )
        ) {

            warrantyEndDate =
                calculateWarrantyEndDate(
                    warrantyStartDate,
                    productRec.Warranty_Duration__c,
                    productRec.Warranty_Duration_Unit__c
                );

            if (warrantyEndDate != null) {

                warrantyStatus =
                    Date.today() <= warrantyEndDate
                        ? 'Active'
                        : 'Expired';
            }
        }


        /* =====================================================
           1. CREATE ASSET
           ===================================================== */

        Asset assetRec =
            new Asset();

        /*
 * Asset Name is automatically generated because
 * Asset Name is no longer entered from the UI.
 */
String generatedAssetName =
    request.productCategory.trim();


assetRec.Name =
    generatedAssetName.length() > 80
        ? generatedAssetName.substring(
            0,
            80
        )
        : generatedAssetName;


assetRec.Name =
    generatedAssetName.length() > 80
        ? generatedAssetName.substring(
            0,
            80
        )
        : generatedAssetName;

        assetRec.AccountId =
            caseRec.AccountId;

        assetRec.ContactId =
            caseRec.ContactId;

            


        /*
         * Asset has only one standard SerialNumber field.
         * Keep the first Serial Number as the primary Asset
         * serial for existing compatibility.
         */

        if (
    request.serials != null &&
    !request.serials.isEmpty() &&
    String.isNotBlank(
        request.serials[0].serialNumber
    )
) {

    assetRec.SerialNumber =
        request.serials[0]
            .serialNumber
            .trim();
}

        /*
 * =====================================================
 * PRODUCT / PRODUCT CATEGORY
 * =====================================================
 */

assetRec.Product_2__c =
    request.productName;


assetRec.Product_Categoriess__c =
    request.productCategory;


if (productId != null) {

    /*
     * Product lookup fields
     */
    assetRec.Product2Id =
        productId;

    assetRec.Product__c =
        productId;
}


if (productCategoryId != null) {

    /*
     * Product Category lookup
     */
    assetRec.Product_Category_3__c =
        productCategoryId;
}


        if (orderProduct != null) {

            assetRec.Related_Order__c =
                orderProduct.OrderId;

            assetRec.Related_Sales_Order_Item__c =
                orderProduct.Id;
        }


        assetRec.PurchaseDate =
            request.purchaseDate;

        assetRec.InstallDate =
            request.installDate;

        assetRec.Invoice_Number__c =
            request.invoiceNumber;

        assetRec.Invoice_No__c =
            request.invoiceNumber;

        assetRec.Invoice_Date__c =
            request.invoiceDate;

        assetRec.Batch_Number__c =
            request.batchNumber;

        assetRec.Quantity =
            request.quantity;

        assetRec.Site_Name__c =
            request.siteName;

        assetRec.Address__c =
            request.address;

        assetRec.City__c =
            request.city;

        assetRec.State__c =
            request.state;

        assetRec.Country__c =
            request.country;

        assetRec.Pin_Code__c =
            request.pinCode;

        assetRec.Dealer_Name__c =
            request.dealerName;

        assetRec.Dealer_Phone_No__c =
            request.dealerPhone;

        assetRec.Dealer_Address__c =
            request.dealerAddress;

        assetRec.Description =
            request.description;


        /*
         * Existing Asset warranty fields.
         *
         * We are NOT changing their existing functionality.
         */

        assetRec.Product_Warranty_Duration__c =
            request.productWarrantyDuration;

        assetRec.Performance_Warranty_Duration__c =
            request.performanceWarrantyDuration;

        assetRec.Product_Warranty_End_Date__c =
            request.assetProductWarrantyEndDate;

        assetRec.Performance_Warranty_End_Date__c =
            request.assetPerformanceWarrantyEndDate;


        try {

            insert assetRec;

        } catch (DmlException e) {

            throw buildDmlException(
                'Unable to create Asset.',
                e
            );
        }

try {

    update caseRec;

} catch (DmlException e) {

    throw buildDmlException(
        'Unable to update Case Asset Component flag.',
        e
    );
}


        /* =====================================================
           2. CREATE CASE RELATED ASSET
           ===================================================== */

        Case_Related_Assets__c caseAsset =
            new Case_Related_Assets__c();

        caseAsset.Case__c =
            caseId;

        caseAsset.Asset__c =
            assetRec.Id;

        caseAsset.Complaint_Registration_Form_Component__c =
            true;


        if (orderProduct != null) {

            caseAsset.Order_Product__c =
                orderProduct.Id;
        }


        /*
         * NEW WARRANTY LOGIC
         *
         * Product is a real Lookup field.
         */

        /*
 * =====================================================
 * PRODUCT / PRODUCT CATEGORY
 * =====================================================
 */

/*
 * Picklist values
 */
caseAsset.Products__c =
    request.productName;


caseAsset.Product_Category_s__c =
    request.productCategory;


/*
 * Product Lookup
 */
if (productId != null) {

    caseAsset.Product__c =
        productId;
}


/*
 * Product Category Lookup
 */
if (productCategoryId != null) {

    caseAsset.Product_Category__c =
        productCategoryId;
}


        /*
         * Invoice Date is a NORMAL Date field.
         *
         * Copy it from Asset.Invoice_Date__c.
         */

        caseAsset.Invoice_Date__c =
            assetRec.Invoice_Date__c;


        /*
         * End Date and Warranty Status are NORMAL fields.
         *
         * Duration / Unit / Start Date / Warranty End Date
         * Formula fields are NOT written here.
         */

        caseAsset.End_Date__c =
            warrantyEndDate;

        caseAsset.Warranty_Status__c =
            warrantyStatus;


        try {

            insert caseAsset;

        } catch (DmlException e) {

            throw buildDmlException(
                'Unable to create Case Related Asset.',
                e
            );
        }


        /* =====================================================
           3. CREATE MULTIPLE ASSET SERIAL NUMBERS
           ===================================================== */

        List<Asset_Serial_No__c>
            serialRecords =
            new List<Asset_Serial_No__c>();


        for (
            SerialRequest serialRequest :
            request.serials
        ) {

            Asset_Serial_No__c serialRec =
                new Asset_Serial_No__c();

            serialRec.Name =
                serialRequest
                    .serialNumber
                    .trim();

            serialRec.Asset__c =
                assetRec.Id;


            /*
             * Existing automatic warranty Flow is skipped
             * for serials created from this component.
             */

            serialRec.Skip_Automatic_Warranty_Creation__c =
                true;


            serialRec.Product_Warranty_End_Date__c =
                serialRequest.productWarrantyEndDate != null
                ? serialRequest.productWarrantyEndDate
                : request.assetProductWarrantyEndDate;


            serialRec.Performance_Warranty_End_Date__c =
                serialRequest.performanceWarrantyEndDate != null
                ? serialRequest.performanceWarrantyEndDate
                : request.assetPerformanceWarrantyEndDate;


            serialRecords.add(
                serialRec
            );
        }


        try {

            insert serialRecords;

        } catch (DmlException e) {

            throw buildDmlException(
                'Unable to create Asset Serial No. records.',
                e
            );
        }


        /* =====================================================
           4. CREATE CASE RELATED SERIAL RECORDS
           ===================================================== */

        List<Case_Related_Assets_Serial_No__c>
            caseSerialRecords =
            new List<Case_Related_Assets_Serial_No__c>();


        for (
            Integer i = 0;
            i < serialRecords.size();
            i++
        ) {

            Case_Related_Assets_Serial_No__c
                caseSerial =
                new Case_Related_Assets_Serial_No__c();


            caseSerial.Asset__c =
                assetRec.Id;

            caseSerial.Asset_Serial_No__c =
                serialRecords[i].Id;

            caseSerial.Case_Related_Assets__c =
                caseAsset.Id;


            caseSerialRecords.add(
                caseSerial
            );
        }


        try {

            insert caseSerialRecords;

        } catch (DmlException e) {

            throw buildDmlException(
                'Unable to create Case Related Asset Serial No. records.',
                e
            );
        }


        /* =====================================================
           5. CREATE EXISTING ASSET WARRANTY RECORDS
           ===================================================== */

        List<AssetWarranty>
            warrantyRecords =
            new List<AssetWarranty>();


        List<Integer>
            warrantySerialIndexes =
            new List<Integer>();


        for (
            Integer serialIndex = 0;
            serialIndex < request.serials.size();
            serialIndex++
        ) {

            SerialRequest serialRequest =
                request.serials[
                    serialIndex
                ];


            if (
                serialRequest.warranties == null ||
                serialRequest.warranties.isEmpty()
            ) {
                continue;
            }


            for (
                WarrantyRequest warrantyRequest :
                serialRequest.warranties
            ) {

                AssetWarranty warrantyRec =
                    new AssetWarranty();


                warrantyRec.AssetId =
                    assetRec.Id;

                warrantyRec.Account__c =
                    caseRec.AccountId;

                warrantyRec.Asset_Serial_No__c =
                    serialRecords[
                        serialIndex
                    ].Id;

                warrantyRec.Serial_No__c =
                    serialRequest
                        .serialNumber
                        .trim();


                warrantyRec.StartDate =
                    warrantyRequest.startDate;

                warrantyRec.EndDate =
                    warrantyRequest.endDate;


                if (
                    String.isNotBlank(
                        warrantyRequest.approvalStatus
                    )
                ) {

                    warrantyRec.Approval_Status__c =
                        warrantyRequest.approvalStatus;
                }


                if (
                    String.isNotBlank(
                        warrantyRequest.warrantyType
                    )
                ) {

                    warrantyRec.WarrantyType =
                        warrantyRequest.warrantyType;
                }


                if (
                    String.isNotBlank(
                        warrantyRequest.customWarrantyType
                    )
                ) {

                    warrantyRec.Type__c =
                        warrantyRequest.customWarrantyType;
                }


                warrantyRec.IsTransferable =
                    warrantyRequest.transferable == true;


                warrantyRec.LaborCovered =
                    warrantyRequest.laborCovered;

                warrantyRec.PartsCovered =
                    warrantyRequest.partsCovered;

                warrantyRec.ExpensesCovered =
                    warrantyRequest.expensesCovered;


                warrantyRec.LaborCoveredEndDate =
                    warrantyRequest.laborCoveredEndDate;

                warrantyRec.PartsCoveredEndDate =
                    warrantyRequest.partsCoveredEndDate;

                warrantyRec.ExpensesCoveredEndDate =
                    warrantyRequest.expensesCoveredEndDate;


                warrantyRec.Exclusions =
                    warrantyRequest.exclusions;


                warrantyRecords.add(
                    warrantyRec
                );


                warrantySerialIndexes.add(
                    serialIndex
                );
            }
        }


        if (!warrantyRecords.isEmpty()) {

            try {

                insert warrantyRecords;

            } catch (DmlException e) {

                throw buildDmlException(
                    'Unable to create Asset Warranty records.',
                    e
                );
            }
        }


        /* =====================================================
           6. CREATE CASE RELATED ASSET WARRANTY
           ===================================================== */

        List<Case_Related_Asset_Warranty__c>
            caseWarrantyRecords =
            new List<Case_Related_Asset_Warranty__c>();


        /*
         * Create one Case Related Asset Warranty record
         * for each existing AssetWarranty record.
         *
         * Existing AssetWarranty is NOT removed.
         */

        for (
            Integer warrantyIndex = 0;
            warrantyIndex < warrantyRecords.size();
            warrantyIndex++
        ) {

            Integer serialIndex =
                warrantySerialIndexes[
                    warrantyIndex
                ];


            Case_Related_Asset_Warranty__c
                caseWarranty =
                new Case_Related_Asset_Warranty__c();


            caseWarranty.Case__c =
                caseId;

            caseWarranty.Asset__c =
                assetRec.Id;

            caseWarranty.Asset_Warranty__c =
                warrantyRecords[
                    warrantyIndex
                ].Id;

            caseWarranty.Case_Related_Assets__c =
                caseAsset.Id;

            caseWarranty.Case_Related_Assets_Serial_No__c =
                caseSerialRecords[
                    serialIndex
                ].Id;


            /*
             * NEW
             *
             * Product is a Lookup field on
             * Case Related Asset Warranty.
             */

            if (productId != null) {

                caseWarranty.Product__c =
                    productId;
            }


            /*
             * IMPORTANT:
             *
             * Do NOT populate:
             *
             * Warranty_Duration__c
             * Warranty_Duration_Unit__c
             * Warranty_Start_Date__c
             * Warranty_End_Date__c
             * Warranty_Status__c
             *
             * These are Formula fields on
             * Case Related Asset Warranty.
             */


            caseWarrantyRecords.add(
                caseWarranty
            );
        }


        if (!caseWarrantyRecords.isEmpty()) {

            try {

                insert caseWarrantyRecords;

            } catch (DmlException e) {

                throw buildDmlException(
                    'Unable to create Case Related Asset Warranty records.',
                    e
                );
            }
        }


        /* =====================================================
           WARRANTY NUMBERS
           ===================================================== */

        List<String> warrantyNumbers =
            new List<String>();


        if (!warrantyRecords.isEmpty()) {

            Set<Id> warrantyIds =
                new Map<Id, AssetWarranty>(
                    warrantyRecords
                ).keySet();


            for (
                AssetWarranty warranty :
                [
                    SELECT Id,
                           AssetWarrantyNumber
                    FROM AssetWarranty
                    WHERE Id IN :warrantyIds
                    ORDER BY CreatedDate
                ]
            ) {

                if (
                    String.isNotBlank(
                        warranty.AssetWarrantyNumber
                    )
                ) {

                    warrantyNumbers.add(
                        warranty.AssetWarrantyNumber
                    );
                }
            }
        }


        /* =====================================================
           RESULT
           ===================================================== */

        CreationResult result =
            new CreationResult();


        result.assetId =
            assetRec.Id;

        result.caseRelatedAssetId =
            caseAsset.Id;

        result.serialCount =
            serialRecords.size();

        result.warrantyCount =
            warrantyRecords.size();

        result.assetName =
            assetRec.Name;


        result.assetWarrantyNumber =
            warrantyNumbers.isEmpty()
            ? null
            : String.join(
                warrantyNumbers,
                ', '
            );


        result.assetSerialIds =
            new List<Id>();


        for (
            Asset_Serial_No__c serialRec :
            serialRecords
        ) {

            result.assetSerialIds.add(
                serialRec.Id
            );
        }


        result.assetWarrantyIds =
            new List<Id>();


        for (
            AssetWarranty warrantyRec :
            warrantyRecords
        ) {

            result.assetWarrantyIds.add(
                warrantyRec.Id
            );
        }


        result.message =
            'Asset created successfully with ' +
            serialRecords.size() +
            ' Serial Number(s) and ' +
            warrantyRecords.size() +
            ' Warranty record(s).';


        return JSON.serialize(
            result
        );


    } catch (Exception e) {

        Database.rollback(sp);


        if (
            e instanceof AuraHandledException
        ) {

            throw (AuraHandledException)e;
        }


        throw new AuraHandledException(
            'Unable to create Asset records: ' +
            e.getMessage()
        );
    }
}


/* =========================================================
   WARRANTY END DATE
   ========================================================= */

private static Date calculateWarrantyEndDate(
    Date startDate,
    Decimal duration,
    String durationUnit
) {

    if (
        startDate == null ||
        duration == null ||
        String.isBlank(durationUnit)
    ) {
        return null;
    }


    Integer durationValue =
        Integer.valueOf(
            String.valueOf(
                duration.setScale(0)
            )
        );


    String unit =
        durationUnit
            .trim()
            .toLowerCase();


    Date endDate;


    if (
        unit == 'year' ||
        unit == 'years' ||
        unit == 'yr' ||
        unit == 'yrs'
    ) {

        endDate =
            startDate.addYears(
                durationValue
            );

    } else if (
        unit == 'month' ||
        unit == 'months' ||
        unit == 'mon' ||
        unit == 'mons'
    ) {

        endDate =
            startDate.addMonths(
                durationValue
            );

    } else if (
        unit == 'day' ||
        unit == 'days'
    ) {

        endDate =
            startDate.addDays(
                durationValue
            );

    } else {

        return null;
    }


    /*
     * Warranty duration is inclusive.
     *
     * Example:
     *
     * 15/07/2026
     * + 5 Years
     * = 15/07/2031
     *
     * Actual End Date:
     * 14/07/2031
     */

    return endDate.addDays(-1);
}


/* =========================================================
   VALIDATION
   ========================================================= */

private static void validateRequest(
    AssetRequest request
) {

    if (request == null) {

        throw new AuraHandledException(
            'Asset details are required.'
        );
    }


    if (
    String.isBlank(
        request.productName
    )
) {

    throw new AuraHandledException(
        'Product is required.'
    );
}


if (
    String.isBlank(
        request.productCategory
    )
) {

    throw new AuraHandledException(
        'Product Category is required.'
    );
}


    if (request.serials == null) {

    request.serials =
        new List<SerialRequest>();
}


    Set<String> serialNumbers =
        new Set<String>();


    Integer serialPosition = 0;


    for (
        SerialRequest serialRequest :
        request.serials
    ) {

        serialPosition++;


        if (
            serialRequest == null ||
            String.isBlank(
                serialRequest.serialNumber
            )
        ) {

            throw new AuraHandledException(
                'Serial Number is required for Serial #' +
                serialPosition +
                '.'
            );
        }


        String serialKey =
            serialRequest
                .serialNumber
                .trim()
                .toLowerCase();


        if (
            serialNumbers.contains(
                serialKey
            )
        ) {

            throw new AuraHandledException(
                'Duplicate Serial Number is not allowed: ' +
                serialRequest.serialNumber
            );
        }


        serialNumbers.add(
            serialKey
        );


        if (
            serialRequest.warranties == null
        ) {
            continue;
        }


        Integer warrantyPosition = 0;


        for (
            WarrantyRequest warranty :
            serialRequest.warranties
        ) {

            warrantyPosition++;


            if (
                warranty.startDate == null
            ) {

                throw new AuraHandledException(
                    'Warranty Start Date is required for Warranty #' +
                    warrantyPosition +
                    ' under Serial Number ' +
                    serialRequest.serialNumber +
                    '.'
                );
            }


            if (
                warranty.endDate == null
            ) {

                throw new AuraHandledException(
                    'Warranty End Date is required for Warranty #' +
                    warrantyPosition +
                    ' under Serial Number ' +
                    serialRequest.serialNumber +
                    '.'
                );
            }


            if (
                warranty.endDate <
                warranty.startDate
            ) {

                throw new AuraHandledException(
                    'Warranty End Date cannot be earlier than Warranty Start Date for Serial Number ' +
                    serialRequest.serialNumber +
                    '.'
                );
            }
        }
    }
}


/* =========================================================
   DML ERROR
   ========================================================= */

private static AuraHandledException buildDmlException(
    String prefix,
    DmlException e
) {

    Set<String> fieldSet =
        new Set<String>();


    for (
        Integer i = 0;
        i < e.getNumDml();
        i++
    ) {

        List<String> fieldNames =
            e.getDmlFieldNames(i);


        if (fieldNames != null) {

            fieldSet.addAll(
                fieldNames
            );
        }
    }


    String message =
        prefix;


    if (!fieldSet.isEmpty()) {

        List<String> fields =
            new List<String>(
                fieldSet
            );


        fields.sort();


        message +=
            ' Fields: ' +
            String.join(
                fields,
                ', '
            ) +
            '.';
    }


    if (e.getNumDml() > 0) {

        message +=
            ' Error: ' +
            e.getDmlMessage(0);

    } else {

        message +=
            ' Error: ' +
            e.getMessage();
    }


    return new AuraHandledException(
        message
    );
}


/* =========================================================
   PRODUCT WARRANTY RESPONSE
   ========================================================= */

public class ProductWarrantyDetails {

    @AuraEnabled
    public Id productId;

    @AuraEnabled
    public String productName;

    @AuraEnabled
    public Decimal warrantyDuration;

    @AuraEnabled
    public String warrantyDurationUnit;
}


/* =========================================================
   REQUEST CLASSES
   ========================================================= */

private class AssetRequest {

    public String productName;

    public String productCategory;

    public Id productId;
    public Id orderProductId;

    public Date purchaseDate;
    public Date installDate;

    public String invoiceNumber;
    public Date invoiceDate;

    public String batchNumber;
    public Decimal quantity;

    public String siteName;

    public String address;
    public String city;
    public String state;
    public String country;
    public String pinCode;

    public String dealerName;
    public String dealerPhone;
    public String dealerAddress;

    public String description;

    public Decimal productWarrantyDuration;
    public Decimal performanceWarrantyDuration;

    public Date assetProductWarrantyEndDate;
    public Date assetPerformanceWarrantyEndDate;

    public List<SerialRequest> serials;
}


private class SerialRequest {

    public String serialNumber;

    public Date productWarrantyEndDate;
    public Date performanceWarrantyEndDate;

    public List<WarrantyRequest> warranties;
}


private class WarrantyRequest {

    public Date startDate;
    public Date endDate;

    public String approvalStatus;
    public String warrantyType;
    public String customWarrantyType;

    public Boolean transferable;

    public Decimal laborCovered;
    public Decimal partsCovered;
    public Decimal expensesCovered;

    public Date laborCoveredEndDate;
    public Date partsCoveredEndDate;
    public Date expensesCoveredEndDate;

    public String exclusions;
}


/* =========================================================
   RESULT
   ========================================================= */

private class CreationResult {

    public Id assetId;
    public Id caseRelatedAssetId;

    public Integer serialCount;
    public Integer warrantyCount;

    public List<Id> assetSerialIds;
    public List<Id> assetWarrantyIds;

    public String assetName;
    public String assetWarrantyNumber;

    public String message;
}
}
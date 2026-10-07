public with sharing class SRT_L2MessageService {

    /*
     * Called only after CaseL2AssignmentController successfully
     * assigns the selected Dealer Supplier Master to the Case.
     * Returns one result per recipient; an invalid number does
     * not prevent the other recipient from being queued.
     */
    public static Map<String, String> queueL2Messages(
        Id caseId,
        Id dealerId
    ) {
        Map<String, String> results = new Map<String, String>{
            'customer' => 'Not attempted',
            'dealer' => 'Not attempted'
        };

        if (caseId == null || dealerId == null) {
            results.put('customer', 'Not queued: Case or dealer is missing.');
            results.put('dealer', 'Not queued: Case or dealer is missing.');
            return results;
        }

        Case c = [
            SELECT Id, CaseNumber, SRT_Case_No__c,
                   SRT_Case_Number__c, L2_Assigned__c,
                   Product__c, Product_Categories__c,
                   Product_Category__c, AssetId,
                   AccountId, Account.Name,
                   Account.Building_Street__c,
                   Account.District__c,
                   Account.BillingPostalCode,
                   ContactId, Contact.Name, Contact.Phone
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        // Never send an L2 notification for an unrelated dealer.
        if (c.L2_Assigned__c != dealerId) {
            results.put('customer', 'Not queued: L2 dealer does not match the Case.');
            results.put('dealer', 'Not queued: L2 dealer does not match the Case.');
            return results;
        }

        // L2 is a Dealer Supplier Master record, NOT a Salesforce User.
        Dealer_Supplier_Master__c dealer = [
            SELECT Id, Mobile_Number__c
            FROM Dealer_Supplier_Master__c
            WHERE Id = :dealerId
            LIMIT 1
        ];

        String srNo = String.isNotBlank(c.SRT_Case_No__c)
            ? c.SRT_Case_No__c.trim()
            : (String.isNotBlank(c.SRT_Case_Number__c)
                ? c.SRT_Case_Number__c.trim()
                : c.CaseNumber);

        if (!srNo.toUpperCase().startsWith('SR-')) {
            srNo = 'SR-' + srNo;
        }

        /* -------------------------------------------------------
           POINT 2: CUSTOMER -> Case.Contact.Phone
           Campaign Customer_process has exactly ONE parameter: SR.
           ------------------------------------------------------- */

        results.put(
            'customer',
            queueOne(
                c.Id,
                c.Contact == null ? null : c.Contact.Phone,
                'Case.Contact.Phone',
                'Customer_process',
                'L2 Customer FSE Visit',
                new List<String>{ srNo }
            )
        );

        /* -------------------------------------------------------
           POINT 4: DEALER -> Dealer_Supplier_Master__c.Mobile_Number__c
           Campaign servicerequest has SEVEN ordered parameters.
           ------------------------------------------------------- */

        Id assetId = c.AssetId;
        if (assetId == null) {
            List<Case_Related_Assets__c> related = [
                SELECT Asset__c
                FROM Case_Related_Assets__c
                WHERE Case__c = :caseId
                  AND Asset__c != null
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!related.isEmpty()) {
                assetId = related[0].Asset__c;
            }
        }

        Asset assetRec;
        if (assetId != null) {
            List<Asset> assets = [
                SELECT Id, Product2.Name, Warranty_Status__c
                FROM Asset
                WHERE Id = :assetId
                LIMIT 1
            ];
            if (!assets.isEmpty()) {
                assetRec = assets[0];
            }
        }

        String product = c.Product__c;
        if (String.isBlank(product) && assetRec != null &&
            assetRec.Product2 != null) {
            product = assetRec.Product2.Name;
        }
        product = fallback(product);

        String category = String.isNotBlank(c.Product_Categories__c)
            ? c.Product_Categories__c
            : c.Product_Category__c;
        category = fallback(category);

        String customerName = c.Contact == null ? null : c.Contact.Name;
        if (String.isBlank(customerName) && c.Account != null) {
            customerName = c.Account.Name;
        }
        customerName = fallback(customerName);

        // Contact number in template also comes specifically from Contact.Phone.
        String customerMobile = fallback(
            normalizePhone(c.Contact == null ? null : c.Contact.Phone)
        );

        List<String> locationParts = new List<String>();
        if (c.Account != null) {
            if (String.isNotBlank(c.Account.Building_Street__c)) {
                locationParts.add(c.Account.Building_Street__c.trim());
            }
            if (String.isNotBlank(c.Account.District__c)) {
                locationParts.add(c.Account.District__c.trim());
            }
            if (String.isNotBlank(c.Account.BillingPostalCode)) {
                locationParts.add(c.Account.BillingPostalCode.trim());
            }
        }
        String location = locationParts.isEmpty()
            ? 'N/A'
            : String.join(locationParts, ', ');

        String warranty = 'Validation Pending';
        if (assetRec != null &&
            String.isNotBlank(assetRec.Warranty_Status__c)) {

            String warrantyStatus =
                assetRec.Warranty_Status__c.trim().toLowerCase();

            if (new Set<String>{
                'yes', 'active', 'valid', 'in warranty', 'under warranty'
            }.contains(warrantyStatus)) {
                warranty = 'Yes';
            } else if (new Set<String>{
                'no', 'expired', 'inactive', 'out of warranty'
            }.contains(warrantyStatus)) {
                warranty = 'No';
            }
        }

        List<String> dealerParams = new List<String>{
            srNo, product, category, customerName,
            customerMobile, location, warranty
        };

        results.put(
            'dealer',
            queueOne(
                c.Id,
                dealer.Mobile_Number__c,
                'Dealer_Supplier_Master__c.Mobile_Number__c',
                'servicerequest',
                'L2 Dealer Assignment',
                dealerParams
            )
        );

        return results;
    }

    /*
     * Create a separate log for each attempt. If the phone is invalid,
     * log the failure but never issue the external API request.
     * No message is sent if its log cannot be created.
     */
    private static String queueOne(
        Id caseId,
        String rawPhone,
        String phoneSource,
        String campaignName,
        String messageType,
        List<String> params
    ) {
        String destination = normalizePhone(rawPhone);
        Boolean invalidPhone = destination == null;

        Whatsapp_Messages__c logRec = new Whatsapp_Messages__c();
        logRec.Case__c = caseId;
        logRec.Campaign_Name__c = campaignName;
        logRec.Recipient_Number__c =
            invalidPhone ? rawPhone : destination;
        logRec.Status__c = invalidPhone ? 'Failed' : 'Pending';
        logRec.Requested_At__c = System.now();
        logRec.Message__c = JSON.serialize(new Map<String, Object>{
            'messageType' => messageType,
            'campaignName' => campaignName,
            'templateParams' => params
        });

        if (invalidPhone) {
            logRec.Failure_Reason__c =
                phoneSource + ' is blank or is not a valid 10-digit Indian mobile number.';
        }

        try {
            insert logRec;
        } catch (Exception insertError) {
            System.debug(
                LoggingLevel.ERROR,
                'L2 WhatsApp log insertion failed. Campaign: ' +
                campaignName + ', Error: ' + insertError.getMessage()
            );
            return 'Not queued: unable to create the WhatsApp log.';
        }

        if (invalidPhone) {
            return 'Not queued: invalid recipient number. Log: ' + logRec.Id;
        }

        try {
            Id jobId = System.enqueueJob(
                new SRT_L2MessageQueueable(
                    caseId, destination, campaignName, params, logRec.Id
                )
            );
            return 'Queued. Job: ' + jobId + ', Log: ' + logRec.Id;

        } catch (Exception enqueueError) {
            try {
                update new Whatsapp_Messages__c(
                    Id = logRec.Id,
                    Status__c = 'Failed',
                    Failure_Reason__c =
                        truncate('Unable to queue: ' + enqueueError.getMessage())
                );
            } catch (Exception updateError) {
                System.debug(
                    LoggingLevel.ERROR,
                    'L2 WhatsApp failure-log update failed. Log: ' +
                    logRec.Id + ', Error: ' + updateError.getMessage()
                );
            }
            System.debug(
                LoggingLevel.ERROR,
                'L2 WhatsApp Queueable could not be queued. Campaign: ' +
                campaignName + ', Error: ' + enqueueError.getMessage()
            );
            return 'Not queued: Queueable error. Log: ' + logRec.Id;
        }
    }

    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return null;
        String digits = phone.replaceAll('[^0-9]', '');
        if (digits.length() == 14 && digits.startsWith('0091')) {
            digits = digits.substring(4);
        }
        if (digits.length() == 12 && digits.startsWith('91')) {
            digits = digits.substring(2);
        }
        return Pattern.matches('[6-9][0-9]{9}', digits) ? digits : null;
    }

    private static String fallback(String value) {
        return String.isBlank(value) ? 'N/A' : value.trim();
    }

    private static String truncate(String value) {
        if (value == null) return null;
        return value.length() > 32768 ? value.substring(0, 32768) : value;
    }
}
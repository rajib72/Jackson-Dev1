public with sharing class API_ctrl_SAPCustomerMasterController {

    private static final String API_NAME = 'SAP Customer Master API';
    private static final String SOURCE_SYSTEM = 'SAP';
    private static final String HTTP_METHOD = 'POST';
    private static final String ENDPOINT = 'callout:NC_SAP_API/http/rfcCustMast';
    private static final Set<String> ALLOWED_SALES_ORGANIZATIONS = new Set<String>{'2000', '2002'};
    private static Map<String, Map<String, String>> picklistValueCache = new Map<String, Map<String, String>>();

    public class CustomerMasterRequest {
        @AuraEnabled public Date fromDate;
        @AuraEnabled public Date toDate;
    }

    public class CustomerMasterResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer totalReceived;
        @AuraEnabled public Integer insertedCount;
        @AuraEnabled public Integer updatedCount;
        @AuraEnabled public Integer failedCount;
        @AuraEnabled public Integer skippedCount;
        @AuraEnabled public List<RowResult> results = new List<RowResult>();
    }

    public class RowResult {
        @AuraEnabled public String customerCode;
        @AuraEnabled public String customerName;
        @AuraEnabled public String action;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public Id accountId;
    }

    public class SAPCustomerDTO {
        public String CUSTOMER_NAME;
        public String CUSTOMER_CODE;
        public String SALESFORCE_CUSTOMER_CODE;
        public String CREATION_DATE;
        public String GSTIN;
        public String PAN;
        public String STREET1;
        public String STREET2;
        public String STREET3;
        public String CITY;
        public String REGION;
        public String PINCODE;
        public String COUNTRY;
        public String NAME;
        public String EMAIL_ID;
        public String PHONENUMBER;
        public String PAYMENTTERMS;
        public String DESCRIPTION;
        public String SALESORGANIZATION;
        public String DISTRIBUTIONCHANNEL;
        public String DIVISION;
    }

    @AuraEnabled
    public static CustomerMasterResponse fetchAndSyncCustomerMaster(Date fromDate, Date toDate) {
        CustomerMasterResponse responseWrapper = new CustomerMasterResponse();
        responseWrapper.success = false;
        responseWrapper.totalReceived = 0;
        responseWrapper.insertedCount = 0;
        responseWrapper.updatedCount = 0;
        responseWrapper.failedCount = 0;
        responseWrapper.skippedCount = 0;

        if (fromDate == null || toDate == null) {
            responseWrapper.message = 'From Date and To Date are required.';
            return responseWrapper;
        }

        if (fromDate > toDate) {
            responseWrapper.message = 'From Date cannot be greater than To Date.';
            return responseWrapper;
        }

        String requestBody = '';
        HttpResponse res;

        try {
            String fromFormattedDate = formatDateYYYYMMDD(fromDate);
            String toFormattedDate = formatDateYYYYMMDD(toDate);

            Map<String, Object> requestMap = new Map<String, Object>();
            requestMap.put('CREATION_FROM_DATE', fromFormattedDate);
            requestMap.put('CREATION_TO_DATE', toFormattedDate);

            requestBody = JSON.serialize(requestMap);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod(HTTP_METHOD);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBody);

            Http http = new Http();
            res = http.send(req);

            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                logIntegrationError(API_NAME, String.valueOf(res.getStatusCode()), 'Non-success response received from SAP API', HTTP_METHOD, requestBody, ENDPOINT, SOURCE_SYSTEM, null, String.valueOf(res.getStatusCode()));
                responseWrapper.message = 'API call failed. Status Code: ' + res.getStatusCode();
                return responseWrapper;
            }

            List<SAPCustomerDTO> sapCustomers = (List<SAPCustomerDTO>) JSON.deserialize(res.getBody(), List<SAPCustomerDTO>.class);
            responseWrapper.totalReceived = sapCustomers != null ? sapCustomers.size() : 0;

            if (sapCustomers == null || sapCustomers.isEmpty()) {
                responseWrapper.success = true;
                responseWrapper.message = 'No records found from SAP for selected date range.';
                return responseWrapper;
            }

            // STEP 1: Collect Customer Codes only for Sales Org 2000 and 2002
            Set<String> allSapCodes = new Set<String>();

            for (SAPCustomerDTO dto : sapCustomers) {
                if (dto != null && isAllowedSalesOrganization(dto.SALESORGANIZATION) && !String.isBlank(dto.CUSTOMER_CODE)) {
                    allSapCodes.add(dto.CUSTOMER_CODE.trim());
                }
            }

            // STEP 2: Query existing Accounts
            Map<String, Account> existingAccountsByCompositeKey = new Map<String, Account>();

            if (!allSapCodes.isEmpty()) {
                for (Account acc : [
                    SELECT Id, Name, SAP_Account_Number__c, Creation_Date__c, Billing_GST_No__c, PAN__c,
                           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                           Street_Address__c, City__c, Region__c, Postal_Code__c, Country__c,
                           Email__c, Phone, Payment_Terms__c, Payment_Description__c,
                           Distribution_Channel__c, Customer_Type__c, Division__c, Sales_Organization_No__c
                    FROM Account
                    WHERE SAP_Account_Number__c IN :allSapCodes
                ]) {
                    existingAccountsByCompositeKey.put(getAccountCompositeKey(acc), acc);
                }
            }

            // STEP 3: Prepare Accounts
            Map<String, Account> accountsToUpsertMap = new Map<String, Account>();
            Map<String, String> statusMapByKey = new Map<String, String>();
            Map<String, String> messageMapByKey = new Map<String, String>();

            for (SAPCustomerDTO dto : sapCustomers) {
                if (dto == null || !isAllowedSalesOrganization(dto.SALESORGANIZATION) || String.isBlank(dto.CUSTOMER_CODE)) {
                    continue;
                }

                String compositeKey;

                try {
                    compositeKey = getDtoCompositeKey(dto);
                } catch (Exception mappingEx) {
                    String errorKey = dto.CUSTOMER_CODE.trim() + '|MAPPING_ERROR';

                    statusMapByKey.put(errorKey, 'Failed');
                    messageMapByKey.put(errorKey, 'Mapping Error: ' + mappingEx.getMessage());

                    logIntegrationError(API_NAME, 'MAPPING_ERROR', mappingEx.getMessage(), HTTP_METHOD, requestBody, ENDPOINT, SOURCE_SYSTEM, mappingEx.getStackTraceString(), String.valueOf(res.getStatusCode()));
                    continue;
                }

                Account acc;

                if (accountsToUpsertMap.containsKey(compositeKey)) {
                    acc = accountsToUpsertMap.get(compositeKey);
                } else if (existingAccountsByCompositeKey.containsKey(compositeKey)) {
                    acc = new Account(Id = existingAccountsByCompositeKey.get(compositeKey).Id);
                } else {
                    acc = new Account();
                }

                try {
                    mapCustomerToAccount(acc, dto);
                    accountsToUpsertMap.put(compositeKey, acc);
                } catch (Exception mappingEx) {
                    statusMapByKey.put(compositeKey, 'Failed');
                    messageMapByKey.put(compositeKey, 'Mapping Error: ' + mappingEx.getMessage());

                    logIntegrationError(API_NAME, 'MAPPING_ERROR', mappingEx.getMessage(), HTTP_METHOD, requestBody, ENDPOINT, SOURCE_SYSTEM, mappingEx.getStackTraceString(), String.valueOf(res.getStatusCode()));
                }
            }

            // STEP 4: Prepare DML list
            List<Account> accountsToUpsert = new List<Account>();
            List<String> orderedKeyList = new List<String>();

            for (String key : accountsToUpsertMap.keySet()) {
                accountsToUpsert.add(accountsToUpsertMap.get(key));
                orderedKeyList.add(key);
            }

            Map<String, Id> accountIdMapByKey = new Map<String, Id>();

            // STEP 5: Perform DML
            if (!accountsToUpsert.isEmpty()) {
                Database.UpsertResult[] saveResults = Database.upsert(accountsToUpsert, false);

                for (Integer i = 0; i < saveResults.size(); i++) {
                    Database.UpsertResult sr = saveResults[i];
                    String key = orderedKeyList[i];

                    if (sr.isSuccess()) {
                        statusMapByKey.put(key, 'Success');
                        accountIdMapByKey.put(key, sr.getId());
                        messageMapByKey.put(key, existingAccountsByCompositeKey.containsKey(key) ? 'Updated successfully.' : 'Inserted successfully.');
                    } else {
                        statusMapByKey.put(key, 'Failed');

                        String errMsg = '';
                        for (Database.Error err : sr.getErrors()) {
                            errMsg += err.getStatusCode() + ' - ' + err.getMessage() + ' ';
                        }

                        messageMapByKey.put(key, errMsg);

                        logIntegrationError(API_NAME, 'DML_ERROR', errMsg, HTTP_METHOD, requestBody, ENDPOINT, SOURCE_SYSTEM, null, String.valueOf(res.getStatusCode()));
                    }
                }
            }

            // STEP 6: Build Audit Result
            List<RowResult> rowAudit = new List<RowResult>();
            Integer insertedCount = 0;
            Integer updatedCount = 0;
            Integer failedCount = 0;
            Integer skippedCount = 0;

            Set<String> metricsProcessed = new Set<String>();

            for (SAPCustomerDTO dto : sapCustomers) {
                RowResult rr = new RowResult();
                rr.customerCode = dto != null ? dto.CUSTOMER_CODE : null;
                rr.customerName = dto != null ? dto.CUSTOMER_NAME : null;

                if (dto == null) {
                    rr.action = 'Failed';
                    rr.status = 'Failed';
                    rr.message = 'Empty customer record received from SAP.';
                    rowAudit.add(rr);
                    failedCount++;
                    continue;
                }

                if (!isAllowedSalesOrganization(dto.SALESORGANIZATION)) {
                    rr.action = 'Skip';
                    rr.status = 'Skipped';
                    rr.message = 'Skipped because SALESORGANIZATION must be 2000 or 2002. Received value: ' + dto.SALESORGANIZATION;
                    rowAudit.add(rr);
                    skippedCount++;
                    continue;
                }

                if (String.isBlank(dto.CUSTOMER_CODE)) {
                    rr.action = 'Failed';
                    rr.status = 'Failed';
                    rr.message = 'Blank CUSTOMER_CODE received from SAP.';
                    rowAudit.add(rr);
                    failedCount++;
                    continue;
                }

                String key;

                try {
                    key = getDtoCompositeKey(dto);
                } catch (Exception mappingEx) {
                    rr.action = 'Failed';
                    rr.status = 'Failed';
                    rr.message = 'Mapping Error: ' + mappingEx.getMessage();
                    rowAudit.add(rr);
                    failedCount++;
                    continue;
                }

                if (statusMapByKey.containsKey(key)) {
                    rr.status = statusMapByKey.get(key);
                    rr.message = messageMapByKey.get(key);
                    rr.accountId = accountIdMapByKey.get(key);
                    rr.action = existingAccountsByCompositeKey.containsKey(key) ? 'Update' : 'Insert';

                    if (!metricsProcessed.contains(key)) {
                        if (rr.status == 'Success') {
                            if (rr.action == 'Insert') {
                                insertedCount++;
                            } else if (rr.action == 'Update') {
                                updatedCount++;
                            }
                        } else {
                            failedCount++;
                        }

                        metricsProcessed.add(key);
                    }
                } else {
                    rr.action = 'Failed';
                    rr.status = 'Failed';
                    rr.message = 'Record failed to process due to an unknown error.';

                    if (!metricsProcessed.contains(key)) {
                        failedCount++;
                        metricsProcessed.add(key);
                    }
                }

                rowAudit.add(rr);
            }

            responseWrapper.success = true;
            responseWrapper.message = 'Customer Master sync completed successfully.';
            responseWrapper.insertedCount = insertedCount;
            responseWrapper.updatedCount = updatedCount;
            responseWrapper.failedCount = failedCount;
            responseWrapper.skippedCount = skippedCount;
            responseWrapper.results = rowAudit;

            return responseWrapper;

        } catch (Exception ex) {
            logIntegrationError(API_NAME, 'EXCEPTION', ex.getMessage(), HTTP_METHOD, requestBody, ENDPOINT, SOURCE_SYSTEM, ex.getStackTraceString(), res != null ? String.valueOf(res.getStatusCode()) : null);

            responseWrapper.success = false;
            responseWrapper.message = 'Error while processing Customer Master API: ' + ex.getMessage();

            return responseWrapper;
        }
    }

    private static Boolean isAllowedSalesOrganization(String salesOrganization) {
        return !String.isBlank(salesOrganization) && ALLOWED_SALES_ORGANIZATIONS.contains(salesOrganization.trim());
    }

    private static String getDtoCompositeKey(SAPCustomerDTO dto) {
        /* String combinedStreet = buildStreet(dto.STREET1, dto.STREET2, dto.STREET3);
        String mappedRegion = getPicklistValueByCode(Account.Region__c, dto.REGION, 'Region');
        String mappedCountry = getPicklistValueByCode(Account.Country__c, dto.COUNTRY, 'Country');
        String mappedCustomerType = getCustomerType(dto.DISTRIBUTIONCHANNEL); */

        /* return keyPart(dto.CUSTOMER_CODE) + '|' +
               keyPart(dto.CREATION_DATE) + '|' +
               keyPart(dto.GSTIN) + '|' +
               keyPart(dto.PAN) + '|' +
               keyPart(combinedStreet) + '|' +
               keyPart(dto.CITY) + '|' +
               keyPart(mappedRegion) + '|' +
               keyPart(dto.PINCODE) + '|' +
               keyPart(mappedCountry) + '|' +
               keyPart(dto.EMAIL_ID) + '|' +
               keyPart(dto.PHONENUMBER) + '|' +
               keyPart(dto.PAYMENTTERMS) + '|' +
               keyPart(dto.DESCRIPTION) + '|' +
               keyPart(dto.SALESORGANIZATION) + '|' +
               keyPart(mappedCustomerType) + '|' +
               keyPart(dto.DIVISION); */
        
        return keyPart(dto.CUSTOMER_CODE);
    }

    private static String getAccountCompositeKey(Account acc) {
        /* return keyPart(acc.SAP_Account_Number__c) + '|' +
               keyPart(acc.Creation_Date__c) + '|' +
               keyPart(acc.Billing_GST_No__c) + '|' +
               keyPart(acc.PAN__c) + '|' +
               keyPart(acc.Street_Address__c) + '|' +
               keyPart(acc.City__c) + '|' +
               keyPart(acc.Region__c) + '|' +
               keyPart(acc.Postal_Code__c) + '|' +
               keyPart(acc.Country__c) + '|' +
               keyPart(acc.Email__c) + '|' +
               keyPart(acc.Phone) + '|' +
               keyPart(acc.Payment_Terms__c) + '|' +
               keyPart(acc.Payment_Description__c) + '|' +
               keyPart(acc.Sales_Organization_No__c) + '|' +
               keyPart(acc.Customer_Type__c) + '|' +
               keyPart(acc.Division__c); */
        return keyPart(acc.SAP_Account_Number__c);
    }

    private static void mapCustomerToAccount(Account acc, SAPCustomerDTO dto) {
        String combinedStreet = buildStreet(dto.STREET1, dto.STREET2, dto.STREET3);
        String mappedRegion = getPicklistValueByCode(Account.Region__c, dto.REGION, 'Region');
        String mappedStateName = getRegionStateNameByCode(dto.REGION);
        String mappedCountry = getPicklistValueByCode(Account.Country__c, dto.COUNTRY, 'Country');
        String mappedCountryName = getCountryNameByCode(dto.COUNTRY);
        String mappedCustomerType = getCustomerType(dto.DISTRIBUTIONCHANNEL);
        String mappedCompanyCode = getPicklistValueByCode(
            Account.Company_Code__c,
            dto.SALESORGANIZATION,
            'Company Code'
        );
        
        acc.Company_Code__c = mappedCompanyCode;

        acc.Name = String.isBlank(dto.CUSTOMER_NAME) ? 'SAP Customer - ' + dto.CUSTOMER_CODE : dto.CUSTOMER_NAME.trim();
        acc.SAP_Account_Number__c = trimOrNull(dto.CUSTOMER_CODE);
        acc.Creation_Date__c = trimOrNull(dto.CREATION_DATE);
        acc.Billing_GST_No__c = trimOrNull(dto.GSTIN);
        acc.PAN__c = trimOrNull(dto.PAN);

        // Existing Billing Address Mapping
        acc.BillingStreet = combinedStreet;
        acc.BillingCity = trimOrNull(dto.CITY);
        acc.BillingState = mappedStateName;
        acc.BillingPostalCode = trimOrNull(dto.PINCODE);
        acc.BillingCountry = mappedCountryName;

        // Additional Custom Address Mapping
        acc.Street_Address__c = combinedStreet;
        acc.City__c = trimOrNull(dto.CITY);
        acc.Region__c = mappedRegion;
        acc.Postal_Code__c = trimOrNull(dto.PINCODE);
        acc.Country__c = mappedCountry;

        acc.Email__c = trimOrNull(dto.EMAIL_ID);
        acc.Phone = trimOrNull(dto.PHONENUMBER);
        acc.Payment_Terms__c = trimOrNull(dto.PAYMENTTERMS);
        acc.Payment_Description__c = trimOrNull(dto.DESCRIPTION);
        acc.Sales_Organization_No__c = trimOrNull(dto.SALESORGANIZATION);

        // Existing Distribution Channel Mapping
        acc.Distribution_Channel__c = trimOrNull(dto.DISTRIBUTIONCHANNEL);

        // Additional Customer Type Mapping
        acc.Customer_Type__c = mappedCustomerType;

        acc.Division__c = trimOrNull(dto.DIVISION);
    }

    private static String getCustomerType(String distributionChannel) {
        if (String.isBlank(distributionChannel)) {
            return null;
        }

        if (distributionChannel.trim().equalsIgnoreCase('DO')) {
            return getPicklistValueByCode(Account.Customer_Type__c, 'DO', 'Customer Type');
        }

        return getPicklistValueByCode(Account.Customer_Type__c, 'Others', 'Customer Type');
    }

    private static String getPicklistValueByCode(Schema.SObjectField fieldToken, String incomingCode, String fieldLabel) {
        if (String.isBlank(incomingCode)) {
            return null;
        }

        Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
        String fieldApiName = fieldDescribe.getName();

        if (!picklistValueCache.containsKey(fieldApiName)) {
            Map<String, String> valuesByCode = new Map<String, String>();

            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                if (!entry.isActive() || String.isBlank(entry.getValue())) {
                    continue;
                }

                String picklistValue = entry.getValue().trim();

                valuesByCode.put(picklistValue.toUpperCase(), entry.getValue());

                Integer separatorIndex = picklistValue.indexOf('-');

                if (separatorIndex > 0) {
                    String code = picklistValue.substring(0, separatorIndex).trim().toUpperCase();
                    valuesByCode.put(code, entry.getValue());
                }
            }

            picklistValueCache.put(fieldApiName, valuesByCode);
        }

        String normalizedCode = incomingCode.trim().toUpperCase();
        Map<String, String> valuesByCode = picklistValueCache.get(fieldApiName);

        if (valuesByCode.containsKey(normalizedCode)) {
            return valuesByCode.get(normalizedCode);
        }

        throw new CustomerMappingException(fieldLabel + ' mapping was not found for SAP value "' + incomingCode + '".');
    }

    private static String buildStreet(String street1, String street2, String street3) {
        List<String> parts = new List<String>();

        if (!String.isBlank(street1)) {
            parts.add(street1.trim());
        }

        if (!String.isBlank(street2)) {
            parts.add(street2.trim());
        }

        if (!String.isBlank(street3)) {
            parts.add(street3.trim());
        }

        return parts.isEmpty() ? null : String.join(parts, ' ');
    }

    private static String trimOrNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static String keyPart(Object value) {
        return value == null ? '' : String.valueOf(value).trim();
    }

    private static Date parseDate(String dateStr) {
        if (String.isBlank(dateStr)) {
            return null;
        }

        try {
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static String getRegionStateNameByCode(String incomingRegion) {
        if (String.isBlank(incomingRegion)) {
            return null;
        }
    
        Schema.DescribeFieldResult fieldDescribe = Account.Region__c.getDescribe();
        String normalizedIncoming = incomingRegion.trim().toUpperCase();
    
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (!entry.isActive() || String.isBlank(entry.getValue())) {
                continue;
            }
    
            String picklistValue = entry.getValue().trim();
            String picklistLabel = entry.getLabel();
    
            // Case 1:
            // Value/Label = "08 - Delhi"
            Integer valueSeparatorIndex = picklistValue.indexOf('-');
    
            if (valueSeparatorIndex > 0) {
                String code = picklistValue
                    .substring(0, valueSeparatorIndex)
                    .trim()
                    .toUpperCase();
    
                if (code == normalizedIncoming) {
                    return picklistValue.substring(valueSeparatorIndex + 1).trim();
                }
            }
    
            // Case 2:
            // Value = "08", Label = "Delhi"
            if (picklistValue.toUpperCase() == normalizedIncoming) {
                if (!String.isBlank(picklistLabel)) {
                    return picklistLabel.trim();
                }
    
                return picklistValue;
            }
    
            // Case 3:
            // Label itself contains the code, e.g. "08 - Delhi"
            if (!String.isBlank(picklistLabel)) {
                Integer labelSeparatorIndex = picklistLabel.indexOf('-');
    
                if (labelSeparatorIndex > 0) {
                    String code = picklistLabel
                        .substring(0, labelSeparatorIndex)
                        .trim()
                        .toUpperCase();
    
                    if (code == normalizedIncoming) {
                        return picklistLabel.substring(labelSeparatorIndex + 1).trim();
                    }
                }
            }
        }
    
        throw new CustomerMappingException(
            'Region mapping was not found for SAP value "' + incomingRegion + '".'
        );
    }
    
    private static String getCountryNameByCode(String incomingCountry) {
        if (String.isBlank(incomingCountry)) {
            return null;
        }
    
        Schema.DescribeFieldResult fieldDescribe = Account.Country__c.getDescribe();
        String normalizedIncoming = incomingCountry.trim().toUpperCase();
    
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (!entry.isActive() || String.isBlank(entry.getValue())) {
                continue;
            }
    
            String picklistValue = entry.getValue().trim();
            String picklistLabel = entry.getLabel();
    
            // Case 1:
            // Value/Label = "IN - India"
            Integer valueSeparatorIndex = picklistValue.indexOf('-');
    
            if (valueSeparatorIndex > 0) {
                String code = picklistValue
                    .substring(0, valueSeparatorIndex)
                    .trim()
                    .toUpperCase();
    
                if (code == normalizedIncoming) {
                    return picklistValue.substring(valueSeparatorIndex + 1).trim();
                }
            }
    
            // Case 2:
            // Value = "IN", Label = "India"
            if (picklistValue.toUpperCase() == normalizedIncoming) {
                if (!String.isBlank(picklistLabel)) {
                    return picklistLabel.trim();
                }
    
                return picklistValue;
            }
    
            // Case 3:
            // Label = "IN - India"
            if (!String.isBlank(picklistLabel)) {
                Integer labelSeparatorIndex = picklistLabel.indexOf('-');
    
                if (labelSeparatorIndex > 0) {
                    String code = picklistLabel
                        .substring(0, labelSeparatorIndex)
                        .trim()
                        .toUpperCase();
    
                    if (code == normalizedIncoming) {
                        return picklistLabel.substring(labelSeparatorIndex + 1).trim();
                    }
                }
            }
        }
    
        throw new CustomerMappingException(
            'Country mapping was not found for SAP value "' + incomingCountry + '".'
        );
    }

    private static String formatDateYYYYMMDD(Date inputDate) {
        String monthStr = (inputDate.month() < 10 ? '0' : '') + String.valueOf(inputDate.month());
        String dayStr = (inputDate.day() < 10 ? '0' : '') + String.valueOf(inputDate.day());

        return String.valueOf(inputDate.year()) + monthStr + dayStr;
    }

    private static void logIntegrationError(String apiName, String errorCode, String errorMessage, String httpMethod, String requestParameters, String requestUri, String sourceSystem, String stackTrace, String statusCode) {
        try {
            Integration_Error_Log__c logRec = new Integration_Error_Log__c();
            logRec.API_Name__c = apiName;
            logRec.Error_Code__c = errorCode;
            logRec.Error_Message__c = errorMessage;
            logRec.Http_Method__c = httpMethod;
            logRec.Logged_On__c = String.valueOf(System.now());
            logRec.Request_Parameters__c = requestParameters;
            logRec.Request_URI__c = requestUri;
            logRec.Source_System__c = sourceSystem;
            logRec.Stack_Trace__c = stackTrace;
            logRec.Status_Code__c = statusCode != null ? Decimal.valueOf(statusCode) : null;

            insert logRec;
        } catch (Exception logEx) {
            System.debug('Failed to log integration error: ' + logEx.getMessage());
        }
    }

    public class CustomerMappingException extends Exception {
    }
}
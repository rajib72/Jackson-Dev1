@RestResource(urlMapping='/get/accounts')
global with sharing class ctrl_VendorAccountAPI {

    private static final String API_NAME = 'VendorAccountAPI';

    global class BulkAccountResponse {
        public Boolean success;
        public String code;
        public String message;
        public Integer statusCode;
        public Integer totalRequested;
        public Integer totalReturned;
        public List<AccountRecordWrapper> records;
        public List<ResponseErrorWrapper> errors;

        public BulkAccountResponse() {
            records = new List<AccountRecordWrapper>();
            errors = new List<ResponseErrorWrapper>();
            totalRequested = 0;
            totalReturned = 0;
        }
    }

    global class AccountRecordWrapper {
        public Id sfCustomerId;
        public String customerName;
        public String nameContinue;
        public String companyCode;
        public String customerAccountGroup;
        public String customerType;
        public String streetHouseNumber;
        public String street2;
        public String street3;
        public String street4;
        public String district;
        public String city;
        public String region;
        public String country;
        public String postalCode;
        public String mobileNo;
        public String emailId;
        public String panNo;
        public String gstStatus;
        public String gstNo;
        public String lob;
        public String customerGroup;
        
        public Datetime lastModifiedDate;
    }

    global class ResponseErrorWrapper {
        public String errorCode;
        public String errorMessage;

        public ResponseErrorWrapper(String errorCode, String errorMessage) {
            this.errorCode = errorCode;
            this.errorMessage = errorMessage;
        }
    }

    global class ApiException extends Exception {
        public String errorCode;
        public Integer httpStatusCode;

        public ApiException(String errorCode, String message, Integer httpStatusCode) {
            this.errorCode = errorCode;
            this.setMessage(message);
            this.httpStatusCode = httpStatusCode;
        }
    }

    @HttpGet
    global static void getAccountsByDate() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        BulkAccountResponse responseObj = new BulkAccountResponse();

        try {
            String startDateStr = req.params.get('startDate');
            String endDateStr = req.params.get('endDate');

            validateInputs(startDateStr, endDateStr);

            Date startDate = Date.valueOf(startDateStr);
            Date endDate = Date.valueOf(endDateStr);
            
            String GSTNo;

            Datetime startDateTime = Datetime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
            Datetime endDateTime = Datetime.newInstance(endDate.year(), endDate.month(), endDate.day(), 23, 59, 59);

            List<Account> accountList = [
                SELECT Id, Name, Company_Code__c, Customer_Account_Group__c, Customer_Type__c, Street_Address__c, District__c, City__c, Region__c,
                Country__c,Postal_Code__c,Phone,Email__c,PAN__c,GST_Status__c,Billing_GST_No__c,LOB__c,Customer_Group__c
                FROM Account
                WHERE (CreatedDate >= :startDateTime
                  AND CreatedDate <= :endDateTime)
                ORDER BY CreatedDate DESC
                LIMIT 50000
            ];

            responseObj.totalRequested = accountList.size();

            Map<Id, AccountRecordWrapper> uniqueAccountMap = new Map<Id, AccountRecordWrapper>();

            for (Account acc : accountList) {
                if (!uniqueAccountMap.containsKey(acc.Id)) {
                    AccountRecordWrapper rec = new AccountRecordWrapper();
                    
                    rec.sfCustomerId = acc.Id;
                    rec.customerName = (acc.Name != null) ? acc.Name.substring(0, Math.min(34, acc.Name.length())) : '';
                    rec.nameContinue = (acc.Name != null && acc.Name.length() > 34) ? acc.Name.substring(34, Math.min(70, acc.Name.length())) : '';
                    rec.companyCode = acc.Company_Code__c;
                    rec.customerAccountGroup = acc.Customer_Account_Group__c;
                    rec.customerType = acc.Customer_Type__c;
                    rec.streetHouseNumber = (acc.Street_Address__c != null) ? acc.Street_Address__c.substring(0, Math.min(24, acc.Street_Address__c.length())) : '';
                    rec.street2 = (acc.Street_Address__c != null && acc.Street_Address__c .length() > 25) ? acc.Street_Address__c .substring(25, Math.min(49, acc.Street_Address__c .length())) : '';
                    rec.street3 = (acc.Street_Address__c != null && acc.Street_Address__c .length() > 50) ? acc.Street_Address__c .substring(50, Math.min(74, acc.Street_Address__c .length())) : '';
                    rec.street4 = (acc.Street_Address__c != null && acc.Street_Address__c .length() > 75) ? acc.Street_Address__c .substring(75, Math.min(99, acc.Street_Address__c .length())) : '';
                    rec.district = acc.District__c;
                    rec.city = acc.City__c;
                    rec.region = acc.Region__c;
                    rec.country= acc.Country__c;
                    rec.postalCode = acc.Postal_Code__c;
                    rec.mobileNo = acc.Phone;
                    rec.emailId = acc.Email__c;
                    rec.panNo = acc.PAN__c;
                    rec.gstStatus = acc.GST_Status__c;
                    rec.gstNo = acc.Billing_GST_No__c;
                    rec.lob= acc.LOB__c;
                    rec.customerGroup = acc.Customer_Group__c;
                    
                    uniqueAccountMap.put(acc.Id, rec);
                }
            }

            responseObj.records.addAll(uniqueAccountMap.values());
            responseObj.totalReturned = responseObj.records.size();
            responseObj.success = true;
            responseObj.code = 'SUCCESS_200';
            responseObj.message = 'Account records fetched successfully.';
            responseObj.statusCode = 200;

            sendResponse(200, responseObj);

        } catch (ApiException ae) {
            responseObj.success = false;
            responseObj.code = ae.errorCode;
            responseObj.message = ae.getMessage();
            responseObj.statusCode = ae.httpStatusCode;
            responseObj.errors.add(new ResponseErrorWrapper(ae.errorCode, ae.getMessage()));

            logError(
                req,
                ae.errorCode,
                ae.getMessage(),
                null,
                ae.httpStatusCode
            );

            sendResponse(ae.httpStatusCode, responseObj);

        } catch (Exception ex) {
            responseObj.success = false;
            responseObj.code = 'ERR_500';
            responseObj.message = 'Unexpected server error occurred.';
            responseObj.statusCode = 500;
            responseObj.errors.add(new ResponseErrorWrapper('ERR_500', ex.getMessage()));

            logError(
                req,
                'ERR_500',
                ex.getMessage(),
                ex.getStackTraceString(),
                500
            );

            sendResponse(500, responseObj);
        }
    }

    private static void validateInputs(String startDateStr, String endDateStr) {
        if (String.isBlank(startDateStr) || String.isBlank(endDateStr)) {
            throw new ApiException(
                'ERR_400_MISSING_DATE',
                'Both startDate and endDate are required in YYYY-MM-DD format.',
                400
            );
        }

        Date startDate;
        Date endDate;

        try {
            startDate = Date.valueOf(startDateStr);
            endDate = Date.valueOf(endDateStr);
        } catch (Exception e) {
            throw new ApiException(
                'ERR_400_INVALID_DATE_FORMAT',
                'Invalid date format. Please use YYYY-MM-DD.',
                400
            );
        }

        if (startDate > endDate) {
            throw new ApiException(
                'ERR_400_INVALID_DATE_RANGE',
                'startDate cannot be greater than endDate.',
                400
            );
        }
    }

    private static void sendResponse(Integer statusCode, BulkAccountResponse responseObj) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseObj));
    }

    private static void logError(
        RestRequest req,
        String errorCode,
        String errorMessage,
        String stackTrace,
        Integer statusCode
    ) {
        try {
            Integration_Error_Log__c logRec = new Integration_Error_Log__c();
            logRec.API_Name__c = API_NAME;
            logRec.Request_URI__c = req != null ? req.requestURI : null;
            logRec.Http_Method__c = req != null ? req.httpMethod : null;
            logRec.Request_Parameters__c  = req != null ? JSON.serialize(req.params) : null;
            logRec.Error_Code__c = errorCode;
            logRec.Error_Message__c = errorMessage;
            logRec.Stack_Trace__c = stackTrace;
            logRec.Status_Code__c = statusCode;
            insert logRec;
        } catch (Exception loggingEx) {
            System.debug('Error while logging API exception: ' + loggingEx.getMessage());
        }
    }
}
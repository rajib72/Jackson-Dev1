public with sharing class API_ctrl_OrderSapEmployeeController {

    public class EmployeeOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String employeeCode;
        @AuraEnabled public String employeeName;

        public EmployeeOption(String employeeCode, String employeeName) {
            this.employeeCode = employeeCode;
            this.employeeName = employeeName;
            this.label = employeeCode + ' - ' + employeeName;
            this.value = employeeCode;
        }
    }

    public class EmployeeResponseWrapper {
        public List<EmployeeData> EMPLOYEE;
    }

    public class EmployeeData {
        public String EMPLOYEE;
        public String FIRST_NAME;
        public String LAST_NAME;
    }

    @AuraEnabled(cacheable=false)
    public static List<EmployeeOption> fetchSapEmployees(Id orderId) {
        List<EmployeeOption> options = new List<EmployeeOption>();
        String requestBodyString = null;
        String endpoint = 'callout:NC_SAP_API/http/empMast';
        String httpMethod = 'POST';

        try {
            if (orderId == null) {
                throw new AuraHandledException('Order Id is required.');
            }

            Order ord = [
                SELECT Id, COMP_CODE__c
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            if (String.isBlank(ord.COMP_CODE__c)) {
                throw new AuraHandledException('COMP_CODE__c is blank on this Order.');
            }

            Map<String, Object> requestBody = new Map<String, Object>{
                'COMP_CODE' => ord.COMP_CODE__c
            };

            requestBodyString = JSON.serialize(requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod(httpMethod);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBodyString);

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            String responseBody = res.getBody();

            if (statusCode != 200) {
                logIntegrationError(
                    'SAP Employee Master API',
                    String.valueOf(statusCode),
                    'Non-success response from SAP API',
                    httpMethod,
                    requestBodyString,
                    endpoint,
                    'SAP',
                    responseBody,
                    String.valueOf(statusCode)
                );
                throw new AuraHandledException('Failed to fetch employee data from SAP. Status Code: ' + statusCode);
            }

            if (String.isBlank(responseBody)) {
                logIntegrationError(
                    'SAP Employee Master API',
                    null,
                    'Blank response received from SAP API',
                    httpMethod,
                    requestBodyString,
                    endpoint,
                    'SAP',
                    null,
                    String.valueOf(statusCode)
                );
                throw new AuraHandledException('Blank response received from SAP API.');
            }

            EmployeeResponseWrapper parsedResponse =
                (EmployeeResponseWrapper) JSON.deserialize(responseBody, EmployeeResponseWrapper.class);

            if (parsedResponse == null || parsedResponse.EMPLOYEE == null || parsedResponse.EMPLOYEE.isEmpty()) {
                logIntegrationError(
                    'SAP Employee Master API',
                    null,
                    'No employee data found in SAP response',
                    httpMethod,
                    requestBodyString,
                    endpoint,
                    'SAP',
                    responseBody,
                    String.valueOf(statusCode)
                );
                throw new AuraHandledException('No employee values returned from SAP.');
            }

            for (EmployeeData emp : parsedResponse.EMPLOYEE) {
                String empCode = emp.EMPLOYEE;
                String empName = ((emp.FIRST_NAME != null ? emp.FIRST_NAME : '') + ' ' +
                                  (emp.LAST_NAME != null ? emp.LAST_NAME : '')).trim();

                options.add(new EmployeeOption(empCode, empName));
            }

            return options;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            logIntegrationError(
                'SAP Employee Master API',
                null,
                e.getMessage(),
                httpMethod,
                requestBodyString,
                endpoint,
                'SAP',
                e.getStackTraceString(),
                null
            );
            throw new AuraHandledException('Error while fetching SAP employee data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveSelectedEmployee(Id orderId, String employeeCode, String employeeName) {
        try {
            if (orderId == null) {
                throw new AuraHandledException('Order Id is required.');
            }
            if (String.isBlank(employeeCode)) {
                throw new AuraHandledException('Employee Code is required.');
            }
            if (String.isBlank(employeeName)) {
                throw new AuraHandledException('Employee Name is required.');
            }

            Order ord = new Order(
                Id = orderId,
                SAP_Employee_Code__c = employeeCode,
                SAP_Employee_Name__c = employeeName
            );
            update ord;

            return 'Employee details saved successfully.';
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            logIntegrationError(
                'SAP Employee Save',
                null,
                e.getMessage(),
                'UPDATE',
                'orderId=' + String.valueOf(orderId) + ', employeeCode=' + employeeCode + ', employeeName=' + employeeName,
                'Order Update',
                'Salesforce',
                e.getStackTraceString(),
                null
            );
            throw new AuraHandledException('Error while saving employee data: ' + e.getMessage());
        }
    }

    private static void logIntegrationError(
        String apiName,
        String errorCode,
        String errorMessage,
        String httpMethod,
        String requestParameters,
        String requestUri,
        String sourceSystem,
        String stackTrace,
        String statusCode
    ) {
        try {
            Integration_Error_Log__c logRec = new Integration_Error_Log__c();
            logRec.API_Name__c = apiName;
            logRec.Error_Code__c = errorCode;
            logRec.Error_Message__c = errorMessage;
            logRec.Http_Method__c = httpMethod;
            logRec.Logged_On__c = string.ValueOf(System.now());
            logRec.Request_Parameters__c = requestParameters;
            logRec.Request_URI__c = requestUri;
            logRec.Source_System__c = sourceSystem;
            logRec.Stack_Trace__c = stackTrace;
            logRec.Status_Code__c = Decimal.ValueOf(statusCode);

            insert logRec;
        } catch (Exception ex) {
            System.debug('Failed to insert Integration_Error_Log__c: ' + ex.getMessage());
        }
    }
}
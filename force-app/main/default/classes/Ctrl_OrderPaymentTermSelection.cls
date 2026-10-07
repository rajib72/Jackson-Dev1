public class Ctrl_OrderPaymentTermSelection {

    @AuraEnabled
    public static List<PaymentTermOption> fetchPaymentTerms(Id orderId) {
        List<PaymentTermOption> options = new List<PaymentTermOption>();
        
        try {
            // 1. Fetch required Order fields
            Order orderRec = [
                SELECT Id, Sold_to_party_Code__c, COMP_CODE__c, Distribution_Channel__c, Division__c 
                FROM Order 
                WHERE Id = :orderId 
                LIMIT 1
            ];
            
            // 2. Prepare API Callout
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('Callout:NC_SAP_API/http/paymentTerms');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            
            // Prepare Request Body
            Map<String, String> reqBodyMap = new Map<String, String>{
                // 'SOLD_TO_PARTY' => String.isNotBlank(orderRec.Sold_to_party_Code__c) ? orderRec.Sold_to_party_Code__c : '',
                // 'SALES_ORG'     => String.isNotBlank(orderRec.COMP_CODE__c) ? orderRec.COMP_CODE__c : '',
                // 'DIST_CHAN'     => String.isNotBlank(orderRec.Distribution_Channel__c) ? orderRec.Distribution_Channel__c : '',
                // 'DIVISION'      => String.isNotBlank(orderRec.Division__c) ? orderRec.Division__c : ''
            };
            request.setBody(JSON.serialize(reqBodyMap));
            
            // 3. Execute Callout
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                // Parse response robustly to handle both Single Object and Array responses from SAP
                Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                if (parsedResponse.containsKey('RESULT')) {
                    Object resultObj = parsedResponse.get('RESULT');

                    // Checks if it's missing entirely, or if it is a string that is empty/whitespace
                    if (resultObj == null || (resultObj instanceof String && String.isBlank((String)resultObj))) {
                        throw new AuraHandledException('No Payment Terms Found');
                    }
                    Map<String, Object> resultNode = (Map<String, Object>) parsedResponse.get('RESULT');
                    
                    if (resultNode.containsKey('item')) {
                        Object itemNode = resultNode.get('item');
                        
                        // If SAP returns a list of items
                        if (itemNode instanceof List<Object>) {
                            for (Object obj : (List<Object>) itemNode) {
                                options.add(mapItemToOption((Map<String, Object>) obj));
                            }
                        } 
                        // If SAP returns a single object
                        else if (itemNode instanceof Map<String, Object>) {
                            options.add(mapItemToOption((Map<String, Object>) itemNode));
                        }
                    }
                }
            } else {
                throw new CalloutException('Failed to fetch Payment Terms. Status Code: ' + response.getStatusCode());
            }
        } catch (AuraHandledException e) {
            throw e; 
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        return options;
    }

    private static PaymentTermOption mapItemToOption(Map<String, Object> itemMap) {
        PaymentTermOption opt = new PaymentTermOption();
        opt.termCode = (String) itemMap.get('PAYMENT_TERMS');
        opt.termDesc = (String) itemMap.get('DESCRIPTION');
        
        opt.termCode = String.isNotBlank(opt.termCode) ? opt.termCode : '';
        opt.termDesc = String.isNotBlank(opt.termDesc) ? opt.termDesc : 'No Description';
        
        opt.label = opt.termCode + ' - ' + opt.termDesc;
        opt.value = opt.termCode;
        return opt;
    }

    @AuraEnabled
    public static String saveSelectedPaymentTerm(Id orderId, String termCode, String termDesc) {
        try {
            Order updateOrder = new Order(
                Id = orderId,
                Payment_Terms_Text__c = termCode,
                Payment_Terms_Description__c = termDesc
            );
            update updateOrder;
            return 'Payment Terms successfully updated!';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving record: ' + e.getMessage());
        }
    }

    // --- Wrapper Class ---
    public class PaymentTermOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String termCode;
        @AuraEnabled public String termDesc;
    }
}
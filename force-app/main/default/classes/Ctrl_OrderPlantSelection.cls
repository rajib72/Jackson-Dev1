public with sharing class Ctrl_OrderPlantSelection {

    @AuraEnabled
    public static List<PlantOption> fetchPlants(Id orderId) {
        List<PlantOption> options = new List<PlantOption>();
        
        try {
            // 1. Fetch Order COMP_CODE__c
            Order orderRec = [SELECT Id, COMP_CODE__c FROM Order WHERE Id = :orderId LIMIT 1];
            String compCode = String.isNotBlank(orderRec.COMP_CODE__c) ? orderRec.COMP_CODE__c : '';
            
            // 2. Prepare API Callout
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('Callout:NC_SAP_API/http/plantMast');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            
            // Prepare Request Body
            Map<String, String> reqBodyMap = new Map<String, String>{
                'SALES_ORG' => compCode
            };
            request.setBody(JSON.serialize(reqBodyMap));
            
            // 3. Execute Callout
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                // Parse the response
                PlantResponse parsedResponse = (PlantResponse) JSON.deserialize(response.getBody(), PlantResponse.class);
                
                if (parsedResponse != null && parsedResponse.RESULT != null && parsedResponse.RESULT.item != null) {
                    for (PlantNode node : parsedResponse.RESULT.item) {
                        PlantOption opt = new PlantOption();
                        opt.plantCode = node.PLANT;
                        opt.plantName = String.isNotBlank(node.DESCRIPTION) ? node.DESCRIPTION : 'No Description';
                        opt.label = node.PLANT + ' - ' + opt.plantName;
                        opt.value = node.PLANT;
                        options.add(opt);
                    }
                }
            } else {
                throw new CalloutException('Failed to fetch plants. Status Code: ' + response.getStatusCode());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
        return options;
    }

    @AuraEnabled
    public static String saveSelectedPlant(Id orderId, String plantCode) {
        try {
            Order updateOrder = new Order(
                Id = orderId,
                Delivering_Plant__c = plantCode
            );
            update updateOrder;
            return 'Delivering Plant successfully updated!';
        } catch (Exception e) {
            throw new AuraHandledException('Error saving record: ' + e.getMessage());
        }
    }

    // --- Wrapper Classes for JSON Parsing & Response ---

    public class PlantOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String plantCode;
        @AuraEnabled public String plantName;
    }

    public class PlantResponse {
        public ResultNode RESULT;
    }

    public class ResultNode {
        public List<PlantNode> item;
    }

    public class PlantNode {
        public String PLANT;
        public String DESCRIPTION;
    }
}
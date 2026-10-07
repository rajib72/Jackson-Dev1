public with sharing class Ctrl_AddSrtOrderDetailsToOrder {

    public class IncotermOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public String detail;

        public IncotermOption(Incoterms_Master__c incoterm) {
            this.id = incoterm.Id;
            this.value = incoterm.INCOTERMS__c;
            this.label = incoterm.INCOTERMS__c;
            this.detail = incoterm.IncoTerms_Details__c;
        }
    }

    public class OrderDetailsWrapper {
        @AuraEnabled public String salesOffice;
        @AuraEnabled public String salesGroup;
        @AuraEnabled public Id incotermId;
        @AuraEnabled public String incotermValue;
        @AuraEnabled public String incotermLabel;
        @AuraEnabled public String incotermDetail;
    }

    @AuraEnabled(cacheable=true)
    public static OrderDetailsWrapper getOrderDetails(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        Order ord = [
            SELECT Id,
                   InCoTerms__c,
                   Sales_Office__c,
                   Sales_Group__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        OrderDetailsWrapper response = new OrderDetailsWrapper();

        response.salesOffice = String.isBlank(ord.Sales_Office__c) ? 'COP1' : ord.Sales_Office__c;
        response.salesGroup = String.isBlank(ord.Sales_Group__c) ? 'DC1' : ord.Sales_Group__c;
        response.incotermValue = ord.InCoTerms__c;
        response.incotermLabel = ord.InCoTerms__c;

        if (!String.isBlank(ord.InCoTerms__c)) {
            List<Incoterms_Master__c> incotermList = [
                SELECT Id,
                       INCOTERMS__c,
                       IncoTerms_Details__c
                FROM Incoterms_Master__c
                WHERE INCOTERMS__c = :ord.InCoTerms__c
                LIMIT 1
            ];

            if (!incotermList.isEmpty()) {
                response.incotermId = incotermList[0].Id;
                response.incotermValue = incotermList[0].INCOTERMS__c;
                response.incotermLabel = incotermList[0].INCOTERMS__c;
                response.incotermDetail = incotermList[0].IncoTerms_Details__c;
            }
        }

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<IncotermOption> searchIncoterms(String searchKey) {
        String cleanedSearchKey = String.isBlank(searchKey) ? '' : searchKey.trim();

        List<Incoterms_Master__c> incotermRecords = new List<Incoterms_Master__c>();

        if (String.isBlank(cleanedSearchKey)) {
            incotermRecords = [
                SELECT Id,
                       INCOTERMS__c,
                       IncoTerms_Details__c
                FROM Incoterms_Master__c
                ORDER BY INCOTERMS__c ASC
                LIMIT 50
            ];
        } else {
            String likeKey = '%' + cleanedSearchKey + '%';

            incotermRecords = [
                SELECT Id,
                       INCOTERMS__c,
                       IncoTerms_Details__c
                FROM Incoterms_Master__c
                WHERE INCOTERMS__c LIKE :likeKey
                   OR IncoTerms_Details__c LIKE :likeKey
                ORDER BY INCOTERMS__c ASC
                LIMIT 50
            ];
        }

        List<IncotermOption> optionList = new List<IncotermOption>();

        for (Incoterms_Master__c incoterm : incotermRecords) {
            optionList.add(new IncotermOption(incoterm));
        }

        return optionList;
    }

    @AuraEnabled
    public static void saveOrderDetails(
        Id orderId,
        String incotermsValue,
        String salesOffice,
        String salesGroup
    ) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        if (String.isBlank(incotermsValue)) {
            throw new AuraHandledException('Incoterms is required.');
        }

        if (String.isBlank(salesOffice)) {
            throw new AuraHandledException('Sales Office is required.');
        }

        if (String.isBlank(salesGroup)) {
            throw new AuraHandledException('Sales Group is required.');
        }

        Order orderToUpdate = new Order();
        orderToUpdate.Id = orderId;
        orderToUpdate.InCoTerms__c = incotermsValue.trim();
        orderToUpdate.Sales_Office__c = salesOffice.trim();
        orderToUpdate.Sales_Group__c = salesGroup.trim();

        update orderToUpdate;
    }
}
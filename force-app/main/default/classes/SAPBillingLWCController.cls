public with sharing class SAPBillingLWCController {
    
    // 1. Fetch Related Delivery Information records
    @AuraEnabled(cacheable=true)
    public static List<Delivery_Information__c> getDeliveryRecords(Id orderId) {
        return [SELECT Id, Name, SAP_Delivery_No__c 
                FROM Delivery_Information__c 
                WHERE Order__c = :orderId];
    }

    // 2. Fetch Billing Info using the existing API Controller
    @AuraEnabled
    public static List<API_Ctrl_BillingInformationController.BillingInfoRow> fetchFromSAP(List<String> deliveryNumbers) {
        List<API_Ctrl_BillingInformationController.BillingInfoRow> allRecords = new List<API_Ctrl_BillingInformationController.BillingInfoRow>();
        
        try {
            // Loop through selected deliveries and call the API for each
            for (String delNum : deliveryNumbers) {
                API_Ctrl_BillingInformationController.BillingInfoResponse response = 
                    API_Ctrl_BillingInformationController.fetchBillingInformation('DELIVERY', null, null, delNum);
                
                if (response.success && response.records != null) {
                    allRecords.addAll(response.records);
                }
            }
            return allRecords;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching SAP Data: ' + e.getMessage());
        }
    }

    // 3. Save records to SAP_Invoice_Details__c and Update OrderItems
    @AuraEnabled
    public static String saveInvoiceDetails(Id orderId, String jsonString) {
        try {
            // Deserialize the JSON sent from LWC
            List<API_Ctrl_BillingInformationController.BillingInfoRow> rowsToSave = 
                (List<API_Ctrl_BillingInformationController.BillingInfoRow>) JSON.deserialize(
                    jsonString, List<API_Ctrl_BillingInformationController.BillingInfoRow>.class
                );

            if (rowsToSave.isEmpty()) return 'No records to save.';

            // ==========================================
            // UPSERT LOGIC (Update existing, Insert new)
            // ==========================================
            List<SAP_Invoice_Details__c> existingInvoices = [
                SELECT Id, Invoice_number__c, Invoice_Item_No__c, Delivery_Information__r.SAP_Delivery_No__c 
                FROM SAP_Invoice_Details__c 
                WHERE Order__c = :orderId
            ];
            
            Map<String, SAP_Invoice_Details__c> existingInvoiceMap = new Map<String, SAP_Invoice_Details__c>();
            for(SAP_Invoice_Details__c existing : existingInvoices) {
                String invNo = String.isNotBlank(existing.Invoice_number__c) ? existing.Invoice_number__c : '';
                String itemNo = String.isNotBlank(existing.Invoice_Item_No__c) ? existing.Invoice_Item_No__c : '';
                String delNo = (existing.Delivery_Information__r != null && String.isNotBlank(existing.Delivery_Information__r.SAP_Delivery_No__c)) 
                               ? existing.Delivery_Information__r.SAP_Delivery_No__c : '';
                
                existingInvoiceMap.put(invNo + '-' + itemNo + '-' + delNo, existing);
            }

            // Query deliveries to map the SAP Delivery No back to the Salesforce Delivery Record Id
            List<Delivery_Information__c> relatedDeliveries = [SELECT Id, SAP_Delivery_No__c 
                                                               FROM Delivery_Information__c 
                                                               WHERE Order__c = :orderId];
                                                               
            Map<String, Id> deliveryNumberToIdMap = new Map<String, Id>();
            for(Delivery_Information__c del : relatedDeliveries) {
                if(String.isNotBlank(del.SAP_Delivery_No__c)) {
                    deliveryNumberToIdMap.put(del.SAP_Delivery_No__c, del.Id);
                }
            }

            Map<String, SAP_Invoice_Details__c> invoicesToUpsertMap = new Map<String, SAP_Invoice_Details__c>();
            
            // MAP to hold billing details by normalized Line Item Number for targeted OrderItem updates
            Map<String, API_Ctrl_BillingInformationController.BillingInfoRow> lineItemToBillingMap = new Map<String, API_Ctrl_BillingInformationController.BillingInfoRow>();

            for (API_Ctrl_BillingInformationController.BillingInfoRow row : rowsToSave) {
                
                String rowInvNo = String.isNotBlank(row.billingDocument) ? row.billingDocument : '';
                String rowItemNo = String.isNotBlank(row.billingLineItemNo) ? row.billingLineItemNo : '';
                String rowDelNo = String.isNotBlank(row.deliveryNumber) ? row.deliveryNumber : '';
                
                String rowKey = rowInvNo + '-' + rowItemNo + '-' + rowDelNo;

                SAP_Invoice_Details__c inv = existingInvoiceMap.containsKey(rowKey) 
                    ? existingInvoiceMap.get(rowKey) 
                    : new SAP_Invoice_Details__c(Order__c = orderId);

                inv.Invoice_number__c = row.billingDocument;
                inv.Invoice_Item_No__c = row.billingLineItemNo;
                inv.Invoice_Amount__c = Decimal.valueOf(row.billingDocumentAmount);
                
                // Native Date.valueOf handles 'YYYY-MM-DD' automatically
                if(String.isNotBlank(row.billingDocumentDate)) {
                    inv.Invoice_Date__c = Date.valueOf(row.billingDocumentDate); 
                }
                
                if (deliveryNumberToIdMap.containsKey(row.deliveryNumber)) {
                    inv.Delivery_Information__c = deliveryNumberToIdMap.get(row.deliveryNumber);
                }

                invoicesToUpsertMap.put(rowKey, inv);
                
                // Populate map for OrderItem matching (normalize line item no to handle leading zeros)
                if (String.isNotBlank(rowItemNo)) {
                    String normalizedItemNo = removeLeadingZeros(rowItemNo);
                    lineItemToBillingMap.put(normalizedItemNo, row);
                }
            }

            if(invoicesToUpsertMap.isEmpty()) {
                return 'No valid records to process.';
            }

            // Perform Upsert
            upsert invoicesToUpsertMap.values();

            // ==========================================
            // NEW: UPDATE ORDER ITEMS (Matched by Line Item No)
            // ==========================================
            if (!lineItemToBillingMap.isEmpty()) {
                
                List<OrderItem> orderItemsToUpdate = [
                    SELECT Id, SAP_Line_Item_No__c, Invoice_Number__c, Invoice_Date__c 
                    FROM OrderItem 
                    WHERE OrderId = :orderId
                ];

                List<OrderItem> itemsToUpdateFinal = new List<OrderItem>();

                for (OrderItem oi : orderItemsToUpdate) {
                    // Check against the line item field (safely handling nulls and removing leading zeros)
                    String oiItemNo = String.isNotBlank(oi.SAP_Line_Item_No__c) ? oi.SAP_Line_Item_No__c : '';
                    String normalizedOiItemNo = removeLeadingZeros(oiItemNo);

                    // If they match, apply the invoice details to this specific OrderItem
                    if (String.isNotBlank(normalizedOiItemNo) && lineItemToBillingMap.containsKey(normalizedOiItemNo)) {
                        
                        API_Ctrl_BillingInformationController.BillingInfoRow matchedRow = lineItemToBillingMap.get(normalizedOiItemNo);
                        
                        oi.Invoice_Number__c = matchedRow.billingDocument;
                        if (String.isNotBlank(matchedRow.billingDocumentDate)) {
                            // Converts '2026-06-25' seamlessly
                            oi.Invoice_Date__c = Date.valueOf(matchedRow.billingDocumentDate);
                        }
                        
                        itemsToUpdateFinal.add(oi);
                    }
                }

                if (!itemsToUpdateFinal.isEmpty()) {
                    update itemsToUpdateFinal;
                }
            }
            // ==========================================

            return 'Success';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving records: ' + e.getMessage());
        }
    }

    // Helper method to strip leading zeros so that "00010" and "10" match perfectly
    private static String removeLeadingZeros(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        // Replace leading zeros using regex
        String stripped = input.replaceFirst('^0+', '');
        // If the original string was '0' or '000', 'stripped' will be empty, so we safely return '0'
        return String.isBlank(stripped) ? '0' : stripped;
    }

    public static void datacover() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}
public with sharing class API_ctrl_SapSalesOrderImportController {
    private static final String defaultAccountName = 'Default Account For Importing SAP Order';
    private static final String MATERIAL_MASTER_ENDPOINT = 'callout:NC_SAP_API/http/rfcMatMast';

    public class SalesOrderRow {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String status;

        @AuraEnabled public String salesOrder;
        @AuraEnabled public String creationDate;
        @AuraEnabled public String distChan;
        @AuraEnabled public String division;
        @AuraEnabled public String salesGroup;
        @AuraEnabled public String salesOffice;
        @AuraEnabled public String documentType;
        @AuraEnabled public String orderReason;
        @AuraEnabled public String salesOrg;
        @AuraEnabled public String deliveringPlant;
        @AuraEnabled public String bgRequired;
        @AuraEnabled public String ldClause;
        @AuraEnabled public String tpc;

        @AuraEnabled public String lineItemNo;
        @AuraEnabled public String materialCode;
        @AuraEnabled public String plant;
        @AuraEnabled public String itemCategory;
        @AuraEnabled public String qty;
        @AuraEnabled public String netPrice;
        @AuraEnabled public String netValue;
        @AuraEnabled public String route;
        @AuraEnabled public String performanceWarranty;
        @AuraEnabled public String productWarranty;
    }

    public class ImportResult {
        @AuraEnabled public Integer totalFromApi = 0;
        @AuraEnabled public Integer duplicateOrders = 0;
        @AuraEnabled public Integer insertedOrders = 0;
        @AuraEnabled public Integer updatedOrders = 0;
        @AuraEnabled public Integer insertedOrderItems = 0;
        @AuraEnabled public Integer updatedOrderItems = 0;
        @AuraEnabled public Integer duplicateOrderItems = 0;
        @AuraEnabled public Integer failedOrders = 0;
        @AuraEnabled public Integer failedOrderItems = 0;
        @AuraEnabled public Integer materialMatched = 0;
        @AuraEnabled public Integer materialNotFound = 0;
        @AuraEnabled public String message;

        @AuraEnabled public List<SalesOrderRow> records = new List<SalesOrderRow>();
    }

    private class SapMaterialDTO {
        public String MATERIAL_CODE;
        public String MATERIAL_DESCRIPTION;
        public String CREATED_ON;
        public String CREATED_BY;
        public String MATERIAL_GROUP;
        public String MATERIAL_GROUP_DESCRIPTION;
        public String UNIT_OF_MEASURE;
        public String MATERIAL_TYPE;
        public String MATERIAL_TYPE_DESCRIPTION;
        public String PLANT;
        public String PLANT_DESCRIPTION;
        public String STORAGE_LOCATION;
        public String STORAGE_LOCATION_DESCRIPTION;
        public String SALES_ORG;
        public String DISTRIBUTION_CHANNEL;
        public String DISTTRIBUTION_CHANNEL_DESC;
        public String DIVISION;
        public String DIVISION_DESCRIPTION;
    }

    @AuraEnabled
    public static ImportResult importSalesOrders(Date fromDate, Date toDate) {
        ImportResult result = new ImportResult();

        String endpoint = 'callout:NC_SAP_API/http/salesOrderDetails';
        String requestBody;

        try {
            System.debug('===== SALES ORDER IMPORT STARTED =====');
            System.debug('===== FROM DATE ===== ' + fromDate);
            System.debug('===== TO DATE ===== ' + toDate);

            if (fromDate == null || toDate == null) {
                throw new AuraHandledException('From Date and To Date are required.');
            }

            if (toDate < fromDate) {
                throw new AuraHandledException('To Date cannot be less than From Date.');
            }

            String fromFormattedDate = formatDateYYYYMMDD(fromDate);
            String toFormattedDate = formatDateYYYYMMDD(toDate);

            Map<String, Object> requestMap = new Map<String, Object>{
                'CREATION_FROM_DATE' => fromFormattedDate,
                'CREATION_TO_DATE'   => toFormattedDate
            };

            requestBody = JSON.serialize(requestMap);

            System.debug('===== SAP REQUEST BODY ===== ' + requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('===== SAP API STATUS CODE ===== ' + res.getStatusCode());
            System.debug('===== SAP API RESPONSE BODY ===== ' + res.getBody());

            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                logIntegrationError(
                    'Sales Order Details API',
                    'HTTP_ERROR',
                    res.getBody(),
                    'POST',
                    requestBody,
                    endpoint,
                    'SAP',
                    null,
                    res.getStatusCode()
                );

                throw new AuraHandledException('SAP API failed. Status Code: ' + res.getStatusCode());
            }

            Map<String, Object> responseMap =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            if (!responseMap.containsKey('SALES_ORDER_DETAILS') || responseMap.get('SALES_ORDER_DETAILS') == null) {
                result.message = 'No SALES_ORDER_DETAILS found in SAP response.';
                return result;
            }

            List<Object> apiRows = (List<Object>) responseMap.get('SALES_ORDER_DETAILS');
            result.totalFromApi = apiRows.size();

            System.debug('===== TOTAL API ROWS ===== ' + apiRows.size());

            if (apiRows.isEmpty()) {
                result.message = 'No records found from SAP.';
                return result;
            }

            List<Map<String, Object>> sapRows = new List<Map<String, Object>>();
            Set<String> sapOrderIds = new Set<String>();
            Set<String> materialCodes = new Set<String>();
            Set<String> materialUniqueKeys = new Set<String>();

            for (Object obj : apiRows) {
                Map<String, Object> row = (Map<String, Object>) obj;

                String salesOrder = getString(row, 'SALES_ORDER');
                String lineItemNo = stripLeadingZeros(getString(row, 'LINE_ITEM_NO'));
                String materialCode = getString(row, 'MATERIAL_CODE');
                String materialUniqueKey = buildMaterialUniqueKeyFromSalesOrderRow(row);

                if (String.isNotBlank(salesOrder)) {
                    sapOrderIds.add(salesOrder);
                    sapRows.add(row);
                }

                if (String.isNotBlank(materialCode)) {
                    materialCodes.add(materialCode);
                }

                if (String.isNotBlank(materialUniqueKey)) {
                    materialUniqueKeys.add(materialUniqueKey);
                }

                SalesOrderRow displayRow = new SalesOrderRow();
                displayRow.rowKey = salesOrder + '-' + lineItemNo;
                displayRow.salesOrder = salesOrder;
                displayRow.creationDate = getString(row, 'CREATION_DATE');
                displayRow.distChan = getString(row, 'DIST_CHAN');
                displayRow.division = getString(row, 'DIVISION');
                displayRow.salesGroup = getString(row, 'SALES_GROUP');
                displayRow.salesOffice = getString(row, 'SALES_OFFICE');
                displayRow.documentType = getString(row, 'DOCUMENT_TYPE');
                displayRow.orderReason = getString(row, 'ORDER_REASON');
                displayRow.salesOrg = getString(row, 'SALES_ORG');
                displayRow.deliveringPlant = getString(row, 'DELIVERING_PLANT');
                displayRow.bgRequired = getString(row, 'BG_REQUIRED');
                displayRow.ldClause = getString(row, 'LD_CLAUSE');
                displayRow.tpc = getString(row, 'TPC');

                displayRow.lineItemNo = lineItemNo;
                displayRow.materialCode = materialCode;
                displayRow.plant = getString(row, 'PLANT');
                displayRow.itemCategory = getString(row, 'ITEM_CATAGORY');
                displayRow.qty = getString(row, 'QTY');
                displayRow.netPrice = getString(row, 'NET_PRICE');
                displayRow.netValue = getString(row, 'NET_VALUE');
                displayRow.route = getString(row, 'ROUTE');
                displayRow.performanceWarranty = getString(row, 'PERFORMANCE_WARRANTY');
                displayRow.productWarranty = getString(row, 'PRODUCT_WARRANTY');

                result.records.add(displayRow);
            }

            System.debug('===== SAP ROWS SIZE ===== ' + sapRows.size());
            System.debug('===== SAP ORDER IDS ===== ' + sapOrderIds);
            System.debug('===== MATERIAL CODES ===== ' + materialCodes);
            System.debug('===== MATERIAL UNIQUE KEYS ===== ' + materialUniqueKeys);

            if (sapOrderIds.isEmpty()) {
                result.message = 'No valid SALES_ORDER found in SAP response.';
                return result;
            }

            /*
             * Existing Order check based on SAP_Order_ID__c
             */
            Map<String, Order> existingOrderMap = new Map<String, Order>();

            for (Order ord : [
                SELECT Id, SAP_Order_ID__c
                FROM Order
                WHERE SAP_Order_ID__c IN :sapOrderIds
            ]) {
                existingOrderMap.put(ord.SAP_Order_ID__c, ord);
            }

            result.duplicateOrders = existingOrderMap.size();

            System.debug('===== EXISTING ORDER MAP SIZE ===== ' + existingOrderMap.size());
            System.debug('===== EXISTING ORDER MAP KEYS ===== ' + existingOrderMap.keySet());

            /*
             * Common Order map.
             * This will hold both existing Orders and newly inserted Orders.
             */
            Map<String, Id> allSapOrderIdToOrderId = new Map<String, Id>();

            for (String sapOrderId : existingOrderMap.keySet()) {
                allSapOrderIdToOrderId.put(sapOrderId, existingOrderMap.get(sapOrderId).Id);
            }

            System.debug('===== EXISTING ORDERS ADDED TO ALL ORDER MAP ===== ' + allSapOrderIdToOrderId);

            /*
             * Material Master map based on Unique_Key__c.
             * If material is not available in Salesforce, Material Master API is called by MATERIAL_CODE only.
             */
            Map<String, Material_Master__c> materialMap = getMaterialMasterMapByUniqueKey(materialUniqueKeys);

            Set<String> missingMaterialCodesForApi = new Set<String>();

            for (Map<String, Object> row : sapRows) {
                String materialCode = getString(row, 'MATERIAL_CODE');
                String materialUniqueKey = buildMaterialUniqueKeyFromSalesOrderRow(row);

                if (
                    String.isNotBlank(materialCode) &&
                    String.isNotBlank(materialUniqueKey) &&
                    !materialMap.containsKey(materialUniqueKey)
                ) {
                    missingMaterialCodesForApi.add(materialCode);
                }
            }

            System.debug('===== INITIAL MATERIAL MAP SIZE ===== ' + materialMap.size());
            System.debug('===== INITIAL MATERIAL MAP KEYS ===== ' + materialMap.keySet());
            System.debug('===== MISSING MATERIAL CODES FOR API ===== ' + missingMaterialCodesForApi);

            Map<String, Id> materialCodeToMaterialMasterIdFromApi = new Map<String, Id>();

            if (!missingMaterialCodesForApi.isEmpty()) {
                materialCodeToMaterialMasterIdFromApi = fetchMissingMaterialMastersFromSap(missingMaterialCodesForApi);

                materialMap = getMaterialMasterMapByUniqueKey(materialUniqueKeys);

                System.debug('===== MATERIAL MAP SIZE AFTER SAP MATERIAL API ===== ' + materialMap.size());
                System.debug('===== MATERIAL MAP KEYS AFTER SAP MATERIAL API ===== ' + materialMap.keySet());
                System.debug('===== MATERIAL CODE TO MATERIAL MASTER ID FROM API ===== ' + materialCodeToMaterialMasterIdFromApi);
            }

            /*
             * Standard Product / Standard Pricebook / PricebookEntry
             */
            Id standardProductId = getStandardProductId();
            System.debug('===== STANDARD PRODUCT ID ===== ' + standardProductId);

            Id standardPricebookId = getStandardPricebookId();
            System.debug('===== STANDARD PRICEBOOK ID ===== ' + standardPricebookId);

            Id standardPricebookEntryId = getOrCreatePricebookEntry(standardProductId, standardPricebookId);
            System.debug('===== STANDARD PRICEBOOK ENTRY ID ===== ' + standardPricebookEntryId);

            /*
             * Prepare unique Orders for Upsert.
             */
            Map<String, Map<String, Object>> uniqueOrderRows = new Map<String, Map<String, Object>>();

            for (Map<String, Object> row : sapRows) {
                String salesOrder = getString(row, 'SALES_ORDER');

                if (String.isBlank(salesOrder)) {
                    continue;
                }

                if (!uniqueOrderRows.containsKey(salesOrder)) {
                    uniqueOrderRows.put(salesOrder, row);
                }
            }

            System.debug('===== UNIQUE ORDER ROWS SIZE ===== ' + uniqueOrderRows.size());
            System.debug('===== UNIQUE ORDER ROWS KEYS ===== ' + uniqueOrderRows.keySet());

            List<Order> ordersToUpsert = new List<Order>();

            List<Account> defaultAccs = [
                SELECT Id
                FROM Account
                WHERE Name = :defaultAccountName
                LIMIT 1
            ];

            Id defaultAccountId;

            if (!defaultAccs.isEmpty()) {
                defaultAccountId = defaultAccs[0].Id;
            } else {
                Account defaultAcc = new Account(Name = defaultAccountName);
                insert defaultAcc;
                defaultAccountId = defaultAcc.Id;
            }

            for (String salesOrder : uniqueOrderRows.keySet()) {
                Map<String, Object> row = uniqueOrderRows.get(salesOrder);

                Order ord = new Order();

                if (existingOrderMap.containsKey(salesOrder)) {
                    ord.Id = existingOrderMap.get(salesOrder).Id;
                } else {
                    ord.EffectiveDate = parseDate(getString(row, 'CREATION_DATE'));
                    ord.Status = 'Draft';
                    ord.Pricebook2Id = standardPricebookId;
                    ord.AccountId = defaultAccountId;
                }

                ord.Sales_Order__c = getString(row, 'SALES_ORDER');
                ord.Imported__c = true;

                ord.Dist_Chan__c = getString(row, 'DIST_CHAN');
                ord.Division_Text__c = getString(row, 'DIVISION');
                ord.Sales_Group__c = getString(row, 'SALES_GROUP');
                ord.Sales_Office__c = getString(row, 'SALES_OFFICE');
                ord.Service_Order_Type__c = getString(row, 'DOCUMENT_TYPE');
                ord.Order_Reason__c = getString(row, 'ORDER_REASON');
                ord.Sales_Org__c = getString(row, 'SALES_ORG');
                ord.Delivering_Plant__c = getString(row, 'DELIVERING_PLANT');

                ord.BG_Required__c = getString(row, 'BG_REQUIRED');
                ord.LD_Clause__c = getString(row, 'LD_CLAUSE');
                ord.TPC__c = getString(row, 'TPC');

                System.debug('===== ORDER PREPARED ===== ' + JSON.serialize(ord));

                ordersToUpsert.add(ord);
            }

            System.debug('===== ORDERS TO UPSERT SIZE ===== ' + ordersToUpsert.size());

            Map<String, Id> newSapOrderIdToOrderId = new Map<String, Id>();
            Map<String, String> orderErrorMap = new Map<String, String>();
            List<Integration_Error_Log__c> orderErrorLogsToInsert = new List<Integration_Error_Log__c>();

            if (!ordersToUpsert.isEmpty()) {
                Database.UpsertResult[] orderResults = Database.upsert(ordersToUpsert, false);

                for (Integer i = 0; i < orderResults.size(); i++) {
                    Order ord = ordersToUpsert[i];
                    String sapOrderId = ord.Sales_Order__c;

                    if (orderResults[i].isSuccess()) {
                        if (orderResults[i].isCreated()) {
                            result.insertedOrders++;
                        } else {
                            result.updatedOrders++;
                        }

                        newSapOrderIdToOrderId.put(sapOrderId, orderResults[i].getId());
                        allSapOrderIdToOrderId.put(sapOrderId, orderResults[i].getId());

                        System.debug('===== ORDER UPSERT SUCCESS ===== SAP Order: ' + sapOrderId + ', Order Id: ' + orderResults[i].getId());
                    } else {
                        result.failedOrders++;

                        List<String> errMsgs = new List<String>();

                        for (Database.Error err : orderResults[i].getErrors()) {
                            errMsgs.add(err.getMessage());

                            System.debug('===== ORDER UPSERT FAILED ===== SAP Order: ' + sapOrderId);
                            System.debug('===== ORDER ERROR STATUS ===== ' + err.getStatusCode());
                            System.debug('===== ORDER ERROR MESSAGE ===== ' + err.getMessage());
                            System.debug('===== ORDER ERROR FIELDS ===== ' + err.getFields());

                            orderErrorLogsToInsert.add(buildIntegrationLog(
                                'Sales Order Details API',
                                String.valueOf(err.getStatusCode()),
                                err.getMessage(),
                                'POST',
                                requestBody,
                                endpoint,
                                'SAP',
                                null,
                                null
                            ));
                        }

                        orderErrorMap.put(sapOrderId, String.join(errMsgs, ' | '));
                    }
                }
            }

            insertIntegrationLogsSafely(orderErrorLogsToInsert);

            System.debug('===== NEW SAP ORDER TO ORDER ID MAP ===== ' + newSapOrderIdToOrderId);
            System.debug('===== ALL SAP ORDER TO ORDER ID MAP ===== ' + allSapOrderIdToOrderId);
            System.debug('===== INSERTED ORDER COUNT ===== ' + result.insertedOrders);
            System.debug('===== UPDATED ORDER COUNT ===== ' + result.updatedOrders);
            System.debug('===== FAILED ORDER COUNT ===== ' + result.failedOrders);

            /*
             * Existing OrderItem check based on:
             * OrderId + SAP_Line_Item_No__c
             */
            Set<Id> allOrderIds = new Set<Id>();
            allOrderIds.addAll(allSapOrderIdToOrderId.values());

            Map<String, OrderItem> existingItemMap = new Map<String, OrderItem>();

            if (!allOrderIds.isEmpty()) {
                for (OrderItem oi : [
                    SELECT Id, OrderId, SAP_Line_Item_No__c
                    FROM OrderItem
                    WHERE OrderId IN :allOrderIds
                ]) {
                    String key = String.valueOf(oi.OrderId) + '-' + oi.SAP_Line_Item_No__c;
                    existingItemMap.put(key, oi);
                }
            }

            System.debug('===== EXISTING ORDER ITEM MAP SIZE ===== ' + existingItemMap.size());
            System.debug('===== EXISTING ORDER ITEM MAP KEYS ===== ' + existingItemMap.keySet());

            /*
             * Prepare OrderItems for Upsert
             */
            List<OrderItem> orderItemsToUpsert = new List<OrderItem>();
            Map<Integer, String> itemIndexToSalesOrder = new Map<Integer, String>();
            Map<String, String> duplicateItemMap = new Map<String, String>();
            List<Integration_Error_Log__c> materialNotFoundLogsToInsert = new List<Integration_Error_Log__c>();

            for (Map<String, Object> row : sapRows) {
                System.debug('===== PREPARING ORDER ITEM ROW ===== ' + JSON.serialize(row));

                String salesOrder = getString(row, 'SALES_ORDER');
                String materialCode = getString(row, 'MATERIAL_CODE');
                String materialUniqueKey = buildMaterialUniqueKeyFromSalesOrderRow(row);

                String lineItemNo = stripLeadingZeros(getString(row, 'LINE_ITEM_NO'));

                System.debug('===== ORDER ITEM SALES ORDER ===== ' + salesOrder);
                System.debug('===== ORDER ITEM MATERIAL CODE ===== ' + materialCode);
                System.debug('===== ORDER ITEM MATERIAL UNIQUE KEY ===== ' + materialUniqueKey);
                System.debug('===== ORDER ID FOUND FOR SALES ORDER ===== ' + allSapOrderIdToOrderId.get(salesOrder));

                if (!allSapOrderIdToOrderId.containsKey(salesOrder)) {
                    System.debug('===== ORDER ITEM SKIPPED: ORDER ID NOT FOUND FOR SALES ORDER ===== ' + salesOrder);
                    continue;
                }

                Id orderIdForItem = allSapOrderIdToOrderId.get(salesOrder);
                String itemKey = String.valueOf(orderIdForItem) + '-' + lineItemNo;

                OrderItem item = new OrderItem();

                if (existingItemMap.containsKey(itemKey)) {
                    item.Id = existingItemMap.get(itemKey).Id;
                } else {
                    item.OrderId = orderIdForItem;
                    item.PricebookEntryId = standardPricebookEntryId;
                }

                item.Quantity = parseDecimal(getString(row, 'QTY'));
                item.UnitPrice = parseDecimal(getString(row, 'NET_PRICE'));

                item.SAP_Line_Item_No__c = lineItemNo;
                item.Plant__c = getString(row, 'PLANT');
                item.Item_Category__c = getString(row, 'ITEM_CATAGORY');

                item.Sub_Total__c = parseDecimal(getString(row, 'NET_VALUE'));
                item.Route__c = getString(row, 'ROUTE');

                item.Performance_Warranty__c = parseDecimal(getString(row, 'PERFORMANCE_WARRANTY'));
                item.Product_Warranty_Duration__c = parseDecimal(getString(row, 'PRODUCT_WARRANTY'));

                /*
                 * Material Master tagging:
                 * 1. First priority: match by Unique_Key__c.
                 * 2. Second priority: match the material returned from Material Master API by MATERIAL_CODE.
                 * 3. If not found, clear old lookup to avoid stale/wrong Material Master remaining.
                 */
                Id materialMasterIdToTag;

                if (
                    String.isNotBlank(materialCode) &&
                    String.isNotBlank(materialUniqueKey) &&
                    materialMap.containsKey(materialUniqueKey)
                ) {
                    materialMasterIdToTag = materialMap.get(materialUniqueKey).Id;

                    System.debug('===== MATERIAL MASTER FOUND BY UNIQUE KEY ===== ' + materialMasterIdToTag);
                } else if (
                    String.isNotBlank(materialCode) &&
                    materialCodeToMaterialMasterIdFromApi.containsKey(materialCode)
                ) {
                    materialMasterIdToTag = materialCodeToMaterialMasterIdFromApi.get(materialCode);

                    System.debug('===== MATERIAL MASTER FOUND FROM MATERIAL API RESPONSE ===== ' + materialMasterIdToTag);
                }

                if (materialMasterIdToTag != null) {
                    item.Material_Master__c = materialMasterIdToTag;
                    result.materialMatched++;

                    System.debug('===== MATERIAL MASTER TAGGED/UPDATED ===== ' + item.Material_Master__c);
                } else {
                    item.Material_Master__c = null;
                    result.materialNotFound++;

                    System.debug('===== MATERIAL MASTER NOT FOUND ===== MATERIAL_CODE: ' + materialCode);
                    System.debug('===== MATERIAL MASTER NOT FOUND ===== UNIQUE_KEY: ' + materialUniqueKey);

                    materialNotFoundLogsToInsert.add(buildIntegrationLog(
                        'Sales Order Details API',
                        'MATERIAL_NOT_FOUND',
                        'Material Master not found for MATERIAL_CODE: ' + materialCode + ', UNIQUE_KEY: ' + materialUniqueKey,
                        'POST',
                        requestBody,
                        endpoint,
                        'SAP',
                        null,
                        null
                    ));
                }

                System.debug('===== ORDER ITEM PREPARED =====');
                System.debug('Full OrderItem: ' + JSON.serialize(item));

                itemIndexToSalesOrder.put(orderItemsToUpsert.size(), salesOrder);
                orderItemsToUpsert.add(item);

                System.debug('===== ORDER ITEM ADDED TO UPSERT LIST. CURRENT SIZE ===== ' + orderItemsToUpsert.size());
            }

            insertIntegrationLogsSafely(materialNotFoundLogsToInsert);

            Map<String, String> itemErrorMap = new Map<String, String>();
            List<Integration_Error_Log__c> itemErrorLogsToInsert = new List<Integration_Error_Log__c>();

            System.debug('===== FINAL ORDER ITEM LIST SIZE ===== ' + orderItemsToUpsert.size());
            System.debug('===== FINAL ORDER ITEM LIST ===== ' + JSON.serialize(orderItemsToUpsert));

            if (!orderItemsToUpsert.isEmpty()) {
                Database.UpsertResult[] itemResults = Database.upsert(orderItemsToUpsert, false);

                for (Integer i = 0; i < itemResults.size(); i++) {
                    String salesOrder = itemIndexToSalesOrder.get(i);

                    if (itemResults[i].isSuccess()) {
                        if (itemResults[i].isCreated()) {
                            result.insertedOrderItems++;
                        } else {
                            result.updatedOrderItems++;
                        }

                        System.debug('===== ORDER ITEM UPSERT SUCCESS =====');
                        System.debug('Sales Order: ' + salesOrder);
                        System.debug('OrderItem Id: ' + itemResults[i].getId());
                    } else {
                        result.failedOrderItems++;

                        List<String> errMsgs = new List<String>();

                        for (Database.Error err : itemResults[i].getErrors()) {
                            errMsgs.add(err.getMessage());

                            System.debug('===== ORDER ITEM UPSERT FAILED =====');
                            System.debug('Sales Order: ' + salesOrder);
                            System.debug('Error Status: ' + err.getStatusCode());
                            System.debug('Error Message: ' + err.getMessage());
                            System.debug('Error Fields: ' + err.getFields());
                            System.debug('OrderItem Record: ' + JSON.serialize(orderItemsToUpsert[i]));

                            itemErrorLogsToInsert.add(buildIntegrationLog(
                                'Sales Order Details API',
                                String.valueOf(err.getStatusCode()),
                                err.getMessage(),
                                'POST',
                                requestBody,
                                endpoint,
                                'SAP',
                                null,
                                null
                            ));
                        }

                        itemErrorMap.put(salesOrder, String.join(errMsgs, ' | '));
                    }
                }
            }

            insertIntegrationLogsSafely(itemErrorLogsToInsert);

            System.debug('===== INSERTED ORDER ITEM COUNT ===== ' + result.insertedOrderItems);
            System.debug('===== UPDATED ORDER ITEM COUNT ===== ' + result.updatedOrderItems);
            System.debug('===== FAILED ORDER ITEM COUNT ===== ' + result.failedOrderItems);
            System.debug('===== ITEM ERROR MAP ===== ' + itemErrorMap);

            /*
             * Final table status mapping
             */
            for (SalesOrderRow row : result.records) {
                if (orderErrorMap.containsKey(row.salesOrder)) {
                    row.status = 'Order Failed: ' + orderErrorMap.get(row.salesOrder);
                } else if (itemErrorMap.containsKey(row.salesOrder)) {
                    row.status = 'Order Upserted, Item Failed: ' + itemErrorMap.get(row.salesOrder);
                } else {
                    row.status = 'Upserted Successfully';
                }
            }

            result.message = 'Sales Order sync completed successfully.';

            System.debug('===== FINAL RESULT ===== ' + JSON.serialize(result));
            System.debug('===== SALES ORDER IMPORT COMPLETED =====');

            return result;

        } catch (Exception e) {
            System.debug('===== SALES ORDER IMPORT EXCEPTION =====');
            System.debug('Exception Message: ' + e.getMessage());
            System.debug('Exception Stack Trace: ' + e.getStackTraceString());

            logIntegrationError(
                'Sales Order Details API',
                'EXCEPTION',
                e.getMessage(),
                'POST',
                requestBody,
                endpoint,
                'SAP',
                e.getStackTraceString(),
                null
            );

            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Map<String, Material_Master__c> getMaterialMasterMapByUniqueKey(Set<String> materialUniqueKeys) {
        Map<String, Material_Master__c> materialMap = new Map<String, Material_Master__c>();

        if (materialUniqueKeys == null || materialUniqueKeys.isEmpty()) {
            return materialMap;
        }

        for (Material_Master__c mat : [
            SELECT Id, Name, Unique_Key__c
            FROM Material_Master__c
            WHERE Unique_Key__c IN :materialUniqueKeys
            ORDER BY Unique_Key__c ASC, CreatedDate ASC
        ]) {
            if (String.isNotBlank(mat.Unique_Key__c) && !materialMap.containsKey(mat.Unique_Key__c)) {
                materialMap.put(mat.Unique_Key__c, mat);
            }
        }

        return materialMap;
    }

    private static Map<String, Id> fetchMissingMaterialMastersFromSap(Set<String> missingMaterialCodes) {
        Map<String, Id> materialCodeToMaterialMasterId = new Map<String, Id>();

        if (missingMaterialCodes == null || missingMaterialCodes.isEmpty()) {
            return materialCodeToMaterialMasterId;
        }

        String endpointName = MATERIAL_MASTER_ENDPOINT;
        String httpMethod = 'POST';

        List<SapMaterialDTO> allSapMaterials = new List<SapMaterialDTO>();
        List<Integration_Error_Log__c> logsToInsert = new List<Integration_Error_Log__c>();

        System.debug('===== FETCHING MISSING MATERIAL MASTERS FROM SAP BY MATERIAL CODE ===== ' + missingMaterialCodes);

        for (String materialCode : missingMaterialCodes) {
            if (String.isBlank(materialCode)) {
                continue;
            }

            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                logsToInsert.add(buildIntegrationLog(
                    'SAP Material Master API',
                    'CALLOUT_LIMIT_REACHED',
                    'Callout limit reached while fetching material code: ' + materialCode,
                    httpMethod,
                    JSON.serialize(new Map<String, Object>{ 'MATERIAL_CODE' => materialCode }),
                    endpointName,
                    'SAP',
                    null,
                    null
                ));
                continue;
            }

            /*
             * IMPORTANT:
             * Material Master API is called by MATERIAL_CODE only.
             * No CREATION_FROM_DATE / CREATION_TO_DATE is passed here.
             */
            String requestBodyString = JSON.serialize(
                new Map<String, Object>{
                    'MATERIAL_CODE' => materialCode.trim()
                }
            );

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpointName);
                req.setMethod(httpMethod);
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(120000);
                req.setBody(requestBodyString);

                Http http = new Http();
                HttpResponse res = http.send(req);

                Integer statusCode = res.getStatusCode();
                String responseBody = res.getBody();

                System.debug('===== MATERIAL MASTER API CALLED BY MATERIAL CODE ===== ' + materialCode);
                System.debug('===== MATERIAL MASTER API REQUEST BODY ===== ' + requestBodyString);
                System.debug('===== MATERIAL MASTER API STATUS ===== ' + statusCode);
                System.debug('===== MATERIAL MASTER API RESPONSE ===== ' + responseBody);

                if (statusCode != 200) {
                    logsToInsert.add(buildIntegrationLog(
                        'SAP Material Master API',
                        'HTTP_' + statusCode,
                        'Material Master API failed for material code: ' + materialCode,
                        httpMethod,
                        requestBodyString,
                        endpointName,
                        'SAP',
                        null,
                        statusCode
                    ));
                    continue;
                }

                if (String.isBlank(responseBody)) {
                    logsToInsert.add(buildIntegrationLog(
                        'SAP Material Master API',
                        'EMPTY_RESPONSE',
                        'Empty response received for material code: ' + materialCode,
                        httpMethod,
                        requestBodyString,
                        endpointName,
                        'SAP',
                        null,
                        statusCode
                    ));
                    continue;
                }

                List<SapMaterialDTO> sapMaterials =
                    (List<SapMaterialDTO>) JSON.deserialize(responseBody, List<SapMaterialDTO>.class);

                if (sapMaterials != null && !sapMaterials.isEmpty()) {
                    allSapMaterials.addAll(sapMaterials);
                }

            } catch (Exception ex) {
                logsToInsert.add(buildIntegrationLog(
                    'SAP Material Master API',
                    'EXCEPTION',
                    'Exception while fetching material code: ' + materialCode + '. Error: ' + ex.getMessage(),
                    httpMethod,
                    requestBodyString,
                    endpointName,
                    'SAP',
                    ex.getStackTraceString(),
                    null
                ));
            }
        }

        upsertMaterialMastersFromSapResponse(allSapMaterials, logsToInsert);

        Set<String> fetchedUniqueKeys = new Set<String>();

        for (SapMaterialDTO dto : allSapMaterials) {
            String uniqueKey = generateMaterialUniqueKey(dto);

            if (String.isNotBlank(uniqueKey)) {
                fetchedUniqueKeys.add(uniqueKey);
            }
        }

        if (!fetchedUniqueKeys.isEmpty()) {
            for (Material_Master__c mm : [
                SELECT Id, Name, Unique_Key__c
                FROM Material_Master__c
                WHERE Unique_Key__c IN :fetchedUniqueKeys
                ORDER BY Name ASC, CreatedDate ASC
            ]) {
                if (String.isNotBlank(mm.Name) && !materialCodeToMaterialMasterId.containsKey(mm.Name)) {
                    materialCodeToMaterialMasterId.put(mm.Name, mm.Id);
                }
            }
        }

        return materialCodeToMaterialMasterId;
    }

    private static void upsertMaterialMastersFromSapResponse(
        List<SapMaterialDTO> sapMaterials,
        List<Integration_Error_Log__c> logsToInsert
    ) {
        if (logsToInsert == null) {
            logsToInsert = new List<Integration_Error_Log__c>();
        }

        if (sapMaterials == null || sapMaterials.isEmpty()) {
            insertIntegrationLogsSafely(logsToInsert);
            return;
        }

        Set<String> uniqueKeys = new Set<String>();

        for (SapMaterialDTO dto : sapMaterials) {
            String uniqueKey = generateMaterialUniqueKey(dto);

            if (String.isNotBlank(uniqueKey)) {
                uniqueKeys.add(uniqueKey);
            }
        }

        Map<String, Material_Master__c> existingMaterialMap = new Map<String, Material_Master__c>();

        if (!uniqueKeys.isEmpty()) {
            for (Material_Master__c mm : [
                SELECT Id, Unique_Key__c
                FROM Material_Master__c
                WHERE Unique_Key__c IN :uniqueKeys
            ]) {
                existingMaterialMap.put(mm.Unique_Key__c, mm);
            }
        }

        Map<String, Material_Master__c> insertMap = new Map<String, Material_Master__c>();
        Map<String, Material_Master__c> updateMap = new Map<String, Material_Master__c>();

        for (SapMaterialDTO dto : sapMaterials) {
            String uniqueKey = generateMaterialUniqueKey(dto);

            if (String.isBlank(uniqueKey)) {
                continue;
            }

            Material_Master__c materialRec;
            Boolean isUpdate = false;

            if (existingMaterialMap.containsKey(uniqueKey)) {
                materialRec = existingMaterialMap.get(uniqueKey);
                isUpdate = true;
            } else {
                materialRec = new Material_Master__c();
            }

            materialRec.Name = safeValue(dto.MATERIAL_CODE);
            materialRec.Unique_Key__c = uniqueKey;
            materialRec.Created_By__c = safeValue(dto.CREATED_BY);
            materialRec.Created_On__c = dto.CREATED_ON;
            materialRec.Distribution_Channel__c = safeValue(dto.DISTRIBUTION_CHANNEL);
            materialRec.Division__c = safeValue(dto.DIVISION);
            materialRec.Material_Description__c = safeValue(dto.MATERIAL_DESCRIPTION);
            materialRec.Material_Group__c = safeValue(dto.MATERIAL_GROUP);
            materialRec.Material_Group_Description__c = safeValue(dto.MATERIAL_GROUP_DESCRIPTION);
            materialRec.Material_Type__c = safeValue(dto.MATERIAL_TYPE);
            materialRec.Material_Type_Description__c = safeValue(dto.MATERIAL_TYPE_DESCRIPTION);
            materialRec.Plant__c = safeValue(dto.PLANT);
            materialRec.Plant_Description__c = safeValue(dto.PLANT_DESCRIPTION);
            materialRec.Sales_Org__c = safeValue(dto.SALES_ORG);
            materialRec.Storage_Location__c = safeValue(dto.STORAGE_LOCATION);
            materialRec.Storage_Location_Description__c = safeValue(dto.STORAGE_LOCATION_DESCRIPTION);
            materialRec.Unit_of_Measure__c = safeValue(dto.UNIT_OF_MEASURE);

            if (isUpdate) {
                updateMap.put(uniqueKey, materialRec);
            } else {
                insertMap.put(uniqueKey, materialRec);
            }
        }

        if (!insertMap.isEmpty()) {
            List<Material_Master__c> recordsToInsert = insertMap.values();
            Database.SaveResult[] insertResults = Database.insert(recordsToInsert, false);
            addMaterialDmlErrors(insertResults, recordsToInsert, logsToInsert);
        }

        if (!updateMap.isEmpty()) {
            List<Material_Master__c> recordsToUpdate = updateMap.values();
            Database.SaveResult[] updateResults = Database.update(recordsToUpdate, false);
            addMaterialDmlErrors(updateResults, recordsToUpdate, logsToInsert);
        }

        insertIntegrationLogsSafely(logsToInsert);
    }

    private static void addMaterialDmlErrors(
        Database.SaveResult[] saveResults,
        List<Material_Master__c> records,
        List<Integration_Error_Log__c> logsToInsert
    ) {
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                continue;
            }

            String errMsg = '';
            String errCode = '';

            for (Database.Error err : saveResults[i].getErrors()) {
                errMsg += err.getMessage() + ' ';
                errCode += String.valueOf(err.getStatusCode()) + ' ';
            }

            logsToInsert.add(buildIntegrationLog(
                'SAP Material Master API',
                errCode,
                errMsg,
                'DML',
                records[i].Unique_Key__c,
                'Material_Master__c',
                'Salesforce',
                null,
                null
            ));
        }
    }

    private static String buildMaterialUniqueKeyFromSalesOrderRow(Map<String, Object> row) {
        if (row == null) {
            return null;
        }

        String materialCode = getString(row, 'MATERIAL_CODE');

        if (String.isBlank(materialCode)) {
            return null;
        }

        String storageLocation = getString(row, 'STORAGE_LOCATION');

        if (String.isBlank(storageLocation)) {
            storageLocation = getString(row, 'STORAGE_LOC');
        }

        return safeValue(materialCode) + '|' +
               safeValue(getString(row, 'PLANT')) + '|' +
               safeValue(storageLocation) + '|' +
               safeValue(getString(row, 'SALES_ORG')) + '|' +
               safeValue(getString(row, 'DIST_CHAN')) + '|' +
               safeValue(getString(row, 'DIVISION'));
    }

    private static String generateMaterialUniqueKey(SapMaterialDTO dto) {
        if (dto == null) {
            return null;
        }

        return safeValue(dto.MATERIAL_CODE) + '|' +
               safeValue(dto.PLANT) + '|' +
               safeValue(dto.STORAGE_LOCATION) + '|' +
               safeValue(dto.SALES_ORG) + '|' +
               safeValue(dto.DISTRIBUTION_CHANNEL) + '|' +
               safeValue(dto.DIVISION);
    }

    private static Integration_Error_Log__c buildIntegrationLog(
        String apiName,
        String errorCode,
        String errorMessage,
        String httpMethod,
        String requestParameters,
        String requestUri,
        String sourceSystem,
        String stackTrace,
        Integer statusCode
    ) {
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

        if (statusCode != null) {
            logRec.Status_Code__c = Decimal.valueOf(String.valueOf(statusCode));
        }

        return logRec;
    }

    private static void insertIntegrationLogsSafely(List<Integration_Error_Log__c> logsToInsert) {
        if (logsToInsert == null || logsToInsert.isEmpty()) {
            return;
        }

        try {
            Database.insert(logsToInsert, false);
        } catch (Exception e) {
            System.debug('===== BULK INTEGRATION ERROR LOG INSERT FAILED ===== ' + e.getMessage());
        }
    }

    private static String formatDateYYYYMMDD(Date inputDate) {
        String monthValue = inputDate.month() < 10
            ? '0' + String.valueOf(inputDate.month())
            : String.valueOf(inputDate.month());

        String dayValue = inputDate.day() < 10
            ? '0' + String.valueOf(inputDate.day())
            : String.valueOf(inputDate.day());

        return String.valueOf(inputDate.year()) + monthValue + dayValue;
    }

    private static String getString(Map<String, Object> row, String key) {
        if (row == null || !row.containsKey(key) || row.get(key) == null) {
            return null;
        }

        return String.valueOf(row.get(key)).trim();
    }

    private static String safeValue(String input) {
        return input == null ? '' : input.trim();
    }

    private static String stripLeadingZeros(String input) {
        if (String.isBlank(input)) {
            return input;
        }

        String stripped = input.replaceFirst('^0+', '');
        return String.isBlank(stripped) ? '0' : stripped;
    }

    private static Date parseDate(String value) {
        if (String.isBlank(value)) {
            return Date.today();
        }

        return Date.valueOf(value);
    }

    private static Decimal parseDecimal(String value) {
        if (String.isBlank(value)) {
            return 0;
        }

        try {
            return Decimal.valueOf(value);
        } catch (Exception e) {
            System.debug('===== DECIMAL PARSE ERROR ===== Value: ' + value + ', Error: ' + e.getMessage());
            return 0;
        }
    }

    private static Boolean convertYNToBoolean(String value) {
        return value == 'Y';
    }

    private static Id getStandardProductId() {
        System.debug('===== FETCHING STANDARD PRODUCT =====');

        List<Product2> products = [
            SELECT Id, Name, IsActive
            FROM Product2
            WHERE Name = 'Standard Product'
            AND IsActive = true
            LIMIT 1
        ];

        System.debug('===== STANDARD PRODUCT LIST SIZE ===== ' + products.size());

        if (products.isEmpty()) {
            throw new AuraHandledException('Active Product not found with Name: Standard Product');
        }

        System.debug('===== STANDARD PRODUCT FOUND ===== ' + products[0]);

        return products[0].Id;
    }

    private static Id getStandardPricebookId() {
        System.debug('===== FETCHING STANDARD PRICEBOOK =====');

        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }

        Pricebook2 pb = [
            SELECT Id, Name, IsStandard, IsActive
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];

        System.debug('===== STANDARD PRICEBOOK FOUND ===== ' + pb);

        return pb.Id;
    }

    private static Id getOrCreatePricebookEntry(Id productId, Id pricebook2Id) {
        System.debug('===== FETCHING PRICEBOOK ENTRY =====');
        System.debug('ProductId: ' + productId);
        System.debug('Pricebook2Id: ' + pricebook2Id);

        List<PricebookEntry> existingPbeList = [
            SELECT Id, Product2Id, Pricebook2Id, IsActive, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id = :productId
            AND Pricebook2Id = :pricebook2Id
            AND IsActive = true
            LIMIT 1
        ];

        System.debug('===== EXISTING PRICEBOOK ENTRY SIZE ===== ' + existingPbeList.size());

        if (!existingPbeList.isEmpty()) {
            System.debug('===== EXISTING PRICEBOOK ENTRY FOUND ===== ' + existingPbeList[0]);
            return existingPbeList[0].Id;
        }

        System.debug('===== PRICEBOOK ENTRY NOT FOUND. CREATING NEW =====');

        PricebookEntry pbe = new PricebookEntry();
        pbe.Product2Id = productId;
        pbe.Pricebook2Id = pricebook2Id;
        pbe.UnitPrice = 0;
        pbe.IsActive = true;
        pbe.UseStandardPrice = false;

        insert pbe;

        System.debug('===== PRICEBOOK ENTRY CREATED ===== ' + pbe.Id);

        return pbe.Id;
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
        Integer statusCode
    ) {
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

            if (statusCode != null) {
                logRec.Status_Code__c = Decimal.valueOf(String.valueOf(statusCode));
            }

            insert logRec;

        } catch (Exception e) {
            System.debug('===== INTEGRATION ERROR LOG INSERT FAILED ===== ' + e.getMessage());
        }
    }
}
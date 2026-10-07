public with sharing class Ctrl_CreateProductRequestLineItem {

    // =========================================================
    // DTO WRAPPERS
    // =========================================================
    public class ProductRequestDefaults {
        @AuraEnabled public Id parentId;
        @AuraEnabled public String parentName;
        @AuraEnabled public Datetime expectedDeliveryDate;
        @AuraEnabled public Id destinationLocationId;
        @AuraEnabled public String destinationLocationName;
        @AuraEnabled public String shipToStreet;
        @AuraEnabled public String shipToCity;
        @AuraEnabled public String shipToState;
        @AuraEnabled public String shipToPostalCode;
        @AuraEnabled public String shipToCountry;
        @AuraEnabled public String fullShipToAddress;
    }

    public class MaterialMasterOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String materialCode;
        @AuraEnabled public String plant;
        @AuraEnabled public String distributionChannel;
        @AuraEnabled public String division;
        @AuraEnabled public String materialType;
        @AuraEnabled public String materialDescription;

        public MaterialMasterOption(Material_Master__c material) {
            this.id = material.Id;
            this.materialCode = material.Name;
            this.plant = material.Plant__c;
            this.distributionChannel = material.Distribution_Channel__c;
            this.division = material.Division__c;
            this.materialType = material.Material_Type__c;
            this.materialDescription = material.Material_Description__c;
        }
    }

    public class LocationOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;

        public LocationOption(Id locationId, String locationName) {
            this.id = locationId;
            this.name = locationName;
        }
    }

    public class LineItemInput {
		@AuraEnabled public Id materialMasterId { get; set; }
		@AuraEnabled public Decimal quantityRequested { get; set; }
		@AuraEnabled public String quantityUnitOfMeasure { get; set; }
		@AuraEnabled public Decimal price { get; set; }
		@AuraEnabled public Id sourceLocationId { get; set; }
		@AuraEnabled public String shipmentType { get; set; }
	}

    // =========================================================
    // GET PRODUCT REQUEST DETAILS
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static ProductRequestDefaults getProductRequestDetails(Id productRequestId) {
        if (productRequestId == null) {
            throw new AuraHandledException('Product Request Id is required.');
        }

        ProductRequest requestRecord = [
            SELECT
                Id,
                ProductRequestNumber,
                NeedByDate,
                DestinationLocationId,
                DestinationLocation.Name,
                ShipToAddress
            FROM ProductRequest
            WHERE Id = :productRequestId
            LIMIT 1
        ];

        ProductRequestDefaults result = new ProductRequestDefaults();
        result.parentId = requestRecord.Id;
        result.parentName = requestRecord.ProductRequestNumber;
        result.expectedDeliveryDate = requestRecord.NeedByDate;
        result.destinationLocationId = requestRecord.DestinationLocationId;

        if (requestRecord.DestinationLocation != null) {
            result.destinationLocationName = requestRecord.DestinationLocation.Name;
        }

        System.Address shipToAddress = (System.Address) requestRecord.get('ShipToAddress');
        if (shipToAddress != null) {
            result.shipToStreet = shipToAddress.getStreet();
            result.shipToCity = shipToAddress.getCity();
            result.shipToState = shipToAddress.getState();
            result.shipToPostalCode = shipToAddress.getPostalCode();
            result.shipToCountry = shipToAddress.getCountry();
        }

        return result;
    }

    // =========================================================
    // SEARCH MATERIAL MASTER
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static List<MaterialMasterOption> searchMaterialMasters(String searchTerm) {
        List<MaterialMasterOption> results = new List<MaterialMasterOption>();
        if (String.isBlank(searchTerm)) {
            return results;
        }

        String searchValue = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        List<Material_Master__c> materials = [
            SELECT
                Id,
                Name,
                Plant__c,
                Distribution_Channel__c,
                Division__c,
                Material_Type__c,
                Material_Description__c
            FROM Material_Master__c
            WHERE Name LIKE :searchValue
               OR Plant__c LIKE :searchValue
            ORDER BY Name
            LIMIT 50
        ];

        for (Material_Master__c material : materials) {
            results.add(new MaterialMasterOption(material));
        }

        return results;
    }

    // =========================================================
    // SEARCH LOCATION (Dynamic SOQL to prevent System.Location collision)
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static List<LocationOption> searchLocations(String searchTerm) {
        List<LocationOption> results = new List<LocationOption>();
        if (String.isBlank(searchTerm)) {
            return results;
        }

        String searchValue = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        String query = 'SELECT Id, Name FROM Location WHERE Name LIKE :searchValue ORDER BY Name LIMIT 50';

        List<SObject> locations = Database.query(query);
        for (SObject locationRecord : locations) {
            results.add(new LocationOption(
                (Id) locationRecord.get('Id'),
                (String) locationRecord.get('Name')
            ));
        }

        return results;
    }

    // =========================================================
    // BULK CREATE LINE ITEMS
    // =========================================================
    @AuraEnabled
    public static List<Id> createLineItems(Id productRequestId, List<LineItemInput> inputItems) {
        if (productRequestId == null) {
            throw new AuraHandledException('Product Request Id is required.');
        }

        if (inputItems == null || inputItems.isEmpty()) {
            throw new AuraHandledException('Please add at least one line item.');
        }

        // Re-query parent record to securely inherit field values
        ProductRequest requestRecord = [
            SELECT
                Id,
                NeedByDate,
                DestinationLocationId,
                ShipToAddress
            FROM ProductRequest
            WHERE Id = :productRequestId
            LIMIT 1
        ];

        System.Address parentAddress = (System.Address) requestRecord.get('ShipToAddress');
        List<ProductRequestLineItem> lineItems = new List<ProductRequestLineItem>();
        Integer rowNumber = 0;

        for (LineItemInput item : inputItems) {
            rowNumber++;

            if (item.quantityRequested == null || item.quantityRequested <= 0) {
                throw new AuraHandledException('Quantity Requested must be greater than zero for row ' + rowNumber + '.');
            }
            if (item.materialMasterId == null) {
                throw new AuraHandledException('Material Master is required for row ' + rowNumber + '.');
            }
            if (String.isBlank(item.quantityUnitOfMeasure)) {
                throw new AuraHandledException('Quantity Unit Of Measure is required for row ' + rowNumber + '.');
            }

            ProductRequestLineItem lineItem = new ProductRequestLineItem();

            // Auto-populated values from Parent Product Request
            lineItem.ParentId = requestRecord.Id;
            lineItem.NeedByDate = requestRecord.NeedByDate;
            lineItem.DestinationLocationId = requestRecord.DestinationLocationId;

            if (parentAddress != null) {
                lineItem.ShipToStreet = parentAddress.getStreet();
                lineItem.ShipToCity = parentAddress.getCity();
                lineItem.ShipToState = parentAddress.getState();
                lineItem.ShipToPostalCode = parentAddress.getPostalCode();
                lineItem.ShipToCountry = parentAddress.getCountry();
            }

            // User input values
            lineItem.Material_Master__c = item.materialMasterId;
            lineItem.QuantityRequested = item.quantityRequested;
            lineItem.QuantityUnitOfMeasure = item.quantityUnitOfMeasure;

            if (item.price != null) {
                lineItem.Price__c = item.price;
            }
            if (item.sourceLocationId != null) {
                lineItem.SourceLocationId = item.sourceLocationId;
            }
            if (String.isNotBlank(item.shipmentType)) {
                lineItem.ShipmentType = item.shipmentType;
            }

            lineItems.add(lineItem);
        }

        insert lineItems;

        List<Id> createdIds = new List<Id>();
        for (ProductRequestLineItem lineItem : lineItems) {
            createdIds.add(lineItem.Id);
        }

        return createdIds;
    }
}
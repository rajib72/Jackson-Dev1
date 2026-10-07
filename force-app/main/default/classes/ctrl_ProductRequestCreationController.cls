/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_ProductRequestCreationController
 * Author          : <Amit>
 * Created Date    : Aug 25, 2026
 * Last Modified By: <Amit>
 * Last Modified On: Aug 25, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Aug 25, 2026  │ <Amit>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ctrl_ProductRequestCreationController {
    public class RecordTypeOption {
        @AuraEnabled public Id id {get; set;}
        @AuraEnabled public String label {get; set;}
        @AuraEnabled public String developerName {get; set;}
        public RecordTypeOption(Id id, String label, String developerName) {
            this.id = id;
            this.label = label;
            this.developerName = developerName;
        }
    }

    public class LocationOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        public LocationOption(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }

    public class ShipAddressOption {
        @AuraEnabled public Id workOrderLineItemId {get; set;}
        @AuraEnabled public Id assetId {get; set;}
        @AuraEnabled public String assetName {get; set;}
        @AuraEnabled public String siteName {get; set;}
        @AuraEnabled public String state {get; set;}
        @AuraEnabled public String street {get; set;}
        @AuraEnabled public String pinCode {get; set;}
        @AuraEnabled public String city {get; set;}
        @AuraEnabled public String country {get; set;}
        @AuraEnabled public String displayLabel {get; set;}
    }

    public class InitialData {
        @AuraEnabled public Id workOrderId {get; set;}
        @AuraEnabled public String workOrderNumber {get; set;}
        @AuraEnabled public List<RecordTypeOption> recordTypes {get; set;}
        @AuraEnabled public List<LocationOption> locations {get; set;}
        @AuraEnabled public List<ShipAddressOption> shipAddresses {get; set;}
        public InitialData() {
            recordTypes = new List<RecordTypeOption>();
            locations = new List<LocationOption>();
            shipAddresses = new List<ShipAddressOption>();
        }
    }

    public class ProductRequestInput {
        @AuraEnabled public Id workOrderId {get; set;}
        @AuraEnabled public Id recordTypeId {get; set;}
        @AuraEnabled public String requestType {get; set;}
        @AuraEnabled public Id destinationLocationId {get; set;}
        @AuraEnabled public String description {get; set;}
        @AuraEnabled public Datetime needByDate {get; set;}
        @AuraEnabled public Id workOrderLineItemId {get; set;}
        @AuraEnabled public Id assetId {get; set;}
        @AuraEnabled public String siteName {get; set;}
        @AuraEnabled public String state {get; set;}
        @AuraEnabled public String street {get; set;}
        @AuraEnabled public String pinCode {get; set;}
        @AuraEnabled public String city {get; set;}
        @AuraEnabled public String country {get; set;}
    }

    @AuraEnabled(cacheable=true)
    public static InitialData getInitialData(Id workOrderId) {
        if (workOrderId == null) throw new AuraHandledException('Work Order Id is required.');

        InitialData result = new InitialData();

        WorkOrder wo = [
            SELECT Id, WorkOrderNumber
            FROM WorkOrder
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        result.workOrderId = wo.Id;
        result.workOrderNumber = wo.WorkOrderNumber;

        for (RecordType rt : [
            SELECT Id, Name, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'ProductRequest'
            AND IsActive = true
            AND Name IN ('FOC', 'Paid', 'RGP')
            ORDER BY Name
        ]) {
            result.recordTypes.add(new RecordTypeOption(rt.Id, rt.Name, rt.DeveloperName));
        }

        for (SObject location : [
            SELECT Id, Name
            FROM Location
            ORDER BY Name
            LIMIT 5000
        ]) {
            result.locations.add(new LocationOption((Id)location.get('Id'), (String)location.get('Name')));
        }

        for (WorkOrderLineItem woli : [
            SELECT Id, WorkOrderId, AssetId,
                   Asset.Name,
                   Asset.Site_Name__c,
                   Asset.State__c,
                   Asset.Address__c,
                   Asset.Pin_Code__c,
                   Asset.City__c,
                   Asset.Country__c
            FROM WorkOrderLineItem
            WHERE WorkOrderId = :workOrderId
            AND AssetId != null
        ]) {
            if (woli.Asset == null) continue;

            ShipAddressOption address = new ShipAddressOption();
            address.workOrderLineItemId = woli.Id;
            address.assetId = woli.AssetId;
            address.assetName = woli.Asset.Name;
            address.siteName = woli.Asset.Site_Name__c;
            address.state = woli.Asset.State__c;
            address.street = woli.Asset.Address__c;
            address.pinCode = woli.Asset.Pin_Code__c;
            address.city = woli.Asset.City__c;
            address.country = woli.Asset.Country__c;
            address.displayLabel = buildAddressLabel(address);
            result.shipAddresses.add(address);
        }

        return result;
    }

    @AuraEnabled
    public static Id createProductRequest(ProductRequestInput input) {
        if (input == null) throw new AuraHandledException('Product Request information is required.');
		System.debug('requestType--- ' + input.requestType);
        if (String.isBlank(input.requestType)) throw new AuraHandledException('Product Request Type is required.');
        if (input.destinationLocationId == null) throw new AuraHandledException('Destination Location is required.');
        if (input.needByDate == null) throw new AuraHandledException('Final Expected Delivery Date is required.');
        if (input.workOrderLineItemId == null) throw new AuraHandledException('Ship To Address is required.');

        RecordType rt = [
            SELECT Id, Name, DeveloperName, IsActive
            FROM RecordType
            WHERE SObjectType = 'ProductRequest'
            AND Name = :input.requestType
            LIMIT 1
        ];

        if (!rt.IsActive) throw new AuraHandledException('Selected Record Type is inactive.');

        WorkOrderLineItem woli = [
            SELECT Id, WorkOrderId, AssetId
            FROM WorkOrderLineItem
            WHERE Id = :input.workOrderLineItemId
            LIMIT 1
        ];

        if (woli.WorkOrderId == null) throw new AuraHandledException('The selected Work Order Line Item is not associated with a Work Order.');
        if (woli.AssetId == null) throw new AuraHandledException('The selected Work Order Line Item does not have an Asset.');

        if (input.workOrderId != null && input.workOrderId != woli.WorkOrderId) {
            throw new AuraHandledException('The selected Ship To Address does not belong to the current Work Order.');
        }

        ProductRequest pr = new ProductRequest();
        pr.RecordTypeId = rt.Id;
        pr.WorkOrderId = woli.WorkOrderId;
        pr.Product_Request_Type__c = input.requestType;
        pr.Status = 'Draft';
        pr.DestinationLocationId = input.destinationLocationId;
        pr.Description = input.description;
        pr.NeedByDate = input.needByDate;

        if (input.requestType == 'FOC') {
            pr.FOC_Status__c = 'Draft';
        } else if (input.requestType == 'Paid') {
            pr.Paid_Status__c = 'Draft';
        } else if (input.requestType == 'RGP') {
            pr.RGP_Status__c = 'Draft';
        } else {
            throw new AuraHandledException('Unsupported Product Request Type: ' + input.requestType);
        }

        pr.Site_Name__c = input.siteName;
        pr.ShipToStreet = input.street;
        pr.ShipToCity = input.city;
        pr.ShipToState = input.state;
        pr.ShipToPostalCode = input.pinCode;
        pr.ShipToCountry = input.country;

		System.debug(LoggingLevel.ERROR, 'RecordTypeId--- ' + pr.RecordTypeId);
		System.debug(LoggingLevel.ERROR, 'RecordTypeName--- ' + rt.Name);
		System.debug(LoggingLevel.ERROR, 'ProductRequestType--- ' + pr.Product_Request_Type__c);
		System.debug(LoggingLevel.ERROR, 'WorkOrderId--- ' + pr.WorkOrderId);
		System.debug(LoggingLevel.ERROR, 'DestinationLocationId--- ' + pr.DestinationLocationId);

        insert pr;
        return pr.Id;
    }

    private static String buildAddressLabel(ShipAddressOption address) {
        List<String> parts = new List<String>();
        if (!String.isBlank(address.assetName)) parts.add(address.assetName);
        if (!String.isBlank(address.siteName)) parts.add(address.siteName);
        if (!String.isBlank(address.street)) parts.add(address.street);
        if (!String.isBlank(address.city)) parts.add(address.city);
        if (!String.isBlank(address.state)) parts.add(address.state);
        if (!String.isBlank(address.pinCode)) parts.add(address.pinCode);
        if (!String.isBlank(address.country)) parts.add(address.country);
        return String.join(parts, ' - ');
    }
}
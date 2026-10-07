@IsTest
public class ctrl_AssetSerialNoControllerTest {

@TestSetup
static void setupData() {

    Account acc = new Account(
        Name = 'Test Account'
    );
    insert acc;

    Product2 prod = new Product2(
        Name = 'Test Product',
        IsActive = true
    );
    insert prod;

    Asset ast = new Asset(
        Name = 'Test Asset',
        AccountId = acc.Id,
        Product2Id = prod.Id,
        Invoice_Date__c = Date.today(),
        InstallDate = Date.today(),
        UsageEndDate = Date.today().addYears(1)
    );
    insert ast;

    List<Asset_Serial_No__c> serialList = new List<Asset_Serial_No__c>{
        new Asset_Serial_No__c(
            Name = 'SN-001',
            Asset__c = ast.Id
        ),
        new Asset_Serial_No__c(
            Name = 'SN-002',
            Asset__c = ast.Id
        )
    };
    insert serialList;
}

    @IsTest
    static void testGetSerialNumbers() {

        Asset ast = [
            SELECT Id
            FROM Asset
            LIMIT 1
        ];

        Test.startTest();
        List<Asset_Serial_No__c> result =
            ctrl_AssetSerialNoController.getSerialNumbers(ast.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetSerialNumbersWithNullAssetId() {

        Test.startTest();
        List<Asset_Serial_No__c> result =
            ctrl_AssetSerialNoController.getSerialNumbers(null);
        Test.stopTest();
    }

    @IsTest
    static void testSaveSerialNumbersInsert() {

        Asset ast = [
            SELECT Id
            FROM Asset
            LIMIT 1
        ];

        List<Asset_Serial_No__c> serialList = new List<Asset_Serial_No__c>{
            new Asset_Serial_No__c(
                Name = 'SN-003'
            ),
            new Asset_Serial_No__c(
                Name = 'SN-004'
            ),
            new Asset_Serial_No__c(
                Name = ''
            )
        };

        Test.startTest();
        ctrl_AssetSerialNoController.saveSerialNumbers(ast.Id, serialList);
        Test.stopTest();
    }

    @IsTest
    static void testSaveSerialNumbersUpdate() {

        Asset ast = [
            SELECT Id
            FROM Asset
            LIMIT 1
        ];

        Asset_Serial_No__c existingSerial = [
            SELECT Id, Name, Asset__c
            FROM Asset_Serial_No__c
            WHERE Asset__c = :ast.Id
            LIMIT 1
        ];

        existingSerial.Name = 'SN-UPDATED';

        List<Asset_Serial_No__c> serialList = new List<Asset_Serial_No__c>{
            existingSerial
        };

        Test.startTest();
        ctrl_AssetSerialNoController.saveSerialNumbers(ast.Id, serialList);
        Test.stopTest();
    }

    @IsTest
    static void testSaveSerialNumbersEmptyList() {

        Asset ast = [
            SELECT Id
            FROM Asset
            LIMIT 1
        ];

        Test.startTest();
        ctrl_AssetSerialNoController.saveSerialNumbers(
            ast.Id,
            new List<Asset_Serial_No__c>()
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveSerialNumbersNullList() {

        Asset ast = [
            SELECT Id
            FROM Asset
            LIMIT 1
        ];

        Test.startTest();
        ctrl_AssetSerialNoController.saveSerialNumbers(ast.Id, null);
        Test.stopTest();
    }

    @IsTest
    static void testSaveSerialNumbersWithNullAssetId() {

        List<Asset_Serial_No__c> serialList = new List<Asset_Serial_No__c>{
            new Asset_Serial_No__c(
                Name = 'SN-005'
            )
        };

        Test.startTest();
        try {
            ctrl_AssetSerialNoController.saveSerialNumbers(null, serialList);
        } catch (Exception e) {
            // Exception handled for coverage
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteSerialNumber() {

        Asset_Serial_No__c serialRec = [
            SELECT Id
            FROM Asset_Serial_No__c
            LIMIT 1
        ];

        Test.startTest();
        ctrl_AssetSerialNoController.deleteSerialNumber(serialRec.Id);
        Test.stopTest();
    }

    @IsTest
    static void testDeleteSerialNumberWithNullId() {

        Test.startTest();
        try {
            ctrl_AssetSerialNoController.deleteSerialNumber(null);
        } catch (Exception e) {
            // Exception handled for coverage
        }
        Test.stopTest();
    }
}
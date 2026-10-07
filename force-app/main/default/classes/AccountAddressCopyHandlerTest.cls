@IsTest
public class AccountAddressCopyHandlerTest {

    @IsTest
    static void testCopyBillingToShippingOnInsert() {

        Account acc = new Account(
            Name = 'Test Account Insert',
            BillingStreet = '123 Billing Street',
            BillingCity = 'Kolkata',
            BillingState = 'West Bengal',
            BillingPostalCode = '700001',
            BillingCountry = 'India',
            Copy_Billing_Address_to_Shipping_Address__c = true
        );

        Test.startTest();
        insert acc;
        Test.stopTest();

        Account insertedAcc = [
            SELECT Id,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Copy_Billing_Address_to_Shipping_Address__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(insertedAcc.BillingStreet, insertedAcc.ShippingStreet);
        System.assertEquals(insertedAcc.BillingCity, insertedAcc.ShippingCity);
        System.assertEquals(insertedAcc.BillingState, insertedAcc.ShippingState);
        System.assertEquals(insertedAcc.BillingPostalCode, insertedAcc.ShippingPostalCode);
        System.assertEquals(insertedAcc.BillingCountry, insertedAcc.ShippingCountry);
    }

    @IsTest
    static void testCopyBillingToShippingOnUpdate() {

        Account acc = new Account(
            Name = 'Test Account Update',
            BillingStreet = 'Old Billing Street',
            BillingCity = 'Old City',
            BillingState = 'Old State',
            BillingPostalCode = '111111',
            BillingCountry = 'India',
            ShippingStreet = 'Old Shipping Street',
            ShippingCity = 'Old Shipping City',
            ShippingState = 'Old Shipping State',
            ShippingPostalCode = '222222',
            ShippingCountry = 'India',
            Copy_Billing_Address_to_Shipping_Address__c = false
        );

        insert acc;

        acc.BillingStreet = '456 New Billing Street';
        acc.BillingCity = 'Delhi';
        acc.BillingState = 'Delhi';
        acc.BillingPostalCode = '110001';
        acc.BillingCountry = 'India';
        acc.Copy_Billing_Address_to_Shipping_Address__c = true;

        Test.startTest();
        update acc;
        Test.stopTest();

        Account updatedAcc = [
            SELECT Id,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Copy_Billing_Address_to_Shipping_Address__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(updatedAcc.BillingStreet, updatedAcc.ShippingStreet);
        System.assertEquals(updatedAcc.BillingCity, updatedAcc.ShippingCity);
        System.assertEquals(updatedAcc.BillingState, updatedAcc.ShippingState);
        System.assertEquals(updatedAcc.BillingPostalCode, updatedAcc.ShippingPostalCode);
        System.assertEquals(updatedAcc.BillingCountry, updatedAcc.ShippingCountry);
    }

    @IsTest
    static void testDoNotCopyWhenCheckboxIsFalse() {

        Account acc = new Account(
            Name = 'Test Account Checkbox False',
            BillingStreet = 'Billing Street',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            ShippingStreet = 'Manual Shipping Street',
            ShippingCity = 'Pune',
            ShippingState = 'Maharashtra',
            ShippingPostalCode = '411001',
            ShippingCountry = 'India',
            Copy_Billing_Address_to_Shipping_Address__c = false
        );

        Test.startTest();
        insert acc;
        Test.stopTest();

        Account insertedAcc = [
            SELECT Id,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Copy_Billing_Address_to_Shipping_Address__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals('Manual Shipping Street', insertedAcc.ShippingStreet);
        System.assertEquals('Pune', insertedAcc.ShippingCity);
        System.assertEquals('Maharashtra', insertedAcc.ShippingState);
        System.assertEquals('411001', insertedAcc.ShippingPostalCode);
        System.assertEquals('India', insertedAcc.ShippingCountry);
    }
}
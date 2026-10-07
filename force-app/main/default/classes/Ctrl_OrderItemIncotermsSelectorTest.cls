@IsTest
public class Ctrl_OrderItemIncotermsSelectorTest {

    @testSetup
    static void setupData() {

        List<Incoterms_Master__c> lst = new List<Incoterms_Master__c>();

        lst.add(new Incoterms_Master__c(
            INCOTERMS__c='EXW',
            DESCRIPTION__c='Ex Works'
        ));

        // duplicate code (should be ignored by controller)
        lst.add(new Incoterms_Master__c(
            INCOTERMS__c='exw',
            DESCRIPTION__c='Duplicate'
        ));

        // blank description
        lst.add(new Incoterms_Master__c(
            INCOTERMS__c='FCA'
        ));

        lst.add(new Incoterms_Master__c(
            INCOTERMS__c='DAP',
            DESCRIPTION__c='Delivered At Place'
        ));

        // blank code
        lst.add(new Incoterms_Master__c(
            INCOTERMS__c='   ',
            DESCRIPTION__c='Should Skip'
        ));

        insert lst;
    }

    @IsTest
    static void testConstructors() {

        Ctrl_OrderItemIncotermsSelector.IncotermsOption o1 =
            new Ctrl_OrderItemIncotermsSelector.IncotermsOption();

        Ctrl_OrderItemIncotermsSelector.IncotermsOption o2 =
            new Ctrl_OrderItemIncotermsSelector.IncotermsOption(
                null,
                'FOB',
                'Free On Board'
            );

        Ctrl_OrderItemIncotermsSelector.IncotermsOption o3 =
            new Ctrl_OrderItemIncotermsSelector.IncotermsOption(
                null,
                'CIF',
                ''
            );

        System.debug(o1);
        System.debug(o2);
        System.debug(o3);
    }

    @IsTest
    static void testGetIncotermsOptions() {

        Test.startTest();

        List<Ctrl_OrderItemIncotermsSelector.IncotermsOption> options =
            Ctrl_OrderItemIncotermsSelector.getIncotermsOptions();

        Test.stopTest();

        System.debug(options);
    }

    @IsTest
    static void testMultipleCalls() {

        Test.startTest();

        Ctrl_OrderItemIncotermsSelector.getIncotermsOptions();
        Ctrl_OrderItemIncotermsSelector.getIncotermsOptions();

        Test.stopTest();
    }
}
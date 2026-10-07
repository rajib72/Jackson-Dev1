@isTest
private class Ctrl_AddOrderReasonToServiceOrderTest {

    @testSetup
    static void setupData() {

        List<Order_Reason_Master__c> reasons = new List<Order_Reason_Master__c>();

        reasons.add(new Order_Reason_Master__c(
            ORDER_REASON__c = 'OR001'
            //Order_Reason_Details__c = 'Installation'
        ));

        reasons.add(new Order_Reason_Master__c(
            ORDER_REASON__c = 'OR002'
           // Order_Reason_Details__c = 'Warranty'
        ));

        insert reasons;
    }

    @isTest
    static void testGetOrderReasons() {

        Test.startTest();

        List<Order_Reason_Master__c> result =
            Ctrl_AddOrderReasonToServiceOrder.getOrderReasons();

        Test.stopTest();

    }
}
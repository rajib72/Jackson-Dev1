@IsTest
public class ctrl_LocationCaptureControllerTest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        WorkOrder wo = new WorkOrder(
            Subject = 'Test Work Order',
            AccountId = acc.Id,
            Status = 'New'
        );
        insert wo;

        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Subject = 'Test Service Appointment',
            Status = 'Scheduled',
            SchedStartTime = System.now(),
            SchedEndTime = System.now().addHours(1)
        );
        insert sa;
    }

    @IsTest
    static void testSaveLocationSuccess() {
        ServiceAppointment sa = [
            SELECT Id
            FROM ServiceAppointment
            LIMIT 1
        ];

        Test.startTest();
        ctrl_LocationCaptureController.saveLocation(
            sa.Id,
            22.5726,
            88.3639
        );
        Test.stopTest();

        ServiceAppointment updatedSA = [
            SELECT Current_Location__Latitude__s,
                   Current_Location__Longitude__s
            FROM ServiceAppointment
            WHERE Id = :sa.Id
        ];

        System.assertEquals(22.5726, updatedSA.Current_Location__Latitude__s);
        System.assertEquals(88.3639, updatedSA.Current_Location__Longitude__s);
    }

    @IsTest
    static void testSaveLocationWithoutRecordId() {
        Test.startTest();
        try {
            ctrl_LocationCaptureController.saveLocation(null, 22.5726, 88.3639);
            System.assert(false, 'Exception should have been thrown.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveLocationWithoutLatitudeLongitude() {
        ServiceAppointment sa = [
            SELECT Id
            FROM ServiceAppointment
            LIMIT 1
        ];

        Test.startTest();
        try {
            ctrl_LocationCaptureController.saveLocation(sa.Id, null, null);
            System.assert(false, 'Exception should have been thrown.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
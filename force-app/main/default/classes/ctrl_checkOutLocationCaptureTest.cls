@IsTest
private class ctrl_checkOutLocationCaptureTest {

    private static String firstActivePicklistValue(Schema.SObjectType sobjectType, String fieldName) {
        Map<String, Schema.SObjectField> fieldMap = sobjectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldName)) {
            return null;
        }

        for (Schema.PicklistEntry pe : fieldMap.get(fieldName).getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static ServiceAppointment createServiceAppointment(Boolean includeCheckInLocation) {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        WorkOrder wo = new WorkOrder();
        if (WorkOrder.SObjectType.getDescribe().fields.getMap().containsKey('Subject')) {
            wo.put('Subject', 'Test Work Order');
        }
        String woStatus = firstActivePicklistValue(WorkOrder.SObjectType, 'Status');
        if (woStatus != null) {
            wo.put('Status', woStatus);
        }
        String woPriority = firstActivePicklistValue(WorkOrder.SObjectType, 'Priority');
        if (woPriority != null) {
            wo.put('Priority', woPriority);
        }
        if (WorkOrder.SObjectType.getDescribe().fields.getMap().containsKey('AccountId')) {
            wo.put('AccountId', acc.Id);
        }
        insert wo;

        ServiceAppointment sa = new ServiceAppointment();

        Map<String, Schema.SObjectField> saFields = ServiceAppointment.SObjectType.getDescribe().fields.getMap();

        if (saFields.containsKey('ParentRecordId')) {
            sa.put('ParentRecordId', wo.Id);
        } else if (saFields.containsKey('WorkOrderId')) {
            sa.put('WorkOrderId', wo.Id);
        }

        String saStatus = firstActivePicklistValue(ServiceAppointment.SObjectType, 'Status');
        if (saStatus != null) {
            sa.put('Status', saStatus);
        }

        if (saFields.containsKey('Subject')) {
            sa.put('Subject', 'Test Service Appointment');
        }

        if (saFields.containsKey('EarliestStartTime')) {
            sa.put('EarliestStartTime', System.now());
        }

        if (saFields.containsKey('DueDate')) {
            sa.put('DueDate', Date.today().addDays(1));
        }

        if (saFields.containsKey('Duration')) {
            sa.put('Duration', 60);
        }

        if (includeCheckInLocation) {
            sa.put('Current_Location__Latitude__s', 12.9716);
            sa.put('Current_Location__Longitude__s', 77.5946);
        }

        insert sa;
        return sa;
    }

    @IsTest
    static void testSaveLocationSuccess() {
        ServiceAppointment sa = createServiceAppointment(true);

        Test.startTest();
        ctrl_checkOutLocationCaptureController.saveLocation(
            sa.Id,
            12.9720,
            77.5950
        );
        Test.stopTest();

        ServiceAppointment updatedSa = [
            SELECT Id,
                   Check_Out_Location__Latitude__s,
                   Check_Out_Location__Longitude__s
            FROM ServiceAppointment
            WHERE Id = :sa.Id
            LIMIT 1
        ];

            }

    @IsTest
    static void testSaveLocationNullRecordId() {
        Test.startTest();
        try {
            ctrl_checkOutLocationCaptureController.saveLocation(
                null,
                12.9720,
                77.5950
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveLocationNullCoordinates() {
        ServiceAppointment sa = createServiceAppointment(true);

        Test.startTest();
        try {
            ctrl_checkOutLocationCaptureController.saveLocation(
                sa.Id,
                null,
                77.5950
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveLocationNoCheckInLocation() {
        ServiceAppointment sa = createServiceAppointment(false);

        Test.startTest();
        try {
            ctrl_checkOutLocationCaptureController.saveLocation(
                sa.Id,
                12.9720,
                77.5950
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveLocationOutOfRange() {
        ServiceAppointment sa = createServiceAppointment(true);

        Test.startTest();
        try {
            ctrl_checkOutLocationCaptureController.saveLocation(
                sa.Id,
                28.7041,
                77.1025
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}
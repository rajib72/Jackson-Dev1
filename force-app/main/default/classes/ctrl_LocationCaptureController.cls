public with sharing class ctrl_LocationCaptureController {

    @AuraEnabled
    public static void saveLocation(Id recordId, Decimal latitude, Decimal longitude) 
    {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        if (latitude == null || longitude == null) {
            throw new AuraHandledException('Latitude and Longitude are required.');
        }

        ServiceAppointment visitRecord = new ServiceAppointment();
        visitRecord.Id = recordId;
        visitRecord.Current_Location__Latitude__s = latitude;
        visitRecord.Current_Location__Longitude__s = longitude;

        update visitRecord;
    }
}
public with sharing class ctrl_checkOutLocationCaptureController {

    private static final Decimal MAX_ALLOWED_DISTANCE_KM = 5;

    @AuraEnabled
    public static void saveLocation(Id recordId, Decimal latitude, Decimal longitude) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        if (latitude == null || longitude == null) {
            throw new AuraHandledException('Latitude and Longitude are required.');
        }

        ServiceAppointment visitRecord = [
            SELECT Id,
                   Current_Location__Latitude__s,
                   Current_Location__Longitude__s
            FROM ServiceAppointment
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (
            visitRecord.Current_Location__Latitude__s == null ||
            visitRecord.Current_Location__Longitude__s == null
        ) {
            throw new AuraHandledException('Check In location is not available. Please capture Check In location first.');
        }

        Decimal checkInLat = visitRecord.Current_Location__Latitude__s;
        Decimal checkInLong = visitRecord.Current_Location__Longitude__s;

        Double distanceInKm = calculateDistanceInKm(
            Double.valueOf(checkInLat),
            Double.valueOf(checkInLong),
            Double.valueOf(latitude),
            Double.valueOf(longitude)
        );

        if (distanceInKm > Double.valueOf(MAX_ALLOWED_DISTANCE_KM)) {
            throw new AuraHandledException(
                'Check Out location must be within 5 KM range of Check In location. Current distance is ' +
                String.valueOf(Decimal.valueOf(distanceInKm).setScale(2)) + ' KM.'
            );
        }

        ServiceAppointment updateRecord = new ServiceAppointment();
        updateRecord.Id = recordId;
        updateRecord.Check_Out_Location__Latitude__s = latitude;
        updateRecord.Check_Out_Location__Longitude__s = longitude;

        update updateRecord;
    }

    private static Double calculateDistanceInKm(
        Double lat1,
        Double lon1,
        Double lat2,
        Double lon2
    ) {
        Double earthRadiusKm = 6371.0;

        Double dLat = toRadians(lat2 - lat1);
        Double dLon = toRadians(lon2 - lon1);

        Double radLat1 = toRadians(lat1);
        Double radLat2 = toRadians(lat2);

        Double a =
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(radLat1) * Math.cos(radLat2) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);

        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return earthRadiusKm * c;
    }

    private static Double toRadians(Double degree) {
        return degree * Math.PI / 180;
    }
}
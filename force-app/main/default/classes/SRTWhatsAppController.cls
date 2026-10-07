public class SRTWhatsAppController {
    @future(callout=true)
    public static void sendWhatsApp(
        String destination,
        String serviceRequestNumber,
        String product,
        String productCategory,
        String customerName,
        String mobileNumber,
        String location,
        String warranty
    ) {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:Go2Market_API/v2/api/clouds3/send');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/json');

            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('apiKey', '2f70ad35-fe61-45ba-be3f-2ddf0e985482');
            requestBody.put('campaignName', 'service_requests');
            requestBody.put('destination', destination);
            requestBody.put('type', 'template');
            requestBody.put('mediatype', 'TEXT');
            requestBody.put('templateParams', new List<String>{
                serviceRequestNumber,
                product,
                productCategory,
                customerName,
                mobileNumber,
                location,
                warranty
            });

            request.setBody(JSON.serialize(requestBody));

            HttpResponse response = new Http().send(request);

            System.debug('Go2Market Status: ' + response.getStatusCode());
            System.debug('Go2Market Response: ' + response.getBody());

        } catch (Exception ex) {
            System.debug('Go2Market WhatsApp Error: ' + ex.getMessage());
        }
    }
}
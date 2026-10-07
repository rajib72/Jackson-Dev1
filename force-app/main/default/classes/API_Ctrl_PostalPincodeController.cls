public with sharing class API_Ctrl_PostalPincodeController {

    public class PostOfficeRow {
        @AuraEnabled public String name;
        @AuraEnabled public String branchType;
        @AuraEnabled public String deliveryStatus;
        @AuraEnabled public String circle;
        @AuraEnabled public String district;
        @AuraEnabled public String division;
        @AuraEnabled public String region;
        @AuraEnabled public String block;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
        @AuraEnabled public String pincode;
    }

    public class ResponseWrapper {
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public List<PostOfficeRow> postOffices;
    }

    @AuraEnabled(cacheable=false)
    public static ResponseWrapper getPostOffices(String pincode) {
        ResponseWrapper responseWrap = new ResponseWrapper();
        responseWrap.postOffices = new List<PostOfficeRow>();

        try {
            if (String.isBlank(pincode)) {
                responseWrap.status = 'Error';
                responseWrap.message = 'Pincode is required.';
                return responseWrap;
            }

            Http http = new Http();
            HttpRequest httpReq = new HttpRequest();
            httpReq.setMethod('GET');
            httpReq.setEndpoint('callout:NC_PIN_Code/pincode/' + EncodingUtil.urlEncode(pincode, 'UTF-8'));
            httpReq.setTimeout(20000);

            HttpResponse httpRes = http.send(httpReq);

            if (httpRes.getStatusCode() == 200) {
                Object rawObj = JSON.deserializeUntyped(httpRes.getBody());

                if (rawObj instanceof List<Object>) {
                    List<Object> outerList = (List<Object>) rawObj;

                    if (!outerList.isEmpty() && outerList[0] instanceof Map<String, Object>) {
                        Map<String, Object> firstObj = (Map<String, Object>) outerList[0];

                        responseWrap.status = String.valueOf(firstObj.get('Status'));
                        responseWrap.message = String.valueOf(firstObj.get('Message'));

                        Object poObj = firstObj.get('PostOffice');
                        if (poObj instanceof List<Object>) {
                            for (Object po : (List<Object>) poObj) {
                                if (po instanceof Map<String, Object>) {
                                    Map<String, Object> poMap = (Map<String, Object>) po;

                                    PostOfficeRow row = new PostOfficeRow();
                                    
                                    row.name = valueOf(poMap.get('Name'));
                                    row.branchType = valueOf(poMap.get('BranchType'));
                                    row.deliveryStatus = valueOf(poMap.get('DeliveryStatus'));
                                    row.circle = valueOf(poMap.get('Circle'));
                                    row.district = valueOf(poMap.get('District'));
                                    row.division = valueOf(poMap.get('Division'));
                                    row.region = valueOf(poMap.get('Region'));
                                    row.block = valueOf(poMap.get('Block'));
                                    row.state = valueOf(poMap.get('State'));
                                    row.country = valueOf(poMap.get('Country'));
                                    row.pincode = valueOf(poMap.get('Pincode'));

                                    responseWrap.postOffices.add(row);
                                    
                                }
                            }
                        }
                        System.debug('Response---'+responseWrap);
                    }
                }
            } else {
                responseWrap.status = 'Error';
                responseWrap.message = 'HTTP Error: ' + httpRes.getStatusCode() + ' - ' + httpRes.getStatus();
            }

        } catch (Exception e) {
            responseWrap.status = 'Error';
            responseWrap.message = e.getMessage();
        }

        return responseWrap;
    }
    
    // Service Appointment
    
    @AuraEnabled
    public static void updateServiceAppointmentFromSelection(
        Id serviceAppointmentId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (serviceAppointmentId == null) {
                throw new AuraHandledException('Service Appointment Id is required.');
            }
    
            ServiceAppointment sa = new ServiceAppointment(
                Id = serviceAppointmentId
            );
            sa.State = stateValue;
            sa.Country = countryValue;
            sa.City = cityValue;
    
            update sa;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Lead
    
    @AuraEnabled
    public static void updateLeadFromSelection(
        Id leadId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (leadId == null) {
                throw new AuraHandledException('Lead Id is required.');
            }
    
            Lead ld = new Lead(
                Id = leadId
            );
            ld.State = stateValue;
            ld.Country = countryValue;
            ld.City = cityValue;
    
            update ld;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Account Billing
    
    @AuraEnabled
    public static void updateAccountBillingFromSelection(
        Id accId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (accId == null) {
                throw new AuraHandledException('Account Id is required.');
            }
    
            Account acc = new Account(
                Id = accId
            );
            acc.BillingState = stateValue;
            acc.BillingCountry = countryValue;
            acc.BillingCity = cityValue;
    
            update acc;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Account Shipping
    
    @AuraEnabled
    public static void updateAccountShippingFromSelection(
        Id accId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (accId == null) {
                throw new AuraHandledException('Account Id is required.');
            }
    
            Account acc = new Account(
                Id = accId
            );
            acc.ShippingState = stateValue;
            acc.ShippingCountry = countryValue;
            acc.ShippingCity = cityValue;
    
            update acc;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String valueOf(Object obj) {
        return obj == null ? '' : String.valueOf(obj);
    }
    
    // Quote Billing
    
    @AuraEnabled
    public static void updateQuoteBillingFromSelection(
        Id qId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (qId== null) {
                throw new AuraHandledException('Quote Id is required.');
            }
    
            Quote qt = new Quote(
                Id = qId
            );
            qt.BillingState = stateValue;
            qt.BillingCountry = countryValue;
            qt.BillingCity = cityValue;
    
            update qt;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // Quote Shipping
    
    @AuraEnabled
    public static void updateQuoteShippingFromSelection(
        Id qId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (qId== null) {
                throw new AuraHandledException('Quote Id is required.');
            }
    
            Quote qt = new Quote(
                Id = qId
            );
            qt.ShippingState = stateValue;
            qt.ShippingCountry = countryValue;
            qt.ShippingCity = cityValue;
    
            update qt;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Asset Update Method
    @AuraEnabled
    public static void updateAssetFromSelection(
        Id assetId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (assetId == null) {
                throw new AuraHandledException('Asset Id is required.');
            }
    
            Asset ast = new Asset(
                Id = assetId
            );
            ast.State__c = stateValue;
            ast.Country__c = countryValue;
            ast.City__c = cityValue;
    
            update ast;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Product Request Update
    @AuraEnabled
    public static void updateProductRequestFromSelection(
        Id prId,
        String stateValue,
        String countryValue,
        String cityValue
    ) {
        try {
            if (prId == null) {
                throw new AuraHandledException('Product Request Id is required.');
            }
    
            ProductRequest pr = new ProductRequest(
                Id = prId
            );
            // Updating the individual components of the standard ShipToAddress compound field
            pr.ShipToState = stateValue;
            pr.ShipToCountry = countryValue;
            pr.ShipToCity = cityValue;
    
            update pr;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
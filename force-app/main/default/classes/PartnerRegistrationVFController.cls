public with sharing class PartnerRegistrationVFController {

    public String partnerId { get; set; }

    public PartnerRegistrationVFController() {
        partnerId = ApexPages.currentPage().getParameters().get('partnerId');
        System.debug('PartnerId from URL: ' + partnerId);
    }
}
public with sharing class PartnerAgreementVFController {

    public String partnerId { get; set; }

    public PartnerAgreementVFController() {
        partnerId = ApexPages.currentPage().getParameters().get('partnerId');
        System.debug('PartnerId from URL: ' + partnerId);
    }
}
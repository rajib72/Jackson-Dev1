public with sharing class WarrantySiteController {
    public AssetWarranty w { get; set; }
    public Asset a{ get; set; }

    public WarrantySiteController() {
        w = new AssetWarranty();
        a = new Asset();
    }

    public PageReference save() {
        try {
            insert w;
            PageReference p = Page.Vf_SiteWarrantyForm;
            p.setRedirect(true);
            return p;
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
            return null;
        }
    }
}
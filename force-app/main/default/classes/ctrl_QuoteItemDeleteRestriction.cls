public with sharing class ctrl_QuoteItemDeleteRestriction {

    private ApexPages.StandardController stdController;
    private Id quoteLineItemId;

    public ctrl_QuoteItemDeleteRestriction (ApexPages.StandardController controller) {
        this.stdController = controller;
        this.quoteLineItemId = controller.getId();

        ApexPages.addMessage(
            new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Delete action is not allowed for Quote Line Item records.'
            )
        );
    }

    public PageReference goBack() {
        if (quoteLineItemId != null) {
            QuoteLineItem qli = [
                SELECT Id, QuoteId
                FROM QuoteLineItem
                WHERE Id = :quoteLineItemId
                LIMIT 1
            ];

            PageReference quotePage = new PageReference('/' + qli.QuoteId);
            quotePage.setRedirect(true);
            return quotePage;
        }

        PageReference homePage = new PageReference('/lightning/o/Quote/list');
        homePage.setRedirect(true);
        return homePage;
    }
}
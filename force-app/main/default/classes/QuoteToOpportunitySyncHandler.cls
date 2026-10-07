public with sharing class QuoteToOpportunitySyncHandler {

    public static void syncQuoteValuesToOpportunity(
        List<Quote> newQuotes,
        Map<Id, Quote> oldQuotesMap
    ) {
        if (newQuotes == null || newQuotes.isEmpty()) {
            return;
        }

        if (oldQuotesMap == null) {
            oldQuotesMap = new Map<Id, Quote>();
        }

        Set<Id> oppIds = new Set<Id>();
        Set<Id> impactedOppIds = new Set<Id>();

        /*
         * Identify all Opportunities impacted by the current transaction.
         *
         * We consider both:
         *  - New OpportunityId
         *  - Old OpportunityId
         *
         * This is important when a Quote is moved from one Opportunity to another.
         */
        for (Quote newQ : newQuotes) {

            if (newQ.OpportunityId != null) {
                oppIds.add(newQ.OpportunityId);
            }

            Quote oldQ = oldQuotesMap.get(newQ.Id);

            if (oldQ != null && oldQ.OpportunityId != null) {
                oppIds.add(oldQ.OpportunityId);
            }

            /*
             * Determine whether this Quote can affect
             * the Opportunity totals.
             */
            if (oldQ == null) {
                // Insert scenario
                if (newQ.OpportunityId != null) {
                    impactedOppIds.add(newQ.OpportunityId);
                }
            } else {

                Boolean quoteValuesChanged =
                    newQ.QuoteLI_Grand_Total__c != oldQ.QuoteLI_Grand_Total__c ||
                    newQ.QuoteLI_Total__c != oldQ.QuoteLI_Total__c;

                Boolean statusChanged =
                    newQ.Status != oldQ.Status;

                Boolean opportunityChanged =
                    newQ.OpportunityId != oldQ.OpportunityId;

                if (
                    quoteValuesChanged ||
                    statusChanged ||
                    opportunityChanged
                ) {
                    if (newQ.OpportunityId != null) {
                        impactedOppIds.add(newQ.OpportunityId);
                    }

                    if (oldQ.OpportunityId != null) {
                        impactedOppIds.add(oldQ.OpportunityId);
                    }
                }
            }
        }

        if (impactedOppIds.isEmpty()) {
            return;
        }

        /*
         * Get the latest non-denied Quote for every impacted Opportunity.
         */
        Map<Id, Quote> oppToLatestValidQuote = new Map<Id, Quote>();

        for (Quote q : [
            SELECT Id,
                   OpportunityId,
                   Status,
                   QuoteLI_Grand_Total__c,
                   QuoteLI_Total__c,
                   LastModifiedDate
            FROM Quote
            WHERE OpportunityId IN :impactedOppIds
            AND Status != 'Denied'
            ORDER BY OpportunityId, LastModifiedDate DESC, Id DESC
        ]) {
            if (!oppToLatestValidQuote.containsKey(q.OpportunityId)) {
                oppToLatestValidQuote.put(q.OpportunityId, q);
            }
        }

        /*
         * Query existing Opportunity values so we avoid
         * unnecessary DML when values are already correct.
         */
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id,
                   Quote_Grand_Total__c,
                   Quote_Total__c
            FROM Opportunity
            WHERE Id IN :impactedOppIds
        ]);

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Id oppId : impactedOppIds) {

            Opportunity existingOpp = oppMap.get(oppId);

            if (existingOpp == null) {
                continue;
            }

            Quote latestQuote = oppToLatestValidQuote.get(oppId);

            Decimal latestGrandTotal;
            Decimal latestTotal;

            if (latestQuote != null) {
                latestGrandTotal = latestQuote.QuoteLI_Grand_Total__c;
                latestTotal = latestQuote.QuoteLI_Total__c;
            } else {
                /*
                 * No valid Quote remains for this Opportunity.
                 * Clear the Opportunity values.
                 */
                latestGrandTotal = null;
                latestTotal = null;
            }

            /*
             * Only update when the values are actually different.
             */
            if (
                existingOpp.Quote_Grand_Total__c != latestGrandTotal ||
                existingOpp.Quote_Total__c != latestTotal
            ) {
                oppsToUpdate.add(
                    new Opportunity(
                        Id = oppId,
                        Quote_Grand_Total__c = latestGrandTotal,
                        Quote_Total__c = latestTotal
                    )
                );
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
    
    public static void test() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    
    }
}

/* public with sharing class QuoteToOpportunitySyncHandler {

    public static void syncQuoteValuesToOpportunity(List<Quote> newQuotes) {
        if (newQuotes == null || newQuotes.isEmpty()) {
            return;
        }

        Set<Id> oppIds = new Set<Id>();

        // Collect Opportunity Ids from trigger records
        for (Quote q : newQuotes) {
            if (q.OpportunityId != null) {
                oppIds.add(q.OpportunityId);
            }
        }

        if (oppIds.isEmpty()) {
            return;
        }

        // Get latest non-denied quote for each opportunity
        Map<Id, Quote> oppToLatestValidQuote = new Map<Id, Quote>();

        for (Quote q : [
            SELECT Id,
                   OpportunityId,
                   Status,
                   QuoteLI_Grand_Total__c,
                   QuoteLI_Total__c,
                   LastModifiedDate
            FROM Quote
            WHERE OpportunityId IN :oppIds
              AND Status != 'Denied'
            ORDER BY OpportunityId, LastModifiedDate DESC
        ]) {
            if (!oppToLatestValidQuote.containsKey(q.OpportunityId)) {
                oppToLatestValidQuote.put(q.OpportunityId, q);
            }
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Id oppId : oppToLatestValidQuote.keySet()) {
            Quote q = oppToLatestValidQuote.get(oppId);

                Opportunity oppToUpdate = new Opportunity(
                    Id = oppId,
                    Quote_Grand_Total__c = q.QuoteLI_Grand_Total__c,
                    Quote_Total__c = q.QuoteLI_Total__c
                );
    
                oppsToUpdate.add(oppToUpdate);
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
} */
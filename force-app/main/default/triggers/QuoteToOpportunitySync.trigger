trigger QuoteToOpportunitySync on Quote (after insert, after update) {
    QuoteToOpportunitySyncHandler.syncQuoteValuesToOpportunity(Trigger.new, Trigger.oldMap);
}
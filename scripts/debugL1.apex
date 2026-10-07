Case c = [SELECT Id, Product__c, AccountId, Account.BillingState FROM Case WHERE AccountId != null AND Product__c != null AND Account.BillingState != null ORDER BY CreatedDate DESC LIMIT 1];
User u = [SELECT Id FROM User WHERE IsActive = true AND UserType = 'Standard' AND Product__c INCLUDES (:c.Product__c) AND State__c INCLUDES (:c.Account.BillingState) LIMIT 1];
if (u != null && c != null) {
    try {
        System.debug('Assigning L1...');
        String res = CaseL1AssignmentController.assignL1(c.Id, u.Id);
        System.debug('SUCCESS: ' + res);
    } catch (Exception e) {
        System.debug('ERROR: ' + e.getMessage());
        System.debug('STACK: ' + e.getStackTraceString());
    }
} else {
    System.debug('No valid case/user combo found.');
}

Case c = [SELECT Id, Product__c, AccountId, Account.BillingState FROM Case WHERE AccountId != null AND Product__c != null AND Account.BillingState != null ORDER BY CreatedDate DESC LIMIT 1];
User u = [SELECT Id, Email, Name, IsActive, UserType, Product__c, State__c FROM User WHERE IsActive = true AND UserType = 'Standard' AND Product__c INCLUDES (:c.Product__c) AND State__c INCLUDES (:c.Account.BillingState) LIMIT 1];
System.debug('Starting test logic...');
try {
    String res = CaseL1AssignmentController.assignL1(c.Id, u.Id);
    System.debug('L1RESULT OK: ' + res);
} catch (Exception e) {
    System.debug('L1RESULT FAILED: ' + e.getMessage() + ' STACK: ' + e.getStackTraceString());
}

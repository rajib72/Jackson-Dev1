public with sharing class LeadCreationController {
    
    @AuraEnabled
    public static Boolean checkDuplicateLead(String email, String mobile, String phone) {
        List<Lead> duplicateLeads = [
            SELECT Id 
            FROM Lead 
            WHERE Status != 'Not Converted'
            AND (Email = :email 
            OR (
                (MobilePhone != null AND (MobilePhone = :mobile OR MobilePhone = :phone))
                OR 
                (Phone != null AND (Phone = :mobile OR Phone = :phone))
            ))
            LIMIT 1
        ];

        return !duplicateLeads.isEmpty();
    }
}
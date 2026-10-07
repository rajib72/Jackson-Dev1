/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ctrl_CaseContactLookupController
 * Author          : <YourAmitName>
 * Created Date    : Aug 26, 2026
 * Last Modified By: <YourAmitName>
 * Last Modified On: Aug 26, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Aug 26, 2026  │ <YourAmitName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class ctrl_CaseContactLookupController {
    @AuraEnabled(cacheable=true)
    public static List<ContactResult> searchContacts(Id accountId, String searchTerm) {
        List<ContactResult> results = new List<ContactResult>();
        if (accountId == null) {
            return results;
        }
        List<Contact> contacts;
        if (String.isBlank(searchTerm)) {
            contacts = [
                SELECT Id, Name, Email, Phone
                FROM Contact
                WHERE AccountId = :accountId
                ORDER BY Name
                LIMIT 200
            ];
        } else {
            String searchPattern = '%' + searchTerm.trim() + '%';
            contacts = [
                SELECT Id, Name, Email, Phone
                FROM Contact
                WHERE AccountId = :accountId
                AND Name LIKE :searchPattern
                ORDER BY Name
                LIMIT 200
            ];
        }
        for (Contact contactRecord : contacts) {
            ContactResult result = new ContactResult();
            result.Id = contactRecord.Id;
            result.Name = contactRecord.Name;
            result.Email = contactRecord.Email;
            result.Phone = contactRecord.Phone;
            results.add(result);
        }
        return results;
    }

    public class ContactResult {
        @AuraEnabled
        public Id Id { get; set; }
        @AuraEnabled
        public String Name { get; set; }
        @AuraEnabled
        public String Email { get; set; }
        @AuraEnabled
        public String Phone { get; set; }
    }
}
public with sharing class Ctrl_CaseCreationForm { 

    // ---------------- DTOs ----------------
    public class AccountDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
    }

    public class ContactDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
    }

    public class AssetDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String serialNumber;
        @AuraEnabled public String productName;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
    }

    public class SearchResponse {
        @AuraEnabled public AccountDTO account;
        @AuraEnabled public List<AccountDTO> accountResults;
        @AuraEnabled public List<ContactDTO> contacts;
        @AuraEnabled public List<AssetDTO> assets;
        @AuraEnabled public String matchedBy;
    }

    // ---------------- Picklist DTOs ----------------
    public class PickVal {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PickVal(String l, String v){ label = l; value = v; }
    }

    public class InitData {
        @AuraEnabled public List<PickVal> complaintTypeOptions;
        @AuraEnabled public List<PickVal> caseStatusOptions;
        @AuraEnabled public List<PickVal> caseOriginOptions;

        @AuraEnabled public List<PickVal> productCategoryOptions;
        @AuraEnabled public List<PickVal> installerTypeOptions;
        @AuraEnabled public List<PickVal> customerPersonaOptions;
    }

    // ---------------- Case Create Request ----------------
    public class CaseCreateRequest {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;

        // keep old field
        @AuraEnabled public Id assetId;

        // multiple assets
        @AuraEnabled public List<Id> assetIds;

        @AuraEnabled public String subject;
        @AuraEnabled public String description;
        @AuraEnabled public String complaintType;
        @AuraEnabled public String status;
        @AuraEnabled public String origin;

        @AuraEnabled public String productCategory;
        @AuraEnabled public String otherProductCategory;
        @AuraEnabled public String vocText;
        @AuraEnabled public String installerType;
        @AuraEnabled public String otherInstaller;
        @AuraEnabled public String customerPersona;
        @AuraEnabled public String otherComplaintType;

        // ---------------- NEW: Draft Account + Contact creation fields ----------------
        @AuraEnabled public Boolean createNewAccountContact;
        @AuraEnabled public String newAccountName;
        @AuraEnabled public String newAccountPhone;
        @AuraEnabled public String newAccountBillingCity;
        @AuraEnabled public String newAccountBillingState;
        @AuraEnabled public String newAccountBillingStreet;
        @AuraEnabled public String newAccountBillingPostalCode;
        @AuraEnabled public String newAccountBillingCountry;

        @AuraEnabled public String newContactFirstName;
        @AuraEnabled public String newContactLastName;
        @AuraEnabled public String newContactPhone;
        @AuraEnabled public String newContactMobilePhone;
        @AuraEnabled public String newContactEmail;
        @AuraEnabled public String newContactDepartment;
        @AuraEnabled public String newContactDesignation;
    }

    // ---------------- Public Search ----------------
    @AuraEnabled(cacheable=true)
    public static SearchResponse search(String term) {

        if (String.isBlank(term) || term.trim().length() < 2) {
            throw new AuraHandledException('Please enter at least 2 characters.');
        }

        String t = term.trim();

        String digits = onlyDigits(t);
        Boolean looksLikePhone = (!String.isBlank(digits) && digits.length() >= 8 && isMostlyPhoneChars(t));
        Boolean looksLikeAssetKey = isLikelyAssetKey(t, digits, looksLikePhone);

        if (looksLikePhone) {
            SearchResponse byPhone = searchByContactPhone(digits);
            if (byPhone != null) return byPhone;
        }

        if (looksLikeAssetKey) {
            SearchResponse byAsset = searchByAssetSerialOrInvoice(t, digits);
            if (byAsset != null) return byAsset;
        }

        SearchResponse byAccount = searchByAccountName(t);
        if (byAccount != null) return byAccount;

        SearchResponse tryAsset = searchByAssetSerialOrInvoice(t, digits);
        if (tryAsset != null) return tryAsset;

        SearchResponse tryPhone = searchByContactPhone(digits);
        if (tryPhone != null) return tryPhone;

        return emptyResponse();
    }

    @AuraEnabled(cacheable=true)
    public static SearchResponse loadByAccountId(Id accountId) {
        if (accountId == null) throw new AuraHandledException('Account Id is required.');
        return buildResponseFromAccountId(accountId, 'AccountSelected');
    }

    // ---------------- Init Data (Picklists) ----------------
    @AuraEnabled(cacheable=true)
    public static InitData getInitData() {
        InitData d = new InitData();

        d.complaintTypeOptions  = picklistOptions(Case.Complaint_Type__c);
        d.caseStatusOptions     = picklistOptions(Case.Status);
        d.caseOriginOptions     = picklistOptions(Case.Origin);

        d.productCategoryOptions = picklistOptions(Case.Product_Category__c);
        d.installerTypeOptions   = picklistOptions(Case.Installer_Type__c);
        d.customerPersonaOptions = picklistOptions(Case.Customer_Persona__c);

        return d;
    }

    // ---------------- Create Case ----------------
    @AuraEnabled
    public static Id createCase(CaseCreateRequest req) {
        if (req == null) throw new AuraHandledException('Invalid request.');
        if (String.isBlank(req.subject)) throw new AuraHandledException('Case Subject is required.');
        if (String.isBlank(req.origin)) throw new AuraHandledException('Case Origin is required.');
        if (String.isBlank(req.description)) throw new AuraHandledException('Description is required.');

        if (req.complaintType == 'Any Other Problem' && String.isBlank(req.otherComplaintType)) {
            throw new AuraHandledException('Other Complaint Type is required.');
        }

        if (req.productCategory == 'Other' && String.isBlank(req.otherProductCategory)) {
            throw new AuraHandledException('Other Product Category is required.');
        }

        Id resolvedAccountId = req.accountId;
        Id resolvedContactId = req.contactId;

        // ---------------- NEW FLOW: create Account + Contact if no result found ----------------
        if (req.createNewAccountContact == true) {

            if (String.isBlank(req.newAccountName)) {
                throw new AuraHandledException('Account Name is required.');
            }
            if (String.isBlank(req.newContactLastName)) {
                throw new AuraHandledException('Contact Last Name is required.');
            }

            Account acc = new Account();
            acc.Name = req.newAccountName;

            if (!String.isBlank(req.newAccountPhone)) acc.Phone = req.newAccountPhone;
            if (!String.isBlank(req.newAccountBillingCity)) acc.BillingCity = req.newAccountBillingCity;
            if (!String.isBlank(req.newAccountBillingState)) acc.BillingState = req.newAccountBillingState;
            if (!String.isBlank(req.newAccountBillingStreet)) acc.BillingStreet = req.newAccountBillingStreet;
            if (!String.isBlank(req.newAccountBillingPostalCode)) acc.BillingPostalCode = req.newAccountBillingPostalCode;
            if (!String.isBlank(req.newAccountBillingCountry)) acc.BillingCountry = req.newAccountBillingCountry;

            // Set Account Status = Draft if field exists
            setAccountDraftStatus(acc);

            insert acc;
            resolvedAccountId = acc.Id;

            Contact con = new Contact();
            con.AccountId = resolvedAccountId;
            con.LastName = req.newContactLastName;

            if (!String.isBlank(req.newContactFirstName)) con.FirstName = req.newContactFirstName;
            if (!String.isBlank(req.newContactPhone)) con.Phone = req.newContactPhone;
            if (!String.isBlank(req.newContactMobilePhone)) con.MobilePhone = req.newContactMobilePhone;
            if (!String.isBlank(req.newContactEmail)) con.Email = req.newContactEmail;
            if (!String.isBlank(req.newContactDepartment)) con.Department = req.newContactDepartment;
            if (!String.isBlank(req.newContactDesignation)) con.Title= req.newContactDesignation;

            insert con;
            resolvedContactId = con.Id;
        }

        // existing flow validation
        if (resolvedContactId == null) throw new AuraHandledException('Contact is required.');

        // If accountId not coming from UI, derive from Contact
        if (resolvedAccountId == null && resolvedContactId != null) {
            Contact ct = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Id = :resolvedContactId
                LIMIT 1
            ];
            resolvedAccountId = ct.AccountId;
        }

        if (resolvedAccountId == null) {
            throw new AuraHandledException('Account is required. Selected Contact is not linked to any Account.');
        }

        // assets optional now
        List<Id> selectedAssets = new List<Id>();
        if (req.assetIds != null) selectedAssets.addAll(req.assetIds);
        if (req.assetId != null && !selectedAssets.contains(req.assetId)) selectedAssets.add(req.assetId);

        Id primaryAssetId = selectedAssets.isEmpty() ? null : selectedAssets[0];

        Case c = new Case();
        c.AccountId = resolvedAccountId;
        c.ContactId = resolvedContactId;

        if (primaryAssetId != null) {
            c.AssetId = primaryAssetId;
        }

        c.Subject = req.subject;
        c.Description = req.description;
        c.Origin = req.origin;
        c.Status = String.isBlank(req.status) ? 'New' : req.status;

        if (!String.isBlank(req.complaintType))       c.Complaint_Type__c = req.complaintType;
        if (!String.isBlank(req.otherComplaintType))  c.Other_Complain_Type__c = req.otherComplaintType;

        if (!String.isBlank(req.productCategory))      c.Product_Category__c = req.productCategory;
        if (!String.isBlank(req.otherProductCategory)) c.Other_Product_Category__c = req.otherProductCategory;
        if (!String.isBlank(req.vocText))              c.Voice_of_the_Customer_VOC__c = req.vocText;
        if (!String.isBlank(req.installerType))        c.Installer_Type__c = req.installerType;
        if (!String.isBlank(req.otherInstaller))       c.Other_Installer_Type__c = req.otherInstaller;
        if (!String.isBlank(req.customerPersona))      c.Customer_Persona__c = req.customerPersona;

        insert c;

        // only if assets selected
        if (!selectedAssets.isEmpty()) {
            createCaseRelatedAssets(c.Id, selectedAssets);
            createCaseAssetLinksIfSupported(c.Id, selectedAssets);
        }

        return c.Id;
    }

    // Wrapper method with parameters
    @AuraEnabled
    public static Id createCase2(
        Id accountId,
        Id contactId,
        Id assetId,
        List<Id> assetIds,
        String subject,
        String description,
        String complaintType,
        String status,
        String origin,
        String productCategory,
        String otherProductCategory,
        String vocText,
        String installerType,
        String otherInstaller,
        String customerPersona,
        String otherComplaintType,

        // NEW
        Boolean createNewAccountContact,
        String newAccountName,
        String newAccountPhone,
        String newAccountBillingCity,
        String newAccountBillingState,
        String newAccountBillingStreet,
        String newAccountBillingPostalCode,
        String newAccountBillingCountry,
        String newContactFirstName,
        String newContactLastName,
        String newContactPhone,
        String newContactMobilePhone,
        String newContactEmail,
        String newContactDepartment,
        String newContactDesignation
    ) {
        CaseCreateRequest req = new CaseCreateRequest();
        req.accountId = accountId;
        req.contactId = contactId;
        req.assetId = assetId;
        req.assetIds = assetIds;
        req.subject = subject;
        req.description = description;
        req.complaintType = complaintType;
        req.status = status;
        req.origin = origin;
        req.productCategory = productCategory;
        req.otherProductCategory = otherProductCategory;
        req.vocText = vocText;
        req.installerType = installerType;
        req.otherInstaller = otherInstaller;
        req.customerPersona = customerPersona;
        req.otherComplaintType = otherComplaintType;

        req.createNewAccountContact = createNewAccountContact;
        req.newAccountName = newAccountName;
        req.newAccountPhone = newAccountPhone;
        req.newAccountBillingCity = newAccountBillingCity;
        req.newAccountBillingState = newAccountBillingState;
        req.newAccountBillingStreet = newAccountBillingStreet;
        req.newAccountBillingPostalCode = newAccountBillingPostalCode;
        req.newAccountBillingCountry = newAccountBillingCountry;
        req.newContactFirstName = newContactFirstName;
        req.newContactLastName = newContactLastName;
        req.newContactPhone = newContactPhone;
        req.newContactMobilePhone = newContactMobilePhone;
        req.newContactEmail = newContactEmail;
        req.newContactDepartment = newContactDepartment;
        req.newContactDesignation = newContactDesignation;

        return createCase(req);
    }

    // Save ALL selected assets into Case_Related_Assets__c
    private static void createCaseRelatedAssets(Id caseId, List<Id> assetIds) {
        if (caseId == null || assetIds == null || assetIds.isEmpty()) return;

        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        if (!g.containsKey('Case_Related_Assets__c')) return;

        Schema.SObjectType t = g.get('Case_Related_Assets__c');
        Map<String, Schema.SObjectField> fMap = t.getDescribe().fields.getMap();

        if (!fMap.containsKey('Case__c') || !fMap.containsKey('Asset__c')) return;

        Set<Id> uniqueAssetIds = new Set<Id>(assetIds);

        Set<Id> alreadyLinked = new Set<Id>();
        for (Case_Related_Assets__c r : [
            SELECT Asset__c
            FROM Case_Related_Assets__c
            WHERE Case__c = :caseId
              AND Asset__c IN :uniqueAssetIds
        ]) {
            alreadyLinked.add(r.Asset__c);
        }

        List<SObject> rows = new List<SObject>();
        for (Id aId : uniqueAssetIds) {
            if (alreadyLinked.contains(aId)) continue;

            SObject r = t.newSObject();
            r.put('Case__c', caseId);
            r.put('Asset__c', aId);
            rows.add(r);
        }

        if (!rows.isEmpty()) {
            try { insert rows; } catch (Exception e) { }
        }
    }

    // Generic junction creator
    private static void createCaseAssetLinksIfSupported(Id caseId, List<Id> assetIds) {
        if (caseId == null || assetIds == null || assetIds.isEmpty()) return;

        List<String> objCandidates = new List<String>{
            'Case_Asset__c', 'CaseAsset__c', 'Case_Assets__c', 'Case_Asset_Link__c'
        };

        String foundObj;
        Map<String, Schema.SObjectType> g = Schema.getGlobalDescribe();
        for (String o : objCandidates) {
            if (g.containsKey(o)) { foundObj = o; break; }
        }
        if (String.isBlank(foundObj)) return;

        Schema.SObjectType t = g.get(foundObj);
        Map<String, Schema.SObjectField> fMap = t.getDescribe().fields.getMap();

        String caseField  = firstExisting(fMap, new List<String>{'Case__c','CaseId__c','Case_Id__c','CaseId'});
        String assetField = firstExisting(fMap, new List<String>{'Asset__c','AssetId__c','Asset_Id__c','AssetId'});

        if (String.isBlank(caseField) || String.isBlank(assetField)) return;

        Set<Id> uniq = new Set<Id>(assetIds);

        Set<Id> alreadyLinked = new Set<Id>();
        try {
            String soql =
                'SELECT ' + assetField +
                ' FROM ' + foundObj +
                ' WHERE ' + caseField + ' = :caseId' +
                ' AND ' + assetField + ' IN :uniq';
            for (SObject r : Database.query(soql)) {
                Id aId = (Id) r.get(assetField);
                if (aId != null) alreadyLinked.add(aId);
            }
        } catch (Exception e) {
        }

        List<SObject> rows = new List<SObject>();
        for (Id aId : uniq) {
            if (alreadyLinked.contains(aId)) continue;

            SObject r = t.newSObject();
            r.put(caseField, caseId);
            r.put(assetField, aId);
            rows.add(r);
        }

        try { if (!rows.isEmpty()) insert rows; } catch (Exception e) { }
    }

    private static String firstExisting(Map<String, Schema.SObjectField> fieldsMap, List<String> names) {
        for (String n : names) if (fieldsMap.containsKey(n)) return n;
        return null;
    }

    // ---------------- NEW: Set Account Status = Draft ----------------
    private static void setAccountDraftStatus(Account acc) {
        if (acc == null) return;

        Map<String, Schema.SObjectField> fMap = Account.SObjectType.getDescribe().fields.getMap();

        List<String> candidateFields = new List<String>{
            'Account_Status__c',
            'Customer_Status__c',
            'Status__c'
        };

        for (String fieldApi : candidateFields) {
            if (fMap.containsKey(fieldApi)) {
                try {
                    acc.put(fieldApi, 'Draft');
                    return;
                } catch (Exception e) {
                }
            }
        }
    }

    // ---------------- Search Implementations ----------------
    private static SearchResponse searchByContactPhone(String digits) {
        if (String.isBlank(digits)) return null;

        List<Contact> hits = [
            SELECT Id, AccountId
            FROM Contact
            WHERE AccountId != null
              AND (MobilePhone LIKE :('%' + digits + '%') OR Phone LIKE :('%' + digits + '%'))
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (hits.isEmpty() || hits[0].AccountId == null) return null;

        SearchResponse resp = buildResponseFromAccountId(hits[0].AccountId, 'ContactPhone');
        resp.accountResults = new List<AccountDTO>();
        return resp;
    }

    private static SearchResponse searchByAccountName(String t) {
        String likeT = '%' + t + '%';

        List<Account> accHits = [
            SELECT Id, Name, Phone, BillingCity, BillingState, LastModifiedDate
            FROM Account
            WHERE Name LIKE :likeT
            LIMIT 50
        ];
        if (accHits.isEmpty()) return null;

        Account best = pickBestAccountMatch(accHits, t);

        SearchResponse resp = buildResponseFromAccountId(best.Id, 'Account');
        resp.accountResults = new List<AccountDTO>();
        for (Account a : accHits) resp.accountResults.add(toAccountDTO(a));
        return resp;
    }

    private static SearchResponse searchByAssetSerialOrInvoice(String raw, String digits) {
        String likeRaw = '%' + raw + '%';
        String likeDigits = (String.isBlank(digits) ? null : ('%' + digits + '%'));

        List<Asset> astHits;
        if (!String.isBlank(likeDigits)) {
            astHits = [
                SELECT Id, AccountId
                FROM Asset
                WHERE AccountId != null
                  AND (
                      SerialNumber LIKE :likeRaw
                      OR Invoice_Number__c LIKE :likeRaw
                      OR SerialNumber LIKE :likeDigits
                      OR Invoice_Number__c LIKE :likeDigits
                  )
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
        } else {
            astHits = [
                SELECT Id, AccountId
                FROM Asset
                WHERE AccountId != null
                  AND (SerialNumber LIKE :likeRaw OR Invoice_Number__c LIKE :likeRaw)
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
        }

        if (astHits.isEmpty() || astHits[0].AccountId == null) return null;

        SearchResponse resp = buildResponseFromAccountId(astHits[0].AccountId, 'Asset');
        resp.accountResults = new List<AccountDTO>();
        return resp;
    }

    // ---------------- Response Builder ----------------
    private static SearchResponse buildResponseFromAccountId(Id accountId, String matchedBy) {
        Account acc = [
            SELECT Id, Name, Phone, BillingCity, BillingState
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        List<Contact> relContacts = [
            SELECT Id, Name, MobilePhone, Phone, Email, AccountId, Account.Name
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];

        List<Asset> relAssets = [
            SELECT Id, Name, SerialNumber, Product2.Name, AccountId, Account.Name,
                   ContactId, Contact.Name, Invoice_Number__c
            FROM Asset
            WHERE AccountId = :accountId
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];

        SearchResponse resp = new SearchResponse();
        resp.account = toAccountDTO(acc);
        resp.contacts = new List<ContactDTO>();
        resp.assets = new List<AssetDTO>();
        resp.accountResults = new List<AccountDTO>();
        resp.matchedBy = matchedBy;

        for (Contact c : relContacts) resp.contacts.add(toContactDTO(c));
        for (Asset a : relAssets) resp.assets.add(toAssetDTO(a));

        return resp;
    }

    private static SearchResponse emptyResponse() {
        SearchResponse r = new SearchResponse();
        r.account = null;
        r.accountResults = new List<AccountDTO>();
        r.contacts = new List<ContactDTO>();
        r.assets = new List<AssetDTO>();
        r.matchedBy = 'None';
        return r;
    }

    // ---------------- Picklist Helper ----------------
    private static List<PickVal> picklistOptions(Schema.SObjectField f) {
        List<PickVal> out = new List<PickVal>();
        Schema.DescribeFieldResult d = f.getDescribe();
        for (Schema.PicklistEntry p : d.getPicklistValues()) {
            if (p.isActive()) out.add(new PickVal(p.getLabel(), p.getValue()));
        }
        return out;
    }

    // ---------------- Ranking Helpers ----------------
    private static Account pickBestAccountMatch(List<Account> hits, String term) {
        String termN = normalizeText(term);

        Account best;
        Integer bestScore = 999999;
        Integer bestLen = 999999;
        Datetime bestLmd;

        for (Account a : hits) {
            String nameN = normalizeText(a.Name);

            Integer score;
            if (nameN == termN) score = 0;
            else if (nameN.startsWith(termN)) score = 1;
            else if (nameN.contains(termN)) score = 2;
            else score = 3;

            Integer len = (a.Name == null) ? 999999 : a.Name.length();
            Datetime lmd = a.LastModifiedDate;

            if (best == null
                || score < bestScore
                || (score == bestScore && len < bestLen)
                || (score == bestScore && len == bestLen && lmd > bestLmd)
            ) {
                best = a;
                bestScore = score;
                bestLen = len;
                bestLmd = lmd;
            }
        }
        return best;
    }

    private static String normalizeText(String s) {
        if (String.isBlank(s)) return '';
        String x = s.trim().toLowerCase();
        x = x.replaceAll('\\s+', ' ');
        return x;
    }

    // ---------------- Pattern Helpers ----------------
    private static String onlyDigits(String s) {
        if (String.isBlank(s)) return null;
        String out = '';
        for (Integer i = 0; i < s.length(); i++) {
            String ch = s.substring(i, i+1);
            if (ch >= '0' && ch <= '9') out += ch;
        }
        return out;
    }

    private static Boolean isMostlyPhoneChars(String raw) {
        String cleaned = raw.replaceAll('[0-9\\s\\+\\-\\(\\)]', '');
        return String.isBlank(cleaned);
    }

    private static Boolean isLikelyAssetKey(String raw, String digits, Boolean looksLikePhone) {
        if (String.isBlank(raw)) return false;
        if (looksLikePhone) return false;

        Boolean hasLetter = raw.toLowerCase() != raw.toUpperCase();
        Boolean hasDigit  = !String.isBlank(digits);

        if (hasLetter && hasDigit) return true;
        if (raw.contains('-') || raw.contains('/') || raw.contains('_')) return true;
        if (!String.isBlank(digits) && digits.length() >= 12) return true;
        return false;
    }

    // ---------------- DTO Mappers ----------------
    private static AccountDTO toAccountDTO(Account a) {
        AccountDTO d = new AccountDTO();
        d.id = a.Id;
        d.name = a.Name;
        d.phone = a.Phone;
        d.billingCity = a.BillingCity;
        d.billingState = a.BillingState;
        return d;
    }

    private static ContactDTO toContactDTO(Contact c) {
        ContactDTO d = new ContactDTO();
        d.id = c.Id;
        d.name = c.Name;
        d.mobilePhone = c.MobilePhone;
        d.phone = c.Phone;
        d.email = c.Email;
        d.accountId = c.AccountId;
        d.accountName = (c.Account != null ? c.Account.Name : null);
        return d;
    }

    private static AssetDTO toAssetDTO(Asset a) {
        AssetDTO d = new AssetDTO();
        d.id = a.Id;
        d.name = a.Name;
        d.serialNumber = a.SerialNumber;
        d.productName = (a.Product2 != null ? a.Product2.Name : null);
        d.invoiceNumber = (String)a.get('Invoice_Number__c');
        d.accountId = a.AccountId;
        d.accountName = (a.Account != null ? a.Account.Name : null);
        d.contactId = a.ContactId;
        d.contactName = (a.Contact != null ? a.Contact.Name : null);
        return d;
    }
}
@isTest
private class API_ctrl_OrderPoAttachmentControllerTest {

    private class SuccessXmlMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/xml');
            res.setBody(
                '<response>' +
                    '<MESSAGE>PO uploaded successfully</MESSAGE>' +
                    '<DMS_DOCUMENT_NO>DMS-12345</DMS_DOCUMENT_NO>' +
                '</response>'
            );
            return res;
        }
    }

    private class SuccessXmlNoMessageMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/xml');
            res.setBody(
                '<response>' +
                    '<DMS_DOCUMENT_NO>DMS-99999</DMS_DOCUMENT_NO>' +
                '</response>'
            );
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/xml');
            res.setBody(
                '<response>' +
                    '<MESSAGE>Server error</MESSAGE>' +
                '</response>'
            );
            return res;
        }
    }

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact billToContact = new Contact(
            LastName = 'Bill To',
            AccountId = acc.Id
        );
        insert billToContact;

        Contact shipToContact = new Contact(
            LastName = 'Ship To',
            AccountId = acc.Id
        );
        insert shipToContact;

        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 500,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        Order goodOrder = buildOrder(
            'ORD-PO-001',
            acc.Id,
            billToContact.Id,
            shipToContact.Id,
            stdPbId,
            'SO-123456',
            'PO-001',
            true
        );
        insert goodOrder;

        Order blankSapOrder = buildOrder(
            'ORD-PO-002',
            acc.Id,
            billToContact.Id,
            shipToContact.Id,
            stdPbId,
            null,
            'PO-002',
            false
        );
        insert blankSapOrder;

        createLinkedFile(goodOrder.Id, 'PO_Success');
        createLinkedFile(blankSapOrder.Id, 'PO_Blank_SAP');
    }

    @isTest
    static void testUploadNullOrderId() {
        Boolean caught = false;
        try {
            Test.startTest();
            API_ctrl_OrderPoAttachmentController.uploadPoToSap(null, null);
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Integer flag = caught ? 1 : 0;
    }

    @isTest
    static void testUploadNullFileId() {
        Order ord = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-001'
            LIMIT 1
        ];

        Boolean caught = false;
        try {
            Test.startTest();
            API_ctrl_OrderPoAttachmentController.uploadPoToSap(ord.Id, null);
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Integer flag = caught ? 1 : 0;
    }

    @isTest
    static void testUploadBlankSapOrderId() {
        Order ord = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-002'
            LIMIT 1
        ];

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ord.Id
            LIMIT 1
        ];

        Boolean caught = false;
        try {
            Test.startTest();
            API_ctrl_OrderPoAttachmentController.uploadPoToSap(ord.Id, cdl.ContentDocumentId);
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Integer flag = caught ? 1 : 0;
    }

    @isTest
    static void testUploadSuccess() {
        Order ord = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-001'
            LIMIT 1
        ];

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ord.Id
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new SuccessXmlMock());

        Test.startTest();
        API_ctrl_OrderPoAttachmentController.SapPoAttachmentResponse resp =
            API_ctrl_OrderPoAttachmentController.uploadPoToSap(ord.Id, cdl.ContentDocumentId);
        Test.stopTest();

        Integer msgLen = resp.message == null ? 0 : resp.message.length();
        Integer fileNameLen = resp.fileName == null ? 0 : resp.fileName.length();
        Integer soDescLen = resp.soDescription == null ? 0 : resp.soDescription.length();
        Integer soNumLen = resp.soNumber == null ? 0 : resp.soNumber.length();
    }

    @isTest
    static void testUploadSuccessDefaultMessage() {
        Order ord = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-001'
            LIMIT 1
        ];

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ord.Id
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new SuccessXmlNoMessageMock());

        Test.startTest();
        API_ctrl_OrderPoAttachmentController.SapPoAttachmentResponse resp =
            API_ctrl_OrderPoAttachmentController.uploadPoToSap(ord.Id, cdl.ContentDocumentId);
        Test.stopTest();

        Integer msgLen = resp.message == null ? 0 : resp.message.length();
    }

    @isTest
    static void testUploadHttpFailure() {
        Order ord = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-001'
            LIMIT 1
        ];

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ord.Id
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Boolean caught = false;
        try {
            Test.startTest();
            API_ctrl_OrderPoAttachmentController.uploadPoToSap(ord.Id, cdl.ContentDocumentId);
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Integer flag = caught ? 1 : 0;

        List<Integration_Error_Log__c> logs = [
            SELECT Id
            FROM Integration_Error_Log__c
            WHERE API_Name__c = 'SAP PO Attachment API'
        ];
        Integer logCount = logs.size();
    }

    @isTest
    static void testRemoveUploadedFileSuccess() {
        Order ord = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-001'
            LIMIT 1
        ];

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ord.Id
            LIMIT 1
        ];

        Test.startTest();
        API_ctrl_OrderPoAttachmentController.removeUploadedFile(ord.Id, cdl.ContentDocumentId);
        Test.stopTest();

        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdl.ContentDocumentId
        ];
    }

    @isTest
    static void testRemoveUploadedFileNotAttached() {
        Order ord = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-002'
            LIMIT 1
        ];

        Order otherOrder = [
            SELECT Id
            FROM Order
            WHERE OrderReferenceNumber = 'ORD-PO-001'
            LIMIT 1
        ];

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :otherOrder.Id
            LIMIT 1
        ];

        Boolean caught = false;
        try {
            Test.startTest();
            API_ctrl_OrderPoAttachmentController.removeUploadedFile(ord.Id, cdl.ContentDocumentId);
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Integer flag = caught ? 1 : 0;
    }

    @isTest
    static void testRemoveUploadedFileNullInputs() {
        Boolean caught = false;
        try {
            Test.startTest();
            API_ctrl_OrderPoAttachmentController.removeUploadedFile(null, null);
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
        }
        Integer flag = caught ? 1 : 0;
    }

    private static Order buildOrder(
        String orderRef,
        Id accountId,
        Id billToContactId,
        Id shipToContactId,
        Id pricebook2Id,
        String salesOrderValue,
        String poNumber,
        Boolean includeSalesOrder
    ) {
        Order ord = new Order(
            Name = 'Test Order ' + orderRef,
            OrderReferenceNumber = orderRef,
            AccountId = accountId,
            Bill_To__c = accountId,
            BillToContactId = billToContactId,
            Contact__c = billToContactId,
            CustomerAuthorizedById = billToContactId,
            EffectiveDate = Date.today(),
            Pricebook2Id = pricebook2Id,
            Ship_To__c = accountId,
            ShipToContactId = shipToContactId,
            Status = getPicklistValue(Order.Status, 'Draft'),
            Customer_Reference__c = poNumber,
            Customer_Reference_Date__c = Date.today(),
            InCoTerms__c = 'FOB',
            Sales_Office__c = 'SO1',
            Sales_Group__c = 'SG1',
            SAP_Employee_Code__c = 'EMP001',
            Delivering_Plant__c = 'PLANT1',
            Freight_Terms__c = 'FREIGHT',
            Insurance_Terms__c = 'INS',
            Scope_Of_OA__c = 'SCOPE-1',
            Dist_Chan__c = '10',
            Division_Text__c = '01',
            PoNumber = poNumber,
            PoDate = Date.today(),
            BG_Required__c = getFirstActivePicklistValue(Order.BG_Required__c),
            LD_Clause__c = getFirstActivePicklistValue(Order.LD_Clause__c),
            TPC__c = getFirstActivePicklistValue(Order.TPC__c),
            Type__c = getPicklistValue(Order.Type__c, 'New Business')
            //UOM__c = 'KW'
        );

        if (includeSalesOrder && String.isNotBlank(salesOrderValue)) {
            ord.Sales_Order__c = salesOrderValue;
        }

        return ord;
    }

    private static void createLinkedFile(Id orderId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('Test file content for PO attachment')
        );
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        insert new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = orderId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    private static String getFirstActivePicklistValue(Schema.SObjectField fieldToken) {
        List<Schema.PicklistEntry> values = fieldToken.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static String getPicklistValue(Schema.SObjectField fieldToken, String preferredValue) {
        List<Schema.PicklistEntry> values = fieldToken.getDescribe().getPicklistValues();

        if (String.isNotBlank(preferredValue)) {
            for (Schema.PicklistEntry pe : values) {
                if (pe.isActive() && pe.getValue() == preferredValue) {
                    return pe.getValue();
                }
            }
        }

        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }
}
@IsTest
private class LeadEmailServiceHandlerTest {

    @IsTest
    static void testHandleInboundEmail() {

        // Create instance of handler
        LeadEmailServiceHandler handler = new LeadEmailServiceHandler();

        // Create mock inbound email
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        // Set email details
        email.fromAddress = 'testuser@example.com';
        email.fromName = 'Test User';
        email.subject = 'Test Subject';
        email.plainTextBody = 'This is a test email body';

        // -------------------------
        // Add Binary Attachment
        // -------------------------
        Messaging.InboundEmail.BinaryAttachment binAttach = new Messaging.InboundEmail.BinaryAttachment();
        binAttach.fileName = 'testFile.pdf';
        binAttach.body = Blob.valueOf('Test Binary Data');

        email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{ binAttach };

        // -------------------------
        // Add Text Attachment
        // -------------------------
        Messaging.InboundEmail.TextAttachment txtAttach = new Messaging.InboundEmail.TextAttachment();
        txtAttach.fileName = 'testFile.txt';
        txtAttach.body = 'Test Text Data';

        email.textAttachments = new List<Messaging.InboundEmail.TextAttachment>{ txtAttach };

        // -------------------------
        // Execute
        // -------------------------
        Test.startTest();
        handler.handleInboundEmail(email, envelope);
        Test.stopTest();
    }

    @IsTest
    static void testHandleInboundEmail_NoAttachments() {

        LeadEmailServiceHandler handler = new LeadEmailServiceHandler();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        email.fromAddress = 'noattach@example.com';
        email.fromName = 'No Attachment User';
        email.subject = 'No Attachment Email';
        email.plainTextBody = 'Email without attachments';

        Test.startTest();
        handler.handleInboundEmail(email, envelope);
        Test.stopTest();
    }

    @IsTest
    static void testHandleInboundEmail_OnlyHtmlBody() {

        LeadEmailServiceHandler handler = new LeadEmailServiceHandler();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();

        email.fromAddress = 'html@example.com';
        email.fromName = 'HTML User';
        email.subject = 'HTML Email';
        email.plainTextBody = null;
        email.htmlBody = '<h1>HTML Body</h1>';

        Test.startTest();
        handler.handleInboundEmail(email, envelope);
        Test.stopTest();
    }
}
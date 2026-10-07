@IsTest
private class Ctrl_MediaUploadTest {

    @TestSetup
    static void setupTestData() {
        // Create a parent record to attach the file to (FirstPublishLocationId)
        Account testAccount = new Account(Name = 'Test Media Parent');
        insert testAccount;
    }

    @IsTest
    static void testUploadSingleFile_Success() {
        // Retrieve the test account
        Account testAcc = [SELECT Id FROM Account LIMIT 1];
        
        // Define mock file data
        String fileName = 'test_document.txt';
        String plainTextContent = 'This is a test file content.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(plainTextContent));

        Test.startTest();
        // Execute the method
        Ctrl_MediaUpload.uploadSingleFile(testAcc.Id, fileName, base64Data);
        Test.stopTest();

        // 1. Verify the ContentVersion was created correctly
        List<ContentVersion> cvList = [
            SELECT Id, Title, PathOnClient, VersionData 
            FROM ContentVersion 
            WHERE Title = :fileName
        ];
        System.assertEquals(1, cvList.size(), 'One ContentVersion record should be created.');
        System.assertEquals(fileName, cvList[0].PathOnClient, 'PathOnClient should match the file name.');
        System.assertEquals(plainTextContent, cvList[0].VersionData.toString(), 'File content should match the decoded data.');
        
        // 2. Verify it was automatically linked to the parent record
        List<ContentDocumentLink> cdlList = [
            SELECT Id, LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :testAcc.Id
        ];
        System.assertEquals(1, cdlList.size(), 'A ContentDocumentLink should have been generated for the Account.');
    }

    @IsTest
    static void testUploadSingleFile_Exception() {
        // Retrieve the test account
        Account testAcc = [SELECT Id FROM Account LIMIT 1];
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            // Passing null for base64Data will trigger a System.NullPointerException 
            // inside EncodingUtil.base64Decode(), forcing it into your catch block.
            Ctrl_MediaUpload.uploadSingleFile(testAcc.Id, 'error_test.txt', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // Workaround for Salesforce quirk: AuraHandledExceptions in tests 
            // always return 'Script-thrown exception' as the message.
            System.assertEquals('Script-thrown exception', e.getMessage(), 'AuraHandledException message wrapper check');
        }
        Test.stopTest();

        // Assert that the catch block was successfully reached
        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown due to null base64 data.');
    }
}
public with sharing class Ctrl_MediaUpload {
    @AuraEnabled
    public static void uploadSingleFile(Id recordId, String filename, String base64Data) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = filename;
            cv.PathOnClient = filename;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = recordId;
            insert cv;
        } catch (Exception e) {
            throw new AuraHandledException('Error uploading ' + filename + ': ' + e.getMessage());
        }
    }
}
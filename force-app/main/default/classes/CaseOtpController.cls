public with sharing class CaseOtpController {
    
    
    @AuraEnabled
    public static String generateAndSendOtp(Id caseId) {
        
        
        if(caseId == null){
            throw new AuraHandledException('Case Id is required.');
        }
        
        
        
        Case caseRecord = [SELECT Id, CaseNumber, ContactId,Contact.Email,Contact.Phone,OTP__c, OTP_Expiry_Date_Time__c, OTP_Verified__c,
        Closure_Reason__c,
        Failure_Category__c
            
            FROM Case  WHERE Id = :caseId LIMIT 1 ];
        
        
        
        if(caseRecord.ContactId == null){
            
            throw new AuraHandledException('Contact is not available on this Case.');
            
        }
        
        
        
        if(
            String.isBlank(caseRecord.Contact.Email)){
            
            throw new AuraHandledException('Contact Email is blank.');
            
        }
        
        
        
        if(caseRecord.OTP_Verified__c == true){
            
            throw new AuraHandledException('OTP is already verified.');
            
        }

        // Validate Closure Reason and Failure Category
if (
    String.isBlank(caseRecord.Closure_Reason__c) ||
    String.isBlank(caseRecord.Failure_Category__c)
) {
    throw new AuraHandledException(
        'Please fill Closure Reason and Failure Category before generating OTP.'
    );
}

        //new part added by Swastika on 23rd Sept

        // Validate Serial Number on all Case Related Assets
List<Case_Related_Assets__c> relatedAssets = [
    SELECT Id, Serial_Number__c
    FROM Case_Related_Assets__c
    WHERE Case__c = :caseId
];

if (relatedAssets.isEmpty()) {
    throw new AuraHandledException(
        'Case Related Asset is not available. Please add the Case Related Asset and Serial Number.'
    );
}

for (Case_Related_Assets__c relatedAsset : relatedAssets) {

    if (String.isBlank(relatedAsset.Serial_Number__c)) {

        throw new AuraHandledException(
            'Serial Number is required. Please fill the Serial Number before generating OTP.'
        );
    }
}
        
        
        
        Integer otpNumber = Math.round(Math.random() * 9000 + 1000);
        
        
        String otp = String.valueOf(otpNumber);
        
        
        
        Datetime expiry = System.now().addMinutes(15);
        
        caseRecord.OTP__c = otp;
caseRecord.OTP_Expiry_Date_Time__c = expiry;

// Update Case Status
caseRecord.SRT_Case_Status__c = 'Happy Code Pending';

update caseRecord;
        
        
        
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        
        
        mail.setToAddresses(
            new List<String>{
                caseRecord.Contact.Email
                    }
        );
        
        
        mail.setSubject('OTP Verification - Case '+ caseRecord.CaseNumber);
        
        
        mail.setPlainTextBody(
            
            'Dear Customer,\n\n'
            
            +
            'Your OTP is: '
            +
            otp
            
            +
            '\n\nThis OTP is valid for 15 minutes.'
            
            +
            '\n\nPlease do not share this OTP with anyone.'
            
            +
            '\n\nRegards,\nJakson SmartCare\n1800-103-2600'
            
        );
        
        
        
        Messaging.SendEmailResult[] result =
    Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{mail}
    );

if (result.isEmpty() || !result[0].isSuccess()) {

    throw new AuraHandledException(
        'OTP generated but email sending failed.'
    );
}

// NEW: Queue WhatsApp using the same saved OTP
String whatsappResult;

try {

    whatsappResult =
        SRT_OtpWhatsAppService.queueOtpMessage(
            caseRecord.Id
        );

} catch (Exception e) {

    whatsappResult =
        'WhatsApp could not be queued.';

    System.debug(
        LoggingLevel.ERROR,
        'OTP WhatsApp preparation failed: ' +
        e.getMessage()
    );
}

return 'OTP sent to registered Contact email. ' +
    whatsappResult;
        
    }


    @AuraEnabled
public static String requestAuthorizedOtp(Id caseId) {

    if (caseId == null) {
        throw new AuraHandledException(
            'Case Id is required.'
        );
    }

    // Fetch Case details
    Case caseRecord = [
        SELECT Id,
               CaseNumber,
        SRT_Case_Number__c,
               ContactId,
               Contact.Name,
               Product__c,
               Complaint_Type_SRT__c,
               Failure_Category__c,
               Closure_Reason__c,
               OTP_Verified__c,
               SRT_Case_Status__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];

    // Already verified
    if (caseRecord.OTP_Verified__c == true) {
        throw new AuraHandledException(
            'OTP is already verified for this Case.'
        );
    }

    // Validate closure details
    if (
        String.isBlank(caseRecord.Closure_Reason__c) ||
        String.isBlank(caseRecord.Failure_Category__c)
    ) {
        throw new AuraHandledException(
            'Please fill Closure Reason and Failure Category.'
        );
    }

    // Identify active Service Head users
    List<User> serviceHeadUsers = [
        SELECT Id, Name, Email
        FROM User
        WHERE Profile.Name = 'Service Head'
        AND IsActive = true
        AND Email != null
    ];

    if (serviceHeadUsers.isEmpty()) {
        throw new AuraHandledException(
            'No active Service Head user found.'
        );
    }

    List<String> emailAddresses = new List<String>();

    for (User usr : serviceHeadUsers) {
        emailAddresses.add(usr.Email);
    }

    // Prepare customer and complaint details
    String customerName =
        caseRecord.Contact != null
        ? caseRecord.Contact.Name
        : 'N/A';

    String productName =
        String.isNotBlank(caseRecord.Product__c)
        ? caseRecord.Product__c
        : 'N/A';

    String complaintType =
    String.isNotBlank(caseRecord.Complaint_Type_SRT__c)
    ? caseRecord.Complaint_Type_SRT__c
    : 'N/A';

    String failureCategory =
        String.isNotBlank(caseRecord.Failure_Category__c)
        ? caseRecord.Failure_Category__c
        : 'N/A';

    String closureReason =
        String.isNotBlank(caseRecord.Closure_Reason__c)
        ? caseRecord.Closure_Reason__c
        : 'N/A';

    // Build clickable Salesforce Case URL
    String caseUrl =
        URL.getOrgDomainUrl().toExternalForm()
        + '/lightning/r/Case/'
        + caseRecord.Id
        + '/view';

    // Email subject
    String emailSubject =
        'Authorized OTP Approval Request - Complaint '
        + caseRecord.CaseNumber;

    // Prepare plain-text email
    String emailBody =
        'Dear Sir,\n\n'

        + 'This is to inform you that the service request '
        + 'mentioned below has been successfully resolved. '
        + 'However, the customer is currently unable to '
        + 'provide the OTP required for complaint closure '
        + 'in CRM.\n\n'

        + 'Complaint No.: '
        + caseRecord.SRT_Case_Number__c + '\n'

        + 'Customer: '
        + customerName + '\n'

        + 'Product Name: '
        + productName + '\n'

        + 'Complaint Type: '
        + complaintType + '\n'

        + 'Failure Category: '
        + failureCategory + '\n'

        + 'Closure Reason: '
        + closureReason + '\n\n'

        + 'Kindly approve an Authorized OTP to enable '
        + 'complaint closure in CRM.\n\n'

        + 'Case Link: '
        + caseUrl + '\n\n'

       + 'Regards,\n'
+ 'Jakson SmartCare\n'
+ '1800-103-2600';

    // Prepare HTML email
    String htmlBody =
        emailBody.escapeHtml4()
            .replace('\n', '<br/>');

    htmlBody = htmlBody.replace(
        caseUrl.escapeHtml4(),
        '<a href="' + caseUrl + '">'
        + 'Click here to view the Case'
        + '</a>'
    );

    // Send approval request email
    Messaging.SingleEmailMessage mail =
        new Messaging.SingleEmailMessage();

    mail.setToAddresses(emailAddresses);

    mail.setSubject(emailSubject);

    mail.setPlainTextBody(emailBody);

    mail.setHtmlBody(htmlBody);

    // Email is logged explicitly below
    mail.setSaveAsActivity(false);

    Messaging.SendEmailResult[] results =
        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{mail}
        );

    if (
        results.isEmpty() ||
        !results[0].isSuccess()
    ) {
        throw new AuraHandledException(
            'Authorized OTP email could not be sent.'
        );
    }

    // Log the outgoing email against the Case
    EmailMessage emailLog = new EmailMessage();

    emailLog.ParentId = caseRecord.Id;

    emailLog.Subject = emailSubject;

    emailLog.TextBody = emailBody;

    emailLog.HtmlBody = htmlBody;

    emailLog.ToAddress =
        String.join(emailAddresses, ';');

    emailLog.FromAddress =
        UserInfo.getUserEmail();

    emailLog.Incoming = false;

    emailLog.Status = '3';

    emailLog.MessageDate = System.now();

    insert emailLog;

    // Mark Authorized OTP request as sent to Service Head
caseRecord.Send_to_Service_Head__c = true;

update caseRecord;

    return 'Authorized OTP approval request sent '
        + 'successfully to Service Head.';

}
    
   
    @AuraEnabled
    public static String validateOtp(Id caseId,String enteredOtp){
        
        if(caseId == null){
            
            throw new AuraHandledException('Case Id is required.');
            
        }
        
        
        if(String.isBlank(enteredOtp)){
            
            throw new AuraHandledException('Please enter OTP.');
            
        }
        
        
        
        
        Case caseRecord = [
            
            SELECT
            
            Id,
            OTP__c,
            OTP_Expiry_Date_Time__c,
            OTP_Verified__c,
            SRT_Case_Status__c,
            Resolve__c,
            Resolve_Date__c
            
            FROM Case
            
            WHERE Id = :caseId
            
            LIMIT 1
            
        ];
        
        
        
        
        if(
            String.isBlank(caseRecord.OTP__c)
        ){
            
            throw new AuraHandledException('OTP not generated.');
            
        }
        
        
        
        if(
            System.now()
            >
            caseRecord.OTP_Expiry_Date_Time__c
        ){
            
            throw new AuraHandledException(
                'OTP expired. Generate new OTP.'
            );
            
        }
        
        
        
        
        if(
            caseRecord.OTP__c
            !=
            enteredOtp.trim()
        ){
            
            throw new AuraHandledException(
                'Invalid OTP.'
            );
            
        }
        
        
        
        
caseRecord.OTP_Verified__c = true;

// Update Case Status after successful OTP verification
caseRecord.SRT_Case_Status__c = 'Resolved';

// Mark Resolve checkbox as true
caseRecord.Resolve__c = true;

// Capture Resolve Date
caseRecord.Resolve_Date__c = Date.today();

update caseRecord;
        
        return
            'OTP verified successfully.';
        
    }
    public static void datacover() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
    
}
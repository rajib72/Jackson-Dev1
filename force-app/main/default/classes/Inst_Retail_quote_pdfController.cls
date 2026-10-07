public class Inst_Retail_quote_pdfController {
  

    public Quote quoteRecord { get; set; }
    public List<QuoteLineItem> qlineitem { get; set; }
    public List<ProductDetailRow> productRows { get; set; }
    public User ownerUser { get; set; }
    public Contact quoteContact { get; set; }

    public List<String> paymentTermsList { get; set; }
    public List<String> limitationList { get; set; }

    public Inst_Retail_quote_pdfController(ApexPages.StandardController controller) {
        Id quoteId = controller.getId();

        quoteRecord = new Quote();
        qlineitem = new List<QuoteLineItem>();
        productRows = new List<ProductDetailRow>();
        ownerUser = new User();
        quoteContact = new Contact();
        paymentTermsList = new List<String>();
        limitationList = new List<String>();

        if (quoteId == null) {
            return;
        }

        List<Quote> quoteList = [
            SELECT Id,
                   Name,
                   OwnerId,
                   ContactId,
                   OpportunityId,
                   Opportunity.Account.Name,
                   Commercial_offer_for__c,
                   GST__c,
                   Payment_Terms__c,
                   In_Co_terms__c,
                   Third_Party_Insurance__c,
                   Packing_Forwarding__c,
                   Unloading__c,
                   Claims_Damages__c,
                   QAP__c,
                   Limitation_of_Liability__c,
                   Cable_Length__c,
                   Offer_Validity__c,
                   Warranty__c,
                   Storage_Charges__c,
                   Deemed_MDCC__c,
                   Governing_Law_Jurisdiction__c,
                   CurrencyIsoCode,
                   Certificates__c,
                   Project_Capacity__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (!quoteList.isEmpty()) {
            quoteRecord = quoteList[0];
        } else {
            return;
        }

        if (quoteRecord.OwnerId != null) {
            List<User> ownerList = [
                SELECT Id, FirstName, LastName, Email, Phone, Title
                FROM User
                WHERE Id = :quoteRecord.OwnerId
                LIMIT 1
            ];
            if (!ownerList.isEmpty()) {
                ownerUser = ownerList[0];
            }
        }

        if (quoteRecord.ContactId != null) {
            List<Contact> contactList = [
                SELECT Id, FirstName, LastName, Email, MobilePhone
                FROM Contact
                WHERE Id = :quoteRecord.ContactId
                LIMIT 1
            ];
            if (!contactList.isEmpty()) {
                quoteContact = contactList[0];
            }
        }

        qlineitem = [
            SELECT Id,
                   QuoteId,
                   Module_Type__c,
                   Cell_Type__c,
                   Module_Technology__c,
                   Product_Rating_BIN__c,
                   Product_Sub_Type__c,
                   Warranty__c,
                   Quantity,
                   Sub_Total__c,
                   Cable_Length__c,
                   SortOrder,
                   CreatedDate,
                   Nos__c,
                   Product_Capacity__c,
                   UOM__c,
                   UnitPrice,
                   Total__c,
                   Grand_Total__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY SortOrder ASC, CreatedDate ASC
        ];

        Decimal gstPercent = getGstPercent();

        for (QuoteLineItem qli : qlineitem) {
            productRows.add(new ProductDetailRow(qli, gstPercent));
        }

        paymentTermsList = splitLines(quoteRecord.Payment_Terms__c);
        limitationList = splitLines(quoteRecord.Limitation_of_Liability__c);
    }
    
    private static final List<String> ones = new List<String>{
    'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
    'Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen',
    'Seventeen','Eighteen','Nineteen'
};

private static final List<String> tens = new List<String>{
    '','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'
};

private String convertAmountToWords(Decimal amount){

    Long rupees = amount.longValue();
    Integer paise = ((amount - rupees) * 100).setScale(0).intValue();

    String words = convertNumber(rupees) + ' Rupees';

    if(paise > 0){
        words += ' and ' + convertNumber(paise) + ' Paise';
    }

    words += ' Only';

    return words;
}

private String convertNumber(Long num){

    if(num == 0)
        return 'Zero';

    String result = '';

    if(num >= 10000000){
        result += convertNumber(num/10000000) + ' Crore ';
        num = Math.mod(num,10000000);
    }

    if(num >= 100000){
        result += convertNumber(num/100000) + ' Lakh ';
        num = Math.mod(num,100000);
    }

    if(num >= 1000){
        result += convertNumber(num/1000) + ' Thousand ';
        num = Math.mod(num,1000);
    }

    if(num >= 100){
        result += convertNumber(num/100) + ' Hundred ';
        num = Math.mod(num,100);
    }

    if(num > 0){
        if(result != '')
            result += '';

        if(num < 20)
            result += ones[(Integer)num];
        else{
            result += tens[(Integer)(num/10)];
            if(Math.mod(num,10) > 0)
                result += ' ' + ones[(Integer)Math.mod(num,10)];
        }
    }

    return result.trim();
}
    
    public Decimal getGrandTotal() {
    Decimal total = 0;

    for(ProductDetailRow row : productRows){
        if(row.grandTotal != null){
            total += row.grandTotal;
        }
    }

    return total;
}

    public String getGrandTotalInWords() {
    return convertAmountToWords(getGrandTotal());
}

    public class ProductDetailRow {
        public String materialDescription { get; set; }
        public Decimal nos { get; set; }
        public Decimal projectCapacity { get; set; }
        public String uom { get; set; }
        public Decimal priceWp { get; set; }
        public Decimal total { get; set; }
        public String gst { get; set; }
        public Decimal grandTotal { get; set; }

        public ProductDetailRow(QuoteLineItem qli, Decimal gstPercent) {
            List<String> parts = new List<String>();

            if (String.isNotBlank(qli.Product_Rating_BIN__c)) {
                parts.add(qli.Product_Rating_BIN__c + ' WP');
            }
            if (String.isNotBlank(qli.Module_Technology__c)) {
                parts.add(qli.Module_Technology__c);
            }
            if (String.isNotBlank(qli.Cable_Length__c)) {
                parts.add(qli.Cable_Length__c +' mm ' + '(Cable length)');
            }
            if (String.isNotBlank(qli.Product_Sub_Type__c)) {
                parts.add(qli.Product_Sub_Type__c);
            }
            if (String.isNotBlank(qli.Module_Type__c)) {
                parts.add(qli.Module_Type__c);
            }

            materialDescription = String.join(parts, ' - ');
            nos = qli.Nos__c;
            projectCapacity = qli.Product_Capacity__c;
            uom = qli.UOM__c;
            priceWp = qli.UnitPrice;
            total = qli.Total__c;
            gst = formatGst(gstPercent);
            grandTotal = qli.Grand_Total__c;
        }
    }

    private static Decimal getGstPercent() {
        List<GST__mdt> gstList = [
            SELECT DeveloperName, GST__c
            FROM GST__mdt
            WHERE DeveloperName = 'JAKSON_GST'
            LIMIT 1
        ];

        if (!gstList.isEmpty() && gstList[0].GST__c != null) {
            return gstList[0].GST__c * 100;
        }
        return 0;
    }

    private static String formatGst(Decimal gstPercent) {
        if (gstPercent == null) {
            return '0 %';
        }

        Decimal roundedValue = gstPercent.setScale(0);
        if (gstPercent == roundedValue) {
            return String.valueOf(roundedValue) + ' %';
        }

        return String.valueOf(gstPercent.setScale(2)) + ' %';
    }

    public List<String> splitLines(String inputText) {
        List<String> result = new List<String>();

        if (String.isBlank(inputText)) {
            return result;
        }

        String cleaned = inputText.replace('\r\n', '\n').replace('\r', '\n');
        List<String> rawLines = cleaned.split('\n');

        for (String line : rawLines) {
            if (line != null) {
                String trimmed = line.trim();
                if (!String.isBlank(trimmed)) {
                    trimmed = removeLeadingBullet(trimmed);
                    result.add(trimmed);
                }
            }
        }

        return result;
    }

    public String removeLeadingBullet(String value) {
        if (String.isBlank(value)) {
            return value;
        }

        String v = value.trim();

        while (
            v.startsWith('•') ||
            v.startsWith('-') ||
            v.startsWith('*') ||
            v.startsWith('✓')
        ) {
            v = v.substring(1).trim();
        }

        return v;
    }


}
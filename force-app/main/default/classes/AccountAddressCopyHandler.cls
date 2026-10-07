public class AccountAddressCopyHandler {
    
    public static void copyBillingToShipping(List<Account> accountList) {
        
        for (Account acc : accountList) {
            
            if (acc.Copy_Billing_Address_to_Shipping_Address__c == true) {
                
                acc.ShippingStreet     = acc.BillingStreet;
                acc.ShippingCity       = acc.BillingCity;
                acc.ShippingState      = acc.BillingState;
                acc.ShippingPostalCode = acc.BillingPostalCode;
                acc.ShippingCountry    = acc.BillingCountry;
            }
        }
    }
}
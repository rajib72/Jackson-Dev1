trigger AccountAddressCopyTrigger on Account (before insert, before update) {
    AccountAddressCopyHandler.copyBillingToShipping(Trigger.new);
}
trigger AccountBeforeUpdate on Account (before update) {
    for(integer i = 0; i < trigger.new.size(); i++)
    {
        if(
            (trigger.old[i].BillingStreet != trigger.new[i].BillingStreet ||
            trigger.old[i].BillingCity != trigger.new[i].BillingCity ||
            trigger.old[i].BillingState != trigger.new[i].BillingState ||
            trigger.old[i].BillingPostalCode != trigger.new[i].BillingPostalCode ||
            trigger.old[i].BillingCountry != trigger.new[i].BillingCountry)
            && trigger.old[i].BillingAddressValid__c == true
        ){
            trigger.new[i].BillingAddressValid__c = false;
        }

        if(
            (trigger.old[i].ShippingStreet != trigger.new[i].ShippingStreet ||
            trigger.old[i].ShippingCity != trigger.new[i].ShippingCity ||
            trigger.old[i].ShippingState != trigger.new[i].ShippingState ||
            trigger.old[i].ShippingPostalCode != trigger.new[i].ShippingPostalCode ||
            trigger.old[i].ShippingCountry != trigger.new[i].ShippingCountry)
            && trigger.old[i].ShippingAddressValid__c == true
        ){
            trigger.new[i].ShippingAddressValid__c = false;
        }
    }
}
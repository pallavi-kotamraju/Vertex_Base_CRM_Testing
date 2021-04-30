public with sharing class ValidateAndUpdateAddress {

	private Account acc;
    // public Id accId;
    private ApexPages.StandardController stdController;

    public ValidateAndUpdateAddress(ApexPages.StandardController stdController) {
        this.stdController = stdController;
        if (!Test.isRunningTest()) stdController.addFields(new List<String>{'BillingStreet', 'ShippingStreet'});
        this.acc = (Account)stdController.getRecord();
    }

    public Id getAcctId () {
        Account a = acc;
        return a.Id;
    }

    public PageReference ReturnRec () {
        PageReference pr = new PageReference ('/'+getAcctId());
        pr.setRedirect(true);
        return pr;
    }

    public String NameSpacePrefix { 

        get{
            if (NameSpacePrefix==null) {
                if (string.isNotEmpty(VertexCore.FetchNamespace())) {
                    NameSpacePrefix = VertexCore.FetchNamespace().left(VertexCore.FetchNamespace().length()-2);
                } else {
                    NameSpacePrefix = 'c';
                }
            }
            return NameSpacePrefix;
        }
        set;
    }

    public PageReference UpdateAddresses() {
        PageReference returnRef = stdController.view();

        VertexAddress__c billingAddress = new VertexAddress__c();
        billingAddress.Address1__c = acc.BillingStreet;
        billingAddress.City__c = acc.BillingCity;
        billingAddress.State__c = acc.BillingState;
        billingAddress.PostalCode__c = acc.BillingPostalCode;
        billingAddress.Country__c = acc.BillingCountry;

        VertexAddress__c newBillingAddress = new VertexAddress__c();
        // if the address is complete then make the callout to verify and correct it
        if (AddressIsComplete(billingAddress))
            newBillingAddress = VertexCore.validateAddressCallout(billingAddress);

        //  Don't change the address if they match or if it's not complete or failed validation entirely
        if (!AddressIsComplete(billingAddress) || newBillingAddress == null || newBillingAddress == new VertexAddress__c())
            billingAddress = null;
        else
            billingAddress = newBillingAddress;

        VertexAddress__c shippingAddress = new VertexAddress__c();
        shippingAddress.Address1__c = acc.ShippingStreet;
        shippingAddress.City__c = acc.ShippingCity;
        shippingAddress.State__c = acc.ShippingState;
        shippingAddress.PostalCode__c = acc.ShippingPostalCode;
        shippingAddress.Country__c = acc.ShippingCountry;

        VertexAddress__c newShippingAddress = new VertexAddress__c();
        // if the address is complete then make the callout to verify and correct it
        if (AddressIsComplete(shippingAddress))
            newShippingAddress = VertexCore.validateAddressCallout(shippingAddress);

        //  Don't change the address if they match or if it's not complete or failed validation entirely
        if (!AddressIsComplete(shippingAddress) || newShippingAddress == null || newShippingAddress == new VertexAddress__c())
            shippingAddress = null;
        else
            shippingAddress = newShippingAddress;

        //Make sure we have perms on relevant fields
        String missingPerms = '';

        // if at least one of the two addresses was updated then replace the account values and update the record
        if (billingAddress != null || shippingAddress != null) {
            String billingAddrStr;
            if (billingAddress != null) {
                acc.BillingStreet = String.isNotBlank(billingAddress.Address1__c) ? billingAddress.Address1__c : acc.BillingStreet;
                acc.BillingCity = String.isNotBlank(billingAddress.City__c) ? billingAddress.City__c : acc.BillingCity;
                acc.BillingState = String.isNotBlank(billingAddress.State__c) ? billingAddress.State__c : acc.BillingState;
                acc.BillingPostalCode = String.isNotBlank(billingAddress.PostalCode__c) ? billingAddress.PostalCode__c : acc.BillingPostalCode;
                acc.BillingCountry = String.isNotBlank(billingAddress.Country__c) ? billingAddress.Country__c : acc.BillingCountry;
                billingAddrStr = acc.BillingStreet + ', ' + acc.BillingCity + ', ' + acc.BillingState + ' ' + acc.BillingPostalCode + ' ' + acc.BillingCountry;
                missingPerms += HaveCRUDAndFLS(new Set<String>{'Account.BillingStreet', 'Account.BillingCity', 'Account.BillingState', 'Account.BillingPostalCode', 'Account.BillingCountry'});
            }

            String shippingAddrStr;
            if (shippingAddress != null) {
                acc.ShippingStreet = String.isNotBlank(shippingAddress.Address1__c) ? shippingAddress.Address1__c : acc.ShippingStreet;
                acc.ShippingCity = String.isNotBlank(shippingAddress.City__c) ? shippingAddress.City__c : acc.ShippingCity;
                acc.ShippingState = String.isNotBlank(shippingAddress.State__c) ? shippingAddress.State__c : acc.ShippingState;
                acc.ShippingPostalCode = String.isNotBlank(shippingAddress.PostalCode__c) ? shippingAddress.PostalCode__c : acc.ShippingPostalCode;
                acc.ShippingCountry = String.isNotBlank(shippingAddress.Country__c) ? shippingAddress.Country__c : acc.ShippingCountry;
                shippingAddrStr = acc.ShippingStreet + ', ' + acc.ShippingCity + ', ' + acc.ShippingState + ' ' + acc.ShippingPostalCode + ' ' + acc.ShippingCountry;
                missingPerms += HaveCRUDAndFLS(new Set<String>{'Account.ShippingStreet', 'Account.ShippingCity', 'Account.ShippingState', 'Account.ShippingPostalCode', 'Account.ShippingCountry'});
            }

            if (missingPerms == ''){
                update acc;
                String logMsg = '';
                if (billingAddrStr != null)
                    logMsg += 'Updating billing address: ' + billingAddrStr + '\n';
                if (shippingAddrStr != null)
                    logMsg += 'Updating shipping address: ' + shippingAddrStr;
                logMsg = logMsg.removeEnd('\n');
                VertexLogging.Log('Debug', logMsg);
            } else {
                VertexLogging.Log('Error', 'Insufficient object or field access on: ' + missingPerms);
            }
        }
        VertexLogging.CommitDelayed();
        return returnRef;
    }

    private String HaveCRUDAndFLS(Set<String> objDotFieldSet) {
        String retVal = '';
            
        VertexCore.PopulateObjToFieldFLSMap(objDotFieldSet, false);
        for (String objectDotField : objDotFieldSet) {
            if (VertexCore.HasCRUDandFLS(objectDotField) != true)
                retVal += objectDotField + ', ';
        }

        return retVal;
    }

    private Boolean AddressIsComplete(VertexAddress__c address) {
        return String.isNotBlank(address.Address1__c) && String.isNotBlank(address.City__c) && String.isNotBlank(address.Country__c);
    }

    @AuraEnabled
    public static boolean isValidationEnabled(){
        return (VertexCore.ActiveSettings.AllowAddressValidation__c == true)? true : false;
    }

    @AuraEnabled
    public static VertexAddress__c checkAddress(string id, string type){
        system.debug('----------id: '+id);
        system.debug('----------type: '+type);
        transient VertexAddress__c addressToTest;
        transient VertexAddress__c correctedAddress = new VertexAddress__c();

        transient LIST<Account> accts = [
            SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, 
                ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM Account
            WHERE id = :id
            LIMIT 1
        ];

        if(accts.size()==1){
            if(type == 'billing'){
                addressToTest = new VertexAddress__c();
                addressToTest.Address1__c = accts[0].BillingStreet;
                addressToTest.City__c = accts[0].BillingCity;
                addressToTest.State__c = accts[0].BillingState;
                addressToTest.PostalCode__c = accts[0].BillingPostalCode;
                addressToTest.Country__c = accts[0].BillingCountry;
            }
            else if(type == 'shipping'){
                addressToTest = new VertexAddress__c();
                addressToTest.Address1__c = accts[0].ShippingStreet;
                addressToTest.City__c = accts[0].ShippingCity;
                addressToTest.State__c = accts[0].ShippingState;
                addressToTest.PostalCode__c = accts[0].ShippingPostalCode;
                addressToTest.Country__c = accts[0].ShippingCountry;
            }
        }
            // if the address is complete then make the callout to verify and correct it
        if (addressToTest != null &&
            String.isNotBlank(addressToTest.Address1__c) && 
            String.isNotBlank(addressToTest.City__c) && 
            String.isNotBlank(addressToTest.Country__c)){
            correctedAddress = VertexCore.validateAddressCallout(addressToTest);
            }
        
        return correctedAddress;
    }
}
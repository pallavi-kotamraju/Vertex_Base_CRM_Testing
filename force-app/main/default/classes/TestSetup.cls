public class TestSetup {

    public static Opportunity ParentOpp;

    public static OpportunityLineItem LineItem;

    public static void CreateData() {
        if (Test.isRunningTest()) {
            Account testAcc = new Account(Name = 'testAcc', BillingStreet = '123 Test Dr', BillingCity = 'Nowhere', BillingState = 'PA', BillingPostalCode = '12345', BillingCountry = 'USA', AccountNumber = '12345');//, NaicsCode = '123');
            insert testAcc;

            ParentOpp = new Opportunity(Name = 'ParentOpp', AccountId = testAcc.Id, StageName = 'Proposal/Price Quote', CloseDate = System.today().addMonths(1));
            insert ParentOpp;

            Pricebook2 pb = new Pricebook2(Name = 'test price book');
            insert pb;

            Product2 prod = new Product2(Name = 'test product');
            insert prod;

            PricebookEntry standardPbe = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id, UnitPrice = 10000, IsActive = true, UseStandardPrice = false);
            insert standardPbe;

            PricebookEntry pbe = new PricebookEntry(UnitPrice = 50, PriceBook2Id = pb.Id, Product2Id = prod.Id, IsActive = true, UseStandardPrice = false);
            insert pbe;  

            LineItem = new OpportunityLineItem(
                                OpportunityId = ParentOpp.Id, 
                                Quantity = 2, 
                                PriceBookEntryId = pbe.Id,
                                UnitPrice = 500
                                );
            insert LineItem;
        }
    }
    
    // To be used in tests only
    public static void CreateConfigurations() {
        if (Test.isRunningTest()) {
            
            // Set up authentication configuration
            transient VertexProtectedSettings__c initConfig = VertexCore.ActiveSettings;
            initConfig.TrustedID__c = '7W3ND73jG5JJ';
            initConfig.TaxAreaLookupURL__c = 'http://test.vertexinc.com/vertex-ws/services/LookupTaxAreas70';
            initConfig.TaxCalculationURL__c = 'http://test.vertexinc.com/vertex-ws/services/CalculateTax70';
            VertexSettingsController.SaveConfig(initConfig);

            // Adding Company and Logging settings to configuration
            transient VertexProtectedSettings__c newConfig = VertexCore.ActiveSettings;
            newConfig.LoggingLevel__c = 'Debug';
            newConfig.MaximumLoggingRows__c = 100.0;
            newConfig.CompanyName__c = 'test';
            newConfig.CompanyTaxId__c = '123';
            newConfig.MaximumLineItems__c = 500;
            newConfig.AllowProcessBuilderRequests__c = true;
            // Save configurations
            VertexSettingsController.SaveAdvancedConfig(newConfig);

            VertexSettingsController.testObjMappings();

            // Grab the new values for the VertexObjectMapping__c to assert in then part
            VertexCore.ObjectMappings = null;
            transient VertexObjectMapping__c oppEstimateMapping = VertexCore.ObjectMappings.get('Estimate');
            transient VertexObjectMapping__c oppOrderMapping = VertexCore.ObjectMappings.get('Order');
            transient VertexObjectMapping__c oppInvoiceMapping = VertexCore.ObjectMappings.get('Invoice');

            // Update the first address on the list ('Administrative Origin Address') 
            transient VertexAddress__c currentAddress = VertexSettingsController.EditAddress('Administrative Origin Address');
            currentAddress.Address1__c = '1 Test Address';
            currentAddress.City__c = 'Test city';
            currentAddress.State__c = 'PA';
            currentAddress.PostalCode__c = '12345';
            currentAddress.Country__c = 'USA';
            VertexSettingsController.SaveAddress(currentAddress);

            // Update the second address on the list ('Default Physical Origin Address') 
            currentAddress = VertexSettingsController.EditAddress('Default Physical Origin Address');
            currentAddress.Address1__c = '1 Test Address';
            currentAddress.City__c = 'Test city';
            currentAddress.State__c = 'PA';
            currentAddress.PostalCode__c = '12345';
            currentAddress.Country__c = 'USA';
            VertexSettingsController.SaveAddress(currentAddress);

            currentAddress = VertexSettingsController.EditAddress('Invoice Trans Dest Map');
            currentAddress.Address1__c = 'account.BillingStreet';
            currentAddress.City__c = 'account.billingcity';
            currentAddress.State__c = 'account.Billingstate';
            currentAddress.PostalCode__c = 'account.billingpostalcode';
            currentAddress.Country__c = 'account.billingcountry';
            VertexSettingsController.SaveAddress(currentAddress);

            currentAddress = VertexSettingsController.EditAddress('Invoice Line Dest Map');
            currentAddress.Address1__c = 'opportunity.account.BillingStreet';
            currentAddress.City__c = 'opportunity.account.billingcity';
            currentAddress.State__c = 'opportunity.account.Billingstate';
            currentAddress.PostalCode__c = 'opportunity.account.billingpostalcode';
            currentAddress.Country__c = 'opportunity.account.billingcountry';
            VertexSettingsController.SaveAddress(currentAddress);
        }
    }
}
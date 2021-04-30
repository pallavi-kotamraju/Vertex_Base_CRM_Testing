public with sharing class TestFactory {
    
    // Create the CPQ Mappings in the Base Package
    public static void createCPQFldMappings(){

        Map<String, Map<String, String>> objectMappingNameToFieldValuePairs = new Map<String, Map<String, String>>();

		Map<String, String> tempMap = new Map<String, String>();

		objectMappingNameToFieldValuePairs.put('CPQ', new Map<String, String>());
		tempMap = objectMappingNameToFieldValuePairs.get('CPQ');
		tempMap.put('ParentSObject__c', 'SBQQ__Quote__c');
		tempMap.put('ChildSObject__c', 'SBQQ__QuoteLine__c');
		tempMap.put('ParentLookup__c', 'SBQQ__Quote__c');
		tempMap.put('ChildSObjectRelationshipName__c', 'SBQQ__LineItems__r');
		tempMap.put('ItemPriceField__c', 'SBQQ__NetTotal__c');
		tempMap.put('TransactionNumber__c', 'Name');
		tempMap.put('TransactionDate__c', 'CreatedDate');
		tempMap.put('ItemTaxField__c', VertexCPQCore.NamespaceString+'Tax_Amount__c');
		tempMap.put('ItemQuantityField__c', 'SBQQ__Quantity__c');
        // tempMap.put('XMLMessage__c', 'Quote');
		tempMap.put('IsExtensionSetting__c', 'true');
        
		tempMap.put('TransactionType__c', 'SALE');
		//tempMap.put('ItemQuantityField__c', 'blng__Quantity__c');
        VertexGlobal.GlobalHelper(new list<object>{'saveObjMap', objectMappingNameToFieldValuePairs});
    }

    // Create the Address Mappings for CPQ for Override and Admin and Destination Mappings in Base Package
    public static void createAddressMappings(){

        Map<String, Map<String, String>> addressMappingNameToFieldValuePairs = new Map<String, Map<String, String>>();

		Map<String, String> addyTempMap = new Map<String, String>();
		Map<String, String> physTempMap = new Map<String, String>();
		Map<String, String> origTempMap = new Map<String, String>();

		addressMappingNameToFieldValuePairs.put('CPQ Trans Dest Map', new Map<String, String>());
		addyTempMap = addressMappingNameToFieldValuePairs.get('CPQ Trans Dest Map');
		addyTempMap.put('Address1__c', 'SBQQ__ShippingStreet__c');
		addyTempMap.put('City__c', 'SBQQ__ShippingCity__c');
		addyTempMap.put('Country__c', 'SBQQ__ShippingCountry__c');
		addyTempMap.put('PostalCode__c', 'SBQQ__ShippingPostalCode__c');
		addyTempMap.put('State__c', 'SBQQ__ShippingState__c');
		//tempMap.put('CustomerCode__c', 'blng__Account__r.AccountNumber');
		//tempMap.put('CustomerClassCode__c', 'blng__Account__r.Id');
        
        addressMappingNameToFieldValuePairs.put('Administrative Origin Address', new Map<String, String>());
		origTempMap = addressMappingNameToFieldValuePairs.get('Administrative Origin Address');
		origTempMap.put('Address1__c', '1 Test St');
		origTempMap.put('City__c', 'Anytown');
		origTempMap.put('Country__c', 'USA');
		origTempMap.put('PostalCode__c', '99999');
		origTempMap.put('State__c', 'PA');

        addressMappingNameToFieldValuePairs.put('Default Physical Origin Address', new Map<String, String>());
		physTempMap = addressMappingNameToFieldValuePairs.get('Default Physical Origin Address');
		physTempMap.put('Address1__c', '1 Test St');
		physTempMap.put('City__c', 'Anytown');
		physTempMap.put('Country__c', 'USA');
		physTempMap.put('PostalCode__c', '99999');
		physTempMap.put('State__c', 'PA');

        VertexGlobal.GlobalHelper(new list<object>{'saveAddyMap', addressMappingNameToFieldValuePairs});
    }

    public static Map<String, String> createQuote(){
        SBQQ.TriggerControl.disable();
        Account newAcc = new Account(
            name = 'Test Account2',
            billingStreet = '1041 old cassatt rd',
            billingCity = 'Berwyn',
            billingState = 'PA',
            billingPostalCode =  '19312',
            billingCountry = 'USA',
            shippingStreet = '1041 old cassatt rd',
            shippingCity = 'Berwyn',
            shippingState = 'PA',
            shippingPostalCode =  '19312',
            shippingCountry = 'USA'
        );
        insert newAcc;

        Opportunity newOppo = new Opportunity(
            name = 'Test Oppo2',
            Accountid = newAcc.id,
            amount = 100000,
            closeDate = date.today(),
            StageName = 'Prospecting',
            Probability = 10
        );
        insert newOppo;

        Pricebook2 newPb = new Pricebook2(
            name = 'TestPricebook',
            IsActive = true
        );
        insert newPb;

        Product2 newProd = new Product2(
            name = 'Test Product',
            IsActive = true,
            ProductCode = 'Test01'
        );
        insert newProd;

        Pricebook2 standardPB = new Pricebook2 (
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPB;

        standardPB = [select id from Pricebook2 where isStandard=true limit 10000 FOR UPDATE];

        PricebookEntry standardPBE = new PricebookEntry(
            Pricebook2Id = standardPB.Id, 
            Product2Id = newProd.Id, 
            UnitPrice = 1000, 
            IsActive = true
        );
        insert standardPBE;

        PricebookEntry newPbe = new PricebookEntry(
            IsActive = true,
            UnitPrice = 500,
            PriceBook2Id = newPb.id,
            Product2Id = newProd.id
        );
        insert newPbe;

        SBQQ__Quote__c newQuote = new SBQQ__Quote__c(
            SBQQ__Account__c = newAcc.id,
            SBQQ__Opportunity2__c = newOppo.id,
            SBQQ__Type__c = 'Quote2',
            SBQQ__Status__c = 'Draft',
            SBQQ__PaymentTerms__c = 'Net 30',
            SBQQ__ExpirationDate__c = Date.Today().addDays(30),
            SBQQ__BillingStreet__c = '1041 old cassatt rd',
            SBQQ__BillingCity__c = 'Berwyn',
            SBQQ__BillingState__c = 'PA',
            SBQQ__BillingPostalCode__c =  '19312',
            SBQQ__BillingCountry__c = 'USA',
            SBQQ__ShippingStreet__c = '1041 old cassatt rd',
            SBQQ__ShippingCity__c = 'Berwyn',
            SBQQ__ShippingState__c = 'PA',
            SBQQ__ShippingPostalCode__c =  '19312',
            SBQQ__ShippingCountry__c = 'USA',
            SBQQ__PriceBook__c = newPb.id,
            SBQQ__PricebookId__c = newPb.id
        );
        insert newQuote;

        SBQQ__QuoteLine__c newQuoteLine = new SBQQ__QuoteLine__c(
            SBQQ__Quote__c = newQuote.id,
            SBQQ__Number__c = 1,
            SBQQ__Quantity__c = 1,
            SBQQ__PricingMethod__c = 'List',
            SBQQ__ListPrice__c = 500,
            SBQQ__CustomerPrice__c = 500,
            SBQQ__NetPrice__c = 500,
            SBQQ__SpecialPrice__c = 500,
            SBQQ__RegularPrice__c = 500
        );
        insert newQuoteLine;

        Map<String, String> objName2Id = new Map<String, String>();
        objName2Id.put('SBQQ__Quote__c', newQuote.id);
        objName2Id.put('SBQQ__QuoteLine__c', newQuoteLine.id);

        return objName2Id;
    }
}
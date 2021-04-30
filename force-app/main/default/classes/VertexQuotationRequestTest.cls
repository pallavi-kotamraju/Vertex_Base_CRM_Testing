@isTest
private class VertexQuotationRequestTest {
    @isTest
    static void itShould() {
        // Given
        transient VertexDataInit dataInit = new VertexDataInit();
        dataInit.CreateUnitTestDestinationMappings();    //Set up dummy VertexAddress__c records

        TestSetup.CreateConfigurations();

        // Set up object mappings
        VertexObjectMapping__c estimateSetting = new VertexObjectMapping__c();
        estimateSetting.Name = 'Estimate';
        estimateSetting.XMLMessage__c = 'Quote';
        estimateSetting.TransactionType__c = 'Sales';
        estimateSetting.ParentSObject__c = 'Opportunity';
        estimateSetting.ChildSObject__c = 'OpportunityLineItem';
        estimateSetting.ParentLookup__c = 'OpportunityId';
        estimateSetting.ChildSObjectRelationshipName__c = 'OpportunityLineItems';
        estimateSetting.TransactionDate__c = 'CloseDate';
        estimateSetting.TransactionNumber__c = 'Name';
        estimateSetting.ItemTaxField__c = VertexCore.NamespaceString + 'TaxRuleId__c';
        estimateSetting.ItemPriceField__c = 'TotalPrice';
        estimateSetting.ItemQuantityField__c = 'Quantity';
        // estimateSetting.ChildSourcePicklist__c = 'Description';
        estimateSetting.ItemTaxNotesField__c = 'Description';

        VertexObjectMapping__c invoiceSetting = new VertexObjectMapping__c();
        invoiceSetting.Name = 'Invoice';
        invoiceSetting.XMLMessage__c = 'Invoice';
        invoiceSetting.TransactionType__c = 'Sales';
        invoiceSetting.ParentSObject__c = 'Opportunity';
        invoiceSetting.ChildSObject__c = 'OpportunityLineItem';
        invoiceSetting.ParentLookup__c = 'OpportunityId';
        invoiceSetting.ChildSObjectRelationshipName__c = 'OpportunityLineItems';
        invoiceSetting.TransactionDate__c = 'CloseDate';
        invoiceSetting.TransactionNumber__c = 'Name';
        invoiceSetting.ItemTaxField__c = VertexCore.NamespaceString + 'TaxRuleId__c';
        invoiceSetting.ItemPriceField__c = 'TotalPrice';
        invoiceSetting.ItemQuantityField__c = 'Quantity';

        VertexObjectMapping__c orderSetting = new VertexObjectMapping__c();
        orderSetting.Name = 'Order';
        orderSetting.XMLMessage__c = 'Distribute';
        orderSetting.TransactionType__c = 'Sales';
        orderSetting.ParentSObject__c = 'Opportunity';
        orderSetting.ChildSObject__c = 'OpportunityLineItem';
        orderSetting.ParentLookup__c = 'OpportunityId';
        orderSetting.ChildSObjectRelationshipName__c = 'OpportunityLineItems';
        orderSetting.TransactionDate__c = 'CloseDate';
        orderSetting.TransactionNumber__c = 'Name';
        orderSetting.ItemTaxField__c = VertexCore.NamespaceString + 'TaxRuleId__c';
        orderSetting.ItemPriceField__c = 'TotalPrice';
        orderSetting.ItemQuantityField__c = 'Quantity';

        List<VertexObjectMapping__c> objMappingList = new List<VertexObjectMapping__c>{estimateSetting, invoiceSetting, orderSetting};
        insert objMappingList;
        
        //Insert text, numeric, and date flex field mappings
        VertexSettingsController.AddAdditionalMapping(estimateSetting.ID, 'line', 'fld', 'Line Text 1', 'Description');
        VertexSettingsController.AddAdditionalMapping(estimateSetting.ID, 'line', 'fld', 'Line Number 1', 'ListPrice');
        VertexSettingsController.AddAdditionalMapping(estimateSetting.ID, 'line', 'fld', 'Line Date 1', 'ServiceDate');

        //Transaction and Line level origin addresses
        List<VertexAddress__c> origins = new List<VertexAddress__c>{
            new VertexAddress__c(Name = 'Estimate Trans Admin', Address1__c = 'AccountId', Address2__c = 'AccountId', City__c = 'AccountId', Country__c = 'AccountId', 
                                PostalCode__c = 'AccountId', State__c = 'AccountId', TaxAreaID__c = 'AccountId', LocationCode__c = 'AccountId'),
            new VertexAddress__c(Name = 'Estimate Trans Phys', Address1__c = 'AccountId', Address2__c = 'AccountId', City__c = 'AccountId', Country__c = 'AccountId', 
                                PostalCode__c = 'AccountId', State__c = 'AccountId', TaxAreaID__c = 'AccountId', LocationCode__c = 'AccountId'),
            new VertexAddress__c(Name = 'Estimate Line Admin', Address1__c = 'OpportunityId', Address2__c = 'OpportunityId', City__c = 'OpportunityId', Country__c = 'OpportunityId', 
                                PostalCode__c = 'OpportunityId', State__c = 'OpportunityId', TaxAreaID__c = 'OpportunityId', LocationCode__c = 'OpportunityId'),
            new VertexAddress__c(Name = 'Estimate Line Phys', Address1__c = 'OpportunityId', Address2__c = 'OpportunityId', City__c = 'OpportunityId', Country__c = 'OpportunityId', 
                                PostalCode__c = 'OpportunityId', State__c = 'OpportunityId', TaxAreaID__c = 'OpportunityId', LocationCode__c = 'OpportunityId'),
            new VertexAddress__c(Name = 'Order Trans Admin', Address1__c = 'AccountId', Address2__c = 'AccountId', City__c = 'AccountId', Country__c = 'AccountId', 
                                PostalCode__c = 'AccountId', State__c = 'AccountId', TaxAreaID__c = 'AccountId', LocationCode__c = 'AccountId'),
            new VertexAddress__c(Name = 'Order Trans Phys', Address1__c = 'AccountId', Address2__c = 'AccountId', City__c = 'AccountId', Country__c = 'AccountId', 
                                PostalCode__c = 'AccountId', State__c = 'AccountId', TaxAreaID__c = 'AccountId', LocationCode__c = 'AccountId'),
            new VertexAddress__c(Name = 'Order Line Admin', Address1__c = 'OpportunityId', Address2__c = 'OpportunityId', City__c = 'OpportunityId', Country__c = 'OpportunityId', 
                                PostalCode__c = 'OpportunityId', State__c = 'OpportunityId', TaxAreaID__c = 'OpportunityId', LocationCode__c = 'OpportunityId'),
            new VertexAddress__c(Name = 'Order Line Phys', Address1__c = 'OpportunityId', Address2__c = 'OpportunityId', City__c = 'OpportunityId', Country__c = 'OpportunityId', 
                                PostalCode__c = 'OpportunityId', State__c = 'OpportunityId', TaxAreaID__c = 'OpportunityId', LocationCode__c = 'OpportunityId'),
            new VertexAddress__c(Name = 'Invoice Trans Admin', Address1__c = 'AccountId', Address2__c = 'AccountId', City__c = 'AccountId', Country__c = 'AccountId', 
                                PostalCode__c = 'AccountId', State__c = 'AccountId', TaxAreaID__c = 'AccountId', LocationCode__c = 'AccountId'),
            new VertexAddress__c(Name = 'Invoice Trans Phys', Address1__c = 'AccountId', Address2__c = 'AccountId', City__c = 'AccountId', Country__c = 'AccountId', 
                                PostalCode__c = 'AccountId', State__c = 'AccountId', TaxAreaID__c = 'AccountId', LocationCode__c = 'AccountId'),
            new VertexAddress__c(Name = 'Invoice Line Admin', Address1__c = 'OpportunityId', Address2__c = 'OpportunityId', City__c = 'OpportunityId', Country__c = 'OpportunityId', 
                                PostalCode__c = 'OpportunityId', State__c = 'OpportunityId', TaxAreaID__c = 'OpportunityId', LocationCode__c = 'OpportunityId'),
            new VertexAddress__c(Name = 'Invoice Line Phys', Address1__c = 'OpportunityId', Address2__c = 'OpportunityId', City__c = 'OpportunityId', Country__c = 'OpportunityId', 
                                PostalCode__c = 'OpportunityId', State__c = 'OpportunityId', TaxAreaID__c = 'OpportunityId', LocationCode__c = 'OpportunityId')
        };
        insert origins;

        Account testAcc = new Account(Name = 'testAcc', BillingStreet = '123 Test Dr', BillingCity = 'Nowhere', BillingState = 'PA', BillingPostalCode = '12345', BillingCountry = 'USA');
        insert testAcc;

        Opportunity parentOpp = new Opportunity(Name = 'ParentOpp', AccountId = testAcc.Id, StageName = 'Proposal/Price Quote', CloseDate = System.today().addMonths(1));
        insert parentOpp;

        Pricebook2 pb = new Pricebook2(Name = 'test price book');
        insert pb;

        Product2 prod = new Product2(Name = 'test product');
        insert prod;

        PricebookEntry standardPbe = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id, UnitPrice = 10000, IsActive = true, UseStandardPrice = false);
        insert standardPbe;

        PricebookEntry pbe = new PricebookEntry(UnitPrice = 50, PriceBook2Id = pb.Id, Product2Id = prod.Id, IsActive = true, UseStandardPrice = false);
        insert pbe;  

        OpportunityLineItem item = new OpportunityLineItem(OpportunityId = parentOpp.Id, Quantity = 2, PriceBookEntryId = pbe.Id, UnitPrice = 500);
        insert item;

        // When
        Test.startTest();

        List<VertexQuotationRequest.InvokeQuoteStructure> requests = new List<VertexQuotationRequest.InvokeQuoteStructure>();
        transient VertexQuotationRequest.InvokeQuoteStructure request = new VertexQuotationRequest.InvokeQuoteStructure();
        request.recordId = parentOpp.Id;
        request.type = 'Estimate';
        requests.add(request);

        Test.setMock(HttpCalloutMock.class, new QuotationRequestMockHttpResponse(item.Id));
        VertexQuotationRequest.InvokeQuotationRequests(requests);
        
        Test.stopTest();

        item = [SELECT Description FROM OpportunityLineItem WHERE ID = :item.ID LIMIT 1];
        System.assert(item.Description != null);   //Some tax value was written

        // Then
        //for (VertexTaxDetail__c detail : [SELECT ParentId__c, Situs__c, TaxCollectedFromParty__c, TaxResult__c, TaxStructure__c, TaxType__c, 
        //                                    JurisdictionLevel__c, JurisdictionId__c, Jurisdiction__c, CalculatedTax__c, EffectiveRate__c, 
        //                                    Taxable__c, Imposition__c, ImpositionId__c, ImpositionType__c, ImpositionTypeId__c, TaxRuleId__c
        //                                  FROM VertexTaxDetail__c
        //                                  LIMIT 1]) {
            
        //    System.assertEquals(item.Id, detail.ParentId__c);
        //    System.assertEquals('ADMINISTRATIVE_ORIGIN' , detail.Situs__c);
        //    System.assertEquals('BUYER', detail.TaxCollectedFromParty__c);
        //    System.assertEquals('TAXABLE', detail.TaxResult__c);
        //    System.assertEquals('SINGLE_RATE', detail.TaxStructure__c);
        //    System.assertEquals('SALES', detail.TaxType__c);

        //    System.assertEquals('STATE', detail.JurisdictionLevel__c);
        //    System.assertEquals(31152, detail.JurisdictionId__c);
        //    System.assertEquals('PENNSYLVANIA', detail.Jurisdiction__c);
        //    System.assertEquals(60.0, detail.CalculatedTax__c);
        //    System.assertEquals(0.06, detail.EffectiveRate__c);

        //    System.assertEquals(1000.0, detail.Taxable__c);
        //    System.assertEquals('Sales and Use Tax', detail.Imposition__c);
        //    System.assertEquals('1', detail.ImpositionId__c);
        //    System.assertEquals('General Sales and Use Tax', detail.ImpositionType__c);
        //    System.assertEquals('1', detail.ImpositionTypeId__c);
        //    System.assertEquals(17423, detail.TaxRuleId__c);
        //}

        //Extra coverage
        VertexStructureRequest.RequestAddressSet reqAddrSet = new VertexStructureRequest.RequestAddressSet(null, null, null, null, null, null, null);
        VertexResponse vResponse = new VertexResponse('test');
        vResponse.GetInvoiceTextCodes();
    }
}
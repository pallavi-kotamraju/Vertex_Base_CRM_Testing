@isTest
private class VertexRequestsTest {

    
    @isTest
    static void orgSetup() {
        transient VertexDataInit dataInit = new VertexDataInit();
        dataInit.CreateVanillaObjMappings();
        dataInit.CreateUnitTestDestinationMappings();

        //Populate a few more fields (with dummy values) for code coverage in VertexRequest and VertexResponse
        VertexObjectMapping__c estimate = VertexObjectMapping__c.getInstance('Estimate');
        estimate.ItemTaxNotesField__c = 'Description';
        estimate.ItemTaxField__c = VertexCore.NamespaceString + 'TaxRuleId__c';
        estimate.Posting_Date__c = 'CreatedDate';
        estimate.CurrencyCode__c = 'Description';
        estimate.TaxRegistrationNumber__c = 'Name';
        estimate.TransactionDeliveryTerm__c = 'Name';
        estimate.LineDeliveryTerm__c = 'Name';
        estimate.InvoiceTextCodes__c = 'Description';
        estimate.TaxCode__c = 'Description';
        estimate.VertexTaxCode__c = 'Description';
        estimate.CommodityCode__c = 'Name';
        estimate.CommodityCodeType__c = 'Description';
        update estimate;

        TestSetup.CreateConfigurations();

        VertexCore.ActiveSettings.AllowProcessBuilderRequests__c = false;
        update VertexCore.ActiveSettings;

		VertexAddress__c transDestMap = VertexAddress__c.getValues('Estimate Trans Dest Map');
        transDestMap.CustomerClassCode__c = 'account.AccountNumber';
        update transDestMap;

        VertexAddress__c invDestMap = VertexAddress__c.getValues('Invoice Trans Dest Map');
        invDestMap.CustomerClassCode__c = 'account.AccountNumber';
        update invDestMap;

        TestSetup.CreateData();

        VertexCore.ActiveSettings.AllowProcessBuilderRequests__c = true;
        update VertexCore.ActiveSettings;
        System.assertEquals(true, VertexCore.ActiveSettings.AllowProcessBuilderRequests__c);
    }

    @isTest
    static void InvoiceRequestTest1() {
        //Given
        orgSetup();

        List<VertexInvoiceRequest.InvokeInvoiceStructure> requests = new List<VertexInvoiceRequest.InvokeInvoiceStructure>();
        transient VertexInvoiceRequest.InvokeInvoiceStructure request = new VertexInvoiceRequest.InvokeInvoiceStructure();
        request.recordId = TestSetup.ParentOpp.Id;  
        request.type = 'Invoice';
        requests.add(request);

        // When
        Test.startTest();
        VertexCore.IsResponseRunning = false;

        Test.setMock(HttpCalloutMock.class, new VertexRequestMockHttpResponse(TestSetup.LineItem.Id, 'Invoice'));
        VertexInvoiceRequest.InvokeQuotationRequests(requests);
        System.assertEquals(true, VertexCore.IsResponseRunning);
        Test.stopTest();
	}

    @isTest
    static void InvoiceRequestTest2() {
        //Given
        orgSetup();

        List<VertexInvoiceRequest.InvokeInvoiceStructure> requests = new List<VertexInvoiceRequest.InvokeInvoiceStructure>();
        transient VertexInvoiceRequest.InvokeInvoiceStructure request = new VertexInvoiceRequest.InvokeInvoiceStructure();
        request.recordId = TestSetup.ParentOpp.Id;  
        request.type = 'Invoice';
        requests.add(request);
        System.assert(requests != null);

        // When
        Test.startTest();
        VertexCore.IsResponseRunning = false;

        Test.setMock(HttpCalloutMock.class, new VertexRequestMockHttpResponse(TestSetup.LineItem.Id, 'Invoice'));
        VertexInvoiceRequest.InvokeVertexCallout(new List<Id> {TestSetup.ParentOpp.Id}, 'Invoice');
        Test.stopTest();
    }

    @isTest
    static void QuotationRequestTest1() {
        //Given
        orgSetup();

        List<VertexQuotationRequest.InvokeQuoteStructure> requests = new List<VertexQuotationRequest.InvokeQuoteStructure>();
        transient VertexQuotationRequest.InvokeQuoteStructure request = new VertexQuotationRequest.InvokeQuoteStructure();
        request.recordId = TestSetup.ParentOpp.Id;  
        request.type = 'Quotation';
        requests.add(request);

        // When
        Test.startTest();
        VertexCore.IsResponseRunning = false;

        Test.setMock(HttpCalloutMock.class, new VertexRequestMockHttpResponse(TestSetup.LineItem.Id, 'Quotation'));
        VertexQuotationRequest.InvokeQuotationRequests(requests);
        System.assertEquals(true, VertexCore.IsResponseRunning);
        Test.stopTest();
    }

    //mgs
    @isTest
    static void QuotationRequestTest2() {
        //Given
        orgSetup();

        List<VertexQuotationRequest.InvokeQuoteStructure> requests = new List<VertexQuotationRequest.InvokeQuoteStructure>();
        transient VertexQuotationRequest.InvokeQuoteStructure request = new VertexQuotationRequest.InvokeQuoteStructure();
        request.recordId = TestSetup.ParentOpp.Id;  
        request.type = 'Quotation';
        requests.add(request);
        System.assert(requests != null);
        
        // When
        Test.startTest();
        VertexCore.IsResponseRunning = false;

        //
        Test.setMock(HttpCalloutMock.class, new VertexRequestMockHttpResponse(TestSetup.LineItem.Id, 'Quotation'));
        VertexQuotationRequest.InvokeVertexCallout(new List<Id> {TestSetup.ParentOpp.Id}, 'Quotation');
        Test.stopTest();

    }

    @isTest
    static void DistributeTaxRequestTest1() {
        //Given
        orgSetup();

        List<VertexDistributeTaxRequest.InvokeDistributeTaxStructure> requests = new List<VertexDistributeTaxRequest.InvokeDistributeTaxStructure>();
        transient VertexDistributeTaxRequest.InvokeDistributeTaxStructure request = new VertexDistributeTaxRequest.InvokeDistributeTaxStructure();
        request.recordId = TestSetup.ParentOpp.Id;  
        request.type = 'Invoice';
        requests.add(request);

        // When
        Test.startTest();
        VertexCore.IsResponseRunning = false;

        Test.setMock(HttpCalloutMock.class, new VertexRequestMockHttpResponse(TestSetup.LineItem.Id, 'DistributeTax'));
        VertexDistributeTaxRequest.InvokeQuotationRequests(requests);
        System.assertEquals(true, VertexCore.IsResponseRunning);
        Test.stopTest();
    }

    @isTest
    static void GenericRequestTest() {
        //Given
        orgSetup();

        List<VertexAnyRequest.InvokeAnyRequestStructure> requests = new List<VertexAnyRequest.InvokeAnyRequestStructure>();
        transient VertexAnyRequest.InvokeAnyRequestStructure request = new VertexAnyRequest.InvokeAnyRequestStructure();
        request.recordId = TestSetup.ParentOpp.Id;
        request.type = 'Estimate';
        requests.add(request);

        // When
        Test.startTest();
        VertexCore.IsResponseRunning = false;

        Test.setMock(HttpCalloutMock.class, new VertexRequestMockHttpResponse(TestSetup.LineItem.Id, 'Quotation'));
        VertexAnyRequest.InvokeAllRequests(requests);
        System.assertEquals(true, VertexCore.IsResponseRunning);
        Test.stopTest();
    }

    @isTest
    static void DeleteRequestTest() {
        VertexDeleteRequest vertDel = new VertexDeleteRequest();
        System.assert(vertDel != null);
    }

    @isTest
    static void testInstallScript() {
        //Test fresh install
        VertexPostInstall postinstall = new VertexPostInstall();
        Test.testInstall(postinstall, null);
        System.assert(VertexObjectMapping__c.getInstance('Estimate') != null);

        //Reset
        transient VertexDataInit dataInit = new VertexDataInit();
        dataInit.ClearAll();
        dataInit.CreateVanillaObjMappings();
        dataInit.CreateUnitTestDestinationMappings();

        //Test an upgrade
        Test.testInstall(postinstall, new Version(1,0), true);
        System.assertEquals('Quote', VertexObjectMapping__c.getInstance('Estimate').XMLMessage__c);
        System.assertEquals('SALE', VertexObjectMapping__c.getInstance('Estimate').TransactionType__c);
        System.assertEquals(null, VertexAddress__c.getInstance('Estimate Trans Dest Map').Address1__c);
    }

    @isTest
    static void fillInRequest(){
        VertexRequest vreq = new VertexRequest('Invoice',true);
        vreq.TaxOnly = false;
        vreq.PostToJournal = false;
        System.assert(vreq != null);
    }


    //verify the override map produces sobjects that contain the most updated values
    @isTest
    static void overrideMap(){
        orgSetup();
        //get an opportunity
        List<Opportunity> oppList = [SELECT Id, Name FROM Opportunity LIMIT 1];
        System.assertEquals(1,oppList.size());
        for(Opportunity opp : oppList){
            System.assertEquals('ParentOpp',opp.Name);
            Map<String,String> overrideMap = new Map<String,String>();
            overrideMap.put('Name',opp.Name + ' 1');
            VertexCore.fieldOverrideMap.put(opp.Id,overrideMap);
        }
        
        List<SObject> sObjectList = VertexRequest.getParentChildOverrideList(oppList,'OpportunityLineItems');

        //verify that the result is that the new sobjects have the overrridden values
        System.assertEquals(1,sobjectList.size());
        for(Sobject obj : sobjectList){
            System.assertEquals('ParentOpp 1',obj.get('Name'));
        }
    }

    //verify that an empty input will also result in an empty list returned
    @isTest
    static void overrideEmpty(){
        orgSetup();
        //get an opportunity
        List<Opportunity> oppList = [SELECT Id, Name FROM Opportunity LIMIT 1];
        System.assertEquals(1,oppList.size());
        for(Opportunity opp : oppList){
            System.assertEquals('ParentOpp',opp.Name);
            Map<String,String> overrideMap = new Map<String,String>();
            overrideMap.put('Name',opp.Name + ' 1');
            VertexCore.fieldOverrideMap.put(opp.Id,overrideMap);
        }

        List<Opportunity> emptyOppList = new List<Opportunity>();
        List<SObject> sObjectList = VertexRequest.getParentChildOverrideList(emptyOppList,'OpportunityLineItems');
        System.assert(sobjectList.isEmpty());
    }


    //verify that an invalid override map would allow normal flow
    @isTest
    static void overrideIncorrectMapping(){
        orgSetup();
        //get an opportunity
        List<Opportunity> oppList = [SELECT Id, Name FROM Opportunity LIMIT 1];
        System.assertEquals(1,oppList.size());
        for(Opportunity opp : oppList){
            System.assertEquals('ParentOpp',opp.Name);
            Map<String,String> overrideMap = new Map<String,String>();
            overrideMap.put('Fake_Field__c',opp.Name + '1 ');
            overrideMap.put('StageName','Closed Won');
            VertexCore.fieldOverrideMap.put(opp.Id,overrideMap);
        }
        
        List<SObject> sObjectList = VertexRequest.getParentChildOverrideList(oppList,'OpportunityLineItems');
        //verify that the result is that the new sobjects have the overrridden values
        System.assertEquals(1,sobjectList.size());
        for(Sobject obj : sobjectList){
            System.assertEquals('ParentOpp',obj.get('Name'));
            System.assertEquals('Closed Won',obj.get('StageName'));
        }
    }

    //verify that an invalid key in the override map will not alter the result of the overrides of valid ids
    @isTest
    static void overrideInvalidId(){
        orgSetup();
        //get an opportunity
        List<Opportunity> oppList = [SELECT Id, Name FROM Opportunity LIMIT 1];
        System.assertEquals(1,oppList.size());
        for(Opportunity opp : oppList){
            System.assertEquals('ParentOpp',opp.Name);
            Map<String,String> overrideMap = new Map<String,String>();
            overrideMap.put('Name','ParentOpp1');
            overrideMap.put('StageName','Closed Won');
            VertexCore.fieldOverrideMap.put(opp.Id,overrideMap);
        }

        //building an invalid mapping to verify that it will not affect the results of 
        String InvalidOppId = 'abc';
        Map<String,String> invalidOverrideMap = new Map<String,String>();
        invalidOverrideMap.put('Name','Test Opp 2');
        VertexCore.fieldOverrideMap.put(invalidOppId,invalidOverrideMap);
        
        List<SObject> sObjectList = VertexRequest.getParentChildOverrideList(oppList,'OpportunityLineItems');
        //verify that the result is that the new sobjects have the overrridden values
        System.assertEquals(1,sobjectList.size());
        for(Sobject obj : sobjectList){
            System.assertEquals('ParentOpp1',obj.get('Name'));
            System.assertEquals('Closed Won',obj.get('StageName'));
        }
    }

    //verify that the opportunity line item is overridden when the field mapping overrides quantity
    @isTest
    static void overrideLineItem(){
        orgSetup();
        //get an opportunity
        List<Opportunity> oppList = [SELECT Id, Name, (SELECT Id FROM OpportunityLineItems) FROM Opportunity LIMIT 1];
        System.assertEquals(1,oppList.size());
        System.assertEquals(1,[SELECT Id FROM OpportunityLineItem].size());
        for(OpportunityLineItem oli : [SELECT Id FROM OpportunityLineItem]){
            Map<String,String> overrideMap = new Map<String,String>();
            overrideMap.put('Quantity','5');
            VertexCore.fieldOverrideMap.put(oli.Id,overrideMap);
        }

        List<SObject> sObjectList = VertexRequest.getParentChildOverrideList(oppList,'OpportunityLineItems');

        //verify that the result is that the new sobjects have the overrridden values
        oppList = (List<Opportunity>) sobjectList;

        for(Opportunity opp : oppList){
            for(OpportunityLineItem oli : opp.OpportunityLineItems){
                System.assertEquals(5,oli.Quantity);
            }
        }
    }

    //verify that choosing a bad field value in a field such as quantity will cause the parsing to fail, but will
    //send the original non-overridden results to the webservice
    @IsTest
    static void badFieldValue(){
        orgSetup();
        //get an opportunity
        List<Opportunity> oppList = [SELECT Id, Name, (SELECT Id FROM OpportunityLineItems) FROM Opportunity LIMIT 1];
        System.assertEquals(1,oppList.size());
        System.assertEquals(1,[SELECT Id FROM OpportunityLineItem].size());
        for(OpportunityLineItem oli : [SELECT Id FROM OpportunityLineItem]){
            Map<String,String> overrideMap = new Map<String,String>();
            overrideMap.put('Quantity','q');
            VertexCore.fieldOverrideMap.put(oli.Id,overrideMap);
        }

        VertexCore.ActiveSettings.LoggingLevel__c = 'Error';
        VertexCore.ActiveSettings.AsynchronousLogging__c = false;
        upsert VertexCore.ActiveSettings;
        Test.startTest();
        List<SObject> sObjectList = VertexRequest.getParentChildOverrideList(oppList,'OpportunityLineItems');
        Test.stopTest();
        oppList = (List<Opportunity>) sobjectList;

        //verify quantity has remained the same after bad value is present
        for(Opportunity opp : oppList){
            for(OpportunityLineItem oli : opp.OpportunityLineItems){
                System.assertEquals(1,oli.Quantity);
            }
        }
    }


    //verify that a call to addNewChildRecords is able to create a new sobject with the overridden values from the map
    @isTest
    static void addNewChildRecords(){

        //create an override map
        Map<String,Map<String,String>> overrideMap = new Map<String,Map<String,String>>();

        Map<String,String> fieldMap = new Map<String,String>();
        fieldMap.put('Quantity','5');
        fieldMap.put('TotalPrice','100');
        overrideMap.put('new1',fieldMap);

        VertexRequest request = new VertexRequest('',true);

        List<SObject> childRecords = new List<SObject>();
        Set<String> idSet = new Set<String>();
        idSet.add('new2');
        childRecords = request.getNewChildRecords(overrideMap,idSet,'OpportunityLineItem');

        //verify that the opportunity line item is created with the overridden values
        System.assertEquals(1,childRecords.size());
        OpportunityLineItem oli = (OpportunityLineItem) childRecords[0];
        System.assertEquals(5,oli.Quantity);
        System.assertEquals(100,oli.TotalPrice);
    }

    //verify overrides of string fields area also valid
    @isTest
    static void testStringOverride(){

        //create an override map
        Map<String,Map<String,String>> overrideMap = new Map<String,Map<String,String>>();

        Map<String,String> fieldMap = new Map<String,String>();
        fieldMap.put('Description','Test Description');
        overrideMap.put('new1',fieldMap);

        VertexRequest request = new VertexRequest('',true);

        List<SObject> childRecords = new List<SObject>();
        Set<String> idSet = new Set<String>();
        idSet.add('new2');

        childRecords = request.getNewChildRecords(overrideMap,idSet,'OpportunityLineItem');

        //verify that the opportunity line item is created with the overridden values
        System.assertEquals(1,childRecords.size());
        OpportunityLineItem oli = (OpportunityLineItem) childRecords[0];
        System.assertEquals('Test Description',oli.Description);
    }

    //verify that a call to addchildrecords will return an empty list when that id has already been processed
    @IsTest
    static void addRecordWithExistingId(){
        //create an override map
        Map<String,Map<String,String>> overrideMap = new Map<String,Map<String,String>>();

        Map<String,String> fieldMap = new Map<String,String>();
        fieldMap.put('Quantity','5');
        fieldMap.put('TotalPrice','100');
        overrideMap.put('new1',fieldMap);

        VertexRequest request = new VertexRequest('',true);

        List<SObject> childRecords = new List<SObject>();

        //setting the set of existing ids to include the current record's id
        Set<String> idSet = new Set<String>();
        idSet.add('new1');

        childRecords = request.getNewChildRecords(overrideMap,idSet,'OpportunityLineItem');

        //verify that childRecords holds an empty list, because no new records were added from the override
        System.assertEquals(0,childRecords.size());
    }

    //verify a new record is created for each dummy id in the override map
    @isTest
    static void testGetNewRecords(){
        //create an override map
        Map<String,Map<String,String>> overrideMap = new Map<String,Map<String,String>>();

        Map<String,String> fieldMap = new Map<String,String>();
        fieldMap.put('Quantity','5');
        fieldMap.put('TotalPrice','100');
        overrideMap.put('new1',fieldMap);
        VertexCore.fieldOverrideMap = overrideMap;
        
        //verify a new records is created
        List<Object> objectList = VertexRequest.getNewRecords();
        System.assertEquals(1,objectList.size());
    }

    //verify the addnewChildRecords method creates a new record when a new override map record is sent
    @isTest
    static void getVertexRequest(){
        VertexRequest request = new VertexRequest('Estimate',false);

        List<Sobject> childRecords = new List<SObject>();
        Map<String,Map<String,String>> overrideMap = new Map<String,Map<String,String>>();
        Map<String,String> fieldMap = new Map<String,String>();
        fieldMap.put('Quantity','2');
        fieldMap.put('Id','new1');
        overrideMap.put('new1',fieldMap);

        Set<String> idSet = new Set<String>();
        String key = 'new1';
        childRecords = request.getNewChildRecords(overrideMap,idSet,'OpportunityLineItem');

        System.assertEquals(1,childRecords.size());
        
    }
}
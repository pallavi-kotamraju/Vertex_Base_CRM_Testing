@isTest
public with sharing class VertexBulkRequestTest {
   

    @TestSetup
    static void testSetup(){

        User usr = new User();
        usr.Id = Userinfo.getUserId();
        System.runas(usr){
            Account acc01 = new Account(
                Name='Test Account 1',
                BillingStreet='860 1st Ave',
                BillingCity='King of Prussia',
                BillingState='PA',
                BillingPostalCode='19406',
                BillingCountry='USA'
            );
            insert acc01;
    
            //  Insert Opportunity
            Opportunity opp01 = new Opportunity(
                Name='Test Opportunity 1', 
                AccountId=acc01.Id, 
                StageName='Prospecting', 
                CloseDate=Date.Today()
            );
            insert opp01;
    
            //  Insert Pricebook
            Pricebook2 pb01 = new Pricebook2(
                Name = 'Test Price Book 1', 
                IsActive = true
            );
            insert pb01;
    
            //  Insert Product
            Product2 product01 = new Product2(
                Name = 'Test Product 1', 
                IsActive = true
            );
            insert product01;
    
            //  Insert Standard Price Book
            PricebookEntry standardPriceBookEntry = new PricebookEntry(
                Pricebook2Id = Test.getStandardPriceBookId(),
                Product2Id = product01.Id,
                UnitPrice = 100.00,
                UseStandardPrice = false,
                IsActive = true
            );
    
            insert standardPriceBookEntry;
    
            //  Insert Pricebook Entry
            PricebookEntry pbe01 = new PricebookEntry(
                UnitPrice=0.01, 
                Product2Id=product01.Id, 
                Pricebook2Id=pb01.Id, 
                isActive=true, 
                UseStandardPrice = false
            );
            insert pbe01;
    
            //  Insert Opportunity Line Items
            List<OpportunityLineItem> oppLineItemList = new List<OpportunityLineItem>();
            for(Integer i=1; i<=20; i++){
                OpportunityLineItem oppLineItem = new OpportunityLineItem(
                    Description='Test Opportunity Line Item ' + i, 
                    Quantity=5, 
                    OpportunityId=opp01.Id, 
                    UnitPrice=100.00, 
                    PriceBookEntryId=pbe01.Id
                );
                oppLineItemList.add(oppLineItem);
            }
    
            insert oppLineItemList;
    
            VertexProtectedSettings__c protectedSettings = new VertexProtectedSettings__c();
            protectedSettings.Name = 'Active';
            protectedSettings.MaximumLineItems__c = 10;
            protectedSettings.TrustedID__c = '7W3ND73jG5JJ';
            protectedSettings.TaxAreaLookupURL__c = 'http://test.vertexinc.com/vertex-ws/services/LookupTaxAreas70';
            protectedSettings.TaxCalculationURL__c = 'http://test.vertexinc.com/vertex-ws/services/CalculateTax70';
            insert protectedSettings;
    
            VertexAddress__c vAddress = new VertexAddress__c();
            vAddress.Name = 'Estimate Trans Admin';
            vAddress.Address1__c = 'Account.BillingStreet';
            insert vAddress;
    
            VertexAddress__c childAddress = new VertexAddress__c();
            childAddress.Name = 'Estimate Line Admin';
            childAddress.Address1__c = 'Opportunity.Account.BillingStreet';
            insert childAddress;
    
            VertexObjectMapping__c objMapping = new VertexObjectMapping__c();
            objMapping.Name = 'Estimate';
            objMapping.ChildSObjectRelationshipName__c = 'OpportunityLineItems';
            objMapping.ParentSObject__c = 'Opportunity';
            objMapping.ChildSObject__c = 'OpportunityLineItem';
            objMapping.ParentLookup__c = 'OpportunityId';
            insert objMapping;
        }
        
    }

    //test to run the batch directly from the invocable method
    @isTest
    private static void testConstructor(){
        List<Opportunity> opportunityList = [SELECT id FROM Opportunity LIMIT 1000];
        Opportunity opp = opportunityList[0];

        List<VertexBaseRequest.InvokeRequestStructure> requestList = new List<VertexBaseRequest.InvokeRequestStructure>();

        VertexBaseRequest.InvokeRequestStructure request = new VertexBaseRequest.InvokeRequestStructure();
        request.recordId = opp.Id;
        request.mappingType = 'Estimate';

        requestList.add(request);

        VertexRequest vertexRequest = new VertexRequest('Estimate',true);

        VertexMapping vMap = new VertexMapping(request);

        List<VertexObjectMapping__c> objectMappingList = [SELECT Id, Name, ChildSObjectRelationshipName__c, ParentSObject__c, ChildSObject__c, ParentLookup__c   FROM VertexObjectMapping__c];
        VertexObjectMapping__c objMapping = objectMappingList[0];
        
        List<VertexAddress__c> vertexAddressList = [SELECT Id, Name, Address1__c FROM VertexAddress__c WHERE Name='Estimate Trans Admin'];
        VertexAddress__c vAddress = vertexAddressList[0];

        List<VertexAddress__c> childAddressList = [SELECT Id, Name, Address1__c FROM VertexAddress__c WHERE Name='Estimate Line Admin'] ;
        VertexAddress__c childAddress = childAddressList[0];


        vmap.ObjMap = objMapping;
        vmap.ParentFieldMap = vAddress;
        vmap.ChildFieldMap = childAddress;
        vertexRequest.vMap = vMap;
        
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new QuotationRequestMockHttpResponse(opp.Id));
        vertexRequest.InvokeRequestList(requestList, true);
        Test.stopTest();

        List<VertexLog__c> vertexLogs = [SELECT id FROM VertexLog__c];
        //though running the batch class will perform a callout, in a text context, the log isn't created.
        //the reason is that we are already in a future context when the log is run
        System.assertEquals(0,vertexLogs.size());
    }

    //returns the query string for the start method
    @isTest
    static void getQueryString(){
        VertexBaseRequest.InvokeRequestStructure request = new VertexBaseRequest.InvokeRequestStructure();
        VertexMapping vMap = new VertexMapping(request);
        
        List<VertexAddress__c> childAddressList = [SELECT Id, Name, Address1__c, Address2__c, City__c, Country__c, PostalCode__c, State__c, TaxAreaId__c, CustomerCode__c, CustomerClassCode__c, LocationCode__c FROM VertexAddress__c WHERE Name='Estimate Line Admin'] ;
        
        VertexAddress__c childAddress = childAddressList[0];
        vMap.ChildFieldMap = childAddress;

        List<VertexObjectMapping__c> objectMappingList = [SELECT Id, Name,UsageClass__c,UsageCode__c,TaxIncludedIndicator__c,SuppressTaxCallout__c,CommodityCode__c,CommodityCodeType__c,LineDeliveryTerm__c,ItemQuantityField__c, ChildSourcePicklist__c,ItemClassField__c,ItemNameField__c,ItemTaxPayerField__c,ItemPriceField__c,InputTotalTax__c, ChildSObjectRelationshipName__c, ParentSObject__c, ChildSObject__c, ParentLookup__c   FROM VertexObjectMapping__c];
            
        VertexObjectMapping__c objMapping = objectMappingList[0];
        VMap.ObjMap = objMapping;

        VertexRequest vRequest = new VertexRequest('Estimate',true);
        vRequest.Vmap = vMap;
        String queryString = VertexBulkRequest.getQueryString(vMap,vRequest);

        System.assertEquals(queryString,'SELECT opportunity.account.billingstreet FROM OpportunityLineItem WHERE OpportunityId = :parentId');
    }


}
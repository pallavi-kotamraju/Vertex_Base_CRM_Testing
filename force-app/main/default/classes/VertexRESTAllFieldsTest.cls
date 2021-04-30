@isTest
public with sharing class VertexRESTAllFieldsTest {
    
    @TestSetup
    static void makeData(){
        TestFactory.createQuote();
    }

    @isTest
    private static void fieldMap(){
        //get record from soql
        List<SBQQ__Quote__c> quoteList = [SELECT Id FROM SBQQ__Quote__c];
        SBQQ__Quote__c quote = quoteList[0];
        
        //serialize into an object
        String quoteString = JSON.serialize(quote);

        //verify field map is created correctly for quote
        Map<String,String> fieldMap = VertexRestAllFields.getFieldMap(quoteString);
        System.assertEquals(fieldMap.get('Id'),quote.Id);
    }


    @isTest
    private static void getOverrideMap(){
        //get the field map for the quote list
        List<SBQQ__Quote__c> quoteList = [SELECT Id FROM SBQQ__Quote__c];
        SBQQ__Quote__c quote = quoteList[0];
        
        //serialize into an object
        String quoteString = JSON.serialize(quote);

        //verify field map is created correctly for quote
        Map<String,String> fieldMap = VertexRestAllFields.getFieldMap(quoteString);

        //get the serialized version of the quote line items
        List<SBQQ__QuoteLine__c> lineItems = [SELECT Id FROM SBQQ__QuoteLine__c];
        String lineItemsString = JSON.serialize(lineItems);

        //get overrideMap
        Map<String,Map<String,String>> overrideMap = VertexRestAllFields.getOverrideMap(fieldMap,lineItemsString);

        //verify the override map has the correct id
        Map<String,String> quoteMap = overrideMap.get(quote.Id);
        System.assertEquals(quote.Id,quoteMap.get('Id'));

        //verify the override map has the line item
        Map<String,String> quoteLineMap = overrideMap.get(lineItems[0].Id);
        System.assertEquals(lineItems[0].Id,quoteLineMap.get('Id'));

    }

    @isTest
    private static void getTaxAllFields(){
        //get the field map for the quote list
        List<SBQQ__Quote__c> quoteList = [SELECT Id FROM SBQQ__Quote__c];
        SBQQ__Quote__c quote = quoteList[0];
        
        //serialize into an object
        String quoteString = JSON.serialize(quote);

        //get the serialized version of the quote line items
        List<SBQQ__QuoteLine__c> lineItems = [SELECT Id FROM SBQQ__QuoteLine__c];
        String lineItemsString = JSON.serialize(lineItems);

        test.startTest();
        Test.setMock(HttpCalloutMock.class, new VertexCPQMockResponse(lineItems[0].Id));
        String jsonResult = VertexRestAllFields.getTaxAllFields(quoteString, lineItemsString, 'CPQ');
        test.stopTest();

        //testing that the function call worked successfully
        System.assertNotEquals(null,jsonResult);
    }

    //verify a mapping that holds a numeric value returns a string
    @isTest
    static void numericMapping(){

        Map<String,Object> quoteMap = new Map<String,Object>();
        quoteMap.put('Quantity',5);

        String value = VertexRestAllFields.getQuoteLineFieldValue(quoteMap,'Quantity');
        System.assertEquals(value,'5');
    }

    // test passing asynchronous values to OCP so that the Queueable can be called
    @isTest
    static void testQueueableOption(){
        //get the field map for the quote list
        List<SBQQ__Quote__c> quoteList = [SELECT Id FROM SBQQ__Quote__c];
        SBQQ__Quote__c quote = quoteList[0];
        
        //serialize into an object
        String quoteString = JSON.serialize(quote);

        //get the serialized version of the quote line items
        List<SBQQ__QuoteLine__c> lineItems = [SELECT Id FROM SBQQ__QuoteLine__c];
        String lineItemsString = JSON.serialize(lineItems);

        VertexCPQSettings__c config = VertexCPQCore.ActiveSettings;
        config.AsynchronousCPQCallout__c = true;
        VertexCPQCore.ActiveSettings = config;
        // GIVEN : Quote, Quote Line records and a Custom Setting of AsynchronousCPQCallout

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new VertexCPQMockResponse(lineItems[0].Id));
        // WHEN : Call getTaxAllFields 
        String jsonResult = VertexRestAllFields.getTaxAllFields(quoteString, lineItemsString, 'CPQ');
        Test.stopTest();
        // THEN : Should return records with async in the Tax Amount field for the OCP Script to update the
        //        Tax Amount to 0.00 and the Status field to Tax Status.
        System.assert(jsonResult.contains('async'));
        
    }

}
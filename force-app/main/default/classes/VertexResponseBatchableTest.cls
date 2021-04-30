@isTest
public with sharing class VertexResponseBatchableTest {

  //  @isTest
    public VertexResponseBatchableTest() {
       // Map<String, String> obj2Id = TestFactory.createQuote();
        List<VertexCore.ResponseWrapper> inputList = new List<VertexCore.ResponseWrapper>();
       
            VertexCore.ResponseWrapper taxWrap = new VertexCore.ResponseWrapper();
          //  taxWrap.reponseBody = 
         //   taxWrap.reponseType = 9;
         //  taxWrap.mappingType = 9;
           // inputList.add(taxWrap);
        }

        // Test.startTest();
        // // WHEN : Wrapper class records passed to batch class
        // Id jobId = Database.executeBatch(new VertexResponseBatchable(inputList), 2);
        // Test.stopTest();
        
        // List<SBQQ__Quote__c> quoteVerifyList = [SELECT Id, Tax_Amount__c FROM SBQQ__Quote__c LIMIT 10000];
        // // THEN : Records should be updated
        // System.assertEquals(quoteVerifyList[0].Tax_Amount__c, 9);

    }


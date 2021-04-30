@isTest
public with sharing class VertexCPQBatchableTest {

    @isTest
    public static void VertexCPQBatchableTest() {
        // GIVEN : A quote with a line item
        Map<String, String> obj2Id = TestFactory.createQuote();
        List<VertexCPQCore.taxAmtWrapper> inputList = new List<VertexCPQCore.taxAmtWrapper>();
        for(String key: obj2Id.keySet()){
            VertexCPQCore.taxAmtWrapper taxWrap = new VertexCPQCore.taxAmtWrapper();
            taxWrap.recdId = obj2Id.get(key);
            taxWrap.taxAmt = 9;
            inputList.add(taxWrap);
        }

        Test.startTest();
        // WHEN : Wrapper class records passed to batch class
        Id jobId = Database.executeBatch(new VertexCPQBatchable(inputList), 2);
        Test.stopTest();
        
        List<SBQQ__Quote__c> quoteVerifyList = [SELECT Id, Tax_Amount__c FROM SBQQ__Quote__c LIMIT 10000];
        // THEN : Records should be updated
        System.assertEquals(quoteVerifyList[0].Tax_Amount__c, 9);
    }
}
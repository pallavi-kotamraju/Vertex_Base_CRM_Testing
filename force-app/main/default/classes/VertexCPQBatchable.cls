public with sharing class VertexCPQBatchable implements Database.Batchable<VertexCPQCore.taxAmtWrapper>, Database.Stateful, Database.AllowsCallouts {
    public List<VertexCPQCore.taxAmtWrapper> calloutResults; // results from the callout to Vertex

    public VertexCPQBatchable(List<VertexCPQCore.taxAmtWrapper> calloutResults) {
        this.calloutResults = calloutResults;
    }

    public Iterable<VertexCPQCore.taxAmtWrapper> start(Database.BatchableContext bc) {
        return calloutResults;
    }

    public void execute(Database.BatchableContext bc, List<VertexCPQCore.taxAmtWrapper> scope){      
        System.debug('-->Log 1 : VertexCPQBatchable: Execute');
        transient List<SBQQ__Quote__c> quoteList = new List<SBQQ__Quote__c>();
        transient List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        transient String quotesObjType = Schema.getGlobalDescribe().get('SBQQ__Quote__c').getDescribe().getKeyPrefix();
        transient String quoteLinesObjType = Schema.getGlobalDescribe().get('SBQQ__QuoteLine__c').getDescribe().getKeyPrefix();
        
        // Loop through results and create lists so we can update
        for(VertexCPQCore.taxAmtWrapper s: scope){
            if(s.recdId.substring(0,3) == quotesObjType){
                transient SBQQ__Quote__c quote = new SBQQ__Quote__c();
                quote.Tax_Amount__c = s.taxAmt;
                quote.id = s.recdId;
                quote.Tax_Status__c = VertexCPQCore.finishCallout;
                quoteList.add(quote);
            }
            if(s.recdId.substring(0,3) == quoteLinesObjType){
                transient SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c();
                quoteLine.Tax_Amount__c = s.taxAmt;
                quoteLine.id = s.recdId;
                quoteLine.Tax_Status__c = VertexCPQCore.finishCallout;
                quoteLineList.add(quoteLine);
            }   
        }

        // Disable CPQ triggers
        SBQQ.TriggerControl.disable();
        if(!quoteList.isEmpty()){
            if(Schema.SObjectType.SBQQ__Quote__c.isUpdateable() &&
               Schema.SObjectType.SBQQ__Quote__c.fields.Tax_Amount__c.isUpdateable() &&
               Schema.SObjectType.SBQQ__Quote__c.fields.Tax_Status__c.isUpdateable()){
                upsert quoteList;
            }
            
        }
        
        if(!quoteLineList.isEmpty()){
            if(Schema.SObjectType.SBQQ__QuoteLine__c.isUpdateable() &&
               Schema.SObjectType.SBQQ__QuoteLine__c.fields.Tax_Amount__c.isUpdateable() &&
               Schema.SObjectType.SBQQ__QuoteLine__c.fields.Tax_Status__c.isUpdateable()){
                upsert quoteLineList;
            }
        }
        SBQQ.TriggerControl.enable();
    }

    public void finish(Database.BatchableContext bc){

    }
}
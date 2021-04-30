public with sharing class VertexGetTaxQueueable implements Queueable, Database.AllowsCallouts {
    
    private String id;
    private String type;
    
    public VertexGetTaxQueueable(String id, String type) {
        System.debug('-->Log 1 VertexGetTaxQueueable : Start');
        this.id = id;
        this.type = type;
    }

    public void execute(QueueableContext ctx){
        System.debug('-->Log 2 VertexGetTaxQueueable : execute');
        transient String result = VertexRestHandler.getTax(this.id,this.type);
        result='['+result+']';
        System.debug('-->Log : VertexGetTaxQueueable : Execute: Result '+result );
        transient List<Object> resultDeserialized = (List<Object>)JSON.deserializeUntyped(result);
        transient Map<String, Object> id2TaxAmt;
        transient List<VertexCPQCore.taxAmtWrapper> resultSplitList = new List<VertexCPQCore.taxAmtWrapper>();
        // build a class to pass into Batchable class
        for(Object obj : resultDeserialized){
            id2TaxAmt = (Map<String, Object>)obj;
            for(String key: id2TaxAmt.keySet()){
                transient VertexCPQCore.taxAmtWrapper resultWrap = new VertexCPQCore.taxAmtWrapper();
                resultWrap.recdId = key;
                resultWrap.taxAmt = (Decimal)id2TaxAmt.get(key);
                resultSplitList.add(resultWrap);
            }
        }
        system.debug('-->Log : VertexGetTaxQueueable: resultSplitList'+resultSplitList);

        transient Id jobId = Database.executeBatch(new VertexCPQBatchable(resultSplitList), VertexCPQCore.batchJobCallout);

    }
}
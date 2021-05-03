public class VertexResponseBatchable implements Database.Batchable<VertexCore.ResponseWrapper>, Database.Stateful, Database.AllowsCallouts {
// public class VertexResponseBatchable implements Database.Batchable<VertexCore.ResponseWrapper>, Database.Stateful, Database.AllowsCallouts {
    
    public list<VertexCore.ResponseWrapper> calloutResults;
    
    public VertexResponseBatchable( list<VertexCore.ResponseWrapper> calloutResults) {   
   
        System.debug('-->Log 0: VertexResponseBatchable: Constructor');
        System.debug('-->Log 0: VertexResponseBatchable: Constructor');
        this.calloutResults = calloutResults;
        System.debug('-->Log 0: VertexResponseBatchable: Constructor: calloutResults::' + calloutResults);
     
    }
        
    public Iterable<VertexCore.ResponseWrapper> start(Database.BatchableContext bc) {
        System.debug('-->Log 1: VertexResponseBatchable: Start Method');
        System.debug('-->Log 0: VertexResponseBatchable: start: calloutResults::' + calloutResults);

        return calloutResults;
    }
    
    public void execute(Database.BatchableContext bc, List<VertexCore.ResponseWrapper> scope){
        
        // HttpResponse res = new HttpResponse();
        // res.setBody(scope[0].reponseBody);
        // System.debug('-->Log VertexResponsebatchable:: Execute: Response boduy::'+scope[0].reponseBody);
        // VertexResponse vr = new VertexResponse(scope[0].reponseType);
        // vr.ParseResponse(res,scope[0].mappingType);
        transient List<Sobject> resultSbjList = new List<Sobject>();
        for(VertexCore.ResponseWrapper tax : scope){
            VertexResponse parser = new VertexResponse(tax.reponseType);
            resultSbjList.addAll(parser.ParseResponse(tax.reponseBody,tax.mappingType));
        }
        if (!resultSbjList.isEmpty()){
            Database.DMLOptions dmlOpts = new Database.DMLOptions();
            dmlOpts.allowFieldTruncation = true;
            try {
                Database.update(resultSbjList, dmlOpts);
            } catch (Exception e){
                System.Debug('Exception '+e);
                VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
            }
        }
    }    

    public void finish(Database.BatchableContext bc){
        // execute any post-processing operations
        System.debug('-->Log 3: VertexResponseBatchable: Finish Method');
        
    } 
}
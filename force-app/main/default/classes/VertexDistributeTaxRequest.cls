global with sharing class VertexDistributeTaxRequest {

	@InvocableMethod(label='Vertex DistributeRequest' description='Initiates a Distribute Tax calculation on all children of parent (all siblings).')
    global static void InvokeQuotationRequests(LIST<InvokeDistributeTaxStructure> requests) {
    	LIST<VertexBaseRequest.InvokeRequestStructure> formattedRequests = new LIST<VertexBaseRequest.InvokeRequestStructure>();
        if(VertexCore.IsResponseRunning != true && VertexCore.ActiveSettings.AllowProcessBuilderRequests__c) {
            VertexCore.IsResponseRunning = true;
            for(InvokeDistributeTaxStructure request : requests){
            	transient VertexBaseRequest.InvokeRequestStructure newReq = new VertexBaseRequest.InvokeRequestStructure();
            	newReq.recordId = request.recordId;
            	newReq.mappingType = request.type;
            	formattedRequests.add(newReq);
            }
            VertexRequest vqr = new VertexRequest('DistributeTax', true);
            if (!requests.isEmpty()) {
                vqr.TaxOnly = requests.get(0).taxOnly;
                vqr.PostToJournal = requests.get(0).postToJournal;
            }
            vqr.InvokeRequestList(formattedRequests, true);
        }
    }

    global class InvokeDistributeTaxStructure {

        @InvocableVariable(required=true)
        global ID recordId;

        @InvocableVariable(required=true)
        global String type;

        @InvocableVariable(required=false)
        global boolean taxOnly;

        @InvocableVariable(required=false)
        global boolean postToJournal;
    }
}
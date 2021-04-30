global with sharing class VertexInvoiceRequest {

	@InvocableMethod(label='Vertex InvoiceRequest' description='Invoices tax on all children of parent (all siblings).')
    global static void InvokeQuotationRequests(LIST<InvokeInvoiceStructure> requests) {
    	LIST<VertexBaseRequest.InvokeRequestStructure> formattedRequests = new LIST<VertexBaseRequest.InvokeRequestStructure>();
        if(VertexCore.IsResponseRunning != true && VertexCore.ActiveSettings.AllowProcessBuilderRequests__c) {
            VertexCore.IsResponseRunning = true;
            for(InvokeInvoiceStructure request : requests){
            	transient VertexBaseRequest.InvokeRequestStructure newReq = new VertexBaseRequest.InvokeRequestStructure();
            	newReq.recordId = request.recordId;
            	newReq.mappingType = request.type;
            	formattedRequests.add(newReq);
            }
            VertexRequest vqr = new VertexRequest('Invoice', true);
            vqr.InvokeRequestList(formattedRequests, true);
        }
    }

    global static List<HttpResponse> InvokeVertexCallout(List<Id> recordIds, String type) {
        LIST<VertexBaseRequest.InvokeRequestStructure> formattedRequests = new LIST<VertexBaseRequest.InvokeRequestStructure>();
        for (Id recordId : recordIds) {
            transient VertexBaseRequest.InvokeRequestStructure newReq = new VertexBaseRequest.InvokeRequestStructure();
            newReq.recordId = recordId;
            newReq.mappingType = type;
            formattedRequests.add(newReq);
        }
        VertexRequest vqr = new VertexRequest('Invoice', false);
        return vqr.InvokeRequestList(formattedRequests, false);
    }

    global class InvokeInvoiceStructure {

        @InvocableVariable(required=true)
        global ID recordId;

        @InvocableVariable(required=true)
        global String type;
    }
}
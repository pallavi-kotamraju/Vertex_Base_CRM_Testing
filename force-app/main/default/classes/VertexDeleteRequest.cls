global class VertexDeleteRequest extends VertexBaseRequest{
	
    //  Prototype for Delete Request
    global VertexDeleteRequest() {
		super('Delete');
		DoParseResponse = false;
	}

    global List<HttpResponse> InvokeRequestList(LIST<Id> transactionIds) {
        List<InvokeRequestStructure> requests = new List<InvokeRequestStructure>();
        for (Id transactionId : transactionIds) {
            InvokeRequestStructure irs = new InvokeRequestStructure();
            irs.recordId = transactionId;
            irs.mappingType = '';
            requests.add(irs);
        }

    	for (InvokeRequestStructure request : requests) {
    		VertexPendingRequest pendingRequest = new VertexPendingRequest(request.recordId,request.mappingType);
    		pendingRequest.xmlBody = GenerateBaseXMLBody(pendingRequest).toXmlString();
    		PendingRequests.add(pendingRequest);
    	}

        //  Enqueue each parent to perform callout to endpoint and handle response (i.e., get tax info and update line items)
		return CompletePendingRequests(requests[0].mappingType, true);
    }

}
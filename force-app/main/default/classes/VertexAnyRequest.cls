global with sharing class VertexAnyRequest {

    @InvocableMethod(label='Vertex Dynamic Tax Handler' description='Either calculate, invoice, or distribute tax on all children of parent (all siblings).')
    global static void InvokeAllRequests(List<InvokeAnyRequestStructure> requests) {
    	List<VertexBaseRequest.InvokeRequestStructure> formattedRequests = new List<VertexBaseRequest.InvokeRequestStructure>();
        if (VertexCore.IsResponseRunning != true && VertexCore.ActiveSettings.AllowProcessBuilderRequests__c) {
            VertexCore.IsResponseRunning = true;
            Set<String> selectedMappings = new Set<String>();
            for (InvokeAnyRequestStructure request : requests){
            	transient VertexBaseRequest.InvokeRequestStructure newReq = new VertexBaseRequest.InvokeRequestStructure();
            	newReq.recordId = request.recordId;
            	newReq.mappingType = request.type;
                selectedMappings.add(newReq.mappingType);
            	formattedRequests.add(newReq);
            }
            //We expect all of the requests to be of the same type
            if (selectedMappings.size() == 1){
                String objMapName = new List<String>(selectedMappings).get(0);
                String xmlMessage = VertexObjectMapping__c.getInstance(objMapName).XMLMessage__c;
                Map<String, String> xmlOpts = new Map<String, String>{'Quote' => 'Quotation', 'Invoice' => 'Invoice', 'Distribute' => 'DistributeTax'};
                VertexRequest vqr = new VertexRequest(xmlOpts.get(xmlMessage), true);
                vqr.InvokeRequestList(formattedRequests, true);
            } else {
                System.debug('Found multiple object mapping selections: ' + selectedMappings);
            }
        }
    }

    global class InvokeAnyRequestStructure {

        @InvocableVariable(required=true)
        global ID recordId;

        @InvocableVariable(required=true)
        global String type;
    }
    
}
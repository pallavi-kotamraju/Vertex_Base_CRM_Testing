global with sharing class VertexQuotationRequest {

    @InvocableMethod(label='Vertex QuotationRequest' description='Calculates tax on all children of parent (all siblings).')
    global static void InvokeQuotationRequests(LIST<InvokeQuoteStructure> requests) {
        System.debug('-->Log 1 : VertexQuotationRequest :InvokeQuotationRequests ');
    	System.debug('-->Log 1.1 : VertexQuotationRequest :InvokeQuotationRequests: VertexCore.ActiveSettings.AllowProcessBuilderRequests__c');
        System.debug('-->Log 1.2 : VertexQuotationRequest :InvokeQuotationRequests: VertexCore.ActiveSettings.AllowProcessBuilderRequests__c : VertexCore.IsResponseRunning' + VertexCore.IsResponseRunning);
        System.debug('-->Log 1.3 : VertexQuotationRequest :InvokeQuotationRequests: VertexCore.ActiveSettings.AllowProcessBuilderRequests__c : VertexCore.ActiveSettings.AllowProcessBuilderRequests__c' + VertexCore.ActiveSettings.AllowProcessBuilderRequests__c);
            
        LIST<VertexBaseRequest.InvokeRequestStructure> formattedRequests = new LIST<VertexBaseRequest.InvokeRequestStructure>();
        if(VertexCore.IsResponseRunning != true && VertexCore.ActiveSettings.AllowProcessBuilderRequests__c) {
            System.debug('-->Log 1.1 : VertexQuotationRequest :InvokeQuotationRequests: VertexCore.ActiveSettings.AllowProcessBuilderRequests__c');
            System.debug('-->Log 1.2 : VertexQuotationRequest :InvokeQuotationRequests: VertexCore.ActiveSettings.AllowProcessBuilderRequests__c : VertexCore.IsResponseRunning' + VertexCore.IsResponseRunning);
            System.debug('-->Log 1.3 : VertexQuotationRequest :InvokeQuotationRequests: VertexCore.ActiveSettings.AllowProcessBuilderRequests__c : VertexCore.ActiveSettings.AllowProcessBuilderRequests__c' + VertexCore.ActiveSettings.AllowProcessBuilderRequests__c);
            VertexCore.IsResponseRunning = true;
            for(InvokeQuoteStructure request : requests){
            	transient VertexBaseRequest.InvokeRequestStructure newReq = new VertexBaseRequest.InvokeRequestStructure();
            	newReq.recordId = request.recordId;
            	newReq.mappingType = request.type;
            	formattedRequests.add(newReq);
                system.debug('-->Log 1.4: newReq.recordId'+ newReq.recordId);
                system.debug('-->Log 1.5: newReq.mappingType'+newReq.mappingType);
            }
            VertexRequest vqr = new VertexRequest('Quotation', true);
            System.debug('Before first callout');
            vqr.InvokeRequestList(formattedRequests, true);
            System.debug('After first callout');
            System.debug('Before second callout');
           vqr.InvokeRequestList(formattedRequests, true);        
          System.debug('After second callout');    
        }
    }

    global static List<HttpResponse> InvokeVertexCallout(List<Id> recordIds, String type) {
        System.debug('-->Log 2 : VertexQuotationRequest :InvokeVertexCallout ');
        LIST<VertexBaseRequest.InvokeRequestStructure> formattedRequests = new LIST<VertexBaseRequest.InvokeRequestStructure>();
        for (Id recordId : recordIds) {
            transient VertexBaseRequest.InvokeRequestStructure newReq = new VertexBaseRequest.InvokeRequestStructure();
            newReq.recordId = recordId;
            newReq.mappingType = type;
            formattedRequests.add(newReq);
            system.debug('-->Log 2.1: newReq.recordId'+ newReq.recordId);
            system.debug('-->Log 2.1: newReq.mappingType'+newReq.mappingType);
        }   
        VertexRequest vqr = new VertexRequest('Quotation', false);
        return vqr.InvokeRequestList(formattedRequests, false);
    }

    global class InvokeQuoteStructure {

        @InvocableVariable(required=true)
        global ID recordId;

        @InvocableVariable(required=true)
        global String type;
    }
    
}
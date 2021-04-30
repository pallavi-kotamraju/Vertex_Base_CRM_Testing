@RestResource(urlMapping='/VertexCPQ/*')
global with sharing class VertexRESTHandler {
    @HttpPost
    global static string getTax(string id, string type) {
        System.debug('-->Log 1 : VerextRestHandler');
        transient string mappingName = 'CPQ';
        transient string calloutError = '';
        transient string returnString='';       //     Will hold JSON
        transient map<String, decimal> idToTaxValue = new map<String, decimal>();   //  Line id to relate tax value
        //  Get Settings:
        Map<String, Map<String, String>> settings = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new list<object>{'fetchObjMap', new LIST<String>{'CPQ'}});
        transient string  xmlCalloutType = settings.get(mappingName).get('XMLMessage__c');
        List<HttpResponse> responses = new LIST<HttpResponse>();
        if( xmlCalloutType == 'Quote'){
            System.debug('-->Log 1.1 : VerextRestHandler: xmlCalloutType == Quote');
            responses = VertexQuotationRequest.InvokeVertexCallout(new List<Id> {id}, mappingName);
            System.Debug('responses '+responses);
        }
        else if ( xmlCalloutType == 'Invoice'){
            System.debug('-->Log 1.2 : VerextRestHandler: xmlCalloutType == Invoice');
            responses = VertexInvoiceRequest.InvokeVertexCallout(new List<Id> {id}, mappingName);
        }
        if (responses.isEmpty()) {
            System.debug('-->Log 1.3 : VerextRestHandler: responses.isEmpty()');
            calloutError = 'No responses returned from Vertex';
            system.debug('No responses returned from Vertex');
        }
        else {
            transient String itemId;
            for (HttpResponse response : responses) {
                if (response.getStatusCode() == 200) {
                    System.debug('-->Log 2 : VerextRestHandler: response.getStatusCode() == 200');
                    //  Properties for XML structure
                    transient string URN = 'urn:vertexinc:o-series:tps:7:0';

                    Dom.XMLNode responseNode;
                    if( xmlCalloutType == 'Quote')
                        responseNode = VertexRESTHandler.ExtractResponseNode(response.getBodyDocument(), 'QuotationResponse');
                    else if ( xmlCalloutType == 'Invoice')
                        responseNode = VertexRESTHandler.ExtractResponseNode(response.getBodyDocument(), 'InvoiceResponse');

                    system.debug('responseNode:'+ responseNode);

                    //Grab the Transaction level tax and Transaction ID
                    string transId = responseNode.getAttributeValue('transactionId' ,'');
                    Dom.XMLNode totalTransTaxNode = responseNode.getChildElement('TotalTax' , URN);
                    decimal TotalTax = decimal.valueOf(totalTransTaxNode.getText());
                    idToTaxValue.put(transId, decimal.valueOf(totalTransTaxNode.getText()));

                    //  Loop through all children and work with specific nodes we want - currently all LineItems
                    if (responseNode!=null)
                    for (Dom.XMLNode node :responseNode.getChildElements()) {
                        if (node.getName() == 'LineItem') {
                            itemId = node.getAttributeValue('lineItemId' ,'');
                            
                            //  Each LineItem node has several children, TotalTax is one of them
                            Dom.XMLNode totalTaxNode = node.getChildElement('TotalTax', URN);
                            
                            //  If there is a tax amount returned, replace default value of 0
                            if (totalTaxNode != null)
                                idToTaxValue.put(itemId, decimal.valueOf(totalTaxNode.getText()));
                        }
                    }
                }
            }
        }
        return JSON.serialize(idToTaxValue);
    }

    global static Dom.XMLNode ExtractResponseNode(Dom.Document responseDocument, String responseType) {
        //  Properties for XML structure
        transient string SoapEnv = 'http://schemas.xmlsoap.org/soap/envelope/';
        transient string URN = 'urn:vertexinc:o-series:tps:7:0';

        Dom.XMLNode envelope = responseDocument.getRootElement();
        Dom.XMLNode Header = envelope.getChildElement('Header', SoapEnv);
        Dom.XMLNode body = envelope.getChildElement('Body', SoapEnv);
        Dom.XMLNode vertexEnvelopeNode = body.getChildElement('VertexEnvelope', URN);
        Dom.XMLNode responseNode = vertexEnvelopeNode.getChildElement(responseType, URN);
        return responseNode;
    }
}
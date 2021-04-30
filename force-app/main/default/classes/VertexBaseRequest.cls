public abstract class VertexBaseRequest {

    public VertexBaseRequest(String requestType) {
        System.debug('****Vertext BAse rtequest**');
        this.RequestType = requestType;
    }

    //  properties used by the request
    public  string Method = 'POST';
    public  string ContentType = 'text/xml';

    protected String RequestType {
        get {
            if (RequestType == null)
                RequestType = '';
            return RequestType;
        }
        set;
    }

    protected boolean DoParseResponse {get; set;}
    //used to check if the id is valid
    private static final Integer MIN_ID_LENGTH = 15;

    //  Collection of wrapper items w/ relevent pieces of process to be built, processed, and enqueued
    public list<VertexPendingRequest> PendingRequests { get { if (PendingRequests == null) PendingRequests = new list<VertexPendingRequest>(); return PendingRequests; } set; }

    public List<HttpResponse> CompletePendingRequests(String mappingType, boolean isAsynchronous) {
        System.Debug('===VertexBaseRequest.CompletePendingRequest===');
        System.Debug('mappingType '+mappingType);
        System.Debug('isAsynchronous '+isAsynchronous);
        List<HttpResponse> responses = new List<HttpResponse>();
        if (!PendingRequests.isEmpty()) {
            System.debug('-->Log 13 : VertexBaseRequest CompletePendingRequests : Pending request not Empty');
            set<Id> parentIds = new set<Id>();
            for (VertexPendingRequest vpq : PendingRequests) {
                parentIds.add(vpq.parentId);
            }
            // call set status method
            setTaxCalloutStatus(parentIds, mappingType, false, true, 'Processing');
            System.debug('-->Log 14 : VertexBaseRequest CompletePendingRequests : sending values to setTaxCalloutStatus');
            
            List<String> xmlBodies = new List<String>();
            //  Obj 4:  Loop through the pending requests, enqueuing aech in its own async job
            for (VertexPendingRequest pendingRequest :PendingRequests) {
                xmlBodies.add(pendingRequest.XMLBody);
            }
            
            if (isAsynchronous){
                System.debug('-->Log 15 : VertexBaseRequest CompletePendingRequests : Asynchronous call');
                ID jobID = System.enqueueJob(new QueueCallouts(VertexCore.ActiveSettings.TaxCalculationURL__c, ContentType, Method, xmlBodies, mappingType, RequestType, DoParseResponse));
            } else {
                System.debug('-->Log 16 : VertexBaseRequest CompletePendingRequests : synchronous  call');
                for (String body : xmlBodies) {
 
                    Http http = new Http();
                    HttpRequest req = BuildRequest(body); 
                    HTTPResponse res = http.send(req);  
                    HandleResponse(req, res, RequestType, mappingType, DoParseResponse);
                    responses.add(res);
                }
            }
                
        
        }
        return responses;
    }

    public HttpRequest BuildRequest(String body) {
        Http http = new Http();
        HttpRequest req = new HttpRequest(); 
        
        //  Setup the request
        req.setMethod(Method);
        req.setHeader('Content-Type', ContentType);
        req.setEndpoint(VertexCore.ActiveSettings.TaxCalculationURL__c);
        
        //  Set up the request's body
        req.setBody(body);
        return req;
    }

    public DOM.Document GenerateBaseXMLBody(VertexPendingRequest pendingRequest) {
        //  Property for new DOM doc to help in generation of appropriate request XML
        DOM.Document doc = new DOM.Document();
        
        //  Parent Envelope Level - <soapenv:Envelope ns=""/>
        DOM.XmlNode SoapEnvelopeNode = doc.createRootElement('Envelope', VertexCore.SoapEnv, 'soapenv');
        SoapEnvelopeNode.setNamespace('soapenv', VertexCore.SoapEnv);
        SoapEnvelopeNode.setNamespace('urn', VertexCore.URN);
        SoapEnvelopeNode.addChildElement('soapenv:Header', null, null);
        
        //  Envelope Body
        DOM.XmlNode soapBodyNode = SoapEnvelopeNode.addChildElement('soapenv:Body', null, null);
        
        //  Vertex Envelope
        DOM.XmlNode vertexEnvelopeNode = soapBodyNode.addChildElement('urn:VertexEnvelope', null, null);
        //  Login set
        DOM.XmlNode loginNode = vertexEnvelopeNode.addChildElement('urn:Login', null, null);
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Login.TrustedID))
            loginNode.addChildElement('urn:TrustedId', null, null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Login.TrustedId);
        else if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Login.UserName)
                 && String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Login.Password)) {
            loginNode.addChildElement('urn:UserName', null, null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Login.UserName);
            loginNode.addChildElement('urn:Password', null, null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Login.Password);
        
        } else {
            VertexLogging.Log('Error', 'Login credentials have not been specified.');
            doc = null;
        }
        
        if (doc != null) {
            //  pendingRequest Set
            DOM.XmlNode requestNode = vertexEnvelopeNode.addChildElement('urn:' + RequestType + 'Request', null, null);
            //requestNode.setAttribute('documentNumber', 'INV0001');
            requestNode.setAttribute('transactionId', pendingRequest.parentId);
            requestNode.setAttribute('returnAssistedParametersIndicator', 'true');
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.DocumentNumber))
                requestNode.setAttribute('documentNumber', pendingRequest.RequestStructure.VertexEnvelope.Request.DocumentNumber);
            requestNode.setAttribute('documentDate', pendingRequest.RequestStructure.VertexEnvelope.Request.DocumentDate);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.PostingDate))
                requestNode.setAttribute('postingDate', pendingRequest.RequestStructure.VertexEnvelope.Request.PostingDate);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.TransactionType))
                requestNode.setAttribute('transactionType', pendingRequest.RequestStructure.VertexEnvelope.Request.TransactionType);    //Default is "SALE"
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.DeliveryTerm))
                requestNode.setAttribute('deliveryTerm', pendingRequest.RequestStructure.VertexEnvelope.Request.DeliveryTerm);
        }
        return doc;
    }

    public static void HandleResponse(HttpRequest req, HttpResponse res, String responseType, String taxTypeCheck, boolean parseResponse) {
        System.Debug('===VertexBaseRequest.HandleResponse===');
        System.Debug('===VertexBaseRequest.HandleResponse=== parseResponse ' + parseResponse);
        System.Debug('');
        if (parseResponse == null)
            parseResponse = false;

        //  Review the response for success or otherwise
        if (res == null) {
            System.debug('-->Log 17 VertexBAseRequest : HandleResponse : if res is null');
            // Construct a temporary doc - for some reason req.getBodyDocument() returns null 
            Dom.Document tempReqDoc = new Dom.Document();
            tempReqDoc.load(req.getBody());
            set<Id> lineItemIdsSet = new set<Id>();
            // Get the request node and add all line item ids that were attempted and failed to the set
            Dom.XMLNode requestNode = VertexCore.ExtractEnvelopeChildNode(tempReqDoc, ResponseType + 'Request');
            for (Dom.XMLNode node :requestNode.getChildElements()) {
                if (String.isNotBlank(node.getAttributeValue('lineItemId' ,'')) && node.getAttributeValue('lineItemId','').length() >= MIN_ID_LENGTH) {
                    lineItemIdsSet.add(node.getAttributeValue('lineItemId', ''));
                }
            }

            //  null response - log error
            VertexLogging.Log('Error', 'An error was encountered while attempting to callout to the Vertex endpoint.', req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), '', 'Response is null', 500);
            setTaxCalloutStatus(lineItemIdsSet, taxTypeCheck, true, false, 'Error');

        } else if (res.getStatusCode() == 200) {
            System.debug('-->Log 18 VertexBAseRequest : HandleResponse : if res  200');
            //  Create Success Log
            VertexLogging.Log('Debug', 'Callout Success', req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
            System.debug('-->log:: veretxBAserequest:: '+ VertexCore.RemoveCalloutCredentials(req.getBody()));
            if (parseResponse) {
                //Queable repsponse can be made.
                //  Hand-off to dedicated QuotationRespone handler
                system.debug('-->Log :parseResponse :::'+ parseResponse);
                system.debug('-->Log :responseType :::'+ responseType);
                system.debug('-->Log :taxTypeCheck :::' + taxTypeCheck);
               // database.executeBatch(new VertexResponseBatchable(responseType,res,taxTypeCheck));
                VertexResponse parser = new VertexResponse(responseType);
              //  parser.ParseResponse(res,taxTypeCheck);
                system.debug('-->Log :VerextBaseRequest:Went of response batchable and cam back :::');
            }
        
        //  Something happened; report it and add the line item ids to the set of failed ids
        } else {
            System.Debug('-->Log 19 : VertexBAseRequest: Response is neither null nor sucess');
            // Construct a temporary doc - for some reason req.getBodyDocument() returns null 
            Dom.Document tempReqDoc = new Dom.Document();
            tempReqDoc.load(req.getBody());
            set<Id> lineItemIdsSet = new set<Id>();
            // Get the request node and add all line item ids that were attempted and failed to the set
            Dom.XMLNode requestNode = VertexCore.ExtractEnvelopeChildNode(tempReqDoc, ResponseType + 'Request');
            for (Dom.XMLNode node :requestNode.getChildElements()) {
                if (String.isNotBlank(node.getAttributeValue('lineItemId' ,'')) && node.getAttributeValue('lineItemId','').length() >= MIN_ID_LENGTH) {
                    VertexCore.FailedLineItemIds.add(node.getAttributeValue('lineItemId' ,''));
                    lineItemIdsSet.add(node.getAttributeValue('lineItemId', ''));
                }
            }

            //  Connectivity issue - log error
            VertexLogging.Log('Error', 'An error was encountered while attempting to callout to the Vertex endpoint.', req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
            setTaxCalloutStatus(lineItemIdsSet, taxTypeCheck, true, false, 'Error');
            System.Debug('-->Log 20 : VertexBAseRequest: Setting setTaxCalloutStatus to Error');
        }
        
        //  Commit anything that was delayed and now should be
        System.Debug('-->Log 21 : VertexBAseRequest: HandelResponse : Now going to CommitDelay() ');
        VertexLogging.CommitDelayed();
    }

    //  Method to queue up a callout along w/ the appropriate override to handle the response payload
    public class QueueCallouts extends VertexCalloutsQueueable {

        public QueueCallouts(string endpoint, string contentType, string method, List<string> bodies, String type, String responseType, boolean parseResponse) {
            super(endpoint, contentType, method, bodies, type, responseType, parseResponse);
        }
         //transient List<VertexCore.ResponseWrapper> resultSplitList = new List<VertexCore.ResponseWrapper>();
          
        public override void ResponseHandler(HttpRequest req, HTTPResponse res) {
            
        //    VertexBaseRequest.HandleResponse(req, res, responseType, taxTypeCheck, ParseCalloutResponse);
            VertexBaseRequest.HandleResponse(req, res, responseType, taxTypeCheck, false);
          transient List<VertexCore.ResponseWrapper> resultSplitList = new List<VertexCore.ResponseWrapper>();
        
        transient VertexCore.ResponseWrapper resultWrap = new VertexCore.ResponseWrapper();
            resultWrap.reponseBody = (string)res.getBody();
            resultWrap.mappingType = taxTypeCheck;
            resultWrap.reponseType = responseType;
            resultSplitList.add(resultWrap);
       //  VertexCore.resultSplitList.add(resultWrap);
            System.debug('-->Log VertexbaseRequest:: resultSplitList::'+ resultSplitList);
           
           // transient map<String, decimal> idToTaxValue = new map<String, decimal>();
           
            /*if (res.getStatusCode() == 200) {
                //  Properties for XML structure
                transient string URN = 'urn:vertexinc:o-series:tps:7:0';
                transient String itemId;
                Dom.XMLNode responseNode;
                if(responseType == 'Quotation')
                    responseNode = VertexCore.ExtractEnvelopeChildNode(res.getBodyDocument(), 'QuotationResponse');
                else if ( responseType == 'Invoice')
                    responseNode = VertexCore.ExtractEnvelopeChildNode(res.getBodyDocument(), 'InvoiceResponse');
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
           // JSON.serialize(idToTaxValue);
           System.debug('(-->log VertexBaseRequest:idToTaxValue:'+idToTaxValue);
            transient String result = JSON.serialize(idToTaxValue);
            result='['+result+']';
            transient List<Object> resultDeserialized = (List<Object>)JSON.deserializeUntyped(result);
            transient Map<String, Object> id2TaxAmt;
            transient List<VertexCore.ResponseWrapper> resultSplitList = new List<VertexCore.ResponseWrapper>();
            // build a class to pass into Batchable class
            for(Object obj : resultDeserialized){
                id2TaxAmt = (Map<String, Object>)obj;
                for(String key: id2TaxAmt.keySet()){
                    transient VertexCore.ResponseWrapper resultWrap = new VertexCore.ResponseWrapper();
                    resultWrap.recdId = key;
                    resultWrap.taxAmt = (Decimal)id2TaxAmt.get(key);
                    resultSplitList.add(resultWrap);
                }
            }
         */
          
        //   if (res.getStatusCode() == 200) {
        //     transient VertexCore.ResponseWrapper resultWrap = new VertexCore.ResponseWrapper();
        //     transient List<VertexCore.ResponseWrapper> resultSplitList = new List<VertexCore.ResponseWrapper>(); 
              
        //       resultWrap.reponseBody=(string)res.getBody();
        //       resultWrap.reponseType=responseType;
        //       resultWrap.mappingType=taxTypeCheck;
        //     resultSplitList.add(resultWrap);
        //      // string calloutRes = (string)res.getBody();
              
        //       transient Id jobId = Database.executeBatch(new VertexResponseBatchable(resultSplitList), VertexCore.batchJobCallout);
        //   }
        transient Id jobId = Database.executeBatch(new VertexResponseBatchable(resultSplitList), VertexCore.batchJobCallout);
            if (Bodies.size() > 1) {
                Bodies.remove(0);
                System.enqueueJob(new QueueCallouts(Endpoint, ContentType, Method, Bodies, taxTypeCheck, ResponseType, ParseCalloutResponse));
            }
            
            
        }
    }

    //  Wrapper class to assist putting the pieces together
    public class VertexPendingRequest {
        
        public VertexStructureRequest RequestStructure { get; set; }
        public sObject Parent { get; set; }
        public Id parentId { get; set;}
        public string XMLBody { get; set; }
        public string mappingType {get; set;}
        
        public VertexPendingRequest(sObject parent,String mappingType) {
            RequestStructure = new VertexStructureRequest();
            this.Parent = parent;
            this.parentId = parent.Id;
            this.mappingType = mappingType;
        }
        public VertexPendingRequest(Id parentId,String mappingType) {
            RequestStructure = new VertexStructureRequest();
            this.parentId = parentId;
            this.mappingType = mappingType;
        }
    }

    public class InvokeRequestStructure {
        public ID recordId;
        public String mappingType;  //mapping name
    }

    public static void setTaxCalloutStatus (set<Id> idsSet, string mappingType, boolean isResponseRunning, boolean isParent, string statusMsg) {
        System.debug('--> Log 20 : VertextBaseRequest : Statusmesage : '+statusMsg);
        
        VertexObjectMapping__c objMap = VertexObjectMapping__c.getValues(mappingType);
        
        if (objMap != null && objMap.ChildSObject__c != null && objMap.TaxCalloutStatus__c != null && (isParent == false || (isParent && objMap.ParentLookup__c != null))) {

            //  Prevent trigger from running on post response update
            if (isResponseRunning)
                VertexCore.IsResponseRunning = TRUE;
            
            string query = 'SELECT Id FROM ';
            query += objMap.ChildSObject__c;
            if (isParent)
                query += ' WHERE ' + objMap.ParentLookup__c + ' IN :idsSet';
            else
                query += ' WHERE Id IN :idsSet';
            
            List<sObject> updateOLIs;
            try {
                updateOLIs = database.query(query);
            } catch (Exception e){
                VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
            }

            for (sObject oli : updateOLIs)
                oli.put(objMap.TaxCalloutStatus__c, statusMsg + ': ' + System.Now().format());

            if (!updateOLIs.isEmpty()){
                try {
                    Database.update(updateOLIs);
                } catch (Exception e){
                    VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
                }
            }
                
        }
    }
}
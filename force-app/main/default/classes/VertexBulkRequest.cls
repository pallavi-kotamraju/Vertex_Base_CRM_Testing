public with sharing class VertexBulkRequest implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    private List<Sobject> parentsWithChildren;
    private VertexMapping vMap;
    private String requestType;
    private boolean doParseResponse;
    private String mappingType;
    VertexRequest vRequest; 
    VertexBaseRequest.VertexPendingRequest pendingRequest;
    String xmlBody = '';
    String endingXmlBody = '</urn:QuotationRequest></urn:VertexEnvelope></soapenv:Body></soapenv:Envelope>';
    Integer lineItemNumber = 1;


    public VertexBulkRequest(List<sObject> parentsWithChildren, VertexMapping vMap, String requestType, boolean doParseResponse, String mappingType) {
        this.parentsWithChildren = parentsWithChildren;
        this.vMap = vMap;
        this.requestType = requestType;
        this.doParseResponse = doParseResponse;
        this.mappingType = mappingType;
        System.debug('-->Log 0 : VertextBulkRequest');
        pendingRequest = new VertexBaseRequest.VertexPendingRequest(parentsWithChildren[0],mappingType);
        
        vRequest = new VertexRequest(requestType,doParseResponse);
        vRequest.vMap = vMap;
        vRequest.setRequestFromTransaction(pendingRequest,true);
        vRequest.generateXMLBody(pendingRequest);
        xmlBody = pendingRequest.xmlBody;

        //remove ending
        xmlBody = xmlBody.removeEnd(endingXmlBody);        
    }

    public Database.QueryLocator start(Database.BatchableContext BC){
        System.debug('-->Log 1 : VertextBulkRequest:  Database.QueryLocator start');
        //create a soql string using the child fields
        SObject parentObj = parentsWithChildren[0];
        Id parentId = parentObj.Id;
        String queryString = getQueryString(vMap, vRequest);
        return Database.getQueryLocator(queryString);
    }

    public void execute(Database.BatchableContext BC, List<Sobject> scope){
        //get all line items in this entry
        System.debug('-->Log 2 : VertextBulkRequest:  Database.QueryLocator Excute');
        List<VertexStructureRequest.RequestLineItem> lineItems = getLineItems(scope, vRequest,lineItemNumber);

        DOM.Document doc = vRequest.GenerateBaseXMLBody(pendingRequest);
        DOM.XmlNode requestNode = doc.getRootElement().getChildElement('soapenv:Body', null).getChildElement('urn:VertexEnvelope', null).getChildElement('urn:' + RequestType + 'Request', null);

        //  Line Item Set
        List<Dom.XMLNode> lineItemNodes = getLineItemNodes(lineItems,pendingRequest,requestType,vRequest);

        String lineItemXML = getXMLString(lineItemNodes);
        xmlBody += lineItemXML;
    }

    public void finish(Database.BatchableContext BC){
        System.debug('-->Log 3 : VertextBulkRequest:  finish');
        xmlBody += endingXmlBody;
        try{
            Http http = new Http();
            HttpRequest req = vRequest.buildRequest(xmlBody);
            req.setTimeout(120000);
            HTTPResponse res = http.send(req);  
            VertexBaseRequest.HandleResponse(req, res, RequestType, mappingType, DoParseResponse);
        }catch(CalloutException e){
            VertexLogging.log('Error','Callout Failed: ' + e.getMessage());
        }
    }

    private static String getXMLString(List<DOM.XMLNode> lineItemNodes){
        DOM.Document liDoc = new DOM.Document();
        
        //  Parent Envelope Level - <soapenv:Envelope ns=""/>
        DOM.XmlNode liNode = liDoc.createRootElement('lineItemDoc',null,null);

        for(Dom.XMLNode lineItemNode : lineItemNodes){
            liNode.insertBefore(lineItemNode,null);
        }

        //we have to remove the end of the string in order to continue the ordering of the line items
        String lineItemXML = liDoc.toXmlString();
        lineItemXML = lineItemXML.remove('<?xml version="1.0" encoding="UTF-8"?><lineItemDoc>');
        lineItemXML = lineItemXML.remove('</lineItemDoc>');

        return lineItemXML;
    }

    private static List<Dom.XMLNode> getLineItemNodes(List<VertexStructureRequest.RequestLineItem> lineItems, VertexBaseRequest.VertexPendingRequest pendingRequest, String requestType, VertexRequest vRequest){
        DOM.Document doc = vRequest.GenerateBaseXMLBody(pendingRequest);
        DOM.XmlNode requestNode = doc.getRootElement().getChildElement('soapenv:Body', null).getChildElement('urn:VertexEnvelope', null).getChildElement('urn:' + RequestType + 'Request', null);

        //  Line Item Set
        List<Dom.XMLNode> lineItemNodes = new List<Dom.XMLNode>();
        for (VertexStructureRequest.RequestLineItem li :lineItems) {
            DOM.XMLNode lineItemNode = vRequest.createChildNode(li,requestNode,li.lineItemNumber);
            lineItemNodes.add(lineItemNode);
        }

        return lineItemNodes;
    }

    private List<VertexStructureRequest.RequestLineItem> getLineItems(List<SObject> scope,VertexRequest vRequest, Integer lineItemNumber){
        List<VertexStructureRequest.RequestLineItem> lineItems = new List<VertexStructureRequest.RequestLineItem>();
        
        for(SObject s : scope){
            VertexStructureRequest.RequestLineItem lineItem = vRequest.createLineItem(s, lineItemNumber, true);

            lineItems.add(lineItem);
            lineItemNumber++;
        }

        return lineItems;
    }

    private static String getChildFieldsString(VertexRequest vRequest){
        Set<String> selectChildFields = vRequest.selectChildFields();
        vRequest.setOriginFields(selectChildFields);
        String selectChildFieldsStr = vRequest.getChildFieldsString(selectChildFields);
        return selectChildFieldsStr;
    }

    @testVisible
    private static String getQueryString(VertexMapping vMap, VertexRequest vRequest){
        //build variables required for start query
        String childName = VMap.ObjMap.ChildSobject__c;
        STring parentLookup = VMap.ObjMap.ParentLookup__c;

        //get child fields
        String selectChildFieldsStr = getChildFieldsString(vRequest);

        //create a soql string using the child fields
        String queryString = 'SELECT ' + selectChildFieldsStr + ' FROM ' + childName + ' WHERE ' + parentLookup  + ' = :parentId';
        return queryString;
    }
}
public with sharing class VertexResponse {

	public VertexResponse(String responseType) {
        System.debug('-->Log1 : VertexResponse');
		this.ResponseType = responseType;
	}

	private String ResponseType {
		get {
			if (ResponseType == null)
				ResponseType = '';
			return ResponseType;
		}
		set;
    }
    
    public boolean doesFieldExist(String objName, string fieldName)
    {
        try {
            SObject so = Schema.getGlobalDescribe().get(objName).newSObject();
            return so.getSobjectType().getDescribe().fields.getMap().containsKey(fieldName);
        }
        catch(Exception ex) {}
         
        return false;
    }
    
    //  Logic called from VertexRequest class' response handler override; take the tax details in the response and perform necessary record creation/updates
    //public void ParseResponse(HTTPResponse res, String taxCheckType) {
        public list<Sobject> ParseResponse(string respString, String taxCheckType) {
            DOM.Document res = new DOM.Document ();
        res.load(respString);
        system.debug(LoggingLevel.WARN, '===Log-->Parse' + ResponseType + 'Response===');
        system.debug(LoggingLevel.ERROR, '===Lof-->res:  ' + res);
        system.debug(LoggingLevel.ERROR, '===Lof-->res:  ' + taxCheckType);
        
        //  Map to later help populating oli's w/ tax amount for post response update
        map<id, VertexStructureResponse.ResponseLineItem> liId2Response = new map<id, VertexStructureResponse.ResponseLineItem>();
    
            
        //  Prevent trigger from running on post response update
        VertexCore.IsResponseRunning = TRUE;

        VertexStructureResponse responseStructure = new VertexStructureResponse();
        System.debug('-->Log : VertexResponse: responseStructure ::: '+ responseStructure);

        // get the response node from the response - only currently interested in Response children
        Dom.XMLNode responseNode = VertexCore.ExtractEnvelopeChildNode(res, ResponseType + 'Response');
        System.debug('-->Log : VertexResponse res.getBodyDocument():::'+ res);
        System.debug('-->Log : VertexResponse ResponseType:::'+ ResponseType);
        //  List to be filled with Transactions to update
        list<sObject> updateTrans = new LIST<sObject>();
        String soqlStr;
        VertexStructureResponse.VertexResponse trans = new VertexStructureResponse.VertexResponse();
        VertexObjectMapping__c objMap = VertexObjectMapping__c.getValues(taxCheckType);
        //  Get the name of the field on the object that holds the field to update the Transaction Tax Amount
        String transTaxAmt = String.valueOf(objMap.TransactionTaxAmount__c);
        Id transId;
        trans.transactionId = responseNode.getAttributeValue('transactionId' ,'');
        transId = trans.transactionId;
        System.debug('-->log: VertexResponse: responseNode.transId::'+transId);
        //  Set to store transaction Id's retrieved from the response node
        set<Id> transIds = new set<Id>();
        transIds.add(transId);
        Dom.XMLNode totalTransTaxNode = responseNode.getChildElement('TotalTax' , VertexCore.URN);
        trans.TotalTax = decimal.valueOf(totalTransTaxNode.getText());
        System.debug('-->Log : VertexResponse  :objMap ::: ' + objMap);
        System.debug('-->Log : VertexResponse  :transTaxAmt ::: ' + transTaxAmt);
        System.debug('-->Log : VertexResponse  :totalTransTaxNode ::: ' + totalTransTaxNode);
        System.debug('-->Log : VertexResponse  :trans.TotalTax ::: ' + trans.TotalTax);
        System.debug('-->Log : VertexResponse::doesFieldExist(objMap.ParentSObject__c, transTaxAmt ) ::: ' + objMap.ParentSObject__c);
        System.debug('-->Log : VertexResponse::doesFieldExist(objMap.ParentSObject__c, transTaxAmt ) ::: ' + objMap.ParentSObject__c);

       // updateTrans.isEmpty()
        //  Query to get transactions from Id's in response node
        if (objMap != null) {
            System.debug('-->Log : VertexResponse  :objMap != null ::: ' + totalTransTaxNode);

            if (doesFieldExist(objMap.ParentSObject__c, transTaxAmt )) {
                System.debug('-->Log : VertexResponse::doesFieldExist(objMap.ParentSObject__c, transTaxAmt ) ::: ' + objMap.ParentSObject__c);
                soqlStr = 'SELECT Id, '+ transTaxAmt;
                soqlStr += ' FROM ' + objMap.ParentSObject__c + ' WHERE Id IN :transIds';

                try{
                    updateTrans = database.query(soqlStr);
                    System.Debug('===updateTrans '+JSON.serialize(updateTrans));
                } catch (Exception e){
                    System.debug('Exception '+e);
                    VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
                }
                

                //  Store Total Tax in Transaction Tax Amount
                for (sObject transactionToUpdate : updateTrans) {
                    if (trans.TotalTax != null)
                        transactionToUpdate.put(String.valueOf(objMap.TransactionTaxAmount__c), trans.TotalTax);
                        system.debug('-->Log: VertexResponse: Store total TAx:::' + trans.TotalTax);                }
            }
        }
        
        //  Update Transactions with Transaction Tax Amount
        // if (!updateTrans.isEmpty()){
        //     Database.DMLOptions dmlOpts = new Database.DMLOptions();
        //     dmlOpts.allowFieldTruncation = true;
        //     try {
        //         Database.update(updateTrans, dmlOpts);
        //     } catch (Exception e){
        //         System.Debug('Exception '+e);
        //         VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
        //     }
            
        

        //  Loop through all QR's children and work with specific nodes we want - currently all LineItems
        for (Dom.XMLNode node : responseNode.getChildElements()) {
            if (node.getName() == 'LineItem') {
                
                VertexStructureResponse.ResponseLineItem lineItem = new VertexStructureResponse.ResponseLineItem();
                
                //  Properties to hold returned values, will be placed in the map, and later applied to update OLIs
                string lineItemTax = '0';
                string lineItemId = node.getAttributeValue('lineItemId' ,'');
                
                //  Each LineItem node has several children, TotalTax is one of them
                Dom.XMLNode totalTaxNode = node.getChildElement('TotalTax', VertexCore.URN);
                
                //  If there is a tax amount retVertexCore.URNed, replace default value of 0
                if (totalTaxNode != null)
                    lineItem.TotalTax = decimal.valueOf(totalTaxNode.getText());
                
                //  Create Tax Detail
                for (Dom.XMLNode taxesNode : node.getChildElements()) {
                    if (taxesNode.getName() == 'Taxes') {

                        VertexStructureResponse.ResponseLineItemTaxes taxBlock = new VertexStructureResponse.ResponseLineItemTaxes();
                        
                        //  Taxes node level
                        taxBlock.Situs = taxesNode.getAttributeValue('situs', '');
                        taxBlock.TaxCollectedFromParty = taxesNode.getAttributeValue('taxCollectedFromParty', '');
                        taxBlock.TaxResult = taxesNode.getAttributeValue('taxResult', '');
                        taxBlock.TaxStructure = taxesNode.getAttributeValue('taxStructure', '');
                        taxBlock.TaxType = taxesNode.getAttributeValue('taxType', '');
                        taxBlock.TaxCode = taxesNode.getAttributeValue('taxCode', '');
                        taxBlock.VertexTaxCode = taxesNode.getAttributeValue('vertexTaxCode', '');
                        
                        //  Taxes.Jurisdiction
                        Dom.XMLNode jurisdictionNode = taxesNode.getChildElement('Jurisdiction', VertexCore.URN);
                        if (jurisdictionNode != null) {
                            taxBlock.Jurisdiction.Jurisdiction = jurisdictionNode.getText();
                            taxBlock.Jurisdiction.JurisdictionId = integer.valueOf(jurisdictionNode.getAttributeValue('jurisdictionId', ''));
                            taxBlock.Jurisdiction.JurisdictionLevel = jurisdictionNode.getAttributeValue('jurisdictionLevel', '');
                        }
                        
                        //  Taxes.Calculated Tax
                        Dom.XMLNode calculatedTaxNode = taxesNode.getChildElement('CalculatedTax', VertexCore.URN);
                        if (calculatedTaxNode != null)
                            taxBlock.CalculatedTax.CalculatedTax = decimal.valueOf(calculatedTaxNode.getText());
                        
                        //  Taxes.Effective Rate
                        Dom.XMLNode effectiveRateNode = taxesNode.getChildElement('EffectiveRate', VertexCore.URN);
                        if (effectiveRateNode != null)
                            taxBlock.EffectiveRate.EffectiveRate = decimal.valueOf(effectiveRateNode.getText());
                        
                        //  Taxes.Taxable
                        Dom.XMLNode taxableNode = taxesNode.getChildElement('Taxable', VertexCore.URN);
                        if (taxableNode != null)
                            taxBlock.Taxable.Taxable = decimal.valueOf(taxableNode.getText());
                        
                        //  Taxes.Imposition
                        Dom.XMLNode impositionNode = taxesNode.getChildElement('Imposition', VertexCore.URN);
                        if (impositionNode != null) {
                            taxBlock.Imposition.Imposition = impositionNode.getText();
                            taxBlock.Imposition.ImpositionId = impositionNode.getAttributeValue('impositionId', '');
                        }
                        
                        //  Taxes.Imposition Type
                        Dom.XMLNode impositionTypeNode = taxesNode.getChildElement('ImpositionType', VertexCore.URN);
                        if (impositionTypeNode != null) {
                            taxBlock.ImpositionType.ImpositionType = impositionTypeNode.getText();
                            taxBlock.ImpositionType.ImpositionTypeId = impositionTypeNode.getAttributeValue('impositionTypeId', '');
                        }

                        //  Taxes.InvoiceTextCode collection
                        for (Dom.XMLNode invTextCodeNode : taxesNode.getChildElements()){
                            if (invTextCodeNode.getName() == 'InvoiceTextCode' && String.isNotBlank(invTextCodeNode.getText()) && invTextCodeNode.getText().isNumeric())
                                taxBlock.InvoiceTextCodes.add(Integer.valueOf(invTextCodeNode.getText()));
                        }
                        
                        //  Taxes.Tax Rule Id
                        Dom.XMLNode taxRuleIdNode = taxesNode.getChildElement('TaxRuleId', VertexCore.URN);
                        if (taxRuleIdNode != null)
                            taxBlock.TaxRuleId.TaxRuleId = integer.valueOf(taxRuleIdNode.getText());
                        else
                            taxBlock.TaxRuleId.TaxRuleId = 0;
                        
                        lineItem.Taxes.add(taxBlock);
                        responseStructure.VertexEnvelope.Response.LineItems.add(lineItem);
                    }
                }
                
                //  Add this LineItem's results into the our id to value map
                liId2Response.put(lineItemId, lineItem);
            }
        }
        
        //  Now that the response XML is structured - perform necessary record updates and creation
     //  UpdateOppLineItems(liId2Response, taxCheckType);
     updateTrans.addAll(UpdateOppLineItems(liId2Response, taxCheckType));
     return updateTrans;
    //  System.debug('-->Log : VertexResponse:: liId2Response:::' + liId2Response);
    //  System.debug('-->Log : VertexResponse:: taxCheckType:::' + taxCheckType);
      /*  transient VertexCore.ResponseWrapper resultWrap = new VertexCore.ResponseWrapper();
        transient List<VertexCore.ResponseWrapper> resultSplitList = new List<VertexCore.ResponseWrapper>();
        resultWrap.liId2Response=liId2Response;
        resultWrap.taxCheckType=taxCheckType;
        resultSplitList.add(resultWrap);
        System.debug('-->Log : VertexResponse:: resultSplitList:::' + resultSplitList);
        database.executeBatch(new VertexResponseBatchable(resultSplitList), VertexCore.batchJobCallout);
       //CreateTaxDetails(liId2Response);
       */
    }
    
    //This is where we set the target mapping fields
    public  list<sObject> UpdateOppLineItems(map<id, VertexStructureResponse.ResponseLineItem> id2VertexLineItem, String taxCheckType) {
        system.debug(LoggingLevel.WARN, '===UpdateOppLineItems===');
        system.debug(LoggingLevel.ERROR, 'id2VertexLineItem:  ' + id2VertexLineItem);
        
        list<sObject> updateOLIs = new LIST<sObject>();
        VertexObjectMapping__c objMap = VertexObjectMapping__c.getValues(taxCheckType);
        Boolean itemTaxFieldPopulatedAndUpdatable = String.isNotBlank(objMap.ItemTaxField__c) && VertexCore.HasCRUDandFLS(objMap.ChildSObject__c + '.' + objMap.ItemTaxField__c);
        Boolean itemTaxNotesFieldPopulatedAndUpdatable = String.isNotBlank(objMap.ItemTaxNotesField__c) && VertexCore.HasCRUDandFLS(objMap.ChildSObject__c + '.' + objMap.ItemTaxNotesField__c);
        Boolean invoiceTextCodesPopulatedAndUpdatable = String.isNotBlank(objMap.InvoiceTextCodes__c) && VertexCore.HasCRUDandFLS(objMap.ChildSObject__c + '.' + objMap.InvoiceTextCodes__c);
        Boolean taxCodePopulatedAndUpdatable = String.isNotBlank(objMap.TaxCode__c) && VertexCore.HasCRUDandFLS(objMap.ChildSObject__c + '.' + objMap.TaxCode__c);
        Boolean vertexTaxCodePopulatedAndUpdatable = String.isNotBlank(objMap.VertexTaxCode__c) && VertexCore.HasCRUDandFLS(objMap.ChildSObject__c + '.' + objMap.VertexTaxCode__c);

        String unwritableFieldsMsg = '';
        if (String.isNotBlank(objMap.ItemTaxField__c) && itemTaxFieldPopulatedAndUpdatable == false)
            unwritableFieldsMsg += 'Unable to save respone to ' + objMap.ChildSObject__c + '.' + objMap.ItemTaxField__c + ' due to insufficient access.\n';
        if (String.isNotBlank(objMap.ItemTaxNotesField__c) && itemTaxNotesFieldPopulatedAndUpdatable == false)
            unwritableFieldsMsg += 'Unable to save respone to ' + objMap.ChildSObject__c + '.' + objMap.ItemTaxNotesField__c + ' due to insufficient access.\n';
        if (String.isNotBlank(objMap.InvoiceTextCodes__c) && invoiceTextCodesPopulatedAndUpdatable == false)
            unwritableFieldsMsg += 'Unable to save respone to ' + objMap.ChildSObject__c + '.' + objMap.InvoiceTextCodes__c + ' due to insufficient access.\n';
        if (String.isNotBlank(objMap.TaxCode__c) && taxCodePopulatedAndUpdatable == false)
            unwritableFieldsMsg += 'Unable to save respone to ' + objMap.ChildSObject__c + '.' + objMap.TaxCode__c + ' due to insufficient access.\n';
        if (String.isNotBlank(objMap.VertexTaxCode__c) && vertexTaxCodePopulatedAndUpdatable == false)
            unwritableFieldsMsg += 'Unable to save respone to ' + objMap.ChildSObject__c + '.' + objMap.VertexTaxCode__c + ' due to insufficient access.';
        if (String.isNotBlank(unwritableFieldsMsg)){
            VertexLogging.Log('Error', unwritableFieldsMsg);
            VertexLogging.CommitDelayed();
        }

        if (itemTaxFieldPopulatedAndUpdatable  || itemTaxNotesFieldPopulatedAndUpdatable || invoiceTextCodesPopulatedAndUpdatable || 
            taxCodePopulatedAndUpdatable || vertexTaxCodePopulatedAndUpdatable){

            //Prevent duplicate field selections in the query string (mostly pertains to test contexts)
            Set<String> fldsToQuery = new Set<String>{objMap.ItemTaxField__c, objMap.ItemTaxNotesField__c, objMap.InvoiceTextCodes__c, objMap.TaxCode__c, objMap.VertexTaxCode__c};
            
            transient String sqlString = 'SELECT Id ';
            if (itemTaxFieldPopulatedAndUpdatable){
                sqlString += ', ' + objMap.ItemTaxField__c + ' ';
                fldsToQuery.remove(objMap.ItemTaxField__c);
            }
            if (itemTaxNotesFieldPopulatedAndUpdatable && fldsToQuery.contains(objMap.ItemTaxNotesField__c)){
                sqlString += ', ' + objMap.ItemTaxNotesField__c + ' ';
                fldsToQuery.remove(objMap.ItemTaxNotesField__c);
            }
            if (invoiceTextCodesPopulatedAndUpdatable && fldsToQuery.contains(objMap.InvoiceTextCodes__c)){
                sqlString += ', ' + objMap.InvoiceTextCodes__c + ' ';
                fldsToQuery.remove(objMap.InvoiceTextCodes__c);
            }
            if (taxCodePopulatedAndUpdatable && fldsToQuery.contains(objMap.TaxCode__c)){
                sqlString += ', ' + objMap.TaxCode__c + ' ';
                fldsToQuery.remove(objMap.TaxCode__c);
            }
            if (vertexTaxCodePopulatedAndUpdatable && fldsToQuery.contains(objMap.VertexTaxCode__c)){
                sqlString += ', ' + objMap.VertexTaxCode__c + ' ';
                fldsToQuery.remove(objMap.VertexTaxCode__c);
            }
            
            transient SET<ID> id2VertexLineItemKeys = id2VertexLineItem.keyset();
            sqlString += 'FROM ' + objMap.ChildSObject__c + ' WHERE Id IN :id2VertexLineItemKeys';
            System.debug('Built SOQL: '+sqlString);

            try{
                updateOLIs = database.query(sqlString);
            } catch (Exception e){
                VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
            }
            
            
            //  Populate the Tax field
            for (sObject oli : updateOLIs) {
                //  populate status field
                if (objMap.TaxCalloutStatus__c != null)
                    oli.put(objMap.TaxCalloutStatus__c, 'Success' + ': ' + System.Now().format());

                VertexStructureResponse.ResponseLineItem lineItem = id2VertexLineItem.get(oli.Id);
                if (itemTaxFieldPopulatedAndUpdatable)
                    oli.put(objMap.ItemTaxField__c, lineItem.TotalTax);

                if (itemTaxNotesFieldPopulatedAndUpdatable || invoiceTextCodesPopulatedAndUpdatable || taxCodePopulatedAndUpdatable || vertexTaxCodePopulatedAndUpdatable){
                    transient String noteValue = '';
                    transient String codeDescriptions = '';
                    transient String taxCodes = '';
                    transient String vertexTaxCodes = '';

                    //Output details for each tax block
                    for (VertexStructureResponse.ResponseLineItemTaxes taxBlock : lineItem.Taxes){
                        noteValue += 'Taxable:' + taxBlock.Taxable.Taxable + ' ';
                        noteValue += 'TaxType:' + taxBlock.TaxType + ' ';
                        noteValue += 'TaxStructure:' + taxBlock.TaxStructure + ' ';
                        noteValue += 'TaxRuleId:' + taxBlock.TaxRuleId.TaxRuleId + ' ';
                        noteValue += 'TaxResult:' + taxBlock.TaxResult + ' ';
                        noteValue += 'TaxCollectedFromParty:' + taxBlock.TaxCollectedFromParty + ' ';
                        noteValue += 'Situs:' + taxBlock.Situs + ' ';
                        noteValue += 'Jurisdiction:' + taxBlock.Jurisdiction.Jurisdiction + ' ';
                        noteValue += 'JurisdictionLevel:' + taxBlock.Jurisdiction.JurisdictionLevel + ' ';
                        noteValue += 'JurisdictionId:' + taxBlock.Jurisdiction.JurisdictionId + ' ';
                        noteValue += 'Imposition:' + taxBlock.Imposition.Imposition + ' ';
                        noteValue += 'ImpositionType:' + taxBlock.ImpositionType.ImpositionType + ' ';
                        noteValue += 'ImpositionTypeId:' + taxBlock.ImpositionType.ImpositionTypeId + ' ';
                        noteValue += 'ImpositionId:' + taxBlock.Imposition.ImpositionId + ' ';
                        noteValue += 'EffectiveRate:' + taxBlock.EffectiveRate.EffectiveRate + ' ';
                        noteValue += 'CalculatedTax:' + taxBlock.CalculatedTax.CalculatedTax + ' ';
                        noteValue += '\n\n';

                        //Collect invoice text codes
                        if (!taxBlock.InvoiceTextCodes.isEmpty()){
                            for (Integer code : taxBlock.InvoiceTextCodes)
                                codeDescriptions += code + ': ' + GetInvoiceTextCodes().get(code) + ', ';
                            codeDescriptions = codeDescriptions.removeEnd(', ');
                            codeDescriptions += '\n\n';
                        }

                        //Get the two different tax codes
                        taxCodes += taxBlock.TaxCode + ', ';
                        vertexTaxCodes += taxBlock.VertexTaxCode + ', ';

                    }
                    noteValue = noteValue.removeEnd('\n\n');
                    codeDescriptions = codeDescriptions.removeEnd('\n\n');
                    taxCodes = taxCodes.removeEnd(', ');
                    vertexTaxCodes = vertexTaxCodes.removeEnd(', ');

                    //Set target mapping fields
                    if (itemTaxNotesFieldPopulatedAndUpdatable)
                        oli.put(objMap.ItemTaxNotesField__c, noteValue);
                    if (invoiceTextCodesPopulatedAndUpdatable)
                        oli.put(objMap.InvoiceTextCodes__c, codeDescriptions);
                    if (taxCodePopulatedAndUpdatable)
                        oli.put(objMap.TaxCode__c, taxCodes);
                    if (vertexTaxCodePopulatedAndUpdatable)
                        oli.put(objMap.VertexTaxCode__c, vertexTaxCodes);
                }
            }
            //  Perform final update to end the process
            if (!updateOLIs.isEmpty()){
                Database.DMLOptions dmlOpts = new Database.DMLOptions();
                dmlOpts.allowFieldTruncation = true;
                try {
                    Database.update(updateOLIs, dmlOpts);
                } catch (Exception e){
                    System.debug('Exception '+e);
                    VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
                }
                
            }
        }
        return updateOLIs;
    }
    
    private Map<Integer, String> InvoiceTextCodes;
    public   Map<Integer, String> GetInvoiceTextCodes(){
        if (InvoiceTextCodes == null){
            InvoiceTextCodes = new Map<Integer, String>{
                1 => 'Export',
                2 => 'Intra EU', 
                3 => 'Zero Rate', 
                4 => 'Reverse Charge', 
                5 => 'Indeterminate Tax', 
                6 => 'Registration Group', 
                7 => 'Triangulation', 
                8 => 'Net Exporter', 
                9 => 'Import VAT', 
                10 => 'Out of Scope at PO', 
                11 => 'Out of Scope at AO', 
                12 => 'Suspended VAT', 
                13 => 'Call Off Simplification', 
                14 => 'Consignment Simplification', 
                15 => 'VAT Liability may exist at AO', 
                16 => 'VAT Liability may exist at PO', 
                17 => 'VAT Liability may exist at AD', 
                18 => 'VAT Liability may exist at D', 
                19 => 'Self-Billing Indicator', 
                20 => 'ESS Indicator', 
                21 => 'Intra-Country', 
                22 => 'Differential VAT', 
                23 => 'VAT Withholding', 
                24 => 'Singapore Section 21', 
                25 => 'Out of Scope at D'
            };
        }
        return InvoiceTextCodes;
    }
}
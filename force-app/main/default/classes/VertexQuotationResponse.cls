public with sharing class VertexQuotationResponse {
/*    
    //  Logic called from QuotationRequest class' response handler override; take the tax details in the response and perform necessary record creation/updates
    public void ParseQuotationResponse(HTTPResponse res, String taxCheckType) {
        system.debug(LoggingLevel.WARN, '===ParseQuotationResponse===');
        system.debug(LoggingLevel.ERROR, 'res:  ' + res);
        
        //  Map to later help populating oli's w/ tax amount for post response update
        map<id, VertexStructureQuotationResponse.QuotationResponseLineItem> liId2QuotationResponse = new map<id, VertexStructureQuotationResponse.QuotationResponseLineItem>();
            
        //  Prevent trigger from running on post response update
        VertexCore.IsResponseRunning = TRUE;

        VertexStructureQuotationResponse quotationResponse = new VertexStructureQuotationResponse();
        
        //  Break out the various parts of the XML structure - only currently interested in QuotationResponse children
        Dom.Document doc = res.getBodyDocument();
        Dom.XMLNode envelope = doc.getRootElement();
        Dom.XMLNode Header = envelope.getChildElement('Header', VertexCore.SoapEnv);
        Dom.XMLNode body = envelope.getChildElement('Body', VertexCore.SoapEnv);
        Dom.XMLNode vertexEnvelopeNode = body.getChildElement('VertexEnvelope', VertexCore.URN);
        Dom.XMLNode quotationResponseNode = vertexEnvelopeNode.getChildElement('QuotationResponse', VertexCore.URN);
        
        //  Loop through all QR's children and work with specific nodes we want - currently all LineItems
        for (Dom.XMLNode node :quotationResponseNode.getChildElements()) {
            
            if (node.getName() == 'LineItem') {
                
                VertexStructureQuotationResponse.QuotationResponseLineItem lineItem = new VertexStructureQuotationResponse.QuotationResponseLineItem();
                
                //  Properties to hold returned values, will be placed in the map, and later applied to update OLIs
                string lineItemTax = '0';
                string lineItemId = node.getAttributeValue('lineItemId' ,'');
                
                //  Each LineItem node has several children, TotalTax is one of them
                Dom.XMLNode totalTaxNode = node.getChildElement('TotalTax', VertexCore.URN);
                
                //  If there is a tax amount retVertexCore.URNed, replace default value of 0
                if (totalTaxNode != null)
                    lineItem.TotalTax = decimal.valueOf(totalTaxNode.getText());
                
                //  Create Tax Detail
                Dom.XMLNode taxesNode = node.getChildElement('Taxes', VertexCore.URN);
                if (taxesNode != null) {
                    
                    //  Taxes node level
                    lineItem.Taxes.Situs = taxesNode.getAttributeValue('situs' ,'');
                    lineItem.Taxes.TaxCollectedFromParty = taxesNode.getAttributeValue('taxCollectedFromParty' ,'');
                    lineItem.Taxes.TaxResult = taxesNode.getAttributeValue('taxResult' ,'');
                    lineItem.Taxes.TaxStructure = taxesNode.getAttributeValue('taxStructure' ,'');
                    lineItem.Taxes.TaxType = taxesNode.getAttributeValue('taxType' ,'');
                    
                    //  Taxes.Jurisdiction
                    Dom.XMLNode jurisdictionNode = taxesNode.getChildElement('Jurisdiction', VertexCore.URN);
                    lineItem.Taxes.Jurisdiction.Jurisdiction = jurisdictionNode.getText();
                    lineItem.Taxes.Jurisdiction.JurisdictionId = integer.valueOf(jurisdictionNode.getAttributeValue('jurisdictionId', ''));
                    lineItem.Taxes.Jurisdiction.JurisdictionLevel = jurisdictionNode.getAttributeValue('jurisdictionLevel', '');
                    
                    //  Taxes.Calculated Tax
                    Dom.XMLNode calculatedTaxNode = taxesNode.getChildElement('CalculatedTax', VertexCore.URN);
                    lineItem.Taxes.CalculatedTax.CalculatedTax = decimal.valueOf(calculatedTaxNode.getText());
                    
                    //  Taxes.Effective Rate
                    Dom.XMLNode effectiveRateNode = taxesNode.getChildElement('EffectiveRate', VertexCore.URN);
                    lineItem.Taxes.EffectiveRate.EffectiveRate = decimal.valueOf(effectiveRateNode.getText());
                    
                    //  Taxes.Taxable
                    Dom.XMLNode taxableNode = taxesNode.getChildElement('Taxable', VertexCore.URN);
                    lineItem.Taxes.Taxable.Taxable = decimal.valueOf(taxableNode.getText());
                    
                    //  Taxes.Imposition
                    Dom.XMLNode impositionNode = taxesNode.getChildElement('Imposition', VertexCore.URN);
                    lineItem.Taxes.Imposition.Imposition = impositionNode.getText();
                    lineItem.Taxes.Imposition.ImpositionId = impositionNode.getAttributeValue('impositionId', '');
                    
                    //  Taxes.Imposition Type
                    Dom.XMLNode impositionTypeNode = taxesNode.getChildElement('ImpositionType', VertexCore.URN);
                    lineItem.Taxes.ImpositionType.ImpositionType = impositionTypeNode.getText();
                    lineItem.Taxes.ImpositionType.ImpositionTypeId = impositionTypeNode.getAttributeValue('impositionTypeId', '');
                    
                    //  Taxes.Tax Rule Id
                    Dom.XMLNode taxRuleIdNode = taxesNode.getChildElement('TaxRuleId', VertexCore.URN);
                    lineItem.Taxes.TaxRuleId.TaxRuleId = integer.valueOf(taxRuleIdNode.getText());
                    
                    quotationResponse.VertexEnvelope.QuotationResponse.LineItems.add(lineItem);
                }
                
                //  Add this LineItem's results into the our id to value map
                liId2QuotationResponse.put(lineItemId, lineItem);
            }
        }
        
        //  Now that the response XML is structured - perform necessary record updates and creation
        UpdateOppLineItems(liId2QuotationResponse, taxCheckType);
        //CreateTaxDetails(liId2QuotationResponse);
    }
    
    public list<OpportunityLineItem> UpdateOppLineItems(map<id, VertexStructureQuotationResponse.QuotationResponseLineItem> id2VertexLineItem, String taxCheckType) {
        system.debug(LoggingLevel.WARN, '===UpdateOppLineItems===');
        system.debug(LoggingLevel.ERROR, 'id2VertexLineItem:  ' + id2VertexLineItem);
        
        list<OpportunityLineItem> updateOLIs = new LIST<OpportunityLineItem>();

        if (!String.isEmpty(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxField__c)  || 
            !String.isEmpty(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxNotesField__c)){

            //  Query for the olis retVertexCore.URNed; should match
            transient String sqlString = 'SELECT Id, Quantity, UnitPrice ';
            if(!String.isEmpty(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxField__c)){
                sqlString += ', '+VertexObjectMapping__c.getValues(taxCheckType).ItemTaxField__c+' ';
            }

            if(!String.isEmpty(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxNotesField__c)){
                sqlString += ', '+VertexObjectMapping__c.getValues(taxCheckType).ItemTaxNotesField__c+' ';
            }
            transient SET<ID> id2VertexLineItemKeys = id2VertexLineItem.keyset();
            sqlString += 'FROM OpportunityLineItem WHERE Id IN :id2VertexLineItemKeys';
            system.debug('Built SOQL: '+sqlString);
            updateOLIs = database.query(sqlString);
            
            //  Populate the Tax field
            for (OpportunityLineItem oli :updateOLIs) {
                
                VertexStructureQuotationResponse.QuotationResponseLineItem lineItem = id2VertexLineItem.get(oli.Id);
                if(!String.isEmpty(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxField__c)){
                    oli.put(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxField__c,lineItem.TotalTax);
                }

                if(!String.isEmpty(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxNotesField__c)){
                    transient String noteValue;
                    noteValue = 'Taxable:' + lineItem.Taxes.Taxable.Taxable + ' ';
                    noteValue += 'TaxType:' + lineItem.Taxes.TaxType + ' ';
                    noteValue += 'TaxStructure:' + lineItem.Taxes.TaxStructure + ' ';
                    noteValue += 'TaxRuleId:' + lineItem.Taxes.TaxRuleId.TaxRuleId + ' ';
                    noteValue += 'TaxResult:' + lineItem.Taxes.TaxResult + ' ';
                    noteValue += 'TaxCollectedFromParty:' + lineItem.Taxes.TaxCollectedFromParty + ' ';
                    noteValue += 'Situs:' + lineItem.Taxes.Situs + ' ';
                    noteValue += 'Jurisdiction:' + lineItem.Taxes.Jurisdiction.Jurisdiction + ' ';
                    noteValue += 'JurisdictionLevel:' + lineItem.Taxes.Jurisdiction.JurisdictionLevel + ' ';
                    noteValue += 'JurisdictionId:' + lineItem.Taxes.Jurisdiction.JurisdictionId + ' ';
                    noteValue += 'Imposition:' + lineItem.Taxes.Imposition.Imposition + ' ';
                    noteValue += 'ImpositionType:' + lineItem.Taxes.ImpositionType.ImpositionType + ' ';
                    noteValue += 'ImpositionTypeId:' + lineItem.Taxes.ImpositionType.ImpositionTypeId + ' ';
                    noteValue += 'ImpositionId:' + lineItem.Taxes.Imposition.ImpositionId + ' ';
                    noteValue += 'EffectiveRate:' + lineItem.Taxes.EffectiveRate.EffectiveRate + ' ';
                    noteValue += 'CalculatedTax:' + lineItem.Taxes.CalculatedTax.CalculatedTax + ' ';
                    oli.put(VertexObjectMapping__c.getValues(taxCheckType).ItemTaxNotesField__c,noteValue);
                }
            }
            //  Perform final update to end the process
            if (!updateOLIs.isEmpty())
                update updateOLIs;
        }   
        return updateOLIs;
    }
    
    //public list<VertexTaxDetail__c> CreateTaxDetails(map<id, VertexStructureQuotationResponse.QuotationResponseLineItem> id2VertexLineItem) {
    //    system.debug(LoggingLevel.WARN, '===CreateTaxDetails===');
    //    system.debug(LoggingLevel.ERROR, 'id2VertexLineItem:  ' + id2VertexLineItem);
        
    //    list<VertexTaxDetail__c> taxDetails = new list<VertexTaxDetail__c>();
        
    //    if (id2VertexLineItem != null && !id2VertexLineItem.isEmpty()) {
            
    //        for (id sfLineItemId :id2VertexLineItem.keyset()) {
    //            system.debug(LoggingLevel.ERROR, 'sfLineItemId:  ' + sfLineItemId);
                
    //            //  Localize this Vertex Line Item (from QuotationResponse's Line Items)
    //            VertexStructureQuotationResponse.QuotationResponseLineItem lineItem = id2VertexLineItem.get(sfLineItemId);
                
    //            //  Create a new Vertex Tax Detail record (not all SF children can have lookups to them; Opp Line Items - NO, Quote Line Items - Yes)
    //            VertexTaxDetail__c detail = new VertexTaxDetail__c();
                
    //            //  Assign DML Options to allow for field truncation
    //            detail.setOptions(VertexCore.getDMLOptions());
                
    //            //  Populate w/ response details
    //            detail.ParentId__c = sfLineItemId;
    //            detail.Situs__c = lineItem.Taxes.Situs;
    //            detail.TaxCollectedFromParty__c = lineItem.Taxes.TaxCollectedFromParty;
    //            detail.TaxResult__c = lineItem.Taxes.TaxResult;
    //            detail.TaxStructure__c = lineItem.Taxes.TaxStructure;
    //            detail.TaxType__c = lineItem.Taxes.TaxType;
    //            detail.JurisdictionLevel__c = lineItem.Taxes.Jurisdiction.JurisdictionLevel;
    //            detail.JurisdictionId__c = lineItem.Taxes.Jurisdiction.JurisdictionId;
    //            detail.Jurisdiction__c = lineItem.Taxes.Jurisdiction.Jurisdiction;
    //            detail.CalculatedTax__c = lineItem.Taxes.CalculatedTax.CalculatedTax;
    //            detail.EffectiveRate__c = lineItem.Taxes.EffectiveRate.EffectiveRate;
    //            detail.Taxable__c = lineItem.Taxes.Taxable.Taxable;
    //            detail.Imposition__c = lineItem.Taxes.Imposition.Imposition;
    //            detail.ImpositionId__c = lineItem.Taxes.Imposition.ImpositionId;
    //            detail.ImpositionType__c = lineItem.Taxes.ImpositionType.ImpositionType;
    //            detail.ImpositionTypeId__c = lineItem.Taxes.ImpositionType.ImpositionTypeId;
    //            detail.TaxRuleId__c = lineItem.Taxes.TaxRuleId.TaxRuleId;
                
    //            //  Add this to the collection of records to be returned to the calling method
    //            taxDetails.add(detail);
    //            system.debug(LoggingLevel.ERROR, 'taxDetails:  ' + taxDetails);
    //            if (!taxDetails.isEmpty())
    //                database.upsert(taxDetails, VertexTaxDetail__c.fields.ParentId__c);
    //        }
    //    }
        
    //    return taxDetails;
    //}*/
}
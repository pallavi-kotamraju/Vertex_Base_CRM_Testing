//  Class definitions for the Response webservice
public with sharing class VertexStructureResponse {
    
    //  Root properties for a Response (/doc/messages/QuotationResponse.html  and /doc/messages/InvoiceResponse.html)
    public VertexResponseEnvelope VertexEnvelope  { get; set; }                                     //  1
    
    //  Init w/ defaults and children
    public VertexStructureResponse() {
        System.debug('-->Log :VertexStructureResponse : extendsVertexStructureEnvelope  ');
        VertexEnvelope = new VertexResponseEnvelope();
    }
    
    //  1 (VertexEnvelope Root) - always the same for endpoints
    public class VertexResponseEnvelope extends VertexStructureEnvelope {

               
        public VertexResponse Response  { get; set; }
        public VertexResponseEnvelope() {
            Response = new VertexResponse();
        }
    }
    
    //  1.2 (Response)
    public class VertexResponse {
        public string transactionId { get; set; }                                                   //  1.2
        public decimal TotalTax { get; set; }                                                       //  1.2.12
        public list<ResponseLineItem> LineItems { get; set; }                                       //  1.2.13
        
        //  Init w/ defaults and children
        public VertexResponse() {
            LineItems = new list<ResponseLineItem>();
        }
    }
    
    //  1.2.13
    public class ResponseLineItem {
        
        public integer LineItemNumber { get; set; }
        public string LineItemId { get; set; }
        public decimal TotalTax { get; set; }
        public List<ResponseLineItemTaxes> Taxes { get; set; }                                                  //  1.2.13.20
        
        public ResponseLineItem() {
            Taxes = new List<ResponseLineItemTaxes>();
        }
    }
    
    //  1.2.13.20
    public class ResponseLineItemTaxes {
        
        public string TaxResult { get; set; }
        public string TaxType { get; set; }
        public string Situs { get; set; }
        public string TaxCollectedFromParty { get; set; }
        public string TaxStructure { get; set; }
        public string TaxCode { get; set; }
        public string VertexTaxCode { get; set; }
        public ResponseLineItemJurisdiction Jurisdiction { get; set; }                                     //  1.2.13.20.1
        public ResponseLineItemCalculatedTax CalculatedTax { get; set; }                                   //  1.2.13.20.2
        public ResponseLineItemEffectiveRate EffectiveRate { get; set; }                                   //  1.2.13.20.3
        public ResponseLineItemTaxable Taxable { get; set; }                                               //  1.2.13.20.6
        public ResponseLineItemImposition Imposition { get; set; }                                         //  1.2.13.20.7
        public ResponseLineItemImpositionType ImpositionType { get; set; }                                 //  1.2.13.20.8
        public ResponseLineItemTaxRuleId TaxRuleId { get; set; }                                           //  1.2.13.20.9
        public List<Integer> InvoiceTextCodes {get; set; }                                                  //  1.2.13.20.25
        
        public ResponseLineItemTaxes() {
            Jurisdiction = new ResponseLineItemJurisdiction();
            CalculatedTax = new ResponseLineItemCalculatedTax();
            EffectiveRate = new ResponseLineItemEffectiveRate();
            Taxable = new ResponseLineItemTaxable();
            Imposition = new ResponseLineItemImposition();
            ImpositionType = new ResponseLineItemImpositionType();
            TaxRuleId = new ResponseLineItemTaxRuleId();
            InvoiceTextCodes = new List<Integer>();
        }
    }
    
    //  1.2.13.20.1
    public class ResponseLineItemJurisdiction {
        public string Jurisdiction { get; set; }
        public string JurisdictionLevel { get; set; }
        public integer JurisdictionId { get; set; }
        
        public ResponseLineItemJurisdiction(){}
    }
    
    //  1.2.13.20.2
    public class ResponseLineItemCalculatedTax {
        public decimal CalculatedTax { get; set; }
        
        public ResponseLineItemCalculatedTax(){}
    }
    
    //  1.2.13.20.3
    public class ResponseLineItemEffectiveRate {
        public decimal EffectiveRate { get; set; }
        
        public ResponseLineItemEffectiveRate() {}
    }
    
    //  1.2.13.20.6
    public class ResponseLineItemTaxable {
        public decimal Taxable { get; set; }
        
        public ResponseLineItemTaxable() {}
    }
    
    //  1.2.13.20.7
    public class ResponseLineItemImposition {
        public string Imposition { get; set; }
        public string ImpositionId { get; set; }
        
        public ResponseLineItemImposition() {}
    }
    
    //  1.2.13.20.8
    public class ResponseLineItemImpositionType {
        public string ImpositionType { get; set; }
        public string ImpositionTypeId { get; set; }
        
        public ResponseLineItemImpositionType() {}
    }
    
    //  1.2.13.20.9
    public class ResponseLineItemTaxRuleId {
        public integer TaxRuleId { get; set; }
        
        public ResponseLineItemTaxRuleId() {}
    }
}
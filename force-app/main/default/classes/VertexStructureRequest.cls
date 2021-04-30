//  Class definitions for the Request webservice
public with sharing class VertexStructureRequest {
    
    //  Root properties for a Request (/doc/messages/QuotationRequest.html and /doc/messages/InvoiceRequest.html)
    public VertexRequestEnvelope VertexEnvelope  { get; set; }                                     //  1
    
    //  Init w/ defaults and children
    public VertexStructureRequest() {
        VertexEnvelope = new VertexRequestEnvelope();
    }
    
    //  1 (VertexEnvelope Root) - always the same for endpoints
    public class VertexRequestEnvelope extends VertexStructureEnvelope {
        
        public VertexRequest Request { get; set; }
        public VertexRequestEnvelope() {
            Request = new VertexRequest();
        }
    }
    
    //  1.2 (Request)
    public class VertexRequest {
        public string DocumentDate { get; set; }
        public string DocumentNumber { get; set; }
        public string TransactionType { get; set; }
        public string PostingDate { get; set; }
        public string DeliveryTerm { get; set; }
        public String CurrencyCodeAlpha { get; set; }                                              // 1.2.1
        public RequestSeller Seller { get; set; }                                                  //  1.2.3
        public RequestCustomer Customer { get; set; }                                              //  1.2.4
        public RequestTaxOverride TaxOverride { get; set; }                                        //  1.2.5
        public list<RequestLineItem> LineItems { get; set; }                                       //  1.2.10
        
        //  Init w/ defaults and children
        public VertexRequest() {
            DocumentDate = system.today().year() + '-' + system.today().month() + '-' + system.today().day();
            TransactionType = 'SALE';   //Default
            Seller = new RequestSeller();
            Customer = new RequestCustomer();
            TaxOverride = new RequestTaxOverride();
            LineItems = new list<RequestLineItem>();
        }
    }
    
    //  Request.Seller - 1.2.3 (QR Root.Seller) AND 1.2.10.1 (QR Root.LineItem.Seller)
    public class RequestSeller {
        
        public string Company { get; set; }                                                                 //  1.2.3.1;  1.2.10.1.1
        public RequestPhysicalOrigin PhysicalOrigin { get; set; }                                  //  1.2.3.5;  1.2.10.1.5
        public RequestAdministrativeOrigin AdministrativeOrigin { get; set; }                      //  1.2.3.6;  1.2.10.1.6
        //public RequestTaxRegistration TaxRegistration {get; set;}                                   //  1.2.3.7;  1.2.4.5
        
        //  Init w/ defaults and children
        public RequestSeller() {
            PhysicalOrigin = new RequestPhysicalOrigin();
            AdministrativeOrigin = new RequestAdministrativeOrigin();
            //TaxRegistration = new RequestTaxRegistration();
        }
    }
    
    //  Shared by 1.2.3.5 (QR Root.Seller.PhysicalOrigin) AND 1.2.10 (QR Root.LineItem.Seller.PhysicalOrigin) - aka "ship from"
    public class RequestPhysicalOrigin {
        
        public String TaxAreaId { get; set; }
        public String LocationCode { get; set; }
        public RequestAddressSet Address { get; set; }                                             //  1.2.3.5.1-7;  1.2.10.1.5.1-7
        
        //  Init w/ defaults and children
        public RequestPhysicalOrigin() {
            Address = new RequestAddressSet();
        }
    }
    
    //  1.2.3.6 (QR Root.Seller.AdministrativeOrigin) AND 1.2.10.1.6 (LineItem.Seller.AdministrativeOrigin) - aka "bill from"
    public class RequestAdministrativeOrigin {
        
        public String TaxAreaId { get; set; }
        public String LocationCode { get; set; }
        public RequestAddressSet Address { get; set; }                                             //  1.2.3.6.1-7;  1.2.10.1.6.1-7
        
        //  Init w/ defaults and children
        public RequestAdministrativeOrigin() {
            Address = new RequestAddressSet();
        }
    }

    //  1.2.3.7 (Seller) AND 1.2.4.5 (Customer)
    public class RequestTaxRegistration {
        
        public String IsoCountryCode { get; set; }
        public String TaxRegistrationNumber { get; set; }
    }
    
    //  1.2.4 (QR Root.Customer) AND 1.2.10.2 (QR Root.LineItem.Customer)
    public class RequestCustomer {
        
        public RequestCustomerDestination Destination { get; set; }                                //  1.2.4.2;  1.2.10.2.2
        public RequestCustomerAdministrativeDestination AdministrativeDestination { get; set; }    //  1.2.4.3;  1.2.10.2.3
        public RequestCustomerCode CustomerCode { get; set; }
        public RequestTaxRegistration TaxRegistration {get; set;}                                   //  1.2.3.7;  1.2.4.5

        //  Init w/ defaults and children
        public RequestCustomer() {
            Destination = new RequestCustomerDestination();
            AdministrativeDestination = new RequestCustomerAdministrativeDestination();
            CustomerCode = new RequestCustomerCode();
            TaxRegistration = new RequestTaxRegistration();
        }
    }

    public class RequestCustomerCode {        
        public String CustomerCode { get; set; }
        public String CustomerClassCode { get; set; }
    }
    
    //  1.2.4.2 (QR Root.Customer.Destination) AND 1.2.10.2 (QR Root.LineItem.Customer.Destination)
    public class RequestCustomerDestination {
        
        public String TaxAreaId { get; set; }
        public String LocationCode { get; set; }
        public RequestAddressSet Address { get; set; }                                             //  1.2.4.2.1-7;  1.2.10.2.2.1-7
        public RequestCustomerCurrencyConversion CurrencyConversion { get; set; }
        
        //  Init w/ defaults and children
        public RequestCustomerDestination() {
            Address = new RequestAddressSet();
            CurrencyConversion = new RequestCustomerCurrencyConversion();
        }
    }

    // 1.2.4.2.8
    public class RequestCustomerCurrencyConversion {
        public String ConversionRate { get; set; }
        public String CurrencyCodeAlpha { get; set; }

        public RequestCustomerCurrencyConversion(){
            ConversionRate = '1';
        }
    }
    
    //  1.2.4.3 (QR Root.Customer.AdministrativeDestination) AND 1.2.10.2.3 (QR Root.LineItem.Customer.Destination)
    public class RequestCustomerAdministrativeDestination {
        
        public String TaxAreaId { get; set; }
        public RequestAddressSet Address { get; set; }                                             //  1.2.4.3.1-7;  1.2.10.2.3.1-7
        
        public RequestCustomerAdministrativeDestination() {
            Address = new RequestAddressSet();
        }
    }
    
    //  1.2.5 (QR Root.TaxOverride) AND 1.2.10.3 (QR Root.LineItem.TaxOverride)
    public class RequestTaxOverride {
        public string OverrideType { get; set; }    //  TAXABLE or NONTAXABLE
        public RequestTaxOverride() {}
    }
    
    //  1.2.10
    public class RequestLineItem {
        
        public integer LineItemNumber { get; set; }
        public string LineItemId { get; set; }
        public string DeliveryTerm { get; set; }
        public RequestSeller Seller { get; set; }                                                  //  1.2.10.1
        public RequestCustomer Customer { get; set; }                                              //  1.2.10.2
        public RequestTaxOverride TaxOverride { get; set; }                                        //  1.2.10.3
        public RequestProductSet Product { get; set; }                                             //  1.2.10.7
        public String CommodityCode { get; set; }
        public String CommodityCodeType {get; set; }                                               //  1.2.10.8 
        public Decimal Quantity { get; set; }                                                      //  1.2.10.9
        public Decimal UnitPrice { get; set; }                                                     //  1.2.10.17
        public Decimal ExtendedPrice { get; set; }                                                 //  1.2.10.18
        public Decimal InputTotalTax { get; set; }                                                 //  1.2.10.21  (DistributeTaxRequest)
        public FlexFieldGroup FlexibleFields {get; set;}                                           //  1.2.10.22
        public boolean taxIncludedIndicator { get; set;}
        public String usageClass {get; set;}
        public String usageCode { get; set;}

        public RequestLineItem() {
            Seller = new RequestSeller();
            Customer = new RequestCustomer();
            TaxOverride = new RequestTaxOverride();
            Product = new RequestProductSet();
            FlexibleFields = new FlexFieldGroup();
        }
    }

    public class RequestProductSet {
        public String ProductCode { get; set; }
        public String ProductClass { get; set; }
    }

    public class FlexFieldGroup {
        public List<FlexField> FlexibleCodeFields {get; set;}                                       //1.2.10.22.1
        public List<FlexField> FlexibleNumericFields {get; set;}                                    //1.2.10.22.2
        public List<FlexField> FlexibleDateFields {get; set;}                                       //1.2.10.22.3
    }

    public class FlexField {
        public String FieldId {get; set;}
        public String FieldVal {get; set;}
    }
    
    public class RequestAddressSet {
        
        //  All addresses use the same field set
        public string StreetAddress1 { get; set; }
        public string StreetAddress2 { get; set; }
        public string City { get; set; }
        public string MainDivision { get; set; }
        public string SubDivision { get; set; }
        public string PostalCode { get; set; }
        public string Country { get; set; }
        
        //  Base Constructor
        public RequestAddressSet() {}
        
        //  Constructor as it's likely to create new object w/ address at same time
        public RequestAddressSet(string streetAddress1, string streetAddress2, string City, string mainDivision, string subDivision, string postalCode, string country) {
            this.StreetAddress1 = streetAddress1;
            this.StreetAddress2 = streetAddress2;
            this.City = city;
            this.MainDivision = mainDivision;
            this.SubDivision = subDivision;
            this.PostalCode = postalCode;
            this.Country = country;
        }
    }
}
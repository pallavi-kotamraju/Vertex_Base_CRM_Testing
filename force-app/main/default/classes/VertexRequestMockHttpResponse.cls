@isTest
public class VertexRequestMockHttpResponse implements HttpCalloutMock {

    Id LineItemId;
    String RequestType;

    public VertexRequestMockHttpResponse(Id itemId, String reqType) {
        this.LineItemId = itemId;
        this.RequestType = reqType;
        System.Debug('===reqType passed into Mock Callout '+reqType);
    }

    public HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();

        res.setBody('<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Header></soapenv:Header><soapenv:Body><VertexEnvelope xmlns="urn:vertexinc:o-series:tps:7:0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Login><TrustedId>7W3ND8IfE5JJ</TrustedId>/n</Login>/n'
        	+'<' + RequestType + 'Response'
        	+' documentDate="2017-04-20" transactionId= "0062100000BkyRlAAJ" transactionType="SALE"><Seller><Company>CRM Science</Company>/n<PhysicalOrigin taxAreaId="390450000"><StreetAddress1>1 Test Address</StreetAddress1>/n<City>Nowhere</City>/n<MainDivision>PA</MainDivision>/n<PostalCode>12345</PostalCode>/n<Country>USA</Country>/n</PhysicalOrigin>/n<AdministrativeOrigin taxAreaId="390450000"><StreetAddress1>1 Test Address</StreetAddress1>/n<City>Nowhere</City>/n<MainDivision>PA</MainDivision>/n<PostalCode>12345</PostalCode>/n<Country>USA</Country>/n</AdministrativeOrigin>/n</Seller>/n<Customer><Destination taxAreaId="390450000"><StreetAddress1>1 Test Address</StreetAddress1>/n<City>Nowhere</City>/n<MainDivision>PA</MainDivision>/n<PostalCode>12345</PostalCode>/n<Country>USA</Country>/n</Destination>/n</Customer>/n<SubTotal>1000.0</SubTotal>/n<Total>1060.0</Total>/n<TotalTax>60.0</TotalTax>/n<LineItem ' 
            + 'lineItemId="' + LineItemId +'"' 
            + ' lineItemNumber="1"><Product>ParentOpp test product</Product>/n<Quantity>1.0</Quantity>/n<FairMarketValue>1000.0</FairMarketValue>/n<ExtendedPrice>1000.0</ExtendedPrice>/n<Taxes taxResult="TAXABLE" taxType="SALES" situs="ADMINISTRATIVE_ORIGIN" taxCollectedFromParty="BUYER" taxStructure="SINGLE_RATE"><Jurisdiction jurisdictionLevel="STATE" jurisdictionId="31152">PENNSYLVANIA</Jurisdiction>/n<CalculatedTax>60.0</CalculatedTax>/n<EffectiveRate>0.06</EffectiveRate>/n<Taxable>1000.0</Taxable>/n<Imposition impositionId="1">Sales and Use Tax</Imposition>/n<ImpositionType impositionTypeId="1">General Sales and Use Tax</ImpositionType>/n<TaxRuleId>17423</TaxRuleId>/n</Taxes>/n<TotalTax>60.0</TotalTax>/n</LineItem>/n'
            + '</' + RequestType +  'Response>/n<ApplicationData><ResponseTimeMS>18.9</ResponseTimeMS>/n</ApplicationData>/n</VertexEnvelope></soapenv:Body></soapenv:Envelope>');
        res.setStatusCode(200);
        res.setStatus('String status');

        System.assertEquals(200, res.getStatusCode());
        System.Debug('===RequestType '+this.RequestType);
        System.Debug('');
        return res;
    }

}
@isTest
public class VerifyAddressMockHttpResponse implements HttpCalloutMock {

    public HTTPResponse respond(HTTPRequest req) {

        HttpResponse res = new HttpResponse();

        res.setBody('<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Header></soapenv:Header><soapenv:Body><VertexEnvelope xmlns="urn:vertexinc:o-series:tps:7:0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Login><TrustedId>7W3ND8IfE5JJ</TrustedId>\n</Login>\n<TaxAreaResponse><TaxAreaResult taxAreaId="390450000" confidenceIndicator="100"><Jurisdiction jurisdictionLevel="COUNTRY" effectiveDate="1900-01-01" expirationDate="9999-12-31" jurisdictionId="1">UNITED STATES</Jurisdiction>\n<Jurisdiction jurisdictionLevel="STATE" effectiveDate="1900-01-01" expirationDate="9999-12-31" jurisdictionId="31152">PENNSYLVANIA</Jurisdiction>\n<Jurisdiction jurisdictionLevel="COUNTY" effectiveDate="1900-01-01" expirationDate="9999-12-31" jurisdictionId="32092">DELAWARE</Jurisdiction>\n<PostalAddress><StreetAddress1>123 Corrected</StreetAddress1>\n<City>New City</City>\n<MainDivision>PA</MainDivision>\n<SubDivision>Delaware</SubDivision>\n<PostalCode>12345-2233</PostalCode>\n<Country>USA</Country>\n</PostalAddress>\n<Status lookupResult="NORMAL"></Status>\n</TaxAreaResult>\n</TaxAreaResponse>\n<ApplicationData><ResponseTimeMS>0.5</ResponseTimeMS>\n</ApplicationData>\n</VertexEnvelope></soapenv:Body></soapenv:Envelope>');
        res.setStatusCode(200);

        System.assertEquals(200, res.getStatusCode());

        return res;
    }

}
public with sharing class VertexCore {

    //Batch callout count
    public static Integer batchJobCallout = 200;
    //  Tracks if the response to the callout is running
    public static boolean IsResponseRunning { get { if (IsResponseRunning == null) IsResponseRunning = false; return IsResponseRunning; } set; }
    
    //  Properties for XML structure
    public static transient final string SoapEnv = 'http://schemas.xmlsoap.org/soap/envelope/';
    public static transient final string URN = 'urn:vertexinc:o-series:tps:7:0';
    
    //  Flag to indicate the sending of a negative value 
    public static boolean NegativeCallout { get { if (NegativeCallout == null) NegativeCallout=false; return NegativeCallout; } set; }
    
    // Holds Ids of line items of failed transactions to be used for error logging when the request returned a non 200 response
    public static Set<Id> FailedLineItemIds { get { if (FailedLineItemIds == null) FailedLineItemIds = new Set<Id>(); return FailedLineItemIds;} set;}

    //Holds a map of record ids, and a map for key / value pairs for most up to date records
    public static Map<String, Map<String,String>> fieldOverrideMap = new Map<String, Map<String,String>>(); 

    // Method to extract the response node from the body document of an http response of the specified type eg InvoiceResponce 
    public static Dom.XMLNode ExtractEnvelopeChildNode(Dom.Document document, String nodeName) {
        Dom.XMLNode envelope = document.getRootElement();
        Dom.XMLNode body = envelope.getChildElement('Body', SoapEnv);
        Dom.XMLNode vertexEnvelopeNode = body.getChildElement('VertexEnvelope', URN);
        Dom.XMLNode responseNode = vertexEnvelopeNode.getChildElement(nodeName, URN);
        return responseNode;
    }

    //Remove credentials before logging the request and response strings
    public static String RemoveCalloutCredentials(String xmlString) {

        if (xmlString != null && xmlString.contains('<urn:Login>')){
            String urnLoginSubstring = xmlString.substring(xmlString.indexOf('<urn:Login>'), xmlString.indexOf('</urn:Login>') + 11);
            xmlString = xmlString.remove(urnLoginSubstring);
        }

        if (xmlString != null && xmlString.contains('<Login>')){
            String loginSubstring = xmlString.substring(xmlString.indexOf('<Login>'), xmlString.indexOf('</Login>') + 7);
            xmlString = xmlString.remove(loginSubstring);
        }

        return xmlString;
    }

    //  Map holding mappings that take higher priority over regular mappings
    public static Map<String, String> LineDestinationOverrideMappings { get { if (LineDestinationOverrideMappings == null) LineDestinationOverrideMappings = new Map<String, String>(); return LineDestinationOverrideMappings;} set; }

    //  Destination mappings on the line level passed by billing package
    public static Map<String, String> BillingDestinationMappings { get { if (BillingDestinationMappings == null) BillingDestinationMappings = new Map<String, String>(); return BillingDestinationMappings;} set; }
    
    // Checks if an object from the billing package is present and returns true if found to indicate the package is installed 
    public static boolean IsBillingInstalled {
        get {
            IsBillingInstalled = false;
            if(VertexCore.GDMap.containsKey('blng__Invoice__c') && ActiveSettings.Billing_Requested__c == true)
                IsBillingInstalled = true;

            return IsBillingInstalled;
        }
        set;
    }

    //  Property to store global describe to conserve on subsequent describes
    public static Map<String, Schema.SObjectType> GDMap{
        get{
            if (GDMap==null)
                GDMap = Schema.getGlobalDescribe();
            return GDMap;
        }
        set;
    }
    
    // variable to return the current active namespace
    public static String NamespaceString{ 
        get{ 
            if (NamespaceString==null)
                NamespaceString=VertexCore.FetchNamespace();
            return NamespaceString;
        }
        set;
    }
    
    //    Returns the namespace of the object defined in objName
    //    including trailing __, or empty string if no NS found.
    public static String FetchNamespace(){
        transient String objName = 'VertexAddress__c';
        transient String namespaceReturn = '';
        
        for (string key: GDMap.keySet()){
            if(key.endsWithIgnoreCase(objName)){
                namespaceReturn = GDMap.get(key).getDescribe().getName().left((key.length()-objName.length()));
                break;
            }
        }
        return namespaceReturn;
    }
    
    //  Stub w/ dummy data for Seller/Taxpayer Code - should store somewhere and configure via options; assume default = Organization.CompanyName
    public static string CompanyName() {
        return ActiveSettings.CompanyName__c;
    }
    
    //  Overrides for when default isn't being used but the picklist is selected
    public static string PhysicalOriginOverrideParent { get; set; }
    public static string PhysicalOriginOverrideChild { get; set; }
    
    //  Stub w/ dummy data for Seller PO address - to be populated by Custom Setting value
    public static VertexAddress__c ParentPhysicalOriginAddress(String objMapName) {
        
        //  Init default
        VertexAddress__c tmp = VertexAddress__c.getInstance('Default Physical Origin Address');

        //  Override if specified
        if (string.isNotBlank(PhysicalOriginOverrideParent) && VertexAddress__c.getInstance(PhysicalOriginOverrideParent) != null)
            tmp = VertexAddress__c.getInstance(PhysicalOriginOverrideParent);

        //Priority choice
        if (objMapName != null){
            VertexAddress__c tmp2 = VertexAddress__c.getInstance(objMapName + ' Trans Phys');
            if (tmp2 != null && String.isNotBlank(tmp2.Address1__c) && String.isNotBlank(tmp2.City__c) && String.isNotBlank(tmp2.Country__c))
                tmp = tmp2;
        }

        // If the address was not found return an empty record
        if (tmp == null)
            tmp = new VertexAddress__c(Name = 'Default Physical Origin Address');
    
        return tmp;
    }

    // Unlike the parent this should return null if the one specified from the picklist is not found (or none was specified)
    public static VertexAddress__c ChildPhysicalOriginAddress() {
        VertexAddress__c tmp;
        //  Override if necessary
        if (string.isNotBlank(PhysicalOriginOverrideChild))
            tmp = VertexAddress__c.getInstance(PhysicalOriginOverrideChild);
        return tmp;
    }
    
    public static VertexAddress__c AdministrativeOriginAddress(String objMapName) {
        VertexAddress__c adminOrigin;
        if (objMapName != null){
            VertexAddress__c tmp = VertexAddress__c.getInstance(objMapName + ' Trans Admin');
            if (tmp != null && String.isNotBlank(tmp.Address1__c) && String.isNotBlank(tmp.City__c) && String.isNotBlank(tmp.Country__c))
                adminOrigin = tmp; //Preferred choice
        }

        if (objMapName == null || adminOrigin == null){
            adminOrigin = VertexAddress__c.getInstance('Administrative Origin Address');   //Fallback option
            // If the address was not found return an empty record
            if (adminOrigin == null)
                adminOrigin = new VertexAddress__c(Name = 'Administrative Origin Address');
        }

        return adminOrigin;
    }
    
    //  Fetch and preserve the Active configuration
    public static VertexProtectedSettings__c ActiveSettings{
        get{
            // if(ActiveSettings==null)
                ActiveSettings=VertexProtectedSettings__c.getInstance('Active');
            return ActiveSettings != null ? ActiveSettings :new VertexProtectedSettings__c(name='Active', AllowAutocomplete__c = true);
        }
        set{
            ActiveSettings = value;
            upsert ActiveSettings;
        }
    }

    public static MAP<String, VertexObjectMapping__c> ObjectMappings{
        get{
            if(ObjectMappings==null){
                ObjectMappings = VertexObjectMapping__c.getAll();
                if(ObjectMappings.size()==0){
                    VertexDataInit init = new VertexDataInit();
                    init.CreateVanillaObjMappings();
                    ObjectMappings = VertexObjectMapping__c.getAll();
                }
            }
            return ObjectMappings;
        }
        set;
    }

    public static MAP<String, VertexFieldMapping__c> FieldMappings{
        get{
            if (FieldMappings == null)
                FieldMappings = VertexFieldMapping__c.getAll();
            return FieldMappings;
        }
        set;
    }
    
    //  Standard set of DMLOptions to help w/ field truncation
    private static Database.DMLOptions DMLOptions;
    public static Database.DMLOptions getDMLOptions() {
        
        if (DMLOptions == null) {
            DMLOptions = new Database.DMLOptions();
            DMLOptions.AllowFieldTruncation = true;
        }
        
        return DMLOptions;
    }

    /*  Necessary to support destination mappings from CC and Billing extension packages.
        Something like "ParentLookup__r.AnotherLookup__r.Data__c" from the custom setting needs to modified before it goes to HasCRUDandFLS().
        Namely, the relationship field names must be substituted with the object names they represent (except when the field name is expected instead)
        So the above example must first be made into something like "ParentObj__c.AnotherObj__c.Data__c"...
        Then that would be split into object-field pairs like {"ParentObj__c.AnotherLookup__c", "AnotherObj__c.Data__c"}
    */
    public static Set<String> GetObjDotField(String parentObj, String srcFld) {
        system.debug(LoggingLevel.WARN, '===GetObjDotField===');

        List<String> splits = srcFld.split('\\.');
        String lookupObj1;
        String lookupObj2;
        String formattedDotNotation;
        String errMsg = 'Error in GetObjDotField("' + parentObj + '", "' + srcFld + '")';   //Default
        if (splits.size() == 1){
            //No dots. Just a single field.
            formattedDotNotation = parentObj + '.' + splits[0];
        } else if (splits.size() == 2){
            //One dot. (e.g. Company__r.Name__c)
            if (GDMap.containsKey(parentObj)){
                Schema.DescribeSObjectResult objDesc = GDMap.get(parentObj).getDescribe();
                lookupObj1 = GetLookupObj(objDesc, splits[0]);
                formattedDotNotation = parentObj + '.' + lookupObj1 + '.' + splits[1];
            } else {
                errMsg = 'Could not find ' + parentObj + ' in global describe map';
            }
        } else if (splits.size() == 3){
            //Two dots. (e.g. Company__r.ContactPerson__r.Email__c)
            if (GDMap.containsKey(parentObj)){
                Schema.DescribeSObjectResult objDesc1 = GDMap.get(parentObj).getDescribe();
                lookupObj1 = GetLookupObj(objDesc1, splits[0]);
                if (GDMap.containsKey(lookupObj1)){
                    Schema.DescribeSObjectResult objDesc2 = GDMap.get(lookupObj1).getDescribe();
                    lookupObj2 = GetLookupObj(objDesc2, splits[1]);
                    formattedDotNotation = parentObj + '.' + lookupObj1 + '.' + lookupObj2 + '.' + splits[2];
                } else {
                    errMsg = 'Could not find ' + lookupObj1 + ' in global describe map (from lookup field ' + splits[0] + ')';
                }
            } else {
                errMsg = 'Could not find ' + parentObj + ' in global describe map';
            }
        } else {
            errMsg = 'Destination mapping of ' + srcFld + ' for ' + parentObj + ' does not fit expected format.  (Max field relation depth is three).';
        }

        if (formattedDotNotation == null){
            VertexLogging.Log('Error', errMsg);
            VertexLogging.CommitDelayed();
        }
        
        //We now have a dot delimited string, knowing both object names and lookup field names to substitute where needed
        //Now we create Object.Field pairings
        Set<String> objFldPairs = new Set<String>();
        if (formattedDotNotation != null){

            Map<String, String> objToLookupFld = new Map<String, String>();
            objToLookupFld.put(lookupObj1, splits[0].replace('__r', '__c'));
            
            if (splits.size() > 1){
                objToLookupFld.put(lookupObj2, splits[1].replace('__r', '__c'));
            }
            List<String> formattedSplits = formattedDotNotation.split('\\.');
            String swapObj; //Substitute object name for field name
            //Go through the relationships again
            for (Integer i = 0; i < formattedSplits.size() - 2; i++){
                swapObj = formattedSplits.get(i + 1);
                objFldPairs.add(formattedSplits.get(i) + '.' + (objToLookupFld.containsKey(swapObj) ? objToLookupFld.get(swapObj) : swapObj));
            }

            //Add the final field
            swapObj = formattedSplits.get(formattedSplits.size() - 1);
            objFldPairs.add(formattedSplits.get(formattedSplits.size() - 2) + '.' + (objToLookupFld.containsKey(swapObj) ? objToLookupFld.get(swapObj) : swapObj));
        }
        return objFldPairs;
    }

    private static String GetLookupObj(Schema.DescribeSObjectResult objDesc, String lookupFld){
        String lookupObj;
        if (lookupFld.endsWithIgnoreCase('__r'))
            lookupFld = lookupFld.replace('__r', '__c');
        if (!lookupFld.contains('__c')) lookupFld += 'id';

        //What object does this lookup field relate to?
        if (objDesc.fields.getMap().containsKey(lookupFld)){
            Schema.DescribeFieldResult dfr = objDesc.fields.getMap().get(lookupFld).getDescribe();
            lookupObj = !dfr.getReferenceTo().isEmpty() ? dfr.getReferenceTo().get(0).getDescribe().getName() : '';
        }
        return lookupObj;
    }
    
    // Returns true if the Object.Field (eg Contact.Name) is accessible
    public static boolean HasCRUDandFLS(String objectDotField) {
        // If it is not in the map call the method to add it to it before returning
        if (!getObjDotFieldToHasCRUDandFLS().containsKey(objectDotField))
            PopulateObjToFieldFLSMap(new Set<String> {objectDotField}, false);
        
        Boolean returnVal = true;
        if (!Test.isRunningTest()){
            LIST<string> splitSchema = objectDotField.split('\\.');
            if (splitSchema.size()>2){
                objectDotField = splitSchema[0]+'.'+splitSchema[1];
                if (objectDotField.endsWithIgnoreCase('__r'))
                    objectDotField = objectDotField.replace('__r', '__c');
                if (!objectDotField.contains('__c')) objectDotField += 'id';
            }
            returnVal = getObjDotFieldToHasCRUDandFLS().get(objectDotField);
            if (returnVal == null){
                //  Trying if it's an "id" field
                returnVal = getObjDotFieldToHasCRUDandFLS().get(objectDotField+'id');
            }
        }

        if (returnVal == null){
            VertexLogging.Log('Error', objectDotField + ' returned a null CRUD/FLS result.');
            VertexLogging.CommitDelayed();
            returnVal = false;
        }
        return returnVal;
    }

    // Maps Object.Field (eg Contact.Name) to a boolean - true if both object and field are accessible
    private static Map<String, boolean> ObjDotFieldToHasCRUDandFLS;
    public static Map<String, boolean> getObjDotFieldToHasCRUDandFLS() {
        if (ObjDotFieldToHasCRUDandFLS == null)
            ObjDotFieldToHasCRUDandFLS = new Map<String, boolean>();
        return ObjDotFieldToHasCRUDandFLS;
    }

    // Adds the crud and fls results for the object.Field in the set
    public static void PopulateObjToFieldFLSMap(Set<String> objectDotFieldSet, boolean checkReadOnly) {
        System.debug('***PopulateObjToFieldFLSMap***');
        SET<String> objectDotFieldSetWithIds  = new SET<String>();
        for (String objDotField : objectDotFieldSet) {
            //  Populate the list with all possible matches, adding "id" fields (like accountid) which
            //  will only be added below if they actually find a match
            objectDotFieldSetWithIds.add(objDotField);
            objectDotFieldSetWithIds.add(objDotField+'id');
        }

        for (String objDotField : objectDotFieldSetWithIds){
            String obj = objDotField.split('\\.').get(0);
            String fld = objDotField.split('\\.').get(1);

            // Check if the map contains the describe result and if not add it
            if (!getObjToDescribe().containsKey(obj))
                if (GDMap.containsKey(obj))
                    getObjToDescribe().put(obj, GDMap.get(obj).getDescribe());
            
            if (getObjToDescribe().containsKey(obj)) {
                Schema.DescribeSObjectResult objDesc = getObjToDescribe().get(obj);

                // Check for crud and if its true proceed for fls check, else set to false
                if (objDesc.isAccessible() && (checkReadOnly || objDesc.isUpdateable())) {
                    // Check if the map contains the field describe and if not add it
                    if (!getFieldToDescribe().containsKey(fld))
                        if (objDesc.fields.getMap().containsKey(fld))
                            getFieldToDescribe().put(fld, objDesc.fields.getMap().get(fld).getDescribe());

                    if (getFieldToDescribe().containsKey(fld)) {
                        // At this point crud has been determined as true so assign the value of the fls results
                        Schema.DescribeFieldResult dfr = getFieldToDescribe().get(fld);
                        if (dfr.isAccessible() && (checkReadOnly || dfr.isUpdateable()))
                            getObjDotFieldToHasCRUDandFLS().put(objDotField, true);
                        else
                            getObjDotFieldToHasCRUDandFLS().put(objDotField, false);
                    }
                } else 
                    getObjDotFieldToHasCRUDandFLS().put(objDotField, false);
            }
        }
    }

    public static String stripCDATA(String str) {
        Pattern p = Pattern.compile('<!\\[CDATA\\[(.*?)\\]\\]>');
        Matcher m = p.matcher(str);
        while(m.find()) {
            str = str.replace(m.group(), m.group(1).escapeXml());
        }
        return str;
    }

    public static VertexAddress__c validateAddressCallout(VertexAddress__c addyToCheck){
        System.Debug('===VertexCore.validateAddressCallout');
        System.Debug('===addyToCheck '+addyToCheck);

        transient VertexProtectedSettings__c config = VertexCore.ActiveSettings;
        
        VertexAddress__c addyToReturn = new VertexAddress__c();
        Boolean failed = false;
        if (addyToCheck != null  && ((!String.isEmpty(config.Username__c) && !String.isEmpty(config.Password__c)) || !String.isEmpty(config.TrustedID__c))){
            
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml');
            req.setEndpoint(config.TaxAreaLookupURL__c);
            req.setBody(VertexSettingsController.BuildAddressXML(addyToCheck));
            Http http = new Http();
            transient String body;
            HTTPResponse res;
            try {
                res = http.send(req);
                body = res.getBody();
            } catch (System.CalloutException e) {
                System.debug('Callout Error on Address Validation: ' + e);
                VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
            }
            
            if (!String.isEmpty(body)){
                transient String xmlNs = VertexSettingsController.URN;

                String debugDetails = 'Address sent for validation: ' + addyToCheck.Address1__c + ', ' + addyToCheck.Address2__c + ', ' + 
                                      addyToCheck.City__c + ', ' + addyToCheck.State__c + ' ' + addyToCheck.PostalCode__c + ', ' + addyToCheck.Country__c + 
                                      ', Tax Area ID: ' + addyToCheck.TaxAreaID__c;
                VertexLogging.Log('Debug', debugDetails, req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
                
                try {
                    transient Dom.Document resDoc = new Dom.Document();
                    resDoc.load(VertexCore.stripCDATA(body));
                    transient Dom.XMLNode envelope = resDoc.getRootElement();
                    transient Dom.XMLNode taxAreaResult = envelope.getChildElement('Body',soapenv).getChildElement('VertexEnvelope',xmlNs).getChildElement('TaxAreaResponse',xmlNs).getChildElement('TaxAreaResult',xmlNs);
                    transient String taxAreaID = taxAreaResult.getAttribute('taxAreaId',null);
                    addyToCheck.TaxAreaID__c = taxAreaID;

                    transient Dom.XMLNode postalAddress = taxAreaResult.getChildElement('PostalAddress',xmlNs);
                    if(postalAddress != null){
                        if(postalAddress.getChildElement('StreetAddress1',xmlNs)!=null)
                            addyToReturn.Address1__c = postalAddress.getChildElement('StreetAddress1',xmlNs).getText();
                        if(postalAddress.getChildElement('StreetAddress2',xmlNs)!=null)
                            addyToReturn.Address2__c = postalAddress.getChildElement('StreetAddress2',xmlNs).getText();
                        if(postalAddress.getChildElement('City',xmlNs)!=null)
                            addyToReturn.City__c = postalAddress.getChildElement('City',xmlNs).getText();
                        if(postalAddress.getChildElement('MainDivision',xmlNs)!=null)
                            addyToReturn.State__c = postalAddress.getChildElement('MainDivision',xmlNs).getText();
                        if(postalAddress.getChildElement('PostalCode',xmlNs)!=null)
                            addyToReturn.PostalCode__c = postalAddress.getChildElement('PostalCode',xmlNs).getText();
                        if(postalAddress.getChildElement('Country',xmlNs)!=null)
                            addyToReturn.Country__c = postalAddress.getChildElement('Country',xmlNs).getText();
                    }
                    addyToReturn.TaxAreaID__c = taxAreaID;

                    if (
                        addyToCheck.Address1__c == addyToReturn.Address1__c
                        &&
                        addyToCheck.Address2__c == addyToReturn.Address2__c
                        &&
                        addyToCheck.City__c == addyToReturn.City__c
                        &&
                        addyToCheck.State__c == addyToReturn.State__c
                        &&
                        addyToCheck.PostalCode__c == addyToReturn.PostalCode__c
                        &&
                        addyToCheck.Country__c == addyToReturn.Country__c
                    )
                        addyToReturn = new VertexAddress__c();

                    if(taxAreaResult.getChildElement('AddressCleansingResultMessage',xmlNs)!=null){
                        addyToReturn = new VertexAddress__c();
                        addyToReturn.TaxAreaID__c = 'ERROR';
                        addyToReturn.Address1__c = taxAreaResult.getChildElement('AddressCleansingResultMessage',xmlNs).getText();
                    }

                } catch (Exception e){
                    VertexLogging.Log('Error', 'Address Validation Error: Unexpected Response', req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
                    failed = true;
                }
            } else if (req != null && res != null){
                VertexLogging.Log('Error', 'Address Validation Error: Null Response Body', req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
                failed = true;
            }
        } else {
            VertexLogging.Log('Error', 'Address Validation Error: Username/password/trustedID is invalid.');
            failed = true;
        }

        //  Return validated address or null
        return (failed==false) ? addyToReturn : null;
    }

    // Holder to avoid getDescribe calls
    private static Map<String, DescribeSObjectResult> ObjToDescribe;
    private static Map<String, DescribeSObjectResult> getObjToDescribe() {
        if (ObjToDescribe == null)
            ObjToDescribe = new Map<String, DescribeSObjectResult>();
        return ObjToDescribe;
    }

    // Holder to avoid getDescribe calls
    private static Map<String, DescribeFieldResult> FieldToDescribe;
    private static Map<String, DescribeFieldResult> getFieldToDescribe() {
        if (FieldToDescribe == null)
            FieldToDescribe = new Map<String, DescribeFieldResult>();
        return FieldToDescribe;
    }

    // public list<ResponseWrapper> resultSplitList { get { if (resultSplitList == null) resultSplitList = new list<ResponseWrapper>(); 
    //     return resultSplitList; } set; }
    public class ResponseWrapper{
        
        public String reponseBody {get; set;}
        public String reponseType {get; set;}
        public String mappingType {get; set;}

    }

}
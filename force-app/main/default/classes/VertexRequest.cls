public class VertexRequest extends VertexBaseRequest{

    /*  Accepted Abbreviations:
        PhysOrigin
        AdminOrigin
        Dest
        AdminDest
    */
    
    /* TODO
        1)  GenerateXML
            a)  XLeverage Matt's CS for Parent Seller AdminOrigin and PhysOrigin
            b)  Leverage Matt's CS for Child Seller PhysOrigin
            c)  Ensure using mappings for Parent Customer Dest/Admin Dest, Child Dest/Admin Dest + Line Items (omitting child seller origins)
        2)  Include parent and child tax override fields
        3)  Reference CS for Taxpayer Code, company tax id
        4)  Reference mapping for Parent Taxable and Child Line Item Taxable
        5)  Handle nulls, empties, etc from obj --> xml
    */

    /*  Vertex Question
        
        1)  Line Item Fields to populate and the available Product2 fields
    
    */    
    /* Objectives
        1)  Build dynamic query string for parents and children, including all address set fields (admin origin, destination, etc)
        2)  Query for records
        3)  Process each record (individual parent w/ children)
            a)  Populate RequestStructure
            b)  Generate Body XML
        4)  Enqueue callouts for each RequestStructure
        5)  Deal w/ response
    */

    //minimum possible length of a salesforce id
    public static final Integer MIN_ID_SIZE = 15;
    
    public VertexRequest(String requestType, boolean doParseResponse) {
        super(requestType);
        this.DoParseResponse = doParseResponse;
    }

    public boolean TaxOnly {get; set;}
    public boolean PostToJournal {get; set;}

    public VertexMapping VMap { get; set; }
    
    //  Generic method to handle quotation requests for collection of parent objects (e.g. Opportunities)
    public List<HttpResponse> InvokeRequestList(LIST<InvokeRequestStructure> requests, boolean isAsynchronous) {
        //  Confirm parent records were provided
        if (!requests.isEmpty()) {
            System.debug('-->Log 2 : VertexRequest !requests.isEmpty');
            VMap = new VertexMapping(requests[0]);
            if (VMap.ObjMap != null) {
                System.debug('-->Log 3 : VertexRequest VMap.ObjMap != null');
                if (VMap.ObjMap.ChildSObjectRelationshipName__c != null && VMap.ObjMap.ParentSObject__c != null) {
                    System.debug('-->Log 4 : VertexRequest VMap.ObjMap.ChildSObjectRelationshipName__c != null');
                    String haveCRUDandFLSResult = HaveCRUDandFLS();
                    //  Suppress FLS checking in Billing calls, it's being managed in the other package.
                    if (VertexCore.ActiveSettings.Billing_Requested__c == true || haveCRUDandFLSResult == '') {
                        System.debug('-->Log 5 : VertexRequest VertexCore.ActiveSettings.Billing_Requested__c == true');
                        //  Objectives 1+2:  Attempt to query for the records associated with those ids, along with their line item children (e.g., Opportunities w/ OpportunityLineItems)
                        list<sObject> parentsWithChildren = getParentsAndChildren(requests);
                        //we only need to run this if the override map is populated
                        if(!VertexCore.fieldOverrideMap.keySet().isEmpty()){
                            parentsWithChildren = getParentChildOverrideList(parentsWithChildren,VMap.ObjMap.ChildSObjectRelationshipName__c);
                        }

                        //  Determine there is at least one parent that needs processed
                        if (!parentsWithChildren.isEmpty()) {
                            System.debug('-->Log 5 : VertexRequest !parentsWithChildren.isEmpty()');
                            
                            SObject parentObj = parentsWithChildren[0];
                            Id parentId = parentObj.Id;
                            String childName = VMap.ObjMap.ChildSobject__c;
                            String parentLookup = VMap.ObjMap.ParentLookup__c;
                            String soql = 'SELECT Id FROM ' + childName + ' WHERE ' + parentLookup + ' =: parentId LIMIT 1000';
                            List<Sobject> childRecords;
                            
                            try{
                                childRecords = Database.query(soql);
                            } catch (Exception e) {
                                System.debug('Exception '+e);
                                VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
                            }
                            

                            Integer childrenSize = childRecords.size();

                            Boolean exceedsMaxSize = false;
                            if(VertexCore.ActiveSettings.MaximumLineItems__c != null && (childrenSize > VertexCore.ActiveSettings.MaximumLineItems__c)){
                                exceedsMaxSize = true;
                                System.debug('-->Log 7 : VertexRequest VertexCore.ActiveSettings.MaximumLineItems__c != null');
                            }
                            
                            //if theres less than that number we can build synchronously
                            if(exceedsMaxSize){
                                System.debug('-->Log 8 : VertexRequest exceedsMaxSize');
                                //run async processing
                                VertexBulkRequest batch = new VertexBulkRequest(parentsWithChildren,VMap,requestType,doParseResponse, requests[0].mappingType);
                                Database.executeBatch(batch);
                            }
                            else{
                                System.debug('-->Log 9 : VertexRequest Doesnot exceedsMaxSize');
                                //  Obj 3:  Loop through those parents and do the necessary work to prepare requests for each
                                for (sObject parent :parentsWithChildren) {
                                    //  Instantiate a new pending request, pre-populating the parent sObject
                                    VertexPendingRequest pendingRequest = new VertexPendingRequest(parent,requests[0].mappingType);

                                    //  Obj 3a:  Fill in the RequestStructure obj structure
                                    Boolean requestPopulatedSuccessfully = PopulateRequest(pendingRequest);
                                    //  Obj 3b:  Create an XML body for the callout based on the RequestStructure obj details
                                    Boolean xmlBodyCreatedSuccessfuly = GenerateXMLBody(pendingRequest);
                                    
                                    // If the xmlBody was succesfully created
                                    if (requestPopulatedSuccessfully && xmlBodyCreatedSuccessfuly){
                                        System.debug('-->Log 12 : VertexRequest requestPopulatedSuccessfully and XML sucess');
                                        //  Add this request to the collection needing processing
                                        pendingRequests.add(pendingRequest);
                                    }
                                    else
                                        // Commit the error logs
                                        VertexLogging.CommitDelayed();
                                }
                            }
                        }
                    } else {
                        VertexLogging.Log('Error', 'Insufficient object or field access on: ' + haveCRUDandFLSResult);
                    }
                } else {
                    VertexLogging.Log('Error', 'Mappings for transaction and line objects are missing from "' + requests[0].mappingType + '" configuration');
                }
            } else {
                VertexLogging.Log('Error', 'Invalid type "' + requests[0].mappingType + '" specified by process.');
            }
        }
        VertexLogging.CommitDelayed();
        return CompletePendingRequests(requests[0].mappingType, isAsynchronous);
    }

    //takes in a list of sobjects, transformes them based on the override list
    //returns a list of sobjects but with the new overridden values
    @testVisible
    private static List<SObject> getParentChildOverrideList(List<SObject> parentsWithChildren, String childRelationshipName){
        //since we may need to do overrides we cast the parentsWithChildren string
        String parentChildString = JSON.serialize(parentsWithChildren);

        //we have to use Object because changing formula field values on SObject produces an error
        List<Object> objList = (List<Object>) JSON.deserializeUntyped(parentChildString);

        //create a list of new SObjects. These will have the modified values from the override map
        List<SObject> modifiedObjectList = new List<SObject>();
        for(Object obj : objList){
            //override the fields by placing the overridemap values into the current record
            Map<String,Object> fieldMap = getOverriddenFieldMap(obj);

            //Child Record Override
            //get the child records
            Object childRecords = fieldMap.get(childRelationshipName);
            //if there are no child records on this object skip the process of overriding them
            if(childRecords != null){
                setChildRecordsOnFieldMap(childRecords, childRelationshipName, fieldMap);
            }
            //if there are overrides that are to new line items add them to the callout
            setAdditionalChildRecordOverrides(childRelationshipName,fieldMap);
            try{
                SObject newSObject = (SObject) JSON.deserialize(JSON.serialize(fieldMap),SObject.class);
                modifiedObjectList.add(newSObject);
            }catch(Exception e){
                VertexLogging.Log('Error','Error parsing overridden record: check that all fields in the override map are using proper data types');
            }
            
        }
        parentsWithChildren = modifiedObjectList;
        return parentsWithChildren;
    }

    //overrides fields on the parent record, places new value into fieldMap
    private static Map<String,Object> getOverriddenFieldMap(Object obj){
        String objString = JSON.serialize(obj);
        Map<String,Object> fieldMap = (Map<String,Object>) JSON.deserializeUntyped(objString);

        Id recordId = (Id) fieldMap.get('Id');

        Map<String,String> overrideMap = VertexCore.fieldOverrideMap.get(recordId);

        if(overrideMap == null){
            overrideMap = new Map<String,String>();
        }

        //for every item in the override map, update the field map
        for(String fieldName : overrideMap.keySet()){
            fieldMap.put(fieldName,overrideMap.get(fieldName));
        }

        return fieldMap;
    }

    //overrides fields on the child record.  Places the new values into fieldMap
    private static void setChildRecordsOnFieldMap(Object childRecords, String childRelationshipName, Map<String,Object> fieldMap){
        Map<String,Object> childMap = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(childRecords));
        List<Object> childRecordsList = (List<Object>) childMap.get('records');
        
        //loop through child records and check for a matching id on the override map
        //if the id matches, update the field map
        List<Object> updatedRecords = getUpdatedRecords(childRecordsList);

        //place the updated records back into the child records
        childMap.put('records',updatedRecords);
        fieldMap.put(childrelationshipName,childMap);
    }

    //takes a list of records, returns the overridden list of records
    //records are overridden from the override map
    private static List<Object> getUpdatedRecords(List<Object> childRecordsList){
        List<Map<String,Object>> childFieldMapList = new List<Map<String,Object>>();

        //convert the childRecord object into a map by casting it as a map
        //this will only work for "Object" types
        //the json for the child record is already in the format of a map so we only need to cast as a map
        //to get it into the new format
        for(Object childRecord : childRecordsList){
            childFieldMapList.add( (Map<String,Object>) childRecord);
        }

        //for each child record, loop through and override the field mapping to create a new list of child
        //records with overridden values
        List<Map<String,Object>> childRecordMapList = new List<Map<String,Object>>();
        for(Map<String,Object> childRecordMap : childFieldMapList){
            String recordId = (String)  childRecordMap.get('Id');

            Map<String,String> overrideMap = VertexCore.fieldOverrideMap.get(recordId);

            //special case when the override map is blank, we want to instantiate it into an empty map
            if(overrideMap == null){
                overrideMap = new Map<String,String>();
            }

            //overwrites the old field value with the new one from the override map for each field on the child record
            for(String fieldName : overrideMap.keySet()){
                childRecordMap.put(fieldName,overrideMap.get(fieldName));
            }
            childRecordMapList.add(childRecordMap);
        }

        return childRecordMapList;
    }


    //if there are records with dummy ids i.e. new1, new2, add them to the list of all child records
    private static void setAdditionalChildRecordOverrides( String childRelationshipName, Map<String,Object> fieldMap){
        Map<String,Object> childMap = new Map<String,Object>();
        Object overriddenChildRecords = fieldMap.get(childRelationshipName);
        if(overriddenChildRecords != null){
            childMap = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(overriddenChildRecords));
        }
        
        List<Object> newRecords = getNewRecords();
        //place the updated records back into the child records
        //get the previous records
        setAllChildRecords(childMap,newRecords,childRelationshipName);
        fieldMap.put(childrelationshipName,childMap);
    }

    //for every item in the override map that has a dummy id 
    //create a new record to add to the list of children
    @testVisible
    private static List<Object> getNewRecords(){
        List<Map<String,String>> newFieldMapList = new List<Map<String,String>>();
        for(String key : VertexCore.fieldOverrideMap.keySet()){
            if( key.startsWith('new') && (key.length() < MIN_ID_SIZE)){
                Map<String,String> newRecordFieldMap = VertexCore.fieldOverrideMap.get(key);
                newFieldMapList.add(newRecordFieldMap);
            }
        }

        //deserialize the newfieldmaplist into new records
        List<Object> newRecords = (List<Object>) JSON.deserializeUntyped(JSON.serialize(newFieldMapList));
        return newRecords;
    }

    //setting the child list after adding in the records that were created from dummy ids
    private static void setAllChildRecords(Map<String,Object> childMap, List<Object> newRecords, String childRelationshipName){
        List<Object> allChildRecords = new List<Object>();
        allChildRecords = (List<Object>) childMap.get('records');
        //handle possibility that childMap has a blank value for records
        if(allChildRecords == null){
            allChildRecords = new List<Object>();
        }
        allChildRecords.addAll(newRecords);
        childMap.put('records',allChildRecords);
    }

    // Method to check for crud and fls access to the fields being accessed by the request
    public String HaveCRUDandFLS() {
        String retVal = '';

        // add the fields from the object mappings
        if (String.isNotBlank(VMap.ObjMap.ParentSObject__c)) {
            if (String.isNotBlank(VMap.ObjMap.ParentSourcePicklist__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.ParentSourcePicklist__c);
            if (String.isNotBlank(VMap.ObjMap.TransactionTaxPayer__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.TransactionTaxPayer__c);
            if (String.isNotBlank(VMap.ObjMap.TransactionDate__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.TransactionDate__c);
            if (String.isNotBlank(VMap.ObjMap.TransactionNumber__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.TransactionNumber__c);
            if (String.isNotBlank(VMap.ObjMap.Posting_Date__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.Posting_Date__c);
            if (String.isNotBlank(VMap.ObjMap.TaxRegistrationNumber__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.TaxRegistrationNumber__c);
            if (String.isNotBlank(VMap.ObjMap.TransactionDeliveryTerm__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.TransactionDeliveryTerm__c);
            if (String.isNotBlank(VMap.ObjMap.CurrencyCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + VMap.ObjMap.CurrencyCode__c);
            
            // add the fields from the address mappings
            Set<String> parentAddressFlds = new Set<String>();
            if (String.isNotBlank(VMap.ParentFieldMap.Address1__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.Address1__c));
            if (String.isNotBlank(VMap.ParentFieldMap.Address2__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.Address2__c));
            if (String.isNotBlank(VMap.ParentFieldMap.City__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.City__c));
            if (String.isNotBlank(VMap.ParentFieldMap.Country__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.Country__c));
            if (String.isNotBlank(VMap.ParentFieldMap.PostalCode__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.PostalCode__c));
            if (String.isNotBlank(VMap.ParentFieldMap.State__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.State__c));
            if (String.isNotBlank(VMap.ParentFieldMap.TaxAreaID__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.TaxAreaID__c));
            if (String.isNotBlank(VMap.ParentFieldMap.CustomerCode__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.CustomerCode__c));
            if (String.isNotBlank(VMap.ParentFieldMap.CustomerClassCode__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.CustomerClassCode__c));
            if (String.isNotBlank(VMap.ParentFieldMap.LocationCode__c))
                parentAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ParentSObject__c, VMap.ParentFieldMap.LocationCode__c));
            
            for (String objDotFld : parentAddressFlds){
                if (String.isNotBlank(objDotFld) && objDotFld.contains('.'))
                    PopulateObjToFieldReadOnly(objDotFld);
            }
        }

        if (String.isNotBlank(VMap.ObjMap.ChildSObject__c)) {
            if (String.isNotBlank(VMap.ObjMap.ChildSourcePicklist__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.ChildSourcePicklist__c);
            if (String.isNotBlank(VMap.ObjMap.ItemClassField__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.ItemClassField__c);
            if (String.isNotBlank(VMap.ObjMap.ItemNameField__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.ItemNameField__c);
            if (String.isNotBlank(VMap.ObjMap.ItemTaxPayerField__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.ItemTaxPayerField__c);
            if (String.isNotBlank(VMap.ObjMap.ItemPriceField__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.ItemPriceField__c);
            if (String.isNotBlank(VMap.ObjMap.InputTotalTax__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.InputTotalTax__c);
            if (String.isNotBlank(VMap.ObjMap.ItemQuantityField__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.ItemQuantityField__c);
            if (String.isNotBlank(VMap.ObjMap.LineDeliveryTerm__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.LineDeliveryTerm__c);
            if (String.isNotBlank(VMap.ObjMap.CommodityCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.CommodityCode__c);
            if(String.isNotBlank(VMap.ObjMap.CommodityCodeType__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.CommodityCodeType__c);
            if (String.isNotBlank(VMap.ObjMap.SuppressTaxCallout__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.SuppressTaxCallout__c);
            if (String.isNotBlank(VMap.ObjMap.TaxIncludedIndicator__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.TaxIncludedIndicator__c);
            if (String.isNotBlank(VMap.ObjMap.UsageCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.UsageCode__c);
            if (String.isNotBlank(VMap.ObjMap.UsageClass__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + VMap.ObjMap.UsageClass__c);

            Set<String> childAddressFlds = new Set<String>();
            if (String.isNotBlank(VMap.ChildFieldMap.Address1__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.Address1__c));
            if (String.isNotBlank(VMap.ChildFieldMap.Address2__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.Address2__c));
            if (String.isNotBlank(VMap.ChildFieldMap.City__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.City__c));
            if (String.isNotBlank(VMap.ChildFieldMap.Country__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.Country__c));
            if (String.isNotBlank(VMap.ChildFieldMap.PostalCode__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.PostalCode__c));
            if (String.isNotBlank(VMap.ChildFieldMap.State__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.State__c));
            if (String.isNotBlank(VMap.ChildFieldMap.TaxAreaID__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.TaxAreaID__c));
            if (String.isNotBlank(VMap.ChildFieldMap.LocationCode__c))
                childAddressFlds.addAll(VertexCore.GetObjDotField(VMap.ObjMap.ChildSObject__c, VMap.ChildFieldMap.LocationCode__c));
            
            for (String objDotFld : childAddressFlds){
                if (String.isNotBlank(objDotFld) && objDotFld.contains('.'))
                    PopulateObjToFieldReadOnly(objDotFld);
            }
        }

        VertexAddress__c transAdminOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Trans Admin');
        if (transAdminOrigin != null){
            if (String.isNotBlank(transAdminOrigin.Address1__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.Address1__c);
            if (String.isNotBlank(transAdminOrigin.Address2__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.Address2__c);
            if (String.isNotBlank(transAdminOrigin.City__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.City__c);
            if (String.isNotBlank(transAdminOrigin.Country__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.Country__c);
            if (String.isNotBlank(transAdminOrigin.PostalCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.PostalCode__c);
            if (String.isNotBlank(transAdminOrigin.State__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.State__c);
            if (String.isNotBlank(transAdminOrigin.TaxAreaID__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.TaxAreaID__c);
            if (String.isNotBlank(transAdminOrigin.LocationCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transAdminOrigin.LocationCode__c);
        }
        VertexAddress__c transPhysOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Trans Phys');
        if (transPhysOrigin != null){
            if (String.isNotBlank(transPhysOrigin.Address1__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.Address1__c);
            if (String.isNotBlank(transPhysOrigin.Address2__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.Address2__c);
            if (String.isNotBlank(transPhysOrigin.City__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.City__c);
            if (String.isNotBlank(transPhysOrigin.Country__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.Country__c);
            if (String.isNotBlank(transPhysOrigin.PostalCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.PostalCode__c);
            if (String.isNotBlank(transPhysOrigin.State__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.State__c);
            if (String.isNotBlank(transPhysOrigin.TaxAreaID__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.TaxAreaID__c);
            if (String.isNotBlank(transPhysOrigin.LocationCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ParentSObject__c + '.' + transPhysOrigin.LocationCode__c);
        }
        VertexAddress__c lineAdminOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Line Admin');
        if (lineAdminOrigin != null){
            if (String.isNotBlank(lineAdminOrigin.Address1__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.Address1__c);
            if (String.isNotBlank(lineAdminOrigin.Address2__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.Address2__c);
            if (String.isNotBlank(lineAdminOrigin.City__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.City__c);
            if (String.isNotBlank(lineAdminOrigin.Country__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.Country__c);
            if (String.isNotBlank(lineAdminOrigin.PostalCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.PostalCode__c);
            if (String.isNotBlank(lineAdminOrigin.State__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.State__c);
            if (String.isNotBlank(lineAdminOrigin.TaxAreaID__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.TaxAreaID__c);
            if (String.isNotBlank(lineAdminOrigin.LocationCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + lineAdminOrigin.LocationCode__c);
        }
        VertexAddress__c linePhysOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Line Phys');
        if (linePhysOrigin != null){
            if (String.isNotBlank(linePhysOrigin.Address1__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.Address1__c);
            if (String.isNotBlank(linePhysOrigin.Address2__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.Address2__c);
            if (String.isNotBlank(linePhysOrigin.City__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.City__c);
            if (String.isNotBlank(linePhysOrigin.Country__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.Country__c);
            if (String.isNotBlank(linePhysOrigin.PostalCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.PostalCode__c);
            if (String.isNotBlank(linePhysOrigin.State__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.State__c);
            if (String.isNotBlank(linePhysOrigin.TaxAreaID__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.TaxAreaID__c);
            if (String.isNotBlank(linePhysOrigin.LocationCode__c))
                PopulateObjToFieldReadOnly(VMap.ObjMap.ChildSObject__c  + '.' + linePhysOrigin.LocationCode__c);
        }

        VertexCore.PopulateObjToFieldFLSMap(ParsedObjectDotFieldSet, true);

        for (String objectDotField : ParsedObjectDotFieldSet) {
            if (VertexCore.HasCRUDandFLS(objectDotField) != true)
                retVal += objectDotField + ', ';
        }

        return retVal.removeEnd(', ');
    }

    private Set<String> ParsedObjectDotFieldSet = new Set<String>();
    // Checks only for read access. String can be multiple levels eg Opportunity.Account.BillingStreet
    public void PopulateObjToFieldReadOnly(String objectDotField) {

        List<String> splits = objectDotField.split('\\.');
        // go through the relationships
        for (Integer i = 0; i < splits.size() - 2; i++) {
            // If the relationship is not a custom one need to append Id (eg Opportunity.AccountId)
            if (splits.get(i + 1).endsWith('__r') || splits.get(i + 1).endsWith('__c'))
                ParsedObjectDotFieldSet.add(splits.get(i) + '.' + splits.get(i + 1));
            else
                ParsedObjectDotFieldSet.add(splits.get(i) + '.' + splits.get(i + 1) + 'Id');
        }

        // Add the final field
        ParsedObjectDotFieldSet.add(splits.get(splits.size() - 2) + '.' + splits.get(splits.size() - 1));
    }


    //  Method to retrieve list of parent sObjects w/ nested children
    public  list<sObject> getParentsAndChildren(LIST<InvokeRequestStructure> requests) {
        
        list<sObject> results = new list<sObject>();
        list<string> parentIds = new LIST<String>();
        //  If there were any, query for parents and ALL children
        if (!requests.isEmpty()) {

            for(InvokeRequestStructure request: requests)
                parentIds.add(request.recordId);
            
            //  Begin base of dynamic soql queries for outer and inner
            string soqlStr = 'SELECT <SELECTPARENTFLDS> FROM <PARENTOBJ> WHERE <PARENTFILTER>';
            string subSoqlStr = ' (SELECT <SELECTCHILDFLDS> FROM <CHILDOBJRELNAME> <CHILDWHERECLAUSE>) ';
            
            //  Create a list of all the fields to be included at the parent level <--  TODO:  Need to determine what child fields can override lineItem seller and customer address sets
            set<string> selectParentFields = new set<string>();
            
            if (String.isNotBlank(VMap.ParentFieldMap.Address1__c))
                selectParentFields.add(VMap.ParentFieldMap.Address1__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.Address2__c))
                selectParentFields.add(VMap.ParentFieldMap.Address2__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.City__c))
                selectParentFields.add(VMap.ParentFieldMap.City__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.Country__c))
                selectParentFields.add(VMap.ParentFieldMap.Country__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.PostalCode__c))
                selectParentFields.add(VMap.ParentFieldMap.PostalCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.State__c))
                selectParentFields.add(VMap.ParentFieldMap.State__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.TaxAreaID__c))
                selectParentFields.add(VMap.ParentFieldMap.TaxAreaID__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.CustomerCode__c))
                selectParentFields.add(VMap.ParentFieldMap.CustomerCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.CustomerClassCode__c))
                selectParentFields.add(VMap.ParentFieldMap.CustomerClassCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ParentFieldMap.LocationCode__c))
                selectParentFields.add(VMap.ParentFieldMap.LocationCode__c.toLowerCase());
                
            if (String.isNotBlank(VMap.ObjMap.ParentSourcePicklist__c))
                selectParentFields.add(VMap.ObjMap.ParentSourcePicklist__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.TransactionTaxPayer__c))
                selectParentFields.add(VMap.ObjMap.TransactionTaxPayer__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.TransactionDate__c))
                selectParentFields.add(VMap.ObjMap.TransactionDate__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.TransactionNumber__c))
                selectParentFields.add(VMap.ObjMap.TransactionNumber__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.Posting_Date__c))
                selectParentFields.add(VMap.ObjMap.Posting_Date__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.TaxRegistrationNumber__c))
                selectParentFields.add(VMap.ObjMap.TaxRegistrationNumber__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.TransactionDeliveryTerm__c))
                selectParentFields.add(VMap.ObjMap.TransactionDeliveryTerm__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.CurrencyCode__c))
                selectParentFields.add(VMap.ObjMap.CurrencyCode__c.toLowerCase());
            
            
            Set<String> selectChildFields = selectChildFields();
            
            VertexAddress__c transAdminOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Trans Admin');
            if (transAdminOrigin != null){
                if (String.isNotBlank(transAdminOrigin.Address1__c))
                    selectParentFields.add(transAdminOrigin.Address1__c.toLowerCase());
                if (String.isNotBlank(transAdminOrigin.Address2__c))
                    selectParentFields.add(transAdminOrigin.Address2__c.toLowerCase());
                if (String.isNotBlank(transAdminOrigin.City__c))
                    selectParentFields.add(transAdminOrigin.City__c.toLowerCase());
                if (String.isNotBlank(transAdminOrigin.Country__c))
                    selectParentFields.add(transAdminOrigin.Country__c.toLowerCase());
                if (String.isNotBlank(transAdminOrigin.PostalCode__c))
                    selectParentFields.add(transAdminOrigin.PostalCode__c.toLowerCase());
                if (String.isNotBlank(transAdminOrigin.State__c))
                    selectParentFields.add(transAdminOrigin.State__c.toLowerCase());
                if (String.isNotBlank(transAdminOrigin.TaxAreaID__c))
                    selectParentFields.add(transAdminOrigin.TaxAreaID__c.toLowerCase());
                if (String.isNotBlank(transAdminOrigin.LocationCode__c))
                    selectParentFields.add(transAdminOrigin.LocationCode__c.toLowerCase());
            }
            VertexAddress__c transPhysOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Trans Phys');
            if (transPhysOrigin != null){
                if (String.isNotBlank(transPhysOrigin.Address1__c))
                    selectParentFields.add(transPhysOrigin.Address1__c.toLowerCase());
                if (String.isNotBlank(transPhysOrigin.Address2__c))
                    selectParentFields.add(transPhysOrigin.Address2__c.toLowerCase());
                if (String.isNotBlank(transPhysOrigin.City__c))
                    selectParentFields.add(transPhysOrigin.City__c.toLowerCase());
                if (String.isNotBlank(transPhysOrigin.Country__c))
                    selectParentFields.add(transPhysOrigin.Country__c.toLowerCase());
                if (String.isNotBlank(transPhysOrigin.PostalCode__c))
                    selectParentFields.add(transPhysOrigin.PostalCode__c.toLowerCase());
                if (String.isNotBlank(transPhysOrigin.State__c))
                    selectParentFields.add(transPhysOrigin.State__c.toLowerCase());
                if (String.isNotBlank(transPhysOrigin.TaxAreaID__c))
                    selectParentFields.add(transPhysOrigin.TaxAreaID__c.toLowerCase());
                if (String.isNotBlank(transPhysOrigin.LocationCode__c))
                    selectParentFields.add(transPhysOrigin.LocationCode__c.toLowerCase());
            }
            
            setOriginFields(selectChildFields);
                    
            //  Build csv string of parent fields from list for use in replacements below
            string selectParentFieldsStr = '';
            if (!selectParentFields.isEmpty()) {
                for (string fld :selectParentFields) {
                    if (string.isNotBlank(fld))
                        selectParentFieldsStr += fld + ', ';
                }
            }
            
            //  Build csv string of child fields from list for use in replacements below
            string selectChildFieldsStr = getChildFieldsString(selectChildFields);

            selectChildFieldsStr = selectChildFieldsStr.removeEnd(', ');
            
            //  Trim commas
            selectParentFieldsStr = selectParentFieldsStr.removeEnd(', ');
            
            //  Perform Replacements for Child
            subSoqlStr = subSoqlStr.replace('<SELECTCHILDFLDS>', selectChildFieldsStr);
            subSoqlStr = subSoqlStr.replace('<CHILDOBJRELNAME>', VMap.ObjMap.ChildSObjectRelationshipName__c);
                       
            //  Append subquery to end of parent select fields
            selectParentFieldsStr += ', ' + subSoqlStr;
            
            soqlStr = soqlStr.replace('<SELECTPARENTFLDS>', selectParentFieldsStr);
            soqlStr = soqlStr.replace('<PARENTOBJ>', VMap.ObjMap.ParentSObject__c);
            soqlStr = soqlStr.replace('<PARENTFILTER>', 'Id IN :parentIds');
            
            if (!string.isEmpty(VMap.ObjMap.SuppressTaxCallout__c))
               soqlStr = soqlStr.replace('<CHILDWHERECLAUSE>', 'WHERE ' + VMap.ObjMap.SuppressTaxCallout__c + ' != true');
            else
                soqlStr = soqlStr.replace('<CHILDWHERECLAUSE>', '');
            
            try {
                results = database.query(soqlStr);
            } catch (System.CalloutException e) {
                System.debug('Exception '+e);
                VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
            }
            
        }
        
        //  RetVertexCore.URN list of parents w/ nested children
        return results;
    }



    public Set<String> selectChildFields(){
        set<string> selectChildFields = new set<string>();
            if (String.isNotBlank(VMap.ChildFieldMap.Address1__c))
                selectChildFields.add(VMap.ChildFieldMap.Address1__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.Address2__c))
                selectChildFields.add(VMap.ChildFieldMap.Address2__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.City__c))
                selectChildFields.add(VMap.ChildFieldMap.City__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.Country__c))
                selectChildFields.add(VMap.ChildFieldMap.Country__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.PostalCode__c))
                selectChildFields.add(VMap.ChildFieldMap.PostalCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.State__c))
                selectChildFields.add(VMap.ChildFieldMap.State__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.TaxAreaID__c))
                selectChildFields.add(VMap.ChildFieldMap.TaxAreaID__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.CustomerCode__c))
                selectChildFields.add(VMap.ChildFieldMap.CustomerCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.CustomerClassCode__c))
                selectChildFields.add(VMap.ChildFieldMap.CustomerClassCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ChildFieldMap.LocationCode__c))
                selectChildFields.add(VMap.ChildFieldMap.LocationCode__c.toLowerCase());
                
            if (String.isNotBlank(VMap.ObjMap.ChildSourcePicklist__c))
                selectChildFields.add(VMap.ObjMap.ChildSourcePicklist__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.ItemClassField__c))
                selectChildFields.add(VMap.ObjMap.ItemClassField__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.ItemNameField__c))
                selectChildFields.add(VMap.ObjMap.ItemNameField__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.ItemTaxPayerField__c))
                selectChildFields.add(VMap.ObjMap.ItemTaxPayerField__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.ItemPriceField__c))
                selectChildFields.add(VMap.ObjMap.ItemPriceField__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.InputTotalTax__c))
                selectChildFields.add(VMap.ObjMap.InputTotalTax__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.ItemQuantityField__c))
                selectChildFields.add(VMap.ObjMap.ItemQuantityField__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.LineDeliveryTerm__c))
                selectChildFields.add(VMap.ObjMap.LineDeliveryTerm__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.CommodityCode__c))
                selectChildFields.add(VMap.ObjMap.CommodityCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.CommodityCodeType__c))
                selectChildFields.add(VMap.ObjMap.CommodityCodeType__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.SuppressTaxCallout__c))
                selectChildFields.add(VMap.ObjMap.SuppressTaxCallout__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.TaxIncludedIndicator__c))
                selectChildFields.add(VMap.ObjMap.TaxIncludedIndicator__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.UsageCode__c))
                selectChildFields.add(VMap.ObjMap.UsageCode__c.toLowerCase());
            if (String.isNotBlank(VMap.ObjMap.UsageClass__c))
                selectChildFields.add(VMap.ObjMap.UsageClass__c.toLowerCase());
            if (VMap.LineFlexFldMaps != null){
                for (VertexFieldMapping__c fldMap : VMap.LineFlexFldMaps)
                    selectChildFields.add(fldMap.SourceField__c.toLowerCase());
            }

            // add fields for the billing child destination address
            if (!VertexCore.BillingDestinationMappings.isEmpty() && VertexCore.IsBillingInstalled)
                for (String fieldName : VertexCore.BillingDestinationMappings.values())
                    if (String.isNotBlank(fieldName))
                        selectChildFields.add(fieldName.toLowerCase());
            // add fields for the child destination address override
            if (!VertexCore.LineDestinationOverrideMappings.isEmpty() && VertexCore.IsBillingInstalled)
                for (String fieldName : VertexCore.LineDestinationOverrideMappings.values())
                    if (String.isNotBlank(fieldName))
                        selectChildFields.add(fieldName.toLowerCase());

        return selectChildFields;
    }



    public void setOriginFields(Set<String> selectChildFields){
        VertexAddress__c lineAdminOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Line Admin');
        if (lineAdminOrigin != null){
            if (String.isNotBlank(lineAdminOrigin.Address1__c))
                selectChildFields.add(lineAdminOrigin.Address1__c.toLowerCase());
            if (String.isNotBlank(lineAdminOrigin.Address2__c))
                selectChildFields.add(lineAdminOrigin.Address2__c.toLowerCase());
            if (String.isNotBlank(lineAdminOrigin.City__c))
                selectChildFields.add(lineAdminOrigin.City__c.toLowerCase());
            if (String.isNotBlank(lineAdminOrigin.Country__c))
                selectChildFields.add(lineAdminOrigin.Country__c.toLowerCase());
            if (String.isNotBlank(lineAdminOrigin.PostalCode__c))
                selectChildFields.add(lineAdminOrigin.PostalCode__c.toLowerCase());
            if (String.isNotBlank(lineAdminOrigin.State__c))
                selectChildFields.add(lineAdminOrigin.State__c.toLowerCase());
            if (String.isNotBlank(lineAdminOrigin.TaxAreaID__c))
                selectChildFields.add(lineAdminOrigin.TaxAreaID__c.toLowerCase());
            if (String.isNotBlank(lineAdminOrigin.LocationCode__c))
                selectChildFields.add(lineAdminOrigin.LocationCode__c.toLowerCase());
        }
        VertexAddress__c linePhysOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Line Phys');
        if (linePhysOrigin != null){
            if (String.isNotBlank(linePhysOrigin.Address1__c))
                selectChildFields.add(linePhysOrigin.Address1__c.toLowerCase());
            if (String.isNotBlank(linePhysOrigin.Address2__c))
                selectChildFields.add(linePhysOrigin.Address2__c.toLowerCase());
            if (String.isNotBlank(linePhysOrigin.City__c))
                selectChildFields.add(linePhysOrigin.City__c.toLowerCase());
            if (String.isNotBlank(linePhysOrigin.Country__c))
                selectChildFields.add(linePhysOrigin.Country__c.toLowerCase());
            if (String.isNotBlank(linePhysOrigin.PostalCode__c))
                selectChildFields.add(linePhysOrigin.PostalCode__c.toLowerCase());
            if (String.isNotBlank(linePhysOrigin.State__c))
                selectChildFields.add(linePhysOrigin.State__c.toLowerCase());
            if (String.isNotBlank(linePhysOrigin.TaxAreaID__c))
                selectChildFields.add(linePhysOrigin.TaxAreaID__c.toLowerCase());
            if (String.isNotBlank(linePhysOrigin.LocationCode__c))
                selectChildFields.add(linePhysOrigin.LocationCode__c.toLowerCase());
        }
    }

    public String getChildFieldsString(Set<String> selectChildFields){
        //  Build csv string of child fields from list for use in replacements below
        string selectChildFieldsStr = '';
        if (!selectChildFields.isEmpty()) {
            for (string fld : selectChildFields) {
                if (string.isNotBlank(fld))
                    selectChildFieldsStr += fld + ', ';
            }
        }

        selectChildFieldsStr = selectChildFieldsStr.removeEnd(', ');

        return selectChildFieldsStr;
    }
    
    public string ApplyMapping(sObject sObj, string srcFld) {
        
        string result;
        
        if (sObj != null && string.isNotBlank(srcFld)) {
            List<String> split = srcFld.split('\\.');
            // If the field is on the object eg sObj.mappingField
            if (split.size() == 1)
                result = string.valueOf(sObj.get(srcFld));
            // else if the field is on the child object eg sObj.Account.mappingField
            else if (split.size() == 2) {
                string lookupFld = split[0];
                string fldOrParentFld = split[1];
                if (sObj.getSObject(lookupFld) != null)
                    result = string.valueOf(sObj.getSObject(lookupFld).get(fldOrParentFld));
            // else if the field is 2 levels down eg sObj.Opportunity.Account.mappingField
            } else if (split.size() == 3) {
                string lookupFld = split[0];
                string lookupFld2 = split[1];
                string fldOrParentFld = split[2];
                if (sObj.getSObject(lookupFld) != null && sObj.getSObject(lookupFld).getSObject(lookupFld2) != null)
                    result = string.valueOf(sObj.getSObject(lookupFld).getSObject(lookupFld2).get(fldOrParentFld));
            } else if (split.size() == 4) {
                string lookupFld = split[0];
                string lookupFld2 = split[1];
                string lookupFld3 = split[2];
                string fldOrParentFld = split[3];
                if (sObj.getSObject(lookupFld) != null && sObj.getSObject(lookupFld).getSObject(lookupFld2) != null && sObj.getSObject(lookupFld).getSObject(lookupFld2).getSObject(lookupFld3) != null)
                    result = string.valueOf(sObj.getSObject(lookupFld).getSObject(lookupFld2).getSObject(lookupFld3).get(fldOrParentFld));
            }
        }
        
        return result;
    }
    
    transient String TruncatedFieldsMessage;
    public Boolean PopulateRequest(VertexPendingRequest pendingRequest) {
        System.debug('-->Log 10 : VertexRequest PopulateRequest');
        Boolean requestPopulatedSuccessfully = true;
        setRequestFromTransaction(pendingRequest, requestPopulatedSuccessfully);
        List<SObject> childRecords = new List<SObject>();
        for(SObject child : pendingRequest.parent.getSObjects(VMap.ObjMap.ChildSObjectRelationshipName__c)){
            childRecords.add(child);
        }

        Map<String,Map<String,String>> overrideMap = VertexCore.fieldOverrideMap;
        //get child record object type
        String childObjectName = VertexCore.ObjectMappings.get(pendingRequest.mappingType).ChildSObject__c;

        Set<String> idSet = getIdSet(childRecords);

        List<SObject> newChildRecords = getNewChildRecords(overrideMap,idSet,childObjectName);

        childRecords.addAll(newChildRecords);
               

        addLineItems(pendingRequest,childRecords,requestPopulatedSuccessfully);

        if (String.isNotBlank(TruncatedFieldsMessage)) {
            VertexLogging.Log('Error', TruncatedFieldsMessage);
            VertexLogging.CommitDelayed();
        }

        return requestPopulatedSuccessfully;
    }

    //attributes class is required to build an Sobject from a json string
    //type holds the api name of the sobject i.e. Account
    public class Attributes{
        public String type;
    }

    @testVisible
    private List<SObject> getNewChildRecords(Map<String,Map<String,String>> overrideMap,Set<String> idSet,String childObjectName){
        List<Map<String,String>> fieldMapList = new List<Map<String,String>>();
        for(String key : overrideMap.keySet()){
            //skip if the key exists in the current set of child records
            
            if(!idSet.contains(key)){
                //from the map of override fields create a map from string to object
                //this is needed for more easily creating the json string when building the child record
                Map<String,String> fieldMap = overrideMap.get(key);
                fieldMapList.add(fieldMap);
            }
        }

        String fieldMapSerializedList = JSON.serialize(fieldMapList);
        List<Object> jsonList = (List<Object>) JSON.deserializeUntyped(fieldMapSerializedList);

        List<Map<String,Object>> jsonMapList = new List<Map<String,Object>>();
        for(Object o : jsonList){
            jsonMapList.add( (Map<String,Object>)o);
        }
        
        for(Map<String,Object> jsonMap : jsonMapList){
            Attributes attributes = new Attributes();
            attributes.type = childObjectName;
            jsonMap.put('attributes',attributes);
        }
        //attributes property is required for building an sObject
        String serializedChildRecords = JSON.serialize(jsonMapList);
        List<Sobject> newChildRecords = (List<SObject>) JSON.deserialize(serializedChildRecords,List<SObject>.class);
        return newChildREcords;
    }

    //for a list of records, build a set of all ids
    //will be used to determine if the id has already been processed by an update
    //if it was part of an update, we don't want to add it again to the list of new child records
    private Set<String> getIdSet(List<SObject> childRecords){
        Set<String> idSet = new Set<String>();
        for(SObject childRecord : childRecords){
            String idString = (String) childRecord.get('Id');
            idSet.add(idString);
        }

        return idSet;
    }



    public void setRequestFromTransaction(VertexPendingRequest pendingRequest, Boolean requestPopulatedSuccessfully){
        requestPopulatedSuccessfully = true;
        TruncatedFieldsMessage = '';

        //  Populate Parent Details (Vanilla = Opportunity)
        pendingRequest.RequestStructure.VertexEnvelope.Request.TransactionType = VMap.ObjMap.TransactionType__c;

        VertexAddress__c adminOrigin = VertexCore.AdministrativeOriginAddress(VMap.ObjMap.Name);
        if (adminOrigin.Name != 'Administrative Origin Address' && 
            String.isNotBlank(ApplyMapping(pendingRequest.parent, adminOrigin.Address1__c)) && 
        	String.isNotBlank(ApplyMapping(pendingRequest.parent, adminOrigin.City__c)) && 
            String.isNotBlank(ApplyMapping(pendingRequest.parent, adminOrigin.Country__c))){
            //This is NOT for DML. It is to assist with XML request creation.
            adminOrigin.Address1__c = ApplyMapping(pendingRequest.parent, adminOrigin.Address1__c);
            adminOrigin.Address2__c = ApplyMapping(pendingRequest.parent, adminOrigin.Address2__c);
            adminOrigin.City__c = ApplyMapping(pendingRequest.parent, adminOrigin.City__c);
            adminOrigin.State__c = ApplyMapping(pendingRequest.parent, adminOrigin.State__c);
            adminOrigin.PostalCode__c = ApplyMapping(pendingRequest.parent, adminOrigin.PostalCode__c);
            adminOrigin.Country__c = ApplyMapping(pendingRequest.parent, adminOrigin.Country__c);
            adminOrigin.LocationCode__c = ApplyMapping(pendingRequest.parent, adminOrigin.LocationCode__c);
            adminOrigin.TaxAreaID__c = ApplyMapping(pendingRequest.parent, adminOrigin.TaxAreaID__c);
		}
        
        //  Populate Parent Seller AdministrativeOrigin (billing from - can be overridden at line item level) - Always Custom Setting
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.StreetAddress1 = TruncateField('Seller Administrative Origin Street Address 1', adminOrigin.Address1__c, 100);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.StreetAddress2 = TruncateField('Seller Administrative Origin Street Address 2', adminOrigin.Address2__c, 100);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.City = TruncateField('Seller Administrative Origin City', adminOrigin.City__c, 60);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.MainDivision = TruncateField('Seller Administrative Origin State (MainDivision)', adminOrigin.State__c, 60);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.PostalCode = TruncateField('Seller Administrative Origin Postal Code', adminOrigin.PostalCode__c, 20);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.Country = TruncateField('Seller Administrative Origin Country', adminOrigin.Country__c, 60);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.LocationCode = TruncateField('Seller Administrative Origin Location Code', adminOrigin.LocationCode__c, 20);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.TaxAreaId = adminOrigin.TaxAreaID__c;

        //  Preset override if necessary
        String tmpPicklistValue = ApplyMapping(pendingRequest.parent, VMap.ObjMap.ParentSourcePicklist__c);
        if (String.isNotBlank(tmpPicklistValue))
            VertexCore.PhysicalOriginOverrideParent = tmpPicklistValue;
        
        VertexAddress__c physOrigin = VertexCore.ParentPhysicalOriginAddress(VMap.ObjMap.Name);
        if (physOrigin.Name == VMap.ObjMap.Name + ' Trans Phys' &&
           	String.isNotBlank(ApplyMapping(pendingRequest.parent, physOrigin.Address1__c)) && 
        	String.isNotBlank(ApplyMapping(pendingRequest.parent, physOrigin.City__c)) && 
            String.isNotBlank(ApplyMapping(pendingRequest.parent, physOrigin.Country__c))){
            //This is NOT for DML. It is to assist with XML request creation.
            physOrigin.Address1__c = ApplyMapping(pendingRequest.parent, physOrigin.Address1__c);
            physOrigin.Address2__c = ApplyMapping(pendingRequest.parent, physOrigin.Address2__c);
            physOrigin.City__c = ApplyMapping(pendingRequest.parent, physOrigin.City__c);
            physOrigin.State__c = ApplyMapping(pendingRequest.parent, physOrigin.State__c);
            physOrigin.PostalCode__c = ApplyMapping(pendingRequest.parent, physOrigin.PostalCode__c);
            physOrigin.Country__c = ApplyMapping(pendingRequest.parent, physOrigin.Country__c);
            physOrigin.LocationCode__c = ApplyMapping(pendingRequest.parent, physOrigin.LocationCode__c);
            physOrigin.TaxAreaID__c = ApplyMapping(pendingRequest.parent, physOrigin.TaxAreaID__c);
        }

        //  Populate Parent Seller.PhysicalOrigin (shipping from - can be overridden at line item level) - Assume default; can be driven from target object's picklist
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.StreetAddress1 = TruncateField('Seller Physical Origin Street Address 1', physOrigin.Address1__c, 100);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.StreetAddress2 = TruncateField('Seller Physical Origin Street Address 2', physOrigin.Address2__c, 100);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.City = TruncateField('Seller Physical Origin City', physOrigin.City__c, 60);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.MainDivision = TruncateField('Seller Physical Origin State (MainDivision)', physOrigin.State__c, 60);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.PostalCode = TruncateField('Seller Physical Origin Postal Code', physOrigin.PostalCode__c, 20);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.Country = TruncateField('Seller Physical Origin Country', physOrigin.Country__c, 60);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.LocationCode = TruncateField('Seller Physical Origin Location Code', physOrigin.LocationCode__c, 20);
        pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.TaxAreaId = physOrigin.TaxAreaID__c;

        //  Populate Customer TaxRegistration
        pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.TaxRegistration.TaxRegistrationNumber = TruncateField('Tax Registration Number from mapping ' + VMap.ObjMap.Name, ApplyMapping(pendingRequest.parent, VMap.ObjMap.TaxRegistrationNumber__c), 40);
        if (ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.Country__c)!=null){
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.TaxRegistration.IsoCountryCode = GetCountryIsoCodes().get(ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.Country__c).toLowerCase());
            if (pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.TaxRegistration.IsoCountryCode==null)
                VertexLogging.Log('Error','Unable to identify ISOCountryCode for '+ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.Country__c));
        }

        if (!VertexCore.IsBillingInstalled) {
            //  Parent.Customer.DestParentFieldMap.Address1__c
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress1  = TruncateField('Street Address 1 field from mapping ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.Address1__c), 100);
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress2  = TruncateField('Street Address 2 field from mapping ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.Address2__c), 100);
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.City            = TruncateField('City field from mapping ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.City__c), 60);
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.MainDivision    = TruncateField('State field from mapping ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.State__c), 60);
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.PostalCode      = TruncateField('Postal Code field from mapping ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.PostalCode__c), 20);
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.Country         = TruncateField('Country field from mapping ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.Country__c), 60);
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.TaxAreaId               = ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.TaxAreaID__c);
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.LocationCode            = TruncateField('Location Code field from mapping ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.LocationCode__c), 20);

            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.CurrencyConversion.CurrencyCodeAlpha = TruncateField('Currency Code from mapping ' + VMap.ObjMap.Name, ApplyMapping(pendingRequest.parent, VMap.ObjMap.CurrencyCode__c), 3);
        }
        
        // - still need to add...
        //  Parent TaxOverride
        if (String.isNotBlank(VMap.ObjMap.TransactionDate__c)) {
            try {
                Datetime tempDate = Datetime.valueOf(ApplyMapping(pendingRequest.parent, VMap.ObjMap.TransactionDate__c));
                pendingRequest.RequestStructure.VertexEnvelope.Request.DocumentDate = tempDate.format('yyyy-MM-dd');
            } catch (Exception e) {
                VertexLogging.Log('Error', 'Mapping for transaction date did not contain a valid date value');
                requestPopulatedSuccessfully = false;
            }
        }
        if (String.isNotBlank(VMap.ObjMap.Posting_Date__c)) {
            try {
                Datetime tempDate = Datetime.valueOf(ApplyMapping(pendingRequest.parent, VMap.ObjMap.Posting_Date__c));
                pendingRequest.RequestStructure.VertexEnvelope.Request.PostingDate = tempDate.format('yyyy-MM-dd');
            } catch (Exception e) {
                VertexLogging.Log('Error', 'Mapping for posting date did not contain a valid date value');
                requestPopulatedSuccessfully = false;
            }
        }
        if (String.isNotBlank(VMap.ObjMap.TransactionNumber__c))
            pendingRequest.RequestStructure.VertexEnvelope.Request.DocumentNumber = TruncateField('Transaction Document Number', ApplyMapping(pendingRequest.parent, VMap.ObjMap.TransactionNumber__c), 50);
        if (String.isNotBlank(VMap.ObjMap.TransactionDeliveryTerm__c))
            pendingRequest.RequestStructure.VertexEnvelope.Request.DeliveryTerm = TruncateField('Transaction Delivery Term from mapping ' + VMap.ObjMap.Name, ApplyMapping(pendingRequest.parent, VMap.ObjMap.TransactionDeliveryTerm__c), 3);
        if (String.isNotBlank(VMap.ObjMap.CurrencyCode__c))
            pendingRequest.RequestStructure.VertexEnvelope.Request.CurrencyCodeAlpha = TruncateField('Currency Code from mapping ' + VMap.ObjMap.Name, ApplyMapping(pendingRequest.parent, VMap.ObjMap.CurrencyCode__c), 3);
        if (String.isNotBlank(VMap.ObjMap.TransactionTaxPayer__c))
            pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.Company = TruncateField('Transaction Tax Payer', ApplyMapping(pendingRequest.parent, VMap.ObjMap.TransactionTaxPayer__c), 40);
        if (String.isBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.Company))
            pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.Company = TruncateField('Seller Company', VertexCore.CompanyName(), 40);
        if (String.isNotBlank(VMap.ParentFieldMap.CustomerCode__c))
           pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerCode = ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.CustomerCode__c);
        if (String.isNotBlank(VMap.ParentFieldMap.CustomerClassCode__c))
            pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerClassCode = TruncateField('Customer Class Code from ' + VMap.ParentFieldMap.Name, ApplyMapping(pendingRequest.parent, VMap.ParentFieldMap.CustomerClassCode__c), 40);
    }

    //add to pending request the structure of the line items
    public void addLineItems(VertexPendingRequest pendingRequest, List<Sobject> lineItemRecords, Boolean requestPopulatedSuccessfully){

        list<VertexStructureRequest.RequestLineItem> lineItems = new list<VertexStructureRequest.RequestLineItem>();
        
        //  Dig into children
        integer i = 1;
        if(lineItemRecords == null){
            lineItemRecords = new List<SObject>();
        }
        for (sObject sObj : lineItemRecords) {
            //  Handling for Children
            //    Note 1:  Customer.AdminDest and Seller.AdminOrigin not going to be overridable in app per Vertex (5/2/2017)
            //    Note 2:  Customer.Dest is mappable
            //   Note 3:  Seller.PhyOrigin is per picklist field mapping/custom setting lookup
            
            VertexStructureRequest.RequestLineItem lineItem = createLineItem(sObj, i, requestPopulatedSuccessfully);
            //  Add LI to list
            pendingRequest.RequestStructure.VertexEnvelope.Request.LineItems.add(lineItem);
            
            //  Review record's taxable/not taxable field and populate TaxOverride.OverrideType = TAXABLE or NONTAXABLE
            //lineItem.TaxOverride = 
            
            //  Increment for next LI (li number is just incremented for now)
            i++;
        }
    }

    public VertexStructureRequest.RequestLineItem createLineItem(SObject sObj, Integer i, boolean requestPopulatedSuccessfully){
        VertexStructureRequest.RequestLineItem lineItem = new VertexStructureRequest.RequestLineItem();
            
        //  Set LI level values
        lineItem.LineItemNumber = i;

        if(String.isNotBlank(VMap.ObjMap.TaxIncludedIndicator__c)){
            lineItem.taxIncludedIndicator = (boolean) sObj.get(VMap.ObjMap.TaxIncludedIndicator__c);
        }

        if(String.isNotBlank(VMap.ObjMap.UsageCode__c)){
            lineItem.usageCode = (String) sObj.get(VMap.ObjMap.UsageCode__c);
        }

        if(String.isNotBlank(VMap.ObjMap.UsageClass__c)){
            lineItem.usageClass = (String) sObj.get(VMap.ObjMap.UsageClass__c);
        }
        
        //  Set Delivery Term 
        if (String.isNotBlank(VMap.ObjMap.LineDeliveryTerm__c))
            lineItem.DeliveryTerm = TruncateField('Line Delivery Term from mapping ' + VMap.ObjMap.Name, ApplyMapping(sObj, VMap.ObjMap.LineDeliveryTerm__c), 3);
        
        //  Line item base field preps
        lineItem.LineItemId = (string)sObj.get('Id');
        if(String.isNotBlank(VMap.ObjMap.ItemNameField__c))
            lineItem.Product.ProductCode = (string)sObj.get(VMap.ObjMap.ItemNameField__c);
        if (String.isNotBlank(VMap.ObjMap.ItemTaxPayerField__c))
            lineItem.Seller.Company       = (string)sObj.get(VMap.ObjMap.ItemTaxPayerField__c);
        if(String.isNotBlank(VMap.ObjMap.ItemClassField__c))
            LineItem.Product.ProductClass = TruncateField('Product Class ', (string)sObj.get(VMap.ObjMap.ItemClassField__c), 40);
        if (VMap.ObjMap.ItemQuantityField__c != null)
            lineItem.Quantity = (decimal)sObj.get(VMap.ObjMap.ItemQuantityField__c);
        else {
            // if no mapping is specified default quantity to 1
            lineItem.Quantity = 1;
        }

        //Set LI Commodity Code
        if (String.isNotBlank(VMap.ObjMap.CommodityCode__c))
            lineItem.CommodityCode = TruncateField('Commodity Code', ApplyMapping(sObj, VMap.ObjMap.CommodityCode__c), 40);
        if(String.isNotBlank(VMap.ObjMap.CommodityCodeType__c))
            lineItem.CommodityCodeType = TruncateField('Commodity Code Type',ApplyMapping(sObj,VMap.ObjMap.CommodityCodeType__c),40);

        //lineItem.UnitPrice = (decimal)sObj.get(VMap.ObjMap.get('Unit Price').SourceField__c);
        if (VMap.ObjMap.ItemPriceField__c != null){
            if(VertexCore.NegativeCallout==true)
                lineItem.ExtendedPrice = 0 - (decimal)sObj.get(VMap.ObjMap.ItemPriceField__c);
            else
                lineItem.ExtendedPrice = (decimal)sObj.get(VMap.ObjMap.ItemPriceField__c);
        }
        else {
            VertexLogging.Log('Error', 'Mapping for Item Price missing from "' + VMap.ObjMap.Name + '"');
            requestPopulatedSuccessfully = false;	        	
        }

        //Set InputTotalTax (if request is DistributeTax)
        if (String.isNotBlank(VMap.ObjMap.InputTotalTax__c) && RequestType == 'DistributeTax')
            lineItem.InputTotalTax = (Decimal)sObj.get(VMap.ObjMap.InputTotalTax__c);

        //Get the Line level Flex Fields
        if (VMap.LineFlexFldMaps != null){
            lineItem.FlexibleFields.FlexibleCodeFields = new List<VertexStructureRequest.FlexField>();
            lineItem.FlexibleFields.FlexibleNumericFields = new List<VertexStructureRequest.FlexField>();
            lineItem.FlexibleFields.FlexibleDateFields = new List<VertexStructureRequest.FlexField>();
            for (VertexFieldMapping__c fldMap : VMap.LineFlexFldMaps){
                VertexStructureRequest.FlexField flx = new VertexStructureRequest.FlexField();
                flx.FieldId = fldMap.Label__c.substringAfterLast(' ');    //The number at the end
                flx.FieldVal = sObj.get(fldMap.SourceField__c) != null ? String.valueOf(sObj.get(fldMap.SourceField__c)) : '';
                flx.FieldVal = TruncateField(fldMap.Label__c, flx.FieldVal, 40);
                if (fldMap.Label__c.contains('Text')){
                    lineItem.FlexibleFields.FlexibleCodeFields.add(flx);
                } else if (fldMap.Label__c.contains('Number')){
                    lineItem.FlexibleFields.FlexibleNumericFields.add(flx);
                } else if (fldMap.Label__c.contains('Date')){
                    if (sObj.get(fldMap.SourceField__c) != null){
                        //Overwrite the default value we assigned to FieldVal
                        Date d = (Date)sObj.get(fldMap.SourceField__c);
                        flx.FieldVal = DateTime.newInstance(d.year(), d.month(), d.day()).format('yyyy-MM-dd');
                    }
                    lineItem.FlexibleFields.FlexibleDateFields.add(flx);
                }
            }
        }
        
        VertexAddress__c linePhysOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Line Phys');
        if (linePhysOrigin != null && String.isNotBlank(linePhysOrigin.Address1__c) && String.isNotBlank(linePhysOrigin.City__c) && String.isNotBlank(linePhysOrigin.Country__c)){
            lineItem.Seller.PhysicalOrigin.Address.StreetAddress1 = TruncateField('Line Item Seller Physical Origin Street Address 1', ApplyMapping(sObj, linePhysOrigin.Address1__c), 100);
            lineItem.Seller.PhysicalOrigin.Address.StreetAddress2 = TruncateField('Line Item Seller Physical Origin Street Address 2', ApplyMapping(sObj, linePhysOrigin.Address2__c), 100);
            lineItem.Seller.PhysicalOrigin.Address.City           = TruncateField('Line Item Seller Physical Origin City', ApplyMapping(sObj, linePhysOrigin.City__c), 60);
            lineItem.Seller.PhysicalOrigin.Address.MainDivision   = TruncateField('Line Item Seller Physical Origin State (MainDivision)', ApplyMapping(sObj, linePhysOrigin.State__c), 60);
            lineItem.Seller.PhysicalOrigin.Address.PostalCode     = TruncateField('Line Item Seller Physical Origin Postal Code', ApplyMapping(sObj, linePhysOrigin.PostalCode__c), 20);
            lineItem.Seller.PhysicalOrigin.Address.Country        = TruncateField('Line Item Seller Physical Origin Country', ApplyMapping(sObj, linePhysOrigin.Country__c), 60);
            lineItem.Seller.PhysicalOrigin.LocationCode = TruncateField('Line Item Seller Physical Origin Location Code', ApplyMapping(sObj, linePhysOrigin.LocationCode__c), 20);
            lineItem.Seller.PhysicalOrigin.TaxAreaId = ApplyMapping(sObj, linePhysOrigin.TaxAreaID__c);
        } else if (String.isNotBlank(VMap.ObjMap.ChildSourcePicklist__c)) {
            //  Prep for Child.Seller.PhysOrigin Override if necessary
            string tmpPicklistValueChld = (string)sObj.get(VMap.ObjMap.ChildSourcePicklist__c);
            if (String.isNotBlank(tmpPicklistValueChld)) {
                VertexCore.PhysicalOriginOverrideChild = tmpPicklistValueChld;
                if (VertexCore.ChildPhysicalOriginAddress() != null) {
                    //  Child.Seller.PhysOrigin
                    lineItem.Seller.PhysicalOrigin.Address.StreetAddress1 = TruncateField('Line Item Seller Physical Origin Street Address 1', VertexCore.ChildPhysicalOriginAddress().Address1__c, 100);
                    lineItem.Seller.PhysicalOrigin.Address.StreetAddress2 = TruncateField('Line Item Seller Physical Origin Street Address 2', VertexCore.ChildPhysicalOriginAddress().Address2__c, 100);
                    lineItem.Seller.PhysicalOrigin.Address.City           = TruncateField('Line Item Seller Physical Origin City', VertexCore.ChildPhysicalOriginAddress().City__c, 60);
                    lineItem.Seller.PhysicalOrigin.Address.MainDivision   = TruncateField('Line Item Seller Physical Origin State (MainDivision)', VertexCore.ChildPhysicalOriginAddress().State__c, 60);
                    lineItem.Seller.PhysicalOrigin.Address.PostalCode     = TruncateField('Line Item Seller Physical Origin Postal Code', VertexCore.ChildPhysicalOriginAddress().PostalCode__c, 20);
                    lineItem.Seller.PhysicalOrigin.Address.Country        = TruncateField('Line Item Seller Physical Origin Country', VertexCore.ChildPhysicalOriginAddress().Country__c, 60);
                    lineItem.Seller.PhysicalOrigin.LocationCode = TruncateField('Line Item Seller Physical Origin Location Code', VertexCore.ChildPhysicalOriginAddress().LocationCode__c, 20);
                    lineItem.Seller.PhysicalOrigin.TaxAreaId = VertexCore.ChildPhysicalOriginAddress().TaxAreaID__c;
                }
            }
        }

        VertexAddress__c lineAdminOrigin = VertexAddress__c.getInstance(VMap.ObjMap.Name + ' Line Admin');
        if (lineAdminOrigin != null && String.isNotBlank(lineAdminOrigin.Address1__c) && String.isNotBlank(lineAdminOrigin.City__c) && String.isNotBlank(lineAdminOrigin.Country__c)){
            //Child.Seller.AdminOrigin
            lineItem.Seller.AdministrativeOrigin.Address.StreetAddress1 = TruncateField('Line Item Seller Administrative Origin Street Address 1', ApplyMapping(sObj, lineAdminOrigin.Address1__c), 100);
            lineItem.Seller.AdministrativeOrigin.Address.StreetAddress2 = TruncateField('Line Item Seller Administrative Origin Street Address 2', ApplyMapping(sObj, lineAdminOrigin.Address2__c), 100);
            lineItem.Seller.AdministrativeOrigin.Address.City           = TruncateField('Line Item Seller Administrative Origin City', ApplyMapping(sObj, lineAdminOrigin.City__c), 60);
            lineItem.Seller.AdministrativeOrigin.Address.MainDivision   = TruncateField('Line Item Seller Administrative Origin State (MainDivision)', ApplyMapping(sObj, lineAdminOrigin.State__c), 60);
            lineItem.Seller.AdministrativeOrigin.Address.PostalCode     = TruncateField('Line Item Seller Administrative Origin Postal Code', ApplyMapping(sObj, lineAdminOrigin.PostalCode__c), 20);
            lineItem.Seller.AdministrativeOrigin.Address.Country        = TruncateField('Line Item Seller Administrative Origin Country', ApplyMapping(sObj, lineAdminOrigin.Country__c), 60);
            lineItem.Seller.AdministrativeOrigin.LocationCode = TruncateField('Line Item Seller Administrative Origin Location Code', ApplyMapping(sObj, lineAdminOrigin.LocationCode__c), 20);
            lineItem.Seller.AdministrativeOrigin.TaxAreaId = ApplyMapping(sObj, lineAdminOrigin.TaxAreaID__c);
        }
        
        //  Child.Customer.Dest
        if (!VertexCore.LineDestinationOverrideMappings.isEmpty() && VertexCore.IsBillingInstalled) {
            lineItem.Customer.Destination.Address.StreetAddress1 = TruncateField('Street Address 1 field from Line Overrides', ApplyMapping(sObj, VertexCore.LineDestinationOverrideMappings.get('Address1')), 100);
            lineItem.Customer.Destination.Address.StreetAddress2 = TruncateField('Street Address 2 field from Line Overrides', ApplyMapping(sObj, VertexCore.LineDestinationOverrideMappings.get('Address2')), 100);
            lineItem.Customer.Destination.Address.City           = TruncateField('City field from Line Overrides', ApplyMapping(sObj, VertexCore.LineDestinationOverrideMappings.get('City')), 60);
            lineItem.Customer.Destination.Address.MainDivision   = TruncateField('State field from Line Overrides', ApplyMapping(sObj, VertexCore.LineDestinationOverrideMappings.get('State')), 60);
            lineItem.Customer.Destination.Address.PostalCode     = TruncateField('Postal Code field from Line Overrides', ApplyMapping(sObj, VertexCore.LineDestinationOverrideMappings.get('Postal')), 20);
            lineItem.Customer.Destination.Address.Country        = TruncateField('Country field from Line Overrides', ApplyMapping(sObj, VertexCore.LineDestinationOverrideMappings.get('Country')), 60);
        }
        if (String.isBlank(lineItem.Customer.Destination.Address.StreetAddress1) &&
            String.isBlank(lineItem.Customer.Destination.Address.StreetAddress2) &&
            String.isBlank(lineItem.Customer.Destination.Address.City) &&
            String.isBlank(lineItem.Customer.Destination.Address.MainDivision) &&
            String.isBlank(lineItem.Customer.Destination.Address.PostalCode) &&
            String.isBlank(lineItem.Customer.Destination.Address.Country)
            ){
            if (!VertexCore.BillingDestinationMappings.isEmpty() && VertexCore.IsBillingInstalled) {
                lineItem.Customer.Destination.Address.StreetAddress1 = TruncateField('Street Address 1 field from Billing Destinations', ApplyMapping(sObj, VertexCore.BillingDestinationMappings.get('Address1')), 100);
                lineItem.Customer.Destination.Address.StreetAddress2 = TruncateField('Street Address 2 field from Billing Destinations', ApplyMapping(sObj, VertexCore.BillingDestinationMappings.get('Address2')), 100);
                lineItem.Customer.Destination.Address.City           = TruncateField('City field from Billing Destinations', ApplyMapping(sObj, VertexCore.BillingDestinationMappings.get('City')), 60);
                lineItem.Customer.Destination.Address.MainDivision   = TruncateField('State field from Billing Destinations', ApplyMapping(sObj, VertexCore.BillingDestinationMappings.get('State')), 60);
                lineItem.Customer.Destination.Address.PostalCode     = TruncateField('Postal Code field from Billing Destinations', ApplyMapping(sObj, VertexCore.BillingDestinationMappings.get('Postal')), 20);
                lineItem.Customer.Destination.Address.Country        = TruncateField('Country field from Billing Destinations', ApplyMapping(sObj, VertexCore.BillingDestinationMappings.get('Country')), 60);
            } else {
                lineItem.Customer.Destination.Address.StreetAddress1  = TruncateField('Street Address 1 field from mapping ' + VMap.ChildFieldMap.Name, ApplyMapping(sObj, VMap.ChildFieldMap.Address1__c), 100);
                lineItem.Customer.Destination.Address.StreetAddress2  = TruncateField('Street Address 2 field from mapping ' + VMap.ChildFieldMap.Name, ApplyMapping(sObj, VMap.ChildFieldMap.Address2__c), 100);
                lineItem.Customer.Destination.Address.City            = TruncateField('City field from mapping ' + VMap.ChildFieldMap.Name, ApplyMapping(sObj, VMap.ChildFieldMap.City__c), 60);
                lineItem.Customer.Destination.Address.MainDivision    = TruncateField('State field from mapping ' + VMap.ChildFieldMap.Name, ApplyMapping(sObj, VMap.ChildFieldMap.State__c), 60);
                lineItem.Customer.Destination.Address.PostalCode      = TruncateField('Postal Code field from mapping ' + VMap.ChildFieldMap.Name, ApplyMapping(sObj, VMap.ChildFieldMap.PostalCode__c), 20);
                lineItem.Customer.Destination.Address.Country         = TruncateField('Country field from mapping ' + VMap.ChildFieldMap.Name, ApplyMapping(sObj, VMap.ChildFieldMap.Country__c), 60);
                lineItem.Customer.Destination.TaxAreaID               = ApplyMapping(sObj, VMap.ChildFieldMap.TaxAreaID__c);
                lineItem.Customer.Destination.LocationCode            = TruncateField('Location Code field from mapping ' + VMap.ChildFieldMap.Name, ApplyMapping(sObj, VMap.ChildFieldMap.LocationCode__c), 20);
            }
        }
        
        if (String.isNotBlank(VMap.ChildFieldMap.CustomerCode__c))
            lineItem.Customer.CustomerCode.CustomerCode = ApplyMapping(sObj, VMap.ChildFieldMap.CustomerCode__c);
        if (String.isNotBlank(VMap.ChildFieldMap.CustomerClassCode__c))
            lineItem.Customer.CustomerCode.CustomerClassCode = ApplyMapping(sObj, VMap.ChildFieldMap.CustomerClassCode__c);
        return lineItem;
    }
    
    public String TruncateField(String fieldName, String fieldValue, Integer maxRange) {
        if (String.isNotBlank(fieldValue) && fieldValue.length() > maxRange) {
            fieldValue = fieldValue.left(maxRange);
            TruncatedFieldsMessage += fieldName + ' was truncated to meet the API range limit of ' +  maxRange + ' characters| ';
        }
        return fieldValue;
    }

    //  Based on the wrapper object in this class, go through and create necessary XML body/payload for RequestStructure
    public Boolean GenerateXMLBody(VertexPendingRequest pendingRequest) {
        System.debug('-->Log 11 : VertexRequest GenerateXMLBody');
        transient Boolean xmlBodyCreatedSuccessfuly = true;

        //  Property for new DOM doc to help in generation of appropriate request XML
        DOM.Document doc = GenerateBaseXMLBody(pendingRequest);
        DOM.XmlNode requestNode = doc.getRootElement().getChildElement('soapenv:Body', null).getChildElement('urn:VertexEnvelope', null).getChildElement('urn:' + RequestType + 'Request', null);
        if (RequestType == 'DistributeTax') {
            if (TaxOnly != null)
                requestNode.setAttribute('isTaxOnlyAdjustmentIndicator', String.valueOf(TaxOnly));
            if (PostToJournal != null)
                requestNode.setAttribute('postToJournal', String.valueOf(PostToJournal));
        }
        
        DOM.XmlNode currencyNode = requestNode.addChildElement('urn:Currency',null,null);
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.CurrencyCodeAlpha))
            currencyNode.setAttribute('isoCurrencyCodeAlpha', pendingRequest.RequestStructure.VertexEnvelope.Request.CurrencyCodeAlpha);

        //  Seller Set
        DOM.XmlNode sellerNode = requestNode.addChildElement('urn:Seller',null,null);
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.Company))
            sellerNode.addChildElement('urn:Company',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.Company);
                
        //  Seller.PhysicalOrigin
        DOM.XmlNode physicalOriginNode = sellerNode.addChildElement('urn:PhysicalOrigin',null,null);
        
        //Use Location Code if we have it
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.LocationCode)){
            physicalOriginNode.setAttribute('locationCode', pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.LocationCode);
        }
        //If not, use Tax Area ID
        else if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.TaxAreaID)){
            physicalOriginNode.setAttribute('taxAreaId', pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.TaxAreaID);
        }
        //Last resort is sending the full address
        else if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.StreetAddress1)
            && String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.City)
            && String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.Country)) {

            physicalOriginNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.StreetAddress1);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.StreetAddress2))
                physicalOriginNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.StreetAddress2);
            physicalOriginNode.addChildElement('urn:City',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.City);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.MainDivision))
                physicalOriginNode.addChildElement('urn:MainDivision',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.MainDivision);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.PostalCode))
                physicalOriginNode.addChildElement('urn:PostalCode',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.PostalCode);
            physicalOriginNode.addChildElement('urn:Country',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.PhysicalOrigin.Address.Country);
        } else  {
            VertexLogging.Log('Error', 'Address 1 (Street), City, and Country must all be populated on Vertex Address "' + VertexCore.ParentPhysicalOriginAddress(VMap.ObjMap.Name).Name + '" are empty');
            xmlBodyCreatedSuccessfuly = false;
        }
        
        //  Seller.AdministrativeOrigin
        DOM.XmlNode administrativeOriginNode = sellerNode.addChildElement('urn:AdministrativeOrigin',null,null);

        //Use Location Code if we have it
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.LocationCode)){
            administrativeOriginNode.setAttribute('locationCode', pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.LocationCode);
        }
        //If not, use Tax Area ID
        else if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.TaxAreaID)){
            administrativeOriginNode.setAttribute('taxAreaId', pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.TaxAreaID);
        }
        //Last resort is sending the full address
         else if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.StreetAddress1)
            && String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.City)
            && String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.Country)) {

            administrativeOriginNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.StreetAddress1);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.StreetAddress2))
                administrativeOriginNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.StreetAddress2);
            administrativeOriginNode.addChildElement('urn:City',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.City);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.MainDivision))
                administrativeOriginNode.addChildElement('urn:MainDivision',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.MainDivision);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.PostalCode))
                administrativeOriginNode.addChildElement('urn:PostalCode',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.PostalCode);
            administrativeOriginNode.addChildElement('urn:Country',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Seller.AdministrativeOrigin.Address.Country);
        } else {
            VertexLogging.Log('Error', 'Address 1 (Street), City, and Country must all be populated on Vertex Address "' + VertexCore.AdministrativeOriginAddress(VMap.ObjMap.Name).Name + '" are empty');
            xmlBodyCreatedSuccessfuly = false;
        }
        
        //  Customer
        DOM.XmlNode customerNode = requestNode.addChildElement('urn:Customer',null,null);
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerCode) || 
            String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerClassCode)){

            DOM.XmlNode customerCodeNode = customerNode.addChildElement('urn:CustomerCode',null,null);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerCode))
                customerCodeNode.addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerCode);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerClassCode))
                customerCodeNode.setAttribute('classCode', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.CustomerCode.CustomerClassCode);
        }

        // Customer.Destination Address
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress1) || 
            String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.TaxAreaId) || 
            String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.LocationCode)) {
            DOM.XmlNode destinationNode = customerNode.addChildElement('urn:Destination', null, null);
            DOM.XmlNode adminDestinationNode = customerNode.addChildElement('urn:AdministrativeDestination', null, null);

            //Use Location Code if we have it
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.LocationCode)){
                destinationNode.setAttribute('locationCode', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.LocationCode);
                adminDestinationNode.setAttribute('locationCode', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.LocationCode);
            }
            //Fallback option is Tax Area ID
            else if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.TaxAreaId)){
                destinationNode.setAttribute('taxAreaId', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.TaxAreaId);
                adminDestinationNode.setAttribute('taxAreaId', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.TaxAreaId);
            }
            //Last option is full address
            else if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress1) && 
                    String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.City) && 
                    String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.Country)) {
                destinationNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress1);
                adminDestinationNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress1);
                if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress2)){
                    destinationNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress2);
                    adminDestinationNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.StreetAddress2);
                }
                destinationNode.addChildElement('urn:City',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.City);
                adminDestinationNode.addChildElement('urn:City',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.City);
                if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.MainDivision)){
                    destinationNode.addChildElement('urn:MainDivision',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.MainDivision);
                    adminDestinationNode.addChildElement('urn:MainDivision',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.MainDivision);
                }
                if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.PostalCode)){
                    destinationNode.addChildElement('urn:PostalCode',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.PostalCode);
                    adminDestinationNode.addChildElement('urn:PostalCode',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.PostalCode);
                }
                if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.Country)){
                    destinationNode.addChildElement('urn:Country',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.Country);
                    adminDestinationNode.addChildElement('urn:Country',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.Address.Country);
                }
                
                if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.CurrencyConversion.CurrencyCodeAlpha)){
                    DOM.XmlNode destCurrencyNode = destinationNode.addChildElement('urn:CurrencyConversion',null,null);
                    destCurrencyNode.addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.CurrencyConversion.ConversionRate);
                    destCurrencyNode.setAttribute('isoCurrencyCodeAlpha', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.CurrencyConversion.CurrencyCodeAlpha);
                    
                    DOM.XmlNode adminDestCurrencyNode = adminDestinationNode.addChildElement('urn:CurrencyConversion',null,null);
                    adminDestCurrencyNode.addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.CurrencyConversion.ConversionRate);
                    adminDestCurrencyNode.setAttribute('isoCurrencyCodeAlpha', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.Destination.CurrencyConversion.CurrencyCodeAlpha);
                }
            }
        }

        //  Customer.TaxRegistration
        if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.TaxRegistration.TaxRegistrationNumber)){
            DOM.XmlNode taxRegistrationNode = customerNode.addChildElement('urn:TaxRegistration', null, null);
            if (String.isNotBlank(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.TaxRegistration.IsoCountryCode))
                taxRegistrationNode.setAttribute('isoCountryCode', pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.TaxRegistration.IsoCountryCode);
            taxRegistrationNode.setAttribute('impositionType', 'VAT');
            taxRegistrationNode.addChildElement('urn:TaxRegistrationNumber',null,null).addTextNode(pendingRequest.RequestStructure.VertexEnvelope.Request.Customer.TaxRegistration.TaxRegistrationNumber);
        }
                
        //  Line Item Set
        integer i = 1;
        for (VertexStructureRequest.RequestLineItem li :pendingRequest.RequestStructure.VertexEnvelope.Request.LineItems) {
            
            createChildNode(li,requestNode,i);
            i++;
        }
        
        pendingRequest.xmlBody = doc.toXmlString();
        return xmlBodyCreatedSuccessfuly;
    }

    public DOM.XMLNode createChildNode(VertexStructureRequest.RequestLineItem li, DOM.XmlNode requestNode, Integer i){
        DOM.XmlNode lineItemNode = requestNode.addChildElement('urn:LineItem',null,null);
        lineItemNode.setAttribute('lineItemNumber', string.valueOf(i));
        
        //  Line Item Product Id
        lineItemNode.setAttribute('lineItemId', string.valueOf(li.lineItemId));  // RecordId

        if(li.taxIncludedIndicator != null)
            lineItemNode.setAttribute('taxIncludedIndicator',string.valueOf(li.taxIncludedIndicator));

        //usage code
        if(String.isNotBlank(li.usageCode))
            lineItemNode.setAttribute('usage',li.usageCode);

        //usage class
        if(String.isNotBlank(li.usageClass)){
            lineItemNode.setAttribute('usageClass',li.usageClass);
        }

        //  Delivery Term
        if (String.isNotBlank(li.DeliveryTerm))
            lineItemNode.setAttribute('deliveryTerm', li.DeliveryTerm);
        
        // Physical Origin Address
        DOM.XmlNode liSellerNode = lineItemNode.addChildElement('urn:Seller', null, null);
        if (String.isNotBlank(li.Seller.Company))
            liSellerNode.addChildElement('urn:Company', null, null).addTextNode(li.Seller.Company);
        if (String.isNotBlank(li.Seller.PhysicalOrigin.Address.StreetAddress1) || String.isNotBlank(li.Seller.PhysicalOrigin.TaxAreaId) || String.isNotBlank(li.Seller.PhysicalOrigin.LocationCode)) {
            DOM.XmlNode liPhysicalOriginNode = liSellerNode.addChildElement('urn:PhysicalOrigin', null, null);

            //Use Location Code if we have it
            if (String.isNotBlank(li.Seller.PhysicalOrigin.LocationCode)){
                liPhysicalOriginNode.setAttribute('locationCode', li.Seller.PhysicalOrigin.LocationCode);
            }
            //Fallback option is Tax Area ID
            else if (String.isNotBlank(li.Seller.PhysicalOrigin.TaxAreaId)){
                liPhysicalOriginNode.setAttribute('taxAreaId', li.Seller.PhysicalOrigin.TaxAreaId);
            }
            //Last option is full address
            else if (String.isNotBlank(li.Seller.PhysicalOrigin.Address.StreetAddress1) && String.isNotBlank(li.Seller.PhysicalOrigin.Address.City) && String.isNotBlank(li.Seller.PhysicalOrigin.Address.Country)) {
                liPhysicalOriginNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(li.Seller.PhysicalOrigin.Address.StreetAddress1);
                if (String.isNotBlank(li.Seller.PhysicalOrigin.Address.StreetAddress2))
                    liPhysicalOriginNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(li.Seller.PhysicalOrigin.Address.StreetAddress2);
                liPhysicalOriginNode.addChildElement('urn:City',null,null).addTextNode(li.Seller.PhysicalOrigin.Address.City);
                if (String.isNotBlank(li.Seller.PhysicalOrigin.Address.MainDivision))
                    liPhysicalOriginNode.addChildElement('urn:MainDivision',null,null).addTextNode(li.Seller.PhysicalOrigin.Address.MainDivision);
                if (String.isNotBlank(li.Seller.PhysicalOrigin.Address.PostalCode))
                    liPhysicalOriginNode.addChildElement('urn:PostalCode',null,null).addTextNode(li.Seller.PhysicalOrigin.Address.PostalCode);
                liPhysicalOriginNode.addChildElement('urn:Country',null,null).addTextNode(li.Seller.PhysicalOrigin.Address.Country);
            }
        }

        // Administrative Origin Address
        if (String.isNotBlank(li.Seller.AdministrativeOrigin.Address.StreetAddress1) || String.isNotBlank(li.Seller.AdministrativeOrigin.TaxAreaId) || String.isNotBlank(li.Seller.AdministrativeOrigin.LocationCode)) {
            DOM.XmlNode liAdministrativeOriginNode = liSellerNode.addChildElement('urn:AdministrativeOrigin', null, null);

            //Use Location Code if we have it
            if (String.isNotBlank(li.Seller.AdministrativeOrigin.LocationCode)){
                liAdministrativeOriginNode.setAttribute('locationCode', li.Seller.AdministrativeOrigin.LocationCode);
            }
            //Fallback option is Tax Area ID
            else if (String.isNotBlank(li.Seller.AdministrativeOrigin.TaxAreaId)){
                liAdministrativeOriginNode.setAttribute('taxAreaId', li.Seller.AdministrativeOrigin.TaxAreaId);
            }
            //Last option is full address
            else if (String.isNotBlank(li.Seller.AdministrativeOrigin.Address.StreetAddress1) && String.isNotBlank(li.Seller.AdministrativeOrigin.Address.City) && String.isNotBlank(li.Seller.AdministrativeOrigin.Address.Country)) {
                liAdministrativeOriginNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(li.Seller.AdministrativeOrigin.Address.StreetAddress1);
                if (String.isNotBlank(li.Seller.AdministrativeOrigin.Address.StreetAddress2))
                    liAdministrativeOriginNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(li.Seller.AdministrativeOrigin.Address.StreetAddress2);
                liAdministrativeOriginNode.addChildElement('urn:City',null,null).addTextNode(li.Seller.AdministrativeOrigin.Address.City);
                if (String.isNotBlank(li.Seller.AdministrativeOrigin.Address.MainDivision))
                    liAdministrativeOriginNode.addChildElement('urn:MainDivision',null,null).addTextNode(li.Seller.AdministrativeOrigin.Address.MainDivision);
                if (String.isNotBlank(li.Seller.AdministrativeOrigin.Address.PostalCode))
                    liAdministrativeOriginNode.addChildElement('urn:PostalCode',null,null).addTextNode(li.Seller.AdministrativeOrigin.Address.PostalCode);
                liAdministrativeOriginNode.addChildElement('urn:Country',null,null).addTextNode(li.Seller.AdministrativeOrigin.Address.Country);
            }
        }

        DOM.XmlNode liCustomerNode = lineItemNode.addChildElement('urn:Customer', null, null);
        // Customer.CustomerCode
        if (String.isNotBlank(li.Customer.CustomerCode.CustomerCode) || String.isNotBlank(li.Customer.CustomerCode.CustomerClassCode)) {
            DOM.XmlNode liCustomerCodeNode = liCustomerNode.addChildElement('urn:CustomerCode', null, null);
            if (String.isNotBlank(li.Customer.CustomerCode.CustomerCode))
                liCustomerCodeNode.addTextNode(li.Customer.CustomerCode.CustomerCode);

            if (String.isNotBlank(li.Customer.CustomerCode.CustomerClassCode))
                liCustomerCodeNode.setAttribute('classCode', li.Customer.CustomerCode.CustomerClassCode);    
        }

        // Child.Customer.Destination Address
        if (String.isNotBlank(li.Customer.Destination.Address.StreetAddress1) || String.isNotBlank(li.Customer.Destination.TaxAreaId) || String.isNotBlank(li.Customer.Destination.LocationCode)) {
            DOM.XmlNode liDestinationNode = liCustomerNode.addChildElement('urn:Destination', null, null);

            //Use Location Code if we have it
            if (String.isNotBlank(li.Customer.Destination.LocationCode)){
                liDestinationNode.setAttribute('locationCode', li.Customer.Destination.LocationCode);
            }
            //Fallback option is Tax Area ID
            else if (String.isNotBlank(li.Customer.Destination.TaxAreaId)){
                liDestinationNode.setAttribute('taxAreaId', li.Customer.Destination.TaxAreaId);
            }
            //Last option is full address
            else if (String.isNotBlank(li.Customer.Destination.Address.StreetAddress1) && String.isNotBlank(li.Customer.Destination.Address.City) && String.isNotBlank(li.Customer.Destination.Address.Country)) {
                liDestinationNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(li.Customer.Destination.Address.StreetAddress1);
                if (String.isNotBlank(li.Customer.Destination.Address.StreetAddress2))
                    liDestinationNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(li.Customer.Destination.Address.StreetAddress2);
                liDestinationNode.addChildElement('urn:City',null,null).addTextNode(li.Customer.Destination.Address.City);
                if (String.isNotBlank(li.Customer.Destination.Address.MainDivision))
                    liDestinationNode.addChildElement('urn:MainDivision',null,null).addTextNode(li.Customer.Destination.Address.MainDivision);
                if (String.isNotBlank(li.Customer.Destination.Address.PostalCode))
                    liDestinationNode.addChildElement('urn:PostalCode',null,null).addTextNode(li.Customer.Destination.Address.PostalCode);
                liDestinationNode.addChildElement('urn:Country',null,null).addTextNode(li.Customer.Destination.Address.Country);
            }
        }

        //  Product.Name
        if (String.isNotBlank(li.Product.ProductCode) || String.isNotBlank(li.Product.ProductClass)){
            DOM.XmlNode productNode = lineItemNode.addChildElement('urn:Product',null,null);
            if (String.isNotBlank(li.Product.ProductCode))
                productNode.addTextNode(li.Product.ProductCode);  //  Name of product
            if (String.isNotBlank(li.Product.ProductClass))
                productNode.setAttribute('productClass', li.Product.ProductClass);  //  Class of product
        }
        
        //LineItem.CommodityCode
        if (String.isNotBlank(li.CommodityCode)){
            DOM.XmlNode commodityCodeNode = lineItemNode.addChildElement('urn:CommodityCode',null,null);
            if(String.isNotBlank(li.CommodityCodeType))    
                commodityCodeNode.setAttribute('commodityCodeType', li.CommodityCodeType);
            commodityCodeNode.addTextNode(li.CommodityCode);
        }
        
        // LineItem.Quantity
        if (li.Quantity != null)
            lineItemNode.addChildElement('urn:Quantity',null,null).addTextNode(string.valueOf(li.Quantity)); //  Quantity

        //  LineItem.ExtendedPrice
        if (li.ExtendedPrice != null)
            lineItemNode.addChildElement('urn:ExtendedPrice',null,null).addTextNode(string.valueOf(li.ExtendedPrice)); //  Quantity * Unit

        //  LineItem.InputTotalTax (if DistributeTax)
        if (li.InputTotalTax != null && RequestType == 'DistributeTax')
            lineItemNode.addChildElement('urn:InputTotalTax',null,null).addTextNode(string.valueOf(li.InputTotalTax));

        //Flex Fields (Code, Numeric, and Date)
        DOM.XmlNode liFlexGroupNode = lineItemNode.addChildElement('urn:FlexibleFields', null, null);
        if (li.FlexibleFields.FlexibleCodeFields != null){
            for (VertexStructureRequest.FlexField ff : li.FlexibleFields.FlexibleCodeFields) {
                DOM.XmlNode liFlexCodeFieldNode = liFlexGroupNode.addChildElement('urn:FlexibleCodeField', null, null);
                liFlexCodeFieldNode.addTextNode(ff.FieldVal);
                liFlexCodeFieldNode.setAttribute('fieldId', ff.FieldId);
            }
        }
        if (li.FlexibleFields.FlexibleNumericFields != null){
            for (VertexStructureRequest.FlexField ff : li.FlexibleFields.FlexibleNumericFields) {
                DOM.XmlNode liFlexNumericFieldNode = liFlexGroupNode.addChildElement('urn:FlexibleNumericField', null, null);
                liFlexNumericFieldNode.addTextNode(ff.FieldVal);
                liFlexNumericFieldNode.setAttribute('fieldId', ff.FieldId);
            }
        }
        if (li.FlexibleFields.FlexibleDateFields != null){
            for (VertexStructureRequest.FlexField ff : li.FlexibleFields.FlexibleDateFields) {
                DOM.XmlNode liFlexDateFieldNode = liFlexGroupNode.addChildElement('urn:FlexibleDateField', null, null);
                liFlexDateFieldNode.addTextNode(ff.FieldVal);
                liFlexDateFieldNode.setAttribute('fieldId', ff.FieldId);
            }
        }

        return lineItemNode;
    }

    private Map<String, String> CountryIsoCodes;
    public Map<String, String> GetCountryIsoCodes(){
        if (CountryIsoCodes == null){
            CountryIsoCodes = new Map<String, String>();   //Some keys will look up to the same value (i.e. Great Britain and United Kingdom)
            CountryIsoCodes.put('afghanistan', 'AFG');
            CountryIsoCodes.put('aland islands', 'ALA');
            CountryIsoCodes.put('albania', 'ALB');
            CountryIsoCodes.put('algeria', 'DZA');
            CountryIsoCodes.put('american samoa', 'ASM');
            CountryIsoCodes.put('andorra', 'AND');
            CountryIsoCodes.put('angola', 'AGO');
            CountryIsoCodes.put('anguilla', 'AIA');
            CountryIsoCodes.put('antarctica', 'ATA');
            CountryIsoCodes.put('antigua and barbuda', 'ATG');
            CountryIsoCodes.put('argentina', 'ARG');
            CountryIsoCodes.put('armenia', 'ARM');
            CountryIsoCodes.put('aruba', 'ABW');
            CountryIsoCodes.put('australia', 'AUS');
            CountryIsoCodes.put('austria', 'AUT');
            CountryIsoCodes.put('azerbaijan', 'AZE');
            CountryIsoCodes.put('bahamas', 'BHS');
            CountryIsoCodes.put('bahrain', 'BHR');
            CountryIsoCodes.put('bangladesh', 'BGD');
            CountryIsoCodes.put('barbados', 'BRB');
            CountryIsoCodes.put('belarus', 'BLR');
            CountryIsoCodes.put('belgium', 'BEL');
            CountryIsoCodes.put('belize', 'BLZ');
            CountryIsoCodes.put('benin', 'BEN');
            CountryIsoCodes.put('bermuda', 'BMU');
            CountryIsoCodes.put('bhutan', 'BTN');
            CountryIsoCodes.put('bolivia', 'BOL');
            CountryIsoCodes.put('bosnia and herzegovina', 'BIH');
            CountryIsoCodes.put('botswana', 'BWA');
            CountryIsoCodes.put('bouvet island', 'BVT');
            CountryIsoCodes.put('brazil', 'BRA');
            CountryIsoCodes.put('british virgin islands', 'VGB');
            CountryIsoCodes.put('british indian ocean territory', 'IOT');
            CountryIsoCodes.put('brunei darussalam', 'BRN');
            CountryIsoCodes.put('bulgaria', 'BGR');
            CountryIsoCodes.put('burkina faso', 'BFA');
            CountryIsoCodes.put('burundi', 'BDI');
            CountryIsoCodes.put('cambodia', 'KHM');
            CountryIsoCodes.put('cameroon', 'CMR');
            CountryIsoCodes.put('canada', 'CAN');
            CountryIsoCodes.put('cape verde', 'CPV');
            CountryIsoCodes.put('cayman islands', 'CYM');
            CountryIsoCodes.put('central african republic', 'CAF');
            CountryIsoCodes.put('ceuta', 'VX7');
            CountryIsoCodes.put('chad', 'TCD');
            CountryIsoCodes.put('chile', 'CHL');
            CountryIsoCodes.put('china', 'CHN');
            CountryIsoCodes.put('hong kong, sar china', 'HKG');
            CountryIsoCodes.put('macao, sar china', 'MAC');
            CountryIsoCodes.put('christmas island', 'CXR');
            CountryIsoCodes.put('cocos (keeling) islands', 'CCK');
            CountryIsoCodes.put('colombia', 'COL');
            CountryIsoCodes.put('comoros', 'COM');
            CountryIsoCodes.put('congo (brazzaville)', 'COG');
            CountryIsoCodes.put('congo, (kinshasa)', 'COD');
            CountryIsoCodes.put('cook islands', 'COK');
            CountryIsoCodes.put('costa rica', 'CRI');
            CountryIsoCodes.put('côte d’ivoire', 'CIV');
            CountryIsoCodes.put('croatia', 'HRV');
            CountryIsoCodes.put('cuba', 'CUB');
            CountryIsoCodes.put('curaçao', 'CUW');
            CountryIsoCodes.put('cyprus', 'CYP');
            CountryIsoCodes.put('czech republic', 'CZE');
            CountryIsoCodes.put('denmark', 'DNK');
            CountryIsoCodes.put('deutschland', 'DEU');
            CountryIsoCodes.put('djibouti', 'DJI');
            CountryIsoCodes.put('dominica', 'DMA');
            CountryIsoCodes.put('dominican republic', 'DOM');
            CountryIsoCodes.put('ecuador', 'ECU');
            CountryIsoCodes.put('egypt', 'EGY');
            CountryIsoCodes.put('el salvador', 'SLV');
            CountryIsoCodes.put('equatorial guinea', 'GNQ');
            CountryIsoCodes.put('eritrea', 'ERI');
            CountryIsoCodes.put('españa', 'ESP');
            CountryIsoCodes.put('estonia', 'EST');
            CountryIsoCodes.put('ethiopia', 'ETH');
            CountryIsoCodes.put('falkland islands (malvinas)', 'FLK');
            CountryIsoCodes.put('faroe islands', 'FRO');
            CountryIsoCodes.put('fiji', 'FJI');
            CountryIsoCodes.put('finland', 'FIN');
            CountryIsoCodes.put('france', 'FRA');
            CountryIsoCodes.put('french guiana', 'GUF');
            CountryIsoCodes.put('french polynesia', 'PYF');
            CountryIsoCodes.put('french southern territories', 'ATF');
            CountryIsoCodes.put('gabon', 'GAB');
            CountryIsoCodes.put('gambia', 'GMB');
            CountryIsoCodes.put('georgia', 'GEO');
            CountryIsoCodes.put('germany', 'DEU');
            CountryIsoCodes.put('ghana', 'GHA');
            CountryIsoCodes.put('gibraltar', 'GIB');
            CountryIsoCodes.put('great britain', 'GBR');
            CountryIsoCodes.put('greece', 'GRC');
            CountryIsoCodes.put('greenland', 'GRL');
            CountryIsoCodes.put('grenada', 'GRD');
            CountryIsoCodes.put('guadeloupe', 'GLP');
            CountryIsoCodes.put('guam', 'GUM');
            CountryIsoCodes.put('guatemala', 'GTM');
            CountryIsoCodes.put('guernsey', 'GGY');
            CountryIsoCodes.put('guinea', 'GIN');
            CountryIsoCodes.put('guinea-bissau', 'GNB');
            CountryIsoCodes.put('guyana', 'GUY');
            CountryIsoCodes.put('haiti', 'HTI');
            CountryIsoCodes.put('heard and mcdonald islands', 'HMD');
            CountryIsoCodes.put('holy see (vatican city state)', 'VAT');
            CountryIsoCodes.put('honduras', 'HND');
            CountryIsoCodes.put('hungary', 'HUN');
            CountryIsoCodes.put('iceland', 'ISL');
            CountryIsoCodes.put('india', 'IND');
            CountryIsoCodes.put('indonesia', 'IDN');
            CountryIsoCodes.put('iran, islamic republic of', 'IRN');
            CountryIsoCodes.put('iraq', 'IRQ');
            CountryIsoCodes.put('ireland', 'IRL');
            CountryIsoCodes.put('isle of man', 'IMN');
            CountryIsoCodes.put('israel', 'ISR');
            CountryIsoCodes.put('italy', 'ITA');
            CountryIsoCodes.put('ivory coast', 'CIV');
            CountryIsoCodes.put('jamaica', 'JAM');
            CountryIsoCodes.put('japan', 'JPN');
            CountryIsoCodes.put('jersey', 'JEY');
            CountryIsoCodes.put('jordan', 'JOR');
            CountryIsoCodes.put('kazakhstan', 'KAZ');
            CountryIsoCodes.put('kenya', 'KEN');
            CountryIsoCodes.put('kiribati', 'KIR');
            CountryIsoCodes.put('korea (north)', 'PRK');
            CountryIsoCodes.put('korea (south)', 'KOR');
            CountryIsoCodes.put('kuwait', 'KWT');
            CountryIsoCodes.put('kyrgyzstan', 'KGZ');
            CountryIsoCodes.put('lao pdr', 'LAO');
            CountryIsoCodes.put('latvia', 'LVA');
            CountryIsoCodes.put('lebanon', 'LBN');
            CountryIsoCodes.put('lesotho', 'LSO');
            CountryIsoCodes.put('liberia', 'LBR');
            CountryIsoCodes.put('libya', 'LBY');
            CountryIsoCodes.put('liechtenstein', 'LIE');
            CountryIsoCodes.put('lithuania', 'LTU');
            CountryIsoCodes.put('luxembourg', 'LUX');
            CountryIsoCodes.put('macedonia, republic of', 'MKD');
            CountryIsoCodes.put('madagascar', 'MDG');
            CountryIsoCodes.put('malawi', 'MWI');
            CountryIsoCodes.put('malaysia', 'MYS');
            CountryIsoCodes.put('maldives', 'MDV');
            CountryIsoCodes.put('mali', 'MLI');
            CountryIsoCodes.put('malta', 'MLT');
            CountryIsoCodes.put('marshall islands', 'MHL');
            CountryIsoCodes.put('martinique', 'MTQ');
            CountryIsoCodes.put('mauritania', 'MRT');
            CountryIsoCodes.put('mauritius', 'MUS');
            CountryIsoCodes.put('mayotte', 'MYT');
            CountryIsoCodes.put('melilla', 'VX8');
            CountryIsoCodes.put('mexico', 'MEX');
            CountryIsoCodes.put('micronesia, federated states of', 'FSM');
            CountryIsoCodes.put('moldova', 'MDA');
            CountryIsoCodes.put('monaco', 'MCO');
            CountryIsoCodes.put('mongolia', 'MNG');
            CountryIsoCodes.put('montenegro', 'MNE');
            CountryIsoCodes.put('montserrat', 'MSR');
            CountryIsoCodes.put('morocco', 'MAR');
            CountryIsoCodes.put('mozambique', 'MOZ');
            CountryIsoCodes.put('myanmar', 'MMR');
            CountryIsoCodes.put('namibia', 'NAM');
            CountryIsoCodes.put('nauru', 'NRU');
            CountryIsoCodes.put('nepal', 'NPL');
            CountryIsoCodes.put('netherlands', 'NLD');
            CountryIsoCodes.put('netherlands antilles', 'ANT');
            CountryIsoCodes.put('new caledonia', 'NCL');
            CountryIsoCodes.put('new zealand', 'NZL');
            CountryIsoCodes.put('nicaragua', 'NIC');
            CountryIsoCodes.put('niger', 'NER');
            CountryIsoCodes.put('nigeria', 'NGA');
            CountryIsoCodes.put('niue', 'NIU');
            CountryIsoCodes.put('norfolk island', 'NFK');
            CountryIsoCodes.put('northern mariana islands', 'MNP');
            CountryIsoCodes.put('norway', 'NOR');
            CountryIsoCodes.put('oman', 'OMN');
            CountryIsoCodes.put('pakistan', 'PAK');
            CountryIsoCodes.put('palau', 'PLW');
            CountryIsoCodes.put('palestinian territory', 'PSE');
            CountryIsoCodes.put('panama', 'PAN');
            CountryIsoCodes.put('papua new guinea', 'PNG');
            CountryIsoCodes.put('paraguay', 'PRY');
            CountryIsoCodes.put('peru', 'PER');
            CountryIsoCodes.put('philippines', 'PHL');
            CountryIsoCodes.put('pitcairn', 'PCN');
            CountryIsoCodes.put('poland', 'POL');
            CountryIsoCodes.put('portugal', 'PRT');
            CountryIsoCodes.put('puerto rico', 'PRI');
            CountryIsoCodes.put('qatar', 'QAT');
            CountryIsoCodes.put('réunion', 'REU');
            CountryIsoCodes.put('romania', 'ROU');
            CountryIsoCodes.put('russian federation', 'RUS');
            CountryIsoCodes.put('rwanda', 'RWA');
            CountryIsoCodes.put('saint-barthélemy', 'BLM');
            CountryIsoCodes.put('saint helena', 'SHN');
            CountryIsoCodes.put('saint kitts and nevis', 'KNA');
            CountryIsoCodes.put('saint lucia', 'LCA');
            CountryIsoCodes.put('saint-martin (french part)', 'MAF');
            CountryIsoCodes.put('saint pierre and miquelon', 'SPM');
            CountryIsoCodes.put('saint vincent and grenadines', 'VCT');
            CountryIsoCodes.put('samoa', 'WSM');
            CountryIsoCodes.put('san marino', 'SMR');
            CountryIsoCodes.put('sao tome and principe', 'STP');
            CountryIsoCodes.put('saudi arabia', 'SAU');
            CountryIsoCodes.put('senegal', 'SEN');
            CountryIsoCodes.put('serbia', 'SRB');
            CountryIsoCodes.put('seychelles', 'SYC');
            CountryIsoCodes.put('sierra leone', 'SLE');
            CountryIsoCodes.put('singapore', 'SGP');
            CountryIsoCodes.put('slovakia', 'SVK');
            CountryIsoCodes.put('slovenia', 'SVN');
            CountryIsoCodes.put('solomon islands', 'SLB');
            CountryIsoCodes.put('somalia', 'SOM');
            CountryIsoCodes.put('south africa', 'ZAF');
            CountryIsoCodes.put('south georgia and the south sandwich islands', 'SGS');
            CountryIsoCodes.put('south korea', 'KOR');
            CountryIsoCodes.put('south sudan', 'SSD');
            CountryIsoCodes.put('spain', 'ESP');
            CountryIsoCodes.put('sri lanka', 'LKA');
            CountryIsoCodes.put('sudan', 'SDN');
            CountryIsoCodes.put('suriname', 'SUR');
            CountryIsoCodes.put('svalbard and jan mayen islands', 'SJM');
            CountryIsoCodes.put('swaziland', 'SWZ');
            CountryIsoCodes.put('sweden', 'SWE');
            CountryIsoCodes.put('switzerland', 'CHE');
            CountryIsoCodes.put('syrian arab republic (syria)', 'SYR');
            CountryIsoCodes.put('taiwan, republic of china', 'TWN');
            CountryIsoCodes.put('tajikistan', 'TJK');
            CountryIsoCodes.put('tanzania, united republic of', 'TZA');
            CountryIsoCodes.put('thailand', 'THA');
            CountryIsoCodes.put('timor-leste', 'TLS');
            CountryIsoCodes.put('togo', 'TGO');
            CountryIsoCodes.put('tokelau', 'TKL');
            CountryIsoCodes.put('tonga', 'TON');
            CountryIsoCodes.put('trinidad and tobago', 'TTO');
            CountryIsoCodes.put('tunisia', 'TUN');
            CountryIsoCodes.put('turkey', 'TUR');
            CountryIsoCodes.put('turkmenistan', 'TKM');
            CountryIsoCodes.put('turks and caicos islands', 'TCA');
            CountryIsoCodes.put('tuvalu', 'TUV');
            CountryIsoCodes.put('uganda', 'UGA');
            CountryIsoCodes.put('ukraine', 'UKR');
            CountryIsoCodes.put('united arab emirates', 'ARE');
            CountryIsoCodes.put('united kingdom', 'GBR');
            CountryIsoCodes.put('united states', 'USA');
            CountryIsoCodes.put('united states of america', 'USA');
            CountryIsoCodes.put('us', 'USA');
            CountryIsoCodes.put('usa', 'USA');
            CountryIsoCodes.put('us minor outlying islands', 'UMI');
            CountryIsoCodes.put('uruguay', 'URY');
            CountryIsoCodes.put('uzbekistan', 'UZB');
            CountryIsoCodes.put('vanuatu', 'VUT');
            CountryIsoCodes.put('venezuela (bolivarian republic)', 'VEN');
            CountryIsoCodes.put('viet nam', 'VNM');
            CountryIsoCodes.put('vietnam', 'VNM');
            CountryIsoCodes.put('virgin islands, us', 'VIR');
            CountryIsoCodes.put('wallis and futuna islands', 'WLF');
            CountryIsoCodes.put('western sahara', 'ESH');
            CountryIsoCodes.put('yemen', 'YEM');
            CountryIsoCodes.put('zambia', 'ZMB');
            CountryIsoCodes.put('zimbabwe', 'ZWE');
        }
        return CountryIsoCodes;
    }
}
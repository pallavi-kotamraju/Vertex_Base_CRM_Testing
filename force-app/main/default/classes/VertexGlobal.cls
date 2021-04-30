global with sharing class VertexGlobal {

    //     Exception to throw when parameters expected aren't met
    //     *Placeholder for future use
    public class VertexGlobalException extends Exception {}

    //     Reminder, SF can't tell the difference between Object and LIST<Object>
    //     In this case we're expecting a list
    global static object GlobalHelper(object params){
        system.debug(LoggingLevel.WARN, '===VertexGlobalHelper===');
        system.debug(LoggingLevel.ERROR, 'params:  ' + params);

        //  Variable Prep        
        transient object result;                //  Return variable for whatever is relevant to the request
        transient list<object> paramList;       //  Variable to store the list of objects handed in
        transient String functionCall;          //  Declaration of what function is being requested


        //  Validate the payload isn't empty
        if (params != null){
            //  Try/catch to make sure it's really a list coming in...
            try {
                //  Cast to list of objects if we can
                paramList = (list<object>) params;
            } catch (exception ex) {
                VertexLogging.Log('Error', 'Vertex Error:  Provided parameters not in correct list<object> format. - '+ ex.getMessage());
                throw new VertexGlobalException('Vertex Error:  Provided parameters not in correct list<object> format.');
            }
        }

        //  Check to ensure paramList has values inside
        if (!paramList.isEmpty()){
            functionCall = (string)paramList[0];

            if(functionCall=='saveObjMap'){
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Map of Object Mappings to Map of Field Value Pairs is required');
                Map<String, Map<String, String>> objMappings;
                try {
                    //  Cast to correct object type if we can
                    objMappings = (Map<String, Map<String, String>>)paramList[1];
                } catch (exception ex) {
                    VertexLogging.Log('Error', 'Vertex Error:  Second parameter not in correct Map<String, Map<String, String>> format. - '+ ex.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Second parameter not in correct Map<String, Map<String, String>> format.');
                }
                VertexGlobal.UpdateObjectMappingsFromMap(objMappings);
                result = true;
            }
            else if(functionCall=='fetchObjMap'){
                if (paramList.size() == 1) {
                    VertexGlobal.InitBillingObjectMappings();
                } else{
                    VertexGlobal.PopulateObjectMappings((List<String>)paramList[1]);    //Initialize with passed in map names
                }
                result = VertexGlobal.ObjectMappingNameToFieldValuePairs;
            }
            else if (functionCall=='saveAddyMap'){
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Map of Address mappings to Map of Field Value Pairs is required');
                Map<String, Map<String, String>> addyMappings;
                try {
                    //  Cast to correct object type if we can
                    addyMappings = (Map<String, Map<String, String>>)paramList[1];
                } catch (exception ex) {
                    VertexLogging.Log('Error', 'Vertex Error:  Second parameter not in correct Map<String, Map<String, String>> format. - '+ex.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Second parameter not in correct Map<String, Map<String, String>> format.');
                }
                VertexGlobal.UpdateAddressFromMap(addyMappings);
                result = true;

            }
            else if (functionCall=='fetchAddyMap') {
                if (paramList.size() == 1) {
                    VertexGlobal.InitBillingAddressMappings();
                } else{
                    VertexGlobal.PopulateAddressMappings((List<String>)paramList[1]);    //Initialize with passed in map names
                }
                result = VertexGlobal.AddressNameToFieldValuePairs;
            }
            else if (functionCall=='fetchFldMap') {
               VertexGlobal.PopulateFieldMappings();
               result = VertexGlobal.FieldMappingValuePairs;
            }
            else if (functionCall=='saveFldMap') {
               if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Map of Field mappings to Map of Field Value Pairs is required');
                Map<String, Map<String, String>> flexMappings;
                try {
                    //  Cast to correct object type if we can
                    flexMappings = (Map<String, Map<String, String>>)paramList[1];
                } catch (exception ex) {
                    VertexLogging.Log('Error', 'Vertex Error:  Second parameter not in correct Map<String, Map<String, String>> format. - '+ex.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Second parameter not in correct Map<String, Map<String, String>> format.');
                }
                VertexGlobal.UpdateFieldsFromMap(flexMappings);
                result = true;
            }
            else if (functionCall=='deleteFldMap') {
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - String of custom setting ID is required');
                VertexGlobal.DeleteFieldMapping((String)paramList[1]);
                result = true;
            }
            else if (functionCall == 'suppressLogs') {
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Boolean suppressLogs is required');
                try {
                    VertexLogging.SuppressLogs = (Boolean) paramList[1];
                } catch (exception e) {
                    VertexLogging.Log('Error', 'Vertex Error:  Provided parameter is not of type Boolean - '+e.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Provided parameter is not of type Boolean');
                }
            }
            else if (functionCall == 'billingRequest') {
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Boolean billingRequest is required');
                try {
                    VertexCore.ActiveSettings.Billing_Requested__c = (Boolean) paramList[1];
                } catch (exception e) {
                    VertexLogging.Log('Error', 'Vertex Error:  Provided parameter is not of type Boolean - '+e.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Provided parameter is not of type Boolean');
                }
            }

            else if (functionCall=='negativeCallout') {
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Boolean negativeCallout is required');
                try {
                    VertexCore.NegativeCallout = (Boolean) paramList[1];
                } catch (exception e) {
                    VertexLogging.Log('Error', 'Vertex Error:  Provided parameter is not of type Boolean - '+e.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Provided parameter is not of type Boolean');
                }
            }
            else if (functionCall=='fetchFailedLineItemIds'){
                return VertexCore.FailedLineItemIds;
            }
            else if (functionCall=='saveLineDestinationOverrideMappings') {
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Map<String, String> lineDestinationOverrideMappings is required');
                try {
                    VertexCore.LineDestinationOverrideMappings = (Map<String, String>) paramList[1];
                } catch (exception e) {
                    VertexLogging.Log('Error', 'Vertex Error:  Provided parameter is not of type Map<String, String> - '+e.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Provided parameter is not of type Map<String, String>');
                }
            }
            else if (functionCall=='saveBillingDestinationMappings') {
                if (paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Map<String, String> BillingDestinationMappings is required');
                try {
                    VertexCore.BillingDestinationMappings = (Map<String, String>) paramList[1];
                } catch (exception e) {
                    VertexLogging.Log('Error', 'Vertex Error:  Provided parameter is not of type Map<String, String> - '+e.getMessage());
                    throw new VertexGlobalException('Vertex Error:  Provided parameter is not of type Map<String, String>');
                }
            }
            else if(functionCall=='saveOverrideMappings'){
                if( paramList.size() < 2)
                    throw new VertexGlobalException('Vertex Error:  Insufficient parameters - Map< String, Map<String, String>> overrideMappings is required');
                try{
                    VertexCore.fieldOverrideMap = (Map<String,Map<String,String>>) paramList[1];
                }catch(exception e){
                    VertexLogging.Log('Error', 'Vertex Error:  Provided parameter is not of type Map<String, String> - '+e.getMessage());
                    throw new VertexGlobalException('Vertex Error: Provided parameter is not of type Map<String,Map<String,String>>');
                }
            }

        }
        return result;
    }

    // Update VertexObjectMapping__c records with values passed in through map of field value pairs
    public static void UpdateObjectMappingsFromMap(Map<String, Map<String, String>> recordNameToFieldValuePairs) {
        List<VertexObjectMapping__c> tmpList = new List<VertexObjectMapping__c>();
        for (String recordName : recordNameToFieldValuePairs.keySet()) {
            // Populate the list that is to be upserted with the existing custom settings or a new one if one doesnt exist already
            if (VertexCore.ObjectMappings.get(recordName) == null){
                insert new VertexObjectMapping__c(Name = recordName);
                VertexCore.ObjectMappings = null;
            }

            tmpList.add(VertexCore.ObjectMappings.get(recordName));
            transient Set<String> booleanFields = new Set<String>{'isextensionsetting__c'};
            // Loop trough the custom settings in the temp list
            for (VertexObjectMapping__c objMap : tmpList){
                // loop through all the fields in the map and copy the values into the custom setting records
                for (String fieldName : recordNameToFieldValuePairs.get(objMap.Name).keySet()){
                    String fldVal = recordNameToFieldValuePairs.get(objMap.Name).get(fieldName) != null ? recordNameToFieldValuePairs.get(objMap.Name).get(fieldName) : '';
                    if (booleanFields.contains(fieldName.removeStartIgnoreCase(VertexCore.NamespaceString).toLowerCase()))
                        objMap.put(fieldName, fldVal == 'true');
                    else
                        objMap.put(fieldName, fldVal);
                }
            }
        }

        try {
            Database.upsert(tmpList, false);
        } catch (Exception e) {
            System.debug('Exception '+e);
            VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
        }
    }

    //This allows for instantiation of any number of mapping names
    public static void PopulateObjectMappings(List<String> mappingNames){
        if (ObjectMappingNameToFieldValuePairs == null)
            ObjectMappingNameToFieldValuePairs = new Map<String, Map<String, String>>();
        
        transient Schema.DescribeSObjectResult objDesc = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexObjectMapping__c').getDescribe();
        
        for (String mappingName : mappingNames){
            ObjectMappingNameToFieldValuePairs.put(mappingName, new Map<String, String>());
            // Loop trough the fields to populate the maps with their values
            for (String fieldKey : objDesc.fields.getMap().keySet()) {
                // Only need custom fields and the record ID itself
                if (fieldKey.endsWith('__c') || fieldKey.equalsIgnoreCase('id')){
                    transient String fldName = objDesc.fields.getMap().get(fieldKey).getDescribe().getName();
                    String value = '';
                    // If the custom settings exists and the field's value is not null populate the map with its value, else leave blank
                    if (VertexCore.ObjectMappings.get(mappingName) != null && VertexCore.ObjectMappings.get(mappingName).get(fldName) != null)
                        value = String.valueOf(VertexCore.ObjectMappings.get(mappingName).get(fldName));

                    ObjectMappingNameToFieldValuePairs.get(mappingName).put(fldName, value);
                }
            }
        }
    }

    public static void InitBillingObjectMappings(){
        // Populate map with 3 records used by the billing extension
        Set<String> mappingNames = new Set<String> {'SFNote', 'SFOrder', 'SFInv'};

        // Instantiate maps for each record
        for (String mappingName : mappingNames)
            ObjectMappingNameToFieldValuePairs.put(mappingName, new Map<String, String>());
        
        transient Schema.DescribeSObjectResult objDesc = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexObjectMapping__c').getDescribe();

        // Loop trough the fields to populate the maps with their values
        for (String fieldKey : objDesc.fields.getMap().keySet()){
            // Only need custom fields and the record ID itself
            if (fieldKey.endsWith('__c')) {
                transient String fldName = objDesc.fields.getMap().get(fieldKey).getDescribe().getName();
                for (String mappingName : mappingNames) {
                    String value = '';
                    // If the custom settings exists and the field's value is not null populate the map with its value, else leave blank
                    if (VertexCore.ObjectMappings.get(mappingName) != null && VertexCore.ObjectMappings.get(mappingName).get(fldName) != null)
                        value = String.valueOf(VertexCore.ObjectMappings.get(mappingName).get(fldName));

                    ObjectMappingNameToFieldValuePairs.get(mappingName).put(fldName, value);
                }
            }
        }
    }

    public static Map<String, Map<String, String>> ObjectMappingNameToFieldValuePairs {
        get {
            if (ObjectMappingNameToFieldValuePairs == null)
                ObjectMappingNameToFieldValuePairs = new Map<String, Map<String, String>>();
            
            return ObjectMappingNameToFieldValuePairs;
        }
        set;
    }

    // TODO: create 2 abstract with most of the code from following two to avoid code duplication with 2 above

    // Update VertexAddress__c records with values passed in through map of field value pairs
    public static void UpdateAddressFromMap(Map<String, Map<String, String>> recordNameToFieldValuePairs) {
        List<VertexAddress__c> tmpList = new List<VertexAddress__c>();
        for (String recordName : recordNameToFieldValuePairs.keySet()) {
            // Populate the list that is to be upserted with the existing custom settings or a new one if one doesnt exist already
            if (VertexAddress__c.getAll().get(recordName) == null)
                tmpList.add(new VertexAddress__c(Name = recordName));
            else
                tmpList.add(VertexAddress__c.getAll().get(recordName));

            // Loop trough the custom settings in the temp list
            for (VertexAddress__c objMap : tmpList){
                // loop through all the fields in the map and copy the values into the custom setting records
                for (String fieldName : recordNameToFieldValuePairs.get(objMap.Name).keySet()){
                    if (!fieldName.equalsIgnoreCase('id'))
                        objMap.put(fieldName, recordNameToFieldValuePairs.get(objMap.Name).get(fieldName));
                }
            }
        }
        
        try {
            Database.upsert(tmpList, false); 
        } catch (Exception e) {
            System.debug('Exception '+e);
            VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
        }
    }

    //This allows for instantiation of any number of address mappings
    public static void PopulateAddressMappings(List<String> mappingNames){
        if (AddressNameToFieldValuePairs == null)
            AddressNameToFieldValuePairs = new Map<String, Map<String, String>>();
        
        transient Schema.DescribeSObjectResult objDesc = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexAddress__c').getDescribe();
        
        for (String mappingName : mappingNames){
            AddressNameToFieldValuePairs.put(mappingName, new Map<String, String>());
            // Loop trough the fields to populate the maps with their values
            for (String fieldKey : objDesc.fields.getMap().keySet()) {
                // Only need custom fields
                if (fieldKey.endsWith('__c') || fieldKey.equalsIgnoreCase('id')){
                    transient String fldName = objDesc.fields.getMap().get(fieldKey).getDescribe().getName();
                    String value = '';
                    // If the custom settings exists and the field's value is not null populate the map with its value else leave blank
                    if (VertexAddress__c.getAll().get(mappingName) != null)
                        if (VertexAddress__c.getAll().get(mappingName).get(fldName) != null)
                            value = (String) VertexAddress__c.getAll().get(mappingName).get(fldName);

                    AddressNameToFieldValuePairs.get(mappingName).put(fldName, value);
                }
            }
        }
    }

    public static void InitBillingAddressMappings(){
        // Populate map with 3 records used by the billing extension
        Set<String> mappingNames = new Set<String> {'SFNote Trans Dest Map', 'SFOrder Trans Dest Map', 'SFInv Trans Dest Map',
                                                    'SFNote Line Dest Map', 'SFOrder Line Dest Map', 'SFInv Line Dest Map'};

        // Instantiate maps for each record
        for (String mappingName : mappingNames)
            AddressNameToFieldValuePairs.put(mappingName, new Map<String, String>());
        
        transient Schema.DescribeSObjectResult objDesc = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexAddress__c').getDescribe();

        // Loop trough the fields to populate the maps with their values
        for (String fieldKey : objDesc.fields.getMap().keySet()){
            // Only need custom fields
            if (fieldKey.endsWith('__c')) {
                transient String fldName = objDesc.fields.getMap().get(fieldKey).getDescribe().getName();
                for (String mappingName : mappingNames) {
                    String value = '';
                    // If the custom settings exists and the field's value is not null populate the map with its value else leave blank
                    if (VertexAddress__c.getAll().get(mappingName) != null)
                        if (VertexAddress__c.getAll().get(mappingName).get(fldName) != null)
                            value = (String) VertexAddress__c.getAll().get(mappingName).get(fldName);

                    AddressNameToFieldValuePairs.get(mappingName).put(fldName, value);
                }
            }
        }
    }
    
    public static Map<String, Map<String, String>> AddressNameToFieldValuePairs {
        get {
            if (AddressNameToFieldValuePairs == null) 
                AddressNameToFieldValuePairs = new Map<String, Map<String, String>>();
            
            return AddressNameToFieldValuePairs;
        }
        set;
    }

    //This allows for instantiation of any number of field mappings
    public static void PopulateFieldMappings(){
        FieldMappingValuePairs = new Map<String, Map<String, String>>();
        transient Schema.DescribeSObjectResult objDesc = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexFieldMapping__c').getDescribe();
        
        for (VertexFieldMapping__c fldMap : VertexCore.FieldMappings.values()){
            FieldMappingValuePairs.put(fldMap.Name, new Map<String, String>());
            // Loop trough the fields to populate the maps with their values
            for (String fieldKey : objDesc.fields.getMap().keySet()) {
                // Only need custom fields
                if (fieldKey.endsWith('__c') || fieldKey.equalsIgnoreCase('id')){
                    transient String fldName = objDesc.fields.getMap().get(fieldKey).getDescribe().getName();
                    String value = '';
                    // If the custom settings exists and the field's value is not null, populate the map with its value, else leave blank
                    if (fldMap.get(fldName) != null)
                        value = String.valueOf(fldMap.get(fldName));

                    FieldMappingValuePairs.get(fldMap.Name).put(fldName, value);
                }
            }
        }
    }

    public static Map<String, Map<String, String>> FieldMappingValuePairs {
        get {
            if (FieldMappingValuePairs == null) 
                FieldMappingValuePairs = new Map<String, Map<String, String>>();
            
            return FieldMappingValuePairs;
        }
        set;
    }

    // Update VertexFieldMapping__c records with values passed in through map of field value pairs
    public static void UpdateFieldsFromMap(Map<String, Map<String, String>> recordNameToFieldValuePairs) {
        List<VertexFieldMapping__c> tmpList = new List<VertexFieldMapping__c>();
        for (String recordName : recordNameToFieldValuePairs.keySet()) {
            // Populate the list that is to be upserted with the existing custom settings or a new one if one doesnt exist already
            if (VertexFieldMapping__c.getAll().get(recordName) == null)
                tmpList.add(new VertexFieldMapping__c(Name = recordName));
            else
                tmpList.add(VertexFieldMapping__c.getAll().get(recordName));

            // Loop trough the custom settings in the temp list
            for (VertexFieldMapping__c fldMap : tmpList){
                // loop through all the fields in the map and copy the values into the custom setting records
                for (String fieldName : recordNameToFieldValuePairs.get(fldMap.Name).keySet()){
                    if (!fieldName.equalsIgnoreCase('id'))
                        fldMap.put(fieldName, recordNameToFieldValuePairs.get(fldMap.Name).get(fieldName));
                }
            }
        }
        
        try{
            Database.upsert(tmpList, false);
        } catch (Exception e) {
            System.debug('Exception '+e);
            VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
        }
    }

    public static void DeleteFieldMapping(String settingID){
        List<VertexFieldMapping__c> fldSetting = [SELECT ID FROM VertexFieldMapping__c WHERE ID = :settingID LIMIT 1];
        if (!fldSetting.isEmpty())
            delete fldSetting;
    }

}
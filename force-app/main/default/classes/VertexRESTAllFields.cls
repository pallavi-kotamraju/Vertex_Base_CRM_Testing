@RestResource(urlMapping='/VertexCPQAllFields/*')
global with sharing class VertexRESTAllFields{
    @HttpPost
    global static String getTaxAllFields(String quote, String lineModels, String type){
        transient Map<String,String> quoteFieldMap = getFieldMap(quote);
        transient String Id = quoteFieldMap.get('Id');
        //create override map, place quote in overridemap
        Map<String,Map<String,String>> overrideMap = getOverrideMap(quoteFieldMap, lineModels);
        overrideMap.remove(Id);
        //need to connect to base pacakge to set override map
        VertexGlobal.GlobalHelper(new list<object>{'saveOverrideMappings', overrideMap});
        
        transient VertexCPQSettings__c vtxCPQSet = VertexCPQSettings__c.getOrgDefaults();
        
        transient String result;

        // if synchronous mode
        if(!vtxCPQSet.AsynchronousCPQCallout__c){
            result = VertexRestHandler.getTax(Id,'Quote');
        } else {
            // needed to check to see if there are extended prices for all line items
            // without this check on the initial calculation from CPQ a callout will be made
            // and it will fail because there is no value in SBQQ_QuoteLine__c.SBQQ_netTotal__c
            Boolean missingNetTotal = false;
            String qcpStatus = 'sbqq_nettotal__cNull';

            List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
            if(Schema.SObjectType.SBQQ__QuoteLine__c.isAccessible() &&
               Schema.SObjectType.SBQQ__QuoteLine__c.fields.SBQQ__NetTotal__c.isAccessible() ){
                quoteLineList = [SELECT Id, SBQQ__NetTotal__c FROM SBQQ__QuoteLine__c 
                                 WHERE SBQQ__Quote__c =: Id 
                                 AND SBQQ__NetTotal__c = null
                                 WITH SECURITY_ENFORCED LIMIT 10000 ];
            }

            // in asynchronous mode with values in extended price line items
            if(quoteLineList.size() == 0){
                System.debug('-->Log 1 : VeretexRESTALL Fields: Asynchrouse checked');
                VertexGetTaxQueueable calloutReq = new VertexGetTaxQueueable(Id, 'Quote');
                Id jobId = System.enqueueJob(calloutReq);
                qcpStatus = 'async';
            }

            // create fake response to set values to zero so that the CPQ callout does not fail.
            result = '{"'+Id+'"'+': "'+qcpStatus+'",';
            for(SBQQ__QuoteLine__c ql: [SELECT Id FROM SBQQ__QuoteLine__c WHERE 
                                        SBQQ__Quote__c =: Id LIMIT 10000]){
                result += '"'+ql.id+'": "'+qcpStatus+'",';

            }
            result = result.removeEnd(',');
            result += '}';

        }
            
        return result;
    }



    //retrieves the mapped key/value pairs stored in the Transaction object fields
    @testVisible
    private static Map<String,String> getFieldMap(String record){

        //get a set of all mapped fields
        transient Set<String> mappedFields = getCpqMappedFields();

        transient Map<String,Object> objectMap = (Map<String,Object>) JSON.deserializeUntyped(record);

        transient Map<String,String> stringMap = new Map<String,String>();
        for(String key : objectMap.keySet()){

            //serializing adds extra quotes that we should remove
            //ideally would like to use a safer way to covert from object to a string without adding extra quotes
            transient String value = (String) JSON.Serialize(objectMap.get(key));
            value = value.removeStart('"');
            value = value.removeEnd('"');

            //serializing strings causes an issue where null values become the null string, need to revert back to null
            if(value == 'null'){
                value = null;
            }

            if(mappedFields.contains(key)){
                stringMap.put(key,value);
            }
        }
        
        return stringMap;
    }
    
    //returns all mapped fields defined by each mapping type : flex, trans destination, line destination
    private static Set<String> getCpqMappedFields(){
        //get a set of all mapped fields
        Map<String,Map<String,String>> ObjectMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new List<object>{'fetchObjMap', new List<String>{'CPQ'}});
        Map<String,String> objFieldMap = objectMappingNameToFieldValuePairs.get('CPQ');
        Set<String> mappedFields = new Set<String>();
        mappedFields.add('Id');
        mappedFields.addAll(objFieldMap.values());

        //get a set of all flex fields
        Map<String,Map<String,String>> fieldMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new List<object>{'fetchFldMap', new List<String>{'CPQ'}});
        Map<String,String> fieldMap = fieldMappingNameToFieldValuePairs.get('CPQ');

        if(fieldMap != null){
            mappedFields.addAll(fieldMap.values());
        }

        //get a set of all address fields, both trans destination map and line destination map
        Map<String,Map<String,String>> addressMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new List<object>{'fetchAddyMap', new List<String>{'CPQ Trans Dest Map','CPQ Line Dest Map'}});
        
        Map<String,String> addressFieldMap = addressMappingNameToFieldValuePairs.get('CPQ Trans Dest Map');
        Map<String,String> addressLineFieldMap = addressMappingNameToFieldValuePairs.get('CPQ Line Dest Map');
        
        if(addressFieldMap != null){
            mappedFields.addAll(addressFieldMap.values());
        }

        if(addressLineFieldMap != null){
            mappedFields.addAll(addressLineFieldMap.values());
        }
        
        return mappedFields;
    }

    //returns all fields defined in the quoteFieldMap
    @testVisible
    private static Map<String,Map<String,String>> getOverrideMap(Map<String,String> quoteFieldMap, String lineModels){
        //create override map, place quote in overridemap
        Map<String,Map<String,String>> overrideMap = new Map<String,Map<String,String>>();
        String Id = quoteFieldMap.get('Id');

        //we can remove these fields from the override map as they will never need to be overridden
        quoteFieldMap.remove('Name');
        quoteFieldMap.remove('SBQQ__NetTotal__c');
        
        overrideMap.put(Id,quoteFieldMap);

        //holds a list of maps: for each quote line item, holds a fields mapping
        List<Map<String,Object>> quoteLineFieldMaps = new List<Map<String,Object>>();

        //deserialize the line items into a list of objects
        List<Object> lineItemList = (List<Object>) JSON.deserializeUntyped(lineModels);

        //convert the objects into an object map, add each object map to a list
        for(Object obj : lineItemList){
            quoteLineFieldMaps.add((Map<String,Object>) obj);
        }

        //obtain the set of already mapped fields, this way, our override map will only have fields that have been mapped
        Set<String> mappedFields = getCpqMappedFields();
        for(Map<String,Object> quoteLineFieldMap : quoteLineFieldMaps){
            //create a field map
            Map<String,String> fieldMap = getFieldMap(mappedFields,quoteLineFieldMap);
            overrideMap.put((String) quoteLineFieldMap.get('Id'),fieldMap);
        }
        
        return overrideMap;
    }
    
    //creates a map of field key/value pairs to override a single line item
    //mapped fields holds a set of fields that are present in the current mapping
    //quoteLineFieldMap holds the current key/value mapping from one of the quote lines
    private static Map<String,String> getFieldMap(Set<String> mappedFields, Map<String,Object> quoteLineFieldMap){
        Map<String,String> fieldMap = new Map<String,String>();
            
        //for every mapped field create a map with its field/value pair
        for(String mappedField : mappedFields){
            if(quoteLineFieldMap.containsKey(mappedField)){
                String val = getQuoteLineFieldValue(quoteLineFieldMap,mappedField);
                fieldMap.put(mappedField,val);
            }
        }

        //these fields will not be overwritten so we can remove them from the field mapping
        fieldMap.remove('Name');
        fieldMap.remove('SBQQ__Quote__c');

        return fieldMap;
    }

    //if the mapped field is contained in the quoteLineFieldMap, then return the string version of the field
    //if the field is not a string or a number, we set the value to the empty string
    @testVisible
    private static String getQuoteLineFieldValue(Map<String,Object> quoteLineFieldMap, String mappedField){
        String val = '';

        try{
            if(quoteLineFieldMap.get(mappedField) instanceof Decimal){
                val = String.valueOf(quoteLineFieldMap.get(mappedField));
            }
            else{
                val = (String) quoteLineFieldMap.get(mappedField);
            }
        }catch(Exception e){
            System.debug('field type not of type string or decimal: ' + e.getMessage());
        }

        return val;
    }
}
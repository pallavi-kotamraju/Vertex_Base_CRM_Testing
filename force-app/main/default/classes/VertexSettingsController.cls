public with sharing class VertexSettingsController {

    public static String SoapEnv = 'http://schemas.xmlsoap.org/soap/envelope/';
    public static String URN =  'urn:vertexinc:o-series:tps:7:0';
    private static final Integer OBJECT_MAPPING_NAME_MAX_CHARS = 18;   //Maximum length of object setting name (allowing " Trans Dest Map" in address setting)
    
    public String NameSpacePrefix { 
        get{
            if(NameSpacePrefix==null){
                NameSpacePrefix = VertexCore.NamespaceString;
            }
            return NameSpacePrefix;
        }
        set;
    }

    public LIST<VertexAddress__c> AddressList { 
        get{
            RefreshAddresses();
            return AddressList; 
        }
        set;
    }

    public VertexProtectedSettings__c config { 
        get{
            if (config == null)   //  was ActiveConfig
                config = VertexCore.ActiveSettings;
            return config;
        }
        set; 
    }

    //============================================================
    //  START ITEM MAPPINGS SECTION
    //============================================================

    public List<VertexObjectMapping__c> getItemMappings(){
        List<VertexObjectMapping__c> allMappings = new List<VertexObjectMapping__c>();
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
            if (objMap.IsExtensionSetting__c != true)
                allMappings.add(objMap);
        allMappings.add(new VertexObjectMapping__c());  //Add empty record to allow the user to create a new one
        return allMappings;
    }

    //Must be a remote action for when the page needs a refreshed definition of the object mapping settings
    @RemoteAction
    public static List<VertexObjectMapping__c> getItemMappingsRA(){
        List<VertexObjectMapping__c> allMappings = new List<VertexObjectMapping__c>();
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
            if (objMap.IsExtensionSetting__c != true)
                allMappings.add(objMap);
        return allMappings;
    }

    @RemoteAction
    public static String SaveItemMapping(ObjectMapSetting objMapSetting){
        String errorMsg;
        Boolean isUpdate = String.isNotBlank(objMapSetting.settingID);
        VertexObjectMapping__c settingToUpsert = String.isNotBlank(objMapSetting.settingID) ? new VertexObjectMapping__c(ID = objMapSetting.settingID) : new VertexObjectMapping__c();
        String oldName; //Necessary if destination mappings need to be updated to a new object mapping name
        if (isUpdate == true){
            oldName = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :objMapSetting.settingID LIMIT 1].Name;
        }
            
        //Prevent case-insentitive name duplication
        Boolean nameDupe = false;
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values()){
            if (objMap.IsExtensionSetting__c != true && !objMap.Name.equals(objMapSetting.mappingName) && objMap.Name.equalsIgnoreCase(objMapSetting.mappingName)){
                nameDupe = true;
                break;
            }
        }

        if (nameDupe == true)
            errorMsg = 'Could not save mapping because the name "' + objMapSetting.mappingName + '" is a duplicate';

        if (objMapSetting.IsAnyFieldEmpty() == true){
            errorMsg = 'Could not save mapping. Please ensure that all required fields are populated';
            System.Debug('===errorMsg '+JSON.serialize(errorMsg));
        }
        
        //We are either updating an existing setting (retrieved by ID) or inserting a new setting
        if (settingToUpsert != null && errorMsg == null){
            settingToUpsert.Name = objMapSetting.mappingName;
            settingToUpsert.XMLMessage__c = objMapSetting.xmlMessage;
            settingToUpsert.TransactionType__c = objMapSetting.transactionType;
            settingToUpsert.ParentSObject__c = objMapSetting.parentObj;
            settingToUpsert.ChildSObject__c = objMapSetting.lineObj;
            settingToUpsert.ParentLookup__c = objMapSetting.parentLookup;
            settingToUpsert.ChildSObjectRelationshipName__c = objMapSetting.relationshipName;
            settingToUpsert.TransactionTaxAmount__c	 = objMapSetting.transactionTaxAmount;
            settingToUpsert.TransactionDate__c	 = objMapSetting.transactionDate;
            settingToUpsert.TransactionNumber__c = objMapSetting.documentNumber;
            settingToUpsert.ItemTaxField__c = objMapSetting.taxAmount;
            settingToUpsert.ItemPriceField__c = objMapSetting.extendedPrice;
            settingToUpsert.ItemQuantityField__c = objMapSetting.quantity;
            try {
                upsert settingToUpsert;
            } catch (Exception err){
                errorMsg = 'Error: Failed to save object mapping. ' + err.getMessage() + ': ' + err.getStackTraceString();
            }

            if (errorMsg == null){
                VertexAddress__c transDestMap, lineDestMap, transAdminOrigin, transPhysOrigin, lineAdminOrigin, linePhysOrigin;
                if (isUpdate == true && oldName != settingToUpsert.Name){
                    //The name of this object mapping has changed, and needs to be updated in its destination mappings
                    List<VertexAddress__c> updateAddressMaps = new List<VertexAddress__c>();
                    transDestMap = VertexAddress__c.getInstance(oldName + ' Trans Dest Map');
                    if (transDestMap != null){
                        transDestMap.Name = transDestMap.Name.replace(oldName, settingToUpsert.Name);
                        updateAddressMaps.add(transDestMap);
                    }
                    lineDestMap = VertexAddress__c.getInstance(oldName + ' Line Dest Map');
                    if (lineDestMap != null){
                        lineDestMap.Name = lineDestMap.Name.replace(oldName, settingToUpsert.Name);
                        updateAddressMaps.add(lineDestMap);
                    }
                    transAdminOrigin = VertexAddress__c.getInstance(oldName + ' Trans Admin');
                    if (transAdminOrigin != null){
                        transAdminOrigin.Name = transAdminOrigin.Name.replace(oldName, settingToUpsert.Name);
                        updateAddressMaps.add(transAdminOrigin);
                    }
                    transPhysOrigin = VertexAddress__c.getInstance(oldName + ' Trans Phys');
                    if (transPhysOrigin != null){
                        transPhysOrigin.Name = transPhysOrigin.Name.replace(oldName, settingToUpsert.Name);
                        updateAddressMaps.add(transPhysOrigin);
                    }
                    lineAdminOrigin = VertexAddress__c.getInstance(oldName + ' Line Admin');
                    if (lineAdminOrigin != null){
                        lineAdminOrigin.Name = lineAdminOrigin.Name.replace(oldName, settingToUpsert.Name);
                        updateAddressMaps.add(lineAdminOrigin);
                    }
                    linePhysOrigin = VertexAddress__c.getInstance(oldName + ' Line Phys');
                    if (linePhysOrigin != null){
                        linePhysOrigin.Name = linePhysOrigin.Name.replace(oldName, settingToUpsert.Name);
                        updateAddressMaps.add(linePhysOrigin);
                    }
                    if (!updateAddressMaps.isEmpty())
                        update updateAddressMaps;
                } else {
                    //Either this is an update where the name hasn't changed, or this is a new object mapping that needs new destination mappings
                    List<VertexAddress__c> insertAddressMaps = new List<VertexAddress__c>();
                    transDestMap = VertexAddress__c.getInstance(objMapSetting.mappingName + ' Trans Dest Map');
                    if (transDestMap == null){
                        transDestMap = new VertexAddress__c(Name = objMapSetting.mappingName + ' Trans Dest Map');
                        insertAddressMaps.add(transDestMap);
                    }
                    lineDestMap = VertexAddress__c.getInstance(objMapSetting.mappingName + ' Line Dest Map');
                    if (lineDestMap == null){
                        lineDestMap = new VertexAddress__c(Name = objMapSetting.mappingName + ' Line Dest Map');
                        insertAddressMaps.add(lineDestMap);
                    }
                    transAdminOrigin = VertexAddress__c.getInstance(objMapSetting.mappingName + ' Trans Admin');
                    if (transAdminOrigin == null){
                        transAdminOrigin = new VertexAddress__c(Name = objMapSetting.mappingName + ' Trans Admin');
                        insertAddressMaps.add(transAdminOrigin);
                    }
                    transPhysOrigin = VertexAddress__c.getInstance(objMapSetting.mappingName + ' Trans Phys');
                    if (transPhysOrigin == null){
                        transPhysOrigin = new VertexAddress__c(Name = objMapSetting.mappingName + ' Trans Phys');
                        insertAddressMaps.add(transPhysOrigin);
                    }
                    lineAdminOrigin = VertexAddress__c.getInstance(objMapSetting.mappingName + ' Line Admin');
                    if (lineAdminOrigin == null){
                        lineAdminOrigin = new VertexAddress__c(Name = objMapSetting.mappingName + ' Line Admin');
                        insertAddressMaps.add(lineAdminOrigin);
                    }
                    linePhysOrigin = VertexAddress__c.getInstance(objMapSetting.mappingName + ' Line Phys');
                    if (linePhysOrigin == null){
                        linePhysOrigin = new VertexAddress__c(Name = objMapSetting.mappingName + ' Line Phys');
                        insertAddressMaps.add(linePhysOrigin);
                    }
                    
                    if (!insertAddressMaps.isEmpty())
                        insert insertAddressMaps;
                }
            }
        }
        return errorMsg;
    }

    @RemoteAction
    public static String CloneItemMapping(String objMapID){
        String newSettingID;
        String errorMsg;
        try {
            VertexObjectMapping__c settingToClone = [SELECT Name, ChildSObject__c, ChildSObjectRelationshipName__c, ChildSourcePicklist__c, CommodityCode__c, CommodityCodeType__c, SuppressTaxCallout__c, 
                                                            TaxIncludedIndicator__c, UsageCode__c, UsageClass__c,
                                                            InputTotalTax__c, InvoiceTextCodes__c, IsExtensionSetting__c, ItemClassField__c, ItemNameField__c, 
                                                            ItemPriceField__c, ItemQuantityField__c, ItemTaxField__c, ItemTaxNotesField__c, ItemTaxPayerField__c, 
                                                            LineDeliveryTerm__c, ParentLookup__c, ParentSObject__c, ParentSourcePicklist__c, Posting_Date__c, 
                                                            TaxCode__c, TaxRegistrationNumber__c, TransactionTaxAmount__c, TransactionDate__c, TransactionDeliveryTerm__c, TransactionNumber__c, 
                                                            TransactionTaxPayer__c, TransactionType__c, VertexTaxCode__c, XMLMessage__c 
                                                    FROM VertexObjectMapping__c WHERE ID = :objMapID LIMIT 1];
            String baseName = settingToClone.Name;
            //Only allow cloning of settings that aren't fresh copies, because we don't want to keep adding " Copy" suffixes
            if (!baseName.endsWith(' Copy')){
                //Truncate the name if necessary
                if (baseName.length() > VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS - 5)    //Five characters for " Copy"
                    baseName = baseName.substring(0, VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS - 4);
                
                //Clone the object mapping
                VertexObjectMapping__c newSetting = settingToClone.clone(false, true, false, false);
                newSetting.Name = baseName + ' Copy';

                //Check for duplicates
                Boolean nameDupe = false;
                for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values()){
                    if (objMap.IsExtensionSetting__c != true && objMap.Name.equalsIgnoreCase(newSetting.Name)){
                        nameDupe = true;
                        break;
                    }
                }
                if (!nameDupe){
                    insert newSetting;
                    newSettingID = newSetting.ID;
                    
                    //Clone the destination mappings
                    List<VertexAddress__c> insertAddressMappings = new List<VertexAddress__c>();
                    VertexAddress__c transDestMap = VertexAddress__c.getInstance(settingToClone.Name + ' Trans Dest Map');
                    VertexAddress__c clonedTransDest;
                    if (transDestMap != null){
                        clonedTransDest = transDestMap.clone(false, true, false, false);
                        clonedTransDest.Name = newSetting.Name + ' Trans Dest Map';
                        insertAddressMappings.add(clonedTransDest);
                    }
                    VertexAddress__c lineDestMap = VertexAddress__c.getInstance(settingToClone.Name + ' Line Dest Map');
                    VertexAddress__c clonedLineDest;
                    if (lineDestMap != null){
                        clonedLineDest = lineDestMap.clone(false, true, false, false);
                        clonedLineDest.Name = newSetting.Name + ' Line Dest Map';
                        insertAddressMappings.add(clonedLineDest);
                    }
                    //Clone the admin and physical origin addresses
                    VertexAddress__c transAdminOrigin = VertexAddress__c.getInstance(settingToClone.Name + ' Trans Admin');
                    VertexAddress__c clonedTransAdmin;
                    if (transAdminOrigin != null){
                        clonedTransAdmin = transAdminOrigin.clone(false, true, false, false);
                        clonedTransAdmin.Name = newSetting.Name + ' Trans Admin';
                        insertAddressMappings.add(clonedTransAdmin);
                    }
                    VertexAddress__c transPhysOrigin = VertexAddress__c.getInstance(settingToClone.Name + ' Trans Phys');
                    VertexAddress__c clonedTransPhys;
                    if (transPhysOrigin != null){
                        clonedTransPhys = transPhysOrigin.clone(false, true, false, false);
                        clonedTransPhys.Name = newSetting.Name + ' Trans Phys';
                        insertAddressMappings.add(clonedTransPhys);
                    }
                    VertexAddress__c lineAdminOrigin = VertexAddress__c.getInstance(settingToClone.Name + ' Line Admin');
                    VertexAddress__c clonedLineAdmin;
                    if (lineAdminOrigin != null){
                        clonedLineAdmin = lineAdminOrigin.clone(false, true, false, false);
                        clonedLineAdmin.Name = newSetting.Name + ' Line Admin';
                        insertAddressMappings.add(clonedLineAdmin);
                    }
                    VertexAddress__c linePhysOrigin = VertexAddress__c.getInstance(settingToClone.Name + ' Line Phys');
                    VertexAddress__c clonedLinePhys;
                    if (linePhysOrigin != null){
                        clonedLinePhys = linePhysOrigin.clone(false, true, false, false);
                        clonedLinePhys.Name = newSetting.Name + ' Line Phys';
                        insertAddressMappings.add(clonedLinePhys);
                    }

                    if (!insertAddressMappings.isEmpty())
                        insert insertAddressMappings;

                    //Clone the field mappings
                    List<VertexFieldMapping__c> fldMappingList = [SELECT Name, Label__c, ObjectMapping__c, SourceField__c, Type__c 
                                                                  FROM VertexFieldMapping__c WHERE ObjectMapping__c = :objMapID];
                    List<VertexFieldMapping__c> clonedFldMappings = new List<VertexFieldMapping__c>();
                    for (VertexFieldMapping__c fldMap : fldMappingList){
                        VertexFieldMapping__c clonedFldMap = fldMap.clone(false, true, false, false);
                        clonedFldMap.Name = fldMap.Name.replace(objMapID, newSetting.ID);
                        clonedFldMap.ObjectMapping__c = newSetting.ID;
                        clonedFldMappings.add(clonedFldMap);
                    }
                    insert clonedFldMappings;
                } else {
                    errorMsg = 'Duplicate setting found for ' + newSetting.Name + '. Please rename.';
                }
            } else {
                errorMsg = 'Please remove " Copy" from end of the name';
            }
        } catch (Exception e) {
            newSettingID = null;
            errorMsg = e.getMessage();
        }
        errorMsg = 'Error: ' + errorMsg;
        return newSettingID != null ? newSettingID : errorMsg;
    }

    @RemoteAction
    public static void DeleteItemMapping(String objMapID){
        VertexObjectMapping__c settingToDelete = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :objMapID LIMIT 1];
        if (settingToDelete != null){
            String settingName = settingToDelete.Name;
            delete settingToDelete;

            List<VertexAddress__c> addressMappingsToDelete = new List<VertexAddress__c>();
            VertexAddress__c transDestMap = VertexAddress__c.getInstance(settingName + ' Trans Dest Map');
            if (transDestMap != null)
                addressMappingsToDelete.add(transDestMap);
            VertexAddress__c lineDestMap = VertexAddress__c.getInstance(settingName + ' Line Dest Map');
            if (lineDestMap != null)
                addressMappingsToDelete.add(lineDestMap);
            
            VertexAddress__c transAdminOrigin = VertexAddress__c.getInstance(settingName + ' Trans Admin');
            if (transAdminOrigin != null)
                addressMappingsToDelete.add(transAdminOrigin);
            VertexAddress__c transPhysOrigin = VertexAddress__c.getInstance(settingName + ' Trans Phys');
            if (transPhysOrigin != null)
                addressMappingsToDelete.add(transPhysOrigin);
            VertexAddress__c lineAdminOrigin = VertexAddress__c.getInstance(settingName + ' Line Admin');
            if (lineAdminOrigin != null)
                addressMappingsToDelete.add(lineAdminOrigin);
            VertexAddress__c linePhysOrigin = VertexAddress__c.getInstance(settingName + ' Line Phys');
            if (linePhysOrigin != null)
                addressMappingsToDelete.add(linePhysOrigin);
            
            delete addressMappingsToDelete;
        }
        
        List<VertexFieldMapping__c> fldMappingList = [SELECT ID FROM VertexFieldMapping__c WHERE ObjectMapping__c = :objMapID];
        delete fldMappingList;
    }

    @RemoteAction
    public static void Refresh(){}

    @RemoteAction
    public static List<String> getFilteredObjects(String filterString){
        transient List<String> targetObjNames;
        targetObjNames = new List<String>();
        
        for (String s : new List<String>(VertexCore.GDMap.keySet())){

            //Add object to list if creatable and updatable
            Schema.DescribeSObjectResult sObjResult = VertexCore.GDMap.get(s).getDescribe();

            if (!sObjResult.getName().contains('__Vertex') && !sObjResult.isCustomSetting() && sObjResult.isCreateable() && sObjResult.isUpdateable() &&
                (sObjResult.getName().containsIgnoreCase(filterString) || sObjResult.getLabel().containsIgnoreCase(filterString)))
                targetObjNames.add(sObjResult.getName());
        }
        return targetObjNames;
    }

    @RemoteAction
    public static List<String> getChildObjects(String parentObj){
        transient List<String> childObjJSON = new List<String>();   //List of JSON strings that contain child object name, parent lookup field, and child relationship name
        if (VertexCore.GDMap.containsKey(parentObj)){
            //This Parent Object exists

            for (ChildRelationship childRelationship : VertexCore.GDMap.get(parentObj).getDescribe().getChildRelationships()){
                String jsonStr =    '{"childObj": "' + childRelationship.getChildSObject() + '", ' + 
                                    '"parentLookup": "' + childRelationship.getField().getDescribe().getName() + '", ' + 
                                    '"relationshipName": "' + childRelationship.getRelationshipName() + '"}';
                childObjJSON.add(jsonStr);
            }
        }
        return childObjJSON;
    }
    
    @RemoteAction
    public static void AddAdditionalMapping(String itemMappingID, String objLevel, String mappingType, String targetLoc, String valueToWrite){
        if (mappingType == 'obj'){
            VertexObjectMapping__c itmMapping =  new VertexObjectMapping__c(ID = itemMappingID);
            itmMapping.put(targetLoc, valueToWrite);
            update itmMapping;
        } else if (mappingType == 'fld'){
            VertexFieldMapping__c fldSetting = new VertexFieldMapping__c(Name = targetLoc + ': ' + itemMappingID);
            fldSetting.SourceField__c = valueToWrite;
            fldSetting.ObjectMapping__c = itemMappingID;
            fldSetting.Type__c = objLevel;

            String levelPrefix = objLevel == 'transaction' ? 'Trans' : 'Line';
            String label = targetLoc.substringAfter(levelPrefix + ' ');     //For example, "Text 1" or "Number 4"
            fldSetting.Label__c = 'Flex ' + label.split(' ')[0] + ' Field ' + label.split(' ')[1];  //For example, "Flex Text Field 1" or "Flex Number Field 4"
            insert fldSetting;
        } else if (mappingType == 'dest'){
            VertexObjectMapping__c itmMapping = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :itemMappingID LIMIT 1];
            String objLevelLabel = objLevel == 'transaction' ? 'Trans' : 'Line';
            VertexAddress__c destinationMapping = VertexAddress__c.getInstance(itmMapping.Name + ' ' + objLevelLabel + ' Dest Map');
            destinationMapping.put(targetLoc, valueToWrite);
            update destinationMapping;
        } else if (mappingType == 'orig-admin'){
            VertexObjectMapping__c itmMapping = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :itemMappingID LIMIT 1];
            String objLevelLabel = objLevel == 'transaction' ? 'Trans' : 'Line';
            VertexAddress__c adminOriginAddr = VertexAddress__c.getInstance(itmMapping.Name + ' ' + objLevelLabel + ' Admin');
            adminOriginAddr.put(targetLoc, valueToWrite);
            update adminOriginAddr;
        } else if (mappingType == 'orig-phys'){
            VertexObjectMapping__c itmMapping = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :itemMappingID LIMIT 1];
            String objLevelLabel = objLevel == 'transaction' ? 'Trans' : 'Line';
            VertexAddress__c physOriginAddr = VertexAddress__c.getInstance(itmMapping.Name + ' ' + objLevelLabel + ' Phys');
            physOriginAddr.put(targetLoc, valueToWrite);
            update physOriginAddr;
        }
    }

    @RemoteAction
    public static void DeleteAdditionalMapping(String itemMappingID, String objLevel, String mappingType, String location){
        if (mappingType == 'obj'){
            VertexObjectMapping__c itmMapping =  new VertexObjectMapping__c(ID = itemMappingID);
            itmMapping.put(location, '');   //"location" is a field API name
            update itmMapping;
        } else if (mappingType == 'fld'){
            VertexFieldMapping__c fldSetting = new VertexFieldMapping__c(ID = location);    //"location" is an ID
            delete fldSetting;
        } else if (mappingType == 'dest'){
            VertexObjectMapping__c itmMapping = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :itemMappingID LIMIT 1];
            VertexAddress__c destMapping = VertexAddress__c.getInstance(itmMapping.Name + ' ' + objLevel + ' Dest Map');
            destMapping.put(location, '');   //"location" is a field API name
            update destMapping;
        } else if (mappingType == 'orig-admin'){
            VertexObjectMapping__c itmMapping = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :itemMappingID LIMIT 1];
            VertexAddress__c adminOriginAddr = VertexAddress__c.getInstance(itmMapping.Name + ' ' + objLevel + ' Admin');
            adminOriginAddr.put(location, '');  //"location" is a field API name
            update adminOriginAddr;
        } else if (mappingType == 'orig-phys'){
            VertexObjectMapping__c itmMapping = [SELECT Name FROM VertexObjectMapping__c WHERE ID = :itemMappingID LIMIT 1];
            VertexAddress__c physOriginAddr = VertexAddress__c.getInstance(itmMapping.Name + ' ' + objLevel + ' Phys');
            physOriginAddr.put(location, '');   //"location" is a field API name
            update physOriginAddr;
        }
    }

    @RemoteAction
    public static void ResetAllMappings(){
        //Delete existing
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values()){
            if (objMap.IsExtensionSetting__c != true)
                VertexSettingsController.DeleteItemMapping(objMap.ID);
        }
        
        //Restore defaults
        VertexDataInit di = new VertexDataInit();
        di.CreateVanilla();
    }

    public Map<String, List<AdditionalItemMapping>> getBoundAdditionalTransItmMaps(){
        Map<String, List<AdditionalItemMapping>> outputMap = new Map<String, List<AdditionalItemMapping>>();    //Custom Setting ID --> [Wrapper Objects]
        transient List<VertexObjectMapping__c> objMappingsPlusEmpty = new List<VertexObjectMapping__c>();
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
            if (objMap.IsExtensionSetting__c != true)
                objMappingsPlusEmpty.add(objMap);
        objMappingsPlusEmpty.add(new VertexObjectMapping__c());     //For the "New Mapping" button
        for (VertexObjectMapping__c objMap : objMappingsPlusEmpty){
            transient List<AdditionalItemMapping> wrapperList = new List<AdditionalItemMapping>();
            //First index is blank, to allow for new selections
            wrapperList.add(new AdditionalItemMapping(null, null, null, null));

            //Optional Mappings
            if (String.isNotBlank(objMap.CurrencyCode__c))
                wrapperList.add(new AdditionalItemMapping('Currency Code', 'obj', objMap.CurrencyCode__c, 'CurrencyCode__c'));
            if (String.isNotBlank(objMap.Posting_Date__c))
                wrapperList.add(new AdditionalItemMapping('Posting Date', 'obj', objMap.Posting_Date__c, 'Posting_Date__c'));
            if (String.isNotBlank(objMap.TaxRegistrationNumber__c))
                wrapperList.add(new AdditionalItemMapping('Tax Registration Number', 'obj', objMap.TaxRegistrationNumber__c, 'TaxRegistrationNumber__c'));
            if (String.isNotBlank(objMap.TransactionDeliveryTerm__c))
                wrapperList.add(new AdditionalItemMapping('Transaction Delivery Term', 'obj', objMap.TransactionDeliveryTerm__c, 'TransactionDeliveryTerm__c'));
            if (String.isNotBlank(objMap.ParentSourcePicklist__c))
                wrapperList.add(new AdditionalItemMapping('Transaction Physical Origin Field', 'obj', objMap.ParentSourcePicklist__c, 'ParentSourcePicklist__c'));
            if (String.isNotBlank(objMap.TransactionTaxPayer__c))
                wrapperList.add(new AdditionalItemMapping('Transaction Tax Payer', 'obj', objMap.TransactionTaxPayer__c, 'TransactionTaxPayer__c'));
            
            if (objMap.Name != null && objMap.Name.length() <= VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS){
                //Destination Mappings
                VertexAddress__c transDestMap = VertexAddress__c.getInstance(objMap.Name + ' Trans Dest Map');
                if (transDestMap != null){  //Should never be null
                    if (String.isNotBlank(transDestMap.Address1__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Address 1', 'dest', transDestMap.Address1__c, 'Address1__c'));
                    if (String.isNotBlank(transDestMap.Address2__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Address 2', 'dest', transDestMap.Address2__c, 'Address2__c'));
                    if (String.isNotBlank(transDestMap.City__c))
                        wrapperList.add(new AdditionalItemMapping('Destination City', 'dest', transDestMap.City__c, 'City__c'));
                    if (String.isNotBlank(transDestMap.Country__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Country', 'dest', transDestMap.Country__c, 'Country__c'));
                    if (String.isNotBlank(transDestMap.CustomerClassCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Customer Class Code', 'dest', transDestMap.CustomerClassCode__c, 'CustomerClassCode__c'));
                    if (String.isNotBlank(transDestMap.CustomerCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Customer Code', 'dest', transDestMap.CustomerCode__c, 'CustomerCode__c'));
                    if (String.isNotBlank(transDestMap.PostalCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Postal Code', 'dest', transDestMap.PostalCode__c, 'PostalCode__c'));
                    if (String.isNotBlank(transDestMap.State__c))
                        wrapperList.add(new AdditionalItemMapping('Destination State', 'dest', transDestMap.State__c, 'State__c'));
                    if (String.isNotBlank(transDestMap.TaxAreaID__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Tax Area ID', 'dest', transDestMap.TaxAreaID__c, 'TaxAreaID__c'));
                    if (String.isNotBlank(transDestMap.LocationCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Location Code', 'dest', transDestMap.LocationCode__c, 'LocationCode__c'));
                }
                //Admin Origin Address
                VertexAddress__c transAdminAddr = VertexAddress__c.getInstance(objMap.Name + ' Trans Admin');
                if (transAdminAddr != null){
                    if (String.isNotBlank(transAdminAddr.Address1__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Address 1', 'orig-admin', transAdminAddr.Address1__c, 'Address1__c'));
                    if (String.isNotBlank(transAdminAddr.Address2__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Address 2', 'orig-admin', transAdminAddr.Address2__c, 'Address2__c'));
                    if (String.isNotBlank(transAdminAddr.City__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin City', 'orig-admin', transAdminAddr.City__c, 'City__c'));
                    if (String.isNotBlank(transAdminAddr.Country__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Country', 'orig-admin', transAdminAddr.Country__c, 'Country__c'));
                    if (String.isNotBlank(transAdminAddr.PostalCode__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Postal Code', 'orig-admin', transAdminAddr.PostalCode__c, 'PostalCode__c'));
                    if (String.isNotBlank(transAdminAddr.State__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin State', 'orig-admin', transAdminAddr.State__c, 'State__c'));
                    if (String.isNotBlank(transAdminAddr.TaxAreaID__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Tax Area ID', 'orig-admin', transAdminAddr.TaxAreaID__c, 'TaxAreaID__c'));
                    if (String.isNotBlank(transAdminAddr.LocationCode__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Location Code', 'orig-admin', transAdminAddr.LocationCode__c, 'LocationCode__c'));
                }
                //Physical Origin Address
                VertexAddress__c transPhysAddr = VertexAddress__c.getInstance(objMap.Name + ' Trans Phys');
                if (transPhysAddr != null){
                    if (String.isNotBlank(transPhysAddr.Address1__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Address 1', 'orig-phys', transPhysAddr.Address1__c, 'Address1__c'));
                    if (String.isNotBlank(transPhysAddr.Address2__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Address 2', 'orig-phys', transPhysAddr.Address2__c, 'Address2__c'));
                    if (String.isNotBlank(transPhysAddr.City__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin City', 'orig-phys', transPhysAddr.City__c, 'City__c'));
                    if (String.isNotBlank(transPhysAddr.Country__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Country', 'orig-phys', transPhysAddr.Country__c, 'Country__c'));
                    if (String.isNotBlank(transPhysAddr.PostalCode__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Postal Code', 'orig-phys', transPhysAddr.PostalCode__c, 'PostalCode__c'));
                    if (String.isNotBlank(transPhysAddr.State__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin State', 'orig-phys', transPhysAddr.State__c, 'State__c'));
                    if (String.isNotBlank(transPhysAddr.TaxAreaID__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Tax Area ID', 'orig-phys', transPhysAddr.TaxAreaID__c, 'TaxAreaID__c'));
                    if (String.isNotBlank(transPhysAddr.LocationCode__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Location Code', 'orig-phys', transPhysAddr.LocationCode__c, 'LocationCode__c'));
                }
            }
            outputMap.put(objMap.ID, wrapperList);
        }
        return outputMap;
    }

    public Map<String, List<SelectOption>> getUnboundAdditionalTransItmMaps(){
        Map<String, List<SelectOption>> outputMap = new Map<String, List<SelectOption>>();    //Custom Setting ID --> [SelectOptions]
        transient List<VertexObjectMapping__c> objMappingsPlusEmpty = new List<VertexObjectMapping__c>();
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
            if (objMap.IsExtensionSetting__c != true)
                objMappingsPlusEmpty.add(objMap);
        objMappingsPlusEmpty.add(new VertexObjectMapping__c());     //For the "New Mapping" button
        for (VertexObjectMapping__c objMap : objMappingsPlusEmpty){
            transient List<SelectOption> optList = new List<SelectOption>();

            //Optional Mappings
            if (String.isBlank(objMap.CurrencyCode__c))
                optList.add(new SelectOption('obj: CurrencyCode__c', 'Currency Code'));
            if (String.isBlank(objMap.Posting_Date__c))
                optList.add(new SelectOption('obj: Posting_Date__c', 'Posting Date'));
            if (String.isBlank(objMap.TaxRegistrationNumber__c))
                optList.add(new SelectOption('obj: TaxRegistrationNumber__c', 'Tax Registration Number'));
            if (String.isBlank(objMap.TransactionDeliveryTerm__c))
                optList.add(new SelectOption('obj: TransactionDeliveryTerm__c', 'Transaction Delivery Term'));
            if (String.isBlank(objMap.ParentSourcePicklist__c))
                optList.add(new SelectOption('obj: ParentSourcePicklist__c', 'Transaction Physical Origin Field'));
            if (String.isBlank(objMap.TransactionTaxPayer__c))
                optList.add(new SelectOption('obj: TransactionTaxPayer__c', 'Transaction Tax Payer'));
            
            if (objMap.Name != null && objMap.Name.length() <= VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS){
                //Destination Mappings
                VertexAddress__c transDestMap = VertexAddress__c.getInstance(objMap.Name + ' Trans Dest Map');
                if (transDestMap != null){  //Should never be null
                    if (String.isBlank(transDestMap.Address1__c))
                        optList.add(new SelectOption('dest: Address1__c', 'Destination Address 1'));
                    if (String.isBlank(transDestMap.Address2__c))
                        optList.add(new SelectOption('dest: Address2__c', 'Destination Address 2'));
                    if (String.isBlank(transDestMap.City__c))
                        optList.add(new SelectOption('dest: City__c', 'Destination City'));
                    if (String.isBlank(transDestMap.Country__c))
                        optList.add(new SelectOption('dest: Country__c', 'Destination Country'));
                    if (String.isBlank(transDestMap.CustomerClassCode__c))
                        optList.add(new SelectOption('dest: CustomerClassCode__c', 'Destination Customer Class Code'));
                    if (String.isBlank(transDestMap.CustomerCode__c))
                        optList.add(new SelectOption('dest: CustomerCode__c', 'Destination Customer Code'));
                    if (String.isBlank(transDestMap.PostalCode__c))
                        optList.add(new SelectOption('dest: PostalCode__c', 'Destination Postal Code'));
                    if (String.isBlank(transDestMap.State__c))
                        optList.add(new SelectOption('dest: State__c', 'Destination State'));
                    if (String.isBlank(transDestMap.TaxAreaID__c))
                        optList.add(new SelectOption('dest: TaxAreaID__c', 'Destination Tax Area ID'));
                    if (String.isBlank(transDestMap.LocationCode__c))
                        optList.add(new SelectOption('dest: LocationCode__c', 'Destination Location Code'));
                }
                //Admin Origin Address
                VertexAddress__c transAdminAddr = VertexAddress__c.getInstance(objMap.Name + ' Trans Admin');
                if (transAdminAddr != null){
                    if (String.isBlank(transAdminAddr.Address1__c))
                        optList.add(new SelectOption('orig-admin: Address1__c', 'Admin Origin Address 1'));
                    if (String.isBlank(transAdminAddr.Address2__c))
                        optList.add(new SelectOption('orig-admin: Address2__c', 'Admin Origin Address 2'));
                    if (String.isBlank(transAdminAddr.City__c))
                        optList.add(new SelectOption('orig-admin: City__c', 'Admin Origin City'));
                    if (String.isBlank(transAdminAddr.Country__c))
                        optList.add(new SelectOption('orig-admin: Country__c', 'Admin Origin Country'));
                    if (String.isBlank(transAdminAddr.PostalCode__c))
                        optList.add(new SelectOption('orig-admin: PostalCode__c', 'Admin Origin Postal Code'));
                    if (String.isBlank(transAdminAddr.State__c))
                        optList.add(new SelectOption('orig-admin: State__c', 'Admin Origin State'));
                    if (String.isBlank(transAdminAddr.TaxAreaID__c))
                        optList.add(new SelectOption('orig-admin: TaxAreaID__c', 'Admin Origin Tax Area ID'));
                    if (String.isBlank(transAdminAddr.LocationCode__c))
                        optList.add(new SelectOption('orig-admin: LocationCode__c', 'Admin Origin Location Code'));
                }
                //Physical Origin Address
                VertexAddress__c transPhysAddr = VertexAddress__c.getInstance(objMap.Name + ' Trans Phys');
                if (transPhysAddr != null){
                    if (String.isBlank(transPhysAddr.Address1__c))
                        optList.add(new SelectOption('orig-phys: Address1__c', 'Physical Origin Address 1'));
                    if (String.isBlank(transPhysAddr.Address2__c))
                        optList.add(new SelectOption('orig-phys: Address2__c', 'Physical Origin Address 2'));
                    if (String.isBlank(transPhysAddr.City__c))
                        optList.add(new SelectOption('orig-phys: City__c', 'Physical Origin City'));
                    if (String.isBlank(transPhysAddr.Country__c))
                        optList.add(new SelectOption('orig-phys: Country__c', 'Physical Origin Country'));
                    if (String.isBlank(transPhysAddr.PostalCode__c))
                        optList.add(new SelectOption('orig-phys: PostalCode__c', 'Physical Origin Postal Code'));
                    if (String.isBlank(transPhysAddr.State__c))
                        optList.add(new SelectOption('orig-phys: State__c', 'Physical Origin State'));
                    if (String.isBlank(transPhysAddr.TaxAreaID__c))
                        optList.add(new SelectOption('orig-phys: TaxAreaID__c', 'Physical Origin Tax Area ID'));
                    if (String.isBlank(transPhysAddr.LocationCode__c))
                        optList.add(new SelectOption('orig-phys: LocationCode__c', 'Physical Origin Location Code'));
                }
            }
            outputMap.put(objMap.ID, optList);
        }
        return outputMap;
    }

    public Map<String, List<AdditionalItemMapping>> getBoundAdditionalLineItmMaps(){
        Map<String, List<AdditionalItemMapping>> outputMap = new Map<String, List<AdditionalItemMapping>>();    //Custom Setting ID --> [Wrapper Objects]
        transient List<VertexObjectMapping__c> objMappingsPlusEmpty = new List<VertexObjectMapping__c>();
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
            if (objMap.IsExtensionSetting__c != true)
                objMappingsPlusEmpty.add(objMap);
        objMappingsPlusEmpty.add(new VertexObjectMapping__c());     //For the "New Mapping" button
        for (VertexObjectMapping__c objMap : objMappingsPlusEmpty){
            transient List<AdditionalItemMapping> wrapperList = new List<AdditionalItemMapping>();
            //First index is blank, to allow for new selections
            wrapperList.add(new AdditionalItemMapping(null, null, null, null));

            //Optional Mappings
            if (String.isNotBlank(objMap.CommodityCode__c))
                wrapperList.add(new AdditionalItemMapping('Commodity Code', 'obj', objMap.CommodityCode__c, 'CommodityCode__c'));
            if (String.isNotBlank(objMap.CommodityCodeType__c))
                wrapperList.add(new AdditionalItemMapping('Commodity Code Type', 'obj', objMap.CommodityCodeType__c, 'CommodityCodeType__c'));
            if (String.isNotBlank(objMap.InputTotalTax__c))
                wrapperList.add(new AdditionalItemMapping('Input Total Tax', 'obj', objMap.InputTotalTax__c, 'InputTotalTax__c'));
            if (String.isNotBlank(objMap.InvoiceTextCodes__c))
                wrapperList.add(new AdditionalItemMapping('Invoice Text Codes', 'obj', objMap.InvoiceTextCodes__c, 'InvoiceTextCodes__c'));
            if (String.isNotBlank(objMap.LineDeliveryTerm__c))
                wrapperList.add(new AdditionalItemMapping('Line Delivery Term', 'obj', objMap.LineDeliveryTerm__c, 'LineDeliveryTerm__c'));
            if (String.isNotBlank(objMap.ChildSourcePicklist__c))
                wrapperList.add(new AdditionalItemMapping('Line Physical Origin Field', 'obj', objMap.ChildSourcePicklist__c, 'ChildSourcePicklist__c'));
            if (String.isNotBlank(objMap.ItemTaxNotesField__c))
                wrapperList.add(new AdditionalItemMapping('Line Tax Details Output', 'obj', objMap.ItemTaxNotesField__c, 'ItemTaxNotesField__c'));
            if (String.isNotBlank(objMap.ItemTaxPayerField__c))
                wrapperList.add(new AdditionalItemMapping('Line Tax Payer', 'obj', objMap.ItemTaxPayerField__c, 'ItemTaxPayerField__c'));
            if (String.isNotBlank(objMap.ItemClassField__c))
                wrapperList.add(new AdditionalItemMapping('Product Class', 'obj', objMap.ItemClassField__c, 'ItemClassField__c'));
            if (String.isNotBlank(objMap.ItemNameField__c))
                wrapperList.add(new AdditionalItemMapping('Product Code', 'obj', objMap.ItemNameField__c, 'ItemNameField__c'));
            if (String.isNotBlank(objMap.TaxCode__c))
                wrapperList.add(new AdditionalItemMapping('Tax Code', 'obj', objMap.TaxCode__c, 'TaxCode__c'));
            if (String.isNotBlank(objMap.VertexTaxCode__c))
                wrapperList.add(new AdditionalItemMapping('Vertex Tax Code', 'obj', objMap.VertexTaxCode__c, 'VertexTaxCode__c'));
            if (String.isNotBlank(objMap.SuppressTaxCallout__c))
                wrapperList.add(new AdditionalItemMapping('Suppress Tax Callout', 'obj', objMap.SuppressTaxCallout__c, 'SuppressTaxCallout__c'));
            if (String.isNotBlank(objMap.TaxIncludedIndicator__c))
                wrapperList.add(new AdditionalItemMapping('Tax Included Indicator', 'obj', objMap.TaxIncludedIndicator__c, 'TaxIncludedIndicator__c'));
            if (String.isNotBlank(objMap.UsageCode__c))
                wrapperList.add(new AdditionalItemMapping('Usage Code', 'obj', objMap.UsageCode__c, 'UsageCode__c'));
            if (String.isNotBlank(objMap.UsageClass__c))
                wrapperList.add(new AdditionalItemMapping('Usage Class', 'obj', objMap.UsageClass__c, 'UsageClass__c'));               
            if (String.isNotBlank(objMap.TaxCalloutStatus__c))
                wrapperList.add(new AdditionalItemMapping('Tax Callout Status', 'obj', objMap.TaxCalloutStatus__c, 'TaxCalloutStatus__c'));
            
            if (objMap.Name != null && objMap.Name.length() <= VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS){
                //Destination Mappings
                VertexAddress__c lineDestMap = VertexAddress__c.getInstance(objMap.Name + ' Line Dest Map');
                if (lineDestMap != null){  //Should never be null
                    if (String.isNotBlank(lineDestMap.Address1__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Address 1', 'dest', lineDestMap.Address1__c, 'Address1__c'));
                    if (String.isNotBlank(lineDestMap.Address2__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Address 2', 'dest', lineDestMap.Address2__c, 'Address2__c'));
                    if (String.isNotBlank(lineDestMap.City__c))
                        wrapperList.add(new AdditionalItemMapping('Destination City', 'dest', lineDestMap.City__c, 'City__c'));
                    if (String.isNotBlank(lineDestMap.Country__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Country', 'dest', lineDestMap.Country__c, 'Country__c'));
                    if (String.isNotBlank(lineDestMap.CustomerClassCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Customer Class Code', 'dest', lineDestMap.CustomerClassCode__c, 'CustomerClassCode__c'));
                    if (String.isNotBlank(lineDestMap.CustomerCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Customer Code', 'dest', lineDestMap.CustomerCode__c, 'CustomerCode__c'));
                    if (String.isNotBlank(lineDestMap.PostalCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Postal Code', 'dest', lineDestMap.PostalCode__c, 'PostalCode__c'));
                    if (String.isNotBlank(lineDestMap.State__c))
                        wrapperList.add(new AdditionalItemMapping('Destination State', 'dest', lineDestMap.State__c, 'State__c'));
                    if (String.isNotBlank(lineDestMap.TaxAreaID__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Tax Area ID', 'dest', lineDestMap.TaxAreaID__c, 'TaxAreaID__c'));
                    if (String.isNotBlank(lineDestMap.LocationCode__c))
                        wrapperList.add(new AdditionalItemMapping('Destination Location Code', 'dest', lineDestMap.LocationCode__c, 'LocationCode__c'));
                }
                //Admin Origin Address
                VertexAddress__c lineAdminAddr = VertexAddress__c.getInstance(objMap.Name + ' Line Admin');
                if (lineAdminAddr != null){
                    if (String.isNotBlank(lineAdminAddr.Address1__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Address 1', 'orig-admin', lineAdminAddr.Address1__c, 'Address1__c'));
                    if (String.isNotBlank(lineAdminAddr.Address2__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Address 2', 'orig-admin', lineAdminAddr.Address2__c, 'Address2__c'));
                    if (String.isNotBlank(lineAdminAddr.City__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin City', 'orig-admin', lineAdminAddr.City__c, 'City__c'));
                    if (String.isNotBlank(lineAdminAddr.Country__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Country', 'orig-admin', lineAdminAddr.Country__c, 'Country__c'));
                    if (String.isNotBlank(lineAdminAddr.PostalCode__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Postal Code', 'orig-admin', lineAdminAddr.PostalCode__c, 'PostalCode__c'));
                    if (String.isNotBlank(lineAdminAddr.State__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin State', 'orig-admin', lineAdminAddr.State__c, 'State__c'));
                    if (String.isNotBlank(lineAdminAddr.TaxAreaID__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Tax Area ID', 'orig-admin', lineAdminAddr.TaxAreaID__c, 'TaxAreaID__c'));
                    if (String.isNotBlank(lineAdminAddr.LocationCode__c))
                        wrapperList.add(new AdditionalItemMapping('Admin Origin Location Code', 'orig-admin', lineAdminAddr.LocationCode__c, 'LocationCode__c'));
                }
                //Physical Origin Address
                VertexAddress__c linePhysAddr = VertexAddress__c.getInstance(objMap.Name + ' Line Phys');
                if (linePhysAddr != null){
                    if (String.isNotBlank(linePhysAddr.Address1__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Address 1', 'orig-phys', linePhysAddr.Address1__c, 'Address1__c'));
                    if (String.isNotBlank(linePhysAddr.Address2__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Address 2', 'orig-phys', linePhysAddr.Address2__c, 'Address2__c'));
                    if (String.isNotBlank(linePhysAddr.City__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin City', 'orig-phys', linePhysAddr.City__c, 'City__c'));
                    if (String.isNotBlank(linePhysAddr.Country__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Country', 'orig-phys', linePhysAddr.Country__c, 'Country__c'));
                    if (String.isNotBlank(linePhysAddr.PostalCode__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Postal Code', 'orig-phys', linePhysAddr.PostalCode__c, 'PostalCode__c'));
                    if (String.isNotBlank(linePhysAddr.State__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin State', 'orig-phys', linePhysAddr.State__c, 'State__c'));
                    if (String.isNotBlank(linePhysAddr.TaxAreaID__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Tax Area ID', 'orig-phys', linePhysAddr.TaxAreaID__c, 'TaxAreaID__c'));
                    if (String.isNotBlank(linePhysAddr.LocationCode__c))
                        wrapperList.add(new AdditionalItemMapping('Physical Origin Location Code', 'orig-phys', linePhysAddr.LocationCode__c, 'LocationCode__c'));
                }
            }
            
            transient VertexFieldMapping__c fetchFldSetting;    //Name format is "Line [DataType] [N]: [ObjectMappingID]"
            //Flex Mappings
            for (Integer i = 1; i <= 25; i++){
                fetchFldSetting = VertexFieldMapping__c.getInstance('Line Text ' + i + ': ' + objMap.ID);
                if (fetchFldSetting != null && String.isNotBlank(fetchFldSetting.SourceField__c))
                    wrapperList.add(new AdditionalItemMapping('Flex Text Field ' + i, 'fld', fetchFldSetting.SourceField__c, fetchFldSetting.ID));
            }
            
            for (Integer i = 1; i <= 10; i++){
                fetchFldSetting = VertexFieldMapping__c.getInstance('Line Number ' + i + ': ' + objMap.ID);
                if (fetchFldSetting != null && String.isNotBlank(fetchFldSetting.SourceField__c))
                    wrapperList.add(new AdditionalItemMapping('Flex Number Field ' + i, 'fld', fetchFldSetting.SourceField__c, fetchFldSetting.ID));
            }
            
            for (Integer i = 1; i <= 5; i++){
                fetchFldSetting = VertexFieldMapping__c.getInstance('Line Date ' + i + ': ' + objMap.ID);
                if (fetchFldSetting != null && String.isNotBlank(fetchFldSetting.SourceField__c))
                    wrapperList.add(new AdditionalItemMapping('Flex Date Field ' + i, 'fld', fetchFldSetting.SourceField__c, fetchFldSetting.ID));
            }
            outputMap.put(objMap.ID, wrapperList);
        }
        return outputMap;
    }

    public Map<String, List<SelectOption>> getUnboundAdditionalLineItmMaps(){
        Map<String, List<SelectOption>> outputMap = new Map<String, List<SelectOption>>();    //Custom Setting ID --> [SelectOptions]
        transient List<VertexObjectMapping__c> objMappingsPlusEmpty = new List<VertexObjectMapping__c>();
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
            if (objMap.IsExtensionSetting__c != true)
                objMappingsPlusEmpty.add(objMap);
        objMappingsPlusEmpty.add(new VertexObjectMapping__c());     //For the "New Mapping" button
        for (VertexObjectMapping__c objMap : objMappingsPlusEmpty){
            transient List<SelectOption> optList = new List<SelectOption>();

            //Optional Mappings
            if (String.isBlank(objMap.CommodityCode__c))
                optList.add(new SelectOption('obj: CommodityCode__c', 'Commodity Code'));
            if (String.isBlank(objMap.CommodityCodeType__c))
                optList.add(new SelectOption('obj: CommodityCodeType__c', 'Commodity Code Type'));
            if (String.isBlank(objMap.InputTotalTax__c))
                optList.add(new SelectOption('obj: InputTotalTax__c', 'Input Total Tax'));
            if (String.isBlank(objMap.InvoiceTextCodes__c))
                optList.add(new SelectOption('obj: InvoiceTextCodes__c', 'Invoice Text Codes'));
            if (String.isBlank(objMap.LineDeliveryTerm__c))
                optList.add(new SelectOption('obj: LineDeliveryTerm__c', 'Line Delivery Term'));
            if (String.isBlank(objMap.ChildSourcePicklist__c))
                optList.add(new SelectOption('obj: ChildSourcePicklist__c', 'Line Physical Origin Field'));
            if (String.isBlank(objMap.ItemTaxNotesField__c))
                optList.add(new SelectOption('obj: ItemTaxNotesField__c', 'Line Tax Details Output'));
            if (String.isBlank(objMap.ItemTaxPayerField__c))
                optList.add(new SelectOption('obj: ItemTaxPayerField__c', 'Line Tax Payer'));
            if (String.isBlank(objMap.ItemClassField__c))
                optList.add(new SelectOption('obj: ItemClassField__c', 'Product Class'));
            if (String.isBlank(objMap.ItemNameField__c))
                optList.add(new SelectOption('obj: ItemNameField__c', 'Product Code'));
            if (String.isBlank(objMap.TaxCode__c))
                optList.add(new SelectOption('obj: TaxCode__c', 'Tax Code'));
            if (String.isBlank(objMap.VertexTaxCode__c))
                optList.add(new SelectOption('obj: VertexTaxCode__c', 'Vertex Tax Code'));    
            if (String.isBlank(objMap.SuppressTaxCallout__c))
                optList.add(new SelectOption('obj: SuppressTaxCallout__c', 'Suppress Tax Callout'));
            if(String.isBlank(objMap.TaxIncludedIndicator__c))
                optList.add(new SelectOption('obj: TaxIncludedIndicator__c', 'Tax Included Indicator'));
            if(String.isBlank(objMap.UsageCode__c))
                optList.add(new SelectOption('obj: UsageCode__c', 'Usage Code'));
            if(String.isBlank(objMap.UsageClass__c))
                optList.add(new SelectOption('obj: UsageClass__c', 'Usage Class'));
            if (String.isBlank(objMap.TaxCalloutStatus__c))
                optList.add(new SelectOption('obj: TaxCalloutStatus__c', 'Tax Callout Status'));
            
            if (objMap.Name != null && objMap.Name.length() <= VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS){
                //Destination Mappings
                VertexAddress__c lineDestMap = VertexAddress__c.getInstance(objMap.Name + ' Line Dest Map');
                if (lineDestMap != null){  //Should never be null
                    if (String.isBlank(lineDestMap.Address1__c))
                        optList.add(new SelectOption('dest: Address1__c', 'Destination Address 1'));
                    if (String.isBlank(lineDestMap.Address2__c))
                        optList.add(new SelectOption('dest: Address2__c', 'Destination Address 2'));
                    if (String.isBlank(lineDestMap.City__c))
                        optList.add(new SelectOption('dest: City__c', 'Destination City'));
                    if (String.isBlank(lineDestMap.Country__c))
                        optList.add(new SelectOption('dest: Country__c', 'Destination Country'));
                    if (String.isBlank(lineDestMap.CustomerClassCode__c))
                        optList.add(new SelectOption('dest: CustomerClassCode__c', 'Destination Customer Class Code'));
                    if (String.isBlank(lineDestMap.CustomerCode__c))
                        optList.add(new SelectOption('dest: CustomerCode__c', 'Destination Customer Code'));
                    if (String.isBlank(lineDestMap.PostalCode__c))
                        optList.add(new SelectOption('dest: PostalCode__c', 'Destination Postal Code'));
                    if (String.isBlank(lineDestMap.State__c))
                        optList.add(new SelectOption('dest: State__c', 'Destination State'));
                    if (String.isBlank(lineDestMap.TaxAreaID__c))
                        optList.add(new SelectOption('dest: TaxAreaID__c', 'Destination Tax Area ID'));
                    if (String.isBlank(lineDestMap.LocationCode__c))
                        optList.add(new SelectOption('dest: LocationCode__c', 'Destination Location Code'));
                }
                //Admin Origin Address
                VertexAddress__c lineAdminAddr = VertexAddress__c.getInstance(objMap.Name + ' Line Admin');
                if (lineAdminAddr != null){
                    if (String.isBlank(lineAdminAddr.Address1__c))
                        optList.add(new SelectOption('orig-admin: Address1__c', 'Admin Origin Address 1'));
                    if (String.isBlank(lineAdminAddr.Address2__c))
                        optList.add(new SelectOption('orig-admin: Address2__c', 'Admin Origin Address 2'));
                    if (String.isBlank(lineAdminAddr.City__c))
                        optList.add(new SelectOption('orig-admin: City__c', 'Admin Origin City'));
                    if (String.isBlank(lineAdminAddr.Country__c))
                        optList.add(new SelectOption('orig-admin: Country__c', 'Admin Origin Country'));
                    if (String.isBlank(lineAdminAddr.PostalCode__c))
                        optList.add(new SelectOption('orig-admin: PostalCode__c', 'Admin Origin Postal Code'));
                    if (String.isBlank(lineAdminAddr.State__c))
                        optList.add(new SelectOption('orig-admin: State__c', 'Admin Origin State'));
                    if (String.isBlank(lineAdminAddr.TaxAreaID__c))
                        optList.add(new SelectOption('orig-admin: TaxAreaID__c', 'Admin Origin Tax Area ID'));
                    if (String.isBlank(lineAdminAddr.LocationCode__c))
                        optList.add(new SelectOption('orig-admin: LocationCode__c', 'Admin Origin Location Code'));
                }
                //Physical Origin Address
                VertexAddress__c linePhysAddr = VertexAddress__c.getInstance(objMap.Name + ' Line Phys');
                if (linePhysAddr != null){
                    if (String.isBlank(linePhysAddr.Address1__c))
                        optList.add(new SelectOption('orig-phys: Address1__c', 'Physical Origin Address 1'));
                    if (String.isBlank(linePhysAddr.Address2__c))
                        optList.add(new SelectOption('orig-phys: Address2__c', 'Physical Origin Address 2'));
                    if (String.isBlank(linePhysAddr.City__c))
                        optList.add(new SelectOption('orig-phys: City__c', 'Physical Origin City'));
                    if (String.isBlank(linePhysAddr.Country__c))
                        optList.add(new SelectOption('orig-phys: Country__c', 'Physical Origin Country'));
                    if (String.isBlank(linePhysAddr.PostalCode__c))
                        optList.add(new SelectOption('orig-phys: PostalCode__c', 'Physical Origin Postal Code'));
                    if (String.isBlank(linePhysAddr.State__c))
                        optList.add(new SelectOption('orig-phys: State__c', 'Physical Origin State'));
                    if (String.isBlank(linePhysAddr.TaxAreaID__c))
                        optList.add(new SelectOption('orig-phys: TaxAreaID__c', 'Physical Origin Tax Area ID'));
                    if (String.isBlank(linePhysAddr.LocationCode__c))
                        optList.add(new SelectOption('orig-phys: LocationCode__c', 'Physical Origin Location Code'));
                }
            }

            transient VertexFieldMapping__c fetchFldSetting;    //Name format is "Line [DataType] [N]: [ObjectMappingID]"
            //Flex Mappings
            for (Integer i = 1; i <= 25; i++){
                fetchFldSetting = VertexFieldMapping__c.getInstance('Line Text ' + i + ': ' + objMap.ID);
                if (fetchFldSetting == null || (fetchFldSetting != null && String.isBlank(fetchFldSetting.SourceField__c)))
                    optList.add(new SelectOption('fld: Line Text ' + i, 'Flex Text Field ' + i));
            }
            
            for (Integer i = 1; i <= 10; i++){
                fetchFldSetting = VertexFieldMapping__c.getInstance('Line Number ' + i + ': ' + objMap.ID);
                if (fetchFldSetting == null || (fetchFldSetting != null && String.isBlank(fetchFldSetting.SourceField__c)))
                    optList.add(new SelectOption('fld: Line Number ' + i, 'Flex Number Field ' + i));
            }
            
            for (Integer i = 1; i <= 5; i++){
                fetchFldSetting = VertexFieldMapping__c.getInstance('Line Date ' + i + ': ' + objMap.ID);
                if (fetchFldSetting == null || (fetchFldSetting != null && String.isBlank(fetchFldSetting.SourceField__c)))
                    optList.add(new SelectOption('fld: Line Date ' + i, 'Flex Date Field ' + i));
            }
            outputMap.put(objMap.ID, optList);
        }
        return outputMap;
    }

    @RemoteAction
    public static LIST<objContainer> UpdateFldList(String obj) {
        transient LIST<objContainer> tempContainerList = new LIST<objContainer>();
        if(VertexCore.GDMap.get(obj)!=null){
            transient Schema.SObjectType objSchema = VertexCore.GDMap.get(obj);
            for(String fieldKey : objSchema.getDescribe().fields.getMap().keySet()){
                transient Schema.DescribeFieldResult fldDesc = objSchema.getDescribe().fields.getMap().get(fieldKey).getDescribe();
                transient objContainer tempContainer = new objContainer();
                transient String fieldNamespace = fldDesc.getName().remove(fldDesc.getLocalName()).removeEnd('__');
                tempContainer.api = fldDesc.getName();
                tempContainer.name = fldDesc.getLabel() + ((String.isBlank(fieldNamespace)) ? '' : ' (' + fieldNamespace +')');
                tempContainer.dataType = String.ValueOf(fldDesc.getType()).toLowerCase();
                if(tempContainerList.size()==999){
                    tempContainer.api = '';
                    tempContainer.name = '-- Too Many Objects to Show --';
                }
                if(tempContainerList.size()<1000)
                    tempContainerList.add(tempContainer);
            }
        }
        tempContainerList.sort();
        return tempContainerList;
    }

    public class ObjectMapSetting {
        public String settingID {get; set;}
        public String mappingName {get { 
                                        if (mappingName != null && mappingName.length() > VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS)
                                            mappingName = mappingName.substring(0, VertexSettingsController.OBJECT_MAPPING_NAME_MAX_CHARS + 1);
                                        return mappingName;
                                    } set;}
        public String xmlMessage {get; set;}
        public String transactionType {get; set;}
        public String parentObj {get; set;}
        public String lineObj {get; set;}
        public String parentLookup {get; set;}
        public String relationshipName {get; set;}
        public String transactionTaxAmount {get; set;}
        public String transactionDate {get; set;}
        public String documentNumber {get; set;}
        public String taxAmount {get; set;}
        public String extendedPrice {get; set;}
        public String quantity {get; set;}

        public Boolean IsAnyFieldEmpty(){
            Boolean result = false;
            if (
                String.isBlank(mappingName) ||
                String.isBlank(xmlMessage) ||
                String.isBlank(transactionType) ||
                String.isBlank(parentObj) ||
                String.isBlank(lineObj) ||
                String.isBlank(parentLookup) ||
                String.isBlank(relationshipName) ||
                String.isBlank(transactionDate) ||
                String.isBlank(documentNumber) ||
                String.isBlank(taxAmount) ||
                String.isBlank(extendedPrice) ||
                String.isBlank(quantity)
            )
                result = true;
            
            return result;
        }
    }

    public class AdditionalItemMapping {
        public String label {get; set;}     //i.e. Product Class, Line Tax Payer, Flex Text Field 1, Flex Date Field 5, etc
        public String settingType {get; set;}   //"obj": Save to VertexObjectMapping__c, "fld": Save to VertexFieldMapping__c
        public String sourceField {get; set;}
        public String settingLoc {get; set;}   //For "obj", "dest", and "orig": API name of the field to write on VertexObjectMapping__c. For "fld": Custom Setting ID.

        public AdditionalItemMapping(String theLabel, String theSettingType, String theSourceField, String theSettingLocation){
            label = theLabel;
            settingType = theSettingType;
            sourceField = thesourceField;
            settingLoc = theSettingLocation;
        }
    } 

    //============================================================
    //  END ITEM MAPPINGS SECTION
    //============================================================

    public static MAP<String, VertexObjectMapping__c> ObjMappings { 
        get{
            if (ObjMappings==null){
                ObjMappings = new MAP<String, VertexObjectMapping__c>();
                for (String objMapID : VertexCore.ObjectMappings.keySet())
                    if (VertexCore.ObjectMappings.get(objMapID).IsExtensionSetting__c != true)
                        ObjMappings.put(objMapID, VertexCore.ObjectMappings.get(objMapID));
            }
            return ObjMappings;
        }
        set;
    }

    //  Variables used in the parent/child configurations
    public Static LIST<objContainer> ObjectList = new LIST<objContainer>();

    public Static LIST<objContainer> estTransObjs = new LIST<objContainer>();
    
    public Static LIST<objContainer> orderTransObjs = new LIST<objContainer>();
    
    public Static LIST<objContainer> invTransObjs = new LIST<objContainer>();

    public LIST<objContainer> getObjectList(){
        return VertexSettingsController.ObjectList;
    }

    public LIST<objContainer> getestTransObjs(){
        return VertexSettingsController.estTransObjs;
    }

    public LIST<objContainer> getorderTransObjs(){
        return VertexSettingsController.orderTransObjs;
    }

    public LIST<objContainer> getinvTransObjs(){
        return VertexSettingsController.invTransObjs;
    }

    public Static LIST<objContainer> EstimateParentFldList = new LIST<objContainer>();
    public Static LIST<objContainer> estLineFldList = new LIST<objContainer>();
    public Static LIST<objContainer> OrderParentFldList = new LIST<objContainer>();
    public Static LIST<objContainer> orderLineFldList = new LIST<objContainer>();
    public Static LIST<objContainer> InvoiceParentFldList = new LIST<objContainer>();
    public Static LIST<objContainer> invLineFldList = new LIST<objContainer>();

    public LIST<objContainer> getEstimateParentFldList(){
        return VertexSettingsController.EstimateParentFldList;
    }
    public LIST<objContainer> getestLineFldList(){
        return VertexSettingsController.estLineFldList;
    }
    public LIST<objContainer> getOrderParentFldList(){
        return VertexSettingsController.OrderParentFldList;
    }
    public LIST<objContainer> getorderLineFldList(){
        return VertexSettingsController.orderLineFldList;
    }
    public LIST<objContainer> getInvoiceParentFldList(){
        return VertexSettingsController.InvoiceParentFldList;
    }
    public LIST<objContainer> getinvLineFldList(){
        return VertexSettingsController.invLineFldList;
    }

    //  Constructor
    public VertexSettingsController() {
        //  Next bit populates the AddressList LIST with admin, def, then any remaining records that exist
        AddressList = new LIST<VertexAddress__c>();
        RefreshAddresses();
    }

    public static void testObjMappings(){
        if(ObjMappings.get('Estimate')!=null && !String.isEmpty(ObjMappings.get('Estimate').ParentSObject__c)){
            estTransObjs = updateObjList('estTransObj', ObjMappings.get('Estimate').ParentSObject__c);
            EstimateParentFldList = getAddressFieldOptions(ObjMappings.get('Estimate').ParentSObject__c);
        }
        if(ObjMappings.get('Estimate')!=null && !String.isEmpty(ObjMappings.get('Estimate').ChildSObject__c)){
            estLineFldList = getAddressFieldOptions(ObjMappings.get('Estimate').ChildSObject__c);
        }
        
        if(ObjMappings.get('Order')!=null && !String.isEmpty(ObjMappings.get('Order').ParentSObject__c)){
            orderTransObjs = updateObjList('orderTransObj', ObjMappings.get('Order').ParentSObject__c);
            OrderParentFldList = getAddressFieldOptions(ObjMappings.get('Order').ParentSObject__c);
        }
        if(ObjMappings.get('Order')!=null && !String.isEmpty(ObjMappings.get('Order').ChildSObject__c)){
            orderLineFldList = getAddressFieldOptions(ObjMappings.get('Order').ChildSObject__c);
        }
        
        if(ObjMappings.get('Invoice')!=null && !String.isEmpty(ObjMappings.get('Invoice').ParentSObject__c)){
            invTransObjs = updateObjList('invTransObj', ObjMappings.get('Invoice').ParentSObject__c);
            InvoiceParentFldList = getAddressFieldOptions(ObjMappings.get('Invoice').ParentSObject__c);

        }
        if(ObjMappings.get('Invoice')!=null && !String.isEmpty(ObjMappings.get('Invoice').ChildSObject__c)){
            invLineFldList = getAddressFieldOptions(ObjMappings.get('Invoice').ChildSObject__c);
        }
    }

    @RemoteAction
    public static LIST<String> getMappingOptions(String addressName, String filterString){
        transient LIST<String> tempReturnList;
        if(estTransObjs.size()==0 && orderTransObjs.size()==0 && invTransObjs.size()==0)
            VertexSettingsController.testObjMappings();

        transient LIST<objContainer> tempContainers;
        tempReturnList = new LIST<String>();
        if(addressName=='Estimate Trans Dest Map'){
            tempContainers = EstimateParentFldList;
        }
        else if(addressName=='Estimate Line Dest Map'){
            tempContainers = estLineFldList;
        }
        else if(addressName=='Order Trans Dest Map'){
            tempContainers = OrderParentFldList;
        }
        else if(addressName=='Order Line Dest Map'){
            tempContainers = orderLineFldList;
        }
        else if(addressName=='Invoice Trans Dest Map'){
            tempContainers = InvoiceParentFldList;
        }
        else if(addressName=='Invoice Line Dest Map'){
            tempContainers = invLineFldList;
        }

        tempContainers.sort();
        for(objContainer objCon : tempContainers){
            if (objCon.api.contains(filterString))
                tempReturnList.add(objCon.api);
        }
        return tempReturnList;
    }

    //  Returns an updated list of Addresses stored in the VertexAddress__c Custom setting, ordering Admin and Default first
    public void RefreshAddresses(){
        transient LIST<VertexAddress__c> addrList = new LIST<VertexAddress__c>();

        transient VertexAddress__c newAddr;
        transient MAP<String,VertexAddress__c> nameToAddrMap = VertexAddress__c.getAll();
        if (nameToAddrMap.keySet().contains('Administrative Origin Address')){
            addrList.add(nameToAddrMap.get('Administrative Origin Address'));
        } else {
            newAddr = new VertexAddress__c();
            newAddr.name = 'Administrative Origin Address';
            addrList.add(newAddr);
        }

        if (nameToAddrMap.keySet().contains('Default Physical Origin Address')){
            addrList.add(nameToAddrMap.get('Default Physical Origin Address'));
        } else {
            newAddr = new VertexAddress__c();
            newAddr.name = 'Default Physical Origin Address';
            addrList.add(newAddr);
        }

        transient SET<String> includedAddresses = new SET<String>{'Administrative Origin Address', 'Default Physical Origin Address'};

        for (String addrName : nameToAddrMap.keySet()){
            if (addrName.endsWith('Dest Map') || addrName.endsWith('Trans Admin') || addrName.endsWith('Line Admin') || addrName.endsWith('Trans Phys') || addrName.endsWith('Line Phys'))
                continue;
            
            if (addrName != 'Default Physical Origin Address' && addrName != 'Administrative Origin Address'){
                addrList.add(nameToAddrMap.get(addrName));
                includedAddresses.add(addrName);
            }
        }
        AddressList = addrList;
    }

    // Remoting method called to verify all the required fields in the address 
    // are filled in before sending the request
    @RemoteAction
    public static Boolean AddressIsComplete(String addyName) {
        transient VertexProtectedSettings__c config = VertexCore.ActiveSettings;
        transient VertexAddress__c addyToCheck = VertexAddress__c.getValues(addyName);

        //Leave out state and postal code, for international address support
        return String.isNotBlank(addyToCheck.Address1__c) && String.isNotBlank(addyToCheck.City__c) && String.isNotBlank(addyToCheck.Country__c);
    }

    //  Remoting method called to request a vertex address verification on the address with the referenced name
    @RemoteAction
    public static LIST<VertexAddress__c> VerifyAddress(String addyName) {
        List<VertexAddress__c> returnAddresses;
        transient VertexAddress__c addyToCheck = VertexAddress__c.getValues(addyName);
        transient VertexAddress__c addyToReturn = VertexCore.validateAddressCallout(addyToCheck);

        if (addyToReturn != null)
            returnAddresses = new List<VertexAddress__c>{addyToCheck, addyToReturn};
        
        VertexLogging.CommitDelayed();
        return returnAddresses;
    }

    //  Build & return the data structure for the address verification callout to vertex
    public static String BuildAddressXML(VertexAddress__c addyToCheck) {
        transient VertexProtectedSettings__c config = VertexCore.ActiveSettings;

        //  Soap Envelope
        DOM.Document doc = new DOM.Document();
        DOM.XmlNode soapEnvelope = doc.createRootElement('Envelope', soapenv, 'soapenv');
        soapEnvelope.setNamespace('soapenv', soapenv);
        soapEnvelope.setNamespace('urn', urn);
        soapEnvelope.addChildElement('soapenv:Header', null, null);

        DOM.XmlNode soapBody = soapEnvelope.addChildElement('soapenv:Body', null, null);

        //  Vertex Envelope
        DOM.XmlNode vertexEnvelope = soapBody.addChildElement('urn:VertexEnvelope', null, null);
        
        //  Login set
        DOM.XmlNode login = vertexEnvelope.addChildElement('urn:Login', null, null);
        if (!String.isEmpty(config.TrustedID__c)){
            login.addChildElement('urn:TrustedId', null, null).addTextNode(config.TrustedID__c);
        } else if (!String.isEmpty(config.Username__c) || !String.isEmpty(config.Password__c)){
            login.addChildElement('urn:UserName', null, null).addTextNode(config.Username__c);
            login.addChildElement('urn:Password', null, null).addTextNode(config.Password__c);
        }

        //  TaxAreaRequest Set
        DOM.XmlNode taxAreaRequest = vertexEnvelope.addChildElement('urn:TaxAreaRequest', null, null);
        DOM.XmLNode taxAreaLookup = taxAreaRequest.addChildElement('urn:TaxAreaLookup', null, null);
        DOM.XmlNode postalAddress = taxAreaLookup.addChildElement('urn:PostalAddress', null, null);
        system.debug('-->Log: taxAreaRequest:::'+ taxAreaRequest);
        system.debug('-->Log: taxAreaRequest:::'+ taxAreaRequest);
        system.debug('-->Log: postalAddress:::'+ postalAddress);
        postalAddress.addChildElement('urn:StreetAddress1',null,null).addTextNode(addyToCheck.Address1__c);
        
        if (string.isNotBlank(addyToCheck.Address2__c))
            postalAddress.addChildElement('urn:StreetAddress2',null,null).addTextNode(addyToCheck.Address2__c);
        
        postalAddress.addChildElement('urn:City',null,null).addTextNode(addyToCheck.City__c);

        if (string.isNotBlank(addyToCheck.State__c))
            postalAddress.addChildElement('urn:MainDivision',null,null).addTextNode(addyToCheck.State__c);

        if (string.isNotBlank(addyToCheck.PostalCode__c))
            postalAddress.addChildElement('urn:PostalCode',null,null).addTextNode(addyToCheck.PostalCode__c);
        
        postalAddress.addChildElement('urn:Country',null,null).addTextNode(addyToCheck.Country__c);
        System.debug('-->Log :doc.toXmlString()::: '+doc.toXmlString().substring(0,(doc.toXmlString().length()/2)));
        System.debug('-->Log :doc.toXmlString()::: '+doc.toXmlString().substring((doc.toXmlString().length()/2),(doc.toXmlString().length())));
        return doc.toXmlString();
    }

    public static String BuildTaxCalloutXML(VertexAddress__c addyToCheck) {
        transient VertexProtectedSettings__c config = VertexCore.ActiveSettings;

        //  Soap Envelope
        DOM.Document doc = new DOM.Document();
        DOM.XmlNode soapEnvelope = doc.createRootElement('Envelope', soapenv, 'soapenv');
        soapEnvelope.setNamespace('soapenv', soapenv);
        soapEnvelope.setNamespace('urn', urn);
        soapEnvelope.addChildElement('soapenv:Header', null, null);

        DOM.XmlNode soapBody = soapEnvelope.addChildElement('soapenv:Body', null, null);

        //  Vertex Envelope
        DOM.XmlNode vertexEnvelope = soapBody.addChildElement('urn:VertexEnvelope', null, null);
        
        //  Login set
        DOM.XmlNode login = vertexEnvelope.addChildElement('urn:Login', null, null);
        if (!String.isEmpty(config.TrustedID__c)){
            login.addChildElement('urn:TrustedId', null, null).addTextNode(config.TrustedID__c);
        } else if (!String.isEmpty(config.Username__c) || !String.isEmpty(config.Password__c)){
            login.addChildElement('urn:UserName', null, null).addTextNode(config.Username__c);
            login.addChildElement('urn:Password', null, null).addTextNode(config.Password__c);
        }

        //  QuotationRequest
        DOM.XmlNode quoteRequest = vertexEnvelope.addChildElement('urn:QuotationRequest', null, null);
        quoteRequest.setAttribute('transactionId', 'testTransaction');
        quoteRequest.setAttribute('returnAssistedParametersIndicator', 'true');
        quoteRequest.setAttribute('documentNumber', 'testDocument');
        quoteRequest.setAttribute('documentDate', System.now().format('yyyy-MM-dd'));
        quoteRequest.setAttribute('transactionType', 'SALE');

        DOM.XmlNode sellerNode = quoteRequest.addChildElement('urn:Seller',null,null);
        sellerNode.addChildElement('urn:Company',null,null).addTextNode('Test Company');

        DOM.XmlNode physicalOriginNode = sellerNode.addChildElement('urn:PhysicalOrigin',null,null);
        physicalOriginNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(addyToCheck.Address1__c);
        if (string.isNotBlank(addyToCheck.Address2__c))
            physicalOriginNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(addyToCheck.Address2__c);
        physicalOriginNode.addChildElement('urn:City',null,null).addTextNode(addyToCheck.City__c);
        if (string.isNotBlank(addyToCheck.State__c))
            physicalOriginNode.addChildElement('urn:MainDivision',null,null).addTextNode(addyToCheck.State__c);
        if (string.isNotBlank(addyToCheck.PostalCode__c))
            physicalOriginNode.addChildElement('urn:PostalCode',null,null).addTextNode(addyToCheck.PostalCode__c);
        physicalOriginNode.addChildElement('urn:Country',null,null).addTextNode(addyToCheck.Country__c);

        DOM.XmlNode adminOriginNode = sellerNode.addChildElement('urn:AdministrativeOrigin',null,null);
        adminOriginNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(addyToCheck.Address1__c);
        if (string.isNotBlank(addyToCheck.Address2__c))
            adminOriginNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(addyToCheck.Address2__c);
        adminOriginNode.addChildElement('urn:City',null,null).addTextNode(addyToCheck.City__c);
        if (string.isNotBlank(addyToCheck.State__c))
            adminOriginNode.addChildElement('urn:MainDivision',null,null).addTextNode(addyToCheck.State__c);
        if (string.isNotBlank(addyToCheck.PostalCode__c))
            adminOriginNode.addChildElement('urn:PostalCode',null,null).addTextNode(addyToCheck.PostalCode__c);
        adminOriginNode.addChildElement('urn:Country',null,null).addTextNode(addyToCheck.Country__c);

        DOM.XmlNode customerNode = quoteRequest.addChildElement('urn:Customer',null,null);
        DOM.XmlNode destinationNode = customerNode.addChildElement('urn:Destination',null,null);
        destinationNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(addyToCheck.Address1__c);
        if (string.isNotBlank(addyToCheck.Address2__c))
            destinationNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(addyToCheck.Address2__c);
        destinationNode.addChildElement('urn:City',null,null).addTextNode(addyToCheck.City__c);
        if (string.isNotBlank(addyToCheck.State__c))
            destinationNode.addChildElement('urn:MainDivision',null,null).addTextNode(addyToCheck.State__c);
        if (string.isNotBlank(addyToCheck.PostalCode__c))
            destinationNode.addChildElement('urn:PostalCode',null,null).addTextNode(addyToCheck.PostalCode__c);
        destinationNode.addChildElement('urn:Country',null,null).addTextNode(addyToCheck.Country__c);

        DOM.XmlNode adminDestinationNode = customerNode.addChildElement('urn:AdministrativeDestination',null,null);
        adminDestinationNode.addChildElement('urn:StreetAddress1',null,null).addTextNode(addyToCheck.Address1__c);
        if (string.isNotBlank(addyToCheck.Address2__c))
            adminDestinationNode.addChildElement('urn:StreetAddress2',null,null).addTextNode(addyToCheck.Address2__c);
        adminDestinationNode.addChildElement('urn:City',null,null).addTextNode(addyToCheck.City__c);
        if (string.isNotBlank(addyToCheck.State__c))
            adminDestinationNode.addChildElement('urn:MainDivision',null,null).addTextNode(addyToCheck.State__c);
        if (string.isNotBlank(addyToCheck.PostalCode__c))
            adminDestinationNode.addChildElement('urn:PostalCode',null,null).addTextNode(addyToCheck.PostalCode__c);
        adminDestinationNode.addChildElement('urn:Country',null,null).addTextNode(addyToCheck.Country__c);

        DOM.XmlNode lineItemNode = quoteRequest.addChildElement('urn:LineItem',null,null);
        lineItemNode.addChildElement('urn:Quantity',null,null).addTextNode('1');
        lineItemNode.addChildElement('urn:ExtendedPrice',null,null).addTextNode('10.00');

        return doc.toXmlString();
    }

    public static String ValidateURL(String requestBody, String endpoint) {
        transient String versionStatus = 'No Connection';
        HttpRequest req = new HttpRequest(); 
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml');
        req.setEndpoint(endpoint);
        req.setBody(requestBody);


        Http http = new Http();
        
        transient String body;
        HTTPResponse res;
        system.debug('-->Log VertexSettingController::ValidateURL:: Request:: '+ req);
        system.debug('-->Log VertexSettingController::ValidateURL::Response.req.getBody:: '+ req.getBody());
        
        try {
            req.setTimeout(20000);
            res = http.send(req);
            body = res.getBody();
            system.debug('-->Log VertexSettingController::ValidateURL:: Request:: '+ req);
            system.debug('-->Log VertexSettingController::ValidateURL:: Response:: '+ res);
            system.debug('-->Log VertexSettingController::ValidateURL::Response.getBody:: '+ body);

            system.debug('-->Log VertexSettingController::ValidateURL::Response.getEndpoint:: '+ req.getEndpoint());
            system.debug('-->Log VertexSettingController::ValidateURL::Response.getStatus:: '+ res.getStatus() );
            system.debug('-->Log VertexSettingController::ValidateURL::Response.getStatusCode:: '+ res.getStatusCode());
           
        } catch (System.CalloutException e) {
            System.debug('-->Log Try catch block: ValidateURL :');
            System.debug(e);
            VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
        }
        if (String.isNotEmpty(body)){
            transient Dom.Document resDoc = new Dom.Document();
            resDoc.load(body);
            system.debug('-->Log VertexSettingController::ValidateURL::Response.resDoc.load(body):: ' + resDoc);
            transient Dom.XMLNode envelope = resDoc.getRootElement();
            transient Dom.XMLNode bodyNode = envelope.getChildElement('Body', soapenv);

            if (bodyNode.getChildElement('Fault',soapenv) != null){
                System.debug('Callout Fault: ' + bodyNode.getChildElement('Fault',soapenv).getChildElement('faultstring',null).getText());
                VertexLogging.Log('Error', 'Authentication Error: ' + bodyNode.getChildElement('Fault',soapenv).getChildElement('faultstring',null).getText(), req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
            } else {
                versionStatus = 'Successful Connection';
                VertexLogging.Log('Debug', 'Authentication Result: ' + versionStatus, req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
            }
        } else {
            VertexLogging.Log('Error', 'Authentication Error: Null Response Body', req.getEndpoint(), VertexCore.RemoveCalloutCredentials(req.getBody()), VertexCore.RemoveCalloutCredentials(res.getBody()), res.getStatus(), res.getStatusCode());
        }
        return versionStatus;
    }
    
    //Instead of checking the version, which won't work for some users, we check a static address to confirm authentication
    @RemoteAction
    public static List<String> ValidateAddressAndTaxURLs() {
        transient VertexProtectedSettings__c config = VertexCore.ActiveSettings;
        transient List<String> resultStrings = new List<String>{'', ''};
        
        if ( (!String.isEmpty(config.Username__c) && !String.isEmpty(config.Password__c)) || !String.isEmpty(config.TrustedID__c) ){
            
            transient VertexAddress__c dummyAddress = new VertexAddress__c();
            dummyAddress.Name = 'CRM Science';
            dummyAddress.Address1__c = '1150 1st Ave';
            dummyAddress.Address2__c = '#501';
            dummyAddress.City__c = 'King of Prussia';
            dummyAddress.State__c = 'PA';
            dummyAddress.PostalCode__c = '19406';
            dummyAddress.Country__c = 'United States';

            Boolean asyncLoggingVal = config.AsynchronousLogging__c;
            config.AsynchronousLogging__c = false;  //Temporarily disable log insertion until callouts are done

            //Check Tax Area Lookup URL
            String addressResult = VertexSettingsController.ValidateURL(VertexSettingsController.BuildAddressXML(dummyAddress), config.TaxAreaLookupURL__c);
            System.debug('-->Log 0: VertextSettingController: addressResult::'+ addressResult);
            //Check the Tax Calculation URL
            String taxCalcResult = VertexSettingsController.ValidateURL(VertexSettingsController.BuildTaxCalloutXML(dummyAddress), config.TaxCalculationURL__c);
            System.debug('-->Log 0: VertextSettingController: TaxCalcResult::'+ taxCalcResult);
            resultStrings.set(0, addressResult);
            resultStrings.set(1, taxCalcResult);

            config.AsynchronousLogging__c = asyncLoggingVal;

            VertexLogging.CommitDelayed();
        }

        System.debug('-->Log 0: VertextSettingController: resultStrings::'+ resultStrings);
        return resultStrings;
    }

    @RemoteAction
    public static void SetAddressValidationField(Boolean settingVal){
        transient VertexProtectedSettings__c config = VertexCore.ActiveSettings;
        config.AllowAddressValidation__c = settingVal;
        update config;
    }

    //  Sets all values from the current address to match the response from vertex
    @RemoteAction
    public static boolean UpdateAddress(VertexAddress__c testedAddy, VertexAddress__c correctedAddy) {
        testedAddy.Address1__c = String.isNotBlank(correctedAddy.Address1__c) ? correctedAddy.Address1__c : testedAddy.Address1__c;
        testedAddy.Address2__c = String.isNotBlank(correctedAddy.Address2__c) ? correctedAddy.Address2__c : testedAddy.Address2__c;
        testedAddy.City__c = String.isNotBlank(correctedAddy.City__c) ? correctedAddy.City__c : testedAddy.City__c;
        testedAddy.State__c = String.isNotBlank(correctedAddy.State__c) ? correctedAddy.State__c : testedAddy.State__c;
        testedAddy.PostalCode__c = String.isNotBlank(correctedAddy.PostalCode__c) ? correctedAddy.PostalCode__c : testedAddy.PostalCode__c;
        testedAddy.Country__c = String.isNotBlank(correctedAddy.Country__c) ? correctedAddy.Country__c : testedAddy.Country__c;
        testedAddy.TaxAreaID__c = String.isNotBlank(correctedAddy.TaxAreaID__c) ? correctedAddy.TaxAreaID__c : testedAddy.TaxAreaID__c;
        testedAddy.LocationCode__c = String.isNotBlank(correctedAddy.LocationCode__c) ? correctedAddy.LocationCode__c : testedAddy.LocationCode__c;
        update testedAddy;
        return true;
    }

    //  Update because the fetch earlier had updated the TaxAreaID field, but there was no DML until now
    @RemoteAction
    public static boolean SaveAddress(VertexAddress__c testedAddy) {
        upsert testedAddy;
        return true;
    }

    @RemoteAction
    public static boolean DeleteAddress(String addressId) {
        delete new VertexAddress__c(Id = addressId);
        return true;
    }

    //  fetch newest data to edit address
    @RemoteAction
    public static VertexAddress__c EditAddress(String addyName) {
        transient VertexAddress__c addyToEdit = VertexAddress__c.getValues(addyName);
        return (addyToEdit!=null) ? addyToEdit : new VertexAddress__c(name=addyName);
    }

    //  save config data
    @RemoteAction
    public static boolean SaveConfig(VertexProtectedSettings__c newConfig) {
        VertexProtectedSettings__c config = VertexCore.ActiveSettings;
        config.TaxAreaLookupURL__c = newConfig.TaxAreaLookupURL__c;
        config.TaxCalculationURL__c = newConfig.TaxCalculationURL__c;
        config.Username__c = newConfig.Username__c;
        config.Password__c = newConfig.Password__c;
        config.TrustedId__c = newConfig.TrustedId__c;
        VertexCore.ActiveSettings = config;
        return true;
    }
    

    //  save Advanced config data
    @RemoteAction
    public static boolean SaveAdvancedConfig(VertexProtectedSettings__c newConfig) {
        VertexProtectedSettings__c config = VertexCore.ActiveSettings;
        config.LoggingLevel__c = newConfig.LoggingLevel__c;
        config.AllowProcessBuilderRequests__c = newConfig.AllowProcessBuilderRequests__c;
        config.MaximumLoggingRows__c = newConfig.MaximumLoggingRows__c;
        config.CompanyName__c = newConfig.CompanyName__c;
        config.MaximumLineItems__c = newConfig.MaximumLineItems__c;
        config.CompanyTaxId__c = newConfig.CompanyTaxId__c;
        config.AllowAutocomplete__c = true;
        config.AsynchronousLogging__c = newConfig.AsynchronousLogging__c;
        VertexCore.ActiveSettings = config;
        return true;
    }
    
    @RemoteAction
    public static logContainer queryVertexLog(String logId) {
        logContainer retVal;
        if (IsVertexLogAccessible(new Set<String>{'Id', 'Name', 'Details__c', 'Endpoint__c', 'Request__c', 'Response__c', 'ResponseStatusCode__c', 'ResponseStatus__c', 'CreatedDate'})){
            for (VertexLog__c log : [SELECT Id, Name, Details__c, Endpoint__c, Request__c, Response__c, ResponseStatusCode__c, ResponseStatus__c, CreatedDate
                                    FROM VertexLog__c WHERE Id = :logId LIMIT 1])
                retVal = new logContainer(log.Id, log.Name, log.Details__c, log.Endpoint__c, log.Request__c, log.Response__c, log.CreatedDate.format(), log.ResponseStatus__c, log.ResponseStatusCode__c);

            if (retVal == null)
                retVal = new logContainer();
        }
        return retVal;
    }

    @RemoteAction
    public static List<logContainer> buildLogTable() {
        List<logContainer> logs = new List<logContainer>();
        if (IsVertexLogAccessible(new    Set<String>{'Id', 'Name', 'Details__c', 'Endpoint__c', 'Request__c', 'Response__c', 'ResponseStatusCode__c', 'ResponseStatus__c', 'CreatedDate'})){
            for (VertexLog__c log : [SELECT Id, Name, Details__c, Endpoint__c, Request__c, Response__c, ResponseStatusCode__c, ResponseStatus__c, CreatedDate
                                    FROM VertexLog__c ORDER BY CreatedDate DESC LIMIT 25])
                logs.add(new logContainer(log.Id, log.Name, log.Details__c, log.Endpoint__c, log.Request__c, log.Response__c, log.CreatedDate.format(), log.ResponseStatus__c, log.ResponseStatusCode__c));
        }
        return logs;
    }

    @RemoteAction
    public static LIST<objContainer> updateObjList(String requestingField, String value) {
        transient LIST<objContainer> tempContainerList = new LIST<objContainer>();
        transient Schema.SObjectType objSchema = VertexCore.GDMap.get(value);
        if(objSchema!=null && objSchema.getDescribe()!=null){
            for(ChildRelationship objRef : objSchema.getDescribe().getChildRelationships()){
                transient Schema.DescribeSObjectResult objDesc = objRef.getChildSObject().getDescribe();
                transient objContainer tempContainer = new objContainer();
                transient String objNamespace = objDesc.getName().remove(objDesc.getLocalName()).removeEnd('__');
                tempContainer.api = objDesc.getName();
                tempContainer.name = objDesc.getLabel() + ((String.isBlank(objNamespace)) ? '' : ' (' + objNamespace + ')');
                if (tempContainer.api.endsWith('History') ||
                    tempContainer.api.endsWith('__mdt') ||
                    tempContainer.api.endsWith('__kav') ||
                    tempContainer.api.endsWith('__ka') ||
                    tempContainer.api.endsWith('__DataCategorySelection') ||
                    tempContainer.api.endsWith('__KnowledgeArticleVersion') ||
                    tempContainer.api.endsWith('Feed') ||
                    tempContainer.api.endsWith('Status') ||
                    tempContainer.api.endsWith('Member') ||
                    tempContainer.api.endsWith('Share') ||
                    tempContainer.api.endsWith('MemberRequest') ||
                    tempContainer.api.endsWith('Link') ||
                    tempContainer.api.startsWith('Content')
                )
                continue;
            if(tempContainerList.size()==999){
                tempContainer.api = '';
                tempContainer.name = '-- Too Many Objects to Show --';
            }
            if(tempContainerList.size()<1000)
                tempContainerList.add(tempContainer);
            }
            if(requestingField == 'estTransObj')
                VertexSettingsController.estTransObjs = tempContainerList;
            else if(requestingField == 'orderTransObj')
                VertexSettingsController.orderTransObjs = tempContainerList;
            else if(requestingField == 'invTransObj')
                VertexSettingsController.invTransObjs = tempContainerList;
        }
        tempContainerList.sort();
        return tempContainerList;
    }

    public static Boolean IsVertexLogAccessible(Set<String> flds){
        Schema.DescribeSObjectResult logDescr = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexLog__c').getDescribe();
        if (!logDescr.isAccessible()){
            return false;
        } else {
            Boolean fldResults = true;
            for (String fld : flds){
                Schema.DescribeFieldResult fldDescr = logDescr.fields.getMap().get(VertexCore.NamespaceString + fld).getDescribe();
                if (!fldDescr.isAccessible()){
                    fldResults = false;
                    break;
                }
            }
            return fldResults;
        }
    }
    
    //  Address fields should only be of certain field types; these have been identified so far
    public static set<Schema.DisplayType> DisplayTypeWhiteList = new set<Schema.DisplayType>{
        Schema.DisplayType.ADDRESS,
        Schema.DisplayType.LOCATION,
        Schema.DisplayType.STRING
    };
    
    //  Can omit certain parent relationships because relavent address fields won't be found here
    public static boolean IsValidRelationship(string relationshipName) {
        return !new set<string>{'owner','lastmodifiedby','createdby','userrole','profile','masterrecord','dandbcompany'}.contains(relationshipName);
    }
    
    public static void HandleLevel(integer currentLevel, Map<String, Schema.SObjectField> fldMap, string prefix, integer maxLevels) {
        system.debug(LoggingLevel.WARN, '===HandleLevel===');
        system.debug(LoggingLevel.ERROR, 'currentLevel:  ' + currentLevel);
        system.debug(LoggingLevel.ERROR, 'fldMap:  ' + fldMap.size());
        system.debug(LoggingLevel.ERROR, 'prefix:  ' + prefix);
        system.debug(LoggingLevel.ERROR, 'prefix:  ' + prefix);
        
        //  Loop through this object's fields
        for(String field: fldMap.keySet()) {
            
            //  Ensure there's a value (would think there always is... but not always)
            if (fldMap.get(field) != null) {
                Schema.DescribeFieldResult dfr = fldMap.get(field).getDescribe();
                
                //  If this type of field is one that needs to be in the dropdown, add it, and do so w/ a prefix if a parent
                if (DisplayTypeWhiteList.contains(dfr.getType())) {
                    string option = string.isBlank(prefix) ? field : prefix + '.' + field;
                    transient objContainer tempContainer = new objContainer();
                    tempContainer.api = option;
                    tempContainer.name = option;
                    if(getLevel2Options().get(currentLevel).size()==999){
                        tempContainer.api = '';
                        tempContainer.name = '-- Too Many Objects to Show --';
                    }
                    if(getLevel2Options().get(currentLevel).size()<1000)
                        getLevel2Options().get(currentLevel).add(tempContainer);
                }
                
                //  Otherwise, is the field a lookup to another? Repeat the process
                else if(dfr.getType() == Schema.DisplayType.REFERENCE &&
                        dfr.getRelationshipName() != null &&
                        IsValidRelationship(dfr.getRelationshipName().toLowerCase()) && 
                        !dfr.getReferenceTo().isEmpty()) {
                    
                    //  Provide a new level prefix (opportunity.account, campaign.opportunity, campaign.campaign)
                    string levelPrefix = string.isBlank(prefix) ? dfr.getRelationshipName().toLowerCase() : prefix + '.' + dfr.getRelationshipName().toLowerCase();
                    if (currentLevel < maxLevels)
                        HandleLevel(currentLevel + 1, dfr.getReferenceTo().get(0).getDescribe().fields.getMap(), levelPrefix, maxLevels);
                }
            }
        }
    }
    
    //  Method to return a list of all select option up to X levels into parent (currently 3; soql allows 5)
    public static list<objContainer> getAddressFieldOptions(String selectedObject) {
        
        List<objContainer> results = new List<objContainer>();
        
        Schema.SObjectType ObjectSchema = VertexCore.GDMap.get(selectedObject);
        if(ObjectSchema!=null && ObjectSchema.getDescribe()!=null){
            Map<String, Schema.SObjectField> startFldMap = ObjectSchema.getDescribe().fields.getMap();
            HandleLevel(1, startFldMap, null, 3);
            
            for (integer i :getLevel2Options().keyset()) {
                list<objContainer> options = getLevel2Options().get(i);
                //options.sort();
                results.addAll(options);
            }
            for (objContainer o : results) {
                if (o.api.endsWith('billingaddress')) {
                    o.api = o.api.replace('billingaddress', 'billingstreet');
                    o.name = o.name.replace('billingaddress', 'billingstreet');
                }
                if (o.api.endsWith('mailingaddress')) {
                    o.api = o.api.replace('mailingaddress', 'mailingstreet');
                    o.name = o.name.replace('mailingaddress', 'mailingstreet');
                }
            }
            results.sort();
        }        
        return results;
    }
    
    private static map<integer, list<objContainer>> Level2Options;
    public static map<integer, list<objContainer>> getLevel2Options() {
        
        if (Level2Options == null) {
            Level2Options = new map<integer, list<objContainer>>();
            
            for (integer i = 1; i <=5; i++)
                Level2Options.put(i, new list<objContainer>());
        }
        return Level2Options;
    }

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // VALIDITY CHECK
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    private Map<List<String>, Map<String, String>> FieldDataTypes = new Map<List<String>, Map<String, String>>();

    public void RefreshValidityChecks(){
        FieldValidityResults = null;
        FieldPermissionResults = null;
        IncompleteDestinationMappings = null;
        DataTypeResults = null;
        FieldDataTypes = new Map<List<String>, Map<String, String>>();
    }

    //{Mapping Name, sObject Name} --> List of fields (taken from object, field, and address mappings)
    public Map<List<String>, List<String>> getObjFieldMap(){
        transient Map<List<String>, List<String>> objFieldMap = new Map<List<String>, List<String>>();
        transient List<VertexObjectMapping__c> objMappings = new List<VertexObjectMapping__c>();
        for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
            if (objMap.IsExtensionSetting__c != true)
                objMappings.add(objMap);
        transient List<VertexFieldMapping__c> fldMappings = VertexFieldMapping__c.getAll().values();
        transient List<VertexAddress__c> destinationMappings = VertexAddress__c.getAll().values();
        
        //Transaction objects
        for (VertexObjectMapping__c objMap : objMappings){
            String transObj = objMap.ParentSObject__c;
            
            if (transObj != null){
                Map<String, String> referencedFlds = new Map<String, String>{objMap.TransactionTaxAmount__c => 'STRING',
                                                                            objMap.TransactionDate__c => 'DATE',
                                                                            objMap.TransactionNumber__c => 'STRING', 
                                                                            objMap.ParentSourcePicklist__c => 'STRING', 
                                                                            objMap.TransactionTaxPayer__c => 'STRING', 
                                                                            objMap.Posting_Date__c => 'DATE', 
                                                                            objMap.TaxRegistrationNumber__c => 'STRING', 
                                                                            objMap.TransactionDeliveryTerm__c => 'STRING', 
                                                                            objMap.CurrencyCode__c => 'STRING'};
                for (VertexAddress__c destMap : destinationMappings){
                    if (destMap.Name.contains('Trans Dest Map') && destMap.Name.remove('Trans Dest Map').contains(objMap.Name))
                        referencedFlds.putAll(new Map<String, String>{destMap.Address1__c => 'STRING', 
                                                                    destMap.Address2__c => 'STRING', 
                                                                    destMap.City__c => 'STRING', 
                                                                    destMap.Country__c => 'STRING',
                                                                    destMap.CustomerClassCode__c => 'STRING', 
                                                                    destMap.CustomerCode__c => 'STRING', 
                                                                    destMap.PostalCode__c => 'STRING', 
                                                                    destMap.State__c => 'STRING', 
                                                                    destMap.TaxAreaID__c => 'STRING', 
                                                                    destMap.LocationCode__c => 'STRING'});
                }
                referencedFlds.remove(null);
                objFieldMap.put(new List<String>{objMap.Name, transObj}, new List<String>(referencedFlds.keySet()));
                FieldDataTypes.put(new List<String>{objMap.Name, transObj}, referencedFlds);
            }
        }

        //Line objects
        for (VertexObjectMapping__c objMap : objMappings){
            String lineObj = objMap.ChildSObject__c;
            
            if (lineObj != null){
                Map<String, String> referencedFlds = new Map<String, String>{objMap.ItemTaxField__c => 'STRING', 
                                                                            objMap.ItemPriceField__c => 'STRING', 
                                                                            objMap.ItemQuantityField__c => 'STRING', 
                                                                            objMap.ItemClassField__c => 'STRING',
                                                                            objMap.ItemTaxPayerField__c => 'STRING', 
                                                                            objMap.ItemNameField__c => 'STRING', 
                                                                            objMap.ItemTaxNotesField__c => 'TEXTAREA', 
                                                                            objMap.ChildSourcePicklist__c => 'STRING', 
                                                                            objMap.LineDeliveryTerm__c => 'STRING', 
                                                                            objMap.InputTotalTax__c => 'STRING', 
                                                                            objMap.InvoiceTextCodes__c => 'STRING', 
                                                                            objMap.TaxCode__c => 'STRING', 
                                                                            objMap.VertexTaxCode__c => 'STRING', 
                                                                            objMap.CommodityCode__c => 'STRING',
                                                                            objMap.CommodityCodeType__c => 'STRING',
                                                                            objMap.SuppressTaxCallout__c => 'STRING',
                                                                            objMap.TaxIncludedIndicator__c => 'STRING',
                                                                            objMap.UsageCode__c => 'STRING',
                                                                            objMap.UsageClass__c => 'STRING',
                                                                            objMap.TaxCalloutStatus__c => 'STRING'};
                                                                            
                //Only Line objects have flex field mappings
                for (VertexFieldMapping__c fldMap : fldMappings){
                    if (fldMap.ObjectMapping__c == objMap.ID){
                        String flexFldType = fldMap.Label__c.substringBetween('Flex ', ' Field');
                        String dataType = flexFldType == 'Text' || flexFldType == 'Number' ? 'STRING' : 'DATE';
                        referencedFlds.put(fldMap.SourceField__c, dataType);
                    }
                }
                for (VertexAddress__c destMap : destinationMappings){
                    if (destMap.Name.contains('Line Dest Map') && destMap.Name.remove('Line Dest Map').contains(objMap.Name))
                        referencedFlds.putAll(new Map<String, String>{destMap.Address1__c => 'STRING', 
                                                                    destMap.Address2__c => 'STRING', 
                                                                    destMap.City__c => 'STRING', 
                                                                    destMap.Country__c => 'STRING',
                                                                    destMap.CustomerClassCode__c => 'STRING', 
                                                                    destMap.CustomerCode__c => 'STRING', 
                                                                    destMap.PostalCode__c => 'STRING',
                                                                    destMap.State__c => 'STRING', 
                                                                    destMap.TaxAreaID__c => 'STRING', 
                                                                    destMap.LocationCode__c => 'STRING'});
                }
                referencedFlds.remove(null);
                objFieldMap.put(new List<String>{objMap.Name, lineObj}, new List<String>(referencedFlds.keySet()));
                FieldDataTypes.put(new List<String>{objMap.Name, lineObj}, referencedFlds);
            }
        }
        return objFieldMap;
    }
    
    //Returns a list of error messages: One for each field that could not be found on the given sObject
    private List<String> FieldValidityResults;
    public List<String> getFieldValidityResults(){
        if (FieldValidityResults == null){
            FieldValidityResults = new List<String>();
            transient Map<List<String>, List<String>> objFldMap = getObjFieldMap();
            transient Set<String> objectFields;

            for (List<String> mapKey : objFldMap.keySet()){
                String mapName = mapKey[0];
                String obj = mapKey[1];
                if(VertexCore.GDMap.get(obj)!=null){
                    objectFields = VertexCore.GDMap.get(obj).getDescribe().fields.getMap().keySet();
                    for (String fld : objFldMap.get(mapKey)){
                        if (!objectFields.contains(fld.toLowerCase()))
                            FieldValidityResults.add(mapName + ': ' + fld + ' is not a valid field on ' + obj);
                    }
                }
                else {
                    FieldValidityResults.add(mapName + ': ' + obj + ' is not a valid object');
                }
            }
        }
        return FieldValidityResults;
    }

    //Returns a list of error messages: One for each field with a data type that doesn't match the mapping's expected type(s)
    private List<String> DataTypeResults;
    public List<String> getDataTypeResults(){
        if (DataTypeResults == null){
            DataTypeResults = new List<String>();
            transient Schema.DescribeSobjectResult objDescr;

            for (List<String> mapKey : FieldDataTypes.keySet()){
                String mapName = mapKey[0];
                String obj = mapKey[1];
                if (VertexCore.GDMap.get(obj) != null) {
                    objDescr = VertexCore.GDMap.get(obj).getDescribe();

                    //Now traverse the map of field name => expected data type
                    for (String fld : FieldDataTypes.get(mapKey).keySet()){
                        //Skip invalid fields that were caught in getFieldValidityResults()
                        if (!objDescr.fields.getMap().keySet().contains(fld.toLowerCase()))
                            continue;
                        Schema.DisplayType fldType = objDescr.fields.getMap().get(fld.toLowerCase()).getDescribe().getType();
                        String expectedType = FieldDataTypes.get(mapKey).get(fld);
                        
                        if ((expectedType == 'STRING' && (fldType == Schema.DisplayType.Date || fldType == Schema.DisplayType.DateTime)) || 
                            (expectedType == 'DATE' && fldType != Schema.DisplayType.Date && fldType != Schema.DisplayType.DateTime) || 
                            (expectedType == 'TEXTAREA' && fldType != Schema.DisplayType.TextArea)){
                            
                            DataTypeResults.add(mapName + ': ' + obj + '.' + fld + ' is of type ' + fldType + ', but the mapping expects a data type of ' + expectedType);
                        }
                    }
                }
            }
        }
        return DataTypeResults;
    }

    //Returns a list of error messages: One for each field that is not readable (or updateable, in a few cases) for this user
    private List<String> FieldPermissionResults;
    public List<String> getFieldPermissionResults(){
        if (FieldPermissionResults == null){
            FieldPermissionResults = new List<String>();

            transient Map<List<String>, List<String>> objFldMap = getObjFieldMap();
            transient Schema.DescribeSobjectResult objDescr;
            transient Schema.DescribeFieldResult fldDescr;

            transient Map<String, VertexObjectMapping__c> objMappings = new Map<String, VertexObjectMapping__c>();  //Name --> Setting record
            for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
                if (objMap.IsExtensionSetting__c != true)
                    objMappings.put(objMap.Name, objMap);

            for (List<String> mapKey : objFldMap.keySet()){
                String mapName = mapKey[0];
                String obj = mapKey[1];
                if(VertexCore.GDMap.get(obj) != null){
                    objDescr = VertexCore.GDMap.get(obj).getDescribe();

                    //We only care about write permissions for a few fields
                    Set<String> fieldsToWrite = new Set<String>();
                    VertexObjectMapping__c thisSetting = objMappings.get(mapName);
                    if (thisSetting != null && thisSetting.ChildSObject__c == obj){
                        if (thisSetting.ItemTaxField__c != null)
                            fieldsToWrite.add(thisSetting.ItemTaxField__c.toLowerCase());
                        if (thisSetting.ItemTaxNotesField__c != null)
                            fieldsToWrite.add(thisSetting.ItemTaxNotesField__c.toLowerCase());
                        if (thisSetting.InvoiceTextCodes__c != null)
                            fieldsToWrite.add(thisSetting.InvoiceTextCodes__c.toLowerCase());
                        if (thisSetting.TaxCode__c != null)
                            fieldsToWrite.add(thisSetting.TaxCode__c.toLowerCase());
                        if (thisSetting.VertexTaxCode__c != null)
                            fieldsToWrite.add(thisSetting.VertexTaxCode__c.toLowerCase());
                        if (thisSetting.TaxCalloutStatus__c != null)
                            fieldsToWrite.add(thisSetting.TaxCalloutStatus__c.toLowerCase());
                    }

                    for (String fld : objFldMap.get(mapKey)){
                        //Skip invalid fields that were caught in getFieldValidityResults()
                        if (!objDescr.fields.getMap().keySet().contains(fld.toLowerCase()))
                            continue;
                        fldDescr = objDescr.fields.getMap().get(fld.toLowerCase()).getDescribe();
                        String fldErrMsg;
                        if (!fldDescr.isAccessible()){
                            fldErrMsg = 'You do not have read';
                            if (fieldsToWrite.contains(fld.toLowerCase()) && !fldDescr.isUpdateable())
                                fldErrMsg += ' or write';
                        
                            fldErrMsg += ' permissions for ' + fld + ' on ' + obj;
                            FieldPermissionResults.add(mapName + ': ' + fldErrMsg);
                        } else if (fieldsToWrite.contains(fld.toLowerCase()) && !fldDescr.isUpdateable()){
                            fldErrMsg = 'You do not have write permissions for ' + fld + ' on ' + obj;
                            FieldPermissionResults.add(mapName + ': ' + fldErrMsg);
                        }
                    }
                }
            }
        }
        return FieldPermissionResults;
    }

    private List<String> IncompleteDestinationMappings;
    public List<String> getIncompleteDestinationMappings(){
        if (IncompleteDestinationMappings == null){
            IncompleteDestinationMappings = new List<String>();

            //First, identify the names of object settings in use
            transient Set<String> objSettings = new Set<String>();
            for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values())
                if (objMap.IsExtensionSetting__c != true)
                    objSettings.add(objMap.Name);
            
            transient Map<String, List<VertexAddress__c>> destinationMappings = new Map<String, List<VertexAddress__c>>();  //Trans and Line dest maps for each obj map name
            for (VertexAddress__c destMap : VertexAddress__c.getAll().values()){
                if (destMap.Name.contains('Dest Map')){
                    String objMapName = destMap.Name.remove(' Trans Dest Map').remove(' Line Dest Map');    //"Estimate", "Invoice", "Custom Mapping 1", etc
                    if (objSettings.contains(objMapName)){
                        if (destinationMappings.containsKey(objMapName))
                            destinationMappings.get(objMapName).add(destMap);
                        else
                            destinationMappings.put(objMapName, new List<VertexAddress__c>{destMap});
                    }
                }
            }
            
            for (String objMapName : destinationMappings.keySet()){
                Boolean completedAddress = false;
                //Look at both the Trans and Line level destination mappings, and determine if either one of them is "complete"
                for (VertexAddress__c destMap : destinationMappings.get(objMapName)){
                    if (String.isNotBlank(destMap.Address1__c) && String.isNotBlank(destMap.City__c) && String.isNotBlank(destMap.Country__c)){
                        completedAddress = true;
                        break;  //Quit once we find a complete address
                    }
                }
                if (!completedAddress)
                    IncompleteDestinationMappings.add(objMapName + ': Destination requires a Street (Address 1), City, and Country for either Transaction or Line object.');
            }

        }
        return IncompleteDestinationMappings;
    }

    public class objContainer implements Comparable {
        public String api   { get; set; }
        public String name  { get; set; }
        public String dataType {get; set;}

        public Integer compareTo(Object compareTo){
            Integer retVal;
            if (compareTo instanceof objContainer) {
                objContainer obj = (objContainer) compareTo;
                if (this.name.startsWith('-')  && !obj.name.startsWith('-'))
                    retVal = 1;
                else if (!this.name.startsWith('-')  && obj.name.startsWith('-'))
                    retVal = -1;
                else
                    retVal = this.name.compareTo(obj.name);
            } else
                retVal = null;

            return retVal;
        }
    }

    public class logContainer {
        public String logId                              { get; set;}
        public String name                               { get; set;}
        public String details                            { get; set;}
        public String endpoint                           { get; set;}
        public String request                            { get; set;}
        public String response                           { get; set;}
        public String createdDate                        { get; set;}
        public String responseStatus                     { get; set;}
        public Decimal responseStatusCode                { get; set;}
        public String transactionId                      { get; set;}

        public logContainer(String logId, String name, String details, String endpoint, String request, String response, String createdDate, String responseStatus, Decimal responseStatusCode) {
            this.logId = logId;
            this.name = name;
            this.details = details;
            this.endpoint = endpoint;
            this.request = request;
            this.response = response;
            this.createdDate = createdDate;
            this.responseStatus = responseStatus;
            this.responseStatusCode = responseStatusCode;
            this.transactionId = String.isNotBlank(request) && request.contains('transactionId="') ? request.substringBetween('transactionId="', '"') : '';
        }

        public logContainer() {}
    }

    /////////////////////////////////////////////////
    //
    //          Log Functions
    public void deleteAllLogs(){
        transient boolean done = false;
        transient LIST<VertexLog__c> logs;
        transient LIST<VertexLog__c> logsToDelete = new LIST<VertexLog__c>();

        for(integer x=0; (x < 5 && done == false ); x++){
            logs = [SELECT id FROM VertexLog__c Order by CreatedDate asc LIMIT 10000];
            if(logs.size() != 10000)
                done = true;
            logsToDelete.addAll(logs);
        }

        if (!logsToDelete.isEmpty() && Schema.sObjectType.VertexLog__c.isDeletable())
            delete logsToDelete;
    }

    public void deleteOldLogs(){
        transient boolean done = false;
        transient LIST<VertexLog__c> logs;
        transient LIST<VertexLog__c> logsToDelete = new LIST<VertexLog__c>();

        for(integer x=0; (x < 5 && done == false ); x++){
            logs = [SELECT id FROM VertexLog__c WHERE createdDate < LAST_N_MONTHS:1 Order by CreatedDate asc LIMIT 10000];
            if(logs.size() != 10000)
                done = true;
            logsToDelete.addAll(logs);
        }

        if (!logsToDelete.isEmpty() && Schema.sObjectType.VertexLog__c.isDeletable())
            delete logsToDelete;
    }
}
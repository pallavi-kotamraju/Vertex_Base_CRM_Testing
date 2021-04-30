public with sharing class VertexCPQConfigurationController {
    public VertexCPQConfigurationController() {}

    
    //  Property to store global describe to conserve on subsequent describes
    public static Map<String, Schema.SObjectType> GDMap {
        get{
            if (GDMap == null)
                GDMap = Schema.getGlobalDescribe();
            return GDMap;
        }
        set;
    }

    public static Map<String, Map<String, String>> ObjectMappingNameToFieldValuePairs {
        get {
            if (ObjectMappingNameToFieldValuePairs == null){
                ObjectMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new List<object>{'fetchObjMap', new List<String>{'CPQ'}});
            }
            return ObjectMappingNameToFieldValuePairs;
        }
        set;
    }

    public static List<String> DestinationMappings {
        get {
            if (DestinationMappings == null)
                DestinationMappings = new List<String>{'CPQ Trans Dest Map', 'CPQ Line Dest Map'};
            return DestinationMappings;
        }
        set;
    }
    public static List<String> AdminOriginMappings {
        get {
            if (AdminOriginMappings == null)
                AdminOriginMappings = new List<String>{'CPQ Trans Admin', 'CPQ Line Admin'};
            return AdminOriginMappings;
        }
        set;
    }
    public static List<String> PhysicalOriginMappings {
        get {
            if (PhysicalOriginMappings == null)
                PhysicalOriginMappings = new List<String>{'CPQ Trans Phys', 'CPQ Line Phys'};
            return PhysicalOriginMappings;
        }
        set;
    }
    public static Map<String, Map<String, String>> AddressMappingNameToFieldValuePairs {
        get {
            if (AddressMappingNameToFieldValuePairs == null){
                List<String> allMappings = new List<String>();
                allMappings.addAll(DestinationMappings);
                allMappings.addAll(AdminOriginMappings);
                allMappings.addAll(PhysicalOriginMappings);
                AddressMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new List<object>{'fetchAddyMap', allMappings});
            }
            return AddressMappingNameToFieldValuePairs;
        }
        set;
    }

    public static Map<String, Map<String, String>> FlexFieldNameToFieldValuePairs {
        get {
            if (FlexFieldNameToFieldValuePairs == null){
                FlexFieldNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new List<object>{'fetchFldMap'});
            }
            return FlexFieldNameToFieldValuePairs;
        }
        set;
    }

    @RemoteAction
    public static LIST<objContainer> UpdateFldList(String objectName) {
        transient LIST<objContainer> tempContainerList = new LIST<objContainer>();
        if(GDMap.get(objectName)!=null){
            transient Schema.SObjectType objSchema = GDMap.get(objectName);
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
    
    @RemoteAction
    public static void ResetObjMappings(){
        Map<String, Map<String, String>> objectMappingNameToFieldValuePairs = new Map<String, Map<String, String>>();
		Map<String, String> tempMap = new Map<String, String>();

		objectMappingNameToFieldValuePairs.put('CPQ', new Map<String, String>());
		tempMap = objectMappingNameToFieldValuePairs.get('CPQ');
		tempMap.put('ParentSourcePicklist__c', '');
        tempMap.put('TransactionTaxPayer__c', '');
        tempMap.put('TransactionNumber__c', 'Name');
        tempMap.put('TransactionDate__c', 'CreatedDate');
        tempMap.put('Posting_Date__c', 'CreatedDate');
        tempMap.put('ChildSourcePicklist__c', '');
        tempMap.put('ItemClassField__c', '');
        tempMap.put('ItemNameField__c', '');
        tempMap.put('ItemTaxPayerField__c', '');
        
		VertexGlobal.GlobalHelper(new list<object>{'saveObjMap', objectMappingNameToFieldValuePairs});
    }

    @RemoteAction
    public static void AddFieldMapping(String objLevel, String mappingType, String targetLoc, String valueToWrite){
        if (mappingType == 'obj'){
            Map<String, Map<String, String>> objectSettingUpdate = new Map<String, Map<String, String>>();
            objectSettingUpdate.put('CPQ', new Map<String, String>{targetLoc => valueToWrite});
            VertexGlobal.GlobalHelper(new list<object>{'saveObjMap', objectSettingUpdate});
        } else if (mappingType == 'fld'){
            String label = targetLoc.substringAfter('Line ');   //e.g. Text 3
            String cartSettingID = ObjectMappingNameToFieldValuePairs.get('CPQ').get('Id');

            Map<String, Map<String, String>> writeSettings = new Map<String, Map<String, String>>();
            Map<String, String> settingValues = new Map<String, String>();
            
            settingValues.put('Label__c', 'Flex ' + label.split(' ')[0] + ' Field ' + label.split(' ')[1]); //For example, "Flex Text Field 1" or "Flex Number Field 4"
            settingValues.put('ObjectMapping__c', cartSettingID);
            settingValues.put('SourceField__c', valueToWrite);
            settingValues.put('Type__c', 'line');
            writeSettings.put('Line ' + label.split(' ')[0] + ' ' + label.split(' ')[1] + ': ' + cartSettingID, settingValues);
            VertexGlobal.GlobalHelper(new List<object>{'saveFldMap', writeSettings});
        } else if (mappingType == 'dest' || mappingType == 'orig-admin' || mappingType == 'orig-phys'){
            String objLevelLabel = objLevel == 'transaction' ? 'Trans' : 'Line';
            String typeLabel;
            if (mappingType == 'dest') typeLabel = 'Dest Map';
            else if (mappingType == 'orig-admin') typeLabel = 'Admin';
            else if (mappingType == 'orig-phys') typeLabel = 'Phys';
            MAP<String, String> destinationMapping = AddressMappingNameToFieldValuePairs.get('CPQ ' + objLevelLabel + ' ' + typeLabel);
            destinationMapping.put(targetLoc, valueToWrite);
            VertexGlobal.GlobalHelper(new list<object>{'saveAddyMap', AddressMappingNameToFieldValuePairs});
        }
    }

    @RemoteAction
    public static void DeleteFieldMapping(String objLevel, String mappingType, String location){
        if (mappingType == 'obj'){
            Map<String, Map<String, String>> objectSettingUpdate = new Map<String, Map<String, String>>();
            objectSettingUpdate.put('CPQ', new Map<String, String>{location => ''});
            VertexGlobal.GlobalHelper(new list<object>{'saveObjMap', objectSettingUpdate});
        } else if (mappingType == 'fld'){
            VertexGlobal.GlobalHelper(new List<object>{'deleteFldMap', location});
        } else if (mappingType == 'dest' || mappingType == 'orig-admin' || mappingType == 'orig-phys'){
            String objLevelLabel = objLevel == 'transaction' ? 'Trans' : 'Line';
            String typeLabel;
            if (mappingType == 'dest') typeLabel = 'Dest Map';
            else if (mappingType == 'orig-admin') typeLabel = 'Admin';
            else if (mappingType == 'orig-phys') typeLabel = 'Phys';
            MAP<String, String> destinationMapping = AddressMappingNameToFieldValuePairs.get('CPQ ' + objLevelLabel + ' ' + typeLabel);
            destinationMapping.put(location, '');
            VertexGlobal.GlobalHelper(new list<object>{'saveAddyMap', AddressMappingNameToFieldValuePairs});
        }
    }

    public List<FieldMapping> getBoundCartMappings(){
        Map<String, String> objMap = ObjectMappingNameToFieldValuePairs.get('CPQ');
        transient List<FieldMapping> wrapperList = new List<FieldMapping>();
        //First index is blank, to allow for new selections
        wrapperList.add(new FieldMapping(null, null, null, null));

        if (String.isNotBlank(objMap.get('ParentSourcePicklist__c')))
            wrapperList.add(new FieldMapping('Transaction Origin Field', 'obj', objMap.get('ParentSourcePicklist__c'), 'ParentSourcePicklist__c'));
        if (String.isNotBlank(objMap.get('TransactionTaxPayer__c')))
            wrapperList.add(new FieldMapping('Transaction Tax Payer', 'obj', objMap.get('TransactionTaxPayer__c'), 'TransactionTaxPayer__c'));
        if (String.isNotBlank(objMap.get('TransactionNumber__c')))
            wrapperList.add(new FieldMapping('Transaction Number', 'obj', objMap.get('TransactionNumber__c'), 'TransactionNumber__c'));
        if (String.isNotBlank(objMap.get('TransactionDate__c')))
            wrapperList.add(new FieldMapping('Transaction Date', 'obj', objMap.get('TransactionDate__c'), 'TransactionDate__c'));
        if (String.isNotBlank(objMap.get('CurrencyCode__c')))
            wrapperList.add(new FieldMapping('Currency Code', 'obj', objMap.get('CurrencyCode__c'), 'CurrencyCode__c'));
        if (String.isNotBlank(objMap.get('Posting_Date__c')))
            wrapperList.add(new FieldMapping('Posting Date', 'obj', objMap.get('Posting_Date__c'), 'Posting_Date__c'));
        if (String.isNotBlank(objMap.get('TaxRegistrationNumber__c')))
            wrapperList.add(new FieldMapping('Tax Registration Number', 'obj', objMap.get('TaxRegistrationNumber__c'), 'TaxRegistrationNumber__c'));
        if (String.isNotBlank(objMap.get('TransactionDeliveryTerm__c')))
            wrapperList.add(new FieldMapping('Transaction Delivery Term', 'obj', objMap.get('TransactionDeliveryTerm__c'), 'TransactionDeliveryTerm__c'));
        
        MAP<String, String> transDestMap = AddressMappingNameToFieldValuePairs.get('CPQ Trans Dest Map');
        if (transDestMap != null){  //Should never be null
            if (String.isNotBlank(transDestMap.get('Address1__c')))
                wrapperList.add(new FieldMapping('Destination Address 1', 'dest', transDestMap.get('Address1__c'), 'Address1__c'));
            if (String.isNotBlank(transDestMap.get('Address2__c')))
                wrapperList.add(new FieldMapping('Destination Address 2', 'dest', transDestMap.get('Address2__c'), 'Address2__c'));
            if (String.isNotBlank(transDestMap.get('City__c')))
                wrapperList.add(new FieldMapping('Destination City', 'dest', transDestMap.get('City__c'), 'City__c'));
            if (String.isNotBlank(transDestMap.get('Country__c')))
                wrapperList.add(new FieldMapping('Destination Country', 'dest', transDestMap.get('Country__c'), 'Country__c'));
            if (String.isNotBlank(transDestMap.get('CustomerClassCode__c')))
                wrapperList.add(new FieldMapping('Destination Customer Class Code', 'dest', transDestMap.get('CustomerClassCode__c'), 'CustomerClassCode__c'));
            if (String.isNotBlank(transDestMap.get('CustomerCode__c')))
                wrapperList.add(new FieldMapping('Destination Customer Code', 'dest', transDestMap.get('CustomerCode__c'), 'CustomerCode__c'));
            if (String.isNotBlank(transDestMap.get('PostalCode__c')))
                wrapperList.add(new FieldMapping('Destination Postal Code', 'dest', transDestMap.get('PostalCode__c'), 'PostalCode__c'));
            if (String.isNotBlank(transDestMap.get('State__c')))
                wrapperList.add(new FieldMapping('Destination State', 'dest', transDestMap.get('State__c'), 'State__c'));
            if (String.isNotBlank(transDestMap.get('TaxAreaID__c')))
                wrapperList.add(new FieldMapping('Destination Tax Area ID', 'dest', transDestMap.get('TaxAreaID__c'), 'TaxAreaID__c'));
            if (String.isNotBlank(transDestMap.get('LocationCode__c')))
                wrapperList.add(new FieldMapping('Destination Location Code', 'dest', transDestMap.get('LocationCode__c'), 'LocationCode__c'));
        }
        //Admin Origin Address
        MAP<String, String> transAdminAddr = AddressMappingNameToFieldValuePairs.get('CPQ Trans Admin');
        if (transAdminAddr != null){
            if (String.isNotBlank(transAdminAddr.get('Address1__c')))
                wrapperList.add(new FieldMapping('Admin Origin Address 1', 'orig-admin', transAdminAddr.get('Address1__c'), 'Address1__c'));
            if (String.isNotBlank(transAdminAddr.get('Address2__c')))
                wrapperList.add(new FieldMapping('Admin Origin Address 2', 'orig-admin', transAdminAddr.get('Address2__c'), 'Address2__c'));
            if (String.isNotBlank(transAdminAddr.get('City__c')))
                wrapperList.add(new FieldMapping('Admin Origin City', 'orig-admin', transAdminAddr.get('City__c'), 'City__c'));
            if (String.isNotBlank(transAdminAddr.get('Country__c')))
                wrapperList.add(new FieldMapping('Admin Origin Country', 'orig-admin', transAdminAddr.get('Country__c'), 'Country__c'));
            if (String.isNotBlank(transAdminAddr.get('PostalCode__c')))
                wrapperList.add(new FieldMapping('Admin Origin Postal Code', 'orig-admin', transAdminAddr.get('PostalCode__c'), 'PostalCode__c'));
            if (String.isNotBlank(transAdminAddr.get('State__c')))
                wrapperList.add(new FieldMapping('Admin Origin State', 'orig-admin', transAdminAddr.get('State__c'), 'State__c'));
            if (String.isNotBlank(transAdminAddr.get('TaxAreaID__c')))
                wrapperList.add(new FieldMapping('Admin Origin Tax Area ID', 'orig-admin', transAdminAddr.get('TaxAreaID__c'), 'TaxAreaID__c'));
            if (String.isNotBlank(transAdminAddr.get('LocationCode__c')))
                wrapperList.add(new FieldMapping('Admin Origin Location Code', 'orig-admin', transAdminAddr.get('LocationCode__c'), 'LocationCode__c'));
        }
        //Physical Origin Address
        MAP<String, String> transPhysAddr = AddressMappingNameToFieldValuePairs.get('CPQ Trans Phys');
        if (transPhysAddr != null){
            if (String.isNotBlank(transPhysAddr.get('Address1__c')))
                wrapperList.add(new FieldMapping('Physical Origin Address 1', 'orig-phys', transPhysAddr.get('Address1__c'), 'Address1__c'));
            if (String.isNotBlank(transPhysAddr.get('Address2__c')))
                wrapperList.add(new FieldMapping('Physical Origin Address 2', 'orig-phys', transPhysAddr.get('Address2__c'), 'Address2__c'));
            if (String.isNotBlank(transPhysAddr.get('City__c')))
                wrapperList.add(new FieldMapping('Physical Origin City', 'orig-phys', transPhysAddr.get('City__c'), 'City__c'));
            if (String.isNotBlank(transPhysAddr.get('Country__c')))
                wrapperList.add(new FieldMapping('Physical Origin Country', 'orig-phys', transPhysAddr.get('Country__c'), 'Country__c'));
            if (String.isNotBlank(transPhysAddr.get('PostalCode__c')))
                wrapperList.add(new FieldMapping('Physical Origin Postal Code', 'orig-phys', transPhysAddr.get('PostalCode__c'), 'PostalCode__c'));
            if (String.isNotBlank(transPhysAddr.get('State__c')))
                wrapperList.add(new FieldMapping('Physical Origin State', 'orig-phys', transPhysAddr.get('State__c'), 'State__c'));
            if (String.isNotBlank(transPhysAddr.get('TaxAreaID__c')))
                wrapperList.add(new FieldMapping('Physical Origin Tax Area ID', 'orig-phys', transPhysAddr.get('TaxAreaID__c'), 'TaxAreaID__c'));
            if (String.isNotBlank(transPhysAddr.get('LocationCode__c')))
                wrapperList.add(new FieldMapping('Physical Origin Location Code', 'orig-phys', transPhysAddr.get('LocationCode__c'), 'LocationCode__c'));
        }
        return wrapperList;
    }

    public List<SelectOption> getUnboundCartMappings(){
        transient List<SelectOption> optList = new List<SelectOption>();
        Map<String, String> objMap = ObjectMappingNameToFieldValuePairs.get('CPQ');

        if (String.isBlank(objMap.get('ParentSourcePicklist__c')))
            optList.add(new SelectOption('obj: ParentSourcePicklist__c', 'Transaction Origin Field'));
        if (String.isBlank(objMap.get('TransactionTaxPayer__c')))
            optList.add(new SelectOption('obj: TransactionTaxPayer__c', 'Transaction Tax Payer'));
        if (String.isBlank(objMap.get('TransactionNumber__c')))
            optList.add(new SelectOption('obj: TransactionNumber__c', 'Transaction Number'));
        if (String.isBlank(objMap.get('TransactionDate__c')))
            optList.add(new SelectOption('obj: TransactionDate__c', 'Transaction Date'));
        if (String.isBlank(objMap.get('CurrencyCode__c')))
            optList.add(new SelectOption('obj: CurrencyCode__c', 'Currency Code'));
        if (String.isBlank(objMap.get('Posting_Date__c')))
            optList.add(new SelectOption('obj: Posting_Date__c', 'Posting Date'));
        if (String.isBlank(objMap.get('TaxRegistrationNumber__c')))
            optList.add(new SelectOption('obj: TaxRegistrationNumber__c', 'Tax Registration Number'));
        if (String.isBlank(objMap.get('TransactionDeliveryTerm__c')))
            optList.add(new SelectOption('obj: TransactionDeliveryTerm__c', 'Transaction Delivery Term'));
        
        //Destination Mappings
        MAP<String, String> transDestMap = AddressMappingNameToFieldValuePairs.get('CPQ Trans Dest Map');
        if (transDestMap != null){  //Should never be null
            if (String.isBlank(transDestMap.get('Address1__c')))
                optList.add(new SelectOption('dest: Address1__c', 'Destination Address 1'));
            if (String.isBlank(transDestMap.get('Address2__c')))
                optList.add(new SelectOption('dest: Address2__c', 'Destination Address 2'));
            if (String.isBlank(transDestMap.get('City__c')))
                optList.add(new SelectOption('dest: City__c', 'Destination City'));
            if (String.isBlank(transDestMap.get('Country__c')))
                optList.add(new SelectOption('dest: Country__c', 'Destination Country'));
            if (String.isBlank(transDestMap.get('CustomerClassCode__c')))
                optList.add(new SelectOption('dest: CustomerClassCode__c', 'Destination Customer Class Code'));
            if (String.isBlank(transDestMap.get('CustomerCode__c')))
                optList.add(new SelectOption('dest: CustomerCode__c', 'Destination Customer Code'));
            if (String.isBlank(transDestMap.get('PostalCode__c')))
                optList.add(new SelectOption('dest: PostalCode__c', 'Destination Postal Code'));
            if (String.isBlank(transDestMap.get('State__c')))
                optList.add(new SelectOption('dest: State__c', 'Destination State'));
            if (String.isBlank(transDestMap.get('TaxAreaID__c')))
                optList.add(new SelectOption('dest: TaxAreaID__c', 'Destination Tax Area ID'));
            if (String.isBlank(transDestMap.get('LocationCode__c')))
                optList.add(new SelectOption('dest: LocationCode__c', 'Destination Location Code'));
        }
        //Admin Origin Address
        MAP<String, String> transAdminAddr = AddressMappingNameToFieldValuePairs.get('CPQ Trans Admin');
        if (transAdminAddr != null){
            if (String.isBlank(transAdminAddr.get('Address1__c')))
                optList.add(new SelectOption('orig-admin: Address1__c', 'Admin Origin Address 1'));
            if (String.isBlank(transAdminAddr.get('Address2__c')))
                optList.add(new SelectOption('orig-admin: Address2__c', 'Admin Origin Address 2'));
            if (String.isBlank(transAdminAddr.get('City__c')))
                optList.add(new SelectOption('orig-admin: City__c', 'Admin Origin City'));
            if (String.isBlank(transAdminAddr.get('Country__c')))
                optList.add(new SelectOption('orig-admin: Country__c', 'Admin Origin Country'));
            if (String.isBlank(transAdminAddr.get('PostalCode__c')))
                optList.add(new SelectOption('orig-admin: PostalCode__c', 'Admin Origin Postal Code'));
            if (String.isBlank(transAdminAddr.get('State__c')))
                optList.add(new SelectOption('orig-admin: State__c', 'Admin Origin State'));
            if (String.isBlank(transAdminAddr.get('TaxAreaID__c')))
                optList.add(new SelectOption('orig-admin: TaxAreaID__c', 'Admin Origin Tax Area ID'));
            if (String.isBlank(transAdminAddr.get('LocationCode__c')))
                optList.add(new SelectOption('orig-admin: LocationCode__c', 'Admin Origin Location Code'));
        }
        //Physical Origin Address
        MAP<String, String> transPhysAddr = AddressMappingNameToFieldValuePairs.get('CPQ Trans Phys');
        if (transPhysAddr != null){
            if (String.isBlank(transPhysAddr.get('Address1__c')))
                optList.add(new SelectOption('orig-phys: Address1__c', 'Physical Origin Address 1'));
            if (String.isBlank(transPhysAddr.get('Address2__c')))
                optList.add(new SelectOption('orig-phys: Address2__c', 'Physical Origin Address 2'));
            if (String.isBlank(transPhysAddr.get('City__c')))
                optList.add(new SelectOption('orig-phys: City__c', 'Physical Origin City'));
            if (String.isBlank(transPhysAddr.get('Country__c')))
                optList.add(new SelectOption('orig-phys: Country__c', 'Physical Origin Country'));
            if (String.isBlank(transPhysAddr.get('PostalCode__c')))
                optList.add(new SelectOption('orig-phys: PostalCode__c', 'Physical Origin Postal Code'));
            if (String.isBlank(transPhysAddr.get('State__c')))
                optList.add(new SelectOption('orig-phys: State__c', 'Physical Origin State'));
            if (String.isBlank(transPhysAddr.get('TaxAreaID__c')))
                optList.add(new SelectOption('orig-phys: TaxAreaID__c', 'Physical Origin Tax Area ID'));
            if (String.isBlank(transPhysAddr.get('LocationCode__c')))
                optList.add(new SelectOption('orig-phys: LocationCode__c', 'Physical Origin Location Code'));
        }

        return optList;
    }

    public List<FieldMapping> getBoundCartItemMappings(){
        Map<String, String> objMap = ObjectMappingNameToFieldValuePairs.get('CPQ');
        transient List<FieldMapping> wrapperList = new List<FieldMapping>();
        //First index is blank, to allow for new selections
        wrapperList.add(new FieldMapping(null, null, null, null));

        if (String.isNotBlank(objMap.get('ChildSourcePicklist__c')))
            wrapperList.add(new FieldMapping('Line Item Origin Field', 'obj', objMap.get('ChildSourcePicklist__c'), 'ChildSourcePicklist__c'));
        if (String.isNotBlank(objMap.get('ItemTaxPayerField__c')))
            wrapperList.add(new FieldMapping('Line Item Tax Payer', 'obj', objMap.get('ItemTaxPayerField__c'), 'ItemTaxPayerField__c'));
        if (String.isNotBlank(objMap.get('ItemClassField__c')))
            wrapperList.add(new FieldMapping('Product Class', 'obj', objMap.get('ItemClassField__c'), 'ItemClassField__c'));
        if (String.isNotBlank(objMap.get('ItemNameField__c')))
            wrapperList.add(new FieldMapping('Product Code', 'obj', objMap.get('ItemNameField__c'), 'ItemNameField__c'));
        if (String.isNotBlank(objMap.get('InvoiceTextCodes__c')))
            wrapperList.add(new FieldMapping('Invoice Text Codes', 'obj', objMap.get('InvoiceTextCodes__c'), 'InvoiceTextCodes__c'));
        if (String.isNotBlank(objMap.get('TaxCode__c')))
            wrapperList.add(new FieldMapping('Tax Code', 'obj', objMap.get('TaxCode__c'), 'TaxCode__c'));
        if (String.isNotBlank(objMap.get('VertexTaxCode__c')))
            wrapperList.add(new FieldMapping('Vertex Tax Code', 'obj', objMap.get('VertexTaxCode__c'), 'VertexTaxCode__c'));
        if (String.isNotBlank(objMap.get('CommodityCode__c')))
            wrapperList.add(new FieldMapping('Commodity Code', 'obj', objMap.get('CommodityCode__c'), 'CommodityCode__c'));
        if (String.isNotBlank(objMap.get('LineDeliveryTerm__c')))
            wrapperList.add(new FieldMapping('Line Delivery Term', 'obj', objMap.get('LineDeliveryTerm__c'), 'LineDeliveryTerm__c'));

        
        
        MAP<String, String> lineDestMap = AddressMappingNameToFieldValuePairs.get('CPQ Line Dest Map');
        if (lineDestMap != null){  //Should never be null
            if (String.isNotBlank(lineDestMap.get('Address1__c')))
                wrapperList.add(new FieldMapping('Destination Address 1', 'dest', lineDestMap.get('Address1__c'), 'Address1__c'));
            if (String.isNotBlank(lineDestMap.get('Address2__c')))
                wrapperList.add(new FieldMapping('Destination Address 2', 'dest', lineDestMap.get('Address2__c'), 'Address2__c'));
            if (String.isNotBlank(lineDestMap.get('City__c')))
                wrapperList.add(new FieldMapping('Destination City', 'dest', lineDestMap.get('City__c'), 'City__c'));
            if (String.isNotBlank(lineDestMap.get('Country__c')))
                wrapperList.add(new FieldMapping('Destination Country', 'dest', lineDestMap.get('Country__c'), 'Country__c'));
            if (String.isNotBlank(lineDestMap.get('CustomerClassCode__c')))
                wrapperList.add(new FieldMapping('Destination Customer Class Code', 'dest', lineDestMap.get('CustomerClassCode__c'), 'CustomerClassCode__c'));
            if (String.isNotBlank(lineDestMap.get('CustomerCode__c')))
                wrapperList.add(new FieldMapping('Destination Customer Code', 'dest', lineDestMap.get('CustomerCode__c'), 'CustomerCode__c'));
            if (String.isNotBlank(lineDestMap.get('PostalCode__c')))
                wrapperList.add(new FieldMapping('Destination Postal Code', 'dest', lineDestMap.get('PostalCode__c'), 'PostalCode__c'));
            if (String.isNotBlank(lineDestMap.get('State__c')))
                wrapperList.add(new FieldMapping('Destination State', 'dest', lineDestMap.get('State__c'), 'State__c'));
            if (String.isNotBlank(lineDestMap.get('TaxAreaID__c')))
                wrapperList.add(new FieldMapping('Destination Tax Area ID', 'dest', lineDestMap.get('TaxAreaID__c'), 'TaxAreaID__c'));
            if (String.isNotBlank(lineDestMap.get('LocationCode__c')))
                wrapperList.add(new FieldMapping('Destination Location Code', 'dest', lineDestMap.get('LocationCode__c'), 'LocationCode__c'));
        }
        //Admin Origin Address
        MAP<String, String> lineAdminAddr = AddressMappingNameToFieldValuePairs.get('CPQ Line Admin');
        if (lineAdminAddr != null){
            if (String.isNotBlank(lineAdminAddr.get('Address1__c')))
                wrapperList.add(new FieldMapping('Admin Origin Address 1', 'orig-admin', lineAdminAddr.get('Address1__c'), 'Address1__c'));
            if (String.isNotBlank(lineAdminAddr.get('Address2__c')))
                wrapperList.add(new FieldMapping('Admin Origin Address 2', 'orig-admin', lineAdminAddr.get('Address2__c'), 'Address2__c'));
            if (String.isNotBlank(lineAdminAddr.get('City__c')))
                wrapperList.add(new FieldMapping('Admin Origin City', 'orig-admin', lineAdminAddr.get('City__c'), 'City__c'));
            if (String.isNotBlank(lineAdminAddr.get('Country__c')))
                wrapperList.add(new FieldMapping('Admin Origin Country', 'orig-admin', lineAdminAddr.get('Country__c'), 'Country__c'));
            if (String.isNotBlank(lineAdminAddr.get('PostalCode__c')))
                wrapperList.add(new FieldMapping('Admin Origin Postal Code', 'orig-admin', lineAdminAddr.get('PostalCode__c'), 'PostalCode__c'));
            if (String.isNotBlank(lineAdminAddr.get('State__c')))
                wrapperList.add(new FieldMapping('Admin Origin State', 'orig-admin', lineAdminAddr.get('State__c'), 'State__c'));
            if (String.isNotBlank(lineAdminAddr.get('TaxAreaID__c')))
                wrapperList.add(new FieldMapping('Admin Origin Tax Area ID', 'orig-admin', lineAdminAddr.get('TaxAreaID__c'), 'TaxAreaID__c'));
            if (String.isNotBlank(lineAdminAddr.get('LocationCode__c')))
                wrapperList.add(new FieldMapping('Admin Origin Location Code', 'orig-admin', lineAdminAddr.get('LocationCode__c'), 'LocationCode__c'));
        }

        //Physical Origin Address
        MAP<String, String> linePhysAddr = AddressMappingNameToFieldValuePairs.get('CPQ Line Phys');
        if (linePhysAddr != null){
            if (String.isNotBlank(linePhysAddr.get('Address1__c')))
                wrapperList.add(new FieldMapping('Physical Origin Address 1', 'orig-phys', linePhysAddr.get('Address1__c'), 'Address1__c'));
            if (String.isNotBlank(linePhysAddr.get('Address2__c')))
                wrapperList.add(new FieldMapping('Physical Origin Address 2', 'orig-phys', linePhysAddr.get('Address2__c'), 'Address2__c'));
            if (String.isNotBlank(linePhysAddr.get('City__c')))
                wrapperList.add(new FieldMapping('Physical Origin City', 'orig-phys', linePhysAddr.get('City__c'), 'City__c'));
            if (String.isNotBlank(linePhysAddr.get('Country__c')))
                wrapperList.add(new FieldMapping('Physical Origin Country', 'orig-phys', linePhysAddr.get('Country__c'), 'Country__c'));
            if (String.isNotBlank(linePhysAddr.get('PostalCode__c')))
                wrapperList.add(new FieldMapping('Physical Origin Postal Code', 'orig-phys', linePhysAddr.get('PostalCode__c'), 'PostalCode__c'));
            if (String.isNotBlank(linePhysAddr.get('State__c')))
                wrapperList.add(new FieldMapping('Physical Origin State', 'orig-phys', linePhysAddr.get('State__c'), 'State__c'));
            if (String.isNotBlank(linePhysAddr.get('TaxAreaID__c')))
                wrapperList.add(new FieldMapping('Physical Origin Tax Area ID', 'orig-phys', linePhysAddr.get('TaxAreaID__c'), 'TaxAreaID__c'));
            if (String.isNotBlank(linePhysAddr.get('LocationCode__c')))
                wrapperList.add(new FieldMapping('Physical Origin Location Code', 'orig-phys', linePhysAddr.get('LocationCode__c'), 'LocationCode__c'));
        }

        Map<String, String> fetchFldSetting;
        String cartSettingID = objMap.get('Id');
        //Flex Mappings
        if (FlexFieldNameToFieldValuePairs != null){
            for (Integer i = 1; i <= 25; i++){
                fetchFldSetting = FlexFieldNameToFieldValuePairs.get('Line Text ' + i + ': ' + cartSettingID);
                if (fetchFldSetting != null && String.isNotBlank(fetchFldSetting.get('SourceField__c'))){
                    wrapperList.add(new FieldMapping('Flex Text Field ' + i, 'fld', fetchFldSetting.get('SourceField__c'), fetchFldSetting.get('Id')));
                }
            }
            
            for (Integer i = 1; i <= 10; i++){
                fetchFldSetting = FlexFieldNameToFieldValuePairs.get('Line Number ' + i + ': ' + cartSettingID);
                if (fetchFldSetting != null && String.isNotBlank(fetchFldSetting.get('SourceField__c')))
                    wrapperList.add(new FieldMapping('Flex Number Field ' + i, 'fld', fetchFldSetting.get('SourceField__c'), fetchFldSetting.get('Id')));
            }
            
            for (Integer i = 1; i <= 5; i++){
                fetchFldSetting = FlexFieldNameToFieldValuePairs.get('Line Date ' + i + ': ' + cartSettingID);
                if (fetchFldSetting != null && String.isNotBlank(fetchFldSetting.get('SourceField__c')))
                    wrapperList.add(new FieldMapping('Flex Date Field ' + i, 'fld', fetchFldSetting.get('SourceField__c'), fetchFldSetting.get('Id')));
            }
        }
        return wrapperList;
    }

    public List<SelectOption> getUnboundCartItemMappings(){
        Map<String, String> objMap = ObjectMappingNameToFieldValuePairs.get('CPQ');
        transient List<SelectOption> optList = new List<SelectOption>();

        //Optional Mappings
        if (String.isBlank(objMap.get('ChildSourcePicklist__c')))
            optList.add(new SelectOption('obj: ChildSourcePicklist__c', 'Line Item Origin Field'));
        if (String.isBlank(objMap.get('ItemTaxPayerField__c')))
            optList.add(new SelectOption('obj: ItemTaxPayerField__c', 'Line Item Tax Payer'));
        if (String.isBlank(objMap.get('ItemClassField__c')))
            optList.add(new SelectOption('obj: ItemClassField__c', 'Product Class'));
        if (String.isBlank(objMap.get('ItemNameField__c')))
            optList.add(new SelectOption('obj: ItemNameField__c', 'Product Code'));
        if (String.isBlank(objMap.get('InvoiceTextCodes__c')))
            optList.add(new SelectOption('obj: InvoiceTextCodes__c', 'Invoice Text Codes'));
        if (String.isBlank(objMap.get('TaxCode__c')))
            optList.add(new SelectOption('obj: TaxCode__c', 'Tax Code'));
        if (String.isBlank(objMap.get('VertexTaxCode__c')))
            optList.add(new SelectOption('obj: VertexTaxCode__c', 'Vertex Tax Code'));
        if (String.isBlank(objMap.get('CommodityCode__c')))
            optList.add(new SelectOption('obj: CommodityCode__c', 'Commodity Code'));
        if (String.isBlank(objMap.get('LineDeliveryTerm__c')))
            optList.add(new SelectOption('obj: LineDeliveryTerm__c', 'Line Delivery Term'));
 
       //Destination Mappings
        MAP<String, String> lineDestMap = AddressMappingNameToFieldValuePairs.get('CPQ Line Dest Map');
        if (lineDestMap != null){  //Should never be null
            if (String.isBlank(lineDestMap.get('Address1__c')))
                optList.add(new SelectOption('dest: Address1__c', 'Destination Address 1'));
            if (String.isBlank(lineDestMap.get('Address2__c')))
                optList.add(new SelectOption('dest: Address2__c', 'Destination Address 2'));
            if (String.isBlank(lineDestMap.get('City__c')))
                optList.add(new SelectOption('dest: City__c', 'Destination City'));
            if (String.isBlank(lineDestMap.get('Country__c')))
                optList.add(new SelectOption('dest: Country__c', 'Destination Country'));
            if (String.isBlank(lineDestMap.get('CustomerClassCode__c')))
                optList.add(new SelectOption('dest: CustomerClassCode__c', 'Destination Customer Class Code'));
            if (String.isBlank(lineDestMap.get('CustomerCode__c')))
                optList.add(new SelectOption('dest: CustomerCode__c', 'Destination Customer Code'));
            if (String.isBlank(lineDestMap.get('PostalCode__c')))
                optList.add(new SelectOption('dest: PostalCode__c', 'Destination Postal Code'));
            if (String.isBlank(lineDestMap.get('State__c')))
                optList.add(new SelectOption('dest: State__c', 'Destination State'));
            if (String.isBlank(lineDestMap.get('TaxAreaID__c')))
                optList.add(new SelectOption('dest: TaxAreaID__c', 'Destination Tax Area ID'));
            if (String.isBlank(lineDestMap.get('LocationCode__c')))
                optList.add(new SelectOption('dest: LocationCode__c', 'Destination Location Code'));
        }
        //Admin Origin Address
        MAP<String, String> lineAdminAddr = AddressMappingNameToFieldValuePairs.get('CPQ Line Admin');
        if (lineAdminAddr != null){
            if (String.isBlank(lineAdminAddr.get('Address1__c')))
                optList.add(new SelectOption('orig-admin: Address1__c', 'Admin Origin Address 1'));
            if (String.isBlank(lineAdminAddr.get('Address2__c')))
                optList.add(new SelectOption('orig-admin: Address2__c', 'Admin Origin Address 2'));
            if (String.isBlank(lineAdminAddr.get('City__c')))
                optList.add(new SelectOption('orig-admin: City__c', 'Admin Origin City'));
            if (String.isBlank(lineAdminAddr.get('Country__c')))
                optList.add(new SelectOption('orig-admin: Country__c', 'Admin Origin Country'));
            if (String.isBlank(lineAdminAddr.get('PostalCode__c')))
                optList.add(new SelectOption('orig-admin: PostalCode__c', 'Admin Origin Postal Code'));
            if (String.isBlank(lineAdminAddr.get('State__c')))
                optList.add(new SelectOption('orig-admin: State__c', 'Admin Origin State'));
            if (String.isBlank(lineAdminAddr.get('TaxAreaID__c')))
                optList.add(new SelectOption('orig-admin: TaxAreaID__c', 'Admin Origin Tax Area ID'));
            if (String.isBlank(lineAdminAddr.get('LocationCode__c')))
                optList.add(new SelectOption('orig-admin: LocationCode__c', 'Admin Origin Location Code'));
        }
        //Physical Origin Address
        MAP<String, String> linePhysAddr = AddressMappingNameToFieldValuePairs.get('CPQ Line Phys');
        if (linePhysAddr != null){
            if (String.isBlank(linePhysAddr.get('Address1__c')))
                optList.add(new SelectOption('orig-phys: Address1__c', 'Physical Origin Address 1'));
            if (String.isBlank(linePhysAddr.get('Address2__c')))
                optList.add(new SelectOption('orig-phys: Address2__c', 'Physical Origin Address 2'));
            if (String.isBlank(linePhysAddr.get('City__c')))
                optList.add(new SelectOption('orig-phys: City__c', 'Physical Origin City'));
            if (String.isBlank(linePhysAddr.get('Country__c')))
                optList.add(new SelectOption('orig-phys: Country__c', 'Physical Origin Country'));
            if (String.isBlank(linePhysAddr.get('PostalCode__c')))
                optList.add(new SelectOption('orig-phys: PostalCode__c', 'Physical Origin Postal Code'));
            if (String.isBlank(linePhysAddr.get('State__c')))
                optList.add(new SelectOption('orig-phys: State__c', 'Physical Origin State'));
            if (String.isBlank(linePhysAddr.get('TaxAreaID__c')))
                optList.add(new SelectOption('orig-phys: TaxAreaID__c', 'Physical Origin Tax Area ID'));
            if (String.isBlank(linePhysAddr.get('LocationCode__c')))
                optList.add(new SelectOption('orig-phys: LocationCode__c', 'Physical Origin Location Code'));
        }

        Map<String, String> fetchFldSetting;
        String cartSettingID = objMap.get('Id');
        //Flex Mappings
        if (FlexFieldNameToFieldValuePairs != null){
            for (Integer i = 1; i <= 25; i++){
                fetchFldSetting = FlexFieldNameToFieldValuePairs.get('Line Text ' + i + ': ' + cartSettingID);
                if (fetchFldSetting == null || (fetchFldSetting != null && String.isBlank(fetchFldSetting.get('SourceField__c'))))
                    optList.add(new SelectOption('fld: Line Text ' + i, 'Flex Text Field ' + i));
            }
            
            for (Integer i = 1; i <= 10; i++){
                fetchFldSetting = FlexFieldNameToFieldValuePairs.get('Line Number ' + i + ': ' + cartSettingID);
                if (fetchFldSetting == null || (fetchFldSetting != null && String.isBlank(fetchFldSetting.get('SourceField__c'))))
                    optList.add(new SelectOption('fld: Line Number ' + i, 'Flex Number Field ' + i));
            }
            
            for (Integer i = 1; i <= 5; i++){
                fetchFldSetting = FlexFieldNameToFieldValuePairs.get('Line Date ' + i + ': ' + cartSettingID);
                if (fetchFldSetting == null || (fetchFldSetting != null && String.isBlank(fetchFldSetting.get('SourceField__c'))))
                    optList.add(new SelectOption('fld: Line Date ' + i, 'Flex Date Field ' + i));
            }
        }
        return optList;
    }

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // VALIDITY CHECK
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    private Map<List<String>, Map<String, String>> FieldDataTypes = new Map<List<String>, Map<String, String>>();

    public void RefreshValidityChecks(){
        FieldValidityResults = null;
        FieldPermissionResults = null;
        DataTypeResults = null;
        FieldDataTypes = new Map<List<String>, Map<String, String>>();
    }

    //{Mapping Name, sObject Name} --> List of fields (taken from object, field, and address mappings)
    public Map<List<String>, List<String>> getObjFieldMap(){
        transient Map<List<String>, List<String>> objFieldMap = new Map<List<String>, List<String>>();
        Map<String, String> objMap = ObjectMappingNameToFieldValuePairs.get('CPQ');
        Map<String, String> cartDestMap = AddressMappingNameToFieldValuePairs.get('CPQ Trans Dest Map');
        Map<String, String> cartItemDestMap = AddressMappingNameToFieldValuePairs.get('CPQ Line Dest Map');
        Map<String, String> cartAdminOriginMap = AddressMappingNameToFieldValuePairs.get('CPQ Trans Admin');
        Map<String, String> cartItemAdminOriginMap = AddressMappingNameToFieldValuePairs.get('CPQ Line Admin');
        Map<String, String> cartPhysOriginMap = AddressMappingNameToFieldValuePairs.get('CPQ Trans Phys');
        Map<String, String> cartItemPhysOriginMap = AddressMappingNameToFieldValuePairs.get('CPQ Line Phys');
        
        //Transaction object (Cart)
        Map<String, String> cartMappings = new Map<String, String>();
        cartMappings.put(objMap.get('TransactionNumber__c'), 'STRING');
        cartMappings.put(objMap.get('TransactionDate__c'), 'DATE');
        cartMappings.put(objMap.get('Posting_Date__c'), 'DATE');
        cartMappings.put(objMap.get('ParentSourcePicklist__c'), 'STRING');
        cartMappings.put(objMap.get('TransactionTaxPayer__c'), 'STRING');
        cartMappings.put(objMap.get('TaxRegistrationNumber__c'), 'STRING');
        cartMappings.put(objMap.get('TransactionDeliveryTerm__c'), 'STRING');
        cartMappings.put(cartDestMap.get('CustomerCode__c'), 'STRING');
        cartMappings.put(cartDestMap.get('CustomerClassCode__c'), 'STRING');
        for (String fldName : cartAdminOriginMap.keySet())
            if (!fldName.equalsIgnoreCase('id'))
                cartMappings.put(cartAdminOriginMap.get(fldName), 'STRING');
        for (String fldName : cartPhysOriginMap.keySet())
            if (!fldName.equalsIgnoreCase('id'))
                cartMappings.put(cartPhysOriginMap.get(fldName), 'STRING');
        cartMappings.remove(null);
        cartMappings.remove('');
        
        objFieldMap.put(new List<String>{'CPQ', 'SBQQ__Quote__c'}, new List<String>(cartMappings.keySet()));
        FieldDataTypes.put(new List<String>{'CPQ', 'SBQQ__Quote__c'}, cartMappings);

        //Line object (Line Item)
        Map<String, String> cartItemMappings = new Map<String, String>();
        cartItemMappings.put(objMap.get('ChildSourcePicklist__c'), 'STRING');
        cartItemMappings.put(objMap.get('ItemClassField__c'), 'STRING');
        cartItemMappings.put(objMap.get('ItemNameField__c'), 'STRING');
        cartItemMappings.put(objMap.get('ItemTaxPayerField__c'), 'STRING');
        cartItemMappings.put(objMap.get('InvoiceTextCodes__c'), 'STRING');
        cartItemMappings.put(objMap.get('TaxCode__c'), 'STRING');
        cartItemMappings.put(objMap.get('CommodityCode__c'), 'STRING');
        cartItemMappings.put(cartItemDestMap.get('CustomerCode__c'), 'STRING');
        cartItemMappings.put(cartItemDestMap.get('CustomerClassCode__c'), 'STRING');
        for (String fldName : cartItemAdminOriginMap.keySet())
            if (!fldName.equalsIgnoreCase('id'))
                cartItemMappings.put(cartItemAdminOriginMap.get(fldName), 'STRING');
        for (String fldName : cartItemPhysOriginMap.keySet())
            if (!fldName.equalsIgnoreCase('id'))
                cartMappings.put(cartItemPhysOriginMap.get(fldName), 'STRING');
        
        String cartSettingID = objMap.get('Id');
        if (FlexFieldNameToFieldValuePairs != null){
            for (Map<String, String> fldVals : FlexFieldNameToFieldValuePairs.values()){
                if (fldVals.get('ObjectMapping__c') == cartSettingID){
                    String flexFldType = fldVals.get('Label__c').substringBetween('Flex ', ' Field');
                    String dataType = flexFldType == 'Text' || flexFldType == 'Number' ? 'STRING' : 'DATE';
                    cartItemMappings.put(fldVals.get('SourceField__c'), dataType);
                }
            }
        }
        
        cartItemMappings.remove(null);
        cartItemMappings.remove('');

        objFieldMap.put(new List<String>{'CPQ', 'SBQQ__QuoteLine__c'}, new List<String>(cartItemMappings.keySet()));
        FieldDataTypes.put(new List<String>{'CPQ', 'SBQQ__QuoteLine__c'}, cartItemMappings);

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
                if (GDMap.get(obj) == null){
                    FieldValidityResults.add(obj + ' is not a valid object');
                    continue;
                }
                objectFields = GDMap.get(obj).getDescribe().fields.getMap().keySet();
                for (String fld : objFldMap.get(mapKey)){
                    if (fld.contains('.'))
                        FieldValidityResults.add(mapName + ': ' + fld + ' is a field relationship that cannot be automatically validated. The user must confirm the correctness of this field manually.');
                    else if (!objectFields.contains(fld.toLowerCase()))
                        FieldValidityResults.add(mapName + ': ' + fld + ' is not a valid field on ' + obj);
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
                //  Just bail on this loop if the object is invalid (already reported error elsewhere)
                if (GDMap.get(obj) == null) continue;
                
                objDescr = GDMap.get(obj).getDescribe();

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

            for (List<String> mapKey : objFldMap.keySet()){
                String mapName = mapKey[0];
                String obj = mapKey[1];
                //  Just bail on this loop if the object is invalid (already reported error elsewhere)
                if (GDMap.get(obj) == null) continue;
                objDescr = GDMap.get(obj).getDescribe();

                for (String fld : objFldMap.get(mapKey)){
                    //Skip invalid fields that were caught in getFieldValidityResults()
                    if (!objDescr.fields.getMap().keySet().contains(fld.toLowerCase()))
                        continue;
                    fldDescr = objDescr.fields.getMap().get(fld.toLowerCase()).getDescribe();
                    String fldErrMsg;
                    if (!fldDescr.isAccessible()){
                        fldErrMsg = 'You do not have read permissions for ' + fld + ' on ' + obj;
                        FieldPermissionResults.add(mapName + ': ' + fldErrMsg);
                    }
                }
            }
        }
        return FieldPermissionResults;
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

    public class FieldMapping {
        public String label {get; set;}     //i.e. Product Class, Line Tax Payer, Flex Text Field 1, Flex Date Field 5, etc
        public String settingType {get; set;}   //"obj": Save to VertexObjectMapping__c, "fld": Save to VertexFieldMapping__c
        public String sourceField {get; set;}
        public String settingLoc {get; set;}   //For "obj": API name of the field to write on VertexObjectMapping__c. For "fld": Custom Setting ID.

        public FieldMapping(String theLabel, String theSettingType, String theSourceField, String theSettingLocation){
            label = theLabel;
            settingType = theSettingType;
            sourceField = thesourceField;
            settingLoc = theSettingLocation;
        }
    }

    public VertexCPQSettings__c config { 
        get{
            config = VertexCPQCore.ActiveSettings;
            return config;
        }
        set; 
    }

    @RemoteAction
    public static void setAsychronousCallout(Boolean setting){
        transient VertexCPQSettings__c config = VertexCPQCore.ActiveSettings;
        config.AsynchronousCPQCallout__c = setting;
        update config;
    }
}
@isTest
public class VertexSettingsControllerTest {

    @isTest
    public static void legacyTest() {

        // Given
        transient VertexDataInit dataInit = new VertexDataInit();
        dataInit.CreateVanilla();

        transient VertexSettingsController controller = new VertexSettingsController();

        transient VertexLog__c log = new VertexLog__c(
                    Details__c = 'details',
                    Endpoint__c = 'endpoint',
                    Request__c = 'request',
                    Response__c = 'response',
                    ResponseStatus__c = 'responseStatus',
                    ResponseStatusCode__c = 200
                );

        insert log;

        // When

        TestSetup.CreateConfigurations();

        Test.startTest();
        
        // Callout to check authentication          
        Test.setMock(HttpCalloutMock.class, new CheckVersionMockHttpResponse());
        VertexSettingsController.ValidateAddressAndTaxURLs();

        // Callout to verify the above address
        Test.setMock(HttpCalloutMock.class, new VerifyAddressMockHttpResponse());
        List<VertexAddress__c> results = VertexSettingsController.VerifyAddress(controller.AddressList.get(0).Name);

        Boolean isComplete = VertexSettingsController.AddressIsComplete(controller.AddressList.get(0).Name);
        System.assert(isComplete);

        // Change to the verified address returned by the response
        VertexSettingsController.UpdateAddress(controller.AddressList.get(0), controller.AddressList.get(0));

        VertexSettingsController.SetAddressValidationField(true);
        System.assertEquals(true, VertexCore.ActiveSettings.AllowAddressValidation__c);

        Test.stopTest();

        // exploit null pattern to grab from the updated custom setting values
        controller.AddressList = null;

        // Call the methods used by the page to obtain data
        controller.AddressList = controller.AddressList;
        controller.config = controller.config;

        Object dummyObject;
        dummyObject = controller.getObjectList();

        dummyObject = controller.getEstTransObjs();
        dummyObject = controller.getOrderTransObjs();
        dummyObject = controller.getInvTransObjs();

        dummyObject = controller.getEstimateParentFldList();
        dummyObject = controller.getestLineFldList();
        dummyObject = controller.getOrderParentFldList();
        dummyObject = controller.getorderLineFldList();
        dummyObject = controller.getInvoiceParentFldList();
        dummyObject = controller.getinvLineFldList();

        dummyObject = VertexSettingsController.getMappingOptions('Estimate Trans Dest Map', '');
        dummyObject = VertexSettingsController.getMappingOptions('Estimate Line Dest Map', '');
        dummyObject = VertexSettingsController.getMappingOptions('Order Trans Dest Map', '');
        dummyObject = VertexSettingsController.getMappingOptions('Order Line Dest Map', '');
        dummyObject = VertexSettingsController.getMappingOptions('Invoice Trans Dest Map', '');
        dummyObject = VertexSettingsController.getMappingOptions('Invoice Line Dest Map', '');        

        VertexSettingsController.buildLogTable();
        VertexSettingsController.queryVertexLog(log.Id);

        VertexSettingsController.DeleteAddress(controller.AddressList.get(0).ID);
    }

    public static testMethod void itemMappingsTest(){
        VertexDataInit dataInit = new VertexDataInit();
        dataInit.CreateVanilla();
        TestSetup.CreateConfigurations();

        VertexSettingsController con = new VertexSettingsController();

        con.NameSpacePrefix = null;
        System.debug(con.NameSpacePrefix);

        System.assert(con.getItemMappings().size() != 0);
        System.assert(VertexSettingsController.getItemMappingsRA().size() != 0);

        //Insert a new item mapping
        VertexSettingsController.ObjectMapSetting objMapSetting = new VertexSettingsController.ObjectMapSetting();
        objMapSetting.mappingName = 'Custom Map?';
        objMapSetting.xmlMessage = 'Quote';
        objMapSetting.transactionType = 'Sales';
        objMapSetting.parentObj = 'Opportunity';
        objMapSetting.lineObj = 'OpportunityLineItem';
        objMapSetting.parentLookup = 'OpportunityId';
        objMapSetting.relationshipName = 'OpportunityLineItems';
        objMapSetting.transactionTaxAmount = 'Amount';
        objMapSetting.transactionDate = 'CloseDate';
        objMapSetting.documentNumber = 'Name';
        objMapSetting.taxAmount = VertexCore.NamespaceString + 'TaxRuleId__c';
        objMapSetting.extendedPrice = 'TotalPrice';
        objMapSetting.quantity = 'Quantity';
        VertexSettingsController.SaveItemMapping(objMapSetting);
        VertexObjectMapping__c createdSetting = VertexObjectMapping__c.getInstance('Custom Map?');
        System.assertEquals('Opportunity', createdSetting.ParentSObject__c);

        //Rename it
        objMapSetting.settingID = createdSetting.ID;
        objMapSetting.mappingName = 'Custom Map';
        VertexSettingsController.SaveItemMapping(objMapSetting);
        createdSetting = VertexObjectMapping__c.getInstance('Custom Map');

        //Try the object filtering method
        List<String> filteredObjList = VertexSettingsController.getFilteredObjects('Acc');
        Set<String> filteredObjSet = new Set<String>(filteredObjList);
        System.assert(filteredObjSet.contains('Account'));

        List<String> childObjJsonList = VertexSettingsController.getChildObjects('Case');
        System.assert(!childObjJsonList.isEmpty());

        //Insert an "additional" mapping on the object setting (read: optional mapping)
        VertexSettingsController.AddAdditionalMapping(createdSetting.ID, 'transaction', 'obj', 'TransactionTaxPayer__c', 'AccountID');
        createdSetting = VertexObjectMapping__c.getInstance('Custom Map');
        System.assertEquals('AccountID', createdSetting.TransactionTaxPayer__c);

        //Insert an "additional" mapping on the field setting (read: flex mapping)
        VertexSettingsController.AddAdditionalMapping(createdSetting.ID, 'line', 'fld', 'Line Text 1', 'Description');
        VertexFieldMapping__c fldMapping = VertexFieldMapping__c.getInstance('Line Text 1: ' + createdSetting.ID);
        System.assert(fldMapping != null);
        System.assertEquals('Description', fldMapping.SourceField__c);
        System.assertEquals('line', fldMapping.Type__c);

        //Confirm that these two mappings are accounted for
        Map<String, List<VertexSettingsController.AdditionalItemMapping>> transBoundAddlMappings = con.getBoundAdditionalTransItmMaps();
        System.assertEquals(2, transBoundAddlMappings.get(createdSetting.ID).size());    //Optional mapping we created, plus a blank placeholder
        Map<String, List<VertexSettingsController.AdditionalItemMapping>> lineBoundAddlMappings = con.getBoundAdditionalLineItmMaps();
        System.assertEquals(2, lineBoundAddlMappings.get(createdSetting.ID).size());    //Flex mapping we created, plus a blank placeholder

        //Confirm unbound mappings
        Map<String, List<SelectOption>> transUnboundAddlMappings = con.getUnboundAdditionalTransItmMaps();
        System.assert(transUnboundAddlMappings.get(createdSetting.ID).size() > 0);
        Map<String, List<SelectOption>> lineUnboundAddlMappings = con.getUnboundAdditionalLineItmMaps();
        System.assert(lineUnboundAddlMappings.get(createdSetting.ID).size() > 0);

        //Clone this item mapping
        VertexSettingsController.CloneItemMapping(createdSetting.ID);
        VertexObjectMapping__c clonedSetting = VertexObjectMapping__c.getInstance('Custom Map Copy');
        System.assertEquals('Opportunity', clonedSetting.ParentSObject__c);
        System.assert(VertexAddress__c.getInstance('Custom Map Copy Trans Dest Map') != null);

        //Delete the clone
        VertexSettingsController.DeleteItemMapping(clonedSetting.ID);
        System.assertEquals(null, VertexObjectMapping__c.getInstance('Custom Map Copy'));
        System.assertEquals(null, VertexAddress__c.getInstance('Custom Map Copy Trans Dest Map'));

        //Delete both additional mappings
        VertexSettingsController.DeleteAdditionalMapping(createdSetting.ID, 'Trans', 'obj', 'TransactionTaxPayer__c');
        createdSetting = VertexObjectMapping__c.getInstance('Custom Map');
        System.assert(String.isBlank(createdSetting.TransactionTaxPayer__c));
        VertexSettingsController.DeleteAdditionalMapping(createdSetting.ID, 'Line', 'fld', fldMapping.ID);
        fldMapping = VertexFieldMapping__c.getInstance('Line Text 1: ' + createdSetting.ID);
        System.assertEquals(null, fldMapping);

        //Add a destination field mapping
        VertexSettingsController.AddAdditionalMapping(createdSetting.ID, 'transaction', 'dest', 'Address1__c', 'Description');
        System.assertEquals('Description', VertexAddress__c.getInstance('Custom Map Trans Dest Map').Address1__c);

        //Delete the destination field mapping
        VertexSettingsController.DeleteAdditionalMapping(createdSetting.ID, 'Trans', 'dest', 'Address1__c');
        System.assertEquals(null, VertexAddress__c.getInstance('Custom Map Trans Dest Map').Address1__c);

        VertexSettingsController.Refresh();
        VertexSettingsController.ResetAllMappings();
        System.assertEquals(null, VertexObjectMapping__c.getInstance('Custom Map'));

        VertexSettingsController.UpdateFldList('Case');
    }

    public static testMethod void validityCheckTest(){
        VertexDataInit dataInit = new VertexDataInit();
        dataInit.CreateVanilla();
        TestSetup.CreateConfigurations();

        VertexSettingsController con = new VertexSettingsController();
        System.assertEquals(0, con.getFieldValidityResults().size());
        System.assertEquals(0, con.getFieldPermissionResults().size());
        con.getIncompleteDestinationMappings();
        con.RefreshValidityChecks();
        
        //Cover failure cases
        VertexObjectMapping__c estimateMapping = VertexObjectMapping__c.getInstance('Estimate');
        estimateMapping.ItemTaxField__c = 'Id';     //Cannot write to this field
        estimateMapping.TransactionNumber__c = 'BogusField';    //Invalid field
        estimateMapping.TransactionDate__c = 'Name';    //Wrong data type
        update estimateMapping;
        System.assertEquals(1, con.getFieldValidityResults().size());
        System.assertEquals(1, con.getFieldPermissionResults().size());
        System.assertEquals(1, con.getDataTypeResults().size());
    }

    //  Structure from Billing for testing Billing callout
    public class MappingConfigTemplate{
        public String estTransOrigin                     { get; set; }
        public String orderTransOrigin                   { get; set; }
        public String invTransOrigin                     { get; set; }
                    
        public String estTransTaxPayer                   { get; set; }
        public String orderTransTaxPayer                 { get; set; }
        public String invTransTaxPayer                   { get; set; }
                    
        public String estLineOrigin                      { get; set; }
        public String orderLineOrigin                    { get; set; }
        public String invLineOrigin                      { get; set; }

        public String estItemClass                       { get; set; }
        public String orderItemClass                     { get; set; }
        public String invItemClass                       { get; set; }

        public String estItemName                        { get; set; }
        public String orderItemName                      { get; set; }
        public String invItemName                        { get; set; }

        public String estItemTaxPayer                    { get; set; }
        public String orderItemTaxPayer                  { get; set; }
        public String invItemTaxPayer                    { get; set; }
    }

    public static Map<String, Map<String, String>> AddressMappingNameToFieldValuePairs {
        get {
            if (AddressMappingNameToFieldValuePairs == null)
                AddressMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new list<object>{'fetchAddyMap'});
            return AddressMappingNameToFieldValuePairs;
        }
        set;
    }

    public static Map<String, Map<String, String>> ObjectMappingNameToFieldValuePairs {
        get {
            if (ObjectMappingNameToFieldValuePairs == null)
                ObjectMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new list<object>{'fetchObjMap'});
            return ObjectMappingNameToFieldValuePairs;
        }
        set;
    }

    public static Map<String, Map<String, String>> FieldMappingNameToFieldValuePairs {
        get {
            if (FieldMappingNameToFieldValuePairs == null)
                FieldMappingNameToFieldValuePairs = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new List<object>{'fetchFldMap'});
            return FieldMappingNameToFieldValuePairs;
        }
        set;
    }

    public static testMethod void BillingConfigTest(){
        VertexSettingsControllerTest.MappingConfigTemplate config = new VertexSettingsControllerTest.MappingConfigTemplate();
       
        ObjectMappingNameToFieldValuePairs.get('SFInv').put(VertexCore.NamespaceString+'ParentSourcePicklist__c', 'testVal');
        VertexGlobal.GlobalHelper(new list<object>{'saveObjMap', ObjectMappingNameToFieldValuePairs});

        Map<String, String> invLineAddyMap = AddressMappingNameToFieldValuePairs.get('SFInv Line Dest Map');
        invLineAddyMap.put(VertexCore.NamespaceString+'Address1__c', 'testAddyField');
        AddressMappingNameToFieldValuePairs.put('SFInv Line Dest Map', invLineAddyMap);
        VertexGlobal.GlobalHelper(new list<object>{'saveAddyMap', AddressMappingNameToFieldValuePairs});

		// Then
        ObjectMappingNameToFieldValuePairs = null;
        AddressMappingNameToFieldValuePairs = null;

        System.assertEquals(ObjectMappingNameToFieldValuePairs.get('SFInv').get(VertexCore.NamespaceString+'ParentSourcePicklist__c'), 'testVal');
        System.assertEquals(AddressMappingNameToFieldValuePairs.get('SFInv Line Dest Map').get(VertexCore.NamespaceString+'Address1__c'), 'testAddyField');
    }

    public static testMethod void CloudCrazeConfigTest(){
        VertexDataInit di = new VertexDataInit();
        di.CreateVanillaObjMappings();

        String estimateSettingID = VertexObjectMapping__c.getInstance('Estimate').ID;

        //Fetch flex field
        VertexSettingsController.AddAdditionalMapping(estimateSettingID, 'line', 'fld', 'Line Text 1', 'Description');
        System.assert(FieldMappingNameToFieldValuePairs.get('Line Text 1: ' + estimateSettingID) != null);

        //Create flex field
        Map<String, Map<String, String>> writeSettings = new Map<String, Map<String, String>>();
        Map<String, String> settingValues = new Map<String, String>();
        settingValues.put('Label__c', 'Flex Text Field 2');
        settingValues.put('ObjectMapping__c', estimateSettingID);
        settingValues.put('SourceField__c', 'FakeField__c');
        settingValues.put('Type__c', 'line');
        writeSettings.put('Line Text 2: ' + estimateSettingID, settingValues);
        VertexGlobal.GlobalHelper(new List<object>{'saveFldMap', writeSettings});

        ID flexFieldId = [SELECT ID FROM VertexFieldMapping__c WHERE Label__c = 'Flex Text Field 2' LIMIT 1].ID;

        //Delete flex field
        VertexGlobal.GlobalHelper(new List<object>{'deleteFldMap', flexFieldId});
        FieldMappingNameToFieldValuePairs = null;
        System.assertEquals(null, FieldMappingNameToFieldValuePairs.get('Line Text 2: ' + estimateSettingID));

        VertexGlobal.GlobalHelper(new List<object>{'fetchObjMap', new List<String>{'Estimate'}});

        VertexGlobal.GlobalHelper(new list<object>{'suppressLogs', true});
        VertexGlobal.GlobalHelper(new list<object>{'suppressLogs', false});
    }
}
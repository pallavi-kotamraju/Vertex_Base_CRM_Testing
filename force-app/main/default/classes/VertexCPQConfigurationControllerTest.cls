@isTest
public with sharing class VertexCPQConfigurationControllerTest {
    
    @isTest
    public static void testFetching() {
        //Given (init happened)
        VertexCPQDataInit init = new VertexCPQDataInit();

        VertexCPQConfigurationController confController = new VertexCPQConfigurationController();

        //When
        // TODO: Make these tests meaningful!
        system.assertEquals(false, VertexCPQConfigurationController.ObjectMappingNameToFieldValuePairs.isEmpty(), 'There are no Obj Mappings');
        system.assertEquals(false, VertexCPQConfigurationController.AddressMappingNameToFieldValuePairs.isEmpty(), 'There are no Addy Mappings');
        system.assertEquals(true, VertexCPQConfigurationController.UpdateFldList('Opportunity').size()>0, 'Cannot find object children');
        
        VertexCPQConfigurationController.ResetObjMappings();
        VertexCPQConfigurationController.AddFieldMapping('transaction','obj','ItemTaxField__c', VertexCPQCore.NamespaceString+'Tax_Amount__c');
        VertexCPQConfigurationController.AddFieldMapping('transaction','fld','Line Text 3', 'testing');
        VertexCPQConfigurationController.AddFieldMapping('transaction','dest','PostalCode__c', 'SBQQ__ShippingPostalCode__c');
        
        VertexCPQConfigurationController.DeleteFieldMapping('transaction','obj','ItemTaxField__c');
        VertexCPQConfigurationController.DeleteFieldMapping('transaction','fld','Line Text 3');
        VertexCPQConfigurationController.DeleteFieldMapping('transaction','dest','PostalCode__c');

        confController.getBoundCartMappings();
        confController.getUnBoundCartMappings();
        confController.getBoundCartItemMappings();
        confController.getUnBoundCartItemMappings();

        confController.getObjFieldMap();
        confController.getFieldValidityResults();

        //Then
    }

    //run the getDataTypes method, but since we have no mismatched field mappings (Integer when we expect a string), it will return no results
    @isTest
    static void getDataTypeResults(){
        VertexCPQDataInit init = new VertexCPQDataInit();
        VertexCPQConfigurationController confController = new VertexCPQConfigurationController();
        confController.getObjFieldMap();
        List<String> results = confController.getDataTypeResults();
        System.assertEquals(0,results.size());
    }
}
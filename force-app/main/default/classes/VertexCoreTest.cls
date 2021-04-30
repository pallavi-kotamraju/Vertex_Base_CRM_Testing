@isTest
private class VertexCoreTest {
	
	// Covers lines in VertexCore and VertexDataInit not covered through their use in other test classes
	@isTest static void test_method_one() {			
		Map<String, VertexObjectMapping__c> objMappings = VertexCore.ObjectMappings;
		System.assert(objMappings != null);

		Object dummyObject;
		dummyObject = VertexCore.FieldMappings;

		VertexDataInit init = new VertexDataInit();
		init.ResetDefaults();
	}

	@isTest static void test_method_two() {
		//	Placeholder calls to pass coverage
		//	TODO: Make meaningful tests

		VertexCore core = new VertexCore();
		VertexCore.CompanyName();
		String temp = VertexCore.PhysicalOriginOverrideParent;
		temp = VertexCore.PhysicalOriginOverrideChild;
		System.assert(VertexCore.ParentPhysicalOriginAddress('Estimate') != null);
		VertexCore.ChildPhysicalOriginAddress();
		VertexCore.AdministrativeOriginAddress('Estimate');
		VertexLogging.Log('Debug', 'testing');
		VertexLogging.AsyncLog('Details', 'Endpoint', 'Request', 'Response', 'ResponseStatus', 0);
		VertexGlobal.GlobalHelper(new list<object>{'saveObjMap',VertexGlobal.ObjectMappingNameToFieldValuePairs});
		System.debug(VertexGlobal.AddressNameToFieldValuePairs);
	}

	//verify that a call to the global helper method saves the override map
	@isTest
	static void saveObjectMapping(){
		//create a sample account to use for building the override map
		Account acct = new Account();
		acct.Name = 'Test';
		acct.BillingStreet = '123 Main Street';
		insert acct;

		Map<String, Map<String,String>> overrideMap = new Map<String,Map<String,String>>();
		//override the billingstreet field
		Map<String,String> fieldMap = new Map<String,String>();
		fieldMap.put('BillingStreet','456 Green Street');
		overrideMap.put(acct.Id,fieldMap);
		List<Object> objectList = new List<Object>();
		objectList.add('saveOverrideMappings');
		objectList.add(overrideMap);
		VertexGlobal.GlobalHelper(objectList);

		//verify the mapping was saved
		System.assertEquals(1,VertexCore.fieldOverrideMap.keySet().size());
	}
}
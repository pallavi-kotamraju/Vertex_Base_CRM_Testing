@isTest
public with sharing class ValidateAndUpdateAddressTest {
	@isTest
	public static void testMethod01() {
		Account acc = new Account();
		acc.Name = 'Test Account';

        acc.BillingStreet = '123 Test st';
        acc.BillingCity = 'TestVille';
        acc.BillingState = 'pa';
        acc.BillingPostalCode = '19083';
        acc.BillingCountry = 'us';

        acc.ShippingStreet = '123 Corrected';
        acc.ShippingCity = 'New City';
        acc.ShippingState = 'PA';
        acc.ShippingPostalCode = '12345-2233';
        acc.ShippingCountry = 'us';

        insert acc; 

        TestSetup.CreateConfigurations();

        ApexPages.StandardController stdCon = new ApexPages.StandardController(acc);

        ValidateAndUpdateAddress cont = new ValidateAndUpdateAddress(stdCon);
        Test.setMock(HttpCalloutMock.class, new VerifyAddressMockHttpResponse());

        Test.startTest();
        cont.UpdateAddresses();
        Test.stopTest();

        acc = [SELECT ShippingStreet FROM Account WHERE ID = :acc.ID LIMIT 1];
        System.assertEquals('123 Corrected', acc.ShippingStreet);
	}
}
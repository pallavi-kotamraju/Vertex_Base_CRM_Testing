@isTest
public with sharing class VertexCPQCoreTest {
 
    @isTest
    public static void testActiveSettingsGet(){
        // GIVEN : VertexCPQSettings__c
        transient VertexCPQSettings__c CPQSettings = new VertexCPQSettings__c();
        CPQSettings.AsynchronousCPQCallout__c = true;
        insert CPQSettings;
        Test.startTest();
        // WHEN : We retrieve the settings
        transient VertexCPQSettings__c CPQTestSettings = VertexCPQCore.ActiveSettings;
        Test.stopTest();
        // THEN : The retrieved settings should match the created settings
        System.assertEquals(CPQSettings.AsynchronousCPQCallout__c, CPQTestSettings.AsynchronousCPQCallout__c);
    }
}
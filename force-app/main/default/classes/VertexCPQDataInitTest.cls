@isTest
public with sharing class VertexCPQDataInitTest {
    
    @isTest
    public static void testSettings() {
        //given (none, empty org)
        Map<String, Map<String, String>> settings = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new list<object>{'fetchObjMap', new LIST<String>{'CPQ'}});
        
        //When
        VertexCPQDataInit init = new VertexCPQDataInit();

        //Then (Verify data was created)
        settings = (Map<String, Map<String, String>>) VertexGlobal.GlobalHelper(new list<object>{'fetchObjMap', new LIST<String>{'CPQ'}});
        system.assertEquals(false, settings.isEmpty(),'The Settings parameter was empty at the end');

    }
}
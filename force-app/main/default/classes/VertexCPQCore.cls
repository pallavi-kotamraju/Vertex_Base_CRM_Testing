public with sharing class VertexCPQCore {

    public static String startCallout = 'Pending';
    public static String finishCallout = 'Completed';
    public static Integer batchJobCallout = 200;

    public static String NamespaceString{ 
        get{ 
            if (NamespaceString==null)
                NamespaceString=VertexCPQCore.FetchNamespace();
            return NamespaceString;
        }
        set;
    }

    public static String FetchNamespace(){
        String namespaceReturn = VertexCPQCore.class.getName().substringBefore('VertexCPQCore').substringBefore('.');
        if(namespaceReturn != '') namespaceReturn += '__';

        return namespaceReturn;
    }

    // Fetch and Preserve the Active Configuration
    public static VertexCPQSettings__c ActiveSettings {
        get {
            ActiveSettings = VertexCPQSettings__c.getOrgDefaults();
            if(ActiveSettings == null ){
                ActiveSettings = new VertexCPQSettings__c(AsynchronousCPQCallout__c = false);
            }
            return ActiveSettings;
        }
        set { 
            ActiveSettings = value;
            upsert ActiveSettings;     
        }
    }

    public class taxAmtWrapper{
        
        public String recdId {get; set;}
        public Decimal taxAmt {get; set;}
    }
}
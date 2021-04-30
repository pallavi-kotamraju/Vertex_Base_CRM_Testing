public with sharing class VertexMapping {

    public VertexObjectMapping__c ObjMap { get { if (ObjMap == null) ObjMap = new VertexObjectMapping__c(); return ObjMap; } set; }
    public List<VertexFieldMapping__c> LineFlexFldMaps {get; set;}
    public VertexAddress__c ParentFieldMap { get { if (ParentFieldMap == null) ParentFieldMap = new VertexAddress__c(); return ParentFieldMap; } set; }
    public VertexAddress__c ChildFieldMap { get { if (ChildFieldMap == null) ChildFieldMap = new VertexAddress__c(); return ChildFieldMap; } set; }

    //  Constructor to populate
    public VertexMapping(VertexBaseRequest.InvokeRequestStructure request) {
        
        if (request != null) {
            ParentFieldMap = VertexAddress__c.getValues(request.mappingType+' Trans Dest Map');
            ChildFieldMap = VertexAddress__c.getValues(request.mappingType+' Line Dest Map');
            ObjMap = VertexObjectMapping__c.getValues(request.mappingType);
            
            LineFlexFldMaps = new List<VertexFieldMapping__c>();
            for (VertexFieldMapping__c fldMap : VertexFieldMapping__c.getAll().values()){
                if (fldMap.ObjectMapping__c == ObjMap.ID && fldMap.Type__c == 'line')
                    LineFlexFldMaps.add(fldMap);
            }

            //Selection Sort to order the list by flex field number
            for (Integer i = 0; i < LineFlexFldMaps.size()-1; i++){
                Integer minIndex = i;
                for (Integer j = i+1; j < LineFlexFldMaps.size(); j++)
                    if (Integer.valueOf(LineFlexFldMaps[j].Label__c.substringAfterLast(' ')) < Integer.valueOf(LineFlexFldMaps[minIndex].Label__c.substringAfterLast(' ')))
                        minIndex = j;
    
                //Swap the found minimum element with the first element
                VertexFieldMapping__c temp = LineFlexFldMaps[minIndex];
                LineFlexFldMaps[minIndex] = LineFlexFldMaps[i];
                LineFlexFldMaps[i] = temp;
            }
        }
    }
}
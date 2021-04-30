public with sharing class VertexDataInit {
    
    /* Class Structure
        1)  Main Creation Methods - reset defaults, delete existing, create vanilla
        2)  Object Mappings
        3)  Field Mappings + Helpers (broken down methods by parent/child + type)
    */
    
    /* - Exec Anony Script
    VertexDataInit init = new VertexDataInit();
    init.ResetDefaults();
    */
    
    //////////////////////////////
    //  1)  MAIN CREATION METHODS
    //////////////////////////////
    
    //  Remove mappings and re-create defaults
    public void ResetDefaults() {
        ClearAll();
        CreateVanilla();
    }
    
    //  Remove existing object and field mappings
    public void ClearAll() {
        list<VertexObjectMapping__c> tmpObjList = VertexObjectMapping__c.getAll().values();
        list<VertexAddress__c> tmpFldList = VertexAddress__c.getAll().values();
        
        if (!tmpObjList.isEmpty())
            delete tmpObjList;
            
        if (!tmpFldList.isEmpty())
            delete tmpFldList;
    }
    
    public void CreateVanilla() {
        CreateVanillaObjMappings();
        CreateVanillaDestinationMappings();
        CreateVanillaOriginMappings();
    }    
    
    public void CreateVanillaObjMappings() {
        list<VertexObjectMapping__c> tmpList = new list<VertexObjectMapping__c>();
        tmpList.addAll(VanillaObjMappings());
        
        if (!tmpList.isEmpty())
            database.insert(tmpList, VertexCore.getDMLOptions());
    }
    
    public void CreateVanillaDestinationMappings() {
        list<VertexAddress__c> tmpList = new list<VertexAddress__c>();
        tmpList.addAll(VanillaDestinationMappings());
        
        if (!tmpList.isEmpty())
            database.insert(tmpList, VertexCore.getDMLOptions());
    }

    //This method is intended for setting up test data in a unit test context
    public void CreateUnitTestDestinationMappings() {
        if (Test.isRunningTest()){
            list<VertexAddress__c> tmpList = new list<VertexAddress__c>();
            tmpList.addAll(UnitTestDestinationMappings());
            
            if (!tmpList.isEmpty())
                database.insert(tmpList, VertexCore.getDMLOptions());
        }
    }

    public void CreateVanillaOriginMappings() {
        List<VertexAddress__c> tmpList = new List<VertexAddress__c>();
        tmpList.addAll(VanillaOriginMappings());
        
        if (!tmpList.isEmpty())
            Database.insert(tmpList, VertexCore.getDMLOptions());
    }
    
    //////////////////////////////
    //  2) OBJECT MAPPINGS for Parent/Child
    //      Defaults:
    //          Parent:  Opportunity
    //          Child:   OpportunityLineItem
    //////////////////////////////
    public list<VertexObjectMapping__c> VanillaObjMappings() {
        return new list<VertexObjectMapping__c>{
            new VertexObjectMapping__c(Name = 'Estimate',   ParentSObject__c = 'Opportunity',   ChildSObject__c = 'OpportunityLineItem',    ParentLookup__c = 'OpportunityId',    ChildSObjectRelationshipName__c = 'OpportunityLineItems', ItemNameField__c='Product2Id', ItemPriceField__c = 'TotalPrice', ItemQuantityField__c = 'Quantity', XMLMessage__c = 'Quote', TransactionType__c = 'SALE'),
            new VertexObjectMapping__c(Name = 'Order',   ParentSObject__c = '',   ChildSObject__c = '',    ParentLookup__c = '',    ChildSObjectRelationshipName__c = ''),
            new VertexObjectMapping__c(Name = 'Invoice',   ParentSObject__c = '',   ChildSObject__c = '',    ParentLookup__c = '',    ChildSObjectRelationshipName__c = '')
        };
    }
    
    
    //////////////////////////////
    //  3)  FIELD MAPPINGS
    //      Parent Defaults:
    //          Seller AdminOrigin:  Matt's UI Custom Setting
    //          Seller PhysOrigin:  Matt's UI Custom Setting
    //          Customer Destination:  Parent Account Shipping Address
    //          Customer Admin Destination:  Parent Account Billing Address
    //
    //      Child Defaults:
    //          LineItems:  OpportunityLineItems + Product2
    //          Seller AdminOrigin:  blank
    //          Seller PhysOrigin:  blank
    //          Customer Destination:  blank
    //          Customer Admin Destination:  blank
    
    public List<VertexAddress__c> VanillaDestinationMappings() {
        return new List<VertexAddress__c>{
            new VertexAddress__c(Name = 'Estimate Trans Dest Map'),
            new VertexAddress__c(Name = 'Estimate Line Dest Map'),
            new VertexAddress__c(Name = 'Order Trans Dest Map'),
            new VertexAddress__c(Name = 'Order Line Dest Map'),
            new VertexAddress__c(Name = 'Invoice Trans Dest Map'),
            new VertexAddress__c(Name = 'Invoice Line Dest Map')
        };
    }

    public List<VertexAddress__c> VanillaOriginMappings(){
        return new List<VertexAddress__c>{
            new VertexAddress__c(Name = 'Estimate Trans Admin'),
            new VertexAddress__c(Name = 'Estimate Trans Phys'),
            new VertexAddress__c(Name = 'Estimate Line Admin'),
            new VertexAddress__c(Name = 'Estimate Line Phys'),
            new VertexAddress__c(Name = 'Order Trans Admin'),
            new VertexAddress__c(Name = 'Order Trans Phys'),
            new VertexAddress__c(Name = 'Order Line Admin'),
            new VertexAddress__c(Name = 'Order Line Phys'),
            new VertexAddress__c(Name = 'Invoice Trans Admin'),
            new VertexAddress__c(Name = 'Invoice Trans Phys'),
            new VertexAddress__c(Name = 'Invoice Line Admin'),
            new VertexAddress__c(Name = 'Invoice Line Phys')
        };
    }

    //These are the legacy destination mappings that still work in the callout code, but we no longer allow the user to do this style of field mapping in the UI
    public list<VertexAddress__c> UnitTestDestinationMappings() {
        return new list<VertexAddress__c>{
            new VertexAddress__c(Name = 'Estimate Trans Dest Map', Address1__c = 'account.BillingStreet',             City__c = 'account.billingcity',                      Country__c = 'account.billingcountry',                  PostalCode__c = 'account.billingpostalcode',                  State__c = 'account.billingstate', CustomerCode__c = 'account.AccountNumber'),
            new VertexAddress__c(Name = 'Estimate Line Dest Map',  Address1__c = 'opportunity.account.BillingStreet', City__c = 'opportunity.account.billingcity',          Country__c = 'opportunity.account.billingcountry',      PostalCode__c = 'opportunity.account.billingpostalcode',      State__c = 'opportunity.account.billingstate'),
            new VertexAddress__c(Name = 'Order Trans Dest Map',    Address1__c = '',                                  City__c = 'account.billingcity',                      Country__c = 'account.billingcountry',                  PostalCode__c = 'account.billingpostalcode',                  State__c = 'account.billingstate', CustomerCode__c = 'account.AccountNumber'),
            new VertexAddress__c(Name = 'Order Line Dest Map',     Address1__c = '',                                  City__c = 'opportunity.account.billingcity',          Country__c = 'opportunity.account.billingcountry',      PostalCode__c = 'opportunity.account.billingpostalcode',      State__c = 'opportunity.account.billingstate'),
            new VertexAddress__c(Name = 'Invoice Trans Dest Map',  Address1__c = '',                                  City__c = 'account.billingcity',                      Country__c = 'account.billingcountry',                  PostalCode__c = 'account.billingpostalcode',                  State__c = 'account.billingstate', CustomerCode__c = 'account.AccountNumber'),
            new VertexAddress__c(Name = 'Invoice Line Dest Map',   Address1__c = '',                                  City__c = 'opportunity.account.billingcity',          Country__c = 'opportunity.account.billingcountry',      PostalCode__c = 'opportunity.account.billingpostalcode',      State__c = 'opportunity.account.billingstate')
        };
    }

    /*  LINE ITEM AND PRODUCT FIELDS - for discussion w/ Vertex
    
        VERTEX LINE ITEM FIELDS IN QUOTATIONREQUEST
        lineItemNumber
        materialCode - A value that represents a specific item or product.
        projectNumber - A unique identifier that associates a line item to a project for purchasing purposes.
        lineItemId - An identifier that further defines the line item and corresponds to the transaction stored in the host system. This parameter is needed to perform synchronization services, but it is not used for reporting purposes.
        usageClass - Directly identifies a usage class by user-defined usage class code.
        
        SALESFORCE PRODUCT2 FIELDS
        Description,
        DisplayUrl,
        ExternalDataSourceId,
        ExternalId,
        Family,
        Id,
        IsActive,
        IsDeleted,
        Name,
        ProductCode,
        QuantityUnitOfMeasure
    */
}
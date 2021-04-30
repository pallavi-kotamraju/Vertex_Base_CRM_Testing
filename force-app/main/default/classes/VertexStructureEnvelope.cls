public virtual class VertexStructureEnvelope {
     
     //  Login node is always present; additional 1.x level nodes can be added by classes extending this one
     public VertexLogin Login { get; set; }      //  1.1
     
     //  Init w/ defaults and children
     public VertexStructureEnvelope() {
         Login = new VertexLogin();
     }
     
     //  1.1 (VertexEnvelope Root.Login)
     public class VertexLogin {
         public string UserName { get; set; }        //  1.1.1
         public string Password { get; set; }        //  1.1.2
         public string TrustedId { get; set; }       //  1.1.3
         
         //  Init w/ defaults and children
         public VertexLogin() {
             UserName = VertexCore.ActiveSettings.UserName__c;
             Password = VertexCore.ActiveSettings.Password__c;
             TrustedId = VertexCore.ActiveSettings.TrustedId__c;
         }
     }
 }
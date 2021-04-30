public abstract class VertexCalloutsQueueable implements queueable, Database.AllowsCallouts {
    
    //  Properties common
    public string Endpoint { get; set; }
    public string ContentType { get; set; }
    public string Method { get; set; }
    public string Body { get; set; }
    public List<string> Bodies { get; set; }
    public String taxTypeCheck { get; set; }
    public String ResponseType { get; set; }
    public boolean ParseCalloutResponse { get; set; }
            
    
    public VertexCalloutsQueueable(string endpoint, string contentType, string method, List<string> bodies, String type, String responseType, boolean parseResponse) {
        this.Endpoint = endpoint;
        this.ContentType = contentType;
        this.Method = method;
        this.Bodies = bodies;
        this.Body = bodies.get(0);
        this.taxTypeCheck = type;
        this.ResponseType = responseType;
        this.ParseCalloutResponse = parseResponse;
    }
    
    public void execute(QueueableContext context) {
        system.debug(LoggingLevel.WARN, '===execute===');
        system.debug(LoggingLevel.ERROR, 'Endpoint:  ' + Endpoint);
        system.debug(LoggingLevel.ERROR, 'ContentType:  ' + ContentType);
        system.debug(LoggingLevel.ERROR, 'Method:  ' + Method);
        system.debug(LoggingLevel.ERROR, 'Body:  ' + Body);
        system.debug(LoggingLevel.ERROR, 'ParseCalloutResponse:  ' + ParseCalloutResponse);
        
        //  Instantiate properties for this callout
        Http http = new Http();
        HttpRequest req = new HttpRequest(); 
        
        //  Setup the request
        req.setMethod(Method);
        req.setHeader('Content-Type', ContentType);
        req.setEndpoint(Endpoint);
        
        //  Set up the request's body
        req.setBody(Body);
        
        try {
            
            //Execute web service call here
            HTTPResponse res = http.send(req);  
            system.debug(LoggingLevel.ERROR, 'res:  ' + res);
            
            //  Handle the Response
            if (res != null) {
                System.debug('We will have to create a batch class and then call ResponseHandler form that batch class');
                system.debug('Request : '+ req);
                system.debug('Response : '+ res);
                system.debug('responseType : '+ responseType);
               ResponseHandler(req, res);

            }
        } catch(System.CalloutException ex) {
            //Exception handling goes here....
            system.debug(LoggingLevel.ERROR, 'Exception:  ' + ex.getMessage() + '\r\n\r\n' + ex.getStackTraceString());
            VertexLogging.Log('Error', 'Error: '+ex.getMessage() + ex.getStackTraceString());
        }
    }
    
    //  Upon extending this class, this method must be provided
    public abstract void ResponseHandler(HttpRequest req, HTTPResponse res);
    
}
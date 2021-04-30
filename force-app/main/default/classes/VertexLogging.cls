public without sharing class VertexLogging {

    //  Collection to hold logs generated during app execution
    public static List<VertexLog__c> VLogs { get { if (VLogs == null) VLogs = new List<VertexLog__c>(); return VLogs; } set; }

    //  Flag to indicate commits need to wait until after all callouts are finished
    public static boolean SuppressLogs { get { if (SuppressLogs == null) SuppressLogs = false; return SuppressLogs; } set; }

    //  Create a new Log Entry for API transactions
    public static void Log(String severity, String details, String endpoint, String request, String response, String responseStatus, Integer responseStatusCode) {
        System.debug(LoggingLevel.WARN, '===Log===');
        
        if (VertexCore.ActiveSettings.LoggingLevel__c == 'Debug' || (VertexCore.ActiveSettings.LoggingLevel__c == 'Error' && severity == 'Error')) {
            System.debug(LoggingLevel.WARN, '===Log===1');
            if (VertexCore.ActiveSettings.AsynchronousLogging__c != true) {
                System.debug(LoggingLevel.WARN, '===Log===2');
                if (!SuppressLogs)
                System.debug(LoggingLevel.WARN, '===Log===3');
                    VLogs.add(
                        new VertexLog__c(
                            Details__c = details,
                            Endpoint__c = endpoint,
                            Request__c = request,
                            Response__c = response,
                            ResponseStatus__c = responseStatus,
                            ResponseStatusCode__c = responseStatusCode
                        )
                    );
            }
            else {
                System.debug(LoggingLevel.WARN, '===Log===4');
                AsyncLogQueueable asyncLog = new AsyncLogQueueable(details,endpoint,request,response,responseStatus,responseStatusCode);
                System.enqueueJob(asyncLog);
            }
        }
    }

    // Create a log entry without specifying api 
    public static void Log(String severity, String details) {
        Log(severity, details, null, null, null, null, null);
    }

    //  Create a new Log Entry for API transactions
    @future
    public static void AsyncLog(String details, String endpoint, String request, String response, String responseStatus, Integer responseStatusCode) {
        System.debug(LoggingLevel.WARN, '===AsyncLog===');

        Integer maxLength = 131069;
        Integer endpointMaxLength = 997;
        Integer detailsMaxLength = 252;
        Integer responseStatusMaxLength = 97;

        if(!String.isBlank(details) && (details.length() > detailsMaxLength)){
            details = details.substring(0, detailsMaxLength);
            details = details +'...';
        }

        if(!String.isBlank(endpoint) && (endpoint.length() > endpointMaxLength)){
            endpoint = endpoint.substring(0, endpointMaxLength);
            endpoint = endpoint +'...';
        }

        if(!String.isBlank(request) && (request.length() > maxLength)){
            request = request.substring(0, maxLength);
            request = request +'...';
        }

        if(!String.isBlank(response) && (response.length() > maxLength)){
            response = response.substring(0, maxLength);
            response = response + '...';
        }

        if(!String.isBlank(responseStatus) && (responseStatus.length() > responseStatusMaxLength)){
            responseStatus = responseStatus.substring(0, responseStatusMaxLength);
            responseStatus = responseStatus + '...';
        }


        VertexLog__c newLog = new VertexLog__c(
            Details__c = details,
            Endpoint__c = endpoint,
            Request__c = request,
            Response__c = response,
            ResponseStatus__c = responseStatus,
            ResponseStatusCode__c = responseStatusCode
        );
        insert newLog;
    }

    public class AsyncLogQueueable implements Queueable{

        private String details;
        private String endpoint;
        private string request;
        private String response;
        private String responseStatus;
        private Integer responseStatusCode;

        public AsyncLogQueueable(String details, String endpoint, String request, String response, String responseStatus, Integer responseStatusCode){
            this.details = details;
            this.endpoint = endpoint;
            this.request = request;
            this.response = response;
            this.responseStatus = responseStatus;
            this.responseStatusCode = responseStatusCode;
        }

        public void execute(QueueableContext context){
                Integer maxLength = 131069; // not 131072 because we want an ellipse on the end
                Integer endpointMaxLength = 997;
                Integer detailsMaxLength = 252;
                Integer responseStatusMaxLength = 97;

                if(!String.isBlank(details) && (details.length() > detailsMaxLength)){
                    details = details.substring(0, detailsMaxLength);
                    details = details +'...';
                }

                if(!String.isBlank(endpoint) && (endpoint.length() > endpointMaxLength)){
                    endpoint = endpoint.substring(0, endpointMaxLength);
                    endpoint = endpoint +'...';
                }

                //need to cap request and response
                if(!String.isBlank(request) &&  (request.length() > maxLength)){
                    request = request.substring(0,maxLength);
                    request = request +'...';
                }

                if(!String.isBlank(response) && (response.length() > maxLength)){
                    response = response.substring(0, maxLength);
                    response = response + '...';
                }

                if(!String.isBlank(responseStatus) && (responseStatus.length() > responseStatusMaxLength)){
                    responseStatus = responseStatus.substring(0, responseStatusMaxLength);
                    responseStatus = responseStatus + '...';
                }


                VertexLog__c newLog = new VertexLog__c(
                Details__c = details,
                Endpoint__c = endpoint,
                Request__c = request,
                Response__c = response,
                ResponseStatus__c = responseStatus,
                ResponseStatusCode__c = responseStatusCode
            );
            insert newLog;
        }
    }

    //  Method to perform all necessary, but delayed commits (currently just logs, could be custom settings, mdts, etc)
    public static void CommitDelayed() {
        system.debug(LoggingLevel.WARN, '===CommitDelayed===');
        system.debug(LoggingLevel.ERROR, 'Logs:  ' + VLogs);
        system.debug('SuppressLogs:  ' + SuppressLogs);
        
        if (!VLogs.isEmpty() && !SuppressLogs){
            system.debug('****SuppressLogs and Vlogs both ar enot empty:  ' );
            transient Integer maxRows = Integer.valueOf(VertexCore.ActiveSettings.MaximumLoggingRows__c);
            system.debug('-->Log 1:VertextLogging.CommeitLogs: MaxRows: ' +maxRows );
            if(maxRows != null && maxRows < 10000){
                transient LIST<VertexLog__c> currentLogs = [SELECT id FROM VertexLog__c Order by createdDate asc LIMIT 10000];
                transient LIST<VertexLog__c> logsToDelete = new LIST<VertexLog__c>();
                system.debug('-->Log 2:VertextLogging.CommeitLogs: logsToDelete: ' +logsToDelete );
                if(currentLogs.size() + VLogs.size() > maxRows){
                    system.debug('-->Log 1:VertextLogging.CommeitLogs: currentLogs.size() + VLogs.size() > maxrows : ' +(currentLogs.size() + VLogs.size()) );
                    transient integer badRows = currentLogs.size() + VLogs.size() - maxRows;
                    for (integer x = 0; x < badRows; x++)
                        logsToDelete.add(currentLogs[x]);
                }
                if (!logsToDelete.isEmpty())
                    delete logsToDelete;
            }

            try{
                Database.insert(VLogs, VertexCore.getDMLOptions());
            } catch(Exception e){
                System.Debug('Exception '+e);
                VertexLogging.Log('Error', 'Error: '+e.getMessage() + e.getStackTraceString());
            }
            
        }
    }
}
// https://cargurus.atlassian.net/browse/BR-884
public class Integrations implements Queueable, Database.AllowsCallouts {

    // start integration related constants **************************
    public static final Integration_Controls__mdt INTEGRATION_CONTROLS = 
        Integration_Controls__mdt.getInstance('Integration_Controls');
    
    public static final String REQUEST_STATUS_NEW = 'New';
    public static final String REQUEST_STATUS_RETRY = 'Retry';
    public static final String REQUEST_STATUS_SUCCESS = 'Success';
    public static final String REQUEST_STATUS_FAILURE = 'Failure';
    public static final Set<String> REQUEST_STATUSES_TO_PROCESS = 
        new Set<String>{REQUEST_STATUS_NEW,REQUEST_STATUS_RETRY};

    public static final String RESPONSE_STATUS_PENDING = 'Pending';
    public static final String RESPONSE_STATUS_NEW = 'New';
    public static final String RESPONSE_STATUS_RETRY = 'Retry';
    public static final String RESPONSE_STATUS_PROCESSED = 'Processed';
    public static final String RESPONSE_STATUS_ERROR = 'Error';
    public static final Set<String> RESPONSE_STATUSES_TO_PROCESS = 
        new Set<String>{RESPONSE_STATUS_NEW,RESPONSE_STATUS_RETRY};

    public static final String PROCESS_FEATUREFRAMEWORK = 'Feature Framework';
    public static final String PROCESS_ZACCOUNT = 'Zuora Account';
    public static final String PROCESS_ZORDER = 'Zuora Order';
    public static final String PROCESS_ZORDER_TERMS = 'Zuora Order Terms';
    public static final String PROCESS_ZBILLING = 'Zuora Billing';
    public static final String PROCESS_ZREVPROACTIVATION = 'Zuora Revpro Activation';
    public static final String PROCESS_PHACCOUNT = 'PistonHeads Account';

    static final String ENDPOINT_SENDMESSAGEIDS = Utilities.IS_SANDBOX ? 
        INTEGRATION_CONTROLS.DEV_Endpoint_Send_Integration_Message__c : 
        INTEGRATION_CONTROLS.Endpoint_Send_Integration_Message__c;
    // end integration related constants **************************

    // main method to send a list of integration message ids to boomi, forcing context if needed
    public static void sendMessageIdsToBoomi(List<Id> messageIdList, Boolean contextAllowsCallouts) {
        
        // if not known that the current context allows callouts, route to a context that does
        if (!contextAllowsCallouts) {
            if (!System.isBatch() && !System.isFuture()) {
                sendMessageIdsToBoomiFuture(messageIdList);
            } else if (Limits.getLimitQueueableJobs() > Limits.getQueueableJobs()) {
                sendMessageIdsToBoomiQueueable(messageIdList);
            }
            return;
        }

        // put together json package with messages id and process
        List<Map<String,String>> jsonMapList = new List<Map<String,String>>();

        for (Integration_Message__c im : [SELECT Id, Process__c FROM Integration_Message__c 
            WHERE Id IN :messageIdList]) 
        {
            jsonMapList.add(
                new Map<String,String>{
                    'Id' => im.Id,
                    'Process__c' => im.Process__c
                }
            );
        }

        // setup http request with the feature check endpoint
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        req.setEndpoint(ENDPOINT_SENDMESSAGEIDS);
        req.setMethod('POST');

        req.setBody(JSON.serializePretty(jsonMapList));
        System.debug('req body: '+req.getBody());

        String errorString;

        try {
            res = http.send(req);
            System.debug('res body: '+res.getBody());

            if (res.getStatusCode() != 200) {
                errorString += res.getStatusCode()+' '+res.getStatus();
            }
        } catch(Exception e) {
            errorString += e.getMessage();
        }

        if (errorString != null) {
            System.debug('Error sending message ids to Boomi: '+errorString);
        }
    }

    public static void sendMessageIdsToBoomi(List<Id> messageIdList) {
        sendMessageIdsToBoomi(messageIdList, false);
    }

    public static void sendMessageIdsToBoomi(List<Integration_Message__c> messageList, Boolean contextAllowsCallouts) {
        sendMessageIdsToBoomi(
            new List<Id>(new Map<Id,Integration_Message__c>(messageList).keySet()), contextAllowsCallouts);
    }

    public static void sendMessageIdsToBoomi(List<Integration_Message__c> messageList) {
        sendMessageIdsToBoomi(messageList, false);
    }
    // end overrides to main method for sending integration message ids to boomi **************

    // below methods are all used to force execution into a callout-friendly async context
    @future(callout=true)
    static void sendMessageIdsToBoomiFuture(List<Id> messageIdList) {
        sendMessageIdsToBoomi(messageIdList, true);
    }

    // instance variable if using queueable
    List<Id> messageIdList;

    // constructor for queueable
    public Integrations(List<Id> messageIdList) {
        this.messageIdList = messageIdList;
    }

    // queueable execute - true indicates we are in a context that allows callouts
    public void execute(QueueableContext context) {
        sendMessageIdsToBoomi(messageIdList, true);
    }

    // static method to instantiate class and enqueue job for execution
    static void sendMessageIdsToBoomiQueueable(List<Id> messageIdList) {
        System.enqueueJob(new Integrations(messageIdList));
    }

}
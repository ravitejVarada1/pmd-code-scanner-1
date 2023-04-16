@RestResource(urlMapping='/cscallrouter/*')
global class RestDialpadConsumerSupportCallRouter {
    @HttpPost
    global static RestDialpadCallRouter.Response doPost ()
    {                                                                                                        
             try{
            //Deserialize the payload into an object of the wrapper class "rawPayloadWrap" below
            rawPayloadWrap payload = (rawPayloadWrap)JSON.deserialize(RestContext.request.requestBody.toString(), rawPayloadWrap.class);
            
            //Create an "expanded" payload that includes URI info and validates the parameters in its constructor
            DialpadUtilities.ExpandedCallPayload expandedPayload = new DialpadUtilities.ExpandedCallPayload(payload,
                                                                                                           RestContext.request?.requestURI.split('/'),'Consumer');

             //Create an instance of the DialPadConsumerSupportCallRouterHandler object, and call the findCSRoutingId method,
            //which returns an instance of the wrapper class "Resposne" 
            DialPadConsumerSupportCallRouterHandler handlerObject1 = new DialPadConsumerSupportCallRouterHandler(expandedPayload);
            return handlerObject1.findCSRoutingId();

          
            
        }catch (exception e){
            Dialpad_Router_Log__c failureLog = new Dialpad_Router_Log__c(
            	Failure_Notes__c = RestContext.request.requestBody.toString() + ' | ' +  e.getMessage() + ' | ' +  e.getStackTraceString()
            ); 
            
            insert failureLog;
                                                                                                              
            return null;
        }
        

    }

    public class rawPayloadWrap{
        public String internal_number;
        public String master_call_id;
        public String contact_type;
        public String contact_id;
        public String call_id;
        public String date_started;
        public String external_number;
        
        public rawPayloadWrap(String internal_number, String master_call_id,
                              String contact_type, String contact_id, String call_id,
                              String date_started, String external_number)
        {
            this.internal_number = internal_number;
            this.master_call_id = master_call_id;
            this.contact_type = contact_type;
            this.contact_id = contact_id;
            this.call_id = call_id;
            this.date_started = date_started;
            this.external_number = external_number;
        }
    }
    
    
    
}

/*
SAMPLE PAYLOAD

{
"date_started" : "01-01-2000", 
"call_id" : "1234",
"external_number" : "+14151231234",
"internal_number" : "+14151231234",
"contact_id" : "1234",
"contact_type" : "Test"
}

/services/apexrest/cscallrouter/CONSUMERSUPPORT/
*/
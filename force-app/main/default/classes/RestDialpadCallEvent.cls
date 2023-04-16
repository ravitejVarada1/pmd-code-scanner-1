/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        01/07/2021
* modified:       01/07/2021
* created jira:   BR-360
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@RestResource(urlMapping='/callevent/*')
global class RestDialpadCallEvent {
@HttpPost
    global static void doPost (){
        
        //Deserialize the payload into an object of the wrapper class "rawPayloadWrap" below
        rawPayloadWrap payload = 
            (rawPayloadWrap)JSON.deserialize(RestContext.request.requestBody.toString(), 
                                                               rawPayloadWrap.class);
        
        DialpadCallEventHandler.createSalesforceRecords(payload);
    }

    public class rawPayloadWrap {
        public String master_call_id; 
        public Long date_ended; 
        public String internal_number; 
        public Double duration; 
        public Target entry_point_target; 
        public Target proxy_target; 
        public String call_dispositions;
        public String entry_point_call_id; 
        public String operator_call_id; 
        public String call_id; 
        public String state; 
        public Long date_started; 
        public String transcription_text; 
        public String direction; 
        public Long date_connected; 
        public String voicemail_link; 
        public Boolean is_transferred; 
        public Boolean was_recorded; 
        public Long date_rang; 
        public Target target; 
        public Target contact; 
        public String group_id; 
        public String external_number;
        
        public rawPayloadWrap(String master_call_id, String call_id, String external_number,
                                                String direction, String state)
        {
            this.master_call_id = master_call_id;
            this.call_id = call_id;
            this.external_number = external_number;
            this.direction = direction;
            this.state = state;
        }
    }

    public class Target {
        public String phone; 
        public String type_Z; 
        public String id; 
        public String name; 
        public String email; 
    }
}
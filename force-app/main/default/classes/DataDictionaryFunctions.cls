public class DataDictionaryFunctions {

        public static String getHTTP(String endPointURL) {

            HttpRequest req = new HttpRequest();
			String domainURL;            
            if(!runningInASandbox){
	            domainURL = 'callout:SFDCToolingAPI_Production';
            }
            
            req.setEndpoint(domainURL + endPointURL);
            req.setMethod('GET');                
            Http h = new Http();
            
            String responseBody = null;

            try {
                HttpResponse res = h.send(req);	
                responseBody = res.getBody();
            }
            catch ( System.CalloutException ex ) {
                
                System.debug( 'Tooling API Error Message is << ' + ex.getmessage() + ' >> At line number << ' + ex.getLineNumber());
                system.debug( 'Stace Trace String is ' + ex.getStackTraceString() );
            }
            
            return responseBody;
        } 

        public static Boolean runningInASandbox {
            get {
                if (runningInASandbox == null) {
                    runningInASandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
                }
                return runningInASandbox;
            }
            set;
        }    
    
}
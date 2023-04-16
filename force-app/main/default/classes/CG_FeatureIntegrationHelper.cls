// https://cargurus.atlassian.net/browse/CRM-5021
// methods to help push feature data to and retrieve it from cg
// test coverage in CG_FeatureFramework_Test
public without sharing class CG_FeatureIntegrationHelper {

    public static final Map<String,String> COUNTRYCODE_REGION_MAP = CG_FeatureHelper.getCountryRegionMap();
    public static final String SP_ACTIVEREVIEWSTATUS = 'APPROVED';
    public static final String SP_SUBMITREVIEWSTATUS = 'SUBMITTED';
    public static final Set<String> SP_ALLOWREVIEWSTATUS = new Set<String> {
        SP_ACTIVEREVIEWSTATUS,
        SP_SUBMITREVIEWSTATUS
    };
    private static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;

    // get feature check endpoint, depending on whether we are in a sandbox or production
    public static final String ENDPOINT_FEATURE_CHECK = Utilities.IS_SANDBOX ? 
        INTEGRATION_CONTROLS.DEV_Endpoint_CG_Feature_Check__c : INTEGRATION_CONTROLS.Endpoint_CG_Feature_Check__c;

    // get feature send endpoint, depending on whether we are in a sandbox or production
    public static final String ENDPOINT_FEATURE_SEND = Utilities.IS_SANDBOX ? 
        INTEGRATION_CONTROLS.DEV_Endpoint_Send_Integration_Message__c : 
        INTEGRATION_CONTROLS.Endpoint_Send_Integration_Message__c;

    static final Datetime DATETIME_NOW = System.now();
    static final String STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
    static final String STATUS_RETRY = Integrations.REQUEST_STATUS_RETRY;
    static final String STATUS_FAILURE = Integrations.REQUEST_STATUS_FAILURE;
    static final String STATUS_SUCCESS = Integrations.REQUEST_STATUS_SUCCESS;
    static final Set<String> STATUSES_TO_PROCESS = Integrations.REQUEST_STATUSES_TO_PROCESS;
    static final String INTEGRATION_PROCESS = CG_AccountFeatureMessageHelper.INTEGRATION_PROCESS;
    //static final String JSONUPDATE = ConstantsUtil.JSONUPDATE;  // CRM-4839

    // get map of service provider id to map of features for a single supplied account id
    public static Map<Integer,Map<Integer,CG_AccountFeature>> getCGFeaturesForAccountId(Id accountId) {
        return getCGFeaturesForAccountIds(new Set<Id>{accountId}).get(accountId);
    }
    
    // get a map of account id to map of service provider id to map of features for a supplied set of account ids
    public static Map<Id,Map<Integer,Map<Integer,CG_AccountFeature>>> getCGFeaturesForAccountIds(Set<Id> accountIds) {
        Map<Id,Map<Integer,Map<Integer,CG_AccountFeature>>> returnMap = 
            new Map<Id,Map<Integer,Map<Integer,CG_AccountFeature>>>();

        // query supplied ids for account / service provider data to retrieve features, limited to those with active sps
        List<Account> accountList = [SELECT Id, BillingCountryCode, 
                (SELECT Id, Name, Service_Provider_Id__c FROM Service_Provider__r 
                    WHERE reviewStatus__c IN :SP_ALLOWREVIEWSTATUS AND Can_host_inventory__c = 'Yes')
            FROM Account WHERE Id IN :accountIds];
        
        for (Account a : accountList) {
            returnMap.put(a.Id, getCGFeaturesForAccount(a));
        }

        return returnMap;
    }

    // get a map of service provider id to map of features for a single supplied account with related sp records
    public static Map<Integer,Map<Integer,CG_AccountFeature>> getCGFeaturesForAccount(Account a) {
        
        // the supplied account has no service provider related data, so requery
        if (a.Service_Provider__r == null) {
            return getCGFeaturesForAccountId(a.Id);
        }

        // the supplied account has no active service providers, so move on
        if (a.Service_Provider__r.isEmpty()) {
            return new Map<Integer,Map<Integer,CG_AccountFeature>>();
        }

        Map<Integer,Map<Integer,CG_AccountFeature>> returnMap = new Map<Integer,Map<Integer,CG_AccountFeature>>();
        String region = COUNTRYCODE_REGION_MAP.get(a.BillingCountryCode);
        
        // setup http request with the feature check endpoint
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        req.setEndpoint(ENDPOINT_FEATURE_CHECK);
        req.setMethod('POST');

        // initialize json package map with the account region
        Map<String,Object> jsonMap = new Map<String,Object>{
            'region' => region
        };

        // for each service provider update the json map with the sp id and callout to cg to retrieve feature data
        for (Service_Provider__c sp : a.Service_Provider__r) {
            Integer spId = Integer.valueOf(sp.Service_Provider_Id__c);
            String errorString = 'Error: ';

            jsonMap.put('objectId', spId);
            req.setBody(JSON.serialize(jsonMap));

            System.debug('req endpoint: '+req.getEndpoint());
            System.debug('req body: '+req.getBody());

            // add feature data to sp map, checking for any errors
            try {
                res = http.send(req);

                System.debug('res body: '+res.getBody());

                if (res.getStatusCode() == 200) {
                    try {
                        returnMap.put(spId, parseFeatureResponse(res.getBody()));
                    } catch(Exception e) {
                        errorString += 'Error - '+e.getMessage();
                    }
                } else {
                    errorString += res.getStatusCode()+' '+res.getStatus();
                }
            } catch(Exception e) {
                errorString += e.getMessage();
            }

            // set map with error string if error
            if (!returnMap.containsKey(spId)) {
                returnMap.put(spId, 
                    new Map<Integer,CG_AccountFeature>{1 => new CG_AccountFeature(1, null, errorString, null, null)}
                );
            }
        }

        return returnMap;
    }

    // parse feature response for sp feature details
    static Map<Integer,CG_AccountFeature> parseFeatureResponse(String responseString) {
        Map<Integer,CG_AccountFeature> cgFeatureMap = new Map<Integer,CG_AccountFeature>();

        // the reponse should contain a list of json maps - one for each feature
        for (Object jsonObject : (List<Object>)JSON.deserializeUntyped(responseString)) {
            Map<String,Object> jsonItemMap = (Map<String,Object>)jsonObject;

            Integer cgFeatureId = (Integer)jsonItemMap.get('featureId');
            String featureStatus = (String)jsonItemMap.get('status');
            Datetime cgLastModified = Datetime.valueOf((Long)jsonItemMap.get('lastUpdateTimestamp'));
            String cgLastModifiedBy = (String)jsonItemMap.get('lastUpdatePersonId');
            String featureMDString;

            // if metadata map included with feature data, process into metadata string
            if (jsonItemMap.containsKey('metadataList')) {
                Map<String,String> featureMDMap = new Map<String,String>();

                for (Object mdObject : (List<Object>)jsonItemMap.get('metadataList')) {
                    Map<String,Object> mdObjectMap = (Map<String,Object>)mdObject;
                    featureMDMap.put((String)mdObjectMap.get('name'), (String)mdObjectMap.get('value'));
                }
                featureMDString = JSON.serialize(featureMDMap);
            }

            // use retrieved feature data to generate a cg feature instance and add to return map
            cgFeatureMap.put(cgFeatureId, 
                new CG_AccountFeature(cgFeatureId, featureStatus, featureMDString, cgLastModified, cgLastModifiedBy));
        }
        return cgFeatureMap;
    }

    // send features for supplied cg feature message ids
    public static void sendCGFeatureMessages(Set<Id> cgMessageIds) {
        sendCGFeatureMessages(
            [SELECT Id, Request_Body__c, Request_Status__c FROM Integration_Message__c 
                WHERE Id IN : cgMessageIds 
                AND Request_Status__c IN :STATUSES_TO_PROCESS AND Send_After__c <= :DATETIME_NOW AND Process__c = :INTEGRATION_PROCESS]
        );
    }

    // send features for a supplied list of cg feature messages
    public static void sendCGFeatureMessages(List<Integration_Message__c> cgMessageList) {
        String endpoint = ENDPOINT_FEATURE_SEND;
        
        // map of processed service providers, region to set of sp ids - CRM-4839
        // we use this to set up sp update messages to process, for feature activation error checking
        Map<String,Set<Integer>> processedSPMap = new Map<String,Set<Integer>>();

        for (Integration_Message__c cgm : cgMessageList) {
            String jsonBody = cgm.Request_Body__c;
            Http http = new Http();

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
			req.setBody(jsonBody);
            req.setTimeOut(30000);
			
			HTTPResponse res = http.send(req);

			System.debug('res.getBody(): '+res.getBody());

			if (res.getStatusCode() == 200) {
                cgm.Request_Status__c = STATUS_SUCCESS;
                
                // parse to get spid and country and add to sp update map - CRM-4839
                Map<String,Object> msgBodyMap = (Map<String,Object>)JSON.deserializeUntyped(jsonBody);
                Integer spId = Integer.valueOf(msgBodyMap.get('objectId'));
                String region = (String)(msgBodyMap.get('region'));

                if (!processedSPMap.containsKey(region)) {
                    processedSPMap.put(region, new Set<Integer>());
                }
                processedSPMap.get(region).add(spId);
			} else {
                cgm.Request_Status__c = (cgm.Request_Status__c == STATUS_NEW) ? STATUS_RETRY : STATUS_FAILURE;
				cgm.Response_Body__c = res.getBody();
            }
    	}

        // CRM-4839 - retrieve service provider data from cg to set up sp update messages
        //generateServiceProviderUpdateMessages(processedSPMap);

        // update processed feature messages (to processed, retry, or error)
    	update cgMessageList;
    }

    // // ************* THIS NEEDS REWRITING TO IMMEDIATELY CHECK FOR FEATURE ERRORS ************************************
    // // CRM-4839 - for supplied regions/sps, retrieve sp data from cg and create sp update messages
    // static void generateServiceProviderUpdateMessages(Map<String,Set<Integer>> processedSPMap) {
    //     List<Integration_Message__c> spUpdateMessages = new List<Integration_Message__c>();
    //     String boomiNamedCred = general_Functions.isSandbox() ? 'Boomi_Sandbox_API' : 'Boomi_API';

    //     HttpRequest req = new HttpRequest();
    //     req.setEndpoint('callout:'+boomiNamedCred+'/ws/simple/getSP');
    //     req.setMethod('POST');
    //     req.setTimeOut(30000);  // CRM-5152

    //     for (String region : processedSPMap.keySet()) {
    //         for (Integer spId : processedSPMap.get(region)) {
    //             req.setBody('{"objectId":'+spid+',"region":"'+region+'"}');
    //             Http http = new Http();
    //             HTTPResponse res = http.send(req);

    //             System.debug('spid: '+spid+', region: '+region);

    //             if (res.getStatusCode() == 200) {
    //                 String responseBody = res.getBody();
    //                 System.debug('response body:\n'+responseBody);

    //                 if (!String.isBlank(responseBody)) {
    //                     spUpdateMessages.add(
    //                         new Integration_Message__c(
    //                             Request_Body__c = JSON.serializePretty(JSON.deserializeUntyped(responseBody)),
    //                             Process__c = JSONUPDATE,
    //                             Request_Status__c = STATUS_NEW,
    //                             Destination__c = 'Salesforce',
    //                             Direction__c = 'Incoming'
    //                         )
    //                     );
    //                 }
    //             }
    //         }
    //     }

    //     if (!spUpdateMessages.isEmpty()) {
    //         insert spUpdateMessages;
    //     }
    // }

}
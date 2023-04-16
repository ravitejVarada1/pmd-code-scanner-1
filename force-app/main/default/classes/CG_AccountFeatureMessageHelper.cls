// https://cargurus.atlassian.net/browse/CRM-5021
// helper methods for constructing account feature messages
// test coverage in CG_FeatureFramework_Test
public without sharing class CG_AccountFeatureMessageHelper {
    
    public static final String STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
    public static final String STATUS_SUCCESS = Integrations.REQUEST_STATUS_SUCCESS;
    public static final String STATUS_PROCESSED = Integrations.RESPONSE_STATUS_PROCESSED;
    public static final Set<String> REQUEST_STATUSES_TO_PROCESS = Integrations.REQUEST_STATUSES_TO_PROCESS;
    public static final String INTEGRATION_PROCESS = 'Feature Framework';
    
    // send any generated records immediately by default, but allow for set number of hours' delay
    public static Integer delayHours = -1;

    // if not a batch, then this can be set so that messages are not processed immediately
    public static Integer delayMinutes = 10;

    // generate feature messages for single supplied account id
    public static void generateAccountFeatureMessages(Id accountId) {
        generateAccountFeatureMessages(new Set<Id>{accountId});
    }

    // generate feature messages for set of supplied account ids, without forcing into async context
    public static void generateAccountFeatureMessages(Set<Id> accountIds) {
        generateAccountFeatureMessages(accountIds, false);
    }

    // generate feature messages for set of supplied account ids, optionally forcing into async context
    public static void generateAccountFeatureMessages(Set<Id> accountIds, Boolean doAsync) {

        // if forcing to async context and not already async, round trip to future method
        if (doAsync && !System.isBatch() && !System.isFuture()) {
            generateAccountFeatureMessagesFuture(accountIds);
            return;
        }

        // generate feature maps for supplied accounts and use to create cg feature framework message records
        List<Integration_Message__c> intMessageList = createCGFeatureMessages(
            CG_AccountFeatureMapHelper.generateAccountFeaturesMap(accountIds).values()
        );

        if (!intMessageList.isEmpty()) {
            upsert intMessageList;

            //SA-257 - do not send immediately since contracting generates the feature message and
            //Product Activation Status update updates the same message a few minutes apart

            // if for a single account and not in async context, process immediately
            // if (accountIds.size() == 1 && !System.isBatch() && !System.isFuture()) {
            //     //sendMessagesImmediately(new Map<Id,Integration_Message__c>(intMessageList).keySet());
            //     Integrations.sendMessageIdsToBoomi(intMessageList);
            // }
        }
    }

    // future method to force cg message generation into async context
    @future
    private static void generateAccountFeatureMessagesFuture(Set<Id> accountIds) {
        generateAccountFeatureMessages(accountIds, false);
    }

    // future method to send single account cg messages just generated
    @future (callout=true)
    private static void sendMessagesImmediately(Set<Id> intMessageIds) {
        CG_FeatureIntegrationHelper.sendCGFeatureMessages(intMessageIds);
    }

    static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;
    
    // create cg message records for supplied account feature maps
    private static List<Integration_Message__c> createCGFeatureMessages(List<CG_AccountFeatureMap> cgafMapList) {
        
        if (!INTEGRATION_CONTROLS.Enable_Feature_Map_Generation__c && !Test.isRunningTest()) {
            return new List<Integration_Message__c>();
        }

        Datetime sendAfterDatetime;
        if(!System.isBatch()) {
            sendAfterDatetime = Datetime.now().addMinutes(delayMinutes);
        } else {
            sendAfterDatetime = Datetime.now().addHours(delayHours);
        }
        
        Map<Id,Integration_Message__c> spMessageMap = new Map<Id,Integration_Message__c>();

        for (CG_AccountFeatureMap cgAccountFeatures : cgafMapList) {
            Account a = cgAccountFeatures.afAccount;
            Id accountId = a.Id;
            Map<Integer,CG_AccountFeature> featureMap = cgAccountFeatures.getCurrentFeatureMap();

            // create a message for each service provider, using instance of CG_AccountFeatureMessageBody
            for (Service_Provider__c sp : a.Service_Provider__r) {
                CG_AccountFeatureMessageBody cgAccountMsgBody = 
                    new CG_AccountFeatureMessageBody(a, featureMap, Integer.valueOf(sp.Service_Provider_Id__c));

                Id spRecordId = sp.Id;

                spMessageMap.put(spRecordId,
                    new Integration_Message__c(
                        Account__c = accountId,
                        Service_Provider__c = spRecordId,
                        Request_Body__c = JSON.serializePretty(cgAccountMsgBody, true),
                        Request_Status__c = STATUS_NEW,
                        Process__c = INTEGRATION_PROCESS,
                        Send_After__c = sendAfterDatetime
                    )
                );
            }
        }

        List<Integration_Message__c> upsertIntMessageList = new List<Integration_Message__c>();

        // check existing unprocessed messages to avoid creating duplicates, instead update existing records
        for (Service_Provider__c sp : [SELECT Id, (SELECT Id FROM Integration_Messages__r 
                    WHERE Request_Status__c IN :REQUEST_STATUSES_TO_PROCESS AND Process__c = :INTEGRATION_PROCESS) 
                FROM Service_Provider__c WHERE Id IN : spMessageMap.keySet()]) {
            
            Boolean firstMessage = true;
            
            // if more than one record is found, update the first and mark additional messages as processed
            for (Integration_Message__c spMessage : sp.Integration_Messages__r) {
                if (firstMessage) {
                    spMessageMap.get(sp.Id).Id = spMessage.Id;
                    firstMessage = false;
                } else {
                    upsertIntMessageList.add(
                        new Integration_Message__c(
                            Id = spMessage.Id,
                            Request_Status__c = STATUS_SUCCESS,
                            Response_Status__c = STATUS_PROCESSED,
                            Response_Processing_Error__c = 'Superseded by newer feature message'
                        )
                    );
                }
            }
        }

        upsertIntMessageList.addAll(spMessageMap.values());

        return upsertIntMessageList;
    }

}
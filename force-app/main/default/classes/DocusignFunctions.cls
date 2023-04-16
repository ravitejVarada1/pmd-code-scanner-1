/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         Lawrence Zhao
* modifiedBy:     Lawrence Zhao
* created:        05/26/2021
* modified:       05/26/2021
* jira:           BR-774
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class DocusignFunctions {

    private static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;
    private static List<String> dsEnvelopeIds = new List<String>();
    private static String docusignAccId;
    private static String integrationKey;

    private static String getDocusignAccId() {
        if(docusignAccId != null) {
            return docusignAccId;
        }
        if(!Utilities.IS_SANDBOX) {
            docusignAccId = INTEGRATION_CONTROLS.Docusign_Account_Id_Production__c;
        } else {
            String orgURL = Utilities.orgURL;
            if(orgURL.contains('intqa')) { docusignAccId = INTEGRATION_CONTROLS.Docusign_Account_Id_IntQA__c; }
            if(orgURL.contains('staginguat')) { docusignAccId = INTEGRATION_CONTROLS.Docusign_Account_Id_StagingUAT__c; }
        } 
        return docusignAccId;
    }

    private static String getIntegrationKey() {
        if(integrationKey != null) {
            return integrationKey;
        }
        String orgURL = Utilities.orgURL;
        if(orgURL.contains('intqa')) { 
            integrationKey = INTEGRATION_CONTROLS.Docusign_Integration_Key_IntQA__c; 
        } else {
            integrationKey = INTEGRATION_CONTROLS.Docusign_Integration_Key__c;
        }
        return integrationKey;
    }

    // Retrieves list of Docusign Envelopes by Quotes. Only envelopes with Sent/Delivered status can be voided
    public static List<String> getOpenEnvelopeIDs(List<SBQQ__Quote__c> quoteList) {
        for(dsfs__DocuSign_Status__c q : [SELECT dsfs__DocuSign_Envelope_ID__c 
                                          FROM dsfs__DocuSign_Status__c 
                                          WHERE Quote_CPQ__c IN : quoteList AND dsfs__Envelope_Status__c IN ('Sent','Delivered')]) {
            dsEnvelopeIds.add(q.dsfs__DocuSign_Envelope_ID__c);
        }
        return dsEnvelopeIds;
    }

    public static void voidMultipleEnvelopes(List<String> eids, String voidReason) {
        for(String e : eids){
            voidEnvelope(e, voidReason);
        }
    }

    // Callout to Docusign API to void envelope. 
    // Uses the legacy way of authentication (X-DocuSign-Authentication) which will be phased out. Need to update this to use OAuth 2.0 by September 2022.
    public static void voidEnvelope(String envelopeId, String voidReason) {

        Map<String, String> statusUpdate = new Map<String, String>{
            'status'=>'Voided',
            'voidedReason'=>voidReason
        };
        
        String auth_template = '<DocuSignCredentials><Username>{0}</Username><Password>{1}</Password><IntegratorKey>{2}</IntegratorKey></DocuSignCredentials>';    
                
        String endpoint = '/accounts/'+getDocusignAccId()+'/envelopes/'+envelopeId;
        String calloutDest = Utilities.IS_SANDBOX ? 'callout:Docusign_Sandbox_API' : 'callout:Docusign_API'; // uses named credentials
        String integrationKey = getIntegrationKey();
 
        HttpRequest request = new HttpRequest();
        request.setEndpoint(calloutDest+endpoint);
        request.setMethod('PUT');
        request.setHeader('X-DocuSign-Authentication', String.format(auth_template, new String[]{'{!$Credential.Username}','{!$Credential.Password}',integrationKey}));
        request.setBody(JSON.serialize(statusUpdate));
        System.debug('Request: '+request);
        try{
            HttpResponse resp = new Http().send(request);
            System.debug('RespCode: '+resp.getStatusCode());
            System.debug('RespBody: '+resp.getBody());
        } catch (System.CalloutException e) {
            System.debug('Callout Error: '+e);
        }
    }
}
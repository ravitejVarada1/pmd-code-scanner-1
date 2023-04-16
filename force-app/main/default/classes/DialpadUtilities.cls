/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        01/07/2021
* modified:       01/07/2021
* created jira:   BR-348
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class DialpadUtilities {
    //Constants populated manually
    private static final String FALL_BACK_PATH = 'SUPPORT';
    private static final String FALL_BACK_REGION = 'US';
    private static final String FALL_BACK_LANGUAGE = 'EN';
    private static final String FALL_BACK_CALL_CENTER = 'UNKNOWN';
    private static final String CS_FALL_BACK_PATH = 'CONSUMERSUPPORTUNKNOWN';
    private static final String CS_FALL_BACK_REGION = 'US';
    private static final String CS_FALL_BACK_LANGUAGE = 'EN';
    private static final String CS_FALL_BACK_CALL_CENTER = 'C2DUNKNOWN';
    
    public static final Set<String> VALID_PATHS = new Set<String>{'SUPPORT', 'SALES', 'BILLING', 'COLLECTIONS', 'MARKETING'};
    public static final Set<String> CS_VALID_PATHS = new Set<String>{'CONSUMERSUPPORT'};

        public static final Set<String> VALID_LANGUAGES = new Set<String>{'EN', 'FR'};
    public static final String FALL_BACK_LEAD_QUEUE_NAME = 'RR_SDR_CA';
    public static final String FALL_BACK_CASE_QUEUE_NAME = 'Support_Case_Queue';
        
    //Constants populated via static block
    public static final Set<String> VALID_COUNTRY_CODES;
    public static final Set<String> VALID_COUNTRIES;
    public static final Map<String,Map<String,Map<String,Dialpad_Target__mdt>>> REGION_TO_CALL_CENTER_MAP;
    public static final Map<String,ID> QUEUE_NAME_TO_ID_MAP;
    public static final ID FALL_BACK_CASE_QUEUE;
    public static final ID FALL_BACK_LEAD_QUEUE;
    
    //Populates static variables above (allows one query to populate multiple collections)
    static{
        VALID_COUNTRY_CODES = new Set<String>();
        VALID_COUNTRIES = new Set<String>();
        REGION_TO_CALL_CENTER_MAP = new Map<String,Map<String,Map<String,Dialpad_Target__mdt>>>();
        QUEUE_NAME_TO_ID_MAP = new Map<String,ID>();
        
        for (Dialpad_Target__mdt dialPadTarget : [SELECT Target_ID__c, Callcenter_Type__c, Country_Code__c,
                                                  Country_Prefix__c, Language__c, Default_Case_Queue__c,
                                                  Default_Lead_Queue__c	
                                                  FROM Dialpad_Target__mdt])
        {
            String countryCode = dialPadTarget.Country_Code__c.toUpperCase();
            String callCenterType = dialPadTarget.Callcenter_Type__c.toUpperCase();
            
            if (!REGION_TO_CALL_CENTER_MAP.containsKey(countryCode)){
                REGION_TO_CALL_CENTER_MAP.put(countryCode, new Map<String,Map<String,Dialpad_Target__mdt>>());
            }
            
            if (!REGION_TO_CALL_CENTER_MAP.get(countryCode).containsKey(callCenterType)){
                REGION_TO_CALL_CENTER_MAP.get(countryCode).put(callCenterType, new Map<String,Dialpad_Target__mdt>());
            }
            
            REGION_TO_CALL_CENTER_MAP.get(countryCode).get(callCenterType).put(
                dialPadTarget.Language__c,
                dialPadTarget
            );

            VALID_COUNTRY_CODES.add(dialPadTarget.Country_Prefix__c.toUpperCase());
            VALID_COUNTRIES.add(countryCode.toUpperCase());

            QUEUE_NAME_TO_ID_MAP.putAll(
                new Map<String,ID>{
                    dialPadTarget.Default_Case_Queue__c => null,
                    dialPadTarget.Default_Lead_Queue__c => null
                }
            );
        }
        
        QUEUE_NAME_TO_ID_MAP.remove(null);
        
        for (Group queue : [SELECT Id, DeveloperName
                            FROM Group 
                            WHERE Type = 'Queue'
                            AND DeveloperName IN :QUEUE_NAME_TO_ID_MAP.keySet()])
        {
            QUEUE_NAME_TO_ID_MAP.put(queue.DeveloperName, queue.Id);
            
            if (queue.DeveloperName == FALL_BACK_LEAD_QUEUE_NAME){
                FALL_BACK_LEAD_QUEUE = queue.Id;
            }
            
            if (queue.DeveloperName == FALL_BACK_CASE_QUEUE_NAME){
                FALL_BACK_CASE_QUEUE = queue.Id;
            }
        }
    }
    
    public static Id createCase(ExpandedCallPayload expandedPayload){
        String defaultQueue = expandedPayload.dialPadTarget.Default_Case_Queue__c;
        ID firstAccountId = expandedPayload.firstAccount?.Id;
        Set<String> relatedDealerAccountRecordTypes = new Set<String>{
            'Corporate Account',
            'Dealer Account'
        };
        
        try{
            Case  c = new Case(
                Status = 'New',
                Origin = 'Phone',
                AccountId = firstAccountId,
                Dialpad_Phone__c = expandedPayload.externalNumber,
                Call_Id__c = expandedPayload.callId,
                Master_Call_Id__c = expandedPayload.masterCallId,
                Reason = expandedPayload.path.toLowerCase().capitalize(),
                Priority = 'Medium',
                Subject = 'Customer support call from phone number - ' + expandedPayload.externalNumber,
                Description = 'A call to support was place via phone number ' + expandedPayload.externalNumber,
                CountryCode__c = expandedPayload.region
            );
            
            if (defaultQueue != null && QUEUE_NAME_TO_ID_MAP.containsKey(defaultQueue)){
                c.OwnerId = QUEUE_NAME_TO_ID_MAP.get(defaultQueue);
            }else{
                c.OwnerId = FALL_BACK_CASE_QUEUE;
            }

            //CRM-5931
            //added recordtypes on the to be created new case record
            String currentURIPath = expandedPayload.path;

            if(String.isNotBlank(currentURIPath)){

                if(currentURIPath.containsIgnoreCase('BILLING') || currentURIPath.containsIgnoreCase('COLLECTIONS')){

                    Id requiredCaseRTID = CaseTriggerFunctions.caseRTNameIdMap.get('Billing'); 
                    c.RecordTypeId = requiredCaseRTID;

                }else if(currentURIPath.containsIgnoreCase('SUPPORT')){

                    Id requiredCaseRTID = CaseTriggerFunctions.caseRTNameIdMap.get('Support'); 
                    c.RecordTypeId = requiredCaseRTID;
                }

            }
            
            if (relatedDealerAccountRecordTypes.contains(expandedPayload.firstAccount?.recordType.Name)){
                c.Related_Dealer_Account__c = firstAccountId;
            }
            
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.assignmentRuleHeader.useDefaultRule = false;
            
            
            Database.insert(c, dml);
            return c.Id;
        }catch(exception e){
            expandedPayload.caseCreationErrors = e.getMessage() + '<orderBrokenSpacer>' +  e.getStackTraceString();
            return null;
        }
    }
    
        public static Id createConsumerSupportCase(ExpandedCallPayload expandedPayload){
        
        String defaultQueue = expandedPayload.dialPadTarget.Default_Case_Queue__c;
        ID firstAccountId = expandedPayload.firstAccount?.Id;
        ID firstContactId = expandedPayload.firstContact?.Id;
        Id ConsumerSupportCaseRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND Name = 'Consumer Support'
        ][0].Id;
        
        try{
            Case  c = new Case(
                Status = 'New',
                Origin = 'Phone',
                AccountId = firstAccountId,
                ContactId = firstContactId,
                Dialpad_Phone__c = expandedPayload.externalNumber,
                Call_Id__c = expandedPayload.callId,
                Master_Call_Id__c = expandedPayload.masterCallId,
                RecordTypeId = ConsumerSupportCaseRecordTypeId ,
                Priority = 'Medium',
                Subject = 'Consumer support call from phone number - ' + expandedPayload.externalNumber,
                Description = 'A call to support was place via phone number ' + expandedPayload.externalNumber
            );
            
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.assignmentRuleHeader.useDefaultRule = false;
            
            
            Database.insert(c, dml);
            return c.Id;
        }catch(exception e){
            expandedPayload.caseCreationErrors = e.getMessage() + '<orderBrokenSpacer>' +  e.getStackTraceString();
            return null;
        }
    }
    
    public static Id createLead(ExpandedCallPayload expandedPayload){
        String defaultQueue = expandedPayload.dialPadTarget.Default_Lead_Queue__c;
        
        try{
            Lead l = new Lead(
                LastName = 'Inbound Call',
                Company = 'Unknown',
                Phone = expandedPayload.externalNumber,
                CountryCode = expandedPayload.region,
                Call_Id__c = expandedPayload.callId,
                Master_Call_Id__c = expandedPayload.masterCallId,
                LeadSource = 'Inbound: Phone'
            );
            
            if (defaultQueue != null && QUEUE_NAME_TO_ID_MAP.containsKey(defaultQueue)){
                l.OwnerId = QUEUE_NAME_TO_ID_MAP.get(defaultQueue);
            }else{
                l.OwnerId = FALL_BACK_LEAD_QUEUE;
            }

            if (expandedPayload.firstAccount != null) {
                System.debug('Assigning Lead Account');
                l.Lead_Account__c = expandedPayload.firstAccount.Id;
                l.Company = expandedPayload.firstAccount.Name;
            }
            
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.assignmentRuleHeader.useDefaultRule = false;
            
            Database.insert(l, dml);
            return l.Id;
        }catch(exception e){
            expandedPayload.leadCreationErrors = e.getMessage() + '<orderBrokenSpacer>' +  e.getStackTraceString();
            return null;
        }
    }
    
    //Used in "RestDialpadCallRouter" class to essentially provide a more robust version of the payload
    //that the endpoint takes. The constructor below also validates a bunch of the payload variables
    public class ExpandedCallPayload{
        public String dateStarted;
        public String callId;
        public String masterCallId;
        public String externalNumber;
        public String internalNumber;
        public String contactId;
        public String contactType;
        public String region;
        public String language;
        public String path;
        public String foundCallcenterType;
        public String phoneSearches;
        public String campaignSearches;
        public String foundTargetType;
        public String foundUserId;
        public Account firstAccount;
        public Contact firstContact;
        public Id returnedLeadId;
        
        public List<Account> foundAccounts;
        public List<Contact> foundContacts;
        public Set<ID> foundAccountIds = new Set<ID>();
        public List<Lead> foundLeadsWithAccount;
        public List<Lead> foundLeadsNoAccount;
        public Set<ID> foundLeadIds = new Set<ID>();
        public Set<ID> foundContactIds = new Set<ID>();
        public Boolean accountsExist;
        public Boolean contactExist;
        public Boolean leadsExist;
        public Set<ID> foundCaseIds = new Set<ID>();
        
        public ID createdLeadId;
        public ID createdCaseId;
        public ID createdCampaignMemberId;
        
        public Boolean caseNeeded = false;
        public Boolean leadNeeded = false;
        public Boolean campaignMemberCheckNeeded = false;
        public RestDialpadCallRouter.Response theResponse;

        
        public String caseCreationErrors;
        public String leadCreationErrors;
        
        public Dialpad_Target__mdt dialPadTarget;
        
        public ExpandedCallPayload(){
            
        }
        
        public ExpandedCallPayload(RestDialpadCallRouter.rawPayloadWrap rawPayload,
                           List<String> requestURIParams)
        {
            this.dateStarted = rawPayload.date_started;
            this.callId = rawPayload.call_id;
            this.masterCallId = rawPayload.master_call_id;
            this.externalNumber = rawPayload.external_number;
            this.internalNumber = rawPayload.internal_number;
            this.contactId = rawPayload.contact_id;
            this.contactType = rawPayload.contact_type;
            
            Integer numURIParams = requestURIParams.size();
            this.path = numURIParams >= 3 ? requestURIParams[2].toUpperCase() : null;
            
            String countryAndLanguageParam = numURIParams >= 4 ? requestURIParams[3].toUpperCase() : null;
            
            System.debug(countryAndLanguageParam);
            
            if (countryAndLanguageParam != null){
                switch on countryAndLanguageParam.length(){
                    when 2{
                        this.region = countryAndLanguageParam.substring(0,2);
                        this.language = null;
                    }when 4{
                        this.region = countryAndLanguageParam.substring(0,2);
                        this.language = countryAndLanguageParam.substring(2);
                    }
                }
            }
			
			validatePayloadUrl('Dealer');
        }
        
       public ExpandedCallPayload(RestDialpadConsumerSupportCallRouter.rawPayloadWrap rawPayload,
                           List<String> requestURIParams, String Type)
        {
            this.dateStarted = rawPayload.date_started;
            this.callId = rawPayload.call_id;
            this.masterCallId = rawPayload.master_call_id;
            this.externalNumber = rawPayload.external_number;
            this.internalNumber = rawPayload.internal_number;
            this.contactId = rawPayload.contact_id;
            this.contactType = rawPayload.contact_type;

            Integer numURIParams = requestURIParams.size();
            this.path = numURIParams >= 3 ? requestURIParams[2].toUpperCase() : null;

            String countryAndLanguageParam = numURIParams >= 4 ? requestURIParams[3].toUpperCase() : null;
            
            System.debug(countryAndLanguageParam);
            
            if (countryAndLanguageParam != null){
                switch on countryAndLanguageParam.length(){
                    when 2{
                        this.region = countryAndLanguageParam.substring(0,2);
                        this.language = null;
                    }when 4{
                        this.region = countryAndLanguageParam.substring(0,2);
                        this.language = countryAndLanguageParam.substring(2);
                    }
                }
            }
			
			validatePayloadUrl('Consumer');
        }
        
        //Validates the JSON payload and corrects data if possible
        public void validatePayloadUrl(String Type){
            
            if(Type=='Dealer'){
                
                if (path == null || !VALID_PATHS.contains(path)){
                    path = FALL_BACK_PATH;
                }
                
                if (region == null || !VALID_COUNTRIES.contains(region)){
                    region = FALL_BACK_REGION;
                }
    
                if (language == null || !VALID_LANGUAGES.contains(language)){
    
                    language = FALL_BACK_LANGUAGE;
                }
            }
            else if(Type=='Consumer'){
                
                if (path == null || !CS_VALID_PATHS.contains(path)){
                    path = CS_FALL_BACK_PATH;
                }
                
                if (region == null || !VALID_COUNTRIES.contains(region)){
                    region = CS_FALL_BACK_REGION;
                }
    
                if (language == null || !VALID_LANGUAGES.contains(language)){
    
                    language = CS_FALL_BACK_LANGUAGE;
                }
                
            }

            phoneSearches = getPhoneSearchString(externalNumber);
            campaignSearches = getPhoneSearchString(internalNumber);
        }
        
        //Just removes all non numerical characters and the country code - if one exists,
        //then adds a version of the phone number with the country code and one
        //without to the phoneSearches string
        private string getPhoneSearchString(String externalNumber){
            String externalNumDigits = externalNumber.replaceAll('[^0-9]', '');
            String externalNumDigitsNoCountry;
            String returnString;
            
            for (String countryCode : VALID_COUNTRY_CODES){
                if (externalNumDigits.startsWith(countryCode)){
                    externalNumDigitsNoCountry = externalNumDigits.substringAfter(countryCode);
                }
            }

            returnString = externalNumDigits;
            if (externalNumDigitsNoCountry != null){
                returnString += ' OR ' +  externalNumDigitsNoCountry;
            }
            
            return returnString;
        }
        
        public void insertLog(){
            Dialpad_Router_Log__c log = new Dialpad_Router_Log__c(
                accountId__c = firstAccount?.Id,
                callId__c = callId,
                contactId__c = contactId,
                contactType__c = contactType,
                externalNumber__c = externalNumber,
                foundCallcenterType__c = foundCallcenterType,
                foundAccountIdsLong__c = String.join(new List<ID>(foundAccountIds), ','),
                foundLeadIdsLong__c = String.join(new List<ID>(foundLeadIds), ','),
                foundContactIdsLong__c = String.join(new List<ID>(foundContactIds), ','),
                foundCaseIdsLong__c = String.join(new List<ID>(foundCaseIds), ','),
                foundAccounts__c = !foundAccountIds.isEmpty(),
                foundLeads__c = !foundLeadIds.isEmpty(),
                foundContacts__c = !foundContactIds.isEmpty(),
                foundCases__c = !foundCaseIds.isEmpty(),
                foundTargetType__c = foundTargetType,
                foundUserId__c = foundUserId,
                internalNumber__c = internalNumber,
                masterCallId__c = masterCallId,
                path__c = path,
                language__c = language,
                phoneSearches__c = phoneSearches,
                region__c = region,
                createdLeadId__c = createdLeadId,
                createdCampaignMemberId__c = createdCampaignMemberId,
                createdCaseId__c = createdCaseId,
                
                returnedTargetId__c	= theResponse.target_id,
                returnedTargetType__c = theResponse.target_type,
                
                caseCreationErrors__c = caseCreationErrors,
                leadCreationErrors__c = leadCreationErrors
                
            );
            
            insert log;
        }
    }
    
    public static Dialpad_Target__mdt getDialpadTarget(ExpandedCallPayload payload, STRING Type){
        Dialpad_Target__mdt dialPadTarget = REGION_TO_CALL_CENTER_MAP?.get(payload.region)?.get(payload.foundCallCenterType)?.get(payload.Language);
        
        if (dialPadTarget == null && Type=='Dealer'){
            dialPadTarget = REGION_TO_CALL_CENTER_MAP.get(payload.region).get(FALL_BACK_CALL_CENTER).get(FALL_BACK_LANGUAGE);
        }
        else if(dialPadTarget == null && Type=='Consumer'){
            dialPadTarget = REGION_TO_CALL_CENTER_MAP.get(payload.region).get(CS_FALL_BACK_CALL_CENTER).get(CS_FALL_BACK_LANGUAGE);

        }
        return dialPadTarget;
    }
}
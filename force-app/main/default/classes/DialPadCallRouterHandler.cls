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

public class DialPadCallRouterHandler {
    private DialpadUtilities.ExpandedCallPayload expandedPayload;
    
    private static final String USER_TARGET  = 'user';
    private static final String CALLCENTER_TARGET = 'callcenter';
    private static final String UNKNOWN = 'UNKNOWN';
    private static final String SALES = 'SALES';
    private static final String SUPPORT = 'SUPPORT';
    private static final String COLLECTIONS = 'COLLECTIONS';
    private static final String BILLING = 'BILLING';
    private static final String PAYING = 'PAYING';
    private static final String NON_PAYING = 'NONPAYING';

    public DialPadCallRouterHandler(DialpadUtilities.ExpandedCallPayload expandedPayload){
        this.expandedPayload = expandedPayload;
    }
    
    public RestDialpadCallRouter.Response findRoutingId(){
        
        //Look for the phone in accounts or leads and populate some booleans and lists
        String caseRecordTypeNameSearch = expandedPayload.path.equalsIgnoreCase('SUPPORT') ? 'Support' : 'Billing';

        Integer i = -1;
        for (List<sObject> sObjectList : [FIND :expandedPayload.phoneSearches IN PHONE FIELDS
                                          RETURNING Account (Id ORDER BY lastModifiedDate DESC),
                                          Lead (Id, Lead_Account__c, Lead_Account__r.OwnerId,
                                                Lead_Account__r.Owner.Dialpad_Id__c, Lead_Account__r.Owner.Automation_User__c
                                                WHERE IsConverted != true 
                                                AND Status != 'Closed - Not Converted'
                                                ORDER BY Lead_Account__c NULLS LAST
                                                LIMIT 1),
                                          Contact (Id, AccountId ORDER BY lastModifiedDate DESC),
                                          Case (Id WHERE IsClosed = false AND RecordType.Name = :caseRecordTypeNameSearch LIMIT 1)])
        {        
            i++;
            
            Switch on i{
                when 0{
                    for (Account a : (List<Account>)sObjectList){
                        expandedPayload.foundAccountIds.add(a.Id);
                    }
                }when 1{
                    List<Lead> allLeads = (List<Lead>)sObjectList;
                    
                    if (allLeads.isEmpty()){
                        continue;
                    }
                    
                    expandedPayload.foundLeadsWithAccount = new List<Lead>();
                    expandedPayload.foundLeadsNoAccount = new List<Lead>();
                    
                    for (Lead l : (List<Lead>)sObjectList){
                        expandedPayload.foundLeadIds.add(l.Id);
                        if (l.Lead_Account__c != null){
                            expandedPayload.foundLeadsWithAccount.add(l);
                            expandedPayload.foundAccountIds.add(l.Lead_Account__c);
                        }else{
                            expandedPayload.foundLeadsNoAccount.add(l);
                        }
                    }
                }when 2{
                    //If there are contacts, just grab the related accounts
                    if (sObjectList.isEmpty()){
                        continue;
                    }
                    
                    for (Contact c : (List<Contact>)sObjectList){
                        expandedPayload.foundContactIds.add(c.Id);
                        expandedPayload.foundAccountIds.add(c.AccountId);
                    }
                }when 3{
                    if (sObjectList.isEmpty()){
                        continue;
                    }
                    
                    expandedPayload.foundCaseIds.addAll(new Map<ID,Case>((List<Case>)sObjectList).keySet());
                }
            }
        }

        expandedPayload.foundAccounts = [SELECT Id, Name, Owner.Dialpad_Id__c, Owner.Name, recordType.Name,
                                         Owner.Automation_User__c, Account_Saturation_Percentage_Formula__c,
                                         OwnerId
                                         FROM Account
                                         WHERE Id IN :expandedPayload.foundAccountIds
                                         ORDER BY Account_Saturation_Percentage_Formula__c DESC];
        
        expandedPayload.accountsExist = !expandedPayload.foundAccounts.isEmpty();
        expandedPayload.leadsExist = !expandedPayload.foundLeadIds.isEmpty();
        
        if (expandedPayload.accountsExist){
            expandedPayload.firstAccount = expandedPayload.foundAccounts[0];
        }
        
        //Based on the PATH constant passed in to this method, run the related method,
        //which populates the foundTargetType variable and either the foundUserId 
        //or foundCallcenterType variable
        switch on expandedPayload.path{
            when 'SUPPORT'{
                processNonSalesRequest();
            }when 'BILLING'{
                processNonSalesRequest();
            }when 'COLLECTIONS'{
                processNonSalesRequest();
            }when 'SALES'{
                processSalesRequest();
            }when 'MARKETING'{
                processMarketingRequest();
            }
            when else{
                processFallback();
            }
        }
        
        expandedPayload.dialPadTarget = DialpadUtilities.getDialpadTarget(expandedPayload,'Dealer');
        expandedPayload.theResponse = new RestDialpadCallRouter.Response(expandedPayload);
        
        insertRecords();

        return expandedPayload.theResponse;
    }

    public void processNonSalesRequest(){
        
        for (Case c : [SELECT Id
                       FROM Case
                       WHERE (AccountId IN :expandedPayload.foundAccounts
                              OR Related_Dealer_Account__c IN :expandedPayload.foundAccounts)
                       AND IsClosed = false 
                       AND Reason LIKE :expandedPayload.path
                       LIMIT 1])
        {
            expandedPayload.foundCaseIds.add(c.Id);
        }
        
        String pathAppend = '';
        
        if (expandedPayload.path == SUPPORT){
            if (expandedPayload.accountsExist) {
                pathAppend = expandedPayload.firstAccount.Account_Saturation_Percentage_Formula__c > 0
                    ? PAYING
                    : NON_PAYING;
            }
        }

        //If there are no existing cses, create a case
        if (expandedPayload.foundCaseIds.isEmpty()){
            expandedPayload.caseNeeded = true;
        }
        
        if (expandedPayload.accountsExist || 
                    ((expandedPayload.path == SUPPORT || expandedPayload.path == BILLING || expandedPayload.path == COLLECTIONS) 
                    && expandedPayload.region != 'CA')){
            expandedPayload.foundCallcenterType = expandedPayload.path + pathAppend;
            expandedPayload.foundTargetType = CALLCENTER_TARGET;
        }else{
            processFallback();
        }
    }
    
    public void processSalesRequest(){
        String foundUserDialpadId;

        if (expandedPayload.firstAccount.Owner.Automation_User__c && expandedPayload.region == 'GB' && !expandedPayload.leadsExist) {
            expandedPayload.leadNeeded = true;
        } else {
            expandedPayload.leadNeeded = !expandedPayload.leadsExist && expandedPayload.foundContactIds.isEmpty();
        }

        System.debug('Lead needed: ' + expandedPayload.leadNeeded);
        
        if (expandedPayload.accountsExist && !expandedPayload.firstAccount.Owner.Automation_User__c){
            foundUserDialpadId = expandedPayload.firstAccount.Owner.Dialpad_Id__c;
        }else if (expandedPayload.foundLeadsWithAccount != null && !expandedPayload.foundLeadsWithAccount.isEmpty()){
            for (Lead l : expandedPayload.foundLeadsWithAccount){
                if (String.valueOf(l.Lead_Account__r.OwnerId).startsWithIgnoreCase('005')
                    && !l.Lead_Account__r.Owner.Automation_User__c){
                        foundUserDialpadId = l.Lead_Account__r.Owner.Dialpad_Id__c;
                        expandedPayload.returnedLeadId = l.Id;
                        break;
                }
            }
        }
        
        if (foundUserDialpadId == null){
            processSalesFallback();
            return;
        } else {
            expandedPayload.foundTargetType = USER_TARGET;
            expandedPayload.foundUserId = foundUserDialpadId;
            expandedPayload.foundCallcenterType = expandedPayload.path;
        }
    }
    
    public void processMarketingRequest(){
        expandedPayload.campaignMemberCheckNeeded = true;
        
        processSalesRequest();
    }
    
    public void processFallback(){
        //populate the response with the UNKNOWN call center variables
        expandedPayload.foundTargetType = CALLCENTER_TARGET;
        expandedPayload.foundCallcenterType = UNKNOWN;
    }
    
    public void processSalesFallback(){
        //populate the response with the UNKNOWN call center variables
        expandedPayload.foundTargetType = CALLCENTER_TARGET;
        expandedPayload.foundCallcenterType = SALES;
    }
    
    public Id checkForCampaignMember(){
         
        //Search for a campaign that matches the internal number the cusomer called
        //return if there is no campaign found
        ID matchedCampaignId;
        for (List<Sobject> matchedCampaigns : [FIND :expandedPayload.campaignSearches IN PHONE FIELDS
                                               RETURNING Campaign (Id LIMIT 1)])
        {
            if (!matchedCampaigns.isEmpty()){
                matchedCampaignId = matchedCampaigns[0].Id;
            }else{
                return null;
            }
        }
        
        if (![SELECT Id
              FROM CampaignMember
              WHERE CampaignId = :matchedCampaignId
              AND (
                  ContactId in :expandedPayload.foundContactIds
                  OR
                  LeadId in :expandedPayload.foundLeadIds
              )
              LIMIT 1].isEmpty())
        {
            return null;
        }
        
        //Create a new campaign member and set the ContactId as the first contact we found
        //If we didn't find any contacts, set the LeadId as the first lead we found. If there
        //are no contacts or lead, set the LeadId as the lead we created
        CampaignMember newCampaignMember = new CampaignMember(campaignId = matchedCampaignId);
        
        if (!expandedPayload.foundContactIds.isEmpty()){
            newCampaignMember.ContactId = new List<ID>(expandedPayload.foundContactIds)[0];
        }else{
            ID leadId;
            if (expandedPayload.returnedLeadId != null){
                leadId = expandedPayload.returnedLeadId;
            }else if (!expandedPayload.foundLeadIds.isEmpty()){
                leadId = new List<ID>(expandedPayload.foundLeadIds)[0]; 
            }else if (expandedPayload.createdLeadId != null){
                leadId = expandedPayload.createdLeadId;
            }else{
                return null;
            }
            
            newCampaignMember.LeadId = leadId;
        }
        
        insert newCampaignMember;
        
        return newCampaignMember.Id;
    }
    
    public void insertRecords(){
        if (expandedPayload.caseNeeded){
            expandedPayload.createdCaseId = DialpadUtilities.createCase(expandedPayload);
        }
        
        if (expandedPayload.leadNeeded){
            expandedPayload.createdLeadId = DialpadUtilities.createLead(expandedPayload);
        }
        
        if (expandedPayload.campaignMemberCheckNeeded){
             expandedPayload.createdCampaignMemberId = checkForCampaignMember();
        }

        expandedPayload.insertLog();
    }
}
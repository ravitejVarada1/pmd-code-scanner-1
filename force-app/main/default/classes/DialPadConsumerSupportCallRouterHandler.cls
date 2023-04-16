public class DialPadConsumerSupportCallRouterHandler {
    private DialpadUtilities.ExpandedCallPayload expandedPayload;
    
    private static final String USER_TARGET  = 'user';
    private static final String CALLCENTER_TARGET = 'callcenter';
    private static final String UNKNOWN = 'C2DUNKNOWN';


    public DialPadConsumerSupportCallRouterHandler(DialpadUtilities.ExpandedCallPayload expandedPayload){
        this.expandedPayload = expandedPayload;
    }
    
    public RestDialpadCallRouter.Response findCSRoutingId(){
        //Look for the phone in accounts and populate some booleans and lists
        Integer i = -1;
    for (List<sObject> sObjectList : [FIND :expandedPayload.phoneSearches IN PHONE FIELDS
                                          RETURNING Account (Id where IsPersonAccount=true ORDER BY lastModifiedDate DESC),
                                          Contact (Id, AccountId where IsPersonAccount=true ORDER BY lastModifiedDate DESC),
                                          Case (Id WHERE IsClosed = false AND Reason = :expandedPayload.path AND recordtype.name='Consumer Support' LIMIT 1)])
        {        
            i++;
            
            Switch on i{
                when 0{
                    for (Account a : (List<Account>)sObjectList){
                        expandedPayload.foundAccountIds.add(a.Id);
                    }
                }when 1{
                    //If there are contacts, just grab the related accounts
                    if (sObjectList.isEmpty()){
                        continue;
                    }
                    
                    for (Contact c : (List<Contact>)sObjectList){
                        expandedPayload.foundContactIds.add(c.Id);
                        expandedPayload.foundAccountIds.add(c.AccountId);
                    }
                }when 2{
                    if (sObjectList.isEmpty()){
                        continue;
                    }
                    
                    expandedPayload.foundCaseIds.addAll(new Map<ID,Case>((List<Case>)sObjectList).keySet());
                }
            }
        }

        expandedPayload.foundAccounts = [SELECT Id, Owner.Dialpad_Id__c, Owner.Name, recordType.Name,
                                         OwnerId
                                         FROM Account 
                                         WHERE Id IN :expandedPayload.foundAccountIds 
                                         AND IsPersonAccount=true
                                         ORDER BY CreatedDate DESC];
        
        expandedPayload.accountsExist = !expandedPayload.foundAccounts.isEmpty();
        
        if (expandedPayload.accountsExist){
            expandedPayload.firstAccount = expandedPayload.foundAccounts[0];
        }
        
        if(!expandedPayload.foundContactIds.isEmpty())
        {
            expandedPayload.foundContacts = [select Id from contact where Id IN : expandedPayload.foundContactIds 
                                             and IsPersonAccount=true];
             expandedPayload.contactExist = !expandedPayload.foundContacts.isEmpty();
             if (expandedPayload.contactExist){
            	expandedPayload.firstContact = expandedPayload.foundContacts[0];
        }
            
        }
       if(expandedPayload.foundAccountIds.size()>0)
                processConsumerSupport();
        else
          	processFallback();
        
        expandedPayload.dialPadTarget = DialpadUtilities.getDialpadTarget(expandedPayload,'Consumer');
        expandedPayload.theResponse = new RestDialpadCallRouter.Response(expandedPayload);

        insertRecords();

        return expandedPayload.theResponse;
    }

 
    
    public void processFallback(){
        //populate the response with the UNKNOWN call center variables
        expandedPayload.foundTargetType = CALLCENTER_TARGET;
        expandedPayload.foundCallcenterType = UNKNOWN;
         expandedPayload.caseNeeded = true;
    }
    

    
    public void processConsumerSupport(){
       //populate the response with the KNOWN call center variables
        expandedPayload.foundTargetType = CALLCENTER_TARGET;
         expandedPayload.foundCallcenterType = expandedPayload.path;
        expandedPayload.caseNeeded = true;
        
        
    }
    
    
    public void insertRecords(){
        if (expandedPayload.caseNeeded){
            	expandedPayload.createdCaseId = DialpadUtilities.createConsumerSupportCase(expandedPayload);
        }
        

        expandedPayload.insertLog();
    }
}
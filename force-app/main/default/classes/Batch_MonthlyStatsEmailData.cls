global class Batch_MonthlyStatsEmailData implements Database.Batchable<sObject>, Schedulable{
    
    private static Map<String, Listings_Performance_metrics__mdt> listingsMetadataMap = new Map<String, Listings_Performance_metrics__mdt>();     
    private static Set<String> payingAccountTypeSet = new Set<String>();
    private static Set<String> basicAccountTypeSet = new Set<String>();
    private	static Set<String> acctTypeSet = new Set<String>();    
    private static String payingAccountTypes;
    private static String BasicAccountTypes;    
    
    static {
        
        listingsMetadataMap = Batch_AccountHistorySnapshotHelper.getPerformanceMetricsMtd();
        
        if(listingsMetadataMap.values() != null){
            for(Listings_Performance_metrics__mdt metricsCategory : listingsMetadataMap.values()){
                payingAccountTypes 	= metricsCategory.Include_Paying_Account_Types__c;
                basicAccountTypes	= metricsCategory.Include_Basic_Account_Types__c;            
            }

            if(payingAccountTypes != null){
                payingAccountTypeSet 	= new Set<String>(new List<String>(payingAccountTypes.split(',')));
            }
            if(basicAccountTypes != null) {
                basicAccountTypeSet  	= new Set<String>(new List<String>(basicAccountTypes.split(',')));
            }
            
            acctTypeSet.addAll(payingAccountTypeSet);
            acctTypeSet.addAll(basicAccountTypeSet);            
        }
    }
    
    private static final String[] ahsFields = new List<String>{
        	'X30_Day_SRP_Volume__c' , 						
            'X30_Day_VDP_Volume__c' , 						
            'X30_Day_Lead_Volume_Web_Clicks_Total__c' ,		
            'X30_Day_Lead_Volume_Map_Views_Total__c' ,		
            'X30_Day_Lead_Volume_Total_Total__c' ,			
            'X30_Day_Lead_Volume_Online_Total__c' ,			
            'X30_Day_Lead_Volume_Phone_Total__c' ,			
            'X30_Day_Lead_Volume_SMS_Total__c' ,			
            'X30_Day_Lead_Volume_Chat_Total__c' ,			
            'X30_Day_Reviews__c' ,							
            'X30_Day_Matching_Ad_Impressions__c' , 			
            'X30_Day_Ad_Clicks__c',							
            'X90_Day_Lead_Vol_Current_Chat__c',				
            'X90_Day_Lead_Vol_Current_Online__c',			
            'X90_Day_Lead_Vol_Current_Phone__c',			
            'X90_Day_Lead_Vol_Current_SMS__c',				
            'X90_Day_Lead_Vol_Current_Total__c', 			
            'Total_New_Inventory_Units__c',					
            'Total_Used_Inventory_Units__c'					
            };
                
    private Set<String> queryEmails;
    
    global Batch_MonthlyStatsEmailData() {}
    
    global Batch_MonthlyStatsEmailData(String queryEmail) {
        this.queryEmails = new Set<String>{queryEmail};
            }
    
    global Batch_MonthlyStatsEmailData(Set<String> queryEmails) {
        this.queryEmails = queryEmails;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        String query = 'SELECT Id, Email__c, Account__r.Type FROM ' + 
            'Contact_Dashboard_Access__c WHERE Account__r.Type in : acctTypeSet ' +
            'AND Email__c != null AND status__c = true AND Account__c in '+
            '(SELECT Account__c FROM Account_History_Snapshot__c WHERE ' +
            'Snapshot_Date__c = LAST_MONTH and Account__r.Type IN : acctTypeSet)';
        if (queryEmails != null) {
            query += ' AND Email__c in : queryEmails';		
        }
        system.debug('Batch_MonthlyStatsEmailData Query Locator SOQL Query: '+ query); 
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<Contact_Dashboard_Access__c> cdaList) {
        
        try {
            
            if(!payingAccountTypeSet.isEmpty()){
                processBatch(cdaList, payingAccountTypeSet, 'Paying');
            }
            
            if(!basicAccountTypeSet.isEmpty()){
                processBatch(cdaList, basicAccountTypeSet, 'Basic');
            }
            
        } catch (Exception e) {
            System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
            throw e;
        }
    }

    public void execute(SchedulableContext sc) {        
        Database.executeBatch(new Batch_MonthlyStatsEmailData());
    }              
    
    global void finish(Database.BatchableContext BC) {

        Date myDate = system.today();
        Date cutOffdate = myDate.addDays(-1);
        
        List<AsyncApexJob> failedBatchList = [SELECT Id, Status, NumberOfErrors
                                              FROM AsyncApexJob WHERE ApexClass.name = 'Batch_MonthlyStatsEmailData' 
                                              AND CompletedDate >= : cutOffdate ORDER BY CompletedDate DESC];
        
        //there might be more accounts to process because of ROW LOCK ERRORS so go ahead and send them to Batch again
        if(failedBatchList.size() > 0 && !Test.isRunningTest() && 
           failedBatchList[0].Status == 'Completed' && failedBatchList[0].NumberOfErrors > 0){
               Batch_MonthlyStatsEmailData batch_msed = new Batch_MonthlyStatsEmailData();
               database.executeBatch(batch_msed, 5);
        }

    }
    
    private void processBatch(List<Contact_Dashboard_Access__c> cdaList, Set<String> statsCategorySet, String StatsCategory) { 
        
        Set<String> emails = new Set<String>(); 
        Set<String> existingEmails = new Set<String>();
        Set<Id> accountIds = new Set<id>();
        List<Monthly_Stats_Listings_Email_Data__c > insMSEDList = new List<Monthly_Stats_Listings_Email_Data__c >();
        Map<string, Map<id, set<id>>> emailUpAndAcctMap = new map<string, map<id, set<id>>>();
        Map<id, Account> upIdAcctMap = new Map<id, Account>();
        
        for (Contact_Dashboard_Access__c cda : cdaList) {
            emails.add(cda.Email__c);
        }

        List<Monthly_Stats_Listings_Email_Data__c> MSEDList = [
            SELECT Id, Name, Stats_Category__c FROM Monthly_Stats_Listings_Email_Data__c  
            WHERE createdDate = THIS_MONTH AND name IN : emails AND Stats_Category__c =:  StatsCategory
        ];
        
        if(MSEDList.size() > 0) {
            for(Monthly_Stats_Listings_Email_Data__c  msed : MSEDList){
                existingEmails.add(msed.Name);
            }
            if(existingEmails.size() > 0){
                emails.removeAll(existingEmails);
            }
        }
        
        for (Contact_Dashboard_Access__c cda : [SELECT Id, Account__c, Email__c,  Account__r.Owner.Id,
                                                Account__r.Name, Account__r.Id, Account__r.OwnerId, Account__r.Owner.Email,
                                                Account__r.BillingCountryCode, Account__r.Owner.Extension, Account__r.Type,
                                                Account__r.Ultimate_Parent_Account__r.Id,
                                                Account__r.Ultimate_Parent_Account__r.Name,
                                                Account__r.Ultimate_Parent_Account__r.OwnerId, 
                                                Account__r.Ultimate_Parent_Account__r.Owner.Email, 
                                                Account__r.Ultimate_Parent_Account__r.BillingCountryCode,
                                                Account__r.Ultimate_Parent_Account__r.Owner.Extension
                                                FROM Contact_Dashboard_Access__c WHERE Email__c IN : emails AND status__c = true
                                                AND Account__c IN (SELECT Account__c FROM Account_History_Snapshot__c WHERE
                                                                   Snapshot_Date__c = LAST_MONTH AND Account__r.Type IN : statsCategorySet)]){
                                                                       
			accountIds.add(cda.Account__c);
                                                        
            if(!emailUpAndAcctMap.containsKey(cda.Email__c)) {
	        	emailUpAndAcctMap.put(cda.Email__c, new map<id, set<id>>());
            }
                                                                       
			if(cda.Account__r.ultimate_Parent_Account__c != null){                                
				if(!emailUpAndAcctMap.get(cda.Email__c).containsKey(cda.Account__r.ultimate_Parent_Account__c)) {
					emailUpAndAcctMap.get(cda.Email__c).put(cda.Account__r.ultimate_Parent_Account__c, new set<id>());
					upIdAcctMap.put(cda.Account__r.ultimate_Parent_Account__c, cda.Account__r.ultimate_Parent_Account__r);
				}
				emailUpAndAcctMap.get(cda.Email__c).get(cda.Account__r.ultimate_Parent_Account__c).add(cda.Account__c);  
			} else {
				if(!emailUpAndAcctMap.get(cda.Email__c).containsKey(cda.Account__r.ultimate_Parent_Account__c)) {
					emailUpAndAcctMap.get(cda.Email__c).put(cda.Account__c, new set<id>());
					upIdAcctMap.put(cda.Account__c, cda.Account__r);
				}
				emailUpAndAcctMap.get(cda.Email__c).get(cda.Account__c).add(cda.Account__c);                 
			}
                                                                       
		}
        
        
        if (accountIds.isEmpty()) { return; }
        
        String soqlQuery = 'SELECT Id, Name, OwnerId, Owner.Email, Owner.Extension, BillingCountryCode, (SELECT id, '+
            String.join(ahsFields, ', ')+' '+
            ' FROM Account_History_Snapshots__r WHERE Account__r.Type IN : statsCategorySet AND' +
            ' Snapshot_Date__c = LAST_MONTH ORDER BY CreatedDate DESC LIMIT 1 )' +
            ' FROM Account where Id IN : accountIds ';
        
        Map<ID,Account> accountMap = new Map<ID,Account>(
            (List<Account>)Database.query(soqlQuery)
        );
        
        for(string strEmail : emailUpAndAcctMap.keySet()){ 
            Account msedParentAccount;
            Map<id, Set<Id>> upAcctandChildrenMap = new map<id, set<id>>();
            Integer NoOfChildAccts;
            upAcctandChildrenMap = emailUpAndAcctMap.get(strEmail);
            
            for(Id AcctId : upAcctandChildrenMap.keySet()){
                
                Set<Id> accountsToCompileStats = upAcctandChildrenMap.get(AcctId);
                NoOfChildAccts = accountsToCompileStats.size();
                msedParentAccount = upIdAcctMap.get(AcctId);    

                if(NoOfChildAccts > 10) {
					insMSEDList.add(compileMSED(msedParentAccount, accountsToCompileStats, accountMap, strEmail, StatsCategory, true));
                } else {
                    for(Id accountId : accountsToCompileStats){
                        Account parentAccount = accountMap.get(accountId);
                        Set<Id> accountToCompileStats = new Set<id>();
                        accountToCompileStats.add(accountId);
						insMSEDList.add(compileMSED(parentAccount, accountToCompileStats, accountMap, strEmail, StatsCategory, false));                        
                    }
				}
            }  
        } 
        if(!insMSEDList.isEmpty()){ insert insMSEDList;}        
    }
    
    public static Monthly_Stats_Listings_Email_Data__c compileMSED (Account parentAccount, Set<Id> acctIdSet, 
                                                                          Map<Id,Account> accountMap, String listingEmail,
                                                                          String statsCategory, Boolean aggregatedMetricsFlag){
                                                                              
        Monthly_Stats_Listings_Email_Data__c  newMSED = new Monthly_Stats_Listings_Email_Data__c ();                
        Decimal fldValue;
		Set<String> accountNameSet;   
        String accountNames;
        newMSED.Stats_Category__c = statsCategory;
        newMSED.Name = listingEmail;
        newMSED.Account__c = parentAccount.Id;
        newMSED.Account_Owner_Email__c = parentAccount.Owner.email;
        newMSED.Account_Owner_Extension__c = parentAccount.Owner.Extension;
        newMSED.Account_Billing_Country_Code__c = parentAccount.BillingCountryCode;
        newMSED.Account_Name__c = parentAccount.Name;
        newMSED.OwnerId = parentAccount.OwnerId;
		newMSED.Are_Metrics_Aggregated__c = aggregatedMetricsFlag;                                                                              

			for (String accField : ahsFields) {
				for(Id accId : acctIdSet){                
					if(accountMap.get(accId).Account_History_Snapshots__r.size() > 0 &&
						accountMap.get(accId).Account_History_Snapshots__r[0].get(accField) != null){

                        if(accountNames == null) {
                            accountNames = accountMap.get(accId).Name;                                      
                        } else {
                            accountNames += ',' + accountMap.get(accId).Name; 
                        }

	                    if(fldValue == null ){
							fldValue = (Decimal)accountMap.get(accId).Account_History_Snapshots__r[0].get(accField);
						} else {
							fldValue += (Decimal)accountMap.get(accId).Account_History_Snapshots__r[0].get(accField);
						}
					}
				}
				newMSED.put(accField, fldValue);                 
				fldValue = null;                       
			}
			
            accountNameSet = new Set<String>(new List<String>(accountNames.split(',')));
			accountNames = null;
            accountNames = String.join((Iterable<String>)accountNameSet, ',');                                                                              
			newMSED.Accounts_Included_for_Metrics__c = accountNames;
    	    return newMSED;
    }
}
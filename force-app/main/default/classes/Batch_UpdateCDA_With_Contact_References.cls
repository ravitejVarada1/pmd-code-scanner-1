public class Batch_UpdateCDA_With_Contact_References implements Database.Batchable<sObject>{
	    private Set<Id> queryIds;
	    List<Contact_Dashboard_Access__c> updateCDAList = new List<Contact_Dashboard_Access__c>();	  
	    Map<String,List<Contact>> emailContactsMap = new Map<String,List<Contact>>();
	    Map<Id,List<Contact>> acctIdContactsMap = new map<Id,List<Contact>>();
	    Map<Id,List<Contact_Dashboard_Access__c>> acctIdCDAMap = new map<Id,List<Contact_Dashboard_Access__c>>();    
	    Map<String,Contact_Dashboard_Access__c> emailCDAMap = new Map<String,Contact_Dashboard_Access__c>();
	    List<Contact> contactList = new List<Contact>();
	    List<Contact_Dashboard_Access__c> cdaList = new List<Contact_Dashboard_Access__c>();
	    Set<Id> accountIdSet = new Set<Id>();
    
	    public Batch_UpdateCDA_With_Contact_References() {}
    
	    public Batch_UpdateCDA_With_Contact_References(Id queryId) {
	        this.queryIds = new Set<Id>{queryId};
        } 
    
	    public Batch_UpdateCDA_With_Contact_References(Set<ID> queryIds) { 
	        this.queryIds = queryIds;
	    }    
    
        /*
            We Query all accounts with their Contacts and Contact Dashboard Access records
        */ 
    
    
        public Database.QueryLocator start (Database.BatchableContext context) {
            String query = 'SELECT Id FROM Account WHERE RecordType.DeveloperName NOT IN (\'PersonAccount\')	' +
                'AND Product_Activation_Status__c NOT IN ' +
                '(\'Blocked\', \'No Inventory\')';	    
            if (queryIds != null) {
                query +=   ' AND Id IN : queryIds ORDER BY Id';		
            } else {
                query +=   ' ORDER BY Id';
            }   
            
            system.debug('Update CDA query >> ' + query);
            
            return Database.getQueryLocator(query);            
        }
    
    
	    public void execute(Database.BatchableContext BC, List<Account> acctList) {
        
	        if(!acctList.isEmpty()){          
                for(Account account : acctList){
                    accountIdSet.add(account.Id);
                }
            
                contactList = [SELECT Id, AccountId, Lastname, Email FROM Contact WHERE 
                               Shared_Email__c != true AND AccountId != null AND
                               Status__c  = 'Active' AND Email != null AND AccountId IN : accountIdSet];
                
                for(Contact existingContact : contactList){
                    if(!acctIdContactsMap.containsKey(existingContact.AccountId)){
                        acctIdContactsMap.put(existingContact.AccountId, new List<Contact>());
                    }                            
                    acctIdContactsMap.get(existingContact.AccountId).add(existingContact);
                }
            
                cdaList = [SELECT Id, First_Name__c, Last_Name__c, Email__c, CG_Role__c, 
                           Associated_Service_Providers__c, Status__c, Unique_Key__c, 
                           Account__c, Contact__c FROM Contact_Dashboard_Access__c WHERE
                           Status__c = true AND Account__c IN : accountIdSet];   
                
                for(Contact_Dashboard_Access__c existingCDA : cdaList){
                    if(!acctIdCDAMap.containsKey(existingCDA.Account__c)){
                        acctIdCDAMap.put(existingCDA.Account__c, new List<Contact_Dashboard_Access__c>());
                    }
                    acctIdCDAMap.get(existingCDA.Account__c).add(existingCDA);
                }
            
                for(Account acct : acctList){
                    system.debug('AccountId >> ' + acct.Id);
                    if(acctIdContactsMap.containsKey(acct.Id) && acctIdContactsMap.get(acct.Id) != null){	                    
                        for(Contact contact : acctIdContactsMap.get(acct.Id)){
                            string contactEmail = contact.Email;
                            if(!emailContactsMap.containsKey(contactEmail)){	                           
                                emailContactsMap.put(contactEmail, new List<Contact>());
                            }
                            emailContactsMap.get(contactEmail).add(contact);                            
                        }
                    }
                    
                    if(acctIdCDAMap.containsKey(acct.Id) && acctIdCDAMap.get(acct.Id) != null){
                        for(Contact_Dashboard_Access__c cda : acctIdCDAMap.get(acct.Id)){
                            boolean updateFlag = false;
                            string cdaEmail = cda.Email__c;
                            if(emailContactsMap.containsKey(cdaEmail)){
                                Integer numberOfContacts = emailContactsMap.get(cdaEmail).size();
                                List<Contact> contactList = emailContactsMap.get(cdaEmail);
                                if(emailContactsMap.containsKey(cdaEmail) && numberOfContacts == 1 &&
                                    (contactList[0].get('AccountId') == cda.Account__c)){
                                        cda.Contact__c = contactList[0].Id;
                                        updateFlag = true;
                                    } else {
                                        cda.Contact__c = null;
                                        updateFlag = true;
                                    }
                                if(updateFlag){
                                    updateCDAList.add(cda);
                                }
                            }
                        } 
                    }
                }
	        }
            if(!updateCDAList.isEmpty()){
                update updateCDAList;
            }
    }
    
    public void finish(Database.BatchableContext BC) { }                                             
}
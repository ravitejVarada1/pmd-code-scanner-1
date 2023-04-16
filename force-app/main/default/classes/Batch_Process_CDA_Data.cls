public class Batch_Process_CDA_Data implements Database.Batchable<sObject>, Schedulable{
            
        private Set<Id> queryIds;
    
        public Batch_Process_CDA_Data() {}
    
        public Batch_Process_CDA_Data(Id queryId) {
            this.queryIds = new Set<Id>{queryId};
        } 
        
        public Batch_Process_CDA_Data(Set<ID> queryIds) { 
            this.queryIds = queryIds;
        }    
    
    	/*
    		We Query all accounts which are not PersonAccounts without Product Activation Status Blocked and No Inventory.
    	*/ 
    
        public Database.QueryLocator start (Database.BatchableContext context) {
            String query = 'SELECT Id, Name ' +
                		   'FROM Account WHERE RecordType.DeveloperName NOT IN (\'PersonAccount\')	' +
                		   'AND Product_Activation_Status__c NOT IN ' +
					       '(\'Blocked\', \'No Inventory\')';	                
            if (queryIds != null) {
                                query +=   ' AND Id IN : queryIds ORDER BY Id';		
                            } else {
                                query +=   ' ORDER BY Id';
                            }   
            
            system.debug('process cda query >> ' + query);

        	return Database.getQueryLocator(query);            
            //First error: Aggregate query has too many rows for direct assignment, use FOR loop
        }

    	public void execute(Database.BatchableContext BC, List<Account> accountList) {
            /*
            	Below section process each batch of records and forms the collections for further processing.
            */ 
                try {
                    if(!accountList.isEmpty()){    
                        processBatch(accountList);
                    }
                } catch (Exception e) {
                    System.debug('Error: '+'('+e.getStackTraceString()+') '+e.getMessage());
                throw e;
            }
        }

        public void execute(SchedulableContext sc) {        
            Database.executeBatch(new Batch_Process_CDA_Data());
        }        

        public void finish(Database.BatchableContext BC) {  
        
        /*
        	Call a batch after processing CDA to update Contact references on the CDA Object.
			Search Contact object with incoming CDA email, and if the exact match found with 1 record and
			Contacts Account Id is equal to CDA AccountId use that record reference to update in the CDA Object.
		*/            
            Batch_UpdateCDA_With_Contact_References batch_cdaUpdate = new Batch_UpdateCDA_With_Contact_References();
            database.executeBatch(batch_cdaUpdate);            


        }                                                     


        /*
            The following method takes a single batch of Account List and process them.
        */

        private void processBatch(List<Account> accountList) {

            Map<String,Id> spKeyAccountIdMap = new Map<String,Id>();      
            Map<String,List<Contact_Dashboard_Access__c>> spKeyCDAListMap = new Map<String,List<Contact_Dashboard_Access__c>>();
            Map<String,Contact_Dashboard_Access__c> cdaUniqueKeyMap = new Map<String,Contact_Dashboard_Access__c>();    
            Map<String,Contact_Dashboard_Access__c> existingCDAUniqueKeyMap = new Map<String,Contact_Dashboard_Access__c>();   
            Map<String,Service_Provider__c> spkeySPMap = new Map<String,Service_Provider__c>();      
            Map<String,Set<String>> cdaUniqueKeySPIdSetMap = new Map<String,Set<String>>();	
            List<Contact_Dashboard_Access__c> upsertCDAList = new List<Contact_Dashboard_Access__c>();  
            List<Contact> insertContactList = new List<Contact>();
            List<Service_Provider__c> clearCDADataList = new List<Service_Provider__c>(); 
            List<Contact_Dashboard_Access__c> cdaList = new List<Contact_Dashboard_Access__c>();
            List<Service_Provider__c> spList = new List<Service_Provider__c>();
            Set<Id> accountIdSet = new Set<Id>();    
            Set<String> newCDAEmailSet = new Set<String>();

            if(!accountList.isEmpty()){     

                map<Id,Account> accountMap = new map<Id,Account>(accountList);
                accountIdSet = accountMap.keySet();

                cdaList = [SELECT Id, First_Name__c, Last_Name__c, Email__c, CG_Role__c, 
                            Associated_Service_Providers__c, Status__c, Unique_Key__c, 
                            Account__c, Contact__c FROM Contact_Dashboard_Access__c WHERE
                            Account__c IN : accountIdSet];   
                
                if(!cdaList.isEmpty()){
                    for(Contact_Dashboard_Access__c existingCDA : cdaList){
                        /*
                            Form Existing CDA data with CDA Keys 
                            existingCDAKey = AccountId + '_' + existingCDA.Email__c.toLowerCase();
                        */
                        if(existingCDA.Email__c.Contains('@')){
                            String existingCDAKey = existingCDA.Account__c+'_'+existingCDA.Email__c.toLowerCase();
                            existingCDAUniqueKeyMap.put(existingCDAKey, existingCDA);
                        }
                    }
                }
                

                spList = [SELECT Id, Account__c, Unique_Id__c, Contact_Dashboard_Access_Data__c, 
                            service_provider_id__c FROM Service_Provider__c WHERE Account__c IN : accountIdSet];

                if(!spList.isEmpty()){
                    for(Service_Provider__c sp : spList){
                        if(sp.Contact_Dashboard_Access_Data__c != null){
                            String spId 	= String.valueOf(sp.service_provider_id__c);
                            Id acctId 		= sp.Account__c;
                            String spKey    = sp.Unique_Id__c;
                            
                            spKeyAccountIdMap.put(spKey, acctId);
                            CDA_JSON_Parser parsedRec = CDA_JSON_Parser.parse(sp.Contact_Dashboard_Access_Data__c);
                            
                            spKeyCDAListMap.put(spKey, setupContactDashboardAccessList(parsedRec,spId));
                            spkeySPMap.put(spKey, sp);
                            sp.Contact_Dashboard_Access_Data__c = null;
                            
                            /*
                                We have nulled the Contact_Dashboard_Access_Data__c field data and added 
                                to the below list for final DML Update, so that, soon after we complete 
                                processing we are removing it from Service_Provider__c object.
                            */
                            clearCDADataList.add(sp);
                            
                        }
                    }     
                }

                Set<String> cdaEmailSet = new Set<String>();

                for (String spKey : spKeyCDAListMap.keySet()) {
                    Id accountId = spKeyAccountIdMap.get(spKey);
                    String spId = String.valueOf(spkeySPMap.get(spKey).service_provider_id__c);
                    if(spKeyCDAListMap.get(spKey) != null){
                        for (Contact_Dashboard_Access__c cda : spKeyCDAListMap.get(spKey)) {
                            if(cda.Email__c.Contains('@')){
                                String cdaKey = accountId+'_'+cda.Email__c.toLowerCase();
                                if (!cdaUniqueKeySPIdSetMap.containsKey(cdaKey)) {
                                    cdaUniqueKeySPIdSetMap.put(cdaKey, new Set<String>());
                                }

                                cdaUniqueKeySPIdSetMap.get(cdaKey).add(spId);
                                cda.Associated_Service_Providers__c = 
                                    String.join((Iterable<String>)cdaUniqueKeySPIdSetMap.get(cdaKey), ';');
                                cda.Account__c = accountId;
                                cda.Unique_Key__c = cdaKey;
                                cdaUniqueKeyMap.put(cdaKey, cda);
                                cdaEmailSet.add(cda.Email__c);
                            }
                        }
                    }
                }    

                List<Contact> dupesContactList = [SELECT Id, AccountId, Lastname, Email FROM Contact  
                                WHERE Email != null AND Email IN :cdaEmailSet];

                Set<String> dupeContactEmailSet = new  Set<String>();
                for(Contact ct : dupesContactList) {
                    dupeContactEmailSet.add(ct.Email.toLowerCase());
                }
                
                for (String cdaKey : cdaUniqueKeyMap.keySet()){
                    Contact_Dashboard_Access__c tempCDA 	= cdaUniqueKeyMap.get(cdaKey);
                    Contact_Dashboard_Access__c existingCDA = existingCDAUniqueKeyMap.get(cdaKey);
           
                    /*
                        Check to see if Contact exist with the incoming email, if not
                        create a Contact object and add to insertlist.
                    */ 

                    if(!dupeContactEmailSet.contains(tempCDA.Email__c.toLowerCase()) 
                      	&& (!newCDAEmailSet.contains(tempCDA.Email__c.toLowerCase()))) {
                        insertContactList.add(
                            new Contact(
                                FirstName					= tempCDA.First_Name__c != null ? (String)tempCDA.First_Name__c : 'No CDA FirstName', 
                                LastName					= tempCDA.Last_Name__c != null ? (String)tempCDA.Last_Name__c : 'No CDA LastName', 
                                Email						= tempCDA.Email__c,
                                AccountId					= tempCDA.Account__c,
                                Description					= 'This Contact has been created via CDA automation on : ' + system.now(),
                                Status__c 					= 'Active',
                                Contact_Created_with_CDA__c = true                                
                            )
                        );   
	                    newCDAEmailSet.add(tempCDA.Email__c.toLowerCase());                                 
                    }
                    
                    /*
                        If incoming CDA key doesn't exist in existing CDA Keys
                        that means, there is no CDA with that unique key and add it 
                        to upsert list and Continue
                    */

                    if(!existingCDAUniqueKeyMap.containsKey(cdaKey)){
                        upsertCDAList.add(tempCDA);
                        continue;
                    }
                    

                    /*
                        values from incoming CDA and existing CDA are different,
                        so the incoming data takes the precedence, hence set the id
                        of existingCDA to tempCDA add to upsertList and Continue.
                        If both incoming CDA and existing CDA are same, no action
                        required and remove from existingCDA map as further processing
                        needed.
                    */     

                    if(fieldsDiffer(tempCDA, existingCDA)) {
                        tempCDA.Id = existingCDA.Id;
                        if(!upsertCDAList.contains(tempCDA)){
                            upsertCDAList.add(tempCDA);
                        }
                    }
                    existingCDAUniqueKeyMap.remove(cdaKey);                    
                }
                
                /*
                    All the remaining CDA records from existing CDA should be set to
                    inactive and remove values from Associated Service Providers and Contact field.
                */

                if(!existingCDAUniqueKeyMap.isEmpty()){                
                    for (String cdaKey : existingCDAUniqueKeyMap.keySet()){
                        Contact_Dashboard_Access__c existingCDA = existingCDAUniqueKeyMap.get(cdaKey);
                        existingCDA.Associated_Service_Providers__c = null;
                        existingCDA.Status__c = false;
                        existingCDA.Contact__c = null;
                        upsertCDAList.add(existingCDA);
                    }
                }
            }       

            if(!upsertCDAList.isEmpty()){
                upsert upsertCDAList;
            }
            
            if(!clearCDADataList.isEmpty()){
                update clearCDADataList;
            }
            
            if(!insertContactList.isEmpty()){
                insert insertContactList;
            }    

        }
    	/*
			The following method takes both the source and target maps for each CDA record and return boolean
    	*/
    
        public static Boolean fieldsDiffer(Contact_Dashboard_Access__c tempCDA, Contact_Dashboard_Access__c existingCDA) {
			Map<String,Object> sourceMap = tempCDA.getPopulatedFieldsAsMap();
            Map<String,Object> targetMap = existingCDA.getPopulatedFieldsAsMap();
			Boolean associatedSPFlag = false; 
                
            for (String compareField : sourceMap.keySet()) {

                if (compareField == 'Associated_Service_Providers__c') {
                    
                    Set<String> tempSPIdSet 	= new Set<String>();
                    Set<String> existingSPIdsSet 	= new Set<String>();
                    
                    if(tempCDA.Associated_Service_Providers__c != null){ 
	                    String tempSPIds 		= tempCDA.Associated_Service_Providers__c;                        
                        tempSPIdSet = new Set<String>(tempSPIds.split(';'));
                    }
                    
                    if(existingCDA.Associated_Service_Providers__c != null){ 
	                    String existingSPIds 	= existingCDA.Associated_Service_Providers__c;
                        existingSPIdsSet = new Set<String>(existingSPIds.split(';'));
                    }

                    if(!existingSPIdsSet.equals(tempSPIdSet)){
						associatedSPFlag = true;
                    } else {
                        associatedSPFlag = false;
                    }                     
                }

                if (sourceMap.get(compareField) != targetMap.get(compareField) || (associatedSPFlag)) {
                    System.debug('fieldsDiffer: '+compareField+' - '+sourceMap.get(compareField)+' vs. '+
                                 targetMap.get(compareField));
                    return true;
                }
            }
            return false;
        }    
    
    	/*
    		Below method compiles Contact Dashboard Access records from associatedEmails JSON block, that
			is dropped on the service provider object by Boomi. There will be many Contact Dashboard Access records
			for a single SP record.
    	*/ 

        public static List<Contact_Dashboard_Access__c> setupContactDashboardAccessList(CDA_JSON_Parser parsedRec, String serviceProviderId) {
            List<Contact_Dashboard_Access__c> returnList = new List<Contact_Dashboard_Access__c>();
    
            if (parsedRec.associatedEmails == null) {
                return returnList;
            }
            
            for (CDA_JSON_Parser.AssociatedEmails cdaEmail : parsedRec.associatedEmails) {
                String cgRoleString = String.join((Iterable<String>)cdaEmail.roles, ', ');
                returnList.add(
                    new Contact_Dashboard_Access__c(
                        CG_Person_Id__c = cdaEmail.personId,
                        First_Name__c = cdaEmail.firstName,
                        Last_Name__c = cdaEmail.lastName,
                        Email__c = cdaEmail.email,
                        CG_Role__c = cgRoleString,
                        Associated_Service_Providers__c = serviceProviderId,
                        Status__c = true
                    )
                );
            }
    
            return returnList;
        }

}
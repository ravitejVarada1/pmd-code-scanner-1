/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         bthalvayapati
* modifiedBy:     bthalvayapati
* created:        06/10/2021
* modified:       06/14/2021
* created jira:   BR-1386
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class LeadTriggerFunctions {

    /**
    * When a new lead is created or updated, based on the Lead's email find a corresponding Contact 
    * with the same email, Contact parent Account and the service provider and populate 
    * on the lead. If an account has multiple service providers associated with it, bring the one 
    * that has the Dealer Type = 'Used'.
    * 
    * @author   Bhaskar Thalvayapati
    * @date     06/10/2021
    * @module   BR-1386 : Lead Data Elements - Lead Account, Parent Contact and Service Provider
    */

    public static void populateAcctContactSpRefFields(List<Lead> newLeads) {

        Set<String> leadEmails = new Set<String>();
        Set<Id> acctIds = new Set<Id>();
        Set<String> duplicateContactEmails = new Set<String>();
        List<Contact> matchedContactList = new List<Contact>();
        Map<String,List<Lead>> emailToLeadMap = new Map<String,List<Lead>>();
        Map<String,Contact> emailToContactMap = new Map<String,Contact>();
        Map<Id,Id> acctIdToSpIdMap = new Map<Id,Id>();

        /* 
         * loop through leads in passed trigger scope and form a map
         * with lead emails to Leads.
        */ 
        
        for (Lead newLead : newLeads) {

            String newLeadEmail = newLead.Email;
            
            if(newLeadEmail != null){
				leadEmails.add(newLeadEmail);                

                if (!emailToLeadMap.containsKey(newLeadEmail)) {
                    emailToLeadMap.put(newLeadEmail, new List<Lead>());
                }
				emailToLeadMap.get(newLeadEmail).add(newLead);       
            }
        }   

        if (leadEmails.isEmpty()) return;
        
		/*
		 * Query contacts that matches the lead email. From those contacts, if
		 * there is more than one instance with the same email id mark it as 
		 * duplicate contact email. If there is only one email match to the contact
		 * form a map with contact email and contact
        */

        matchedContactList = [SELECT Id, Email, AccountId, Account.Name FROM Contact 
                              WHERE Email IN : leadEmails];
            
        if (matchedContactList.isEmpty()) return;

        for (Contact matchedContact : matchedContactList) {
            String matchedContactEmail = matchedContact.Email;
            
            if (!emailToContactMap.containsKey(matchedContactEmail)) {
                //The following condition is to make sure matched contact is not an orphan
                if (matchedContact.Account != null) {                
	                emailToContactMap.put(matchedContactEmail, matchedContact);
                    acctIds.add(matchedContact.AccountId);
                }    
            } else {
                duplicateContactEmails.add(matchedContactEmail);
            }
        }

        /*
         * All the duplicate matched contacts and the corresponding leads are 
         * removed from the maps from further processing. We will present duplicate
         * matches Skuid page and based on the user selection, we will bring Account
         * and Contact back into Lead object. 
        */
        
        if(!duplicateContactEmails.isEmpty()){
            emailToLeadMap.keySet().removeAll(duplicateContactEmails);
            emailToContactMap.keySet().removeAll(duplicateContactEmails);        
        }            
        
        /*
         * we may sometimes have orphan contacts in the system and it is
         * necessary to check acctIds set is not before we query  
        */
        
        if (acctIds.isEmpty()) return;
        
        for (Account matchedAccount : [SELECT Id, Name, (SELECT Id, Dealer_Type__c FROM Service_Provider__r 
                                                  WHERE reviewStatus__c = 'APPROVED') 
                                       FROM Account WHERE Id IN : acctIds]) {
                                           
			if (matchedAccount.Service_Provider__r.size() != 0) {     
                system.debug('matchedAccountName >> ' + matchedAccount.Name);
                system.debug('matchedAccount spList Size >> ' + matchedAccount.Service_Provider__r.size());
	            if (matchedAccount.Service_Provider__r.size() == 1) {                                                      
	                acctIdToSpIdMap.put(matchedAccount.Id,matchedAccount.Service_Provider__r[0].Id);
				} else if (matchedAccount.Service_Provider__r.size() > 1) {
					for (Service_Provider__c serviceProvider : matchedAccount.Service_Provider__r){
                        if (serviceProvider.Dealer_Type__c == 'Used') {
                            if (!acctIdToSpIdMap.containsKey(matchedAccount.Id)) {
                                acctIdToSpIdMap.put(matchedAccount.Id,serviceProvider.Id);
                                break;
                            }
                        }
					}                
				}	 
			}
		}

        for (String leadEmail : emailToLeadMap.keySet()) {
            for (Lead lead : emailToLeadMap.get(leadEmail)) {
                
                if (emailToContactMap.containsKey(leadEmail)) {
                    Id contactId = emailToContactMap.get(leadEmail).Id;
                    Id accountId = emailToContactMap.get(leadEmail).AccountId;			
       
                    lead.Parent_Contact__c = contactId;                        
                    lead.Lead_Account__c = accountId;
                    lead.Company = emailToContactMap.get(leadEmail).Account.Name;

                    Id serviceProviderId = acctIdToSpIdMap.get(accountId);   
                    if(serviceProviderId != null) {
                        lead.Service_Provider__c = serviceProviderId;
                    }
                }
            }
        }        
    }
    
    /* When a new Lead records with CarGurus Tracking Id are inserted process
     * should create a new Campaign if one does not exist with that 
     * tracking Id and associate a Lead as campaign Member. If there 
     * is a Campaign already, it should simply associate a Lead to
     * Campaign as a member.
    */     

    public static void upsertCampaigns(List<Lead> leadList) {
		Set<String> carGurusTrackingIds = new Set<String>();
		Map<Id,String> leadCampaignMap = new Map<Id,String>();

		for(Lead l : leadList){
            if (!l.IsConverted && !l.Status.startsWith('Closed') && l.CarGurus_Tracking_Id__c != null) {
                for (String s : l.CarGurus_Tracking_Id__c.split(',')) {
                    carGurusTrackingIds.add(s.trim());
                }
                leadCampaignMap.put(l.Id, l.CarGurus_Tracking_Id__c);
            }
		}

		if (carGurusTrackingIds.isEmpty()) { return; }
        
        Map<String,ID> campaignMap = getCampaignMap(carGurusTrackingIds);
        
        List<CampaignMember> cmList = [select LeadId, CampaignId from CampaignMember 
            where LeadId in : leadCampaignMap.keySet() and CampaignId in : campaignMap.values()];
        
        Set<String> existingCampaignMembers = new Set<String>();
        for (CampaignMember cm : cmList) {
            existingCampaignMembers.add(cm.LeadId+'^'+cm.CampaignId);
        }
        
        cmList = new List<CampaignMember>();
        
        for (Id leadId : leadCampaignMap.keySet()) {
            for (String cgTrackingIds : leadCampaignMap.get(leadId).split(',')) {
                Id campaignId = campaignMap.get(cgTrackingIds.trim().toLowerCase());
                String cmString = leadId+'^'+campaignId;
                if (!existingCampaignMembers.contains(cmString)) {
                    cmList.add(new CampaignMember(LeadId=leadId,CampaignId=campaignId));
                    existingCampaignMembers.add(cmString);
                }
            }
        }
        
        if (!cmList.isEmpty()) {
            try {
                insert cmList;
            } catch (Exception e) {
                System.debug(e.getMessage());
            }
        }
    }

	public static Map<String,ID> getCampaignMap (Set<String> cgTrackingIds) {
		Map<String,ID> campaignMap = new Map<String,ID>();
		List<Campaign> newCampaignList = new List<Campaign>(); 

		for (Campaign c : [SELECT Id, Name from Campaign where Name IN : cgTrackingIds ORDER BY CreatedDate DESC]) {
			campaignMap.put(c.Name.toLowerCase(), c.Id);
		}

		for (String cgTrackingId : cgTrackingIds) {
			if (!campaignMap.containsKey(cgTrackingId.toLowerCase())) {
				newCampaignList.add(new Campaign(Name=cgTrackingId,IsActive=true));
			}
		}
		
		if (newCampaignList.isEmpty()) { return campaignMap; }
		
		insert newCampaignList;
		for (Campaign c : newCampaignList) {
			campaignMap.put(c.Name.toLowerCase(), c.Id);
		}
		
		return campaignMap;
	}
}
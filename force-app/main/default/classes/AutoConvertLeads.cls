/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         bthalvayapati
* modifiedBy:     bthalvayapati
* created:        06/10/2021
* modified:       06/10/2021
* created jira:   BR-2659
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

Public class AutoConvertLeads{
    
    public class ConvertOpptyException extends Exception {}

    @InvocableMethod
    public static void leadAssign(List<Id> leadIds) {

        LeadStatus leadStatus= [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        Map<Id,Lead> leadMap = new Map<Id,Lead>([
            SELECT Id, Parent_Contact__c, Lead_Account__c, Owner.UserRole.DeveloperName, CountryCode
            FROM Lead 
            WHERE Id = :LeadIds]);        

        // Populate new Map with Lead Accounts as values        
        Map<Id,Id> leadIdAccIdMap = new Map<Id,Id> ();
        for (Lead lead : leadMap.values()) {
            leadIdAccIdMap.put(lead.Id, lead.Lead_Account__c);
        }
        
        // Query for Used Inventory Avg on the realted Service Provider
        AggregateResult[] spGroupedResults = [
            SELECT Account__c, Sum(Total_Used_Inventory_Units__c)
            FROM Service_Provider__c
            WHERE Dealer_Type__c = 'Used'            
            AND reviewStatus__c != 'DENIED'
            AND Account__c IN :leadIdAccIdMap.values()
            GROUP BY Account__c
        ];
        
        // Prepare Map with Account and Used Inventory Avg
        Map<String,Decimal> accountInventoryAvg = new Map<String,Decimal> ();
        for (AggregateResult sp : spGroupedResults) {
            accountInventoryAvg.put(String.valueOf(sp.get('Account__c')), Integer.valueOf(sp.get('expr0')));
        }

        Set<String> activeUserRoles = new Set<String> ();
        //Query for active UserRoles on Permissions Settings
        for (Permissions_Settings__mdt userRoleName : [
            SELECT Label, Is_Active__c
            FROM Permissions_Settings__mdt
            WHERE Object__c = 'Lead'
                AND Permission_Type__c = 'ConvertLeadCreateOppty'
                AND Is_Active__c = true
        ]) {
            activeUserRoles.add(userRoleName.Label);
        }
                
        for (Lead lead : leadMap.values()) {

            //BR-4075 - US Inbound Sales team - Lead Conversion Rules
            if (lead.CountryCode == 'US') {
                if (activeUserRoles.contains(lead.Owner.UserRole.DeveloperName)) {
                        if (!accountInventoryAvg.containsKey(lead.Lead_Account__c) ||
                            (accountInventoryAvg.get(lead.Lead_Account__c) <= 10 ||
                              accountInventoryAvg.get(lead.Lead_Account__c) == null)) {
                                continue;
                        } else {
                            throw new ConvertOpptyException('The used car inventory associated to the Account, Service provider is > 10,' +
                            ' please use the Send to Rep button to route the lead to appropriate Sales team member.');
                        }
                }
            }
        }                        

        List<Database.LeadConvert> massLeadconvert = new List<Database.LeadConvert>();
        for(Id currentLead: leadIds){
            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(currentLead);                
            leadConvert.setConvertedStatus(leadStatus.MasterLabel);
            leadConvert.setDoNotCreateOpportunity(true); 
            leadConvert.setContactId(leadMap.get(currentLead).Parent_Contact__c);
            leadConvert.setAccountId(leadMap.get(currentLead).Lead_Account__c);
            massLeadconvert.add(leadConvert); 
            
            if (!massLeadconvert.isEmpty()) {
                List<Database.LeadConvertResult> lcr = Database.convertLead(massLeadconvert);
            }
        }
        
    }
}
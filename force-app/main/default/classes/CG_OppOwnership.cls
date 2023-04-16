public class CG_OppOwnership {

    private static final Id RETENTIONRECORDTYPE = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Retention');
    private static final Id STANDARDRECORDTYPE = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Standard_Opportunity');

    public static void updateOppOwnerToRetention(Map<Id,Opportunity> oppMap, Map<Id,Opportunity> oldOppMap) {

        Set<Id> acctIds = new Set<Id>();
        Set<String> groupNames = new Set<String>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        Set<Id> opptyToProcessIds = new Set<Id> ();

        //collect Opps who turned to Retention record type from Standard record type
        for (Opportunity o : oppMap.values()) {
            Opportunity oldOpp = oldOppMap.get(o.Id);

            if (o.RecordTypeId == RETENTIONRECORDTYPE && oldOpp.RecordTypeId == STANDARDRECORDTYPE) {
                if (o.AccountId != null && !o.Name.contains('Turnkey Cancellation Opp')) {
                    acctIds.add(o.AccountId);
                    opptyToProcessIds.add(o.Id);
                }
            }
        }

        //return if no opps fit this criteria
        if (acctIds.isEmpty()) { return; }

        //query account info to see who owns the account and what country they are in
        //BR-8686 Add subquery to get open retention opps
        Map<Id,Account> accountMap = new Map<Id,Account>(
                [SELECT Id, OwnerId, Owner.UserRole.Name, BillingCountryCode, Owner.UserRoleId, Ultimate_Parent_Account__c,
                    Account_Category__c,
                    (SELECT Id, IsClosed, RecordTypeId, OwnerID
                    FROM Opportunities
                    WHERE RecordTypeId = :RETENTIONRECORDTYPE AND IsClosed = false
                    ORDER BY CreatedDate DESC
                    LIMIT 1)
                FROM Account 
                WHERE Id IN :acctIds
                OR ParentId IN :acctIds
                OR Ultimate_Parent_Account__c IN :acctIds]
        );

        //BR-8686 Populate map with Ultimate Parent Account and Owner of open retention opps
        Map<Id,Id> ultimateAccountOwnerIdMap = new Map<Id,Id> ();
        for (Account acc : accountMap.values()) {
            if (!acc.Opportunities.isEmpty()) {
                ultimateAccountOwnerIdMap.put(acc.Ultimate_Parent_Account__c == null ? acc.Id : acc.Ultimate_Parent_Account__c, acc.Opportunities[0].OwnerId);
            }
        }

        Map<String,List<Opportunity>> roundRobinOpps = new Map<String,List<Opportunity>>();

        //loop through and assign field reps to the opp owner, otherwise divide up opps by country
        for (Id oppId : opptyToProcessIds) {

            Opportunity o = oppMap.get(oppId);
            Account a = accountMap.get(o.AccountId);
            // Get Account category, set default to Indy if blank
            String accCategory = a.Account_Category__c != null ?
                (a.Account_Category__c.containsIgnoreCase('Independent') ? 'Independent' : 'Franchise') : 'Independent';

            String ultimateAccountId = a.Ultimate_Parent_Account__c == null ? a.Id : a.Ultimate_Parent_Account__c;
            //BR-8686 If there is an open retention opp set same user as owner
            if (ultimateAccountOwnerIdMap.containsKey(ultimateAccountId)) {
                o.OwnerId = ultimateAccountOwnerIdMap.get(ultimateAccountId);
            } else {
                String groupKey = 'Retention_' + a.BillingCountryCode + '_' + accCategory;
                if (!roundRobinOpps.containsKey(groupKey)) {
                    roundRobinOpps.put(groupKey, new List<Opportunity>());
                }
                roundRobinOpps.get(groupKey).add(o);
                groupNames.add(groupKey);
            }
        }

        Map<String, List<Round_Robin_User__c>> roundRobinUserMap = new Map<String, List<Round_Robin_User__c>>(); 
        List<Round_Robin_User__c> rrUsersToUpdate = new List<Round_Robin_User__c>();

        //if we have opps to round robin, we collect the users per public group (which is divided by country)
        if (!roundRobinOpps.isEmpty()) {
            roundRobinUserMap = RoundRobinUserHelper.getSortedRoundRobinUserMap(groupNames);
        } else { 
            return; 
        }

        //loop through each country's worth of Opps and assign owners via round robin
        for (String groupName : roundRobinOpps.keySet()) {
            
            if (groupNames.contains(groupName)) {
                List<Opportunity> opps = roundRobinOpps.get(groupName);
                List<Round_Robin_User__c> rrUsers = roundRobinUserMap.get(groupName);

                RoundRobinUserAssignment rrua = new RoundRobinUserAssignment(opps, rrUsers);
                rrUsersToUpdate.addAll(rrua.roundRobinAssignUser());

                oppsToUpdate.addAll(opps);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            upsert rrUsersToUpdate;
        }
        
    }

}
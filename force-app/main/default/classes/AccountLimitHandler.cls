public class AccountLimitHandler {

    public static void verifyOwnerChange(List<Account> acctList, Map<Id,Account> oldAcctMap) {

        Map<String,Account_Cap__mdt> caps = Utilities.getAccountLimits();

        //only process if trigger is evaluating a single account
        if (acctList.size() == 1) {
            for (Account a : acctList) {

                if (!caps.containsKey(a.BillingCountryCode)) { return; }
                
                Id ownerId = a.OwnerId;
                if (ownerId != oldAcctMap.get(a.Id).OwnerId) {
                    Id upId = a.Is_Ultimate_Parent__c ? a.Id : a.Ultimate_Parent_Account__c;
                    if (allowOwnerChange(ownerId, upId, a.BillingCountryCode)) {
                        return;
                    } else {
                        a.addError('You have hit the Account limit for this Owner Id: ' + ownerId);
                    }
                }
            }
        }

    }

    //assume that the acctId being passed in is the Ultimate Parent
    public static boolean allowOwnerChange(Id userId, Id acctId, String region) {

        Map<String,Account_Cap__mdt> caps = Utilities.getAccountLimits();

        Account_Cap__mdt acctCap = caps.get(region);
        Boolean countAllDealerAccount = acctCap.Count_For_Groups__c == 'Every Dealer Account';
        Set<String> acqRoleIds = new Set<String>(acctCap.Acquisition_Role_Ids__c.split(','));

        User u = [SELECT Id, UserRoleId FROM User WHERE Id =: userId limit 1];
        Boolean isAcqUser = acqRoleIds.contains((String)u.UserRoleId); //filter for Sales Users somehow

        if (isAcqUser) {

            String dynamicQuery = 'SELECT Count() FROM Account WHERE OwnerId =: userId';
            if (countAllDealerAccount) {
                dynamicQuery += ' AND RecordType.Name = \'Dealer Account\'';
            } else {
                dynamicQuery += ' AND Is_Ultimate_Parent__c = true';
            }

            //perform count query
            Integer currNumAccounts = Database.countQuery(dynamicQuery);

            //return false if they are at or over account cap
            if (currNumAccounts >= acctCap.Cap__c) {
                return false;
            }

            //query new account group
            Account[] incomingAcctGroup = [SELECT Id, RecordType.Name FROM Account WHERE Id =: acctId OR Ultimate_Parent_Account__c =: acctId];

            Integer incomingAcctGroupCount = 0;

            //count num accounts with incoming account (will be 1 if only counting UPs)
            if (countAllDealerAccount) {
                for (Account a : incomingAcctGroup) {
                    if (a.RecordType.Name == 'Dealer Account') {
                        incomingAcctGroupCount += 1;
                    }
                }
            } else {
                incomingAcctGroupCount = 1;
            }

            //check to see if new account/group being added is greater than cap
            if (currNumAccounts + incomingAcctGroupCount > acctCap.Cap__c) {
                return false;
            }
        }

        return true;
    }

}
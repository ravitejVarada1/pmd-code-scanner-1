public class AccountGroupStatisticsCalculator {
    
    // group field name map
    private static Map<String,String> groupFieldNameMap = new Map<String,String>{
                'Group_Total_Locations__c'               => '',
                'Group_Total_Paying_Locations__c'        => 'Type',
                'Group_Total_Used_Inventory_Avg__c'      => 'Used_Inventory_Avg__c',
                'Group_Total_Used_Inventory__c'          => 'Total_Used_Inventory__c',
                'Group_Total_New_Inventory__c'           => 'Total_New_Inventory__c',
                'Group_Total_Open_Opps_Acq__c'           => 'Open_Opps_Owned_By_Acq_SUM__c',
                'Group_Total_Open_Opps_DR__c'            => 'Open_Opps_Owned_By_DR_SUM__c',
                'Group_Total_CMRR__c'                    => 'Total_CMRR__c'
            };

    // group search term map
    private static Map<String,String> groupFieldSearchTermMap = new Map<String,String>{
                'Group_Total_Locations__c'               => '',
                'Group_Total_Paying_Locations__c'        => 'Customer',
                'Group_Total_Used_Inventory_Avg__c'      => '',
                'Group_Total_Used_Inventory__c'          => '',
                'Group_Total_New_Inventory__c'           => ''
            };

    // account to SP map
    private static Map<Id, Id> accountToSPMap = new Map<Id, Id>();

    /**
     * Gets account to SP Map
     *
     * @author: Adam LaPlante
     * @jira: BR-4593
     */

    public static void fillAccountToSPMap(List<Service_Provider__c> serviceProviders) {
        // loop through provided SPs, if approved and associated account doesn't already exist in the map, add it
        for (Service_Provider__c sp : serviceProviders) {
            // if sp status == reviewed and accountsToSPMap doesn't already contain account
            if ((sp.reviewStatus__c == 'APPROVED' || sp.reviewStatus__c == 'SUBMITTED') && !accountToSPMap.keySet().contains(sp.Account__c)){
                accountToSPMap.put(sp.Account__c,sp.Id);
            }
        }
    } 

    /**
     * Fill account to SP Map, loop through accounts, if no active SP for account remove from list
     *
     * @author: Adam LaPlante
     * @jira: BR-4593
     */

    public static List<Account> removeNonActiveSps(List<Account> accounts) {
        List <Service_Provider__c> sps = accounts[0].All_Hierarchy_Service_Providers__r;
        if (sps.size() > 0) {
            fillAccountToSPMap(sps);
            // clone list so it can be modified and returned
            List<Account> accountsToReturn = accounts.clone();
            for (Account account : accounts) {
                if (!accountToSPMap.keySet().contains(account.Id)) {
                    accountsToReturn.remove(accountsToReturn.indexOf(account));
                }
            }
            return accountsToReturn;
        } else {
            return null;
        }
    }

    /**
     * Calculates each individual group field
     *
     * @author: Adam LaPlante
     * @jira: BR-4251
     */

    public static decimal calculateGroupFieldValue(Account account, String groupField, String searchTerm) {
        // initialize variables
        List<Account> accounts = new List<Account>{account};
        String calcField = groupFieldNameMap.get(groupField);
        Decimal sum = 0;

        // if their are children in hierarchy, add them to list for calc
        if (accounts.size() > 0 && account.Accounts_Descendents__r.size() > 0) {
            accounts.addAll(account.Accounts_Descendents__r);
        }

        system.debug('Accounts before removal : ' + accounts);

        // if counting locations, we only want to count accounts with active SPs
        if (accounts.size() > 0 && (searchTerm == null || searchTerm == '')) {
            accounts = removeNonActiveSps(accounts);
        }

        system.debug('Accounts after removal : ' + accounts);

        if (accounts != null && accounts.size() > 0) {
            // loop through account list
            for (Account acc : accounts) {
                // if no search term is provided
                if (searchTerm == null || searchTerm == '') {
                    // if no calc field is provided (just want to count each individual member of hierarchy)
                    if (calcField == null || calcField == '') {
                        sum += 1;
                    // if a calc field is provided, add its value to sum
                    } else {
                        sum += (Decimal) acc.get(calcField) == null ? 0 : (Decimal) acc.get(calcField);
                    }
                // else, if a search term is provided
                } else if (searchTerm != null && searchTerm != '') {
                    // check if field value contains search term, if so increment sum
                    if (((String) acc.get(calcField)) == searchTerm) {
                        sum += 1;   
                    }
                } 
            }
            // return sum of value, if field contains 'avg' convert sum to avg
            return ((groupField.toLowerCase()).contains('avg') ? (sum / accounts.size()) : sum);
        } else {
            return 0;
        }
    }

    /**
     * Takes in a list of accounts, updates their statistics and sumbits to SF
     *
     * @author: Adam LaPlante
     * @jira: BR-4251
     */

    public static void calculateAndUpdateGroupStatistics(List<Account> accounts) {
        // if accounts are provided
        if (accounts.size() > 0) {
            // loop through provided accounts
            for (Account account : accounts) {
                system.debug('Account : ' + account);
                // loop through group fields in group field map
                for (String groupField : groupFieldNameMap.keySet()) {
                    // set group field value based on calculation
                    account.put(groupField, calculateGroupFieldValue(
                        account, 
                        groupField, 
                        groupFieldSearchTermMap.get(groupField)
                    ));
                }
            }
            // try updating accounts, send error email on failure
            try {
                update accounts;
            } catch (DMLException e) {
                //Utilities.sendSimpleErrorEmail('AccountGroupStatisticsCalculator', e.getMessage());
            }
        }
    }

}
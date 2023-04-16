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

public class AccountCategoryCalculator {
    @TestVisible
    private static final String DEALER_TYPE_NEW = 'New';
    @TestVisible
    private static final String DEALER_TYPE_USED = 'Used';
    private static final String DEFAULT_RULE = 'DEFAULT';
    
    private static final Map<String,Map<String,List<Account_Category_Rule__mdt>>> countryToCategoryRulesMap;
    
    static{ 
        countryToCategoryRulesMap = new Map<String,Map<String,List<Account_Category_Rule__mdt>>>();
        
        for (Account_Category_Rule__mdt rule : [SELECT Majority_Dealer_Type__c, Max_Inventory__c, Category__c,
                                                Country_Code__c 
                                                FROM Account_Category_Rule__mdt
                                                ORDER BY Majority_Dealer_Type__c, Max_Inventory__c NULLS LAST])
        {
            String dealerType = rule.Majority_Dealer_Type__c;
            Decimal maxInventory = rule.Max_Inventory__c;
            String category = rule.Category__c;
            String countryCode = rule.Country_Code__c;
            
            if (!countryToCategoryRulesMap.containsKey(countryCode)){
                countryToCategoryRulesMap.put(countryCode, new Map<String,List<Account_Category_Rule__mdt>>());
            }
            
            if (!countryToCategoryRulesMap.get(countryCode).containsKey(dealerType)){
                countryToCategoryRulesMap.get(countryCode).put(dealerType, new List<Account_Category_Rule__mdt>());
            }
            
            countryToCategoryRulesMap.get(countryCode).get(dealerType).add(rule);

        } 
    }
    
    @future
    public static void executeFuture(Set<ID> ultParentAccountsToCheck){
        execute(ultParentAccountsToCheck);
    }
    
    public static void execute(Set<ID> ultParentAccountsToCheck){
        
        if (!System.isBatch() && !System.isFuture()){
            executeFuture(ultParentAccountsToCheck);
            return;
        }
        
        //Get a map of ultimate parent to a spid aggregate result
        Map<ID,AggregateResult> ultParentToSpidAggMap = new Map<ID,AggregateResult>(
            [SELECT Ultimate_Parent_Account__c Id, SUM(Used_Inventory_Avg__c) usedInvAvg
             FROM Service_Provider__c
             WHERE Ultimate_Parent_Account__c != null
             AND Ultimate_Parent_Account__c IN :ultParentAccountsToCheck
             GROUP BY Ultimate_Parent_Account__c]
        );
        
        //Loop through all the accounts and run the checkSpecificUltAccount method on each one,
        //passing in the account and the aggregate result values as needed
        List<Account> ultAccountsToUpdate = new List<Account>();
        for (Account ultA : [SELECT Account_Category__c, Dealer_Type__c, BillingCountryCode,
                             (SELECT Dealer_Type__c
                              FROM Accounts_Descendents__r)
                             FROM Account
                             WHERE Id IN :ultParentAccountsToCheck])
        {
            Account beforeUltA = ultA.clone(true,true,true,true);
            
            AggregateResult ultAggResult = ultParentToSpidAggMap.get(ultA.Id);
            Decimal totalUsedInventory = 0;
            if (ultAggResult != null && (Decimal)ultAggResult.get('usedInvAvg') > 0){
                totalUsedInventory = (Decimal)ultAggResult.get('usedInvAvg');
            }
            
            checkSpecificUltAccount(ultA, totalUsedInventory);
            
            //If the above method changed the account, add the account to the list that gets updated
            if (beforeUltA != ultA){
                ultAccountsToUpdate.add(ultA);
            }
        }
        
        update ultAccountsToUpdate;
    }

    //Check various ult account fields against their feeding values | Jira: BR-367 & BR-368
    @TestVisible
    private static void checkSpecificUltAccount(Account ultA, Decimal totalUsedInventory){
        String dealerType = ultA.Dealer_Type__c;
        Integer newCount  = dealerType == DEALER_TYPE_NEW ? 1 : 0;
        Integer usedCount = dealerType == DEALER_TYPE_USED ? 1 : 0;
        
        //Loop through descendent accounts and count the New vs Used dealers
        for (Account descendent : ultA.Accounts_Descendents__r){            
            String decDealerType = descendent.Dealer_Type__c;
            
            newCount  += decDealerType == DEALER_TYPE_NEW ? 1 : 0;
            usedCount += decDealerType == DEALER_TYPE_USED  ? 1 : 0;
        }
        
        String countryRules = countryToCategoryRulesMap.containsKey(ultA.BillingCountryCode)
            ? ultA.BillingCountryCode
            : DEFAULT_RULE;

        String hierarchyDealerType = usedCount > newCount || (usedCount == 0 && newCount == 0) 
            ? DEALER_TYPE_USED 
            : DEALER_TYPE_NEW;

        //Loop through a list of Account Category Rules for this account's Country and this account's Dealer Type
        //This list is already sorted by Max Inventory
        for (Account_Category_Rule__mdt thisRule : countryToCategoryRulesMap.get(countryRules).get(hierarchyDealerType)){
            Decimal inventoryMax = thisRule.Max_Inventory__c;
            
            if (inventoryMax == null || totalUsedInventory <= inventoryMax){
                ultA.Account_Category__c = thisRule.Category__c;
                break;
            }
        }
    }
}
/**
 * @author      Adam LaPlante
 * @created     09/21/2021
 * @modified    10/07/2021
 */

public class DealerClassification {

    // lists to store classification values
    List<String> franchiseClassifications = new List<String>();
    List<String> independentClassifications = new List<String>();

    // declare maps used to store min / max values
    Map<String, Decimal> independentMinLocationMap = new Map<String,Decimal>();
    Map<String, Decimal> independentMaxLocationMap = new Map<String,Decimal>();

    Map<String, Decimal> independentMinUsedInventoryAvgMap = new Map<String,Decimal>();
    Map<String, Decimal> independentMaxUsedInventoryAvgMap = new Map<String,Decimal>();

    Map<String, Decimal> franchiseMinLocationMap = new Map<String,Decimal>();
    Map<String, Decimal> franchiseMaxLocationMap = new Map<String,Decimal>();

    Map<String, Decimal> franchiseMinUsedInventoryAvgMap = new Map<String,Decimal>();
    Map<String, Decimal> franchiseMaxUsedInventoryAvgMap = new Map<String,Decimal>();

    /**
     * Constructor class, calls populate variables on invocation
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

    public DealerClassification() {
        populateMaps();
    }

    /**
     * Grabs dealer classification record through SOQL, sets dealer classification determination maps
     * with values from record.
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

    public void populateMaps() {

        // SOQL - grab dealer classification metadata objects
        Dealer_Classification__mdt[] dcArray = 
            [
                SELECT Classification_Level__c,
                       Minimum_Total_Locations__c,  
                       Maximum_Total_Locations__c, 
                       Minimum_Used_Inventory_Avg__c,
                       Maximum_Used_Inventory_Avg__c
                FROM Dealer_Classification__mdt
                ORDER BY Classification_Level__c
            ];

        // loop through mdt records, put values into appropriate maps
        for (Dealer_Classification__mdt dc : dcArray) {
            // if mdt record classification contains franchise
            if (dc.Classification_Level__c.contains('Franchise')) {
                franchiseClassifications.add(dc.Classification_Level__c);
                franchiseMinLocationMap.put(dc.Classification_Level__c, dc.Minimum_Total_Locations__c);
                franchiseMaxLocationMap.put(dc.Classification_Level__c, dc.Maximum_Total_Locations__c);
                franchiseMinUsedInventoryAvgMap.put(dc.Classification_Level__c, dc.Minimum_Used_Inventory_Avg__c);
                franchiseMaxUsedInventoryAvgMap.put(dc.Classification_Level__c, dc.Maximum_Used_Inventory_Avg__c);
            // if mdt record classification contains independent
            } else if (dc.Classification_Level__c.contains('Independent')) {
                independentClassifications.add(dc.Classification_Level__c);
                independentMinLocationMap.put(dc.Classification_Level__c, dc.Minimum_Total_Locations__c);
                independentMaxLocationMap.put(dc.Classification_Level__c, dc.Maximum_Total_Locations__c);
                independentMinUsedInventoryAvgMap.put(dc.Classification_Level__c, dc.Minimum_Used_Inventory_Avg__c);
                independentMaxUsedInventoryAvgMap.put(dc.Classification_Level__c, dc.Maximum_Used_Inventory_Avg__c);
            }

        }

    }

    /**
     * Determines if dealer meets criteria for classification value provided. If so, returns true, else false.
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

    public boolean evaluateClass(
            Decimal locs, 
            Decimal inv, 
            Decimal minLocs, 
            Decimal maxLocs, 
            Decimal minInv, 
            Decimal maxInv
        ) 
    {
            // ensure that if there is no maximum set on metadata, set maximum to 1 more than provided values
            maxLocs = maxLocs == null ? (locs + 1) : maxLocs;
            maxInv = maxInv == null ? (inv + 1) : maxInv;

            // do evaluation
            if (
                ((locs >= minLocs && locs <= maxLocs) && 
                (inv >= minInv && inv <= maxInv)) ||
                (locs > maxLocs)
            ) {
                return true;
                
            } else {
                return false;
            }
    }

    /**
     * Takes in group total locations, group average used inv, and category, runs class evaluation,
     * and finally returns back the class designation
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

    public String setDealerClassification(Decimal groupTotalLocations, Decimal groupAverageUsedInventory, String category) {
        String tempLevel = null;
        // if account category contains franchise, run evaluation using franchise maps
        if (category.contains('Franchise')) {
            // iterate through franchiseClassifications list
            for (String franchiseLevel : franchiseClassifications) {
                // run evalute class, if it returns true, return classification
                if ( evaluateClass(
                        groupTotalLocations,
                        groupAverageUsedInventory,
                        franchiseMinLocationMap.get(franchiseLevel),
                        franchiseMaxLocationMap.get(franchiseLevel),
                        franchiseMinUsedInventoryAvgMap.get(franchiseLevel),
                        franchiseMaxUsedInventoryAvgMap.get(franchiseLevel)
                    ) == true ) {
                        tempLevel = franchiseLevel;
                    }
            }
        // if account category contains independent, run evaluation using independent maps
        } else if (category.contains('Independent')) {
            // iterate through independentClassifications list
            for (String independentLevel : independentClassifications) {
                // run evalute class, if it returns true, return classification
                if ( evaluateClass(
                        groupTotalLocations,
                        groupAverageUsedInventory,
                        independentMinLocationMap.get(independentLevel),
                        independentMaxLocationMap.get(independentLevel),
                        independentMinUsedInventoryAvgMap.get(independentLevel),
                        independentMaxUsedInventoryAvgMap.get(independentLevel)
                    ) == true ) {
                    tempLevel = independentLevel;
                }
            }
        }

        // if the account doesn't evaluate to any class, return null
        return tempLevel;
    }

    /**
     * Takes in a list of accounts, for each account determines and 
     * sets 'Dealer_Classification__c' field, returns list of accounts ready to be upserted.
     *
     * If dealer classification does not change, removes from list so dealer does not get 
     * extraneously updated.
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

    public List<Account> classifyDealers(List<Account> accounts) {

        List<Account> accountsToReturn = new List<Account>(); // used to only return accounts that have been modified
        String tempClassification;

        // iterate through provided accounts
        for (Account account : accounts) {
            // get temp classification
            tempClassification = setDealerClassification(
                account.Group_Total_Locations_Formula__c, 
                account.Group_Total_Used_Inventory_Avg_Formula__c, 
                account.Account_Category_Formula__c
            );
            
            // compare current dealer category against temp category to determine if change is needed
            if (tempClassification != null && tempClassification != account.Dealer_Classification__c) {
                // update account classification, add to accountsToReturn
                account.Dealer_Classification__c = tempClassification;
                accountsToReturn.add(account);
            } 
        
        }

        // return account list
        return accountsToReturn;

    }

    /**
     * Returns list of classified dealeres back to caller
     * 
     * @author: Adam LaPlante
     * @jira: BR-4041
     */

    public List<Account> returnClassifiedDealers(List<Account> accounts) {
        // return account to caller
        return classifyDealers(accounts);
    }

}
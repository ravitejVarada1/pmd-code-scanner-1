public class PricingDataTriggerFunctions {
    public static void checkForDuplicates(List <Pricing_Data__c> triggerNew){
        Map<ID, Set<ID>> accountIdToProdIdsMap = new Map <ID, Set<ID>>();
        Set<ID> relatedAccountIds = new Set<ID>();
        List<Pricing_Data__c> pricingDataToCheck = new List<Pricing_Data__c>();
        
        //Gather all the related accountIds from triggerNew's prcing data records
        for (Pricing_Data__c pd : triggerNew){
            if (!pd.Active__c){
                continue;
            }
            relatedAccountIds.add(pd.Account__c); 
            pricingDataToCheck.add(pd);
        }
        
        //Just return if there are no active pricing data records being edited or inserted
        if (pricingDataToCheck.isEmpty()){
            return;
        }
        
        //Loop through all the related accounts, and inner loop through their related
        //active pricing data records, creating a map of accountId to the productIds of all 
        //related active pricing data records
        for (Account a : [SELECT Id, (SELECT Product__c
                                      FROM Pricing_Data__r
                                      WHERE Active__c = true
                                      AND Id NOT IN : triggerNew)
                          FROM Account
                          WHERE Id in :relatedAccountIds])
        {
            
            if (a.Pricing_Data__r.isEmpty()){
                continue;
            }
            
            accountIdToProdIdsMap.put(a.Id, new Set<ID>());
            
            for (Pricing_Data__c pd : a.Pricing_Data__r){
                accountIdToProdIdsMap.get(a.Id).add(pd.Product__c);
            }
        }
        
        //If none of the related accounts have active pricing data records, return
        if (accountIdToProdIdsMap.isempty()){
            return;
        }

        //Get a map of productId to product name - to be used with error message
        Map<ID,String> prodIdToProdNameMap = new Map<ID,String>();
        for (Product2 p : [SELECT Id, Name
                           FROM Product2])
        {
                               prodIdToProdNameMap.put(p.Id, p.Name);
                           }
        
        //Loop through trigger new and check if the productId for each record is contained in
        //the related set of Ids for the related account
        for (Pricing_Data__c pd : pricingDataToCheck){
            if (!pd.Active__c || !accountIdToProdIdsMap.containsKey(pd.Account__c)){
                continue;
            }
            
            if (accountIdToProdIdsMap.get(pd.Account__c).contains(pd.Product__c)){
                pd.addError('There is already an active Pricing Data record for this product - ' + prodIdToProdNameMap.get(pd.Product__c) + ' - on this account');
            }
        }
        
    }
}
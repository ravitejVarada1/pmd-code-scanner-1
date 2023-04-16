/**
* Controller class for Custom Lookup
* @date 	  11/03/2021
* @module   BR-3733
*/

public class CustomLookupController {
    
    private final static Integer MAX_RESULTS = 5;

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchBillingAccounts(String searchTerm, List<String> selectedAccountIds) {
        // Prepare query paramters
        searchTerm += '*';

        // Execute search query
        List<List<SObject>> searchResults = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING
                Account( Id, Name, Billing_Account_Zuora__c,Billing_Account_Zuora__r.Zuora__AccountNumber__c
                    WHERE Id NOT IN :selectedAccountIds
                    AND Billing_Account_Zuora__c != NULL 
                )
            LIMIT :MAX_RESULTS
        ];

        // Prepare results
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        // Extract Accounts & convert them into LookupSearchResult
        String accountIcon = 'standard:account';
        Account[] accounts = (List<Account>) searchResults[0];
        for (Account account : accounts) {
            results.add(
                new LookupSearchResult(
                    account.Id,
                    'Account',
                    accountIcon,
                    account.Name,
                    account.Billing_Account_Zuora__r.Zuora__AccountNumber__c
                )
            );
        }
        for(LookupSearchResult result : results) {
            system.debug(result);
        }
        
        return results;
    
    }
    
}
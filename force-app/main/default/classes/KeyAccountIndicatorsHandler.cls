/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     nfinn
* created:        09/15/2021
* modified:       10/20/2022              
* created jira:   BR-3373
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public class KeyAccountIndicatorsHandler{
    @AuraEnabled
    public static String getKeyAccountIndicators(ID accountId){
        //BR-3373 query for the account passed in from the LWC and all its related accounts
        Map<ID,Account> accountsWithRelated = new Map<ID,Account>(
            [SELECT Id, ZuoraWriteOffBalance__c, Name, Days_Until_Delinquency_Cancellation__c, Code_of_Conduct_Chkbox__c,
                (SELECT Id, Provisioning_Status_Formula__c, Cancellation_Effective_Date__c 
                 FROM CPQ_Subscriptions_Fulfillment__r 
                 WHERE Provisioning_Status_Formula__c = 'Delinquent' OR Cancellation_Effective_Date__c > TODAY),
                 (SELECT Id, AccountId, RecordType.DeveloperName, Status, CreatedDate, Case_Resolution__c	
                  FROM Cases
                  WHERE RecordType.DeveloperName = 'Integrity' AND CreatedDate = LAST_N_DAYS:730)
             FROM Account
             WHERE Id = :accountId
             OR ParentId = :accountId
            ORDER BY Name]
        );
        
        //Put the account and its related accounts in different variables/collections
        Account recordAccount = accountsWithRelated.remove(accountId);
        List<Account> relatedAccounts = accountsWithRelated.values();
        
        //Return a stringified version of the KeyIndicatorsWithChildIndicators wrapper to the LWC.
        //The constructors of the wrapper and its contents populate all the indicators
        return JSON.serialize(
            new KeyIndicatorsWithChildIndicators(
                recordAccount,
                relatedAccounts
            )
        );
    }
    
	//Main wrapper class that gets returned to the LWC. Contains a KeyIndicatorsWrapper for the parent account,
	//a list of KeyIndicatorsWrapper for each child account,
	//and a list of the unique KeyIndicators on the child accounts
    public class KeyIndicatorsWithChildIndicators{
        public KeyIndicatorsWrapper parentIndicators;
        public List<KeyIndicatorsWrapper> childIndicators = new List<KeyIndicatorsWrapper>();
        public List<KeyIndicator> uniqueChildIndicators = new List<KeyIndicator>();
        
        public KeyIndicatorsWithChildIndicators(Account recordAccount, List<Account> relatedAccounts){
            Map<String, KeyIndicator> uniqueChildIndicatorsMap = new Map<String,KeyIndicator>();
            
            this.parentIndicators = new KeyIndicatorsWrapper(recordAccount);
            
            if (relatedAccounts.isEmpty()){
                return;
            }
            
            for (Account relatedAccount : relatedAccounts){
                KeyIndicatorsWrapper relatedWrapper = new KeyIndicatorsWrapper(relatedAccount);
                
                if (relatedWrapper.indicators.isEmpty()){
                    continue;
                }
                
                for (KeyIndicator ind : relatedWrapper.indicators){
                     uniqueChildIndicatorsMap.put(ind.title, ind);
                }

                this.childIndicators.add(relatedWrapper);
            }
            
            this.uniqueChildIndicators = uniqueChildIndicatorsMap.values();
        }
    }
   
    //Wrapper that contains an account and a list of KeyIndicators
    public class KeyIndicatorsWrapper{
        public Account a;
        public List<KeyIndicator> indicators = new List<KeyIndicator>();
        
        public KeyIndicatorsWrapper(Account recordAccount){
            this.a = recordAccount;
            Map<Id,Case> relatedIntegrityCases = new Map<Id,Case>(recordAccount.Cases);
            this.indicators = checkAccountIndicators(recordAccount, relatedIntegrityCases);
        }
    }
    
    //KeyIndicator object used to style the specific alert
    public class KeyIndicator implements Comparable{
        String iconPath = '/_slds/icons/utility-sprite/svg/symbols.svg#';
        String footerColor;
        String colorIconName;
        String title;
        String subtitle;
        Integer sortOrder;
        
        public KeyIndicator(String iconName, String color, String title, String subtitle, Integer sortOrder){
            hexAndIconName hAndI = COLOR_TO_HEX_AND_ICON_MAP.get(color);
            
            this.iconPath += iconName;
            this.footerColor = hAndI.hex;
            this.colorIconName = hAndI.iconName;
            this.title = title;
            this.subtitle = subtitle;
            this.sortOrder = sortOrder;
        }
        
        // Implement the compareTo() method
        public Integer compareTo(Object compareTo) {
            KeyIndicator compareToKeyInd = (KeyIndicator)compareTo;
            if (sortOrder == compareToKeyInd.sortOrder) return 0;
            if (sortOrder > compareToKeyInd.sortOrder) return 1;
            return -1;        
        }
    }
        
    //Method to just check custom logic, and add KeyIndicators to a return map
    public static List<KeyIndicator> checkAccountIndicators(Account accountToCheck, Map<Id,Case> relatedIntegrityCases) {
        List<KeyIndicator> keyIndicatorsToReturn = new List<KeyIndicator>();
        List<Case> checkForMultipleCases = new List<Case>();

        if (accountToCheck.Days_Until_Delinquency_Cancellation__c != null) {
            keyIndicatorsToReturn.add(
                makeIndicatorRed(
                    'PENDING AUTO CANCELLATION',
                    accountToCheck.Days_Until_Delinquency_Cancellation__c + ' days until delinquency cancellation',
                    'weeklyview',
                    10
                )
            );
        }

        if (accountToCheck.ZuoraWriteOffBalance__c > 0){
            keyIndicatorsToReturn.add(
                makeIndicatorRed(
                    'WRITE OFF', 
                    'Account has a write off balance', 
                    'shield',
                    20
                )
            );   
        }


        
        for(SBQQ__Subscription__c sub : accountToCheck.CPQ_Subscriptions_Fulfillment__r) {
            if (sub.Provisioning_Status_Formula__c == 'Delinquent'){
                keyIndicatorsToReturn.add(
                    makeIndicatorYellow(
                        'DELINQUENT SUBS', 
                        'Account has delinquent subscriptions', 
                        'weeklyview',
                        30
                    )
                );
                break;
            }
        }

        for(SBQQ__Subscription__c sub : accountToCheck.CPQ_Subscriptions_Fulfillment__r) {
            if (sub.Cancellation_Effective_Date__c > System.today() && sub.Provisioning_Status_Formula__c != 'De-activated') { 
                keyIndicatorsToReturn.add(
                    makeIndicatorYellow(
                        'PENDING CANCELLATION', 
                        'Account has a pending cancellation', 
                        'close', 
                        40
                    )
                );
                break;
            }
        }
        if (accountToCheck.Code_of_Conduct_Chkbox__c == true){
            keyIndicatorsToReturn.add(
                makeIndicatorYellow(
                    'CODE OF CONDUCT VIOLATION',
                    'Account has a contact with a code of conduct violation',
                    'shield',
                    40
                )

            );
        }

        for (Case cas : relatedIntegrityCases.values()){
            if (cas.Status != 'Closed'){
                keyIndicatorsToReturn.add(
                    makeIndicatorYellow(
                        'OUTSTANDING COMPLIANCE ISSUE',
                        'Open integrity case',
                        'case',
                        50
                    )            
                );
                relatedIntegrityCases.remove(cas.id);
                break; //breaks the loop once a single case is found. otherwise we end up with multiple of the same KAIs 
            }
        }
        
        for (Case cas : relatedIntegrityCases.values()){
            if ((cas.Case_Resolution__c == 'Other' || cas.Case_Resolution__c == 'Refunded' || cas.Case_Resolution__c == 'Resolved') && cas.Status == 'Closed'){ 
                //icons from https://www.lightningdesignsystem.com/icons/
                checkForMultipleCases.add(cas);
                if (checkForMultipleCases.size() > 1){
                    keyIndicatorsToReturn.add(
                        makeIndicatorYellow(
                            'HISTORICAL MULTIPLE COMPLIANCE ISSUES IDENTIFIED',
                            'Multiple closed integrity cases in the past two years',
                            'cases',
                            60
                        )
                    ); 
                    break;   
                }  

            }
        }

        keyIndicatorsToReturn.sort();

        return keyIndicatorsToReturn;
    }
    
    private static final Map<String,hexAndIconName> COLOR_TO_HEX_AND_ICON_MAP = new Map<String,hexAndIconName>{
        'grey'   => new hexAndIconName('#8199AF', 'canvas'),
        'green'  => new hexAndIconName('#7DC37D', 'record'),
        'yellow' => new hexAndIconName('#FBB439', 'priority'),
        'red'    => new hexAndIconName('#EF6E64', 'close')
    };
                
    private static final String IMAGE_PATH = '/_slds/icons/utility-sprite/svg/symbols.svg#';
    
    //Small class that holds a hex value and the value of an SLDS action icon
    //The hex color determines the footer color of the KeyIndicator and the action icon
    //name determines the color of the icon
    private class hexAndIconName{
        String hex;
        String iconName;
        
        public hexAndIconName(String hex, String iconName){
            this.hex = hex;
            this.iconName = iconName;
        }
    }
    
    @TestVisible
    //Method for making grey KeyIndicators
    private static KeyIndicator makeIndicatorGrey(String title, String subtitle, String icon, Integer sortOrder){
        return new KeyIndicator(
            icon, 
            'grey', 
            title,
            subtitle,
            sortOrder
        );
    }
    
    @TestVisible
    //Method for making ggreen KeyIndicators
    private static KeyIndicator makeIndicatorGreen(String title, String subtitle, String icon, Integer sortOrder){
        return new KeyIndicator(
            icon, 
            'green', 
            title,
            subtitle,
            sortOrder
        );
    }
    
    @TestVisible
    //Method for making red KeyIndicators
    private static KeyIndicator makeIndicatorRed(String title, String subtitle, String icon, Integer sortOrder){
        return new KeyIndicator(
            icon, 
            'red', 
            title,
            subtitle,
            sortOrder
        );
    }
    
    @TestVisible
    //Method for making yellow KeyIndicators
    private static KeyIndicator makeIndicatorYellow(String title, String subtitle, String icon, Integer sortOrder){
        return new KeyIndicator(
            icon, 
            'yellow', 
            title,
            subtitle,
            sortOrder
        );
    }
}
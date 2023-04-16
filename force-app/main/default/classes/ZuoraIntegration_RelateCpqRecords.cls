// https://cargurus.atlassian.net/browse/BR-1144
// methods to match newly created / updated zuora product charges to their related cpq subscriptions
public without sharing class ZuoraIntegration_RelateCpqRecords {

    static final Map<Id,Product2> PRODUCTMAP = ZuoraIntegration_OrderHelper.PRODUCTMAP;
    static final Set<String> QUANTITY_DEPEND_PRODS = new Set<String>{
        'HGLT'
    };

    // match either by zuora subscription numbers or cpq subscription ids - one will always be null
    public static void matchCPQSubZuoraFields(Set<String> zSubNumbers, Set<Id> cpqSubIds) {

        // query cpq subscriptions by zuora subscription numbers or cpq subscription ids
        List<SBQQ__Subscription__c> cpqSubList = getCpqSubList(zSubNumbers, cpqSubIds);

        // if by cpq sub ids, loop through cpq subscriptions to retrieve
        if (zSubNumbers == null) {
            zSubNumbers = new Set<String>();
            for (SBQQ__Subscription__c cpqSub : cpqSubList) {
                zSubNumbers.add(cpqSub.Zuora_Subscription_Number__c);
            }
        }

        // get a map of zuora subscriptions with related charges
        Map<String,Zuora__Subscription__c> zSubMap = getZuoraSubMap(zSubNumbers);
        Map<Id,SBQQ__Subscription__c> cpqSubUpdateMap = new Map<Id,SBQQ__Subscription__c>();

        // loop through cpq subs to match to zuora subs and charges
        for (SBQQ__Subscription__c cpqSub : cpqSubList) {
            Zuora__Subscription__c zSub = zSubMap.get(cpqSub.Zuora_Subscription_Number__c);
            if (zSub == null) {
                continue;
            }

            // update subscription lookup on cpq subscription (if different)
            if (cpqSub.Zuora_Subscription__c != zSub.Id) {
                cpqSub.Zuora_Subscription__c = zSub.Id;
                cpqSubUpdateMap.put(cpqSub.Id, cpqSub);
            }

            Product2 p = PRODUCTMAP.get(cpqSub.SBQQ__Product__c);
            if (p == null) {
                continue;
            }

            String productCode = cpqSub.Product_Code__c;
            Decimal cpqSubNetPrice = cpqSub.SBQQ__NetPrice__c;
            Decimal cpqSubQty = cpqSub.SBQQ__Quantity__c;

            if(QUANTITY_DEPEND_PRODS.contains(productCode) && cpqSubQty > 0) {
                cpqSubNetPrice = cpqSubQty * cpqSubNetPrice;
            }

            // loop through related charges to find match for current cpq subscription and update fields
            for (Zuora__SubscriptionProductCharge__c zSubCharge : zSub.Zuora__Subscription_Product_Charges__r) {
                if (p.Zuora_Product_Rate_Plan_Charge_ID__c == zSubCharge.Zuora__ProductRatePlanChargeId__c
                    && cpqSubNetPrice == zSubCharge.Zuora__MonthlyRecurringRevenue__c) 
                {
                    cpqSub.Zuora_Rate_Plan_Id__c = zSubCharge.Zuora__SubscriptionRatePlan__r.Zuora__External_Id__c;
                    cpqSub.Zuora_Subscription_Rate_Plan__c = zSubCharge.Zuora__SubscriptionRatePlan__c;
                    cpqSubUpdateMap.put(cpqSub.Id, cpqSub);
                }
            }
        }

        if (!cpqSubUpdateMap.isEmpty()) {
            update cpqSubUpdateMap.values();
        }
    }

    // entry point if matching by zuora subscription numbers
    public static void matchCPQSubZuoraFields(Set<String> zSubNumbers) {
        matchCPQSubZuoraFields(zSubNumbers, null);
    }

    // entry point if matching by cpq subscription ids
    public static void matchCPQSubZuoraFields(Set<Id> cpqSubIds) {
        matchCPQSubZuoraFields(null, cpqSubIds);
    }

    // query for cpq subscription data by either zuora sub numbers or cpq sub ids
    static List<SBQQ__Subscription__c> getCpqSubList(Set<String> zSubNumbers, Set<Id> cpqSubIds) {
        Date todayDate = Date.today();

        List<String> queryFields = new List<String>{
            'Id',
            'Product_Code__c',
            'SBQQ__Quantity__c',
            'SBQQ__Product__c',
            'SBQQ__NetPrice__c',
            'Zuora_Subscription_Number__c',
            'Zuora_Subscription__c'
        };

        List<String> queryFilters = new List<String>{
            '(Zuora_Rate_Plan_Id__c = null OR Zuora_Subscription__c = null OR Zuora_Subscription_Rate_Plan__c = null)',
            'SBQQ__EndDate__c >= :todayDate',
            '(SBQQ__TerminatedDate__c = null OR SBQQ__TerminatedDate__c >= :todayDate)'
        };

        if (zSubNumbers != null) {
            queryFilters.add('Zuora_Subscription_Number__c IN :zSubNumbers');
        }

        if (cpqSubIds != null) {
            queryFilters.add('Id IN :cpqSubIds');
        }

        String query = 'SELECT '+String.join(queryFields, ', ')+' FROM SBQQ__Subscription__c WHERE '
            +String.join(queryFilters, ' AND ');

        return (List<SBQQ__Subscription__c>)Database.query(query);
    }
    
    // get a map of zuora subscriptions with related charges
    static Map<String,Zuora__Subscription__c> getZuoraSubMap(Set<String> zSubNumbers) {
        Map<String,Zuora__Subscription__c> returnMap = new Map<String,Zuora__Subscription__c>();

        for (Zuora__Subscription__c zSub : [SELECT Id, Name,
                (SELECT Id, Name, Zuora__SubscriptionRatePlan__c, Zuora__SubscriptionRatePlan__r.Zuora__External_Id__c, 
                    Zuora__ProductRatePlanChargeId__c, Zuora__MonthlyRecurringRevenue__c 
                    FROM Zuora__Subscription_Product_Charges__r
                    WHERE Zuora__Model__c != 'Discount-Percentage') 
            FROM Zuora__Subscription__c WHERE Name IN :zSubNumbers]) 
        {
            returnMap.put(zSub.Name, zSub);
        }

        return returnMap;
    }

}

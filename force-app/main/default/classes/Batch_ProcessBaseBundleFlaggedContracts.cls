/**
 * BR-9384 - process contracts that have the same fulfilllment accounts with different
 * Base Bundle CPQ Subs
 * 
 */
public without sharing class Batch_ProcessBaseBundleFlaggedContracts implements Database.Batchable<sObject> {
    
    private Set<Id> ignoreContractIds = new Set<Id>{'8004S000000cJltQAE','8004S000000cJD5QAM','8004S000000c8kIQAQ'};
    private String recId;
    
    //default constructor
    public Batch_ProcessBaseBundleFlaggedContracts() {}

    public Batch_ProcessBaseBundleFlaggedContracts(String recordId) {
        recId = recordId;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id FROM Contract WHERE Status = \'Activated\' AND Review_Subscriptions__c=true AND Id NOT IN:ignoreContractIds';
        if(String.isNotBlank(recId)){
            query += ' AND Id=\''+recId+'\'';
        }
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Contract> contracts) {
        
        Set<Id> contractIds = new Set<Id>();
        Set<String> productIds = new Set<String>();
        Map<String,List<SBQQ__Subscription__c>> baseSubIdToSubs = new Map<String,List<SBQQ__Subscription__c>>();
        Map<Id,Set<String>> contractIdToBaseSubids = new Map<Id,Set<String>>();

        for(Contract cont : contracts){
            contractIds.add(cont.Id);
        }

        Map<Id,Set<SBQQ__Subscription__c>> locationIdToBaseSubscription = new Map<Id,Set<SBQQ__Subscription__c>>();
        List<SBQQ__Subscription__c> requiredSubs = new List<SBQQ__Subscription__c>();

        for(SBQQ__Subscription__c cpq_sub : getRelatedSubscriptions(contractIds)){

            if(!locationIdToBaseSubscription.containsKey(cpq_sub.Fulfillment_Account__c)){
                locationIdToBaseSubscription.put(cpq_sub.Fulfillment_Account__c,new Set<SBQQ__Subscription__c>());
            }
            locationIdToBaseSubscription.get(cpq_sub.Fulfillment_Account__c).add(cpq_sub);
        }

        for(Id locId : locationIdToBaseSubscription.keyset()){
            Integer relatedBaseSubSize = locationIdToBaseSubscription.get(locId).size();
            if(relatedBaseSubSize > 0){
                requiredSubs.addAll(locationIdToBaseSubscription.get(locId));
            }
        }

        for(SBQQ__Subscription__c cpq_sub : requiredSubs){
            //IGNORE Core Listing Subscription, keeping them on same Contract and moving addons/any other product
            if(cpq_sub.SBQQ__RequiredById__c!=null){

                if(!contractIdToBaseSubids.containsKey(cpq_sub.SBQQ__Contract__c)){
                    contractIdToBaseSubids.put(cpq_sub.SBQQ__Contract__c,new Set<String>());
                }
                contractIdToBaseSubids.get(cpq_sub.SBQQ__Contract__c).add(cpq_sub.SBQQ__RequiredById__c);

                if(!baseSubIdToSubs.containsKey(cpq_sub.SBQQ__RequiredById__c)){
                    baseSubIdToSubs.put(cpq_sub.SBQQ__RequiredById__c,new List<SBQQ__Subscription__c>());
                }
                baseSubIdToSubs.get(cpq_sub.SBQQ__RequiredById__c).add(cpq_sub);

                productIds.add(cpq_sub.SBQQ__Product__c);
            }
        }

        String standaloneProdId = getStandaloneProductId();
        Map<String,SBQQ__ProductOption__c> prodIdToProdOption = getProductOptionMap(productIds,standaloneProdId);

        String fields = '';
        Map<String, Schema.SObjectField> mapofFields = Schema.getGlobalDescribe().get('Contract').getDescribe().fields.getMap();

        for(String fieldName : mapofFields.keySet()) {
            fields += fieldName+',';
        }
        fields = fields.removeEnd(',');
        String soqlQuery = 'SELECT ' + fields + ' FROM Contract WHERE Id IN:contractIds';

        List<Contract> contractList = Database.query(soqlQuery);

        List<Contract> insertDupContractList = new List<Contract>();
        List<Contract> updateOriginalContractList = new List<Contract>();

        Map<Id,List<Contract>> insertDupContractMap = new Map<Id,List<Contract>>();

        List<SBQQ__Subscription__c> updateSubs = new List<SBQQ__Subscription__c>();

        for(Contract cont : contractList){
            Integer duplicateContractCount = contractIdToBaseSubids.get(cont.Id).size();
            
            cont.Review_Subscriptions__c = false;
            updateOriginalContractList.add(cont);

            for(Integer k = 0;k < duplicateContractCount;k++){

                Contract duplicateContract = cont.clone(false,true,true,false);
                duplicateContract.Name = duplicateContract.Name + ' - ' + k;
                duplicateContract.SalesforceLegacyContractID__c = cont.Id;
                duplicateContract.Review_Subscriptions__c = false;
                insertDupContractList.add(duplicateContract);
            }
        }

        update updateOriginalContractList;

        if(!insertDupContractList.isEmpty()){
            insert insertDupContractList;

            for(Contract dupedContract : insertDupContractList){

                if(!insertDupContractMap.containsKey(dupedContract.SalesforceLegacyContractID__c)){
                    insertDupContractMap.put(dupedContract.SalesforceLegacyContractID__c,new List<Contract>());
                }
                insertDupContractMap.get(dupedContract.SalesforceLegacyContractID__c).add(dupedContract);
            }

            for(Id contId : contractIdToBaseSubids.keyset()){

                Set<String> baseSubIdSet = contractIdToBaseSubids.get(contId);
    
                if(!baseSubIdSet.isEmpty()){
    
                    Integer baseSubCounter = 0;
    
                    for(String baseSubId : baseSubIdSet){
    
                        if(insertDupContractMap.containsKey(contId) && baseSubIdToSubs.containsKey(baseSubId)){
    
                            List<Contract> dupedContractItems = insertDupContractMap.get(contId);
    
                            SBQQ__Subscription__c baseSub = new SBQQ__Subscription__c(
                                Id = baseSubId,
                                SBQQ__Contract__c = dupedContractItems[baseSubCounter].Id,
                                SBQQ__Product__c = standaloneProdId
                            );
                            updateSubs.add(baseSub);
    
                            for(SBQQ__Subscription__c childSubs : baseSubIdToSubs.get(baseSubId)){
                                childSubs.SBQQ__Contract__c = dupedContractItems[baseSubCounter].Id;
    
                                //Set Product Option on to be updated Child Subscriptions
                                if(prodIdToProdOption.containsKey(childSubs.SBQQ__Product__c)){
                                    childSubs.SBQQ__ProductOption__c = prodIdToProdOption.get(childSubs.SBQQ__Product__c).Id;
                                }
                                updateSubs.add(childSubs);
                            }
                        }
                        baseSubCounter ++;
                    }
    
                }
    
            }
    
            if(!updateSubs.isEmpty()){
                update updateSubs;
            }
        }
    }

    static List<SBQQ__Subscription__c> getRelatedSubscriptions(Set<Id> contractIds){

        return new List<SBQQ__Subscription__c>([
            SELECT Id, Product_Code__c,SBQQ__RequiredById__c, 
            Fulfillment_Account__c, SBQQ__Contract__c, 
            SBQQ__Product__c, SBQQ__Product__r.Product_Category__c 
            FROM SBQQ__Subscription__c 
            WHERE SBQQ__Contract__c IN :contractIds 
            AND Provisioning_Status__c = 'Activated' 
            AND SBQQ__Product__r.Product_Category__c!='Core Products' 
            AND Product_Code__c!='CG-BASE'
        ]);
    }

    static String getStandaloneProductId(){
        return [SELECT Name, Id, ProductCode FROM Product2 WHERE Name = 'Standalone Bundle' LIMIT 1].Id;
    }

    static Map<String,SBQQ__ProductOption__c> getProductOptionMap(Set<String> productIds,Id standaloneProdId){

        Map<String,SBQQ__ProductOption__c> prodIdToProdOption = new Map<String,SBQQ__ProductOption__c>();

        for(SBQQ__ProductOption__c cpq_ProdOption : [
            SELECT Id, SBQQ__OptionalSKU__c  
            FROM SBQQ__ProductOption__c 
            WHERE SBQQ__OptionalSKU__c IN:productIds 
            AND SBQQ__ConfiguredSKU__c =:standaloneProdId
        ]){
            prodIdToProdOption.put(cpq_ProdOption.SBQQ__OptionalSKU__c,cpq_ProdOption);
        }
        return prodIdToProdOption;
    }

    public void finish(Database.BatchableContext bc) {

    }
}
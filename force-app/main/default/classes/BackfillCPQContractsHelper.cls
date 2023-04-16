public without sharing class BackfillCPQContractsHelper {
    //collect error tasks
    static List<Task> err_tasks = new List<Task>();

    //Map of the Legacy_Id__c field of the contract Account to the Account
    //determined using the SalesforceLegacyAccountID__c field of the zsubs
    static Map<Id, Account> contractAccLookup = new Map<Id, Account>();

    //collect all the legacy contract ids from subs and query filter for 
    //any that have already been backfilled
    static Set<Id> legacyContractIds = new Set<Id>();

    public static List<Zuora__Subscription__c> getzSubs(Set<Id> accountIds) {
    
        Set<String> zSubStatuses = new Set<String>{'Active'};

        Map<Id,Zuora__Subscription__c> zSubMap = new Map<Id,Zuora__Subscription__c>([SELECT Id, Name,
            Zuora__SubscriptionStartDate__c, Zuora__SubscriptionEndDate__c, SalesforceLegacyContractID__c, 
            SalesforceLegacyAccountID__c, Zuora__Account__c, Zuora__Account__r.Ultimate_Parent_Account__c,
            Zuora__InvoiceOwner__r.Zuora__Account__c, Zuora__InitialTerm__c,
            Zuora__InvoiceOwner__r.Zuora__Account__r.ParentId,
            Zuora__InvoiceOwner__r.Zuora__DefaultPaymentMethod__c,
            Zuora__External_Id__c, Zuora__ServiceActivationDate__c, Zuora__Status__c, CurrencyIsoCode, 
                (SELECT Id, Zuora__EffectiveStartDate__c, Zuora__EffectiveEndDate__c, Zuora__Product__c, 
                Zuora__EndDateCondition__c, Zuora__Upto_How_Many_Periods__c,
                Zuora__SubscriptionRatePlan__r.Zuora__OriginalProductRatePlanId__c, Name, 
                Zuora__Quantity__c, Zuora__RatePlanId__c, Zuora__Description__c, Zuora__DiscountAmount__c, 
                Zuora__DiscountPercentage__c, Zuora__Product__r.Name, Zuora__ChargeNumber__c, Zuora__Type__c, 
                Zuora__Model__c, Zuora__Price__c, Zuora__ExtendedAmount__c 
                FROM Zuora__Subscription_Product_Charges__r WHERE Zuora__Type__c != 'Usage')
            FROM Zuora__Subscription__c 
            WHERE Zuora__Account__c in : accountIds AND Zuora__Status__c in : zSubStatuses
            AND SalesforceLegacyContractID__c NOT IN ('null', 'NULL', null) 
            AND SalesforceLegacyAccountID__c NOT IN ('null', 'NULL', null)
            AND Id NOT IN (SELECT Zuora_Subscription__c FROM SBQQ__Subscription__c)]);


        Set<Id> legContractAccIds = new Set<Id>();
        for (Zuora__Subscription__c zsub : zSubMap.values()) {
            legContractAccIds.add(zsub.SalesforceLegacyAccountID__c);
            legacyContractIds.add(zsub.SalesforceLegacyContractID__c);
        }

        for(Account acc : [SELECT Id, Legacy_Id__c,OwnerId, Name, ParentId, RecordType.Name, 
            Ultimate_Parent_Account__c, CurrencyIsoCode, BillingCountryCode FROM Account 
            WHERE Legacy_Id__c IN :legContractAccIds]) {
            
            contractAccLookup.put(acc.Legacy_Id__c, acc);
        }

        return zSubMap.values();
    }

    private static Id getContractAccountId() {
        return null;
    }

    //-------PROCESS BATCH--------//
    public void processBatch(List<Account> accountList) {

        //Accounts, ultimate parents, fields
        Map<Id, Account> accountIdMap = new Map<Id,Account>(accountList);
        
        Set<Id> upAccountIds = new Set<Id>();

        for(Account legAcc : contractAccLookup.values()) {
            if(legAcc.ParentId == null) {
                upAccountIds.add(legAcc.Id);
            } else {
                upAccountIds.add(legAcc.Ultimate_Parent_Account__c);
            }
        }

        for(Account a : accountList) {
            if(a.ParentId == null) {
                upAccountIds.add(a.Id);
            } else {
                upAccountIds.add(a.Ultimate_Parent_Account__c);
            }
        }

        Map<Id,Account> accountMap = new Map<Id,Account>([SELECT Id, OwnerId, Name, ParentId, RecordType.Name, 
            Ultimate_Parent_Account__c, CurrencyIsoCode, BillingCountryCode FROM Account 
            WHERE Id IN : upAccountIds OR Ultimate_Parent_Account__c IN :upAccountIds]);
        
        // cpq Subscription 1 to 1 with zuora subscription rate plan id
        Map<String,SBQQ__Subscription__c> cpqSubscriptionMap = new Map<String, SBQQ__Subscription__c>();

        Map<String, Contract> cpqContractMap = new Map<String, Contract>();

        //zub to rate plan ids and contract key to zsub - help identify cpq subs by zsubid
        Map<String,Set<String>> zSubToSubRatePlanIds = new Map<String,Set<String>>();
		Map<String,Set<String>> contractKeyToZSubId = new Map<String,Set<String>>();
        
        //Ignore these zuora sub prod charge models
        Set<String> ignoredChargeModels = new Set<String>{'Discount-Fixed Amount'};

        System.debug('Account Id Map:'+accountIdMap.keySet());

        //Get Zuora Subscriptions and Product Charges to process
        List<Zuora__Subscription__c> zSubs = getzSubs(accountIdMap.keySet());
        System.debug('# Subscriptions: '+zSubs.size());

        //setup previously backfilled contracts for ref
        cpqContractMap.putAll(getSavedContracts());

        //LOOP THROUGH SUBSCRIPTIONS AND SETUP BASE BUNDLE
        for (Zuora__Subscription__c zSub : zSubs) {               
            
            //ZSUB Fields
            Id fulfillmentAccId = zSub.Zuora__Account__c;
            Date zSubStartDate = zSub.Zuora__SubscriptionStartDate__c;
            Date zSubEndDate = zSub.Zuora__SubscriptionEndDate__c;
            String contractInitialTerm = zSub.Zuora__InitialTerm__c;
            String contractKey = zSub.SalesforceLegacyContractID__c;
            String legacyContractAccountId = zSub.SalesforceLegacyAccountID__c;
            System.debug(legacyContractAccountId);

            //Lookup the Contract Account
            Account contractAcc = contractAccLookup.get(legacyContractAccountId);

            if(contractAcc == null) {
                
                Task et = setErrorTask(zSub.Id,
                    'Contract Account Not Identified');  
                err_tasks.add(et);
                continue;
            }

            Id contractAccountId = contractAcc.Id;
            
            //Fulfillment account and other fields
            Account fulfillmentAcc = accountMap.get(fulfillmentAccId);
            Id accountOwnerId = contractAcc.OwnerId;
            String accountName = contractAcc.Name;
            String currencyCode = contractAcc.CurrencyIsoCode;

            //Billing Account
            Id billingAccountId = zSub.Zuora__InvoiceOwner__r.Zuora__Account__c;

            //contract dates & term
            Date contractEndDate = zSubEndDate.addDays(-1);  //CONTRACT END DATE           
            Date contractStartDate = zSubStartDate;

            //String zTermType = zSub.Zuora__InitialTermPeriodType__c;
            String zInitialTerm = zSub.Zuora__InitialTerm__c;
            Date initialTermEndDate;

            if (zInitialTerm != null && zInitialTerm != 'NULL' && zInitialTerm != 'null') {

                List<String> splitTerm = zInitialTerm.split(' ');

                if (splitTerm[1] == 'Days') {
                    initialTermEndDate = contractStartDate.addDays(Integer.valueOf(splitTerm[0]) - 1);

                } else if (splitTerm[1] == 'Months') {
                    initialTermEndDate = contractStartDate.addMonths(Integer.valueOf(splitTerm[0]));
                }
            }

            //32 char zsub id
            String zSubId = zSub.Zuora__External_Id__c;

            //map contract key to 32 char zsubIds
            if (!contractKeyToZSubId.containsKey(contractKey)) {
                contractKeyToZSubId.put(contractKey, new Set<String>());
            } 
            contractKeyToZSubId.get(contractKey).add(zSubId);

            //map 32 char zsub id to sub rate plan ids
            zSubToSubRatePlanIds.put(zSubId, new Set<String>());

            // create the base bundle
            SBQQ__Subscription__c cpqSubBaseBundle = new SBQQ__Subscription__c(
                SBQQ__Account__c = contractAccountId,
                Fulfillment_Account__c = fulfillmentAccId,
                Billing_Account__c = billingAccountId,
                SBQQ__Product__c = baseBundleProdId,
                CurrencyIsoCode = currencyCode,
                SBQQ__ProductSubscriptionType__c = 'Renewable',
                SBQQ__Quantity__c = 1,
                SBQQ__SubscriptionStartDate__c = contractStartDate,
                //SBQQ__SubscriptionEndDate__c = contractEndDate,    //END DATE CHECK
                SBQQ__NetPrice__c = 0,
                SBQQ__CustomerPrice__c = 0,  
                SBQQ__RegularPrice__c = 0,
                SBQQ__ListPrice__c = 0,
                SBQQ__SpecialPrice__c = 0,
                SBQQ__SubscriptionType__c = 'Renewable',
                Zuora_Subscription__c = zSub.Id,
                Zuora_Subscription_Number__c = zSub.Name,
                Provisioning_Status__c = 'Activated'
                //Zuora_Subscription_Processed__c = true //CHECK DO WE NEED TO SET THIS?
            );
            cpqSubscriptionMap.put(zSubId+'basebundle', cpqSubBaseBundle);
            
            //LOOP SUBSCRIPTION PRODUCT CHARGES
            for (Zuora__SubscriptionProductCharge__c zSubCharge : zSub.Zuora__Subscription_Product_Charges__r) {
                
                if (ignoredChargeModels.contains(zSubCharge.Zuora__Model__c)) {
                    continue;
                }
                
                //rate plan id, product rate plan id, qty
                String zRatePlanId = zSubCharge.Zuora__RatePlanId__c;
                Id zRatePlanLkpId = zSubCharge.Zuora__SubscriptionRatePlan__c;
                String prpId = zSubCharge.Zuora__SubscriptionRatePlan__r.Zuora__OriginalProductRatePlanId__c;
                Double qty = zSubCharge.Zuora__Quantity__c;
                
                if (!prpIdProductMap.containsKey(prpId)) {
                    System.debug('No product for Id: '+prpId);
                }
                
                Id productId = prpIdProductMap.get(prpId).Id;
                
                zSubToSubRatePlanIds.get(zSubId).add(zRatePlanId);

                SBQQ__Subscription__c cpqSub; //INIT CPQ SUB
                if (cpqSubscriptionMap.containsKey(zRatePlanId)) {
                    cpqSub = cpqSubscriptionMap.get(zRatePlanId);
                } else {
                    cpqSub = new SBQQ__Subscription__c();
                    cpqSubscriptionMap.put(zRatePlanId, cpqSub);
                }

                if (zSubCharge.Zuora__Model__c == 'Discount-Percentage') {
                    //If specific end date calculate the difference in months and setup the period in months
                    //If end date conidtion = fized period, then just pick the Up To How Many Periods number
                    String endDateCondition = zSubCharge.Zuora__EndDateCondition__c;
                    Date discStartDate = zSubCharge.Zuora__EffectiveStartDate__c;
                    Date discEndDate = zSubCharge.Zuora__EffectiveEndDate__c;
                    Decimal discPercent = zSubCharge.Zuora__DiscountPercentage__c;
                    System.debug('Discount Percentage: '+discPercent);

                    if (discPercent == 0.00) {
                        continue;
                    }

                    Decimal uptoPeriods = zSubCharge.Zuora__Upto_How_Many_Periods__c;
                    
                    //set the discount percent value
                    cpqSub.Intro_Discount_Percentage__c = discPercent;
                    
                    //set the intro dicount period based on the endDateCondition
                    if (endDateCondition == 'Fixed Period') {
                        cpqSub.Intro_Discount_Period__c = uptoPeriods;
                    } else if (endDateCondition == 'Specific End Date' || endDateCondition == 'Subscription End Date') {
                        cpqSub.Intro_Discount_Period__c = discStartDate.monthsBetween(discEndDate);
                    } else if (endDateCondition == 'One Time') {
                        cpqSub.Intro_Discount_Period__c = 1;
                    }

                } else if (zSubCharge.Zuora__Model__c == 'Flat Fee Pricing'){

                     //The charge amount - monthly charge
                    Double chargeAmount = zSubCharge.Zuora__ExtendedAmount__c;
                    if (chargeAmount == null) {
                        chargeAmount = 0.00;
                    }

                    if (prpIdProductMap.get(prpId).Name != 'Highlight') {     ///REVIEW HIGHLIGHT RELATED CODE
                        qty = 1;
                    } else if(prpIdProductMap.get(prpId).Name == 'Highlight') {
                        qty = zSubCharge.Zuora__Quantity__c;
                        if(qty == 0) {
                            qty = chargeAmount/650;
                        }
                    }
	                    
                    cpqSub.SBQQ__Account__c = contractAccountId;
                    cpqSub.Fulfillment_Account__c = fulfillmentAccId;
                    cpqSub.Billing_Account__c = billingAccountId;
                    cpqSub.SBQQ__Product__c = productId;
                    cpqSub.CurrencyIsoCode = currencyCode;
                    cpqSub.SBQQ__ProductSubscriptionType__c = 'Renewable';
                    cpqSub.SBQQ__Quantity__c = qty;
                    cpqSub.SBQQ__SubscriptionStartDate__c = contractStartDate;
                    //cpqSub.SBQQ__SubscriptionEndDate__c = contractEndDate;
                    cpqSub.SBQQ__CustomerPrice__c = chargeAmount;  
                    cpqSub.SBQQ__RegularPrice__c = chargeAmount;
                    cpqSub.SBQQ__RenewalPrice__c = chargeAmount;
                    cpqSub.SBQQ__ListPrice__c = chargeAmount;
                    cpqSub.SBQQ__SpecialPrice__c = chargeAmount;
                    cpqSub.SBQQ__ProrateMultiplier__c = 1;
                    cpqSub.SBQQ__NetPrice__c = chargeAmount;
                    cpqSub.SBQQ__SubscriptionType__c = 'Renewable';
                    cpqSub.Zuora_Subscription__c = zSub.Id;
                    cpqSub.Zuora_Subscription_Number__c = zSub.Name;
                    cpqSub.Zuora_Rate_Plan_Id__c = zRatePlanId;
                    cpqSub.Zuora_Subscription_Rate_Plan__c = zRatePlanLkpId;
                    cpqSub.Provisioning_Status__c = 'Activated';
                    //Zuora_Subscription_Processed__c = true  //CHECK DO WE NEED TO SET THIS?
                }
            }

            if (!cpqContractMap.containsKey(contractKey)) {
                System.debug(contractAccountId);
                Id pbId = stdPriceBookId;
                
                cpqContractMap.put(contractKey, 
                    new Contract(
                        AccountId = contractAccountId, 
                        OwnerId = accountOwnerId,      
                        Name = 'CPQ Backfill - '+accountName.left(40),
                        StartDate = contractStartDate, 
                        EndDate = contractEndDate,  
                        Initial_Term_End_Date__c = initialTermEndDate,
                        CurrencyIsoCode = currencyCode,
                        ContractTerm = 1,  //CHECK ABOUT CONTRACT TERM //contractStartDate.monthsBetween(contractEndDate);
                        SBQQ__PreserveBundleStructureUponRenewals__c = true,
                       	SBQQ__RenewalForecast__c = false,
                        //SBQQ__AmendmentOwner__c = accountOwnerId,
                        //SBQQ__RenewalOwner__c = accountOwnerId,
                        SBQQ__AmendmentPricebookId__c = pbId, 
                        SBQQ__RenewalPricebookId__c = pbId, 
                        Legacy_Contract__c = true,
                        SalesforceLegacyContractID__c = contractKey, 
                        SalesforceLegacyAccountID__c = legacyContractAccountId
                    )
                );
            }
        }
        
        Set<String> contractKeysWithSubs = new Set<String>(contractKeyToZSubId.keySet());
        cpqContractMap.keySet().retainAll(contractKeysWithSubs);
        
        System.debug('Contracts - '+cpqContractMap.size());
        

        //--Insert contracts--//
        try{
            Database.UpsertResult[] durs = Database.upsert(cpqContractMap.values(), false);
            processSaveResults(durs, cpqContractMap, 'Contract');
            
        } catch (Exception e) {
            System.debug('Exception thrown on contract insert');
            System.debug(e.getStackTraceString());
            throw e;
        }

        //---Insert Subscriptions---//
        Map<String, SBQQ__Subscription__c> baseBundleInsertMap = new Map<String, SBQQ__Subscription__c>();
        for(String contractKey : cpqContractMap.keySet()) {
            Contract cpqContract = cpqContractMap.get(contractKey);
            
            for(String zSubId : contractKeyToZSubId.get(contractKey)) {
                
                SBQQ__Subscription__c baseBundleSub = cpqSubscriptionMap.get(zSubId+'basebundle');
                baseBundleSub.SBQQ__Contract__c = cpqContract.Id;
                baseBundleInsertMap.put(zSubId+'basebundle', baseBundleSub);
            }
        }

        try{
            Database.SaveResult[] dsrs = Database.insert(cpqSubscriptionMap.values(), false);
            processSaveResults(dsrs, cpqSubscriptionMap, 'SBQQ__Subscription__c');
            
        } catch (Exception e) {
            System.debug('Exception thrown on cpq subscription insert');
            System.debug(e.getStackTraceString());
            throw e;
        }

        //---Upsert Subscriptions with the basebundle dependencies set---//
        //---Also update the SBQQ Number so the Quote Editor knows---//
        for(String contractKey : cpqContractMap.keySet()) {

            //for the num check if previosuly saved subs exist, since the number has 
            //to be unique and positions the quote line correctly
            Integer num = 1;
            Contract cpqContract = cpqContractMap.get(contractKey);
            if(cpqContract.SBQQ__Subscriptions__r != null && cpqContract.SBQQ__Subscriptions__r.size() > 0) {
                num = cpqContract.SBQQ__Subscriptions__r.size();
            }

            for(String zSubId : contractKeyToZSubId.get(contractKey)) {
                
                SBQQ__Subscription__c baseBundleSub = cpqSubscriptionMap.get(zSubId+'basebundle');
                baseBundleSub.SBQQ__Number__c = num++;

                for(String zRatePlanId : zSubToSubRatePlanIds.get(zSubId)) {
                    SBQQ__Subscription__c cpqsub;
                    if(cpqSubscriptionMap.get(zRatePlanId) != null) {
                        cpqsub = cpqSubscriptionMap.get(zRatePlanId);
                        cpqsub.SBQQ__Contract__c = cpqContract.Id;
                        cpqSub.SBQQ__OptionLevel__c = 1;
                        cpqSub.SBQQ__RequiredById__c = baseBundleSub.Id;
                        cpqSub.SBQQ__ProductOption__c = 
                            productBundleOptionMap.get(baseBundleSub.SBQQ__Product__c).get(cpqSub.SBQQ__Product__c);
                        cpqSub.SBQQ__OptionType__c = 'Related Product';
                        cpqSub.SBQQ__Number__c = num++;
                    }
                }
            }
        }

        try{
            Database.UpsertResult[] dsrs = Database.upsert(cpqSubscriptionMap.values(), false);
            processSaveResults(dsrs, cpqSubscriptionMap, 'SBQQ__Subscription__c');
            
        } catch (Exception e) {
            System.debug('Exception thrown on cpq subscription insert');
            System.debug(e.getStackTraceString());
            throw e;
        }

        if(!err_tasks.isEmpty()) {
            insert err_tasks;
        }
    }
    
    @TestVisible
    private static void processSaveResults(List<Database.SaveResult> dsrs, Map<String, SObject> records, String objtype) {
        Integer i=0;
        for(Database.SaveResult dsr : dsrs) {
            if(dsr.isSuccess()) { 
                i++;
                continue; 
            }
            
            else {
                Id accId = (Id)records.values()[i].get('SBQQ__Account__c');
                String err_str = '';
                for(Database.Error err : dsr.getErrors()) {
                    err_str += err.getStatusCode()+'\n';   
                    err_str += err.getMessage()+'\n';
                    err_str += String.join(err.getFields(),';')+'\n';
                    err_str += JSON.serialize(records.values()[i]);
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                }
                
                Task t = setErrorTask(accId, err_str); 
                err_tasks.add(t);
            }
            i++;
        }
    }
    
    @TestVisible
    private static void processSaveResults(List<Database.UpsertResult> durs, Map<String, SObject> records, String objtype) {
        Integer i=0;
        String accountField = (objtype == 'Contract'?'AccountId':'SBQQ__Account__c');
        for(Database.UpsertResult dur : durs) {
            if(dur.isSuccess()) { 
                i++;
                continue; 
            }
            
            else {
                Id accId = (Id)records.values()[i].get(accountField);
                String err_str = '';
                for(Database.Error err : dur.getErrors()) {
                    err_str += err.getStatusCode()+'\n';   
                    err_str += err.getMessage()+'\n';
                    err_str += String.join(err.getFields(),';')+'\n';
                    err_str += JSON.serialize(records.values()[i]);
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                }
                
                Task t = setErrorTask(accId, err_str);
                err_tasks.add(t);                    
            }
            i++;
        }
    }

    public static Task setErrorTask(Id recordId, String errmessage) {
        Task t = new Task();
        t.Subject = 'Contract Backfill Error';
        t.WhatId = recordId;
        t.OwnerId = UserInfo.getUserId();
        t.Status = 'New';
        t.Type = 'Call';
        t.Description = errmessage;
		return t;
    }

    private static Map<String,Contract> getSavedContracts() {
        Map<String,Contract> existingContracts = new Map<String,Contract>();

        List<Contract> contracts = [SELECT Id, AccountId, StartDate, EndDate, OwnerId, 
                SalesforceLegacyContractID__c, SalesforceLegacyAccountID__c,
                (SELECT Id, SBQQ__Number__c FROM SBQQ__Subscriptions__r) 
                FROM Contract WHERE SalesforceLegacyContractID__c IN :legacyContractIds];

        for (Contract crt : contracts) {
            existingContracts.put(crt.SalesforceLegacyContractID__c, crt);
        }

        return existingContracts;
    }

    // --Static variables and static code-- //

    public static String baseBundleProdId;
    
    public static Map<String,Product2> prpIdProductMap = new Map<String,Product2>();
    
    public static Map<Id, Map<Id, Id>> productBundleOptionMap = new Map<Id, Map<Id, Id>>();
    
    public static Id stdPriceBookId;

    static {
        if (!Test.isRunningTest()) {
            stdPriceBookId = [SELECT Id FROM Pricebook2 WHERE isStandard = true limit 1].Id;
        }

    	List<Product2> findBaseBundle = [select Id FROM Product2 WHERE Name = 'CG Base Bundle' LIMIT 1];
        if(!findBaseBundle.isEmpty()) {
           baseBundleProdId = findBaseBundle[0].Id;
        }
    
        for (Product2 prod : [SELECT Id, Name, Family, Zuora_Product_Rate_Plan_ID__c,
            Zuora_Product_Rate_Plan_Charge_ID__c, Zuora_Product_Rate_Plan_Charge_Disc_ID__c
            FROM Product2]) {

            prpIdProductMap.put(prod.Zuora_Product_Rate_Plan_ID__c, prod);
        }
    
        //build the product options map - configured sku => (optional sku => option id)
        List<SBQQ__ProductOption__c> prodOpts = [SELECT Id, SBQQ__OptionalSKU__c, SBQQ__ConfiguredSKU__c, 
            SBQQ__Number__c FROM SBQQ__ProductOption__c];
        
        for(SBQQ__ProductOption__c sbpo : prodOpts) {
            if (!productBundleOptionMap.containsKey(sbpo.SBQQ__ConfiguredSKU__c)) {
                productBundleOptionMap.put(sbpo.SBQQ__ConfiguredSKU__c, new Map<Id, Id>());
            }
            productBundleOptionMap.get(sbpo.SBQQ__ConfiguredSKU__c).put(sbpo.SBQQ__OptionalSKU__c, sbpo.Id);
        }
    }
}
@IsTest
private class Batch_FindBaseBundleFulAccountDupes_Test {
    
    @testsetup static void testUserDataSetup() {
        List<Account> accounts = new List<Account>();
        Account acc_US = TestDataFactory.createAccounts(1)[0];
        acc_US.BillingCountryCode = 'US';
        acc_US.CurrencyIsoCode = 'USD';
        acc_US.Account_Category__c = 'Independent - Small';
        acc_US.Product_Activation_Status__c = 'Active';
        acc_US.RecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        accounts.add(acc_US);
        insert accounts;
        
        List<Product2> products = TestDataFactory.createProducts(10);
        products[0].Name = 'CG Base Bundle';
        products[0].ProductCode = 'CG-BASE';
        products[1].Name = 'Enhanced';
        products[2].Name = 'Display';
        products[3].Name = 'Area Boost';
        products[4].Name = 'PistonHeads - Enhanced Placement';
        products[5].Name = 'LeadAI';
        products[6].Name = 'Highlight';
        products[7].Name = '360VinSpin';
        products[8].Name = 'Convert';
        
        products[9].Name = 'Standalone Bundle';
        products[9].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
        
        products[0].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
        products[1].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
        products[2].Family = ConstantsUtil.PRODUCT_DIGITAL_ADVERTISING;
        products[3].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
        products[4].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
        products[4].Source__c = ConstantsUtil.PRODUCT_PISTONHEADS;
        products[5].Family = ConstantsUtil.PRODUCT_FAMILY_DATA;
        products[6].Family = ConstantsUtil.PRODUCT_FAMILY_LISTINGS;
        products[7].Family = ConstantsUtil.PRODUCT_FAMILY_WEBSITE_AND_INVENTORY;
        products[8].Family = ConstantsUtil.PRODUCT_DIGITAL_RETAIL;
        
        products[1].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_CORE;
        products[2].Product_Category__c = ConstantsUtil.PRODUCT_DIGITAL_ADVERTISING;
        products[3].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_ADDON;
        products[4].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_CORE;
        products[5].Product_Category__c = ConstantsUtil.PRODUCT_FAMILY_DATA;
        products[6].Product_Category__c = ConstantsUtil.PRODUCT_CATEGORY_ADDON;
        products[7].Product_Category__c = ConstantsUtil.PRODUCT_FAMILY_WEBSITE_AND_INVENTORY;
        products[8].Product_Category__c = ConstantsUtil.PRODUCT_DIGITAL_RETAIL;
        
        products[1].Sub_Category__c = 'Enhanced';
        products[3].Sub_Category__c = 'Area Boost';
        products[4].Sub_Category__c = 'Enhanced';
        products[5].Sub_Category__c = ConstantsUtil.PRODUCT_FAMILY_DATA;
        products[6].Sub_Category__c = 'Highlight';
        products[7].Sub_Category__c = ConstantsUtil.PRODUCT_FAMILY_WEBSITE_AND_INVENTORY;
        products[8].Sub_Category__c = ConstantsUtil.PRODUCT_DIGITAL_RETAIL;
        
        // set Display Focus subcategory picklist via getDescribe to avoid strange issue of picklist complaining
        Schema.DescribeFieldResult subCategoryDescription = Product2.Sub_Category__c.getDescribe();
        List<Schema.PicklistEntry> subCategoryValues = subCategoryDescription.getPicklistValues();
        for (Schema.PicklistEntry subCategory : subCategoryValues) {
            if (subCategory.getValue().contains('Display') && subCategory.getValue().contains('Focus')) {
                products[2].Sub_Category__c = subCategory.getValue();
                continue;
            }
        }
        insert products;
        
        // set up one contract + subscription for each account
        List<Contract> contracts = new List<Contract>();
        for(Account acc : accounts) {
            Contract con = TestDataFactory.createContract(acc.Id);
            con.StartDate = System.today();
            con.EndDate = System.today().addMonths(5).toStartOfMonth().addDays(-1);
            con.CurrencyIsoCode = acc.CurrencyIsoCode;
            contracts.add(con);
        }
        insert contracts;
        
        List<SBQQ__Subscription__c> subs = new List<SBQQ__Subscription__c>();
        Map<String,Id> baseBundleByCurrencyMap = new Map<String,Id>();
        for(Contract con : contracts) {
            con.Status = 'Activated';
            
            List<Product2> productsPerCountry1 = new List<Product2>();
            productsPerCountry1.add(products[0]);
            productsPerCountry1.add(products[1]);
            productsPerCountry1.add(products[2]);
            productsPerCountry1.add(products[3]);
            productsPerCountry1.add(products[5]);
            productsPerCountry1.add(products[6]);
            productsPerCountry1.add(products[7]);
            productsPerCountry1.add(products[8]);
            
            for(SBQQ__Subscription__c sub : TestDataFactory.createCPQSubsForProducts(productsPerCountry1, con.AccountId)) {
                sub.SBQQ__Contract__c = con.Id;
                sub.Provisioning_Status__c = 'Activated';
                sub.CurrencyIsoCode = con.CurrencyIsoCode;
                if(sub.SBQQ__Product__c == products[1].Id) sub.SBQQ__NetPrice__c = 1200;
                if(sub.SBQQ__Product__c == products[2].Id) sub.SBQQ__NetPrice__c = 2000;
                if(sub.SBQQ__Product__c == products[3].Id) sub.SBQQ__NetPrice__c = 1000;
                if(sub.SBQQ__Product__c == products[4].Id) sub.SBQQ__NetPrice__c = 1500;
                if(sub.SBQQ__Product__c == products[5].Id) sub.SBQQ__NetPrice__c = 700;
                if(sub.SBQQ__Product__c == products[6].Id) sub.SBQQ__NetPrice__c = 150;
                if(sub.SBQQ__Product__c == products[7].Id) sub.SBQQ__NetPrice__c = 500;
                if(sub.SBQQ__Product__c == products[8].Id) sub.SBQQ__NetPrice__c = 400;
                subs.add(sub);
            }
            
            List<Product2> productsPerCountry = new List<Product2>();
            productsPerCountry.add(products[0]);
            productsPerCountry.add(products[1]);
            productsPerCountry.add(products[2]);
            productsPerCountry.add(products[3]);
                
            for(SBQQ__Subscription__c sub : TestDataFactory.createCPQSubsForProducts(productsPerCountry, con.AccountId)) {
                sub.SBQQ__Contract__c = con.Id;
                sub.Provisioning_Status__c = 'Activated';
                sub.CurrencyIsoCode = con.CurrencyIsoCode;
                if(sub.SBQQ__Product__c == products[1].Id) sub.SBQQ__NetPrice__c = 1200;
                if(sub.SBQQ__Product__c == products[2].Id) sub.SBQQ__NetPrice__c = 2000;
                if(sub.SBQQ__Product__c == products[3].Id) sub.SBQQ__NetPrice__c = 1000;
                if(sub.SBQQ__Product__c == products[4].Id) sub.SBQQ__NetPrice__c = 1500;
                subs.add(sub);
            }
            
            List<Product2> additionalProdList = new List<Product2>{products[1]};
            
            SBQQ__Subscription__c futureDatedSub = TestDataFactory.createCPQSubsForProducts(additionalProdList, con.AccountId)[0];
            futureDatedSub.SBQQ__SubscriptionStartDate__c = System.today().addDays(15);
            futureDatedSub.SBQQ__Contract__c = con.Id;
            futureDatedSub.SBQQ__NetPrice__c = 1000;
            subs.add(futureDatedSub);
        }
        update contracts;
        insert subs;
        
        for(SBQQ__Subscription__c sub : subs) {
            if(sub.SBQQ__Product__c == products[0].Id) {
                baseBundleByCurrencyMap.put(sub.CurrencyIsoCode, sub.Id);
            }
        }
        
        for(SBQQ__Subscription__c sub : subs) {
            if((sub.SBQQ__Product__c != products[0].Id)
               && (sub.SBQQ__SubscriptionStartDate__c == null || sub.SBQQ__SubscriptionStartDate__c <= System.today())
              ) {
                  sub.SBQQ__RequiredById__c = baseBundleByCurrencyMap.get(sub.CurrencyIsoCode);
              }
        }
        update subs;
        
    }
    
    @IsTest
    static void testScheduleCMRRBatch() {
        Test.startTest();
            Database.executeBatch(new Batch_FindBaseBundleFulAccountDupes());
        Test.stopTest();
        Database.executeBatch(new Batch_ProcessBaseBundleFlaggedContracts());
    }
}
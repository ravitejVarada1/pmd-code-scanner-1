@isTest
private class QuoteVal_LocationDataObject_Test {
    static final String CPQ_SUB = 'CpqSub';
    static final String QUOTE_EXISTING = 'Existing';
    static final String QUOTE_ADDED = 'Added';
    static final String QUOTE_REMOVED = 'Removed';
    @TestSetup
    static void makeData(){

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        // insert franchise acocunt
        Account a = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        a.Name = 'Account1';
        a.Account_Status__c = 'Active';
        a.Type = 'Customer';
        insert a;

        Opportunity o = TestDataFactory.createOpps(a.Id, 1)[0];

        Product2[] products = new List<Product2>();
        products.add(new Product2(
            Name = 'CG Base Bundle',
            IsActive = true,
            ProductCode = 'CG-BASE'
        ));
        products.add(new Product2(
            Name = 'Enhanced Placement',
            IsActive = true,
            ProductCode = 'ENH-PLC',
            Family = 'Listings',
            Product_Category__c = 'Core Products',
            Sub_Category__c = 'Enhanced'
        ));
        products.add(new Product2(
            Name = 'Enhanced Package',
            IsActive = true,
            ProductCode = 'PKG-ENH',
            Product_Category__c = 'Core Products',
            Sub_Category__c = 'Enhanced'
        ));
        insert products;

        ID pricebookId = Test.getStandardPricebookId();
        PricebookEntry[] pbeList = new List<PricebookEntry>();
        
        for (Product2 p : products) {
            pbeList.add(
                new PricebookEntry(
                    Product2Id = p.Id,
                    Pricebook2Id = pricebookId,
                    CurrencyIsoCode = 'USD',
                    UnitPrice = 100,
                    IsActive = true
                )
            );
        }
        insert pbeList;

        SBQQ__Quote__c quote = new SBQQ__Quote__c();
        quote.SBQQ__Account__c = a.id;
        quote.SBQQ__Opportunity2__c = o.id;
        quote.SBQQ__PricebookId__c = pricebookId;
        insert quote;

        SBQQ__QuoteLine__c ql = new SBQQ__QuoteLine__c();
        ql.SBQQ__Quote__c = quote.id;
        ql.SBQQ__Product__c = products[2].id;
        ql.SBQQ__PricebookEntryId__c = pbeList[2].id;
        ql.SBQQ__Quantity__c = 1;
        insert ql;
    }

    @IsTest
    static void addLineTest(){
        Test.startTest();
        SBQQ__Quoteline__c ql = [SELECT Id, SBQQ__Product__c, SBQQ__ProductName__c, SBQQ__ProductCode__c, Product_Category__c, 
                                SBQQ__ProductFamily__c, SBQQ__Product__r.Sub_Category__c
                                FROM SBQQ__Quoteline__c WHERE SBQQ__Quantity__c > 0 LIMIT 1];
        QuoteVal_LocationDataObject ldo = new QuoteVal_LocationDataObject();
        ldo.addLine(ql, QUOTE_ADDED);
        Test.stopTest();
        System.assertEquals(true, ldo.productIdsByAction.get(QUOTE_ADDED).size() > 0);
    }

    @IsTest
    static void getHasProductIds(){
        QuoteVal_LocationDataObject ldo = new QuoteVal_LocationDataObject();
        Set<Id> returnSet = new Set<Id>(ldo.productIdsByAction.get(CPQ_SUB));
        returnSet.addAll(ldo.productIdsByAction.get(QUOTE_EXISTING));
        returnSet.addAll(ldo.productIdsByAction.get(QUOTE_ADDED));
        System.assertEquals(returnSet.size(), ldo.getHasProductIds().size());
    }

    @IsTest
    static void getHasValidationProductIds(){
        QuoteVal_LocationDataObject ldo = new QuoteVal_LocationDataObject();
        Set<Id> returnSet = new Set<Id>(ldo.validationSettingsProductIdsByAction.get(CPQ_SUB));
        returnSet.addAll(ldo.validationSettingsProductIdsByAction.get(QUOTE_EXISTING));
        returnSet.addAll(ldo.validationSettingsProductIdsByAction.get(QUOTE_ADDED));
        System.assertEquals(returnSet.size(),ldo.getHasValidationProductIds().size());
    }

    @IsTest
    static void getValidationSettingsProductIdsInQuote(){
        QuoteVal_LocationDataObject ldo = new QuoteVal_LocationDataObject();
        Set<Id> returnSet = new Set<Id>(ldo.validationSettingsProductIdsByAction.get(QUOTE_EXISTING));
        returnSet.addAll(ldo.validationSettingsProductIdsByAction.get(QUOTE_ADDED));
        System.assertEquals(returnSet.size(),ldo.getValidationSettingsProductIdsInQuote().size());
    }

    @IsTest
    static void getHasQuoteLines(){
        QuoteVal_LocationDataObject ldo = new QuoteVal_LocationDataObject();
        List<SBQQ__QuoteLine__c> returnList = new List<SBQQ__QuoteLine__c>(ldo.quoteLinesByAction.get(QUOTE_ADDED));
        returnList.addAll(ldo.quoteLinesByAction.get(QUOTE_EXISTING));
        System.assertEquals(returnList.size(),ldo.getHasQuoteLines().size());
    }
}
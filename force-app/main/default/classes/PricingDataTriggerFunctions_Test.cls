@isTest
public class PricingDataTriggerFunctions_Test {
    @testSetup static void setupRecords(){
        
        List <Account> testAccounts = new List <Account>();
        testAccounts.add(testDataFactory.createAccounts(1, 'Location')[0]);
        testAccounts.add(testDataFactory.createAccounts(1, 'Group')[0]);
        insert testAccounts;
        
        testAccounts[0].parentId = testAccounts[1].Id;
        testAccounts[0].Name = 'LocationWithPricingData';
        update testAccounts;
        
        List <Product2> testProducts = TestDataFactory.createProducts(1);
        testProducts[0].Name = 'prod1_testCheckForDuplicates';
        insert testProducts;
        
        List <Pricing_Data__c> pricingDataToInsert = new List <Pricing_Data__c>{new Pricing_Data__c(
            Account__c = testAccounts[0].Id,
            CurrencyIsoCode = 'USD',
            Product__c = testProducts[0].Id,
            Renewal_Price__c = 500,
            Minimum_Price__c = 300,
            Price__c = 400,
            Active__c = true
        )};
            
        insert pricingDataToInsert;
    }
    
    @isTest
    public static void testCheckForDuplicates(){
        Account locationWithPricingData = [SELECT Id
                                           FROM Account
                                           WHERE Name = 'LocationWithPricingData'
                                           LIMIT 1];
        
        Id productId = [SELECT Id
                        FROM Product2
                        WHERE Name = 'prod1_testCheckForDuplicates'][0].Id;
        
        List <Pricing_Data__c> pricingDataToInsert = new List <Pricing_Data__c>{new Pricing_Data__c(
            Account__c = locationWithPricingData.Id,
            CurrencyIsoCode = 'USD',
            Product__c = productId,
            Renewal_Price__c = 500,
            Minimum_Price__c = 300,
            Price__c = 400,
            Active__c = true
        )};
            
            List <Database.SaveResult> pricingDataInsertFail = Database.Insert(pricingDataToInsert, false);
        
        for (Database.SaveResult sr : pricingDataInsertFail){
            System.assertEquals(false, sr.isSuccess());
            for(Database.Error err : sr.getErrors()) {
                System.assertEquals('FIELD_CUSTOM_VALIDATION_EXCEPTION', string.valueOf(err.getStatusCode()));
                System.assert(err.getMessage().contains('There is already an active Pricing Data record for this product'));
            }
        }
        
        update [SELECT Id
                FROM Pricing_Data__c];
        
        List <Pricing_Data__c> pricingDataToInsertNonActive = new List <Pricing_Data__c>{new Pricing_Data__c(
            Account__c = locationWithPricingData.Id,
            CurrencyIsoCode = 'USD',
            Product__c = productId,
            Renewal_Price__c = 500,
            Minimum_Price__c = 300,
            Price__c = 400,
            Active__c = false
        )};
            
        insert pricingDataToInsertNonActive;
        

    }
    
    

    
    
    
    
    
    
    
    
}
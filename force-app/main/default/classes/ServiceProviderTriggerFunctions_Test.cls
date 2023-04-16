/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         dmorrill
* modifiedBy:     dmorrill
* created:        03/11/2021
* modified:       03/11/2021
* created jira:   BR-367 & BR-368
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class ServiceProviderTriggerFunctions_Test {
    
    private static final String DEALER_NAME = 'DEALER';
    private static final String ULT_DEALER_NAME = 'DEALER - ULT';
    @testSetup
    static void testSetup(){
        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
		ID corpAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Corporate_Account');
        
        Account corpAccount = TestDataFactory.createSingleAccount(corpAccountRecordTypeId);
        corpAccount.Name = 'CORP';
        insert corpAccount;
        ID corpAccountId = corpAccount.Id;

        List<Account> dealerAccounts = TestDataFactory.createAccounts(2, dealerAccountRecordTypeId);
        
        dealerAccounts[0].Name = DEALER_NAME;
        dealerAccounts[0].ParentId = corpAccountId;
        dealerAccounts[0].Ultimate_Parent_Account__c = corpAccountId;
        
        dealerAccounts[1].Name = ULT_DEALER_NAME;
        
        insert dealerAccounts;
        ID dealerAccountId = dealerAccounts[0].Id;
        ID ultDealerAccountId = dealerAccounts[1].Id;
        
        List<Service_Provider__c> testSpids = new List<Service_Provider__c>();
        testSpids.add(TestDataFactory.createSingleServiceProvider(ultDealerAccountId));
        for (Integer i=0; i<3; i++){
            Service_Provider__c spid = TestDataFactory.createSingleServiceProvider(dealerAccountId);
            spid.Used_Inventory_Avg__c = 3;
            spid.Total_Used_Inventory_Units__c = 100;
            spid.Used_Cars_Fair_Qty__c = 10;
            spid.Used_Cars_Good_Qty__c = 10;
            spid.Used_Cars_Great_Qty__c = 30;
            
            if (i==0){
                spid.Dealer_Type__c = ServiceProviderTriggerFunctions.DEALER_TYPE_NEW;
            }
            
            testSpids.add(spid);
        }

        //Aparna's test SP
        Service_provider__c sp = new Service_provider__c();
		sp.Name = 'testing Sp';
		sp.Service_Provider_Id__c = 1111;
        testSPids.add(sp);

		insert testSpids;
    }

    static testMethod void checkTrigger(){
		Account ac = [SELECT ID, Name FROM Account WHERE Name = 'testing sp'];
        system.assertEquals('testing Sp', ac.Name);
	}
    
    //- Jira: BR-367 & BR-368 | Method: ServiceProviderTriggerFunctions.updateUltimateParentRef
    //- Purpose: Verifies that Ultimate Parent Account on service providers gets updated on insert
    @isTest
    static void checkUltParentInsert(){
        for (Service_Provider__c sp : [SELECT Ultimate_Parent_Account__c, Account__r.Name, Account__r.Ultimate_Parent_Account__c
                                   FROM Service_Provider__c]){
            if (sp.Account__r.Name == DEALER_NAME){
                System.assertEquals(sp.Account__r.Ultimate_Parent_Account__c, sp.Ultimate_Parent_Account__c);
            }else if (sp.Account__r.Name == ULT_DEALER_NAME){
                System.assertEquals(sp.Account__c, sp.Ultimate_Parent_Account__c);
            }
        }                        
    }
    
    //- Jira: BR-367 & BR-368 | Method: ServiceProviderTriggerFunctions.updateUltimateParentRef
    //- Purpose: Verifies that Ultimate Parent Account on service providers gets updated on update
    @isTest
    static void checkUltParentUpdate(){ 
        ID newAccountId = [SELECT Id
                          FROM Account
                          WHERE Name = :ULT_DEALER_NAME
                          LIMIT 1][0].Id;
        
        Service_Provider__c spidToUpdate = [SELECT Id
                                           FROM Service_Provider__c
                                           WHERE Account__r.Name = :DEALER_NAME
                                           LIMIT 1];
        
        spidToUpdate.Account__c = newAccountId;
        
        Test.startTest();
        update spidToUpdate;
        Test.stopTest();
        
        spidToUpdate = [SELECT Ultimate_Parent_Account__c
                        FROM Service_Provider__c
                        WHERE Id = :spidToUpdate.Id
                        LIMIT 1];
        
        System.assertEquals(newAccountId, spidToUpdate.Ultimate_Parent_Account__c);                   
    }
    
    
    //- Jira: BR-367 & BR-368 | Method: ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel
    //- Purpose: Verifies that the related account's Dealer Type field is set on spid insert 
    @isTest
    static void checkAccountDealerTypeInsert(){
        Account dealerAccount = [SELECT Dealer_Type__c
                                 FROM Account
                                 WHERE Name = :DEALER_NAME
                                 LIMIT 1];
        
        System.assertEquals(ServiceProviderTriggerFunctions.DEALER_TYPE_NEW, dealerAccount.Dealer_Type__c);
    }
    
    //- Jira: BR-367 & BR-368 | Method: ServiceProviderTriggerFunctions.checkAccountFieldsUpdate
    //- Purpose: Verifies that the related account's Dealer Type field is set on spid update 
    @isTest
    static void checkAccountDealerTypeUpdate(){
        Service_Provider__c spidToUpdate = [SELECT Id
                                           FROM Service_Provider__c
                                           WHERE Dealer_Type__c = :ServiceProviderTriggerFunctions.DEALER_TYPE_NEW
                                           LIMIT 1];
        
        spidToUpdate.Dealer_Type__c = ServiceProviderTriggerFunctions.DEALER_TYPE_USED;
        
        Test.startTest();
        update spidToUpdate;
        Test.stopTest();
        
        Account dealerAccount = [SELECT Dealer_Type__c
                                 FROM Account
                                 WHERE Name = :DEALER_NAME
                                 LIMIT 1];
        
        System.assertEquals(ServiceProviderTriggerFunctions.DEALER_TYPE_USED, dealerAccount.Dealer_Type__c);
    }
    
    //- Jira: BR-367 & BR-368 | Method: ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel
    //- Purpose: Verifies that the related account's Dealer Type field is set on spid delete
    @isTest
    static void checkAccountDealerTypeDelete(){
        Service_Provider__c spidToUpdate = [SELECT Id
                                            FROM Service_Provider__c
                                            WHERE Dealer_Type__c = :ServiceProviderTriggerFunctions.DEALER_TYPE_NEW
                                            LIMIT 1];
        
        Test.startTest();
        Delete spidToUpdate;
        Test.stopTest();
        
        Account dealerAccount = [SELECT Dealer_Type__c
                                 FROM Account
                                 WHERE Name = :DEALER_NAME
                                 LIMIT 1];
                                 
        System.assertEquals(ServiceProviderTriggerFunctions.DEALER_TYPE_USED, dealerAccount.Dealer_Type__c);
    }
    
    //- Jira: BR-367 & BR-368 | Method: ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel
    //- Purpose: Verifies that the related account's Dealer Type field is set on spid undelete
    @isTest
    static void checkAccountDealerTypeUndelete(){
        Service_Provider__c spidToUpdate = [SELECT Id
                                            FROM Service_Provider__c
                                            WHERE Dealer_Type__c = :ServiceProviderTriggerFunctions.DEALER_TYPE_NEW
                                            LIMIT 1];
        Delete spidToUpdate;
        Test.startTest();
        Undelete spidToUpdate;
        Test.stopTest();
        
        Account dealerAccount = [SELECT Dealer_Type__c
                                 FROM Account
                                 WHERE Name = :DEALER_NAME
                                 LIMIT 1];
        
        System.assertEquals(ServiceProviderTriggerFunctions.DEALER_TYPE_NEW, dealerAccount.Dealer_Type__c);
    }
    
    //- Jira: BR-845 | Method: ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel
    //- Purpose: Verifies that the related account's InventoryFairOrAbove__c field updates on insert
    @isTest
    static void checkInventoryFairOrAboveInsert(){
        Decimal invFairOrAbove = [SELECT InventoryFairOrAbove__c 
                                  FROM Account
                                  WHERE Id IN (SELECT Account__c
                                               FROM Service_Provider__c
                                               WHERE Total_Used_Inventory_Units__c != null)
                                  LIMIT 1][0].InventoryFairOrAbove__c;
        
        System.assertEquals(50, invFairOrAbove);
    }
    
    //- Jira: BR-845 | Method: ServiceProviderTriggerFunctions.checkAccountFieldsUpdate
    //- Purpose: Verifies that the related account's InventoryFairOrAbove__c field updates on update
    @isTest
    static void checkInventoryFairOrAboveUpdate(){   
        List<Service_Provider__c> spidsToUpdate = [SELECT Used_Cars_Fair_Qty__c,
                                                   Used_Cars_Good_Qty__c,
                                                   Used_Cars_Great_Qty__c,
                                                   Used_Cars_High_Qty__c 
                                                   FROM Service_Provider__c
                                                   WHERE Total_Used_Inventory_Units__c != null];
        
        for (service_provider__c spid : spidsToUpdate){
            spid.Used_Cars_Fair_Qty__c = 50;
            spid.Used_Cars_Good_Qty__c = 20;
            spid.Used_Cars_Great_Qty__c = 20;
        }
        
        Test.startTest();
        update spidsToUpdate;
        Test.stopTest();
        
        Decimal invFairOrAbove = [SELECT InventoryFairOrAbove__c 
                                  FROM Account
                                  WHERE Id IN (SELECT Account__c
                                               FROM Service_Provider__c
                                               WHERE Total_Used_Inventory_Units__c != null)
                                  LIMIT 1][0].InventoryFairOrAbove__c;
        
        System.assertEquals(90, invFairOrAbove);
    }
    
    //- Jira: BR-845 | Method: ServiceProviderTriggerFunctions.checkAccountFieldsInsAndDel
    //- Purpose: Verifies that the related account's InventoryFairOrAbove__c field update on delete and undelete
    @isTest
    static void checkInventoryFairOrAboveDeleteAndUndelete(){   
        List<Service_Provider__c> spidsToUpdate = [SELECT Id
                                                   FROM Service_Provider__c
                                                   WHERE Total_Used_Inventory_Units__c != null];

        Test.startTest();
        delete spidsToUpdate;
        undelete spidsToUpdate;
        Test.stopTest();
        
        Decimal invFairOrAbove = [SELECT InventoryFairOrAbove__c 
                                  FROM Account
                                  WHERE Id IN (SELECT Account__c
                                               FROM Service_Provider__c
                                               WHERE Total_Used_Inventory_Units__c != null)
                                  LIMIT 1][0].InventoryFairOrAbove__c;
        
        System.assertEquals(50, invFairOrAbove);
    }

    //- Jira: SA-255 | Method: ServiceProviderTriggerFunctions.checkSPDenyUndenyScenarios
    //- Purpose: Verifies that the case is generated for deny/undeny updates
    @isTest
    static void checkSPDenyUndenyScenariosTest(){
        Service_Provider__c spidToUpdate = [SELECT Id,Account__c 
                                            FROM Service_Provider__c
                                            WHERE Dealer_Type__c = :ServiceProviderTriggerFunctions.DEALER_TYPE_NEW
                                            LIMIT 1];
        Test.startTest();
        spidToUpdate.reviewStatus__c = 'DENIED';
        update spidToUpdate;
        Test.stopTest();

        List<Case> cs = [SELECT Id,Subject FROM Case WHERE AccountId=:spidToUpdate.Account__c AND Subject = 'Service Provider record Denied'];
        System.assert(cs.isEmpty());
    }
    
    //- Jira: SA-255 | Method: ServiceProviderTriggerFunctions.checkSPDenyUndenyScenarios
    //- Purpose: Verifies that the case is generated for deny/undeny updates
    @isTest
    static void checkSPDenyUndenyScenariosTest2(){
        
        List<Service_Provider__c> updateSP = new List<Service_Provider__c>();
        
        for(Service_Provider__c spRec : [
            SELECT Id,Account__c 
            FROM Service_Provider__c
        ]){
            spRec.reviewStatus__c = 'DENIED';
            updateSP.add(spRec);
        }
        Test.startTest();
        update updateSP;
        Test.stopTest();

        List<Case> cs = [SELECT Id,Subject FROM Case WHERE AccountId=:updateSP[0].Account__c AND Subject = 'Service Provider record Denied'];
        System.assert(!cs.isEmpty());
    }
    
    //- Jira: SA-255 | Method: ServiceProviderTriggerFunctions.checkSPDenyUndenyScenarios
    //- Purpose: Verifies that the case is generated for deny/undeny updates
    @isTest
    static void checkSPDenyUndenyScenariosTest3(){
        Service_Provider__c spidToUpdate = [SELECT Id,Account__c 
                                            FROM Service_Provider__c
                                            WHERE Dealer_Type__c = :ServiceProviderTriggerFunctions.DEALER_TYPE_NEW
                                            LIMIT 1];
        Test.startTest();
        spidToUpdate.reviewStatus__c = 'DENIED';
        update spidToUpdate;
        
        spidToUpdate.reviewStatus__c = 'SUBMITTED';
        update spidToUpdate;
        Test.stopTest();
        
        List<Case> cs1 = [SELECT Id,Subject FROM Case WHERE AccountId=:spidToUpdate.Account__c AND Subject = 'Service Provider record Approved'];
        System.assert(!cs1.isEmpty());
    }
}
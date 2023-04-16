/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         prabhu
* modifiedBy:     prabhu
* created:        05/27/2022
* modified:       05/27/2022
* created jira:   CA-611
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class ConsumerAccountTriggerFunctions_Test {
    
    @isTest
    static void testPhoneUpdate(){
       
        List<Account> accs = TestDataFactory.createPersonalAccounts(1);
        insert accs;
        List<Offer__c> LowerFunneloffer = TestDataFactory.createOffer(1,accs);
        insert LowerFunneloffer;
        
        for(Account ac:accs){
            ac.Phone='535-368-9089';
            update ac;
        }
		
 		Account A1 = [select Id,Phone,Unformatted_Phone_Numer__c From account where phone='535-368-9089' LIMIT 1];      
        System.assertEquals('535-368-9089', A1.Phone);
        System.assertEquals('5353689089', A1.Unformatted_Phone_Numer__c);
        
    }

    @isTest
    static void testAccountDelete() {
        List<Account> accountToDelete = TestDataFactory.createAccounts(1);

        Profile p = [SELECT Id FROM Profile WHERE Name='Consumer and Dealer Support Rep'];
        User userSobject = TestDataFactory.createUser(true,p);
        insert userSobject;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'AccountMerge'];
        insert new PermissionSetAssignment(AssigneeId = userSobject.id, PermissionSetId = ps.Id);

        String errorMessage = 'You do not have permissions to delete dealer accounts. Contact your administrator for help.';

        System.runAs(userSobject) {
            try
                {
                    insert accountToDelete;
                    Test.startTest();
                    delete accountToDelete;
                    Test.stopTest();
                }
            catch(Exception e) 
                {
                    Boolean expectedExceptionThrown =  e.getMessage().contains(errorMessage) ? true : false;
                    System.assertEquals(expectedExceptionThrown, true);
                }
        }
        
    }

    @isTest
    static void testAccountMerge() {
        List<Account> accountsToDelete = TestDataFactory.createPersonalAccounts(2);



        Profile p = [SELECT Id FROM Profile WHERE Name='Consumer and Dealer Support Rep'];
        User userSobject = TestDataFactory.createUser(true,p);
        insert userSobject;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'AccountMerge'];
        insert new PermissionSetAssignment(AssigneeId = userSobject.id, PermissionSetId = ps.Id);

        String errorMessage = 'You do not have permissions to delete dealer accounts. Contact your administrator for help.';

        System.runAs(userSobject) {
            insert accountsToDelete;

            for(Account a: accountsToDelete){
                a.ownerId = userSobject.id;
            }
            update accountsToDelete;

            Account masterAccount = [SELECT Id, Phone, PersonEmail from Account WHERE IsPersonAccount = true and Name LIKE '%0%' LIMIT 1];
            Account mergeAccount = [SELECT Id, Phone, PersonEmail, MasterRecordId from Account WHERE IsPersonAccount = true and Name LIKE '%1%' LIMIT 1];

            Test.startTest();
            merge masterAccount mergeAccount;
            Test.stopTest();

            List<Account> remainingAccount = [SELECT Id, Name  FROM Account WHERE IsPersonAccount = true AND Name LIKE '%Test%'];
            System.assertEquals(remainingAccount.size(), 1);
        }

    }

    

}
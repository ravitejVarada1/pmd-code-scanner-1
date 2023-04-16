@IsTest
public class FieldChangeTrackHandlerTest {

        @TestSetup
    static void makeData(){
        List<Account> accs = TestDataFactory.createPersonalAccounts(3);
        insert accs;
        List<Offer__c> LowerFunneloffer = TestDataFactory.createOffer(1,accs);
        insert LowerFunneloffer;
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User userSobject = TestDataFactory.createUser(true,p);
    }
    
    static testMethod void OfferAssignmentStatus() {
        
        List<Offer__c> OfferList = [select id,Offer_Expiration_Date__c,NewStage__c,Assignment_Status__c  from Offer__c Limit 1];      
        User usr = [select id from user limit 1];
        
        test.starttest();
        for(Offer__c O : OfferList)
        {
            O.Assignment_Status__c  = 'In Progress';
            O.Offer_Expiration_Date__c = System.today().addMonths(4);
            O.Primary_Sales_Rep__c = usr.id; 
            
        }
        
        update OfferList;
        
        test.stoptest();
        Offer__c off = [SELECT Id,Offer_Expiration_Date__c,NewStage__c, Assignment_Status__c  FROM Offer__c Limit 1];
        System.assertEquals('In Progress', off.Assignment_Status__c );
    }
}
@IsTest
public class OfferTriggerFunctions_Test {
    
    @TestSetup
    static void makeData(){
        List<Account> accs = TestDataFactory.createPersonalAccounts(3);
        insert accs;
        List<Offer__c> LowerFunneloffer = TestDataFactory.createOffer(1,accs);
        insert LowerFunneloffer;
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User userSobject = TestDataFactory.createUser(true,p);
    }
    
    static testMethod void OfferActiveFlagUpperFunneloffer() {
        
        List<Offer__c> OfferList = [select id,Offer_Expiration_Date__c,NewStage__c from Offer__c Limit 1];      
        
        test.starttest();
        for(Offer__c O : OfferList)
        {
            O.NewStage__c = 'EXPIRED';
            O.Offer_Expiration_Date__c = System.today().addMonths(4);
            
        }
        
        update OfferList;
        
        test.stoptest();
        Offer__c off = [SELECT Id,Offer_Expiration_Date__c,NewStage__c FROM Offer__c Limit 1];
        System.assertEquals('EXPIRED', off.NewStage__c);
    }
    
    static testMethod void OfferActiveFlagMultipleoffer() {
        
        List<Offer__c> MutipleOffer = [select id,Offer_Expiration_Date__c,NewStage__c from Offer__c Limit 1];      
        
        test.starttest();    
        for(Offer__c O :MutipleOffer)
        {
            O.Offer_Expiration_Date__c = System.today().addDays(-13);
            O.NewStage__c ='DOCS_SUBMITTED';
        }
        
        update MutipleOffer;
        
        OfferExpirationBatch sh1 = new OfferExpirationBatch();      
        String sch = '0 0 23 * * ?';
        system.schedule('Test check', sch, sh1);
        test.stoptest();
        
        Offer__c off = [SELECT Id,Offer_Expiration_Date__c,NewStage__c FROM Offer__c Limit 1];
        System.assertEquals('DOCS_SUBMITTED', off.NewStage__c);
    }
    
    static testMethod void OfferActiveFlagLowerFunneloffer() {
        
        List<Offer__c> LowerFunneloffer = [select id,Offer_Expiration_Date__c,NewStage__c from Offer__c Limit 1];  
        
        test.starttest();        
        for(Offer__c O :LowerFunneloffer){
            O.Offer_Expiration_Date__c = null;
        }
        
        update LowerFunneloffer;
        
        test.stoptest();
        offer__c off = [SELECT Id,Offer_Expiration_Date__c FROM Offer__c where Offer_Expiration_Date__c = null Limit 1];
        System.assertEquals(null, off.Offer_Expiration_Date__c);       
    }
    
    static testMethod void OfferSalesStatusPrimarySalesRep() {
        
        List<Offer__c> UpdateOffer = new List<Offer__c>();
        List<Account> paccs = [select id from account where IsPersonAccount=true];
        List<Offer__c> Expoffer = TestDataFactory.createOffer(1,paccs);
        Expoffer[0].NewStage__c = 'PENDING_DOC_REVIEW';
        insert Expoffer;
        Id usrId =[select id from user limit 1].id;
        
        test.starttest();
        for(Offer__c O :Expoffer)
        {
            O.NewStage__c = 'DOCS_SUBMITTED';
            O.Primary_Sales_Rep__c = usrId;
            UpdateOffer.add(O);
            
        }
        
        update UpdateOffer;
          
        test.stoptest();
        Offer__c off = [SELECT Id,NewStage__c FROM Offer__c where id =: UpdateOffer[0].id Limit 1];
        System.assertEquals('DOCS_SUBMITTED', off.NewStage__c);
        
    }
    
    static testMethod void OfferSalesStatus() {
        List<Offer__c> offerList = [select id,Offer_Expiration_Date__c,NewStage__c,Date_Sales_Claimed__c from Offer__c Limit 1];      
        
        test.starttest();
        for(Offer__c O :offerList)
        {
            O.NewStage__c = 'EXPIRED';
            O.Offer_Expiration_Date__c = System.today().addMonths(4);
        }
        
        update offerList;
        test.stoptest();
        
        Offer__c off = [SELECT Id,NewStage__c FROM Offer__c  Limit 1];
        System.assertEquals('EXPIRED', off.NewStage__c);
        
    }
    
    static testMethod void OfferSalesStatusonInsert() {
        List<Account> paccs = [select id from account where IsPersonAccount=true];
        List<Offer__c> InsertOffer = new List<Offer__c>();
        List<Offer__c> Expoffer = TestDataFactory.createOffer(1,paccs);
        
        for(Offer__c O :Expoffer)
        {
            O.NewStage__c = 'EXPIRED';
            InsertOffer.add(O);   
        }
        
        test.starttest();
        insert InsertOffer;
        test.stoptest();
        
        Offer__c off = [SELECT Id,NewStage__c FROM Offer__c where id =: InsertOffer[0].id Limit 1];
        System.assertEquals('EXPIRED', off.NewStage__c);
        
    }

    static testMethod void OfferSecondaryRep() {
        List<Account> paccs = [select id from account where IsPersonAccount=true];
        List<Offer__c> InsertOffer = new List<Offer__c>();
        List<Offer__c> Expoffer = TestDataFactory.createOffer(1,paccs);
        Id usrId =[select id from user limit 1].id;
        
        for(Offer__c O :Expoffer)
        {
            O.NewStage__c = 'EXPIRED';
            O.Secondary_Sales_Rep__c=null;
            InsertOffer.add(O);   
        }
        
        test.starttest();
        insert InsertOffer;
          for(offer__c OFR: InsertOffer)
          {
              OFR.Secondary_Sales_Rep__c= usrId;
              update OFR;
          }       
        test.stoptest();
        
        Offer__c off = [SELECT Id,Secondary_Sales_Rep__c FROM Offer__c where id =: InsertOffer[0].id Limit 1];
        System.assertEquals(usrId, off.Secondary_Sales_Rep__c);
        
    }
}
@isTest
public class QuoteAlertsHandlerTest {

    @testSetup 
    static void testData() {
        Profile p = [SELECT Id 
                     FROM Profile 
                     WHERE Name='Standard User'];
      	User u = TestDataFactory.createUser(true, p); 
      	insert u;
        User u1 = TestDataFactory.createUser(true, p);
        u1.Username = 'standarduser23456@testorg.com';
        u1.ManagerId = u.id;
      	insert u1;
    }

    @isTest
    static void checkLicense() {
        User u = [SELECT Id FROM User LIMIT 1];
        Boolean hasLicense = QuoteAlertsHandler.hasCongaLicense(u.id);
        System.assertEquals(false, hasLicense);
    }
}

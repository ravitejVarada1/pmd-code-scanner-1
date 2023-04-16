@isTest
public class UtilitiesTest {
    
    @testSetup
    static void testSetup(){
        Account[] accts = TestDataFactory.createAccounts(1);
        insert accts;
    }
    
    @isTest
    static void testRecordLocks(){
        SBQQ__Quote__c q = new SBQQ__Quote__c();
        insert q;
        
        LockRecords.lockRecords(new List<Id>{q.Id});
        System.assert(Approval.isLocked(q.Id));
        
        UnlockRecords.unlockRecords(new List<Id>{q.Id});
        System.assert(!Approval.isLocked(q.Id));
    }
    
    @isTest
    static void testGetType(){
        String nullString;
        Blob testBlob = Blob.valueOf('String');
        Boolean testBoolean = true;
        Date testDate = Date.today();
        Datetime testDatetime = DateTime.now();
        Decimal testDecimal = 5;
        Id testId = [SELECT Id FROM Account LIMIT 1][0].Id;
        Integer testInteger = 5;
        List<object> testList = new List<Object>();
        Long testLong = 5;
        SObject testSObject = new Account();
        String testString = 'String';
        Time testTime = Time.newInstance(1,1,1,1);
        Object o = (Object)new Account();
        
        Utilities.getType(nullString);    
        Utilities.getType(testBlob);
        Utilities.getType(testBoolean);
        Utilities.getType(testDate);
        Utilities.getType(testDatetime);
        Utilities.getType(testDecimal);
        Utilities.getType(testId);
        Utilities.getType(testInteger);
        Utilities.getType(testList);
        Utilities.getType(testLong);
        Utilities.getType(testSObject);
        Utilities.getType(testString);
        Utilities.getType(testTime);
        Utilities.getType(o);
    }
    
    @isTest
    public static void testCompareDynamically(){
        String EQUALS = '=';
        String NOT_EQUALS = '!=';
        String GREATER_THAN = '>';
        String LESS_THAN = '<';
        
        String firstString = 'test';
        String secondString = 'test';
        
        Decimal firstDecimal = 5;
        Decimal secondDecimal = 5;
        
        Boolean firstBoolean = true;
        Boolean secondBoolean = true;
        
        //EQUALS compare methods
        System.assert(Utilities.compareDynamically(firstString, secondString, EQUALS, 'String'));
        System.assert(Utilities.compareDynamically(String.valueOf(firstDecimal), String.valueOf(secondDecimal), EQUALS, 'Decimal'));
        System.assert(Utilities.compareDynamically(String.valueOf(firstBoolean), String.valueOf(secondBoolean), EQUALS, 'Boolean'));
        
        //NOT EQUALS compare methods
        System.assert(!Utilities.compareDynamically(firstString, secondString, NOT_EQUALS, 'String'));
        System.assert(!Utilities.compareDynamically(String.valueOf(firstDecimal), String.valueOf(secondDecimal), NOT_EQUALS, 'Decimal'));
        System.assert(!Utilities.compareDynamically(String.valueOf(firstBoolean), String.valueOf(secondBoolean), NOT_EQUALS, 'Boolean'));
        
        //GREATER THAN compare methods
        System.assert(Utilities.compareDynamically(String.valueOf(firstDecimal), String.valueOf(secondDecimal - 1), GREATER_THAN, 'Decimal'));
        
        //LESS THAN compare methods
        System.assert(Utilities.compareDynamically(String.valueOf(firstDecimal), String.valueOf(secondDecimal + 1), LESS_THAN, 'Decimal')); 
    }
}
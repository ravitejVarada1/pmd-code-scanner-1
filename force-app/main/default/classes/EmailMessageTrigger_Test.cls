@isTest
public class EmailMessageTrigger_Test {

    @testsetup static void testData() {

        Test.startTest();
        List<Account> accs = TestDataFactory.createAccounts(1);
        accs[0].BillingCountryCode = 'US';
        insert accs;
        
        List<Case> cases = TestDataFactory.createCases(1, accs[0].Id);
        Id caseRTID = Utilities.getrecordTypeId('Case', 'Billing');
        cases[0].RecordTypeId = caseRTID;
        cases[0].status='Closed';
        insert cases;

        List<Case> supportCases = TestDataFactory.createCases(1, accs[0].Id);
        Id SupportcaseRTID = Utilities.getrecordTypeId('Case', 'Support');
        supportCases[0].RecordTypeId = SupportcaseRTID;
        supportCases[0].status='Closed';
        supportCases[0].createddate = system.now().adddays(-16);
        supportCases[0].closeddate = system.now().adddays(-15);
        insert supportCases;

        List<Account> personalAccs = TestDataFactory.createPersonalAccounts(2);
        insert personalAccs;
        
        List<Case> createCase = TestDataFactory.createCSCase(1,personalAccs);
        insert createCase;
        createCase[0].Reason='Sell your car (C2D - instant offer)';
        createCase[0].Category__c='Issues Uploading ID';
        createCase[0].Case_Resolution__c='Resolved General Question';
        createCase[0].Case_Resolution_Notes__c='Test Email';
        createCase[0].status='Closed';
        update createCase;
        Test.stopTest();

    }
    
    static testMethod void caseStatusUpdateTest() {
        Id caseRTID = Utilities.getrecordTypeId('Case', 'Billing');
        case c = [SELECT Id FROM Case WHERE RecordTypeId =: caseRTID LIMIT 1];
        
        EmailMessage emsg = new EmailMessage();

        Test.startTest();
        emsg.Incoming = true;
        emsg.ParentId = c.id;
        insert emsg; 
        Test.stopTest();

        case c1 = [select Id,status From Case LIMIT 1];
        system.assertEquals('Reopen',c1.Status );
        
    }
    static testMethod void SupportcaseStatusUpdateTest() {
        Id SupportcaseRTID = Utilities.getrecordTypeId('Case', 'Support');
        case c = [SELECT Id FROM Case WHERE RecordTypeId =: SupportcaseRTID LIMIT 1];
        
        EmailMessage emsg = new EmailMessage();

        Test.startTest();
        emsg.Incoming = true;
        emsg.ParentId = c.id;
        insert emsg; 
        Test.stopTest();

        case c1 = [select Id,status From Case LIMIT 1];
        system.assertEquals('Closed',c1.Status );
        
    }

    static testMethod void caseCSStatusUpdateTest() {
        Id caseRTID = Utilities.getrecordTypeId('Case', 'Consumer_Support');
        
        case c = [SELECT Id FROM Case where RecordTypeId =:caseRTID LIMIT 1];
           
        EmailMessage emsg = new EmailMessage();

        Test.startTest();
        emsg.Incoming = true;
        emsg.ParentId = c.id;
        insert emsg; 
        Test.stopTest();

        case c1 = [select Id,status From Case  where RecordTypeId =:caseRTID  LIMIT 1];
        system.assertEquals('In Progress',c1.Status );
    } 


}
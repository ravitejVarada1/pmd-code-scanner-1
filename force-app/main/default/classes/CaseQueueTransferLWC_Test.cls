@IsTest
private class CaseQueueTransferLWC_Test{
    
    static Set<String> testQueues = new Set<String>{'Billing Case Queue','Payment Case Queue','Support Case Queue'};
    
    static Map<String,String> caseQueueNameToQueueId = new Map<String,String>();
    static Map<String,String> csRecTpNameToRecTpId = new Map<String,String>();
    
    static void initConfig() {
        
        for(Group grp : [
            SELECT Id, Name, DeveloperName, Type 
            FROM Group 
            WHERE Type = 'Queue' 
            AND Name IN:testQueues
        ]){
           caseQueueNameToQueueId.put(grp.Name,grp.Id); 
        }
        
        for(RecordType recType : [
            SELECT Id, Name 
            FROM RecordType 
            WHERE SobjectType = 'Case'
            AND IsActive = true
        ]){
           csRecTpNameToRecTpId.put(recType.Name,recType.Id); 
        }
        
         
    }
    
    static testMethod void caseQueueOwnerUsrNotMember() {
        initConfig();
        
        Account a = new Account();
        a.Name = 'Test account';
        insert a;
        
        List<Case> cases = TestDataFactory.createCases(1, a.Id);
        cases[0].OwnerId = caseQueueNameToQueueId.get('Billing Case Queue');
        cases[0].RecordTypeId = csRecTpNameToRecTpId.get('Billing');
        insert cases;
        
        CaseQueueTransferLWC.getInitialSetup(cases[0].Id);
        
    }

    static testMethod void caseQueueOwnerUsrMember() {
        initConfig();
        
        Account a = new Account();
        a.Name = 'Test account';
        insert a;
        
        System.runAs(new User(Id=UserInfo.getUserId())){
            GroupMember grpMember = new GroupMember();
            grpMember.UserOrGroupId = UserInfo.getUserId();
            grpMember.GroupId = caseQueueNameToQueueId.get('Billing Case Queue');
            insert grpMember;
        }

        List<Case> cases = TestDataFactory.createCases(1, a.Id);
        cases[0].OwnerId = caseQueueNameToQueueId.get('Billing Case Queue');
        cases[0].RecordTypeId = csRecTpNameToRecTpId.get('Billing');
        cases[0].CountryCode__c = 'US';
        insert cases;
        
        Test.startTest();
        CaseQueueTransferLWC.getInitialSetup(cases[0].Id);
        CaseQueueTransferLWC.processCaseSwitch(cases[0].Id,cases[0].RecordTypeId,'Billing: Backdated/ Early Cancellation','Transfer to Payments', 'CA', null);

        Case queryCase = [SELECT Id,OwnerId FROM Case WHERE Id=:cases[0].Id];
        System.assertEquals(queryCase.OwnerId,caseQueueNameToQueueId.get('Payment Case Queue'));
        Test.stopTest();
    }

    static testMethod void caseNotQueueOwner() {
        initConfig();
        
        Account a = new Account();
        a.Name = 'Test account';
        insert a;
        
        List<Case> cases = TestDataFactory.createCases(1, a.Id);
        cases[0].RecordTypeId = csRecTpNameToRecTpId.get('Billing');
        insert cases;
        
        Test.startTest();
        CaseQueueTransferLWC.getInitialSetup(cases[0].Id);
        Test.stopTest();
    }

    static testMethod void caseQueueToConsumerCase() {
        initConfig();
        
        Account a = new Account();
        a.Name = 'Test account';
        insert a;

        Contact c = new Contact();
        c.FirstName = 'test';
        c.LastName = 'br-8364';
        c.Email = 'testcasequeuelwc@carg.com';
        c.Phone = '212112121';
        c.AccountId  = a.Id;
        insert c;
        
        System.runAs(new User(Id=UserInfo.getUserId())){
            GroupMember grpMember = new GroupMember();
            grpMember.UserOrGroupId = UserInfo.getUserId();
            grpMember.GroupId = caseQueueNameToQueueId.get('Billing Case Queue');
            insert grpMember;
        }

        List<Case> cases = TestDataFactory.createCases(1, a.Id);
        cases[0].OwnerId = caseQueueNameToQueueId.get('Billing Case Queue');
        cases[0].RecordTypeId = csRecTpNameToRecTpId.get('Billing');
        cases[0].ContactId = c.Id;
        cases[0].CountryCode__c = 'US';
        insert cases;
        
        Test.startTest();
        CaseQueueTransferLWC.getInitialSetup(cases[0].Id);
        CaseQueueTransferLWC.processCaseSwitch(cases[0].Id,csRecTpNameToRecTpId.get('Consumer Support'),'Other','C2D Offer - Driver / Transporter / Drop-off', 'CA', 'Acertus');
        Test.stopTest();
    }
}
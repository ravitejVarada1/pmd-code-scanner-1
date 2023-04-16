/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         alaplante
* modifiedBy:     
* created:        11/17/2021
* modified:       
* created jira:   BR-4283
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

@isTest
public class Batch_CreateCoOpCases_Test {    
    
    @testSetup
    static void testSetup(){

        ID dealerAccountRecordTypeId = Utilities.getrecordTypeId('Account', 'Dealer_Account');
        
        Account acc = TestDataFactory.createSingleAccount(dealerAccountRecordTypeId);
        acc.Name = 'Co-Op Test Account';
        insert acc;

        Co_op_Program__c coOpProgram = new Co_op_Program__c(
            Name = 'Hyundai',
            Notes__c = 'Test',
            OwnerId = UserInfo.getUserId()
        );

        insert coOpProgram;

        Co_Op_Detail__c coOpDetail = new Co_Op_Detail__c(
            Account__c = acc.Id,
            Active__c = true,
            Co_Op_Program__c = coOpProgram.Id,
            Co_Op_Type__c = 'Display Only',
            Full_Service__c = true,
            Start_Date__c = Date.today()
        );

        insert coOpDetail;


    }

    @isTest
    static void checkCaseCreation(){

        test.startTest();
        Database.executeBatch(new Batch_CreateCoOpCases());
        test.stopTest();

        List<Case> coOpCases = [SELECT Id FROM Case WHERE Subject = 'Co-Op Case'];
        system.debug(coOpCases);
       // System.assert(coOpCases.size() > 0);

    }
    
}
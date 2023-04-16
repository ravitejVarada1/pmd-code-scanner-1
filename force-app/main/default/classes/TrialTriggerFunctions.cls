public class TrialTriggerFunctions {

    public static void populateEndDate(Trial__c[] tList) {

        Map<String,Trial_Setup__mdt> setupRecords = Trial_Setup__mdt.getAll();
        Trial_Setup__mdt defaultRecord = setupRecords.get('Default_Values');
        Integer length = (Integer)defaultRecord.Default_Trial_Duration__c;
        
        for (Trial__c t : tList) {
            Date startDate = t.Start_Date__c;
                if(t.End_Date__c == NULL){
                    Date endDate = t.Start_Date__c.addDays(length);
                    t.End_Date__c = endDate;
                }
        }
    }

    public static void checkTrial(Trial__c[] tList, Map<Id,Trial__c> oldMap) {

        Set<Id> acctIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();

        Map<String,Trial_Setup__mdt> setupRecords = Trial_Setup__mdt.getAll();
        Trial_Setup__mdt defaultRecord = setupRecords.get('Default_Values');
        Integer frequency = (Integer)defaultRecord.Default_Trial_Frequency__c;
        Integer length = (Integer)defaultRecord.Default_Trial_Duration__c;
        Date cutoffDate = date.today().addDays(0-frequency);
        Set<Id> existingIds = new Set<Id>();

        for (Trial__c t : tList) {
            String errorMsg;

            acctIds.add(t.Account__c);
            oppIds.add(t.Opportunity__c);
            Integer trialLength = t.Start_Date__c.daysBetween(t.End_Date__c);

            if (oldMap != null) {
                existingIds = oldMap.keySet();
                if (t.Start_Date__c != oldMap.get(t.Id).Start_Date__c) {
                    errorMsg = 'You may not change the Start Date of this Trial after insertion';
                    t.addError('Start_Date__c',errorMsg);
                    continue;
                } 
                if (t.End_Date__c != oldMap.get(t.Id).End_Date__c && t.End_Date__c != t.Extend_to_End_Date__c && trialLength > length){
                    errorMsg = 'The trial can not be changed to longer than ' + length + ' days. If you would like to extend this trial, please submit an extension approval request.';
                    t.addError('End_Date__c', errorMsg);
                    continue;
                }
            }
            if (oldMap == null && trialLength > length){
                errorMsg = 'The trial can not be longer than ' + length + ' days from the start date.';
                t.addError('End_Date__c', errorMsg);
            }

        }

        Map<Id,Account> acctMap = new Map<Id,Account>([SELECT Id, Type, Product_Activation_Status__c, 
                (SELECT Id,  End_Date__c FROM Trial_Account__r WHERE Id NOT IN: existingIds ORDER BY End_Date__c DESC)
                FROM Account WHERE Id IN: acctIds]);

        Map<Id,Opportunity> oppMap = new Map<Id,Opportunity>([SELECT Id, IsClosed 
                FROM Opportunity WHERE Id IN: oppIds]);

        for (Trial__c t : tList) {
            String errorMsg;

            Account a = acctMap.get(t.Account__c);
            Opportunity o = oppMap.get(t.Opportunity__c);

            //account based errors
            if (a.Type == 'Customer' && Trigger.isInsert) {
                errorMsg = 'You may not provide a Trial to an existing Customer';
                t.addError('Account__c',errorMsg);
                continue;
            } else if (!a.Trial_Account__r.isEmpty()) {
                Date lastEndDate = a.Trial_Account__r[0].End_Date__c;
                if (lastEndDate > cutoffDate) {
                    errorMsg = 'This Account last had a Trial that ended on ' + lastEndDate + '. ' +
                                'You must wait at least ' + frequency + ' days after the end of the last Trial ' +
                                'before another Trial may be granted.';
                    t.addError('Account__c',errorMsg);
                    continue;
                }
            }
 
            //opp based errors
            if (o.IsClosed && Trigger.isInsert) {
                errorMsg = 'You may not provide a Trial from a Closed Opportunity';
                t.addError('Opportunity__c',errorMsg);
                continue;
            }
        }
    }

    public static void updateAccountType(Trial__c[] tList) {

        Set<Id> acctIds = new Set<Id>();
        Account[] updateAccts = new List<Account>();

        for (Trial__c t : tList) {
            acctIds.add(t.Account__c);
        }
        
        for (Account a : [SELECT Id, Product_Activation_Status__c 
                FROM Account WHERE Id IN: acctIds]) {
            if (a.Product_Activation_Status__c != 'Active') {
                a.Product_Activation_Status__c = 'Trial';
                updateAccts.add(a);
            } else {
                String errorMsg = 'Cannot update an Account to Trial if they have an active Subscription';
                a.addError(a.Product_Activation_Status__c,errorMsg);
            }   
        }

        if (!updateAccts.isEmpty()) {
            update updateAccts;
        }

    }

}
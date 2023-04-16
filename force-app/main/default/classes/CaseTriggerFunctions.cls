public without sharing class CaseTriggerFunctions {
    
    public static Map<Id,String> recordTypeNameMap = new Map<Id,String>();

    public static Map<String, List<String>> recordTypeMapWithReason = new Map<String, List<String>>{
        'Sales Support Desk' => new List<String>{
        'Activation Issue', 
        'Quoting',
        'Record Reassign', 
        'Buy/Sell', 
        'Edit Account', 
        'Hierarchy Maintenance', 
        'Other', 
        'Cancellations'
        },
        'Planning and Commissions'=> new list<String>{
        'Commissions', 
        'Book Planning', 
        'Forecasting'
        }
    };

    public static Map<String, String> entitlementProcessMap = new Map<String, String>{
        'Sales Support Desk-Activation Issue'=> 'ssd-activationissue', 
        'Sales Support Desk-Quoting'=>'ssd-quotingcases', 
        'Sales Support Desk-Record Reassign'=>'ssd-recordreassign',
        'Sales Support Desk-Buy/Sell'=>'ssd-buysell', 
        'Sales Support Desk-Edit Account'=>'ssd-editaccount',
        'Sales Support Desk-Hierarchy Maintenance'=>'ssd-hierarchymaintenance', 
        'Sales Support Desk-Other'=>'ssd-othercases', 
        'Sales Support Desk-Cancellations'=>'ssd-cancellationcases',
        'Sales Support Desk-Cancellations' => 'cancellations-timesensitive',
        'Planning and Commissions-Commissions' => 'planning&commissions', 
        'Planning and Commissions-Book Planning' => 'planning&commissions',
        'Planning and Commissions-Forecasting' => 'planning&commissions'
    };

    public static String CLOSED_STATUS = 'Closed';
    public static String PENDING_STATUS = 'Pending';
    public static String ACTIVATED_STATUS = 'Activated';
    public static String PENDING_ACTIVATION_STATUS = 'Pending Activation';

    public static String CGORIGIN = 'Issue Processor';

    public static Map<String, Id> caseRTDevNameIdMap = new Map<String, Id>();
    public static Map<String, Id> caseRTNameIdMap = new Map<String, Id>();
    static {
        Map<String, Schema.RecordTypeInfo> rtInfoByName = Case.getSObjectType().getDescribe().getRecordTypeInfosByName();
        for(String rtName : rtInfoByName.keySet()) {
            Id rtId = rtInfoByName.get(rtName).getRecordTypeId();
            String rtDevName = rtInfoByName.get(rtName).getDeveloperName();
            caseRTDevNameIdMap.put(rtDevName, rtId);
            caseRTNameIdMap.put(rtName, rtId);
        }
    }

    public static Account entitlementAccount = new Account(
        Id = '0014S0000068XDOQA2'
    );

    /**
    * Sets 'View on CG' URL on cases
    *
    * @author alaplante
    * @module BR-2685
    */
    
    public static void setViewOnCGurl(List<Case> caseList, Map<Id, Case> oldCaseMap) {
        // init maps
        Map<Id, Id> caseMap = new Map<Id, Id>();
        Map<Id, String>  urlMap = new Map<Id, String>();
        // loop through cases in scope
        for (Case c : caseList) {
            // if case is new or related dealer account or account change
            if (
            c.View_On_CG__c == null ||
            (oldCaseMap.containsKey(c.Id) && (c.Related_Dealer_Account__c != oldCaseMap.get(c.Id).Related_Dealer_Account__c ||
            c.AccountId != oldCaseMap.get(c.Id).AccountId))
            ) {
            caseMap.put(c.Related_Dealer_Account__c == null ? c.AccountId : c.Related_Dealer_Account__c, c.Id);
            }
        }

        // loop through accounts and SP getting urls
        for (Account account : [ 
            SELECT Id, Name, 
            (SELECT Service_Provider_Id__c, Dealer_Type__c, View_On_CG__c 
            FROM Service_Provider__r 
            ORDER BY Dealer_Type__c DESC, reviewStatus__c ASC NULLS LAST)
            FROM Account WHERE Id IN :caseMap.keySet()
            ]) 
        {
            // throw account id and service provider url into map, cut up url to remove html formatting
            urlMap.put(account.Id, account.Service_Provider__r.size() > 0 
            ? String.valueOf(account.Service_Provider__r[0].View_On_CG__c).substringAfter('<a href="').substringBefore('" target="_blank">View on CG</a>')
            : null);
        }

        // loop through cases setting url field
        for (Case c : caseList) {
            String keyMap = c.Related_Dealer_Account__c == null ? c.AccountId : c.Related_Dealer_Account__c;
            if (urlMap.containsKey(keyMap)) {
            c.Service_Provider_URL__c = urlMap.get(keyMap);
            }
        }
    }

    public static void validateCreateDateBusinessHours(List<Case> caseList) {
        for (Case c : caseList) {
            DateTime dT;
            if (c.CreatedDate != null) {
                dT = c.CreatedDate;
            } else {
                dT = DateTime.now();
            }

            Boolean isDuringBusinessHours = false;
            isDuringBusinessHours = Utilities.isDateDuringBusinessHours(dT, c.CountryCode__c);
            System.debug('Is Business Hours? >>> '+isDuringBusinessHours);

            if (isDuringBusinessHours) {
                c.IsCreatedDuringBusinessHours__c = true;
            } else {
                c.IsCreatedDuringBusinessHours__c = false;
            }
        }
    }

    public static void populateCountryCode(Map<ID, Case> oldCaseMap, List<Case> newCaseList) {
    
        Set<Id> accountId = new Set<Id>();

        //Adding the accoundId into the set
        for (Case c : newCaseList) {
            if (c.accountId != null)
                accountId.add(c.accountId);
            if (c.Related_Dealer_Account__c != null)
                accountId.add(c.Related_Dealer_Account__c);
        }

        // if AccountId set is empty then skip the populate country code logic.
        if(accountId.isEmpty()) {
            return;
        }
        
        // Query for account record details related to case 
        Map<Id, Account> accountMap = new Map<Id, Account>([
        SELECT Id,CurrencyIsoCode,BillingCountryCode
        FROM Account
        WHERE ID IN :accountId
        ]);

        Id ssdRcdTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Sales_Support_Desk');
        Id comissionsRcdType = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Planning_and_Commissions');
            
        // iterating newcaselist to populate the country code
        for (Case c : newCaseList) {
            // checking for related account associated at insertion 
            //of case record and also at the time of update.
            Account acc;
            if ( (c.RecordTypeId == ssdRcdTypeId || c.RecordTypeId == comissionsRcdType) 
                && c.Related_Dealer_Account__c != null ) {

                acc = accountMap.get(c.Related_Dealer_Account__c);

            } else if (c.AccountId != null && (oldCaseMap == null || 
                (oldCaseMap != null && oldCaseMap.containsKey(c.Id) && oldCaseMap.get(c.id).accountId != c.accountId)) ) {

                acc = accountMap.get(c.AccountId);
            }

            if(acc == null) {
                continue;
                
            } else {
                // setting the country code and currency code
                c.CountryCode__c = acc.BillingCountryCode;
                c.CurrencyIsoCode = acc.CurrencyIsoCode;
            }
        }
    }


    //BR-888
    public static void activateRelatedOrderProduct(List<Case> newCaseList, Map<ID, Case> oldCaseMap) {

        Id productProvisionRTId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Product_Provision');
        List<String> activationPOBs = Utilities.getRevProActivationPobs();
        set<Id> orderProductIds = new set<Id>();

        for (Case c : newCaseList) {
            if (c.recordTypeID == productProvisionRTId && c.Status == CLOSED_STATUS 
                && oldCaseMap.containsKey(c.Id) && c.Status != oldCaseMap.get(c.Id).Status && c.Order_Product__c != null) {
            orderProductIds.add(c.Order_Product__c);
            }
        }

        if (!orderProductIds.isEmpty()) {
            List<OrderItem> oProdStatusToBeupdate = new List<OrderItem>();
                Set<Id> orderIds = new Set<Id>();

                for (OrderItem oProd : [
                    SELECT ID, SBQQ__Status__c, OrderId, Product2.Product_Provisioning_Behavior__c
                    FROM OrderItem
                    WHERE Id IN :orderProductIds AND SBQQ__Status__c =: PENDING_ACTIVATION_STATUS
                ]) {
                    DateTime caseCloseDate;

                    for (Case c : newCaseList) {
                        if (c.Order_Product__c == oProd.Id) {
                            caseCloseDate = c.ClosedDate;
                        }
                    }

                    oProd.SBQQ__Status__c = ACTIVATED_STATUS;
                    oProd.SBQQ__Activated__c = true;

                    // SA-170 - only activate Zuora Rev Pro if Products associated POB dictates to do so
                    if (activationPOBs.contains(oProd.Product2.Product_Provisioning_Behavior__c)) {
                        oProd.Activation_Zuora_RevPro__c = PENDING_STATUS;
                    }
                    
                    oProd.Manual_Activation_Date__c = caseCloseDate.date();
                    oProdStatusToBeupdate.add(oProd);
                    orderIds.add(oProd.OrderId);

                }

                if (!oProdStatusToBeupdate.isEmpty()) {
                    database.update(oProdStatusToBeupdate);

                    // since the order product Revpro status is now 'Pending', the Order's Revpro status needs to reflect the same if it doesn't already 
                    List<Order> orders = [
                        SELECT Id, Activation_Status_Manual_Activation__c
                        FROM Order
                        WHERE Id IN :orderIds AND Activation_Status_Manual_Activation__c != :PENDING_STATUS
                    ];

                    if (!orders.isEmpty()) {
                        for (Order o : orders) {
                            o.Activation_Status_Manual_Activation__c = PENDING_STATUS;
                        }
                        update orders;
                    }
                }
        }
    }

    //BR-1249 associating SSD and P&C cases to Cargurus Account
    public static void associateCargurusAccount(List<Case> newCaseList) {

        Set<Id> rtIdSet = new Set<Id>();
        rtIdSet.add(SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Sales_Support_Desk'));
        rtIdSet.add(SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Planning_and_Commissions'));

        for (Case c: newCaseList) {
            if (rtIdSet.contains(c.RecordTypeId)) {
                c.AccountId = entitlementAccount.Id;
            }
        }
    }

    /**
    * Stamps the entitlement on the cases where record types are planning and commissions or SSD
    * @author   Aparna Ganji
    * @date     07/02/21
    * @module   BR-1224 : Automate Entitlement process - Salesforce
    */
    public static void associateEntitlements(List<Case> newCaseList) {
        Set<String> rtNames = new Set<String>{'Planning and Commissions', 'Sales Support Desk'};

        //List<String> recordTypeList = new List<String>{'Planning_and_Commissions', 'Sales_Support_Desk'};
        //for (string s: recordTypeList) {
        //    Id recordTypeId = Utilities.getRecordTypeId('Case', s);
        //    recordTypeIdList.add(recordTypeId);
        //}
        
        //List<RecordType> recordtypeSobjectlist = [SELECT ID, Name FROM RecordType WHERE ID IN :recordTypeIdList];

        for (String rtName : rtNames) {
            String rtId = SObjectDescribeUtils.getRecordTypeIdByName('Case', rtName);
            recordTypeNameMap.put(rtId, rtName);
        }

        List<Case> filteredCases = new List<Case>();
        for (Case c : newCaseList) {
            Id caseRTId = c.RecordTypeId;
            String caseReason = c.Reason;

            if (recordTypeNameMap.containskey(caseRTId)) {
                String rtName = recordTypeNameMap.get(caseRTId);
                List<String> caseReasons = recordTypeMapWithReason.get(rtName);
                if(caseReasons.contains(caseReason)) {
                    filteredCases.add(c);
                }
            }   
        }

        // get entitlement Ids in a map (key: Case.Id)
        Map<Id, Id> entitlementIdsMap = getEntitlementIds(filteredCases);
        for (Case c: filteredCases) {
            c.EntitlementId = entitlementIdsMap.get(c.Id);
        }
    }

    // get EntitlementID method to return a list of entitlementID if found any entitlement process for the combination of 
    // recordtype and reason for the given cases
    private static Map<Id, Id> getEntitlementIds(List<Case> cases) {
        Map<Id, Id> entitlementIdsMap = new Map<Id, Id>();
        //List<Account> accountList = Utilities.getCGEntitlementAccount(); //BR-7299
        Map<String, String> caseIdToProcessNameMap = new Map<String, String>();
        List<Id> accountIds = new List<Id>();

        // we need to associate new entitlements to CarGurus account. If account doesn't exist, create it (only 1st time)
        /*if (accountList.isEmpty()) {
            Account carGurusAccount = new Account(Name = 'CarGurus Account', Account_Status__c = 'Active');
            insert carGurusAccount;
            accountList.add(carGurusAccount);
        }*/

        // first pass through the cases list to extract entitlement process names
        for (Case c : cases) {
            String entitlementProcessName = getEntitlementProcessName(c);
            if (entitlementProcessName != null) {
                String caseKey = c.RecordTypeId+ '-'+c.Reason;
                caseIdToProcessNameMap.put(caseKey, entitlementProcessName);
                accountIds.add(c.AccountId);
            }
        }

        // setup SLA map
        Map<String, SlaProcess> processNameToSlaMap = new Map<String, SlaProcess>();
        for (SlaProcess sla : [
            SELECT Id, Description, Name, NameNorm
            FROM SlaProcess 
            WHERE NameNorm IN :caseIdToProcessNameMap.values()
        ]) {
            processNameToSlaMap.put(sla.NameNorm, sla);
        }

        // setup existing Entitlements map
        Map<String, Entitlement> processNameToEntitlementMap = new Map<String, Entitlement>();
        for (Entitlement ent : [
            SELECT Id, Name, AccountId, SlaProcessId, SlaProcess.NameNorm
            FROM Entitlement 
            WHERE SlaProcess.NameNorm IN :caseIdToProcessNameMap.values()
            AND AccountId IN :accountIds
        ]) {
            processNameToEntitlementMap.put(ent.SlaProcess.NameNorm, ent);
        }

        Map<Id, Entitlement> entitlementsToInsertMap = new Map<Id, Entitlement>();
        // second pass through the cases list, to create/associate the entitlements accordingly
        for (Case c : cases) {
            String caseKey = c.RecordTypeId+ '-'+c.Reason;
            String entitlementProcessName = caseIdToProcessNameMap.get(caseKey);
            if (entitlementProcessName == null) {
                continue;
            }

            Entitlement entitlementSobject;
            
            // if entitlement already exists, add its ID to list (to associate to case afterwards)
            if (processNameToEntitlementMap.containsKey(entitlementProcessName)) {
            entitlementSobject = findEntitlement(c, entitlementProcessName, processNameToEntitlementMap);
            entitlementIdsMap.put(c.Id, entitlementSobject.Id);
            } else {
                // create new entitlement
                SlaProcess sla = processNameToSlaMap.get(entitlementProcessName);
                //stamping sla process to new entitlement
                if (sla != null) {
                    entitlementSobject = new Entitlement(
                    SlaProcessId = sla.Id, 
                    StartDate = System.today(), 
                    Name = entitlementProcessName
                    );
                    
                    //Account carGurusAccount = accountList[0];
                    entitlementSobject.AccountId = entitlementAccount.Id;
                    entitlementsToInsertMap.put(c.Id, entitlementSobject);
                }
            }
        }

        if (!entitlementsToInsertMap.isEmpty()) {
            insert (entitlementsToInsertMap.values());
            for (Id caseId : entitlementsToInsertMap.keyset()) {
                entitlementIdsMap.put(caseId, entitlementsToInsertMap.get(caseId).Id);
            }
        }

        return entitlementIdsMap;
    }

    private static Entitlement findEntitlement(Case c, String entitlementProcessName, Map<String, Entitlement> entitlementsMap) {
        for (String key : entitlementsMap.keyset()) {
            if (key == entitlementProcessName) {
                Entitlement ent = entitlementsMap.get(key);
                if (ent.AccountId == c.AccountId) {
                    return ent;
                }
            }
        }
        return null;
    }

    //method returns the process name basis on the key of case recordtype and case reason 
    private static String getEntitlementProcessName(Case c) {
        String caseKey = recordTypeNameMap.get(c.RecordTypeId) + '-' + c.Reason;
        system.debug('caseKey' +caseKey);
        if (entitlementProcessMap.containsKey(caseKey)) {
            return entitlementProcessMap.get(caseKey);
        }
        else return null;
    }

    /**
     * Mark the milestones automatically on the cases  when completed.
    * @author   Aparna Ganji
    * @date     08/019/21
    * @module   BR-3715 : Automate Entitlement process - Salesforce
    */

    public static void markMilestones(map <id, case> caseNewMap, map <id, case> caseOldMap) {
        List<Id> caseIdList = new List<Id>();
        for(Id c: caseNewMap.keySet()){
            if(caseNewMap.get(c).status == 'In progress')
            caseIdList.add(c);
            if(caseNewMap.get(c).status == 'Closed')
            caseIdList.add(c);
            if(caseoldMap.containskey(c) && caseoldMap.get(C).status == 'Pending Requestor')
            caseIdList.add(c);
        }
        
        List<caseMilestone> caseMileStoneList = [SELECT Id, isCompleted, caseId,  MileStonetype.name, CompletionDate FROM caseMileStone WHERE CaseId IN :caseIdList AND (MileStonetype.name = 'First Response Time' OR  MileStonetype.name = 'Resolution Time.' OR mileStoneType.name = 'Waiting on customer' 
                                                                                                                                                                OR mileStoneType.name = 'Time sensitive First response time' OR MileStonetype.name = 'Time Sensitive Resolution Time')];
        for(caseMilestone cm: caseMileStoneList){
            if(!cm.isCompleted && caseNewMap.get(cm.caseId).status == 'In progress' && cm.MileStonetype.name == 'Time Sensitive First Response Time' && caseNewMap.get(cm.caseId).Priority == 'Time Sensitive')
            cm.CompletionDate = system.now();   
            if(!cm.isCompleted && caseNewMap.get(cm.caseId).status == 'Closed' && cm.MileStonetype.name == 'Time Sensitive Resolution Time' && caseNewMap.get(cm.caseId).Priority == 'Time Sensitive')
            cm.CompletionDate = system.now();
            if(!cm.isCompleted && caseNewMap.get(cm.caseId).status == 'In progress' && cm.MileStonetype.name == 'First Response Time')
            cm.CompletionDate = system.now();
            if(!cm.isCompleted && caseNewMap.get(cm.caseId).status == 'Closed' && cm.MileStonetype.name == 'Resolution Time.')
            cm.CompletionDate = system.now();
            if(!cm.isCompleted && caseOldMap.containskey(cm.caseId) && caseOldMap.get(cm.caseId).status == 'Pending Requestor' && cm.MileStonetype.name == 'Waiting on customer')
            cm.CompletionDate = system.now();
        }
        if(!caseMileStoneList.isEmpty())
        update caseMileStoneList;
    }

        /**
     * Static method to update related data for cancellations, and generate the cancellation quotes
    * @author   Nahuel Goldy
    * @date       06/06/2021
    * @param    Map<Id,Case> - map with previous case values
    * @param    Map<Id,Case> - map with new case values
    * @return   void
    */
    public static void updateAndInsertRelatedDataForCancellations(Map<Id,Case> oldMap, Map<Id,Case> newMap) {
        
        Id cancellationsCaseRecordTypeId = [
        SELECT Id
        FROM RecordType
        WHERE SObjectType = 'Case' AND Name = 'Cancellations'
        ][0].Id;

        Map<Id,Case> contractIdToCaseMap = new Map<Id,Case>();
        List<Id> opps = new List<Id>();

        for (Case c : newMap.values()) {
            Boolean isCancellationsCase = c.RecordTypeId == cancellationsCaseRecordTypeId;
            Boolean caseWasClosed = c.Status == 'Closed' && oldMap.containsKey(c.Id) && oldMap.get(c.Id).Status != c.Status;
            if (isCancellationsCase && caseWasClosed && c.Related_Contract__c != null && c.Related_Opportunity__c != null && c.Case_Resolution__c == 'Full Cancellation') {
                contractIdToCaseMap.put(c.Related_Contract__c, c);
                opps.add(c.Related_Opportunity__c);
            } 
        }

        if (contractIdToCaseMap.isEmpty()) {
            return;
        }

        List<SBQQ__Subscription__c> subs = [
        SELECT Id, SBQQ__Contract__c, Cancellation_Notice_Date__c, Cancellation_Reason__c
        FROM SBQQ__Subscription__c
        WHERE SBQQ__Contract__c IN :contractIdToCaseMap.keyset()
        ];

        for (SBQQ__Subscription__c sub : subs) {      
            Case cancellationCase = contractIdToCaseMap.get(sub.SBQQ__Contract__c);
            //sub.Cancellation_Notice_Date__c = cancellationCase.CreatedDate.date();
            sub.Cancellation_Reason__c = cancellationCase.Case_Resolution__c;
        }

        update subs;

        List<Contract> contractsToUpdate = new List<Contract>();
        for(Id contractId : contractIdToCaseMap.keyset()) {
            contractsToUpdate.add(
                new Contract(
                Id = contractId,
                Cancellation_Effective_Date__c = contractIdToCaseMap.get(contractId).Cancellation_Effective_Date__c,
                Cancellation_Notice_Date__c	= contractIdToCaseMap.get(contractId).CreatedDate.date()
                )
            );
        }

        update contractsToUpdate;

        if(!System.isBatch()) {
            Database.executeBatch(new Batch_SetAutoRenewalDisableDate(new List<Id>(contractIdToCaseMap.keyset()),false));
        }

        clonePrimaryQuoteWithRelatedForFullCancellation(opps);
    }

    /**
     * Static method to clone primary quote + quotelines for the given opportunities
    * @author   Nahuel Goldy
    * @date       06/04/2021
    * @param    List<Id> - list of opportunity IDs that have quotes to be cloned 
    * @return   void
    */
    public static void clonePrimaryQuoteWithRelatedForFullCancellation(List<Id> oppIdsList) {

        List<String> quoteQueryFields = new List<String>(SBQQ__Quote__c.SObjectType.getDescribe().fields.getMap().keySet());
        List<String> quotelineQueryFields = new List<String>(SBQQ__QuoteLine__c.SObjectType.getDescribe().fields.getMap().keySet());

        if (oppIdsList.isEmpty()) {
            return;
        }

        // query the quote plus related opp and case fields - only cancellations
        String query = 'SELECT '+ String.join(quoteQueryFields, ', ') + ', SBQQ__Opportunity2__r.Cancellation_Case__c, '+
        'SBQQ__Opportunity2__r.Cancellation_Case__r.Cancellation_Effective_Date__c, '+
        'SBQQ__MasterContract__r.Estimated_Cancellation_Effective_Date__c, SBQQ__Opportunity2__r.OwnerId, '+
        '('+
            'SELECT ' + String.join(quotelineQueryFields, ', ') + ', SBQQ__Product__r.Name ' +
            'FROM SBQQ__LineItems__r' +
        ') '+
        'FROM SBQQ__Quote__c ' +
        'WHERE SBQQ__Opportunity2__c IN :oppIdsList ' +
            'AND SBQQ__Primary__c = TRUE ' +
            'AND SBQQ__Opportunity2__r.IsClosed = FALSE ' +
            'AND SBQQ__Opportunity2__r.Cancellation_Case__c != NULL ' +
            ' AND SBQQ__Opportunity2__r.Cancellation_Case__r.RecordType.Name = \'Cancellations\' ' +
            'AND SBQQ__Opportunity2__r.Cancellation_Case__r.Case_Resolution__c = \'Full Cancellation\' ';

        Map<Id,SBQQ__Quote__c> quotesMap = new Map<Id,SBQQ__Quote__c>((List<SBQQ__Quote__c>)Database.query(query));
        Map<Id,SBQQ__Quote__c> quoteMapToDelete = new Map<Id,SBQQ__Quote__c>();
        quoteMapToDelete = quotesMap;

        // clone and insert quotes with quote lines
        Map<SBQQ__Quote__c,List<SBQQ__QuoteLine__c>> clonedResultsMap;
        if (quotesMap.keyset().size() > 0) {
            clonedResultsMap = ObjectCloner.cloneQuotesWithRelatedQuoteLines(quotesMap.values());

            List<SBQQ__Quote__c> clonedQuotes = new List<SBQQ__Quote__c>(clonedResultsMap.keyset());
            // lock the quotes
            Approval.LockResult[] lrList = Approval.lock(clonedQuotes, false);

            //BR-3791 update amendment quote owner based on oppty owner
            for (SBQQ__Quote__c quote : quotesMap.values()) {
                if(!Test.isRunningTest()){
                    quote.OwnerId = quote.SBQQ__Opportunity2__r.OwnerId; 
                }
                quote.SBQQ__SalesRep__c = quote.SBQQ__Opportunity2__r.OwnerId;
            }      
            update quotesMap.values();
        }

        deleteQuoteLineAndUpdatePrimaryQuoteType(quoteMapToDelete);
    }
        /**
     * Static method to delete the quoteline items on primary quote.
    * @author   amitul
    */
    public static void deleteQuoteLineAndUpdatePrimaryQuoteType(Map<Id,SBQQ__Quote__c> quotesMap) {
        List<SBQQ__QuoteLine__c> quoteLineToDelete = new List<SBQQ__QuoteLine__c>();
        if (quotesMap.keyset().size() > 0) {
            for (SBQQ__Quote__c quote : quotesMap.values()) {
                for(SBQQ__QuoteLine__c quoteLine : quote.SBQQ__LineItems__r ){
                    //if(quoteLine.SBQQ__ProductCode__c != 'CG-Base'){
                    quoteLineToDelete.add(quoteLine);    
                //}
            }
                quote.SBQQ__Type__c = 'Quote';
                quote.SBQQ__MasterContract__c = null;
            } 
        if(!quoteLineToDelete.isEmpty()){
            delete quoteLineToDelete;
        }
        update quotesMap.values();

        }
    }
    
    // BR-951 automated notification to Aqu.rep
    public static void sendNotification(List<Case> caseList) {
        List<Id> accountIdList = new List<Id>();
        Map<Id,Case> caseToSendNotification = new Map<Id, Case>();
        Id onboardingCaseRecordtypeID = SObjectDescribeUtils.getRecordTypeIdByName('Case', 'Onboarding');
        for (Case caseSobject: caseList) {
        if (caseSobject.AccountId != null && caseSobject.RecordTypeId == onboardingCaseRecordtypeID ) {
            accountIdList.add(caseSobject.AccountId);
            caseToSendNotification.put(caseSobject.Id, caseSobject);
            }
        }
        if (caseToSendNotification.isEmpty()) {
            return;
        }
        List<string> teamMemberList = new List<string>{'Dealer Relations', 'Acquisitions'};
        Map<Id, Account> accountWithAccountTeamMembersMap = new Map<id, Account>([SELECT Id, ownerId, Name, (SELECT Id, UserId, user.Name, teammemberRole FROM AccountTeamMembers WHERE teammemberRole In :teammemberList) FROM Account WHERE Id IN :accountIdList]);
        map<Id, Account> caseWithAccountMap = new Map<Id, Account>();
        Map<Id, String> caseWithDRRepMemberMap = new Map<id, String>();
        for (Case caseSobject: caseToSendNotification.values()) {
            if (accountWithAccountTeamMembersMap.get(caseSobject.AccountId).AccountTeamMembers.size()==2) {
                caseWithAccountMap.put(caseSobject.Id, accountWithAccountTeamMembersMap.get(caseSobject.AccountId));
            }
        }

        CustomNotificationType notificationType =[SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName='Case_Notification'];
        for (Case caseSobject: caseToSendNotification.values()) {
            if (accountwithAccountteamMembersmap.get(caseSobject.AccountId).AccountTeamMembers.size()==2) {           
                AccountTeamMember DRRep;
                AccountTeamMember AcquasitionRep;
                for (AccountTeamMember atm: accountwithAccountteamMembersmap.get(caseSobject.AccountId).AccountTeamMembers)
                {
                    if (atm.teammemberRole == 'Dealer Relations')
                    {
                    DRRep = atm;
                    }
                    if (atm.teammemberRole == 'Acquisitions')
                    {
                    AcquasitionRep = atm;
                    }
                }
                Set<String> recipientsIds = new Set<String>{AcquasitionRep.UserId};
                notifyusers(recipientsIds, DRRep.id, caseWithAccountMap, DRrep.user.Name, notificationType.id, caseSobject); 
            }
        }
    }
    
    
    public static void notifyUsers(Set<String> recipientsIds, String targetId, map<Id, Account> caseWithAccountMap, String caseWithDRRepMemberMap,Id notificationId, Case caseSobject )
    {
        // Create a new custom notification
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        
        // Set the contents for the notification
        notification.setTitle('Onboarding case details');
        notification.setBody('The caseNumber ' + caseSobject.CaseNumber + ' with account name ' + caseWithAccountMap.get(caseSobject.Id).Name + ' account id ' + caseWithAccountMap.get(caseSobject.Id).Id + ' has been assigned to user ' + caseWithDRRepMemberMap);
        
        // Set the notification type and target
        notification.setNotificationTypeId(notificationId);
        notification.setTargetId(targetId);
        
        // Actually send the notification
        if (!recipientsIds.isEmpty())
        notification.send(recipientsIds);
    }
    
    /**
    * "Account" - Process Clarification 
    *
    * @author aganji
    * @module BR-3499
    */
    public static void updateAccount(list<Case> newCaseList, Map<Id, case> oldCaseMap){
        Id datacorrectionId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Data_Correction');

        List<Id> accountIdList = new List<Id>();
        for(Case c:newCaseList){
            if(c.status == 'Closed' && c.Reason == 'New Dealer Account created' && (c.RecordTypeId == datacorrectionId) && oldCaseMap.containsKey(c.Id) && c.Status != oldCaseMap.get(c.Id).Status){
                accountIdList.add(c.AccountId);
            }
        }
        
        Id dealerAccountRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Account', ConstantsUtil.RT_ACCOUNT_DEALER);
        Map<Id,Account> accountMap = new Map<Id,Account>([
            SELECT Id, Account_Status__c, Product_Activation_Status__c 
            FROM Account 
            WHERE Id IN :accountIdList AND RecordTypeId = :dealerAccountRecordTypeId
            ]);
        List<Account> accountUpdateList = new List<Account>();
        if(accountMap.isEmpty()){
            return;  
        }

        for(Case c: newCaseList){
            if(accountMap.containsKey(c.AccountId) && (c.RecordTypeId == datacorrectionId)){
                Account acc = accountMap.get(c.AccountId);
                if(c.Approved_Account__c == 'Yes'){
                    acc.Account_Status__c = 'Active';
                    acc.Product_Activation_Status__c = 'Restricted – Activated';
                }
                else{
                    acc.Account_Status__c = 'Inactive';
                }
                accountUpdateList.add(acc);
            }
        }
        
        if(!accountUpdateList.isEmpty()){
            update accountUpdateList;
        }
    }
    
    // BR-4964 Update Related Account to National
    public static void updateRelatedDealerAccount(List<Case> newCaseList) {
        List<Id> accsToUpdateFieldGroupType = new List<Id>();
        for(Case c : newCaseList) {
            if(c.Update_Related_Account_to_National__c) {
                accsToUpdateFieldGroupType.add(c.Related_Dealer_Account__c);
            }
        }
        updateAccountFields(accsToUpdateFieldGroupType);
    }

    // BR-4964 Update Related Account to National
    public static void updateAccountFields(List<Id> accIds) {
        List<Account> accList = new List<Account>();
        for(Account a : [SELECT Id, Field_Group_Type__c FROM Account WHERE Id IN :accIds]) {
            a.Field_Group_Type__c = 'National';
            accList.add(a);
        }
        update accList;
    }

    /**  
    * BR-7921 Update billing cases Priority based on Case Reason. Validate if running user profile is allowed
    * to edit 
    * @author   Ramiro Alvarez
    * @date       02/16/2022
    */
    
    public static void setPriorityOnBillingCases(List<Case> newCases, Map<Id,Case> oldCaseMap) {
    
        // Get Billing recordTypeId
        Id billingRecordTypeId = caseRTNameIdMap.get('Billing');
        List<Case> billingCases = new List<Case> ();
        for (Case c : newCases) {
            if (c.RecordTypeId == billingRecordTypeId && 
                (oldCaseMap == null || (oldCaseMap.containsKey(c.Id) && (c.Priority != oldCaseMap.get(c.Id).Priority || 
                c.Reason != oldCaseMap.get(c.Id).Reason)))
            ) {
                billingCases.add(c);
            }
        }
        
        // If non-billing cases, return
        if (billingCases.isEmpty()) {
            return;
        }

        //Get Reasons and Priorities from custom metadata
        List<Billing_Case_Reason__mdt> casesReasonPriorityList = Billing_Case_Reason__mdt.getAll().values();    
        Map<String,String> reasonPriorityMap = new Map<String,String> ();
        for(Billing_Case_Reason__mdt bgr : casesReasonPriorityList) {
            reasonPriorityMap.put(bgr.Reason__c, bgr.Priority__c);
        }   

        //Get Allowed Profiles to edit Billing Case Priority
        List<Permissions_Settings__mdt> permissionsSettings = [
            SELECT Label, Is_Active__c,Permission_Type__c
            FROM Permissions_Settings__mdt
            WHERE Object__c = 'Case'
            AND Permission_Type__c = 'AllowEditPriorityBillingCase'
            AND Is_Active__c = true];

        Set<String> allowedProfiles = new Set<String> ();
        for (Permissions_Settings__mdt ps : permissionsSettings) {
            allowedProfiles.add(ps.Label);
        }

        //Get running User Profile Name
        User user = [
            SELECT Id, Profile.Name
            FROM User
            WHERE Id = :userinfo.getUserId()];

        //Loop through billing cases and populate Priority based on Reason
        for (Case c : billingCases) {
            if (oldCaseMap != null && c.Priority != oldCaseMap.get(c.Id).Priority) {
            if (allowedProfiles.contains(user.Profile.Name)) {
                continue;
            } else {
                // Throw error if running user profile is not allowed to edit priority field
                c.addError('Only Billing Managers can edit billing case priority');
            }
            } else if (oldCaseMap == null || c.Reason != oldCaseMap.get(c.Id).Reason) {
                c.Priority = reasonPriorityMap.containsKey(c.Reason) ? reasonPriorityMap.get(c.Reason) : c.Priority;
            }
        }
    }
    public static void updateFirstActivityDate(Map<ID,Task> tcIdMap) {
        if (tcIdMap.isEmpty()) { return; }
        
        List<Case> uCases = [select Id, OwnerId, First_Activity_Created__c from Case where Id in : tcIdMap.keySet()];
        
        List<Case> updCases = new List<Case>(); 
        
        for (Case c : uCases) {
            Task t = tcIdMap.get(c.Id);
            DateTime facDT = DateTime.now();
            if (t != null) { facDT = t.CreatedDate; }
            Boolean updCase = false;
            if (c.First_Activity_Created__c == null || c.First_Activity_Created__c > facDT) {
                c.First_Activity_Created__c = facDT;
                updCase = true;
            }
            if (updCase) {
                updCases.add(c);
            }
        }
        
        if (!updCases.isEmpty()) {
        TriggerHandler.bypass('CaseTriggerHandler');    
            update updCases;
        TriggerHandler.clearAllBypasses();   
        }
    }

    /**  
     * BR-4567 Capability to track case duration on Billing case: Stamp Re-Opened Date
     * @author   Ramiro Alvarez
     * @date       06/08/2022
    */
    public static void setReOpenedDateOnBillingCase(List<Case> newCases, Map<Id,Case> oldCaseMap) {

        // Get Billing recordTypeId
        Id billingRecordTypeId = caseRTNameIdMap.get('Billing');
        for (Case c : newCases) {
            if (c.RecordTypeId == billingRecordTypeId && 
            oldCaseMap.get(c.Id).Status != c.Status && c.Status == 'Reopen') {

                c.Re_Opened_Date_Time__c = DateTime.now();
            }
        }
    }    
        
    /**  
    * BR-4567 Capability to track case duration on Billing case: Calculate CG Duration
    * @author   Ramiro Alvarez
    * @date       06/08/2022
    */
    public static void setCGDurationTimeOnBillingCase(List<Case> newCases, Map<Id,Case> oldCaseMap) {

        // Get Billing recordTypeId
        Id billingRecordTypeId = caseRTNameIdMap.get('Billing');
        for (Case c : newCases) {
            if (c.RecordTypeId == billingRecordTypeId && 
            oldCaseMap.get(c.Id).Status != c.Status && c.Status == 'Closed') {

                // Get Opened Date (Created Date) or Re-Opened Date if was re open case
                Datetime initialDate = c.Re_Opened_Date_Time__c != null ? c.Re_Opened_Date_Time__c : c.CreatedDate;
                
                Double dt1 = initialDate.getTime(); // Returns the number of milliseconds of the initial date
                Double dt2 = DateTime.now().getTime(); // Returns the number of milliseconds of now 
                Double hours = (dt2 - dt1)/1000/60/60; // Do the math and convert to hours
                
                c.CG_Case_Duration__c = c.CG_Case_Duration__c != null ? c.CG_Case_Duration__c + hours : hours;
                if (c.Re_Opened_Date_Time__c != null) {
                //If was a Re-Opened case, just set value to blank
                c.Re_Opened_Date_Time__c = null;
                }
            }
        }
    }

    /**  
    * BR-987 
    * @author   Lawrence Z
    * @date       12/08/2022
    */
    public static void createTasks(List<Case> newCases) {

        Set<Id> caseOrderProducts = new Set<Id>();
        List<Case> productProvisionCases = new List<Case>();
        List<Case> geoExpansionProvisionCases = new List<Case>();
        List<Task> tasksToInsert = new List<Task>();
		
        for(Case c : newCases) {

            if(c.Order_Product__c != null && (c.Reason == 'Product Deactivation' || c.Reason == 'Product Activation')) {
                productProvisionCases.add(c);
                caseOrderProducts.add(c.Order_Product__c);
            }
        }

        if(caseOrderProducts.isEmpty()) {
            System.debug('Cases do not have order products, no tasks will be created');
            return;
        }

        Map<Id, OrderItem> orderItemDetails = new Map<Id, OrderItem>([SELECT Id, Product2.ProductCode 
                                                                      FROM OrderItem WHERE Id IN :caseOrderProducts]);

        for(Case c : productProvisionCases) {
            if(c.Order_Product__c != null) {
                String caseOrderProductCode = orderItemDetails.get(c.Order_Product__c).Product2.ProductCode;
                if(caseOrderProductCode.startsWithIgnoreCase('CG-DIG-DEAL-')) {
                    geoExpansionProvisionCases.add(c);
                }
            }
        }

        if(!geoExpansionProvisionCases.isEmpty()) {
            tasksToInsert.addAll(CaseTaskCreationProcessor.createDigitalDealGeoExpansionCaseTasks(geoExpansionProvisionCases));
        }

        insert tasksToInsert;
    }

    /**  
    * BR-987 
    * @author   Lawrence Z
    * @date       12/13/2022
    */
    public static void validateCaseClosure(List<Case> newCases, Map<Id, Case> oldCases) {

        List<Case> casesToQuery = new List<Case>();
        List<Id> casesToFlagError = new List<Id>();
        ID prodProvisionRecTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Product_Provision');

        for(Case c : newCases) {
            String caseOldStatus = oldCases.get(c.Id).Status;
            if(c.Status == 'Closed' && c.Status != caseOldStatus && 
               c.Order_Product__c != null &&
               c.RecordTypeId == prodProvisionRecTypeId && 
               (c.Reason == 'Product Activation' || c.Reason == 'Product Deactivation')) {
                casesToQuery.add(c);
            } 
        }

        if(casesToQuery.isEmpty()) { return; }
        
        for(Case c : [SELECT Id, Order_Product__c, Order_Product__r.Product2.ProductCode, (SELECT Id FROM Tasks WHERE Status != 'Completed') 
                      FROM Case 
                      WHERE Id IN :casesToQuery AND Order_Product__r.Product2.ProductCode LIKE 'CG-DIG-DEAL-%']) {

            if(c.Tasks.size() > 0) {
                casesToFlagError.add(c.Id);
            }
        }

        if(casesToFlagError.isEmpty()) { return; }

        for(Case c : newCases) {
            if(casesToFlagError.contains(c.Id)) {
                c.addError('All Tasks Must be Closed Before Closing Case');
            }
        }
    }
    public static void assignDDCases(List<Case> newCases){
        // DSS-36
        List<String> queueNames = new List<String>{'Digital Deal - AutoFi Update', 'Digital Deal - Service & Protection', 
        'Digital Deal - Financing','Digital Deal - Dealer Fees','Digital Deal - Profiles & Notifications'};
        Map<Id,Group> queueMap = new Map<Id,Group>([SELECT Id FROM Group WHERE Type = 'Queue' AND Name IN: queueNames]);
        Set<Id> accountIds = new Set<Id>();
        List<Case> processCaseRecords = new List<Case>();
        for (Case cas : newCases){
            if (queueMap.containsKey(cas.ownerId) && cas.origin == 'Email'){
                String subjectToSplit;
                subjectToSplit = cas.Subject;
                if (subjectToSplit.contains(':')){
                    String[] splitter = subjectToSplit.split(':');
                    if (splitter.size() >= 2 && splitter[1].startsWith('001') ){
                        cas.Reason = splitter[0];
                        Id matchedId = Id.valueOf(splitter[1]);
                        cas.AccountId = matchedId;
                        cas.origin = 'Onboarding';
                        accountIds.add(matchedId);
                    
                        processCaseRecords.add(cas);
                    }       
                }  
            }    
            if (processCaseRecords.isEmpty()){
                        return;
            }
        }
        Map<Id,Account> accountQueryMap = new Map<Id,Account>([SELECT Id,Name FROM Account WHERE Id IN:accountIds]);
        for(Case cs : processCaseRecords){
            Id relatedAccId = cs.AccountId;
            if(accountQueryMap.containsKey(relatedAccId)){
                cs.Subject = cs.Reason + ':' + accountQueryMap.get(relatedAccId).Name;
            }
        }
    }

    /**
     * DSS-367 - prevent assignment rules run again on update for CG created Cases
     * @author Justin Chang
     * @Created 2/23/2023
     */
    public static void preventAssignmentRulesOnUpdate(List<Case> cases) {

        for (Case c : cases) {
            if (c.Origin == CGORIGIN && c.RecordTypeId == caseRTDevNameIdMap.get('Support') 
                    && c.Force_Run_Assignment_Rules__c && String.valueOf(c.OwnerId).startsWith('005')) {
                c.Force_Run_Assignment_Rules__c = false;
            }
        }
    }

    /**  
     * SA-247 Value Review Onboarding Case Creation
    * @author   Ramiro Alvarez
    * @date       07/27/2022
    */
    
    // Commented out for SA-870
    /*
    
    public static void createOnBoardingCasesForValueReview(List<Case> newCases, Map<Id,Case> oldCaseMap) {
        
        Id onboardingCaseRecordTypeId = SObjectDescribeUtils.getRecordTypeIdByDevName('Case', 'Onboarding');    
        Map<Id,Case> casesToProcess = new Map<Id,Case> ();
        for (Case c : newCases) {
        if (c.RecordTypeId == onboardingCaseRecordTypeId &&
            c.Status == 'Closed' && oldCaseMap.get(c.Id).Status != 'Closed') {
            casesToProcess.put(c.Id,c);
            }
        }

        if (casesToProcess.isEmpty()) {
        return;
        }

        //Re-query cases with extended fields
        Map<Id,Case> caseMap = new Map<Id,Case> ([
        SELECT Id, AccountId, Account.Name, Related_Quote__r.SBQQ__Type__c, Account.Type,
            OwnerId,Related_Quote__c, Order__c, Related_Opportunity__c,Related_Opportunity__r.CloseDate,
            CountryCode__c,Reason
        FROM Case
        WHERE Id IN :casesToProcess.keySet()
        AND Account.Type = 'Customer'
        AND Related_Quote__r.SBQQ__Type__c != 'Amendment'
        AND Case_Resolution__c IN ('Fully engaged', 'Partially engaged', 'Unengaged')
        ]);

        if (caseMap.isEmpty()) {
        return;
        }

        //caseReasonSettingsMap will contain CountryCode and Reason as key and the Case Number (order) as a value
        Map<String,Decimal> caseReasonSettingsMap = new Map<String,Decimal> ();
        Map<String,String> caseNumberSettingsMap = new Map<String,String> ();
        List<Value_Review_Case_Creation_Setting__mdt> caseCreationSettings = [
        SELECT Id, Case_Number__c, Country_Code__c, Label
        FROM Value_Review_Case_Creation_Setting__mdt
        ORDER BY Country_Code__c, Case_Number__c ASC
        ];

        for (Value_Review_Case_Creation_Setting__mdt setting : caseCreationSettings) {
        //Build caseReasonSettingsMap: Country and Reason as a Key, the case number as a value
        String reasonKey = setting.Country_Code__c + '-' + setting.Label;
        caseReasonSettingsMap.put(reasonKey,setting.Case_Number__c);

        //Build caseNumberSettingsMap: Country and Number as a Key, the case reasoon as a value
        String caseNumberKey = setting.Country_Code__c + '-' + setting.Case_Number__c;
        caseNumberSettingsMap.put(caseNumberKey,setting.Label);
        }

        //Loop through cases that needs to be processed
        List<Case> newCasesToIns = new List<Case> ();
        for (Case c : caseMap.values()) {
        String caseReasonKey = c.CountryCode__c + '-' + c.Reason;
        if (!caseReasonSettingsMap.containsKey(caseReasonKey)) {
            continue;
        }

        Decimal currentCaseNumber = caseReasonSettingsMap.get(caseReasonKey);
        String caseNextNumberKey = c.CountryCode__c + '-' + (currentCaseNumber + 1);

        if (!caseNumberSettingsMap.containsKey(caseNextNumberKey)) {
            continue;
        }

        // Add new case to the list to be inserted
        newCasesToIns.add(createNewOnboardingCase(c,caseNumberSettingsMap.get(caseNextNumberKey)));
        }
        
        if (!newCasesToIns.isEmpty()) {
        insert newCasesToIns;
        }
    }

    //Map from Case Reasons to numbers of days after CloseDate to set Due Date
    private static Map<String, Integer> caseReasonNumberOfDaysMap = new Map<String, Integer> {
        '3 Month Value Review' => 90,
        '6 Month Value Review' => 180,
        '9 Month Value Review' => 270,
        'Renewal Value Review' => 360
    };

    private static Map<String, String> internalCommentsCaseReasonMap = new Map<String, String> {
        '3 Month Value Review' => 'Product review & performance review' + '\n' +
                                'Where would you like to see improvement?' + '\n' +
                                'Has it been easy to reach your rep when needed?' + '\n' +
                                'Has your rep reached your outreach expectations?' + '\n' +
                                'First attempt to categorize dealer' + '\n' +
                                ' - Needs Improvement' + '\n' +
                                ' - Meets Expectations' + '\n' + 
                                ' - Exceeds Expectations',
        '6 Month Value Review' => 'Product review & performance review' + '\n' +
                                'Recategorize dealer' + '\n' +
                                ' - Needs Improvement (Analyze pkg options, choose areas of improvement) '+ '\n' +
                                ' - Meets Expectations (Re-intro the AE, pick “wow” opportunity)'+ '\n' +
                                ' - Exceeds Expectations (Create buzz around upsell, engage AE to upsell opportunity)',      
        '9 Month Value Review' => 'Product review & performance review' + '\n' +
                                    'Set expectations for upcoming renewal' + '\n' +
                                    'Where would you like to see improvement?' + '\n' +
                                    'Has it been easy to reach your rep when needed?' + '\n' +
                                    'Has your rep reached your outreach expectations?' + '\n' +
                                    'Discuss dealership growth goals',
        'Renewal Value Review' => 'This is the last case of Value Review. Please add any further Notes if needed.'
    };

    private static Case createNewOnboardingCase(Case c, String reason) {

        Case newCase = new Case();
        newCase.AccountId = c.AccountId;
        newCase.OwnerId = c.OwnerId;
        newCase.Related_Quote__c = c.Related_Quote__c;
        newCase.Order__c = c.Order__c;
        newCase.Subject = reason + ' for ' + c.Account.Name;
        newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Onboarding').getRecordTypeId();
        newCase.Origin = 'Internal';
        newCase.Priority = 'Medium';
        newCase.Status = 'New';
        newCase.Reason = reason;
        newCase.Related_Opportunity__c = c.Related_Opportunity__c;
        newCase.Due_Date__c = c.Related_Opportunity__r.CloseDate.addDays(caseReasonNumberOfDaysMap.get(reason));
        newCase.Comments = internalCommentsCaseReasonMap.get(reason);
        return newCase;
    }

    */
    
}
  
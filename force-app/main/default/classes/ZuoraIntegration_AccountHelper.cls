// https://cargurus.atlassian.net/browse/BR-1144
// methods to assist in locating accounts to send to zuora and constructing integration messages
public without sharing class ZuoraIntegration_AccountHelper {
    
    static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;

    // if we are sending on-demand, delay send after datetime to avoid concurrent scheduled process picking same record
    static final Datetime SENDAFTERONDEMAND = Datetime.now().addMinutes(10);
    static final String PROCESS_ZACCOUNT = Integrations.PROCESS_ZACCOUNT;
    static final String REQUEST_STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
    static final String APPROVALSTATUS_APPROVED = ConstantsUtil.QUOTE_APPROVALSTATUS_APPROVED;
    static Map<Id, Account> accParentZuoraIdMap = new Map<Id, Account>();

    // for supplied quote ids, create zuora account messages for accounts that need creating in zuora
    public static void createAndSendZAccountMessages(Set<Id> quoteIds) {
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c) {
            return;
        }

        List<Integration_Message__c> zAccountMessages = getZAccountMessages(quoteIds);
        insert zAccountMessages;
        Integrations.sendMessageIdsToBoomi(zAccountMessages);
    }

    // for supplied quote ids, create zuora account messages for accounts that need creating in zuora
    public static void createAndSendZAccountMessages(List<Account> accounts) {
        List<Integration_Message__c> zAccountMessages = new List<Integration_Message__c>();
        accParentZuoraIdMap = getAccountMap(new Map<Id, Account>(accounts).keySet());

        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c) {
            return;
        }

        for (Account acc : accParentZuoraIdMap.values()) {
            zAccountMessages.add(createIntegrationMessage(acc));
        }

        insert zAccountMessages;
        Integrations.sendMessageIdsToBoomi(zAccountMessages);
    }

    // for supplied account ids, check if any related quotes approved and ready for zuora account to be created
    public static void checkAccountsForApprovedQuotes(Set<Id> accountIds) {
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c) {
            return;
        }

        // exclude any accounts that already have an integration message in progress
        accountIds.removeAll(getAccountIdsInProgress());

        Set<Id> quoteIds = new Map<Id,SBQQ__Quote__c>(
            [SELECT Id FROM SBQQ__Quote__c 
                WHERE ApprovalStatus__c = :APPROVALSTATUS_APPROVED AND Id IN 
                    (SELECT SBQQ__Quote__c FROM SBQQ__QuoteLine__c WHERE SBQQ__ProductOption__c = null 
                    AND (Billing_Account__c IN :accountIds OR Fulfillment_Account__c IN :accountIds))]
        ).keySet();

        if (!quoteIds.isEmpty()) {
            createAndSendZAccountMessages(quoteIds);
        }
    }

    // construct integration messages for accounts that need creating in zoura
    static List<Integration_Message__c> getZAccountMessages(Set<Id> quoteIds) {
        List<Integration_Message__c> returnMessages = new List<Integration_Message__c>();

        Map<Id,Id> accountIdQuoteIdMap = new Map<Id,Id>();
        Map<Id,Id> fAccountIdBAccountIdMap = new Map<Id,Id>();
        Set<Id> accountsToCheck = new Set<Id>();

        // go through quote lines to find all related billing and fulfillment accounts
        for (SBQQ__QuoteLine__c ql : getAccountQuoteLines(quoteIds)) {
            Id quoteId = ql.SBQQ__Quote__c;
            Id bAccountId = ql.Billing_Account__c;
            Id fAccountId = ql.Fulfillment_Account__c;

            accountIdQuoteIdMap.put(bAccountId, quoteId);

            // if the billing anf fulfillment accounts are different, keep a map of how they are related
            if (bAccountId != fAccountId) {
                accountIdQuoteIdMap.put(fAccountId, quoteId);
                fAccountIdBAccountIdMap.put(fAccountId, bAccountId);
            }
        }
        
        // query for accounts with all fields needed to construct zuora account messages
        Map<Id,Account> accountMap = getAccountMap(accountIdQuoteIdMap.keySet());

        for (Account a : accountMap.values()) {
            Id accountId = a.Id;

            // if this is a fulfillment account with no billing contact info, pull from the related billing account
            if (a.System_BillingContactEmail__c == null && fAccountIdBAccountIdMap.containsKey(accountId)) {
                Account ba = accountMap.get(fAccountIdBAccountIdMap.get(accountId));

                if (
                    ba.System_BillingContactFirst__c != null && 
                    ba.System_BillingContactLast__c != null &&
                    ba.System_BillingContactEmail__c != null 
                ) {
                    a.System_BillingContactFirst__c = ba.System_BillingContactFirst__c;
                    a.System_BillingContactLast__c =  ba.System_BillingContactLast__c;
                    a.System_BillingContactEmail__c = ba.System_BillingContactEmail__c;
                } else if (
                    ba.Billing_Account_Zuora__r.Zuora__BillToName__c != null &&
                    ba.Billing_Account_Zuora__r.Zuora__BillToWorkEmail__c != null
                ) {

                   List<String> splitName = ba.Billing_Account_Zuora__r.Zuora__BillToName__c.split(' ', 2);

                   if (splitName != null & splitName.size() > 0){
                       a.System_BillingContactFirst__c = splitName[0];
                       a.System_BillingContactLast__c = splitName[1];
                       a.System_BillingContactEmail__c = ba.Billing_Account_Zuora__r.Zuora__BillToWorkEmail__c;
                   }
                   
                }
            }

            // if the account already exists in zuora or does not have billing contact info, skip
            if (a.Billing_Account_Zuora__c != null || a.System_BillingContactEmail__c == null) {
                accountIdQuoteIdMap.remove(accountId);
            }
        }

        // query for all related quote info needed to construct zuora account messages
        Map<Id,SBQQ__Quote__c> quoteMap = getQuoteMap(accountIdQuoteIdMap.values());
        accountIdQuoteIdMap.keySet().removeAll(getAccountIdsInProgress());
        
        // create an integration message for each eligible account
        for (Id accountId : accountIdQuoteIdMap.keySet()) {
            returnMessages.add(
                createIntegrationMessage(accountMap.get(accountId), quoteMap.get(accountIdQuoteIdMap.get(accountId)))
            );
        }

        return returnMessages;
    }

    // create integration message for supplied account / quote
    public static Integration_Message__c createIntegrationMessage(Account a, SBQQ__Quote__c q) {
        return new Integration_Message__c(
            Account__c = a.Id,
            CPQ_Quote__c = q.Id,
            Request_Body__c = ZuoraIntegration_Account.serializeJSON(a, q),
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_ZACCOUNT,
            Send_After__c = SENDAFTERONDEMAND
        );
    }

    // create integration message for supplied account
    public static Integration_Message__c createIntegrationMessage(Account a) {
        return new Integration_Message__c(
            Account__c = a.Id,
            Request_Body__c = ZuoraIntegration_Account.serializeJSON(a).remove('billCycleDay'),
            Request_Status__c = REQUEST_STATUS_NEW,
            Process__c = PROCESS_ZACCOUNT,
            Send_After__c = SENDAFTERONDEMAND
        );
    }

    // query for quote lines related to supplied quote ids
    static List<SBQQ__QuoteLine__c> getAccountQuoteLines(Set<Id> quoteIds) {
        Set<Id> excludeAccountIds = getAccountIdsInProgress();

        return [SELECT Id, SBQQ__Quote__c, Billing_Account__c, Fulfillment_Account__c 
            FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :quoteIds AND SBQQ__ProductOption__c = null 
            AND Billing_Account__c != null AND Fulfillment_Account__c != null
            AND (Billing_Account__c NOT IN :excludeAccountIds OR Fulfillment_Account__c NOT IN :excludeAccountIds)];
    }

    // query account info needed for zuora account messages
    static Map<Id,Account> getAccountMap(Set<Id> accountIds) {
        return new Map<Id,Account>(
            [SELECT Id, Name, CurrencyISOCode, Account_Category_Formula__c, BillingStreet, BillingCity, 
                BillingStateCode, BillingPostalCode, BillingCountryCode, Billing_Account_Zuora__c, Dealer_ID__c, 
                Field_Group_Type__c, OwnerId, Owner.Name, Owner.Email, ParentId, Preferred_Language__c, 
                System_BillingContactFirst__c, System_BillingContactLast__c, System_BillingContactEmail__c, 
                VAT_Id__c, 
                Billing_Account_Zuora__r.Zuora__Zuora_Id__c, Billing_Account_Zuora__r.Zuora__BillToName__c, 
                Billing_Account_Zuora__r.Zuora__BillToWorkEmail__c, 
                Parent.Billing_Account_Zuora__c, Parent.Billing_Account_Zuora__r.Zuora__Zuora_Id__c, 
                Enrollment_Date__c,External_Dealer_ID__c,Division__c,iMR_funds__c,Co_Op_Program_Opt_In__c, 
                (SELECT Service_Provider_Id__c, Dealer_Type__c FROM Service_Provider__r ORDER BY Dealer_Type__c DESC NULLS LAST)
                FROM Account WHERE Id IN :accountIds]
        );
    }

    // query quote info needed for zuora account messages
    static Map<Id,SBQQ__Quote__c> getQuoteMap(List<Id> quoteIds) {
        return new Map<Id,SBQQ__Quote__c>(
            [SELECT Id, Payment_Method__c, SBQQ__PrimaryContact__r.FirstName, SBQQ__PrimaryContact__r.LastName, 
            SBQQ__PrimaryContact__r.Email FROM SBQQ__Quote__c WHERE Id IN :quoteIds]
        );
    }

    // check for accounts with related integration messages in progress
    static Set<Id> accountIdsInProgress;

    public static Set<Id> getAccountIdsInProgress() {
        if (accountIdsInProgress == null) {
            accountIdsInProgress = new Set<Id>();

            for (Integration_Message__c im : [SELECT Id, Account__c FROM Integration_Message__c
                WHERE Account__c != null AND Process__c = :Integrations.PROCESS_ZACCOUNT
                AND Request_Status__c IN :Integrations.REQUEST_STATUSES_TO_PROCESS]) 
            {
                accountIdsInProgress.add(im.Account__c);
            }
        }
        return accountIdsInProgress;
    }
}

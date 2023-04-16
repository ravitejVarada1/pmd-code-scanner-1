// https://cargurus.atlassian.net/browse/BR-1499
public without sharing class ZuoraIntegration_InvoiceHelper {
    
    static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;

    // if we are sending on-demand, delay send after datetime to avoid concurrent scheduled process picking same record
    static final Datetime SENDAFTERONDEMAND = Datetime.now().addMinutes(10);
    static final Datetime SENDINQUEUE = Datetime.now().addMinutes(-10);
    static final String PROCESS_ZBILLING = Integrations.PROCESS_ZBILLING;
    static final String REQUEST_STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
    static final String ACTIVATIONSTATUS_PENDING = ConstantsUtil.ACTIVATION_STATUS_PENDING;
    static final String ACTIVATIONSTATUS_NA = ConstantsUtil.ACTIVATION_STATUS_NA;
    static final String CASE_SUBJECT_MANUALBILLING  = 'Manual Billing Required';
    static final String CASE_ORIGIN_INTERNAL = 'Internal';
    static final String CASE_REASON_MANUALINVOICE = 'Billing: Manual Invoice';
    static final String CASE_CATEGORY_MANUALINVOICE = 'Billing: Manual Invoice';
    static final String CASE_STATUS_NEW = 'New';
    static final Id CASE_BILLING_RTID = SObjectDescribeUtils.getRecordTypeIdByName('Case', 'Billing');

    public static void createAndSendZBillingMessages(Set<Id> orderIds, Boolean sendImmediately) {
        if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c || orderIds.isEmpty()) {
            return;
        }

        // if not in async context, kick to future method
        if (!System.isBatch() && !System.isFuture() && !Test.isRunningTest()) {
            createAndSendZBillingMessagesFuture(orderIds, sendImmediately);
            return;
        }

        // query for accounts / cpq subs related to supplied order ids that are ready to be billed
        Map<Id,Account> billingAccounts = getInvoiceReadyAccounts(orderIds);

        Map<Id,Order> updateOrderMap = new Map<Id,Order>();
        List<Case> manualBillingCases = new List<Case>();
        List<Integration_Message__c> zBillingMessages = new List<Integration_Message__c>();

        // check each account's related subscriptions to see if the related order needs an invoice or not
        // based on the date of change compared to the invoice target date
        // also take into account whether the related quote is designated for manual billing
        for (Account a : billingAccounts.values()) {
            Id accountId = a.Id;
            Date targetDate;
            //for auto pay it should be today
            if(a.Billing_Account_Zuora__r.Zuora__AutoPay__c) {
                targetDate = Date.today();
            } else {
                targetDate = Date.today().addMonths(2).toStartOfMonth().addDays(-1);
            }
            Date invoiceDate = Date.today();
            Id intMsgOrderId;
            Id intMsgQuoteId;
            Set<Id> manualBillingOrderIds = new Set<Id>();
            Set<Id> manualBillingQuoteIds = new Set<Id>();

            // since we will have multiple cpq subs per order, keep track of which orders we have already processed
            Set<Id> processedOrderIds = new Set<Id>();

            // loop through cpq subscriptions
            for (SBQQ__Subscription__c cpqSub : a.CPQ_Subscription_Billing__r) {
                Id orderId = cpqSub.SBQQ__OrderProduct__r.OrderId;

                // if we have already processed this related order, skip
                if (processedOrderIds.contains(orderId)) {
                    continue;
                }
                processedOrderIds.add(orderId);

                Id quoteId = cpqSub.SBQQ__QuoteLine__r.SBQQ__Quote__c;
                Date effectiveDate = cpqSub.SBQQ__OrderProduct__r.Order.EffectiveDate;

                // if the effective date is later than the target date, no invoice needed
                Boolean noInvoiceNeeded = effectiveDate > targetDate;
                Boolean manualBilling =     // check if this quote is set for manual billing
                    cpqSub.SBQQ__QuoteLine__r.SBQQ__Quote__r.Prevent_Automated_Initial_Invoice_Formul__c;

                // if we won't invoice this order, set the related status field to n/a
                if (noInvoiceNeeded || manualBilling) {
                    updateOrderMap.put(orderId, 
                        new Order(
                            Id = orderId,
                            Activation_Zuora_Invoice__c = ACTIVATIONSTATUS_NA
                        )
                    );

                    // if this is for manual billing, keep track so we can create a case for this account
                    if (manualBilling) {
                        manualBillingOrderIds.add(orderId);
                        manualBillingQuoteIds.add(quoteId);
                    }
                } else {    // if we do need to bill this order, keep track of the quote / order ids
                    intMsgOrderId = orderId;
                    intMsgQuoteId = quoteId;
                }
            }

            // if we have a quote for manual billing, create a cases
            if (!manualBillingQuoteIds.isEmpty()) {
                String description = CASE_SUBJECT_MANUALBILLING+'\n'+
                    'Billing Account: '+a.Name+'\n';

                description += getRelatedLinkString('Related Quote Link', manualBillingQuoteIds);
                description += getRelatedLinkString('Related Order Link', manualBillingOrderIds);
                Group billingQueue = [SELECT ID FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Billing_Case_Queue'];

                manualBillingCases.add( 
                    new Case(
                        AccountId = accountId,
                        RecordTypeId = CASE_BILLING_RTID,
                        Subject = CASE_SUBJECT_MANUALBILLING,
                        Origin = CASE_ORIGIN_INTERNAL,
                        Reason = CASE_REASON_MANUALINVOICE,
                        //removing category since was informed not required
                        //Category__c = CASE_REASON_MANUALINVOICE,
                        Status = CASE_STATUS_NEW,
                        Description = description,
                        OwnerId  = billingQueue.Id  
                    )
                );
            }
            
            // if we have orders to bill, create an integration message
            if (intMsgOrderId != null) {
                String zAccountId = a.Billing_Account_Zuora__r.Zuora__External_Id__c;

                zBillingMessages.add(
                    new Integration_Message__c(
                        Account__c = accountId,
                        CPQ_Quote__c = intMsgQuoteId,
                        CPQ_Order__c = intMsgOrderId,
                        Request_Body__c = ZuoraIntegration_Invoice.serializeJSON(zAccountId, invoiceDate, targetDate),
                        Request_Status__c = REQUEST_STATUS_NEW,
                        Process__c = PROCESS_ZBILLING,
                        Send_After__c = (sendImmediately ? SENDAFTERONDEMAND : SENDINQUEUE)
                    )
                );
            }
        }

        // insert / update records as needed
        if (!updateOrderMap.isEmpty()) {
            update updateOrderMap.values();
        }

        if (!manualBillingCases.isEmpty()) {
            insert manualBillingCases;
        }

        if (!zBillingMessages.isEmpty()) {
            insert zBillingMessages;
            if (sendImmediately) {
                Integrations.sendMessageIdsToBoomi(zBillingMessages);
            }
        }
    }

    // add quote / order links to case description
    static String getRelatedLinkString(String baseString, Set<Id> linkIds) {
        String returnString = baseString+(linkIds.size() > 1 ? 's: \n' : ': ');

        for (String linkId : linkIds) {
            returnString += URL.getOrgDomainUrl().toExternalForm()+'/'+linkId+'\n';
        }

        return returnString;
    }

    @future // round trip back to main method in a future context
    static void createAndSendZBillingMessagesFuture(Set<Id> orderIds, Boolean sendImmediately) {
        createAndSendZBillingMessages(orderIds, sendImmediately);
    }

    // query for accounts related to supplied order ids that are ready to be billed based on all related unprocessed 
    // orders being in pending status for invoicing
    static Map<Id,Account> getInvoiceReadyAccounts(Set<Id> orderIds) {
        return new Map<Id,Account>(
            [SELECT Id, Name, Billing_Account_Zuora__r.Zuora__External_Id__c, 
                Billing_Account_Zuora__r.Zuora__AutoPay__c, 
                (SELECT Id, SBQQ__OrderProduct__r.OrderId, SBQQ__OrderProduct__r.Order.EffectiveDate, 
                    SBQQ__QuoteLine__r.SBQQ__Quote__c, 
                    SBQQ__QuoteLine__r.SBQQ__Quote__r.Prevent_Automated_Initial_Invoice_Formul__c 
                    FROM CPQ_Subscription_Billing__r 
                    WHERE SBQQ__OrderProduct__r.Order.Activation_Zuora_Invoice__c = :ACTIVATIONSTATUS_PENDING)
            FROM Account WHERE Id IN (SELECT Billing_Account__c FROM SBQQ__Subscription__c 
                    WHERE SBQQ__OrderProduct__r.OrderId IN :orderIds 
                    AND SBQQ__OrderProduct__r.Order.Activation_Zuora_Invoice__c = :ACTIVATIONSTATUS_PENDING)
            AND Id NOT IN (SELECT Billing_Account__c FROM OrderItem WHERE Order.Activation_Zuora_Invoice__c = null)]
        );
    }

}

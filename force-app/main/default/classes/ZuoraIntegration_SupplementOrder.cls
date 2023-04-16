/**
 * BR-1273, Zuora Order API implementation that can be used for terms and conditions amendments
 * or can be extended to accomodate other types of amendments. For Contract amendments such as 
 * cancellations, product/rate changes etc. refer to ZuoraIntegration_Order.cls
 */

public without sharing class ZuoraIntegration_SupplementOrder {

    //serilize the Zorder into a JSON message structure, this method is for a terms and conditions
    //amendment to set the AutoRenew to false, overload to add other features, enhancements
    public static String getSerializedTermsOrder(SBQQ__Subscription__c cpqBaseSub, Boolean autoRenew) {
        String jsonOrder = JSON.serializePretty(new ZOrder(cpqBaseSub, 'TermsAndConditions', autoRenew), true);
        return jsonOrder;
    }

    public static String getSerializedCommitmentTermsOrder(
            SBQQ__Subscription__c cpqBaseSub, 
            Boolean autoRenew,
            Integer period, 
            String periodType, 
            String termType
        ) {
        String jsonOrder = JSON.serializePretty(new ZOrder(cpqBaseSub, 'TermsAndConditions', period, periodType, termType), true);
        return jsonOrder;
    }

    // BR-3733 Get serialized method 
    public static String getSerializedTransferOwner(SBQQ__Subscription__c cpqBaseSub, String accountNumNew) {
        String jsonOrder = JSON.serializePretty(new ZOrder(cpqBaseSub, 'OwnerTransfer', accountNumNew), true);
        return jsonOrder;
    }

    public static String getSerializedRenewalOrder(SBQQ__Subscription__c cpqBaseSub, String actionType) {
        String jsonOrder = JSON.serializePretty(new ZOrder(cpqBaseSub, actionType), true);
        return jsonOrder;
    }

    //represents the Zuora API Order object
    class ZOrder {
        Date orderDate;
        String existingAccountNumber;
        List<ZSubscription> subscriptions;
        ZProcessingOptions processingOptions;

        //this constructor takes in the base bundle cpq subscriptions and action type 
        public ZOrder(SBQQ__Subscription__c cpqBaseSub, String orderActionType) {
            this.subscriptions = new List<ZSubscription>();

            this.orderDate = Date.today();
            this.existingAccountNumber = cpqBaseSub.Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c;
            this.subscriptions.add(new ZSubscription(cpqBaseSub, orderActionType));
            this.processingOptions = new ZProcessingOptions(false, false);
        }

        //this constructor takes in the base bundle cpq subscriptions, an action type and an auto renew boolean value
        public ZOrder(SBQQ__Subscription__c cpqBaseSub, String orderActionType, Boolean autoRenew) {
            this.subscriptions = new List<ZSubscription>();

            this.orderDate = Date.today();
            this.existingAccountNumber = cpqBaseSub.Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c;
            this.subscriptions.add(new ZSubscription(cpqBaseSub, orderActionType, autoRenew));
            this.processingOptions = new ZProcessingOptions(false, false);
        }

        //this one for commitment term
        public ZOrder(SBQQ__Subscription__c cpqBaseSub, String orderActionType, 
            Integer period, String periodType, String termType) 
        {
            this.subscriptions = new List<ZSubscription>();

            this.orderDate = Date.today();
            this.existingAccountNumber = cpqBaseSub.Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c;
            this.subscriptions.add(
                new ZSubscription(cpqBaseSub, orderActionType, period, periodType, termType)
            );
            this.processingOptions = new ZProcessingOptions(false, false);
        }

        // BR-3733 Constructor for change owner
        public ZOrder(SBQQ__Subscription__c cpqBaseSub, String orderActionType,String accountNumNew) 
        {
            this.subscriptions = new List<ZSubscription>();
            this.orderDate = Date.today();
            //BR-9319 getting existing account number from Invoice Owner, previously acquired from Billing Account
            this.existingAccountNumber = cpqBaseSub.Zuora_Subscription__r.Zuora__InvoiceOwner__r.Zuora__AccountNumber__c;
            this.subscriptions.add(
                new ZSubscription(cpqBaseSub, orderActionType, accountNumNew)
            );
            this.processingOptions = new ZProcessingOptions(false, false);
        }
    }

    //Represents a Zuora Subscription API object
    //nested within the Zuora Order
    class ZSubscription {
        String subscriptionNumber;
        List<ZOrderAction> orderActions;

        public ZSubscription(SBQQ__Subscription__c cpqBaseSub, String orderActionType) {
            this.subscriptionNumber = cpqBaseSub.SBQQ__RevisedSubscription__r.Zuora_Subscription_Number__c;
            this.orderActions = new List<ZOrderAction>{new ZOrderAction(orderActionType)};
        }

        public ZSubscription(SBQQ__Subscription__c cpqBaseSub, String orderActionType, Boolean autoRenew) {
            this.subscriptionNumber = cpqBaseSub.Zuora_Subscription_Number__c;
            this.orderActions = new List<ZOrderAction>{new ZOrderAction(orderActionType, autoRenew)};
        }

        public ZSubscription(SBQQ__Subscription__c cpqBaseSub, String orderActionType,
            Integer period, String periodType, String termType) 
        {
            this.subscriptionNumber = cpqBaseSub.Zuora_Subscription_Number__c;
            this.orderActions = new List<ZOrderAction>{
                new ZOrderAction(orderActionType, period, periodType, termType)
            };
        }

        // BR-3733 Constructor for change owner
        public ZSubscription(SBQQ__Subscription__c cpqBaseSub, String orderActionType, String accountNumNew) 
        {
            this.subscriptionNumber = cpqBaseSub.Zuora_Subscription_Number__c;
            this.orderActions = new List<ZOrderAction>{
                new ZOrderAction(orderActionType, accountNumNew)
            };
        }
    }

    //Represents an Order Action, nested within the ZSubscription
    class ZOrderAction {
        String type;
        List<ZTriggerDate> triggerDates;
        ZTermsAndConditions termsAndConditions;
        ZTransferOwner ownerTransfer;

        public ZOrderAction(String type) {
            this.type = type;
            this.triggerDates = getZTriggerDates();
        }

        public ZOrderAction(String type, Boolean autoRenew) {
            this.type = type;
            this.triggerDates = getZTriggerDates();
            this.termsAndConditions = new ZTermsAndConditions(autoRenew);
        }

        public ZOrderAction(String type, Integer period, String periodType, String termType) {
            this.type = type;
            this.triggerDates = getZTriggerDates();
            this.termsAndConditions = new ZTermsAndConditions(period, periodType, termType);
        }
        
        public ZOrderAction(String type, String accountNumNew) {
            this.type = type;
            this.triggerDates = getZTriggerDates();
            this.ownerTransfer = new ZTransferOwner(accountNumNew);
        }
    }

    //Represents the Zuora Trigger Dates, nested within the ZOrderAction
    class ZTriggerDate {
        String name;
        Date triggerDate;

        public ZTriggerDate(String name, Date triggerDate) {
            this.name = name;
            this.triggerDate = triggerDate;
        }
    }

    //Represents the  ZTermsAndCondition, nested within the ZOrderAction
    class ZTermsAndConditions {
        Boolean autoRenew = false;
        String renewalSetting = 'RENEW_WITH_SPECIFIC_TERM'; 
        ZLastTerm lastTerm;

        public ZTermsAndConditions(Boolean autoRenew) {
            this.autoRenew = autoRenew;
        }

        public ZTermsAndConditions(Integer period, String periodType, String termType) {
            this.autoRenew = true;
            this.lastTerm = new ZLastTerm(period, periodType, termType);
        }
    }

    //Represents the  ZTransferOwner, nested within the ZOrderAction
    class ZTransferOwner {
        // String destinationAccountNumber;
        String destinationInvoiceAccountNumber;

        public ZTransferOwner(String accountNumNew) {
            this.destinationInvoiceAccountNumber = accountNumNew;
        }
    }

    class ZLastTerm {
        Integer period;
        String periodType;
        String termType;

        public ZLastTerm(Integer period, String periodType, String termType) {
            this.period = period;
            this.periodType = periodType;
            this.termType = termType;
        }
    }

    //Represents the ZProcessingOptions, nested within the ZOrder
    class ZProcessingOptions {
        Boolean runBilling;
        Boolean collectPayment;

        public ZProcessingOptions(Boolean runBilling, Boolean collectPayment) {
            this.runBilling = runBilling;
            this.collectPayment = collectPayment;
        }
    }

    //Setup default ZTriggerDates, overload this if we 
    //need other trigger dates
    public static List<ZTriggerDate> getZTriggerDates() {
        List<ZTriggerDate> zTriggerDates = new List<ZTriggerDate>{
            new ZTriggerDate('ContractEffective', Date.today()),
            new ZTriggerDate('ServiceActivation', Date.today()),
            new ZTriggerDate('CustomerAcceptance', Date.today())
        };
        return zTriggerDates;
    }
}
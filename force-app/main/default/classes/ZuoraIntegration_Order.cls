// https://cargurus.atlassian.net/browse/BR-894
// this class represents the zuora order json structure used in the integration message that creates the order
public without sharing class ZuoraIntegration_Order {

    String existingAccountNumber;
    Date orderDate; //date the order is signed
    String orderNumber;
    String description;
    List<ZSubscription> subscriptions;

    // constructor takes a list of base bundle cpq subs, and a map of pending subs by related base bundle sub id
    // we should always have only one base bundle for new subscriptions
    // for amendments we could have two, if the amendment is removing one sub and creating another
    public ZuoraIntegration_Order(List<SBQQ__Subscription__c> baseCPQSubList, 
        Map<Id,List<SBQQ__Subscription__c>> pendingCPQSubMap, Map<Id,Integer> amendmentCPQSubMap) 
    {
        this.orderDate = Date.today();
        this.subscriptions = new List<ZSubscription>();

        // go through supplied base bundles
        for (SBQQ__Subscription__c baseCPQSub : baseCPQSubList) {
            String zAccountNum = baseCPQSub.Billing_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c;
            Integer commitmentPeriod = null;

            // if we are seeing a billing account mismatch, throw an error
            if (this.existingAccountNumber != null && this.existingAccountNumber != zAccountNum) {
                this.existingAccountNumber = 'ERROR: Multiple Billing Accounts on a single Order';
                break;
            }

            // get all pending cpq subs related to this base bundle
            List<SBQQ__Subscription__c> cpqSubList = pendingCPQSubMap.get(baseCPQSub.Id);

            if (amendmentCPQSubMap != null) {
                 // get commitment period related to this base bundle
                 commitmentPeriod = amendmentCPQSubMap.get(baseCPQSub.Id);
            }


            // get either the base bundle (if the related sub list is null / cancellation) or the first sub on the list
            SBQQ__Subscription__c firstOrderSub = (cpqSubList != null) ? cpqSubList[0] : baseCPQSub;

            this.existingAccountNumber = zAccountNum;
            this.orderNumber = firstOrderSub.SBQQ__OrderProduct__r.Order.OrderNumber;
            this.description = URL.getOrgDomainUrl().toExternalForm()+'/'+firstOrderSub.SBQQ__OrderProduct__r.OrderId;

            // set up all subscription data for this base bundle / related cpq subs using ZSubscription constructor
            this.subscriptions.add(new ZSubscription(baseCPQSub, cpqSubList, commitmentPeriod));
        }
    }

    // inner class representing instance of order subscription data
    class ZSubscription {
        String subscriptionNumber;
        List<ZOrderAction> orderActions;
        Map<String,String> customFields;

        public ZSubscription(SBQQ__Subscription__c baseCPQSub, List<SBQQ__Subscription__c> cpqSubList, Integer commitmentPeriod) {
            String cancelZSubNumber = baseCPQSub.SBQQ__RevisedSubscription__r.Zuora_Subscription_Number__c;
            String amendZSubNumber = baseCPQSub.Zuora_Subscription_Number__c;

            System.debug('baseCPQSub: '+baseCPQSub);

            this.customFields = new Map<String,String>{
                'SalesforceContractID__c' => baseCPQSub.SBQQ__Contract__c
            };

            // depending on the type of order, set up one or more order actions
            if (cancelZSubNumber != null) { // for cancellation, construct a single order action
                this.subscriptionNumber = cancelZSubNumber;
                this.orderActions = new List<ZOrderAction>{
                    new ZOrderAction('CancelSubscription', baseCPQSub.SBQQ__StartDate__c)
                };
            }
            else if (amendZSubNumber != null) { // for amendments, construct needed add / remove order actions
                this.subscriptionNumber = amendZSubNumber;
                this.orderActions = getAmendmentOrderActions(cpqSubList, commitmentPeriod);
            }
            else {
                this.orderActions = new List<ZOrderAction>{ // for creation, construct a single order action
                    new ZOrderAction('CreateSubscription', baseCPQSub, cpqSubList)
                };
            }
        }
    }

    // method to construct needed add / remove order actions for amendments
    static List<ZOrderAction> getAmendmentOrderActions(List<SBQQ__Subscription__c> cpqSubList, Integer commitmentPeriod) {
        List<ZOrderAction> returnList = new List<ZOrderAction>();
        
        for (SBQQ__Subscription__c cpqSub : cpqSubList) {
            if (cpqSub.SBQQ__Quantity__c > 0) { // if quantity is greater than 0, contruct add action
                returnList.add(new ZOrderAction('AddProduct', cpqSub));
            } else {    // if quantity is <= 0, contruct remove action
                returnList.add(new ZOrderAction('RemoveProduct', cpqSub));
            }

            // BR-5591
            if (commitmentPeriod != null) {
                returnList.add(new ZOrderAction('TermsAndConditions', cpqSub, commitmentPeriod));
            }
        }

        return returnList;
    }

    // represents instance of a single order action of any type
    class ZOrderAction {
        String type;    // CreateSubscription, CancelSubscription, AddProduct, RemoveProduct, 
                        // TermsAndConditions, UpdateProduct, RenewSubscription, OwnerTransfer, Suspend, Resume
        ZCreateSubscription createSubscription;
        ZCancelSubscription cancelSubscription;
        ZAddProduct addProduct;
        ZRemoveProduct removeProduct;
        ZTermsAndConditions termsAndConditions;
        List<ZTriggerDate> triggerDates;
        ZUpdateProduct updateProduct;
        String subscriptionNumber;  // null for create, otherwise set to target subscription number

        // constructor to handle cancellations
        public ZOrderAction(String orderActionType, Date cancelDate) {
            this.type = orderActionType;
            
            if (orderActionType == 'CancelSubscription') {
                this.cancelSubscription = new ZCancelSubscription(cancelDate);
            }
        }

        // constructor to handle new subscriptions
        public ZOrderAction(String orderActionType, SBQQ__Subscription__c baseCPQSub, 
            List<SBQQ__Subscription__c> cpqSubList) 
        {
            this.type = orderActionType;
            Date orderActionDate = cpqSubList[0].SBQQ__StartDate__c;

            // set order action trigger dates based on first pending cpq subscription
            this.triggerDates = new List<ZTriggerDate>{
                new ZTriggerDate('ServiceActivation', orderActionDate),
                new ZTriggerDate('ContractEffective', orderActionDate)
            };

            if (orderActionType == 'CreateSubscription') {
                this.createSubscription = new ZCreateSubscription(baseCPQSub, cpqSubList);
            }
        }

        // constructor to handle add / remove product
        public ZOrderAction(String orderActionType, SBQQ__Subscription__c cpqSub) {
            this.type = orderActionType;
            Date orderActionDate = cpqSub.SBQQ__StartDate__c;

            // set order action trigger dates based on supplied pending cpq subscription
            this.triggerDates = new List<ZTriggerDate>{
                new ZTriggerDate('ServiceActivation', orderActionDate),
                new ZTriggerDate('ContractEffective', orderActionDate)
            };

            // use add product inner class constructor to add product
            if (orderActionType == 'AddProduct') {
                this.addProduct = new ZAddProduct(cpqSub);
            } else if (orderActionType == 'RemoveProduct') {  // use remove product inner class constructor for removal
                String zSubRatePlanId = cpqSub.SBQQ__RevisedSubscription__r.Zuora_Rate_Plan_Id__c;
                if (zSubRatePlanId != null) {
                    this.removeProduct = new ZRemoveProduct(zSubRatePlanId);
                }
            }
        }

        // BR-5592
        // constructor to handle terms and conditions
        public ZOrderAction(
            String orderActionType, 
            SBQQ__Subscription__c cpqSub, 
            Integer commitmentPeriod
        ) {
            this.type = orderActionType;
            Date orderActionDate = cpqSub.SBQQ__StartDate__c;

            // set order action trigger dates based on supplied pending cpq subscription
            this.triggerDates = new List<ZTriggerDate>{
                new ZTriggerDate('ServiceActivation', orderActionDate),
                new ZTriggerDate('ContractEffective', orderActionDate)
            };
            
            if (orderActionType == 'TermsAndConditions') {
                this.termsAndConditions =  new ZTermsAndConditions(commitmentPeriod);
            }
        }
    }

    // represents an instance of a create subscription action within the order action instance
    class ZCreateSubscription {
        String subscriptionNumber;
        String subscriptionOwnerAccountNumber;
        String notes;
        List<ZAddProduct> subscribeToRatePlans;
        ZTerms terms;

        public ZCreateSubscription(SBQQ__Subscription__c baseCPQSub, List<SBQQ__Subscription__c> cpqSubList) {
            this.subscriptionNumber = baseCPQSub.Name;
            this.subscriptionOwnerAccountNumber = 
                baseCPQSub.Fulfillment_Account__r.Billing_Account_Zuora__r.Zuora__AccountNumber__c;
            this.notes = URL.getOrgDomainUrl().toExternalForm()+'/'+cpqSubList[0].SBQQ__OrderProduct__r.OrderId;

            // use getAddProducts() method to generate instances of add product object
            this.subscribeToRatePlans = getAddProducts(cpqSubList);
            this.terms = new ZTerms(baseCPQSub.SBQQ__StartDate__c, baseCPQSub.SBQQ__EndDate__c.addDays(1));
        }
    }

    // method to generate instances of add product object for each cpq subscription to be added
    static List<ZAddProduct> getAddProducts(List<SBQQ__Subscription__c> cpqSubList) {
        List<ZAddProduct> returnList = new List<ZAddProduct>();

        for (SBQQ__Subscription__c cpqSub : cpqSubList) {
            returnList.add(new ZAddProduct(cpqSub));
        }

        return returnList;
    }

    // represents instance of cancel subscription action within order action
    class ZCancelSubscription {
        String cancellationPolicy = 'SpecificDate';  // EndOfCurrentTerm, EndOfLastInvoicePeriod, SpecificDate
        Date cancellationEffectiveDate;

        public ZCancelSubscription(Date orderActionDate) {
            this.cancellationEffectiveDate = orderActionDate;
        }
    }

    // represents single instance of add product action within order action
    class ZAddProduct {
        String productRatePlanId;
        List<ZChargeOverride> chargeOverrides;
        Map<String,String> customFields;
        
        // constructor takes cpq subscription and uses it to set rate plan id and set charge parameters
        public ZAddProduct(SBQQ__Subscription__c cpqSub) {
            Product2 p = ZuoraIntegration_OrderHelper.PRODUCTMAP.get(cpqSub.SBQQ__Product__c);

            this.productRatePlanId = p.Zuora_Product_Rate_Plan_ID__c;
            this.chargeOverrides = getChargeOverrides(cpqSub, p);
            this.customFields = new Map<String,String> { 
                'CPQ_Subscription_Id__c' => cpqSub.Name
            };
        }
    }

    // method to set up charge overrides for monthly total and intro discount (if applicable)
    static List<ZChargeOverride> getChargeOverrides(SBQQ__Subscription__c cpqSub, Product2 p) {

        // set up monthly charge
        List<ZChargeOverride> returnList = new List<ZChargeOverride>{new ZChargeOverride(cpqSub, p)};

        // set up intro discount charge
        if (cpqSub.Intro_Discount_Percentage__c != null) {
            returnList.add(new ZChargeOverride(cpqSub, p.Zuora_Product_Rate_Plan_Charge_Disc_ID__c));
        }

        return returnList;
    }

    // represents single instance of remove product action within order action
    class ZRemoveProduct {
        String ratePlanId;

        public ZRemoveProduct(String zSubRatePlanId) {
            this.ratePlanId = zSubRatePlanId;
        }
    }

    // instance of terms and conditions object within order action - will be used to enable / disable autorenew
    class ZTermsAndConditions {
        Boolean autoRenew = false;
        String renewalSetting = 'RENEW_WITH_SPECIFIC_TERM'; 
        ZLastTerm lastTerm;

        public ZTermsAndConditions(Boolean autoRenew) {
            this.autoRenew = autoRenew;
        }

        public ZTermsAndConditions(Integer period) {
            this.autoRenew = true;
            this.lastTerm = new ZLastTerm(period, 'Day', 'TERMED');
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

    // represents instance of trigger date within order action, used to activate subscription / amendments
    class ZTriggerDate {
        String name;    // ContractEffective, ServiceActivation, CustomerAcceptance
        Date triggerDate;

        public ZTriggerDate(String name, Date triggerDate) {
            this.name = name;
            this.triggerDate = triggerDate;
        }
    }

    // represents single charge override - used to set amount, listprice custom field, and intro discounts
    class ZChargeOverride {
        String productRatePlanChargeId;
        String chargeNumber;
        ZChargePricing pricing;
        ZChargeBilling billing;
        ZChargeEndDate endDate;
        Map<String,String> customFields;

        // constructor for monthly charge
        public ZChargeOverride(SBQQ__Subscription__c cpqSub, Product2 p) {
            this.productRatePlanChargeId = p.Zuora_Product_Rate_Plan_Charge_ID__c;
            this.chargeNumber = cpqSub.Name;
            this.billing = new ZChargeBilling(cpqSub);
            this.pricing = new ZChargePricing(cpqSub, p.Zuora_Charge_Model__c);
            this.customFields = new Map<String,String>{
                'CustomerListPrice__c' => String.valueOf(cpqSub.SBQQ__ListPrice__c)
            };
        }

        // constructor for intro discount charge
        public ZChargeOverride(SBQQ__Subscription__c cpqSub, String discountRatePlanId) {
            this.productRatePlanChargeId = discountRatePlanId;
            this.chargeNumber = cpqSub.Name+'-INTRO';
            this.pricing = new ZChargePricing(cpqSub, ZuoraIntegration_OrderHelper.ZCHARGEMODEL_DISCOUNT);
            this.endDate = new ZChargeEndDate(cpqSub);
        }
    }

    // instance of charge end date, currently used only to set end date for intro discount charge
    class ZChargeEndDate {
        String endDateCondition = 'Specific_End_Date';    // Subscription_End, Fixed_Period, Specific_End_Date
        Date specificEndDate;

        public ZChargeEndDate(SBQQ__Subscription__c cpqSub) {
            Date firstOfStartMonth = cpqSub.SBQQ__StartDate__c.toStartOfMonth();
            Integer discountPeriods = Integer.valueOf(cpqSub.Intro_Discount_Period__c);
            this.specificEndDate = firstOfStartMonth.addMonths(discountPeriods).addDays(-1);
        }
    }

    // instance of charge pricing, used to set monthly total, quantity (if applicable), and intro discount (if applicable)
    class ZChargePricing {
        ZChargePricingDiscount discount;
        ZChargePricingRecurringFlatFee recurringFlatFee;
        ZChargePricingRecurringPerUnit recurringPerUnit;

        public ZChargePricing(SBQQ__Subscription__c cpqSub, String zChargeModel) {
            if (zChargeModel == ZuoraIntegration_OrderHelper.ZCHARGEMODEL_DISCOUNT) {
                this.discount = new ZChargePricingDiscount(cpqSub);
            } 
            else if (zChargeModel == ZuoraIntegration_OrderHelper.ZCHARGEMODEL_PERUNIT) {
                this.recurringPerUnit = new ZChargePricingRecurringPerUnit(cpqSub);
            } 
            else {
                this.recurringFlatFee = new ZChargePricingRecurringFlatFee(cpqSub);
            }
        }
    }

    // BR-5203
    // instance of charge billing, used to set billing timing for national accounts
    class ZChargeBilling {
        String billingTiming;

        public ZChargeBilling(SBQQ__Subscription__c cpqSub) {
            if (cpqSub.SBQQ__BillingType__c == null) {
                this.billingTiming = 'IN_ADVANCE';
            } else if (cpqSub.SBQQ__BillingType__c == 'Arrears') {
                this.billingTiming = 'IN_ARREARS';
            } else if (cpqSub.SBQQ__BillingType__c == 'Advance') {
                this.billingTiming = 'IN_ADVANCE';
            }
        }
    }

    // instange of charge pricing discount, used to set intro discount percent
    class ZChargePricingDiscount {
        Double discountPercentage;

        public ZChargePricingDiscount(SBQQ__Subscription__c cpqSub) {
            this.discountPercentage = cpqSub.Intro_Discount_Percentage__c;
        }
    }

    // instange of charge pricing recurring flat fee, used to set monthly totals on product with no quantity
    class ZChargePricingRecurringFlatFee {
        Double listPrice;

        public ZChargePricingRecurringFlatFee(SBQQ__Subscription__c cpqSub) {
            this.listPrice = cpqSub.SBQQ__NetPrice__c;
        }
    }

    // instange of charge pricing recurring per unit, used to set unit price and quantity on product with quantity
    class ZChargePricingRecurringPerUnit {
        Double listPrice;
        Integer quantity;

        public ZChargePricingRecurringPerUnit(SBQQ__Subscription__c cpqSub) {
            this.listPrice = cpqSub.SBQQ__NetPrice__c;
            this.quantity = Integer.valueOf(cpqSub.SBQQ__Quantity__c);
        }
    }

    // instance of terms, used to set autorenewal parameters
    class ZTerms {
        Boolean autoRenew = true;
        String renewalSetting = 'RENEW_WITH_SPECIFIC_TERM'; // RENEW_WITH_SPECIFIC_TERM, RENEW_TO_EVERGREEN
        ZInitialTerm initialTerm;
        List<ZRenewalTerm> renewalTerms = new List<ZRenewalTerm>{new ZRenewalTerm()};

        public ZTerms(Date startDate, Date endDate) {
            this.initialTerm = new ZInitialTerm(startDate, endDate);
        }
    }

    // instance of initial term, used to set initial term based on start / end date
    class ZInitialTerm {
        String periodType;  // Month, Year, Day, Week
        Integer period;
        Date startDate;
        String termType = 'TERMED'; // TERMED, EVERGREEN

        public ZInitialTerm(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.periodType = 'Day';
            this.period = startDate.daysBetween(endDate);
        }
    }

    // instance of renewal term, currently always one month
    class ZRenewalTerm {
        String periodType = 'Month';    // Month, Year, Day, Week
        Integer period = 1;
    }

    // instance of update product - not currently used
    class ZUpdateProduct {
        String ratePlanId;
        ZChargeUpdates chargeUpdates;
    }

    // instance of charge update - not currently used
    class ZChargeUpdates {
        String chargeNumber;
        String description;
        ZChargePricing pricing;
    }

    // entry point for class, method to serialize json string for supplied base bundles / related pending cpq subs
    public static String serializeJSON(
        List<SBQQ__Subscription__c> baseCPQSubList, 
        Map<Id,List<SBQQ__Subscription__c>> pendingCPQSubMap, 
        Map<Id,Integer> amendmentCPQSubMap
    ) {
        String jsonString = JSON.serializePretty(new ZuoraIntegration_Order(baseCPQSubList, pendingCPQSubMap, amendmentCPQSubMap), true);

        System.debug('order json: '+jsonString);

        return jsonString;
    }

    // override method to serialize json for single supplied base bundle / list of pending cpq subs
    public static String serializeJSON(SBQQ__Subscription__c baseCPQSub, List<SBQQ__Subscription__c> cpqSubList) {
        return serializeJSON(
            new List<SBQQ__Subscription__c>{baseCPQSub}, 
            new Map<Id,List<SBQQ__Subscription__c>>{baseCPQSub.Id=>cpqSubList},
            null
        );
    }
    
}

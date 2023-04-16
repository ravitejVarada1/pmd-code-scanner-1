// https://cargurus.atlassian.net/browse/BR-894
// test data factory to generate data specific to zuora integration tests
@isTest
public  class ZuoraIntegration_TestDataFactory {


    static final Id PRICEBOOKID = Test.getStandardPricebookId();
    static Id baseBundleProductId;  // set by calling setBaseBundleProductId() from test class
    
    // populate billing contact data to test zuora account creation
    public static List<Account> createAccountsWithBillingContactData(Integer qty, String recordTypeName) {
        List<Account> returnList = TestDataFactory.createAccounts(qty, recordTypeName);

        for (Account a : returnList) {
            a.Product_Activation_Status__c = ConstantsUtil.ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE;
            a.System_BillingContactEmail__c = 'ztezt@cargurus.com';
            a.System_BillingContactFirst__c = 'zteztfirst';
            a.System_BillingContactLast__c = 'zteztlast';
        }

        return returnList;
    }

    // create products with zuora ids and model for use in order integration
    public static List<Product2> createProductsWithZuoraData(Integer qty) {
        List<Product2> returnList = TestDataFactory.createProducts(qty);
        Integer i = 0;

        for (Product2 p : returnList) {
            p.Zuora_Charge_Model__c = 'Per Unit';
            p.Zuora_Product_Rate_Plan_ID__c = 'rpid'+i;
            p.Zuora_Product_Rate_Plan_Charge_ID__c = 'rpcid'+i;
            p.Zuora_Product_Rate_Plan_Charge_Disc_ID__c = 'rpdcid'+i;
            i++;
        }
        returnList[1].Zuora_Charge_Model__c = 'Flat Fee';

        return returnList;
    }

    // create products with zuora ids and model for use in order integration
    public static List<Product2> createProductsWithZuoraData(Integer qty, List<String> productCodes) {
        List<Product2> returnList = TestDataFactory.createProducts(qty);
        Integer i = 0;

        for (Product2 p : returnList) {
            p.Zuora_Charge_Model__c = 'Per Unit';
            p.Zuora_Product_Rate_Plan_ID__c = 'rpid'+i;
            p.Zuora_Product_Rate_Plan_Charge_ID__c = 'rpcid'+i;
            p.Zuora_Product_Rate_Plan_Charge_Disc_ID__c = 'rpdcid'+i;
            if (productCodes.size() > i){
                p.ProductCode = productCodes.get(i);
            }
            i++;
        }
        returnList[1].Zuora_Charge_Model__c = 'Flat Fee';

        return returnList;
    }

    // called from test class to set base bundle product id for use in generating related data
    public static void setBaseBundleProductId(Id suppliedId) {
        baseBundleProductId = suppliedId;
    }

    // create pricebook entries for supplied products
    public static List<PricebookEntry> createPricebookEntries(List<Product2> pList) {
        List<PricebookEntry> returnList = new List<PricebookEntry>();

        for (Product2 p : pList) {
            returnList.add(
                new PricebookEntry(
                    Product2Id = p.Id, 
                    Pricebook2Id = PRICEBOOKID,
                    CurrencyIsoCode = 'USD', 
                    UnitPrice = 100, 
                    IsActive = true
            ));
        }

        return returnList;
    }

    // create an opportunity for each supplied account
    public static List<Opportunity> createOpps(List<Account> accountList) {
        List<Opportunity> returnList = new List<Opportunity>();

        for (Account a : accountList) {
            returnList.addAll(TestDataFactory.createOpps(a.Id, 1));
        }

        return returnList;
    }

    // create a quote for each supplied opportunity
    public static List<SBQQ__Quote__c> createQuotes(List<Opportunity> oppList) {
        List<SBQQ__Quote__c> returnList = new List<SBQQ__Quote__c>();

        for (Opportunity o : oppList) {
            returnList.addAll(TestDataFactory.createQuotes(o.AccountId, o.Id, 1));
        }

        return returnList;
    }

    // create a quote line for each quote / pricebook entry combination
    public static List<SBQQ__QuoteLine__c> createQuoteLines(List<SBQQ__Quote__c> qList, List<PricebookEntry> pbeList) {
        List<SBQQ__QuoteLine__c> returnList = new List<SBQQ__QuoteLine__c>();

        for (SBQQ__Quote__c q : qList) {
            returnList.addAll(createQuoteLines(q, pbeList));
        }

        return returnList;
    }

    // create a quote line for each pricebook entry on the supplied quote
    public static List<SBQQ__QuoteLine__c> createQuoteLines(SBQQ__Quote__c q, List<PricebookEntry> pbeList) {
        List<SBQQ__QuoteLine__c> returnList = new List<SBQQ__QuoteLine__c>();

        for (PricebookEntry pbe : pbeList) {
            returnList.add(
                new SBQQ__QuoteLine__c(
                    SBQQ__Quote__c = q.Id,
                    Billing_Account__c = q.SBQQ__Account__c,
                    Fulfillment_Account__c = q.SBQQ__Account__c,
                    SBQQ__PricebookEntryId__c = pbe.Id
                )
            );
        }

        return returnList;
    }

    // create an order for each supplied quote
    public static List<Order> createOrders(List<SBQQ__Quote__c> quoteList) {
        List<Order> returnList = new List<Order>();

        for (SBQQ__Quote__c q : quoteList) {
            returnList.add(
                new Order(
                    AccountId = q.SBQQ__Account__c,
                    SBQQ__Quote__c = q.Id,
                    EffectiveDate = Date.today(),
                    Status = 'Draft',
                    Pricebook2Id = PRICEBOOKID
                )
            );
        }

        return returnList;
    }

    // create a contract for each supplied order - insert contracts and upsert quotes to set up relationships
    public static List<Contract> createContracts(List<Order> orderList) {
        Map<Id,Contract> contractsByAccountId = new Map<Id,Contract>();

        for (Order o : orderList) {
            Id accountId = o.AccountId;
            Contract c = TestDataFactory.createContract(accountId);
            contractsByAccountId.put(accountId, c);
        }
        insert contractsByAccountId.values();

        for (Order o : orderList) {
            Id accountId = o.AccountId;
            Contract c = contractsByAccountId.get(accountId);
            o.ContractId = c.Id;
            c.Status = 'Activated';
        }
        upsert orderList;
        update contractsByAccountId.values();

        return contractsByAccountId.values();
    }

    // create order item for each supplied order with supplied quote lines on matching related quote
    public static List<OrderItem> createOrderItems(List<Order> oList, List<SBQQ__QuoteLine__c> testQuoteLines) {
        List<OrderItem> returnList = new List<OrderItem>();

        for (Order o : oList) {
            returnList.addAll(createOrderItems(o, testQuoteLines));
        }

        return returnList;
    }

    // for supplied order, create order item for each quote line on matching related quote
    public static List<OrderItem> createOrderItems(Order o, List<SBQQ__QuoteLine__c> testQuoteLines) {
        List<OrderItem> returnList = new List<OrderItem>();

        for (SBQQ__QuoteLine__c ql : testQuoteLines) {
            if (o.SBQQ__Quote__c != ql.SBQQ__Quote__c) {
                continue;
            }

            returnList.add(
                new OrderItem(
                    OrderId = o.Id,
                    SBQQ__QuoteLine__c = ql.Id,
                    Billing_Account__c = ql.Billing_Account__c,
                    Fulfillment_Account__c = ql.Fulfillment_Account__c,
                    PricebookEntryId = ql.SBQQ__PricebookEntryId__c,
                    UnitPrice = 100,
                    Quantity = 1
                )
            );
        }

        return returnList;
    }

    // create cpq sub for each supplied order item - insert / update to establish bundle / feature product relationships
    public static List<SBQQ__Subscription__c> createCPQSubs(List<OrderItem> orderItems) {
        List<SBQQ__Subscription__c> returnList = new List<SBQQ__Subscription__c>();

        for (OrderItem ol : OrderItems) {
            returnList.add(
                new SBQQ__Subscription__c(
                    SBQQ__Quantity__c = 1,
                    SBQQ__OrderProduct__c = ol.Id,
                    SBQQ__QuoteLine__c = ol.SBQQ__QuoteLine__c,
                    SBQQ__Contract__c = ol.Order.ContractId,
                    SBQQ__Product__c = ol.Product2Id,
                    Fulfillment_Account__c = ol.Fulfillment_Account__c,
                    Billing_Account__c = ol.Billing_Account__c,
                    SBQQ__SubscriptionStartDate__c = Date.today(),
                    SBQQ__SubscriptionEndDate__c = Date.today().addDays(30),
                    Intro_Discount_Percentage__c = 50,
                    Intro_Discount_Period__c = 3,
                    SBQQ__NetPrice__c = 100
                )
            );
        }

        insert returnList;
        
        Map<Id,Id> orderBBSubMap = new Map<Id,Id>();

        for (SBQQ__Subscription__c bbSub : [SELECT Id, SBQQ__OrderProduct__r.OrderId FROM SBQQ__Subscription__c 
                WHERE SBQQ__Product__c = :baseBundleProductId AND Id IN :returnList]) 
        {
            orderBBSubMap.put(bbSub.SBQQ__OrderProduct__r.OrderId, bbSub.Id);
        }

        List<SBQQ__Subscription__c> updateCpqSubs = [SELECT Id, SBQQ__OrderProduct__r.OrderId, SBQQ__OrderProduct__c FROM SBQQ__Subscription__c 
            WHERE SBQQ__Product__c != :baseBundleProductId AND Id IN :returnList];

        for (SBQQ__Subscription__c cpqSub : updateCpqSubs) {
            cpqSub.SBQQ__RequiredById__c = orderBBSubMap.get(cpqSub.SBQQ__OrderProduct__r.OrderId);
        }

        for (OrderItem oi : orderItems) {
          for (SBQQ__Subscription__c cpqSub : updateCpqSubs) {
            if(cpqSub.SBQQ__OrderProduct__c == oi.Id) {
              oi.SBQQ__Subscription__c = cpqSub.Id;
              break;
            }
          }
        }

        update updateCpqSubs;
        update orderItems;
        System.debug(returnList);

        return returnList;
    }

    // create zuora subscriptions for each supplied order
    public static List<Zuora__Subscription__c> createZuoraSubs(List<Order> orderList) {
        List<Zuora__Subscription__c> returnList = new List<Zuora__Subscription__c>();

        for (Order o : orderList) {
            returnList.add(
                new Zuora__Subscription__c(
                    Name = o.OrderNumber,
                    Zuora__Account__c = o.AccountId,
                    Zuora__External_Id__c = o.OrderNumber+'extId'
                )
            );
        }

        return returnList;
    }

    // create zuora subscription rate plan for each supplied z sub and product
    public static List<Zuora__SubscriptionRatePlan__c> createZuoraSubRatePlans(List<Zuora__Subscription__c> zSubs, 
        List<Product2> pList) 
    {
        List<Zuora__SubscriptionRatePlan__c> returnList = new List<Zuora__SubscriptionRatePlan__c>();

        for (Zuora__Subscription__c zSub : zSubs) {
            for (Product2 p : pList) {
                returnList.add(
                    new Zuora__SubscriptionRatePlan__c(
                        Zuora__Account__c = zSub.Zuora__Account__c,
                        Zuora__OriginalProductRatePlanId__c = p.Zuora_Product_Rate_Plan_ID__c,
                        Zuora__ProductRatePlanId__c = p.Zuora_Product_Rate_Plan_ID__c,
                        Name = p.Zuora_Product_Rate_Plan_ID__c+zSub.Zuora__Account__c,
                        Zuora__External_Id__c = String.valueOf(p.Id)+zSub.Zuora__Account__c,
                        Zuora__Subscription__c = zSub.Id
                    )
                );
            }
        }

        return returnList;
    }

    // create zuora subscription charge for each supplied z sub rate plan
    public static List<Zuora__SubscriptionProductCharge__c> createZuoraSubCharges(List<Zuora__SubscriptionRatePlan__c> zSubRatePlans) {
        List<Zuora__SubscriptionProductCharge__c> returnList = new List<Zuora__SubscriptionProductCharge__c>();

        Map<String,String> pRatePlanChargeIdMap = new Map<String,String>();

        for (Product2 p : ZuoraIntegration_OrderHelper.PRODUCTMAP.values()) {
            pRatePlanChargeIdMap.put(p.Zuora_Product_Rate_Plan_ID__c, p.Zuora_Product_Rate_Plan_Charge_ID__c);
        } 

        for (Zuora__SubscriptionRatePlan__c zSubRatePlan : zSubRatePlans) {
            returnList.add(
                new Zuora__SubscriptionProductCharge__c(
                    Zuora__Account__c = zSubRatePlan.Zuora__Account__c,
                    Zuora__SubscriptionRatePlan__c = zSubRatePlan.Id, 
                    Name = zSubRatePlan.Name,
                    Zuora__External_Id__c = String.valueOf(zSubRatePlan.Id)+zSubRatePlan.Zuora__Account__c,
                    Zuora__ProductRatePlanChargeId__c = pRatePlanChargeIdMap.get(zSubRatePlan.Zuora__External_Id__c),
                    Zuora__Segment__c = 1,
                    Zuora__MonthlyRecurringRevenue__c = 100
                )
            );
        }

        return returnList;
    }

}
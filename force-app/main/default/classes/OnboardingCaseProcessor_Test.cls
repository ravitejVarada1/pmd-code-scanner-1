@isTest
public class OnboardingCaseProcessor_Test {

    @TestSetup
    static void makeData(){
        TestDataFactory_CreateAccount tdf = new TestDataFactory_CreateAccount();
        tdf.createNewAccountWithOppAndQuote('US');
    }

    static testMethod void test1() {
        List<Order> orders = [SELECT Id, Status FROM Order];
        orders[0].Status = 'Activated';
        update orders;

        List<Case> cases = [SELECT Id FROM Case];
        System.assert(cases.size() == 0);
    }

    
    static testMethod void test2() {

        OnboardingCaseProcessor ocp = new OnboardingCaseProcessor();
        Map<String,Date> dateByProductCode = ocp.getProductLookbackDates();     

        List<OrderItem> orderItems = [SELECT Id, Transaction_Type__c, SBQQ__Status__c, ServiceDate, Fulfillment_Account__c, Product2.ProductCode, Fulfillment_Account__r.BillingCountryCode FROM OrderItem];
        
        Date activationDate;

        for(OrderItem oi : orderItems) {
            String productCountryKey = oi.Product2.ProductCode + oi.Fulfillment_Account__r.BillingCountryCode;
            if(dateByProductCode.keySet().contains(productCountryKey)) {
                activationDate = dateByProductCode.get(productCountryKey);
                break;
            }
        }

        for(OrderItem oi : orderItems) {
            oi.serviceDate = activationDate;
            oi.Transaction_Type__c = 'New Business';
        }

        List<Order> orders = [SELECT Id, ActivatedDate, EffectiveDate, Status FROM Order];
        for(Order o : orders) {
            o.EffectiveDate = activationDate;
        }

        update orders;
        update orderItems;

        List<Order> updatedOrders = [SELECT Id, Status FROM Order];
        updatedOrders[0].Status = 'Activated';
        update updatedOrders;


        Test.startTest();
        List<OrderItem> updatedOrderItems = [SELECT Id, Transaction_Type__c, SBQQ__Status__c, ServiceDate, Fulfillment_Account__c, 
            Fulfillment_Account__r.OwnerId, Product2.ProductCode, Fulfillment_Account__r.BillingCountryCode, Fulfillment_Account__r.Name, 
            OrderId, Order.SBQQ__Quote__c, SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__c, SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__PrimaryContact__c
            FROM OrderItem];

        for(OrderItem oi : updatedOrderItems) {
            if(oi.SBQQ__Status__c == 'Pending Activation') {
                oi.SBQQ__Status__c = 'Activated';
            }
        }
        update updatedOrderItems;

        Map<Id,Case> casesReturned = ocp.getOnboardingCases(updatedOrderItems);

        System.assert(casesReturned.size() > 0);
        Test.stopTest();
    }
}

@isTest
public class TestDataFactory_CreateAccount {

    private List<Case> cases = new List<Case>();
    private static Map<String, String> currencyCodeByCountryCode = new Map<String,String>{
        'US' => 'USD',
        'GB' => 'GBP',
        'CA' => 'CAD'
    };

    public Map<Id, PricebookEntry> pricebookentryByProdId = new Map<Id, PricebookEntry>();
    public List<Product2> products = new List<Product2>();
    public List<PricebookEntry> priceBookEntries = new List<PricebookEntry>();
    public Pricebook2 priceBook;
    public Account accnt;
    public List<Opportunity> opportunities;
    public List<SBQQ__Quote__c> quotes;
    public List<SBQQ__Quoteline__c> quoteLines;
    public List<Order> orders;
    public List<OrderItem> orderItems;
    
    public void createNewAccountWithOppAndQuote(String country) {
        createProducts('US');
        createNonPayingAccount('US');
        createOpp(accnt);
        createQuote(accnt, opportunities[0], priceBook);
        createQuotelines(accnt, quotes[0], products, 1);
        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        createOrder(accnt, quotes[0], opportunities[0], System.today());
        TriggerHandler.bypass('OrderProductTriggerHandler');
        createOrderProduct(orders[0], products, 1000, 1, System.today(), System.today().addDays(30), accnt);
        TriggerHandler.clearAllBypasses();
    }

    private void createNonPayingAccount(String country) {
        List<Account> acc = TestDataFactory.createAccounts(1);
        acc[0].BillingCountryCode = country;
        acc[0].Type = 'Prospect';
        insert acc;
        this.accnt = acc[0];
    }

    private void createProducts(String country) {
        List<Product2> productList = new List<Product2>();
        Map<String, Product2> productByProductCode = new Map<String, Product2>();

        Product2 bundle = new Product2();
        bundle.IsActive = true;
        bundle.CurrencyIsoCode = currencyCodeByCountryCode.get(country);
        bundle.Name = 'CG Base Bundle';
        bundle.ProductCode = 'CG-BASE';
        productList.add(bundle);

        Product2 listingsProd = new Product2();
        listingsProd.IsActive = true;
        listingsProd.CurrencyIsoCode = currencyCodeByCountryCode.get(country);
        listingsProd.Name = 'Enhanced Package';
        listingsProd.ProductCode = 'PKG-ENH';
        productList.add(listingsProd);

        Product2 digDealProd = new Product2();
        digDealProd.IsActive = true;
        digDealProd.CurrencyIsoCode = currencyCodeByCountryCode.get(country);
        digDealProd.Name = 'Digital Deal - 200 Miles';
        digDealProd.ProductCode = 'CG-DIG-DEAL-200';
        digDealProd.Activation_Case_Queue__c ='Area Boost Activation Case Queue';
        digDealProd.Deactivation_Case_Queue__c ='Area Boost Activation Case Queue';
        digDealProd.Manually_Provisioned__c = true;
        digDealProd.Product_Provisioning_Behavior__c = 'Manual Rec / Manual Prov';
        productList.add(digDealProd);

        insert productList;
        this.products = productList;

        createPriceBookEntriesForProducts(productList);
    }

    void createPriceBookEntriesForProducts(List<Product2> productList) {

        List<PricebookEntry> pbes = new List<PricebookEntry>();
        Map<Id, PricebookEntry> pricebookentryByProdId = new Map<Id, PricebookEntry>();
        //Instantiate the Pricebook2 record with StandardPricebookId
        Pricebook2 standardPricebook = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        //Execute an update DML on the Pricebook2 record, to make IsStandard to true
        update standardPricebook;
        this.priceBook = standardPricebook;

        for(Product2 prod : productList) {
            pbes.add(TestDataFactory.createPriceBookEntry(standardPricebook.Id, prod.Id));
        }
        insert pbes;
        this.priceBookEntries = pbes;

        for(PricebookEntry pbe : pbes) {
            pricebookentryByProdId.put(pbe.Product2Id, pbe);
        }
        this.pricebookentryByProdId = pricebookentryByProdId;
    }

    private void createOpp(Account a) {
    
        Opportunity[] opps = TestDataFactory.createOpps(a.Id,1);
        opps[0].RecordTypeId = Utilities.getRecordTypeId('Opportunity','Standard_Opportunity');
        insert opps;
        this.opportunities = opps;
    }

    private void createQuote(Account a, Opportunity o, Pricebook2 pb) {

        List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();

        SBQQ__Quote__c q = new SBQQ__Quote__c();
        q.SBQQ__Account__c = a.id;
        q.SBQQ__Opportunity2__c = o.id;
        q.SBQQ__PricebookId__c = pb.id;
        q.SBQQ__Type__c = 'Quote';
        q.SBQQ__StartDate__c = System.today();
        q.SBQQ__Primary__c = true;

        quotes.add(q);
        insert quotes;
        this.quotes = quotes;
    }

    private void createQuotelines(Account a, SBQQ__Quote__c quote, List<Product2> prod, Decimal qty) {
        
        List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();

        for(Product2 p : prod) {
            SBQQ__Quoteline__c ql = new SBQQ__Quoteline__c();
            ql.Fulfillment_Account__c = a.id;
            ql.SBQQ__Product__c = p.id;
            ql.SBQQ__Quote__c = quote.id;
            ql.SBQQ__Quantity__c = qty;
            ql.SBQQ__PricebookEntryId__c = pricebookentryByProdId.get(p.id).id;
            
            quoteLines.add(ql);
        }

        TriggerHandler.bypass('CPQQuoteLineTriggerHandler');
        insert quoteLines;
        TriggerHandler.clearAllBypasses();
        this.quoteLines = quoteLines;
    }

    private void createOrder(Account acc, SBQQ__Quote__c quote, Opportunity opp, Date orderStartDate) {

        List<Order> orders = new List<Order>();

        Order ord = new Order();
        ord.AccountId = acc.id;
        ord.SBQQ__Quote__c = quote.id;
        ord.OpportunityId = opp.id;
        ord.EffectiveDate = orderStartDate;
        ord.Status = 'Draft';

        orders.add(ord);
        insert orders;
        this.orders = orders;
    }

    private void createOrderProduct(Order ord, List<Product2> prod, Decimal unitPrice, Integer qty, Date startDate, Date endDate, Account a) {

        List<OrderItem> orderItems = new List<OrderItem>();

        for(Product2 p : prod) {
            OrderItem oi = new OrderItem();
            oi.OrderId = ord.id;
            oi.Product2Id = p.id;
            oi.UnitPrice = unitPrice;
            oi.Quantity = qty;
            oi.ServiceDate = startDate;
            oi.EndDate = endDate;
            oi.PricebookEntryId = pricebookentryByProdId.get(p.Id).id;
            oi.SBQQ__Status__c = 'Draft';
            oi.Fulfillment_Account__c = a.id;

            orderItems.add(oi);
        }

        insert orderItems;
        this.orderItems = orderItems;
    }
}

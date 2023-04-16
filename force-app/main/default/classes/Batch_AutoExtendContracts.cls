/*Batch process to Auto extend CPQ Contracts|| https://cargurus.atlassian.net/browse/BR-1269/BR-3716
* author:         amitul
* created:        06/07/2021
* modified:       05/10/2022
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class Batch_AutoExtendContracts implements Database.Batchable<sObject>,Schedulable {

    public final static String ACH ='ACH';
    public final static String CREDITCARD = 'CreditCard';
    public final static String CHECK = 'Check';
    public final static String BANKTRANSFER = 'BankTransfer'; 
    
    public static final Set<String> NON_AUTO_PAYMENT = new Set<String>{CHECK};
    public static final Set<String> AUTO_PAYMENT = new Set<String>{ACH, CREDITCARD, BANKTRANSFER, CHECK};
   
    public final static Date firstDayOfMonth = System.today().toStartOfMonth();
    public final static Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month())-1);

    public boolean executeAdHoc = false;
    public boolean adHocIncludeAutoPay = false;
    public boolean adHocIncludeNonAutoPay = false;

    private Set<Id> contractIds;

    public Batch_AutoExtendContracts() {}

    public Batch_AutoExtendContracts(Boolean adHoc, Boolean adHocIncludeAutoPay, Boolean adHocIncludeNonAutoPay) {
        this.executeAdHoc = adHoc;
        this.adHocIncludeAutoPay = adHocIncludeAutoPay;
        this.adHocIncludeNonAutoPay = adHocIncludeNonAutoPay;
    }

    public Batch_AutoExtendContracts(Set<Id> ids) {
        this.contractIds = ids;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        String query = 'SELECT Id, EndDate FROM Contract ' + 
            'WHERE (EndDate =:lastDayOfMonth) AND Auto_Renewal_Disable_Date__c = null AND Status != \'Cancelled\' ';
        if(contractIds != null && !contractIds.isEmpty()) {
            List<Id> queryIds = new List<Id>(contractIds);
            query += ' AND Id IN :queryIds';
        }
        System.debug('QUERY ===> '+query);
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Contract> contracts){
        Set<Id> contractIds = new Set<Id>();
        for (Contract con : contracts){
            contractIds.add(con.Id);
        }
        
        List<Contract> contractEndDateToBeUpdated = new List<Contract>();
        
        Map<Id,List<SBQQ__Subscription__c>> subsMap = new Map<Id,List<SBQQ__Subscription__c>>();
        
        List<SBQQ__Subscription__c> subsList = new List<SBQQ__Subscription__c>();
        subsList = [SELECT Auto_Renewal_Flag__c,Fulfillment_Account__c,SBQQ__Contract__c, 
                    Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c,
                    Billing_Account__r.Billing_Account_Zuora__r.Zuora__Default_Payment_Method__r.Zuora__Type__c 
                    FROM  SBQQ__Subscription__c 
                    WHERE Product_Code__c ='CG-BASE'
                    AND Auto_Renewal_Flag__c = true 
                    AND Fulfillment_Account__r.Renewal_Eligible__c = false 
                    AND SBQQ__Contract__c =:contractIds];
        
        for(SBQQ__Subscription__c sub : subsList){
            if(subsMap.containsKey(sub.SBQQ__Contract__c)) {
               subsMap.get(sub.SBQQ__Contract__c).add(sub);
            }else{
                subsMap.put(sub.SBQQ__Contract__c,new List<SBQQ__Subscription__c>{sub}); 
            }
        }
        
        for (Contract con : contracts){
        List<SBQQ__Subscription__c> subList = new List<SBQQ__Subscription__c>();   
        if(subsMap.containsKey(con.Id)){
          subList = subsMap.get(con.Id) ;    
        }
            
        for(SBQQ__Subscription__c subs : subList){
            Boolean isPaymentMethodNotNull = subs != null && subs.Fulfillment_Account__c != null 
            && subs.Billing_Account__r.Billing_Account_Zuora__c != null;
            
      		if(isPaymentMethodNotNull) {
            String paymentMethodName = '';
            // setting payment method name 
            if(subs.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c != null){
                paymentMethodName = subs.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c;
            }
            else{
                paymentMethodName = subs.Billing_Account__r.Billing_Account_Zuora__r.Zuora__Default_Payment_Method__r.Zuora__Type__c;
            }
            
            // set the contract end date to the  next month if Payment_Method__c is Auto Pay(ACH, Credit Card, Bank Transfer) and today is last date of the month 
            if (AUTO_PAYMENT.contains(paymentMethodName) && lastDayOfMonth == con.EndDate  && ((System.today() == lastDayOfMonth || Test.isRunningTest()) || (executeAdHoc && adHocIncludeAutoPay))) {    
				Date firstDayOftheExtendedMonth = con.EndDate.addMonths(1).toStartOfMonth();
				con.EndDate  = firstDayOftheExtendedMonth.addDays(Date.daysInMonth(firstDayOftheExtendedMonth.year(), firstDayOftheExtendedMonth.month())-1); 
                contractEndDateToBeUpdated.add(con);
                
            }
            // set the contract end date to the  next month if Payment_Method__c is Non Auto(Check) and today is first day of the month
            else if (NON_AUTO_PAYMENT.contains(paymentMethodName) && lastDayOfMonth == con.EndDate  && ((System.today() == firstDayOfMonth || Test.isRunningTest()) || (executeAdHoc && adHocIncludeNonAutoPay))) { 
				Date firstDayOftheExtendedMonth = con.EndDate.addMonths(1).toStartOfMonth();
                con.EndDate  = firstDayOftheExtendedMonth.addDays(Date.daysInMonth(firstDayOftheExtendedMonth.year(), firstDayOftheExtendedMonth.month())-1);
                contractEndDateToBeUpdated.add(con);
            }

            }
    	}
           
    }
        if(!contractEndDateToBeUpdated.isEmpty())
            update contractEndDateToBeUpdated;
        
    }       

    public void finish(Database.BatchableContext bc){
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new Batch_AutoExtendContracts(false,false,false));
    }
}
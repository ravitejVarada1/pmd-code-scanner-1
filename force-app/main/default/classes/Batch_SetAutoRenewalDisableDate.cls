/*Set Auto Renewal Disable Date o Contracts|| https://cargurus.atlassian.net/browse/BR-1271
* author:         amitul
* created:        06/01/2021
* modified:       07/26/2021
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
global class Batch_SetAutoRenewalDisableDate implements Database.Batchable<sObject>,Schedulable {

    public final static String ACH ='ACH';
    public final static String CREDITCARD = 'CreditCard';
    public final static String CHECK = 'Check';
    public final static String BANKTRANSFER = 'BankTransfer'; 

    public static final Set<String> NON_AUTO_PAYMENT = new Set<String>{CHECK};
    public static final Set<String> AUTO_PAYMENT = new Set<String>{ACH, CREDITCARD, BANKTRANSFER};
    List<Id> contractIds = new List<Id>();
    boolean isRenewalFlag = true;

    global Batch_SetAutoRenewalDisableDate() {}

    global Batch_SetAutoRenewalDisableDate(List<Id> ids,boolean isRenewal) {
        isRenewalFlag = isRenewal;
        contractIds.addAll(ids);
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {

        Date firstDayOfMonth = System.today().addMonths(1).toStartOfMonth();
        Date lastDayOfMonth = firstDayOfMonth.addDays(Date.daysInMonth(firstDayOfMonth.year(), firstDayOfMonth.month())-1);
        Boolean specificContracts = contractIds != null && !contractIds.isEmpty();
        String queryConditions1 = specificContracts == true ? '' : ' AND Fulfillment_Account__r.Renewal_Eligible__c = true ';
        String contractIdsCondition = '\'' + String.join(contractIds, '\', \'') + '\'';
        String queryConditions2 = specificContracts == true ? ' AND Id IN (' + contractIdsCondition + ')' : ' AND EndDate =:lastDayOfMonth';

        string query = 'SELECT Id, Auto_Renewal_Disable_Date__c, ' +
              '(' +
                'SELECT Fulfillment_Account__c,Fulfillment_Account__r.OwnerId, Fulfillment_Account__r.Renewal_Eligible__c,Auto_Renewal_Flag__c, ' +
                'Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c, ' +
                'Billing_Account__r.Billing_Account_Zuora__r.Zuora__Default_Payment_Method__r.Zuora__Type__c ' +
                'FROM SBQQ__Subscriptions__r ' +
                'WHERE Product_Code__c  = \'CG-BASE\' ' +
                  'AND Auto_Renewal_Flag__c = true ' +
                  queryConditions1 +
              ') ' +
              'FROM Contract '+ 
              'WHERE Auto_Renewal_Disable_Date__c = null' + queryConditions2;

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<Contract> contracts) {
        List<Contract> contractEndDateToBeUpdated = new List<Contract>();
      
        for (Contract con : contracts) {
                
            for(SBQQ__Subscription__c subs : con.SBQQ__Subscriptions__r) {

                Boolean isPaymentMethodNull = subs == null 
                                              || subs.Fulfillment_Account__c == null 
                                              || subs.Billing_Account__r.Billing_Account_Zuora__c == null;

                if(isPaymentMethodNull) {
                    continue;
                }

                String paymentMethodName = '';
                // setting payment method name 
                if(subs.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c != null){
                paymentMethodName = subs.Billing_Account__r.Billing_Account_Zuora__r.Zuora__DefaultPaymentMethod__c;
           		}
            	else{
                paymentMethodName = subs.Billing_Account__r.Billing_Account_Zuora__r.Zuora__Default_Payment_Method__r.Zuora__Type__c;
            	}
                    
                // set the Auto_Renewal_Disable_Date to first day of next month if Payment_Method__c is Auto(ACH, Credit Card)
                if (AUTO_PAYMENT.contains(paymentMethodName) ){ 
                    con.Auto_Renewal_Disable_Date__c = System.today().AddMonths(1).toStartOfMonth().addDays(1);
                    if(isRenewalFlag){
                    con.SBQQ__RenewalForecast__c = True;
                    con.SBQQ__RenewalQuoted__c = True;
                    con.SBQQ__RenewalOwner__c = subs.Fulfillment_Account__r.OwnerId;
                    }
                    contractEndDateToBeUpdated.add(con);
                } 
                // set the Auto_Renewal_Disable_Date to today if Payment_Method__c is non auto (Bank transfers, Check)
                else if (NON_AUTO_PAYMENT.contains(paymentMethodName) ) { 
                    con.Auto_Renewal_Disable_Date__c = System.today();
                     if(isRenewalFlag){
                    con.SBQQ__RenewalForecast__c = True;
                    con.SBQQ__RenewalQuoted__c = True;
                    con.SBQQ__RenewalOwner__c = subs.Fulfillment_Account__r.OwnerId;
                     }
                    contractEndDateToBeUpdated.add(con);
                }

                if(con.Auto_Renewal_Disable_Date__c != null) break;
            }
        }

        if(!contractEndDateToBeUpdated.isEmpty()) {
            update contractEndDateToBeUpdated;
        }

    }

    global void finish(Database.BatchableContext bc) {}

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new Batch_SetAutoRenewalDisableDate(), 1);
    }
}
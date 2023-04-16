/**
 * When the number of stores exceeds a threshold pass on the Quote Ordering to this
 * Queueable
 * 
 */
public class QueueableQuoteOrders implements Queueable {
    private List<Id> quoteIds;
    
    public QueueableQuoteOrders(List<Id> quoteIds){
        this.quoteIds = quoteIds;
    }

    public void execute(QueueableContext context){
        Savepoint sp = Database.setSavepoint();
        Date tdy = Date.today();
        Map<ID,Opportunity> oppsToClose = new Map<ID,Opportunity>();

        //Query for just one order that is not contracted yet, if this is an amendment, or query for all orders 
        //if this is not an amendment
        List<SBQQ__Quote__c> quotesToOrder = [SELECT Id, SBQQ__Ordered__c, SBQQ__Opportunity2__c
            FROM SBQQ__Quote__c
            WHERE SBQQ__Ordered__c = false
            AND Id IN :quoteIds
            LIMIT 1];
        
        if (quotesToOrder.isEmpty()){
            return;
        }
        
        for (SBQQ__Quote__c qt : quotesToOrder){
            qt.SBQQ__Ordered__c = true;
            oppsToClose.put(qt.SBQQ__Opportunity2__c, null);
        }
        try{
            //collect the opp info before ordering, so we have a reference ot the Opp tracker
            Id RECORDTYPEIDSTANDARD = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Standard_Opportunity');
            Id RECORDTYPEIDRETENTION = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Retention');
            Id RECORDTYPEIDRENEWAL = SObjectDescribeUtils.getRecordTypeIdByDevName('Opportunity','Renewal');
            
            oppsToClose = new Map<ID,Opportunity>([SELECT Id, CloseDate, recordTypeID,
                Opportunity_Tracker__c
                FROM Opportunity
                WHERE Id IN :oppsToClose.keySet()]);
            
            for (Opportunity opp : oppstoClose.values()) {
                
                opp.CloseDate = tdy; //DSS-705 Stamp Today Date when closing won                
                
                if(opp.recordTypeID == RECORDTYPEIDSTANDARD || opp.recordTypeID == RECORDTYPEIDRENEWAL) {
                    opp.StageName = ConstantsUtil.OPP_STATUS_CLOSED_WON;
                }
                
                if(opp.recordTypeID == RECORDTYPEIDRETENTION ){
                    opp.StageName = ConstantsUtil.OPP_STATUS_CLOSED_SAVED;
                }
            }

            //order the quote
            update quotesToOrder;

            //close the opportunity
            update oppsToClose.values();
            
            //activate the orders
            List<Order> orders = [SELECT Id, Status FROM Order WHERE SBQQ__Quote__c = :quotesToOrder[0].Id];
            for (Order ord : orders) {
                ord.Status = 'Activated';
            }
            update orders;

        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(e.getStackTraceString());
            System.debug(e.getCause());
            System.debug(e.getLineNumber());
            System.debug(e.getLineNumber());
            Opportunity_Tracker__c ot = new Opportunity_Tracker__c(
                Id = oppsToClose.values().get(0).Opportunity_Tracker__c,
                QuoteOrderingErrors__c = e.getMessage() + '<orderBrokenSpacer>' +  e.getStackTraceString()
            );
            update ot;
        }
    }
}

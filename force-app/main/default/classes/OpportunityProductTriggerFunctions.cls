/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         amitul
* modifiedBy:     amitul
* created:        01/19/2022
* modified:       01/19/2022
* created jira:   BR-4528
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/

public without sharing class OpportunityProductTriggerFunctions {
    public static void replaceProductsOnRenewal(List<OpportunityLineItem> oppLineItem) {
      
        Map<String,Id> getProductId = new Map<String,Id>();
        for(Product2 p : [SELECT Id,ProductCode,name FROM Product2]){
            getProductId.put(p.ProductCode,p.Id);
        }
        
        Map<String,Id> getPriceBookId = new Map<String,Id>();
        for(PricebookEntry  pbe :[SELECT Id,Product2.ProductCode,Pricebook2Id,CurrencyIsoCode  FROM PricebookEntry 
            WHERE Pricebook2.Name = 'Standard Price Book' AND Product2Id IN: getProductId.values()]){
            getPriceBookId.put(pbe.Product2.ProductCode+pbe.CurrencyIsoCode,pbe.Id);
        }
        
        Map<String,String> mapRenewalProducts = new Map<String,String>();
        for(Renewal_Product_Map__mdt mdt : [SELECT Id, Account_Billing_Country__c, Existing_Product__c, Renewal_Product__c 
            FROM Renewal_Product_Map__mdt]){
            mapRenewalProducts.put(mdt.Existing_Product__c+mdt.Account_Billing_Country__c,mdt.Renewal_Product__c);
        }
        
        List<OpportunityLineItem> cloneOppLineItem = new List<OpportunityLineItem>();
        Set<Id> oppLineItemToBeDeleted = new Set<Id>();
        for(OpportunityLineItem oli : oppLineItem) {
            if(mapRenewalProducts.containsKey(oli.ProductCode+oli.Billing_Country__c) && oli.Quantity > 0 
                && oli.OpportunityId != null && oli.IsRenewal__c == true){
                OpportunityLineItem oppOli = oli.clone();
                oppOli.Product2Id = getProductId.get(mapRenewalProducts.get(oli.ProductCode+oli.Billing_Country__c));
                oppOli.TotalPrice = null;
                oppOli.PricebookEntryId = getPriceBookId.get(mapRenewalProducts.get(oli.ProductCode+oli.Billing_Country__c)+oli.CurrencyIsoCode);
                cloneOppLineItem.add(oppOli);
                oppLineItemToBeDeleted.add(oli.Id);      
            }
        } 

        if(!cloneOppLineItem.isEmpty()){
            if(!Test.isRunningTest()){
                insert cloneOppLineItem;
            }
        }

        if (!System.isBatch() && !System.isFuture()){
            if(!oppLineItemToBeDeleted.isEmpty()){
                deleteOli(oppLineItemToBeDeleted);
            }
        }
    }
    
    @future
    public static void deleteOli(Set<Id> OliId) {
    delete [SELECT Id FROM OpportunityLineItem WHERE Id IN: OliId];
    }

    /**
    * BR-9060 Recreate Negative Line Items on the Retention Opportunity (deleted by CPQ managed pkg)
    * @author   Ramiro Alvarez
    * @date     05/09/2022
    * @param    Map<Id,Id> - opptyContractIdMap
    * @return   void
    */
    
    public static void recreateNegativeLines(List<OpportunityLineItem> oppLineItems) {

        Id RECORDTYPEIDRETENTION = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Retention').getRecordTypeId();
        Id RECORDTYPEIDRENEWAL = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Renewal').getRecordTypeId();
        Set<Id> recordTypeIds = new Set<Id> {RECORDTYPEIDRETENTION,RECORDTYPEIDRENEWAL};
        Set<Id> opptyIds = new Set<Id> ();
        for (OpportunityLineItem oli : oppLineItems) {
            opptyIds.add(oli.OpportunityId);
        }

        Map<Id,Opportunity> opptyMap = new Map<Id, Opportunity>([
            SELECT Id, Name
            FROM Opportunity
            WHERE Id IN :opptyIds
            AND RecordTypeId IN :recordTypeIds
        ]);

        if (opptyMap.isEmpty()) {
            return;
        }
        
        List<OpportunityLineItem> recreateOliList = new List<OpportunityLineItem> ();
        for (OpportunityLineItem oli : oppLineItems) {
            if (oli.Quantity < 0 &&
                oli.SBQQ__QuoteLine__c == null &&
                opptyMap.containsKey(oli.OpportunityId)
                )
            {
                OpportunityLineItem newOli = oli.clone(false,false,false,false);
                newOli.TotalPrice = null;
                recreateOliList.add(newOli);
            }
        }
        
        if (!recreateOliList.isEmpty()) {
            insert recreateOliList;
        }
    }
}
/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 09/07/2022
 * @last modified by  : Adam LaPlante
**/
public class OrderProductTriggerFunctions {
    
    public static String DRAFT_STATUS = 'Draft';
    public static String ACTIVATED_STATUS = 'Activated';
    public static String PENDING_ACTIVATION_STATUS = 'Pending Activation';
    public static String PENDING_STATUS = 'Pending';
    public static  Set<String> PH_PRODUCT_CODES = ConstantsUtil.PH_PRODUCT_CODES;
  
    //Provisioning, Onboarding etc cases to be created,collect them here, add to casesToInsert.
    //Please also see commitCaseInsert() method
    public static List<Case> casesToInsert = new List<Case>();
    public static List<Case> manualProvisionCases = new List<Case>();
    public static List<Case> onboardingCases = new List<Case>();
    public static List<Case> coOpCases = new List<Case>();
  
    /**
     * Creates Product Provisioning Cases
     *
     * SA-170 : Updated to pull functionality out of OrderProductTriggerFunctions 
     *          and into its own class ProductProvisioningCaseProcessor
     */
  
    public static void createProvisioningCases(List<OrderItem> newOrderProductList) {
  
        List<Case> caseListToBeCreated = ProductProvisioningCaseProcessor.createProvisioningCases(newOrderProductList);
  
        if (caseListToBeCreated.size() > 0){
          
          manualProvisionCases.addAll(caseListToBeCreated); //BR-7299
  
        }
    }
  
  
    /**
     * Creates CoOp Cases
     *
     * SA-299 : Updated to pull functionality out of OrderProductTriggerFunctions 
     *          and into its own class CoOpCaseProcessor
     */
  
    public static void createCoOpCases(Map<Id, OrderItem> newOrderItemsMap, Map<Id, OrderItem> oldOrderItemsMap) {
  
        List<Case> caseListToBeCreated = CoOpCaseProcessor.createCoOpCases(newOrderItemsMap, oldOrderItemsMap);
  
        if (caseListToBeCreated.size() > 0){
          coOpCases.addAll(caseListToBeCreated);
        }
    }
  
    /**
    * BR-888
    * BR-7299 - if large quote is processed by a queueable then this will fail since
    *  the trigger handles records in chunks of 200 and this function would have already
    *  set the order status to Activated - the 201st Order Item would cause the error if that
    *  order items belongs to an Order that was previously activated. Hence escape this method
    *  if queueable
    **/
  
    public static void setOrderStatusToActivated(List<OrderItem> newOrderProductList){
        if(System.isQueueable()) {
            return;
        }
        Set<Id> orderIDs = new Set<Id>();
        for (OrderItem oProd : newOrderProductList){
            if (oProd.OrderId != null){
                orderIDs.add(oProd.OrderId);
            }
        }
        if (!orderIDs.isEmpty()){
            List<Order> orderToSetActivated = new List<Order>();
            for (order ord : [
                SELECT Id, Status
                FROM Order
                WHERE ID IN :orderIDs
            ]) {
                ord.Status = ACTIVATED_STATUS;
                orderToSetActivated.add(ord);
            }

            if (!orderToSetActivated.isEmpty()){
                Database.update(orderToSetActivated);
                System.debug('order has been activated');
            }
        }
    }
      
    /**
     * BR-888
     * SA-559 - Updated to run after insert and use activation POBs metadata
     * DSS-31 - Modified method to remove a lot of the processing from this method. Moving the processing logic to the event trigger.
     *
     * modified: 01/30/2023
     * modifiedby: Lawrence Zhao
     */
  
    public static void publishOrderItemUpdateEvent(Map<Id, OrderItem> newOrderProductMap){
    
        // list of event messages to publish
        List<Order_Item_Update_Event__e> publishEvents = new List<Order_Item_Update_Event__e>();

        for (OrderItem orderItem : newOrderProductMap.values()) {
            // add platform event here to kick off process that will handle order items for large orders
            publishEvents.add(
                new Order_Item_Update_Event__e (
                    TransactionId__c = orderItem.Id,
                    ProductId__c = orderItem.Product2Id
                )
            );
        }

        // if messages present, publish them
        if (!publishEvents.isEmpty()) {
            EventBus.publish(publishEvents);
        }
    }
  
    /**
     * Update the ContractCustom__c field on orders | Jira: BR-367 & BR-368
     */
    
    public static void updateOrderContractId(Map<ID,ID> orderIdToContactIdMap){
        List<Order> ordersToUpdate = new List<Order>();
  
        for (Order o : [
            SELECT ContractCustom__c
            FROM Order
            WHERE Id IN : orderIdToContactIdMap.keySet()
            ]) {
            if (o.ContractCustom__c != orderIdToContactIdMap.get(o.Id)){
                o.ContractCustom__c = orderIdToContactIdMap.get(o.Id);
                ordersToUpdate.add(o);
            }
        }
        
        update ordersToUpdate;
    }
  
    /**
     * Update the ContractCustom__c field on orders whenever an order item is
     * inserted or updated | Jira: BR-367 & BR-368
     */
      
    public static void checkOrderContractId(List<OrderItem> newOiList, Map<ID,OrderItem> oldOiMap){
        Map<ID,ID> orderIdToContractIdMap = new Map<ID,ID>();
        
        for (OrderItem oi : newOiList){
            ID orderId = oi.OrderId;
            ID contractId = oi.SBQQ__Contract__c;
            
            if (!Trigger.isInsert && !(Trigger.isUpdate && (contractId != oldOiMap.get(oi.Id).SBQQ__Contract__c))){
                continue;
            }
            
            if (orderId == null || contractId == null || orderIdToContractIdMap.containsKey(orderId)){
                continue;
            }
            
            orderIdToContractIdMap.put(orderId, contractId);
        }  
        
        if (!orderIdToContractIdMap.isEmpty()){
            updateOrderContractId(orderIdToContractIdMap);
        }        
    }
  
  
  
    /**
    *  Makes context swap to future method for queue assignment
    */
  
    private static void manualProvisioningAssignQueue(Map<Id, Case> manualProvisionCaseMap) {
        // calling future method to fix the case assignment overwrite issue
        if(!System.isFuture()) {
            if(!System.isBatch()) {
                assignQueueFuture(manualProvisionCaseMap.keySet());
            } else {
                assignQueue(manualProvisionCaseMap.keySet());
            }
        }
    }
  
    /*
    * Assign queue future function used for context swapping
    */
  
    @future
    private static void assignQueueFuture(Set<Id> caseIds) {
        assignQueue(caseIds);
    }
  
    /**
    * Determines and assigns queue for provisioning cases
    */
  
    private static void assignQueue(Set<Id> caseId) {
  
        List<Case> caseListToBeUpdated = new List<Case>();
        List<Task> tasksToUpdate = new List<Task>();
        Map<String, Id> caseQueueWithIds = Utilities.getCaseQueueMap();
        Id UkAdOpsQueueId = caseQueueWithIds.get('UK Ad Ops Case Queue');
        Id UkAreaBoostQueueId = caseQueueWithIds.get('UK Area Boost Case Queue');
  
        for (Case c : [
            SELECT  Id, 
                    Order_Product__r.Product2.Name, 
                    Order_Product__r.Product2.Activation_Case_Queue__c, 
                    Order_Product__r.Product2.Deactivation_Case_Queue__c, 
                    Order_Product__r.Product2Id, 
                    Order_Product__r.Quantity, 
                    OwnerId, 
                    Account.BillingCountryCode,
                    Order_Product__r.Product2.Sub_Category__c,
                    (SELECT Id, OwnerId, Status FROM Tasks WHERE Status = 'Open')
            FROM Case
            WHERE Id 
            IN :caseId
        ]) {
            if (c.Order_Product__c != null && c.Order_Product__r.Quantity > 0) {
                if (c.Order_Product__r.Product2Id != null && c.Order_Product__r.Product2.Activation_Case_Queue__c != null) {
                c.ownerId = c.Account.BillingCountryCode == 'GB' ? (c.Order_Product__r.Product2.Sub_Category__c == 'Area Boost' ? UkAreaBoostQueueId : UkAdOpsQueueId)
                    : caseQueueWithIds.get(c.Order_Product__r.Product2.Activation_Case_Queue__c);
                caseListToBeUpdated.add(c);
                }
            } else if (c.Order_Product__c != null && c.Order_Product__r.Quantity < 0) {
            if ( c.Order_Product__r.Product2Id != null && c.Order_Product__r.Product2.Deactivation_Case_Queue__c != null) {
                c.ownerId = c.Account.BillingCountryCode == 'GB' ? (c.Order_Product__r.Product2.Sub_Category__c == 'Area Boost' ? UkAreaBoostQueueId : UkAdOpsQueueId)
                    : caseQueueWithIds.get(c.Order_Product__r.Product2.Deactivation_Case_Queue__c);
                caseListToBeUpdated.add(c);
            }
            }
        }
        
        for(Case c : caseListToBeUpdated) {
            for(Task t : c.Tasks) {
                t.OwnerId = c.OwnerId;
                tasksToUpdate.add(t);
            }
        }
        
        Database.update(caseListToBeUpdated);
        Database.update(tasksToUpdate);
    }
    
  
    /**
     * Below Functions Are All Related to Onboarding Case Processing  
     */
  
    /**
     * Create onboarding cases if a given fulfillment account gets booked when being either prospect or former customer
     */
  
    public static void createOnboardingCases(Map<Id, OrderItem> newOrderItemsMap, Map<Id, OrderItem> oldOrderItemsMap) {
        system.debug('createOnboardingCases');
        List<OrderItem> updatedOrderItemsList = new List<OrderItem>();
        
        // consider only newly activated order products, or order products that are set with a transaction type
        // (need to check both due to potential sequence-of-operations gaps)
        for(OrderItem oi : newOrderItemsMap.values()) {
          Boolean transactionTypeChanged = (oi.Transaction_Type__c != null && oi.Transaction_Type__c != oldOrderItemsMap.get(oi.id).Transaction_Type__c);
          if(oldOrderItemsMap.get(oi.id).Transaction_Type__c == null && transactionTypeChanged) {
              updatedOrderItemsList.add(oi);
          }
        }
  
        if(updatedOrderItemsList.isEmpty()) {
            return;
        }
  
        //BR-7814 Query for "US Onboarding Case Queue"
        Map<String,Id> caseQueueMap = Utilities.getCaseQueueMap();
        Id USonboardingCaseQueue = caseQueueMap.get('US Onboarding Case Queue');
  
        Map<Id,List<Case>> onboardingCasesMap = new Map<Id,List<Case>> (); //BR-7332
        Set<Id> fulfillmentAccountIdList = new Set<Id>();
        Set<Id> baseBundleQlIdList = new Set<Id>();
        Set<Id> phProductQlIdList = new Set<Id>();
        Map<Id,OrderItem> baseBundlesMap = new Map<Id,OrderItem>();
        Id RECORDTYPEIDRETENTION = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Retention').getRecordTypeId();
  
        // re-query only Bundle-header order products (either CG Base or Standalone)
        Map<Id, OrderItem> orderItemsMap = new Map<Id, OrderItem>([
          SELECT Id, Fulfillment_Account__c, Fulfillment_Account__r.OwnerId, Fulfillment_Account__r.Name, 
            Fulfillment_Account__r.BillingCountryCode, Fulfillment_Account__r.Type, Transaction_Type__c, OrderId,
            Order.SBQQ__Quote__c, Order.SBQQ__Quote__r.SBQQ__Type__c, SBQQ__QuoteLine__c, SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__c,
            SBQQ__QuoteLine__r.Used_Inventory_Cap__c, Product2.ProductCode, SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__PrimaryContact__c
          FROM OrderItem 
          WHERE Id IN :updatedOrderItemsList
            AND (
              Product2.ProductCode = 'CG-BASE' OR Product2.ProductCode = 'CG-DIG-DEAL' OR
              Fulfillment_Account__r.BillingCountryCode = 'GB' OR 
              (Transaction_Type__c = 'New Business' AND Fulfillment_Account__r.BillingCountryCode = 'US') OR
              (Order.SBQQ__Quote__r.SBQQ__Type__c = 'Renewal' AND Fulfillment_Account__r.BillingCountryCode = 'US')
            )
            AND SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__r.RecordTypeId != :RECORDTYPEIDRETENTION //BR-5316
        ]);
  
        for(OrderItem oi : orderItemsMap.values()) {
          baseBundleQlIdList.add(oi.SBQQ__QuoteLine__c);
          fulfillmentAccountIdList.add(oi.Fulfillment_Account__c);
          if(oi.Product2.ProductCode == 'CG-BASE') {
            baseBundlesMap.put(oi.Fulfillment_Account__c, oi);
          }
          if (PH_PRODUCT_CODES.contains(oi.Product2.ProductCode)){
            phProductQlIdList.add(oi.SBQQ__QuoteLine__c);
          }
        }
          
        system.debug('phProductQlIdList::'+phProductQlIdList);
        Map<Id, SBQQ__QuoteLine__c> newPHquoteLinesMap = new Map<Id, SBQQ__QuoteLine__c>();
  
        // if ph products are detected, run ph line query
        if (phProductQlIdList != null && phProductQlIdList.size() > 0) {
  
          // query PistonHeads-only constituent quotelines, for new deals only
          for(SBQQ__QuoteLine__c ql : [
            SELECT Id, SBQQ__RequiredBy__c
            FROM SBQQ__QuoteLine__c
            WHERE (SBQQ__RequiredBy__c IN :baseBundleQlIdList OR ID IN: phProductQlIdList)
              AND SBQQ__Product__r.Provisioning_Platform__c INCLUDES ('PistonHeads')
              AND (SBQQ__Quote__r.SBQQ__Type__c = 'Quote'
                OR (SBQQ__Quote__r.SBQQ__Type__c = 'Amendment'
                  AND SBQQ__Existing__c = false)
                OR (SBQQ__Quote__r.SBQQ__Type__c = 'Renewal'
                  AND SBQQ__RenewedSubscription__c = null)
              )
          ]) {
            // we populate a map: requiredBy -> one PH product
            // (it doesn't matter if there are more, detecting one is enough to create a PH onboarding case)
              if (!baseBundleQlIdList.contains(ql.SBQQ__RequiredBy__c)) {
                  newPHquoteLinesMap.put(ql.Id, ql);
              } else {
                  newPHquoteLinesMap.put(ql.SBQQ__RequiredBy__c, ql);
              }
          }
        }
          
        // query fulfillment accounts with their related Used SPs
        // currently the OrderBy will return 'Used' SPs first in the list
        Map<Id,Account> fulfillmentAccountsMap = new Map<Id,Account>([
          SELECT Id, PH_Admin_Centre_Id__c, (SELECT Id FROM Service_Provider__r ORDER BY Dealer_Type__c DESC NULLS LAST),
            (SELECT Id, TeamMemberRole, UserId FROM AccountTeamMembers) //BR-7814 Need to get Account Manager teamRole
          FROM Account
          WHERE Id IN :fulfillmentAccountIdList
        ]);
  
  
        for(OrderItem oi : orderItemsMap.values()) {
            
          Boolean isCAandQualifiesForOnboarding = oi.Fulfillment_Account__r.BillingCountryCode == 'CA'
            && (oi.Fulfillment_Account__r.Type == 'Prospect' || oi.Fulfillment_Account__r.Type == 'Former Customer');
            
          Boolean isGBandQualifiesForOnboarding = oi.Fulfillment_Account__r.BillingCountryCode == 'GB' 
            && oi.SBQQ__QuoteLine__r.Used_Inventory_Cap__c > 10 && oi.Product2.ProductCode == 'CG-BASE'
            && (oi.Fulfillment_Account__r.Type == 'Prospect' || oi.Fulfillment_Account__r.Type == 'Former Customer');
            
          Boolean isGBandQualifiesForPHOnboarding = oi.Fulfillment_Account__r.BillingCountryCode == 'GB' 
            && newPHquoteLinesMap.get(oi.SBQQ__QuoteLine__c) != null;
            
          Boolean isUSandQualifiesForOnboarding = oi.Fulfillment_Account__r.BillingCountryCode == 'US' 
            && oi.Transaction_Type__c == 'New Business'
            && !onboardingCasesMap.containsKey(oi.Fulfillment_Account__c)
            && (oi.Product2.ProductCode == 'CG-BASE'
              || baseBundlesMap.get(oi.Fulfillment_Account__c) == null
              || baseBundlesMap.get(oi.Fulfillment_Account__c).Transaction_Type__c != 'New Business'
            );
  
            Boolean isDigitalDealOnBoardingProduct =  oi.Product2.ProductCode == 'CG-DIG-DEAL' ;
  
          /* CA & UK: only create onboarding cases for new customers (stores). consider both net new quotes 
            as well as store additions by amending or renewing existing contracts
            US: create onboarding cases for all 'New Business' transactions, only one case per account (BR-4540)
          */ 
            
            
          if(isCAandQualifiesForOnboarding || isGBandQualifiesForOnboarding) {
              
            Case newCase = createRegularOnboardingCase(
              oi.Fulfillment_Account__c, 
              oi.Fulfillment_Account__r.Name, 
              oi.Fulfillment_Account__r.OwnerId, 
              oi.Order.SBQQ__Quote__c, 
              oi.OrderId, 
              oi.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__c
            );
              
            if (!onboardingCasesMap.containsKey(oi.Fulfillment_Account__c)) {
              onboardingCasesMap.put(oi.Fulfillment_Account__c, new List<Case> ());
            }
            onboardingCasesMap.get(oi.Fulfillment_Account__c).add(newCase);        
  
          }
            
            
          if (isUSandQualifiesForOnboarding) {
  
              Id ownerIdForUSonboardingCase = USonboardingCaseQueue;
              List<AccountTeamMember> accTeamMembers = 
                  fulfillmentAccountsMap.get(oi.Fulfillment_Account__c).AccountTeamMembers != null ?
                  fulfillmentAccountsMap.get(oi.Fulfillment_Account__c).AccountTeamMembers : new List<AccountTeamMember> () ;
  
              for (AccountTeamMember act : accTeamMembers){
                  if (act.TeamMemberRole == 'Account Manager'||act.TeamMemberRole == 'Field Account Manager') {
                  ownerIdForUSonboardingCase = act.UserId;
                  break;
                  }
              }          
  
            Case newCase = createRegularOnboardingCase(
              oi.Fulfillment_Account__c, 
              oi.Fulfillment_Account__r.Name, 
              ownerIdForUSonboardingCase, 
              oi.Order.SBQQ__Quote__c, 
              oi.OrderId, 
              oi.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__c
            );
  
            if (!onboardingCasesMap.containsKey(oi.Fulfillment_Account__c)) {
              onboardingCasesMap.put(oi.Fulfillment_Account__c, new List<Case> ());
            }
            onboardingCasesMap.get(oi.Fulfillment_Account__c).add(newCase);
             
          }
          
          // for GB specifically, we need to check if it qualifies for PistonHeads onboarding
          if(isGBandQualifiesForPHOnboarding) {
  
            List<Service_Provider__c> usedSPs = fulfillmentAccountsMap.get(oi.Fulfillment_Account__c).Service_Provider__r;
            
            /*BR-8895, Removing PH Admin Id check
            String adminCentreId = fulfillmentAccountsMap.get(oi.Fulfillment_Account__c).PH_Admin_Centre_Id__c;  
            if (adminCentreId == '' || adminCentreId == null) {
            }
            */
            Id spId = usedSPs.isEmpty() ? null : usedSPs[0].Id;
  
            Case newCase = createPhOnboardingCase(oi.Fulfillment_Account__c, spId, oi.orderID);
  
            if(!onboardingCasesMap.containsKey(oi.Fulfillment_Account__c)) {
              onboardingCasesMap.put(oi.Fulfillment_Account__c, new List<Case> ());
            }
            onboardingCasesMap.get(oi.Fulfillment_Account__c).add(newCase);
          }
        }
  
        if(!onboardingCasesMap.isEmpty()) {
          for (Id fullAccId : onboardingCasesMap.keySet()) {
            onboardingCases.addAll(onboardingCasesMap.get(fullAccId)); //BR-7299
          }
        }    
    }
  
    /**
     * Creates regular onboarding case record
     */
  
    private static Case createRegularOnboardingCase(Id ffAccId, String ffAccName, Id ownerId, Id quoteId, Id orderId, Id oppId) {
        Case newCase = new Case();
        newCase.AccountId = ffAccId;
        newCase.OwnerId = ownerId;
        newCase.Related_Quote__c = quoteId;
        newCase.Order__c = orderId;
        newCase.Subject = 'Onboarding case for ' + ffAccName;
        newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Onboarding').getRecordTypeId();
        newCase.Origin = 'Internal';
        newCase.Priority = 'Medium';
        newCase.Status = 'New';
        newCase.Related_Opportunity__c = oppId;
        return newCase;
    }
  
      /*private static Case createRegularUSonboardingCase(Id ffAccId, String ffAccName, Id ownerId, Id quoteId, Id orderId, Id oppId) {
        Case newCase = new Case();
        newCase.AccountId = ffAccId;
        newCase.OwnerId = ownerId;
        newCase.Related_Quote__c = quoteId;
        newCase.Order__c = orderId;
        newCase.Subject = 'Onboarding Value Review for ' + ffAccName;
        newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Onboarding').getRecordTypeId();
        newCase.Origin = 'Internal';
        newCase.Priority = 'Medium';
        newCase.Status = 'New';
        newCase.Reason = 'Onboarding Value Review';
        newCase.Related_Opportunity__c = oppId;
        newCase.Comments = 'Please complete the 5 tasks before closing case.';
        return newCase;
    }*/
  
    private static Case createPhOnboardingCase(Id ffAccId, Id spId, ID orderID) {
        QueueSobject phQueue = [
        SELECT QueueId 
        FROM QueueSobject 
        WHERE SobjectType = 'Case' AND Queue.DeveloperName = 'PistonHeads_Case_Queue'
        LIMIT 1
        ];
        Case newCase = new Case();
        newCase.AccountId = ffAccId;        
        newCase.OwnerId = phQueue.QueueId;
        newCase.Subject = 'New Dealer Activation checks in PH Admin';
        newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Onboarding').getRecordTypeId();
        newCase.Reason = 'Support: PH Activation Checks';
        newCase.Origin = 'Internal';
        newCase.Priority = 'Medium';
        newCase.Status = 'New';
        newCase.Service_Provider__c = spId;
        newCase.Order__c = orderID;
        return newCase;
    }
  
    /**
     * Inserts onboarding and provisioning cases
     */
  
    public static void commitCaseInsert() {
        if (!manualProvisionCases.isEmpty()) {
            casesToInsert.addAll(manualProvisionCases);
        }
  
        if (!onboardingCases.isEmpty()) {
            casesToInsert.addAll(onboardingCases);
        }
  
        if (!coOpCases.isEmpty()) {
            casesToInsert.addAll(coOpCases);
        }
  
        if(!casesToInsert.isEmpty()) {
            insert casesToInsert;
        }
  
        if(!manualProvisionCases.isEmpty()) {
            manualProvisioningAssignQueue(new Map<Id, Case>(manualProvisionCases));
        }
  
        casesToInsert.clear();
        manualProvisionCases.clear();
        onboardingCases.clear();
        coOpCases.clear();
    }
  
}

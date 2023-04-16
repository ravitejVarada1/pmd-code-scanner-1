// https://cargurus.atlassian.net/browse/BR-1613
public without sharing class ZuoraIntegration_RevproHelper {

  static final Integration_Controls__mdt INTEGRATION_CONTROLS = Integrations.INTEGRATION_CONTROLS;
  static final Datetime SENDAFTERONDEMAND = Datetime.now().addMinutes(10);
  static final Datetime SENDINQUEUE = Datetime.now().addMinutes(-10);
  static final String PROCESS_ZREVPROACTIVATION = Integrations.PROCESS_ZREVPROACTIVATION;
  static final String REQUEST_STATUS_NEW = Integrations.REQUEST_STATUS_NEW;
  static final Boolean sendImmediately = true;

  public static void createAndSendRevproActivationMessages(List<OrderItem> orderItems) {

    if (!INTEGRATION_CONTROLS.Enable_Zuora_Integration__c || orderItems.isEmpty()) {
      return;
    }

    List<Integration_Message__c> integrationMessages = getRevproMessages(orderItems);
    insert integrationMessages;

    if (sendImmediately) {
      Integrations.sendMessageIdsToBoomi(integrationMessages);
    }

  }
  
  public static List<Integration_Message__c> getRevproMessages(List<OrderItem> orderItems) {

    List<Integration_Message__c> integrationMessages = new List<Integration_Message__c>();
    List<Id> rateplanIds = new List<Id>();

    for(OrderItem oi : orderItems) {
        if(String.isNotBlank(oi.SBQQ__Subscription__r.Zuora_Subscription_Rate_Plan__c)) {
            rateplanIds.add(oi.SBQQ__Subscription__r.Zuora_Subscription_Rate_Plan__c);
        }
    }

    Map<Id,Zuora__SubscriptionProductCharge__c> charges = new Map<Id,Zuora__SubscriptionProductCharge__c>();
    for(Zuora__SubscriptionProductCharge__c charge : [
        SELECT Zuora__SubscriptionRatePlan__c, Zuora__Segment__c, Zuora__SubscriptionChargeNumber__c, 
          Zuora__Zuora_Id__c, Zuora__OriginalId__c, Zuora__EffectiveEndDate__c
        FROM Zuora__SubscriptionProductCharge__c
        WHERE Zuora__SubscriptionRatePlan__c IN :rateplanIds
          AND Zuora__Model__c != 'Discount-Percentage'
    ]) {
        charges.put(charge.Zuora__SubscriptionRatePlan__c, charge);
    }

    for(OrderItem oi : orderItems) {
      String ratePlanId = oi.SBQQ__Subscription__r.Zuora_Subscription_Rate_Plan__c;
      String chargeNumber = extractFieldValue(charges, ratePlanId, 'Zuora__SubscriptionChargeNumber__c');
      String origChargeId = extractFieldValue(charges, ratePlanId, 'Zuora__OriginalId__c');
      String segment = extractFieldValue(charges, ratePlanId, 'Zuora__Segment__c');
      DateTime dt = oi.ServiceDate > oi.Manual_Activation_Date__c ? oi.ServiceDate : oi.Manual_Activation_Date__c;
      // we need to add 1 day as the formatting converts from midnight GMT to current timezone, and as it's US it'll convert to one day less
      String caseCloseDate = String.valueOf(((DateTime) oi.Manual_Activation_Date__c).addDays(1).format('MM/dd/yyyy'));
      String revproStartDate = String.valueOf(dt.addDays(1).format('MM/dd/yyyy'));
      String chargeEffectiveEndDate = extractDateFieldValueFormatted(charges, ratePlanId, 'Zuora__EffectiveEndDate__c', 'MM/dd/yyyy');
      
      // body is (in csv format): chargeNumber,Segment (defaulted),100 (defaulted),startDate,endDate,activationDate
      String body = chargeNumber + ',' + '1' + ',100,'+ revproStartDate +','+ chargeEffectiveEndDate +',' + caseCloseDate;

      integrationMessages.add(
        new Integration_Message__c(
          Account__c = oi.Billing_Account__c,
          CPQ_Order__c = oi.OrderId,
          CPQ_Order_Product__c = oi.Id,
          Request_Body__c = body,
          Request_Status__c = REQUEST_STATUS_NEW,
          Process__c = PROCESS_ZREVPROACTIVATION,
          Send_After__c = (sendImmediately ? SENDAFTERONDEMAND : SENDINQUEUE)
        )
      );
    }

    return integrationMessages;

  }

  private static String extractFieldValue(Map<Id,Zuora__SubscriptionProductCharge__c> charges, String ratePlanId, String fieldName) {
    String result = '';
    try {
      result = String.valueOf((charges.get(ratePlanId)).get(fieldName));
    } catch(Exception e) {
      System.debug('No Zuora rate plan found related to the order product');
    }
    if(result == '' && fieldName == 'Zuora__Segment__c') {
      return '1';
    }
    return result;
  }

  private static String extractDateFieldValueFormatted(Map<Id,Zuora__SubscriptionProductCharge__c> charges, String ratePlanId, String fieldName, String format) {
    String result = '';
    try {
      result = String.valueOf(((DateTime)(charges.get(ratePlanId)).get(fieldName)).format(format));
    } catch(Exception e) {
      System.debug('No Zuora rate plan found related to the order product');
    }
    return result;
  }

}
public with sharing class Utilities {

    public static final String ORGURL = URL.getOrgDomainUrl().toExternalForm();

    //Checks if code is already in a async context. If yes, deserialize and insert sObjects.
    //If no, call future version of this method
    public static void futureInsert(String sObjectsToInsert){
        if (System.isBatch() || System.isFuture()){
            insert (List<sObject>)JSON.deserialize(sObjectsToInsert, List<sObject>.class);
        }else{
            futureInsertWithAnnot(sObjectsToInsert);
        }
    }

    //Accepts a JSON serialized list of sObjects, and inserts them in a future method
    @future
    private static void futureInsertWithAnnot(String sObjectsToInsert){
        futureInsert(sObjectsToInsert);
    }

    //Checks if code is already in a async context. If yes, deserialize and insert sObjects.
    //If no, call future version of this method
    public static void futureUpdate(String sObjectsToUpdate){
        if (System.isBatch() || System.isFuture()){
            update (List<sObject>)JSON.deserialize(sObjectsToUpdate, List<sObject>.class);
        }else{
            futureUpdateWithAnnot(sObjectsToUpdate);
        }
    }
    
    //Accepts a JSON serialized list of sObjects, and inserts them in a future method
    @future
    private static void futureUpdateWithAnnot(String sObjectsToUpdate){
        futureUpdate(sObjectsToUpdate);
    }
    

    //Map of object name to map of record type name and Id - created via BR-825
    public static Map<String,Map<String,ID>> objectToRecordTypeNameMap = new Map<String,Map<String,ID>>();
    public static ID getrecordTypeId(String objectType, String developerName){   
        //If map already contains teh record type, just return it
        if (objectToRecordTypeNameMap.get(objectType)?.get(developerName) != null){
            return objectToRecordTypeNameMap.get(objectType).get(developerName);
        }

        Map<String,ID> recordTypeToIdMap = new Map<String,ID>();  
        objectToRecordTypeNameMap.put(objectType, recordTypeToIdMap);

        //Put all the record types for the specified object in the map
        for (RecordType rt : [SELECT Id, DeveloperName
                                FROM RecordType
                                WHERE SobjectType = :objectType])
        {
            recordTypeToIdMap.put(rt.DeveloperName, rt.Id);
        }

        //Return just the specified record type Id
        return recordTypeToIdMap.get(developerName);
    }

    public static final Boolean IS_SANDBOX = [SELECT IsSandbox FROM Organization LIMIT 1][0].isSandbox;

    //Create and returns a cron string <minutesFromNow> minutes from now
    public static String getCronExpressionMinutesFromNow(Integer minutesFromNow) {
        Datetime scheduleDT = Datetime.now().addMinutes(minutesFromNow);
        String cronString = scheduleDT.second()+' '+
            scheduleDT.minute()+' '+
            scheduleDT.hour()+' '+
            scheduleDT.day()+' '+
            scheduleDT.month()+' ? '+
            scheduleDT.year();

        return cronString;
    }

    private static Map<String, Id> businessHoursMap;
    public static Map<String, Id> getBusinessHoursMap() {
        if (businessHoursMap == null) {
            businessHoursMap = new Map<String, Id>();
            for(BusinessHours bh : [SELECT id, Name, isDefault FROM BusinessHours WHERE isActive = true]) {
                businessHoursMap.put(bh.Name, bh.Id);
                if(bh.isDefault) {
                    businessHoursMap.put('Default', bh.Id);
                }
            }
        }
        return businessHoursMap;
    }

    public static Boolean isDateDuringBusinessHours(DateTime d, String countryCode) {

        Map<String, Id> businessHoursMap = getBusinessHoursMap();
        String countryToUse = countryCode == null ? 'Default' : countryCode;
        String businessHoursId = (String) businessHoursMap.get(countryToUse);
        if(BusinessHours.isWithin(businessHoursId, d)) {
            return true;
        }
        return false;
    }

    public static final Set<String> RUNNING_ASYNC_STATUSES = new Set<String>{
        'Holding',
        'Queued',
        'Preparing',
        'Processing'
    };
    
    public static Boolean batchAlreadyRunning(String batchClassName) {
        return !([SELECT ApexClassId FROM AsyncApexJob WHERE ApexClass.Name = :batchClassName AND JobType = 'BatchApex' 
            AND Status IN : RUNNING_ASYNC_STATUSES LIMIT 1]).isEmpty();   
    }

    public static Map<String, Id> getCaseQueueMap(){

		Map<String, Id> caseQueueWithIds = new Map<String, Id>(); 
		for (QueueSobject qu : [SELECT QueueId, Queue.Name 
                                FROM QueueSobject 
                                WHERE SobjectType = 'Case']){
			caseQueueWithIds.put(qu.Queue.Name, qu.QueueId);
		}
		return caseQueueWithIds;
	}

     /*
    * Gets and returns product provisioning metadata
    */

    public static Map<String, Product_Provisioning_Behavior__mdt> getProductProvisioningMetadata() {
       return Product_Provisioning_Behavior__mdt.getAll();
    }

    /*
    * Gets and returns list of pobs requiring activation case
    */

    public static List<String> getManualActivationPobs() {
        List<String> valuesToReturn = new List<String>();
        for (Product_Provisioning_Behavior__mdt pob : getProductProvisioningMetadata().values()) {
            if (pob.Create_Activation_Case__c == true) {
                valuesToReturn.add(pob.MasterLabel);
            }
        }
        return valuesToReturn;
    }

    /*
    * Gets and returns list of pobs requiring deactivaiton case
    */

    public static List<String> getManualDeactivationPobs() {
        List<String> valuesToReturn = new List<String>();
        for (Product_Provisioning_Behavior__mdt pob : getProductProvisioningMetadata().values()) {
            if (pob.Create_Deactivation_Case__c == true) {
                valuesToReturn.add(pob.MasterLabel);
            }
        }
        return valuesToReturn;
    }

    /*
    * Gets and returns lists of pobs requiring rev pro activation message
    */

    public static List<String> getRevProActivationPobs() {
        List<String> valuesToReturn = new List<String>();
        for (Product_Provisioning_Behavior__mdt pob : getProductProvisioningMetadata().values()) {
            if (pob.Activate_Revenue_Recognition__c == true) {
                valuesToReturn.add(pob.MasterLabel);
            }
        }
        return valuesToReturn;
    }
    
    //- Jira: BR-788
    //Dynamically returns the type of an object
    public static string getType(Object o){
        if(o == null){
            return null;
        }
        if(o instanceof SObject){
            return ((SObject)o).getSObjectType().getDescribe().getName()+'';
        }
        if(o instanceof Boolean){          
            return 'Boolean';
        }
        if(o instanceof Id){           
            return 'Id';
        }
        if(o instanceof String){        
            return 'String';
        }
        if(o instanceof Blob){              
            return 'Blob';
        }
        if(o instanceof Date){             
            return 'Date';
        }
        if(o instanceof Datetime){           
            return 'Datetime';
        }
        if(o instanceof Time){            
            return 'Time';
        }
        if(o instanceof Integer){         
            return 'Integer';
        }
        if(o instanceof Long){              
            return 'Long';
        }
        if(o instanceof Decimal){            
            return 'Decimal';
        }
        if(o instanceof Double){             
            return 'Double';
        } 
        if(o instanceof List<object>){       
            return 'List';
        }
        return 'Object';                    
    }

    //- Jira: BR-788
    //Takes four strings (including a fieldType string and an operator), and dynamically compares the field values
    public static Boolean compareDynamically(String fieldValue, String expectedValue, String operator, String fieldType){
        
        Boolean fieldIsNull = fieldValue == null;
        
        if (expectedValue == ''){
            return fieldIsNull;
        }else if (fieldIsNull){
            return false;
        }
        
        Switch on operator{
            when '='{
                Switch on fieldType{
                    when 'Decimal'{
                        return Decimal.valueOf(fieldValue) == Decimal.valueOf(expectedValue);
                    }when 'String'{
                        return String.valueOf(fieldValue) == String.valueOf(expectedValue);
                    }when 'Boolean'{
                        return Boolean.valueOf(fieldValue) == Boolean.valueOf(expectedValue);
                    }
                }
            }when '!='{
                Switch on fieldType{
                    when 'Decimal'{
                        return Decimal.valueOf(fieldValue) != Decimal.valueOf(expectedValue);
                    }when 'String'{
                        return String.valueOf(fieldValue) != String.valueOf(expectedValue);
                    }when 'Boolean'{
                        return Boolean.valueOf(fieldValue) != Boolean.valueOf(expectedValue);
                    }
                }
            }when '>'{
                return Decimal.valueOf(fieldValue) > Decimal.valueOf(expectedValue);
            }when '<'{
                return Decimal.valueOf(fieldValue) < Decimal.valueOf(expectedValue);
            }
        }
        return false;
    }

    /**
     * Takes in 2 SObjects and a string list of fields. Compares accounts for each field,
     * if difference found returns true. If no difference, returns false.
     *
     * @author  Adam LaPlante
     * @date    10/05/2021
     * @module  BR-4251 
     */

    public static boolean simpleCompareFields(SObject object1, SObject object2, List<String> fields) {
        for (String field : fields) {
            if (object1.get(field) != object2.get(field)) {
                return true;
            }
        }
        return false;
    }

    private static Map<String,String> currencyCountryMap;
  
    public static Map<String,String> getCurrencyCountryMap() {
        if (currencyCountryMap == null) {
        Set<String> activeCurrencies = new Set<String>();
        
        for(Schema.PicklistEntry s : Lead.CurrencyIsoCode.getDescribe().getPicklistValues()) {
                activeCurrencies.add(s.getValue());
            }
            
            currencyCountryMap = new Map<String,String>();
            if (activeCurrencies.contains('USD')) { currencyCountryMap.put('US', 'USD'); }
            if (activeCurrencies.contains('CAD')) { currencyCountryMap.put('CA', 'CAD'); }
            if (activeCurrencies.contains('GBP')) { currencyCountryMap.put('GB', 'GBP'); }
            if (activeCurrencies.contains('EUR')) {
                currencyCountryMap.put('DE', 'EUR');
                currencyCountryMap.put('IT', 'EUR');
                currencyCountryMap.put('ES', 'EUR');
                currencyCountryMap.put('FR', 'EUR');
            }
        }
        
        return currencyCountryMap;
    }
    
    public static void setCurrencyField(sObject obj, String billingCountry) {
        
        Map<String,String> currencyMap = Utilities.getCurrencyCountryMap();

        if (currencyMap != null && currencyMap.containsKey(billingCountry)) {
                obj.put('CurrencyIsoCode', currencyMap.get(billingCountry));
        }
    }

    public static String getEndOfLastMonth(Date dtInput){
      date d = dtInput.toStartOfMonth().addDays(-1);
      String dt = DateTime.newInstance(d.year(),d.month(),d.day()).format('yyyy-MM-dd');
      return dt;
    }
  
    public static Object getAnyObjFldValue (SObject sObjectType, String objfieldName) {
      Object fieldVal;
      SObject sObjectName = sObjectType;
      if (objfieldName.contains('.')) {
          List<String> refObjectFields = new List<String>(objfieldName.split('\\.'));
          String parentObjName 	= refObjectFields[0];
          String parentObjField 	= refObjectFields[1];
          if (parentObjName.contains('__r')) {
              //This block is to deal with custom relationships.
              String parentObjAPIName = parentObjName.replace('__r','__c');
              if(sobjectName.get(parentObjAPIName) != null && sobjectName.getSObject(parentObjName).get(parentObjField) != null){
                  fieldVal = sobjectName.getSObject(parentObjName).get(parentObjField);
              }
          } else {
              //This block is to deal with standard relationships.
              if(sobjectName.getSObject(parentObjName).get(parentObjField) != null){
                  fieldVal = sobjectName.getSObject(parentObjName).get(parentObjField);
              }
          }
      } else {
          fieldVal = sObjectName.get(objfieldName);
      }
      return fieldVal;
    }

    public static void wait(Integer secondsToWait){
        Long endTime = System.Now().getTime() + (secondsToWait * 1000);
        while(System.Now().getTime() < endTime){
            //DO NOTHING - JUST WAIT
        }
    }
    
    public static String formatDate(DateTime d) {
        String returnDate = d.format('dd-MMM-yyyy');
        return returnDate;
    }

    public static Object getValue(SObject record, String path) {
        try {
            SObject temp = record;
            String[] parts = path.split('\\.');
            while(parts.size() > 1) {
                temp = temp.getSObject(parts.remove(0));
            }
            return temp.get(parts[0]);
        } catch(Exception e) {
            return null;
        }
    }

    private static Map<Id,UserRole> acqMap;
    public static Map<Id,UserRole> getAcqRoles() {
        Set<String> acqStrings = new Set<String>{ConstantsUtil.CA_SALES, ConstantsUtil.CA_SALES_MANAGER};
        if (acqMap == null) {
            acqMap = new Map<Id,UserRole>([SELECT Id, Name FROM UserRole WHERE DeveloperName IN: acqStrings]);
        }
        return acqMap;
    }

    private static Map<Id,UserRole> salesOpsMap;
    public static Map<Id,UserRole> getSalesOpsRoles() {
        if (salesOpsMap == null) {
            salesOpsMap = new Map<Id,UserRole>([SELECT Id, Name FROM UserRole 
                    WHERE DeveloperName LIKE '%Sales_Ops%' OR Name LIKE '%Sales_Operations%']);
        }
        return salesOpsMap;
    }
    
    /**
     * Fed a process name and error message, sends a simple error email to error emails
     * set in ConstantsUtil class
     *
     * @author Adam LaPlante
     * @module BR-4495
     */

    public static void sendSimpleErrorEmail(String process, String errorText) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(ConstantsUtil.ERROR_EMAILS);
        email.setSubject('IMPORTANT : Apex Process Failure - ' + process);
        email.setPlainTextBody('Please review the following error message: \n\n' + errorText);
        email.setHtmlBody('<b>Please review the following error message:</b> \n\n' + errorText);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
    }

    /**
     * Fed a subject, body, and recipient, sends a simple email.
     *
     * @author Adam LaPlante
     * @module BR-4495
     */

    public static void sendSimpleEmail(String subject, String body, String recipient) {
        List<String> recipients = new List<String>{recipient};
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipients);
        email.setSubject(subject);
        email.setPlainTextBody(body);
        email.setHtmlBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});
    }

    //BR-4077 Return Leads Queue Map
    public static Map<String, Id> getLeadQueueMap() {

		Map<String, Id> leadQueueWithIds = new Map<String, Id>(); 
		for (QueueSobject qu : [SELECT QueueId, Queue.DeveloperName
                                FROM QueueSobject 
                                WHERE SobjectType = 'Lead']) {

			    leadQueueWithIds.put(qu.Queue.DeveloperName, qu.QueueId);
		}
		return leadQueueWithIds;
	}
    /**
     * Checks if the user in scope has the specified permission assigned.
     */
    
    public static boolean checkCustomPermission(String permissionName) {
        return FeatureManagement.checkPermission(permissionName);
    }
    
    private static Map<String,Account_Cap__mdt> accountLimits;
    public static Map<String,Account_Cap__mdt> getAccountLimits() {
        if (accountLimits == null) {
            accountLimits = new Map<String,Account_Cap__mdt>();
            Map<String,Account_Cap__mdt> allLimits = Account_Cap__mdt.getAll();
            for (Account_Cap__mdt currCap : allLimits.values()) {
                accountLimits.put(currCap.Region__c,currCap);
            }
        }
        return accountLimits;
    }

    /**
     * Returns the CarGurus Account that has the entitlements setup
     * BR-7299
     */
    private static List<Account> cgEntitlementAccount;
    public static List<Account> getCGEntitlementAccount() {
        if(cgEntitlementAccount != null) {
            return cgEntitlementAccount;
        }

        cgEntitlementAccount = [SELECT Id FROM Account WHERE Name = 'CarGurus Account' LIMIT 1];
        return cgEntitlementAccount;
    }

    
    /**
     * Returns Product Language Setting Custom Metadata
     * SA-591
     */
    private static List<Product_Language_Setting__mdt> productLanguageSettingMap;
    public static List<Product_Language_Setting__mdt> getProductLanguageSetting () {
        
        if (productLanguageSettingMap != null) {
            return productLanguageSettingMap;
        }
        productLanguageSettingMap = [
            SELECT Id, Product_Name__c, Language__c, Product_Code__c, Product_Description__c, Valid_From__c, Valid_To__c
            FROM Product_Language_Setting__mdt
            WHERE Valid_From__c <= TODAY
            AND Valid_To__c >= TODAY
        ];

        return productLanguageSettingMap;
    }

    /**
     * Return Map with Translated Product Names
     * SA-591
     */
    public static Map<String,String> getTranslatedProductName() {

        Map<String,String> productNameLangMap = new Map<String,String> ();
        for (Product_Language_Setting__mdt pls : getProductLanguageSetting()) {
            String plsKey = pls.Language__c + '-' + pls.Product_Code__c;
            productNameLangMap.put(plsKey, pls.Product_Name__c);
        }
        return productNameLangMap;
    }
    
    /**
     * Return Map with Translated Product Descriptions
     * SA-591
     */    
    public static Map<String,String> getTranslatedProductDescription() {
                
        Map<String,String> productDescriptionLangMap = new Map<String,String> ();
        for (Product_Language_Setting__mdt pls : getProductLanguageSetting()) {
            String plsKey = pls.Language__c + '-' + pls.Product_Code__c;
            productDescriptionLangMap.put(plsKey, pls.Product_Description__c);
        }
        return productDescriptionLangMap;
    }

    // return set of ids common to both supplied id sets
    public static Set<Id> getCommonIds(Set<Id> idSet1, Set<Id> idSet2) {
        Set<Id> returnSet = new Set<Id>(idSet1);
        returnSet.retainAll(idSet2);
        return returnSet;
    }
    
     /*Identify Production / Sandbox Salesforce Org : Returns Boolean
      * CSS-110
      */
     public static Boolean isSandbox() {
        String sandboxName = DomainParser.parse(DomainCreator.getOrgMyDomainHostname()).getSandboxName();
        boolean isSandbox = false;
        if(!String.isEmpty(sandboxName)){
            isSandbox = true;
        }
        return isSandbox;
    }
    
}
public without sharing class OnboardingCaseProcessor {
    
    private static Map<String, List<Onboarding_Case_Tasks__mdt>> productToOnboardingCaseTasks = 
        new Map<String, List<Onboarding_Case_Tasks__mdt>>(); // DIG-DEALUS => Tasks Records to be created
    private static Map<String, List<Onboarding_Case_Fields__mdt>> productToCaseFields = 
        new Map<String, List<Onboarding_Case_Fields__mdt>>(); // DIG-DEALUS => Case Fields to be populated
    private static Map<String, Date> dateByProductCode = new Map<String, Date>(); // DIG-DEALUS => 08/11/2022
    private static List<String> obSettingsProductCodes = new List<String>();
    private static Date farthestLookbackDate = System.today();
    
    public Map<String, List<Onboarding_Case_Tasks__mdt>> getProductToOnboardingCaseTasks() { return productToOnboardingCaseTasks; }
    public Map<String, List<Onboarding_Case_Fields__mdt>> getproductToCaseFields() { return productToCaseFields; }
    public Date getFarthestLookbackDate() { return farthestLookbackDate; }
    public List<String> getSettingProducts() { return obSettingsProductCodes; }
    public Map<String,Date> getProductLookbackDates() { return dateByProductCode;}

    static {

        List<String> activeProdCodes = new List<String>();
        for(Product2 p : [SELECT Id, ProductCode, isActive FROM Product2 WHERE isActive = true]) {
            activeProdCodes.add(p.ProductCode);
        }

        for(Onboarding_Case_Setting__mdt obCaseSetting : Onboarding_Case_Setting__mdt.getAll().values()) {

            String productCode = obCaseSetting.Product_Code__c;
    
            // Check for invalid products/product codes
            if(!activeProdCodes.contains(productCode)) {
                System.debug('This Product Code is either invalid or is not an active product: '+productCode);
                continue;
            }
    
            if(!obCaseSetting.isActive__c) {
                System.debug('Inactive Onboarding Case Setting Metadata: '+obCaseSetting);
                continue;
            }
    
            // Create key = product code + country
            String productCountryKey = obCaseSetting.Product_Code__c + obCaseSetting.Country__c;
            obSettingsProductCodes.add(obCaseSetting.Product_Code__c);
            Date productDateCompare = (System.today().addDays(-obCaseSetting.Days_After_Activation__c.intValue()));
    
            if(!dateByProductCode.keySet().contains(productCountryKey)) {
                    dateByProductCode.put(productCountryKey, productDateCompare);
            }

            if(farthestLookbackDate > productDateCompare) {
                farthestLookbackDate = productDateCompare;
            }
        }

        // Go through Onboarding Case Tasks to create map of product code + country key to the onboarding case tasks custom metadata
        for(Onboarding_Case_Tasks__mdt obCaseTask : Onboarding_Case_Tasks__mdt.getAll().values()) {

            Onboarding_Case_Setting__mdt obCaseSetting = Onboarding_Case_Setting__mdt.getInstance(obCaseTask.Onboarding_Case_Setting__c);
            String settingProductCode = obCaseSetting.Product_Code__c;
            String settingCountryCode = obCaseSetting.Country__c;
            String productCountryKey = settingProductCode + settingCountryCode;

            if(!productToOnboardingCaseTasks.keySet().contains(productCountryKey)) {
                productToOnboardingCaseTasks.put(productCountryKey, new List<Onboarding_Case_Tasks__mdt>());
            }
            productToOnboardingCaseTasks.get(productCountryKey).add(obCaseTask);
        }

        // Go through Onboarding Case Fields custom metadata to create a map of product code + country key to case fields that need to be set
        for(Onboarding_Case_Fields__mdt obCaseField : Onboarding_Case_Fields__mdt.getAll().values()) {

            Onboarding_Case_Setting__mdt obCaseSetting = Onboarding_Case_Setting__mdt.getInstance(obCaseField.Onboarding_Case_Setting__c);
            String settingProductCode = obCaseSetting.Product_Code__c;
            String settingCountryCode = obCaseSetting.Country__c;
            String productCountryKey = settingProductCode + settingCountryCode;

            if(!productToCaseFields.keySet().contains(productCountryKey)) {
                productToCaseFields.put(productCountryKey, new List<Onboarding_Case_Fields__mdt>());
            }
            productToCaseFields.get(productCountryKey).add(obCaseField);
        }
    }

    public Map<Id, Case> getOnboardingCases(List<OrderItem> orderItems) {
        
        Map<Id,Case> onboardingCasesMap = new Map<Id,Case>();
        Set<Id> fulfillmentAccountIdList = new Set<Id>();
        Id onboardRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Onboarding').getRecordTypeId();
        
        for (OrderItem oi : orderItems) {
            fulfillmentAccountIdList.add(oi.Fulfillment_Account__c);
        }

        Map<Id,Account> fulfillmentAccountsMap = new Map<Id,Account>([
            SELECT Id, (SELECT Id, TeamMemberRole, UserId FROM AccountTeamMembers),  //BR-7814 Need to get Account Manager teamRole
            (SELECT Id, Order_Product__r.Product2.ProductCode, CountryCode__c, Reason FROM Cases WHERE IsClosed = false AND RecordTypeId = :onboardRecordTypeId) 
            FROM Account
            WHERE Id IN :fulfillmentAccountIdList
        ]);

        for (OrderItem oi : orderItems) {

            Boolean skipOrderItem = false;
            Account ffAcc = fulfillmentAccountsMap.get(oi.Fulfillment_Account__c);
            String oiProductCountryKey = oi.Product2.ProductCode + oi.Fulfillment_Account__r.BillingCountryCode;

            System.debug('current orderItem = '+oi);
            
            skipOrderItem = validateOrderItem(oi, ffAcc);

            if(skipOrderItem) {
                continue;
            }

            for(Onboarding_Case_Setting__mdt ocs : Onboarding_Case_Setting__mdt.getAll().values()) {

                String ocsProductCountryKey = (ocs.Product_Code__c + ocs.Country__c);
                Boolean productMatch = (oiProductCountryKey == ocsProductCountryKey);
                Boolean serviceDatesMatch = (oi.ServiceDate == dateByProductCode.get(oiProductCountryKey));

                if(productMatch && serviceDatesMatch) {

                    // Determine ownerId. Default owner to Fulfillment Account's Owner unless there is an AM/FAM account team member
                    Id ownerIdForUSonboardingCase = oi.Fulfillment_Account__r.OwnerId;

                    if(ffAcc.AccountTeamMembers != null) {
                        for(AccountTeamMember acc : ffAcc.AccountTeamMembers) {
                            if (acc.TeamMemberRole == 'Account Manager' || acc.TeamMemberRole == 'Field Account Manager') {
                                ownerIdForUSonboardingCase = acc.UserId;
                            }
                        }
                    }
    
                    if(!onboardingCasesMap.containsKey(oi.Fulfillment_Account__c)) {
                        
                        Case newCase = new Case();
                        newCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Onboarding').getRecordTypeId();
                        newCase.AccountId = oi.Fulfillment_Account__c;
                        newCase.OwnerId = ownerIdForUSonboardingCase;
                        newCase.ContactId = oi.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__PrimaryContact__c;
                        newCase.Order__c = oi.OrderId;
                        newCase.Order_Product__c = oi.Id;
                        newCase.Related_Quote__c = oi.Order.SBQQ__Quote__c;
                        newCase.Related_Opportunity__c = oi.SBQQ__QuoteLine__r.SBQQ__Quote__r.SBQQ__Opportunity2__c;
                        newCase.Priority = 'Medium';
                        newCase.Status = 'New';
                        newCase.Origin = 'Internal';

                        // Set fields defined under Onboarding_Case_Setting__mdt
                        if(productToCaseFields.size() > 0) {
                            for(Onboarding_Case_Fields__mdt fields : productToCaseFields.get(ocsProductCountryKey)) {
                                String fieldNameFormatted = fields.Object_Fields__c.remove(fields.Object__c + '.');
                                newCase.put(fieldNameFormatted, fields.Value__c);
                            }
                        }

                        onboardingCasesMap.put(oi.Fulfillment_Account__c, newCase);
                    }
                }
            }
        }
        return onboardingCasesMap;
    }

    public List<Task> getTasksByCaseIds(List<Id> cases) {

        List<Task> tasksToReturn = new List<Task>();

        for(Case caseRecord : [SELECT Id, OwnerId, Order_Product__c, Order_Product__r.Product2.ProductCode, CountryCode__c, CurrencyIsoCode 
                               FROM Case WHERE Id IN :cases]) {
            
            String countryCode = caseRecord.CountryCode__c;
            String productCode = caseRecord.Order_Product__r.Product2.ProductCode;
            String productKey = productCode + countryCode;
            
            if(!productToOnboardingCaseTasks.keySet().contains(productKey)) {
                continue;
            }

            for(Onboarding_Case_Tasks__mdt oct : productToOnboardingCaseTasks.get(productKey)) {

                Task newTask = new Task();
                newTask.Subject = oct.Subject__c;
                newTask.Status = 'Open';
                newTask.OwnerId = caseRecord.OwnerId;
                newTask.CurrencyIsoCode = caseRecord.CurrencyIsoCode;
                newTask.Priority = 'Normal';
                newTask.ActivityDate = System.today();
                newTask.WhatId = caseRecord.id;

                tasksToReturn.add(newTask);
            }
        }

        return tasksToReturn;
    }

    // Method to check if order item needs to be skipped or not
    private Boolean validateOrderItem(OrderItem oi, Account ffAcc) {

        String oiProductCountryKey = oi.Product2.ProductCode + oi.Fulfillment_Account__r.BillingCountryCode;
        Boolean skipOrderItem = false;

        if(oi.SBQQ__Status__c != 'Activated' || oi.Transaction_Type__c != 'New Business') {
            skipOrderItem = true;
        }
        
        // Check to see if there's any open onboarding cases by using the Order Product on the case and country of case
        if(ffAcc.Cases.size() > 0) {
            skipOrderItem = checkForExistingOnboardingCase(oiProductCountryKey, ffAcc.Cases);
        }

        return skipOrderItem;
    }

    public Boolean checkForExistingOnboardingCase(String orderItemProdCountryKey, List<Case> onboardingCases) {
        Boolean hasExistingOnboardCase = false;
        for(Case c : onboardingCases) {
            String caseProductCountryCodeKey = c.Order_Product__r.Product2.ProductCode + c.CountryCode__c;
            if(caseProductCountryCodeKey == orderItemProdCountryKey || c.Reason == 'Digital Deal: Onboarding') {
                hasExistingOnboardCase = true;
            }
        }
        return hasExistingOnboardCase;
    }
}

// https://cargurus.atlassian.net/browse/CRM-5021
// controller for CG_ManageAccountFeatures vf page
// test coverage in CG_FeatureFramework_Test
public class CG_ManageAccountFeatures_extension {

    public Account afAccount { get; private set; }
    Id accountId { get; private set; }
    Map<Integer,Map<Integer,CG_AccountFeatureMessageBody>> serviceProviderFeatureMap;
    
    //Test visible variables
    @TestVisible
    CG_AccountFeatureMap accountFeatures;

    @TestVisible    // map of feature id to account feature data, to allow displaying a table row with all relevant data
    Map<Integer,AccountFeatureComparision> accountFeatureComparisonMap;

    // inner class to represent all necessary data regarding a particular account feature
    public class AccountFeatureComparision {
        public CG_AccountFeature currentFeature { get; private set; }   // account feature (including if overridden)
        public CG_AccountFeature generatedFeature { get; private set; } // generated account feature
        public CG_AccountFeature cgFeature { get; private set; }    // feature as pulled from cg for related sp
        
        // variables used to store metadata strings as maps, including types for proper display / update
        public Map<String, String> generatedMetadataMap { get; set; }
        public Map<String, String> generatedTypeMap { get; set; }
        public Map<String, String> overrideableMetadataMap { get; set; }
        public Map<String, String> overrideTypeMap { get; set; }
        public Map<String, String> cgMetadataMap { get; set; }
        public Map<String, String> cgMetadataTypeMap { get; set; }

        // constructor takes source feature data (current, generated, pulled from cg) and country code (for metadata)
        public AccountFeatureComparision(CG_AccountFeature currentFeature, CG_AccountFeature generatedFeature, 
                CG_AccountFeature cgFeature, String countryCode) {
            
            this.currentFeature = currentFeature;
            this.generatedFeature = generatedFeature;
            this.cgFeature = cgFeature;
            setupOverrideMetadata(countryCode);
        }

        // use country code to get feature metadata setup data, used in determining metadata types for display / update
        public void setupOverrideMetadata(String countryCode) {
            System.debug(currentFeature.cgFeatureId);

            Map<String,Object> currentMDMap = currentFeature?.getFeatureMetadataMap();
            Map<String,Object> generatedMDMap = generatedFeature?.getFeatureMetadataMap();
            Map<String,Object> cgMDMap = cgFeature?.getFeatureMetadataMap();

            // get feature metadata setup data for current feature
            List<CG_Feature_Metadata__c> cgfmList = 
                CG_FeatureHelper.getFeatureMetadata(currentFeature.sfFeatureId, countryCode);

            // initialize metadata maps
            generatedTypeMap = new Map<String, String>();
            generatedMetadataMap = new Map<String, String>();
            overrideTypeMap = new Map<String, String>();
            overrideableMetadataMap = new Map<String, String>();
            cgMetadataMap = new Map<String, String>();
            cgMetadataTypeMap = new Map<String, String>();

            for (CG_Feature_Metadata__c cgfm : cgfmList) {
                String mdKey = cgfm.Key__c;

                // set up map for generated metadata for this feature (if available)
                if (generatedMDMap != null && generatedMDMap.containsKey(mdKey)) {
                    generatedTypeMap.put(mdKey, cgfm.Type__c);
                    generatedMetadataMap.put(mdKey, '');
                    
                    String generatedMdtString = (String)generatedMDMap.get(mdKey);
                    if (generatedMdtString == null) {
                        generatedMdtString = '';
                    }
                    generatedMetadataMap.put(mdKey, generatedMdtString);
                }

                // set up map for metadata pulled from cg for this feature (if available)
                if (cgMDMap != null && cgMDMap.containsKey(mdKey)) {
                    cgMetadataTypeMap.put(mdKey, cgfm.Type__c);
                    cgMetadataMap.put(mdKey, '');

                    String cgMdtString = String.valueOf(cgMDMap.get(mdKey));
                    if (cgMdtString == null) {
                        cgMdtString = '';
                    }
                    cgMetadataMap.put(mdKey, cgMdtString);
                }

                // if this is overridable metadata, setup values for current
                // if overridden, this will be the override
                // else, if there is a generated value, this will be that
                // else, it will be the value (if any) pulled from cg
                if(cgfm.Overrideable__c) {
                    overrideTypeMap.put(mdKey, cgfm.Type__c);
                    overrideableMetadataMap.put(mdKey, '');

                    if (currentMDMap != null && currentMDMap.containsKey(mdKey)) {
                        overrideableMetadataMap.put(mdKey, String.valueOf(currentMDMap.get(mdKey)));
                    } else if (cgMetadataMap != null && cgMetadataMap.containsKey(mdKey)) {
                        overrideableMetadataMap.put(mdKey, cgMetadataMap.get(mdKey));
                    } 
                }
            }
        }

        // this method is used solely to rerender the page element
        public Pagereference setEnableStatusOverride() {
            return null;
        }

        public Boolean getMetadataOverridable() {
            return !overrideTypeMap.isEmpty();
        }
    }
    
    // constructor sets up all account feature data
    public CG_ManageAccountFeatures_extension(ApexPages.StandardController stdController) {   
        this.accountId = System.currentPageReference().getParameters().get('id');

        this.accountFeatures = CG_AccountFeatureMapHelper.generateAccountFeaturesInstance(accountId);
        this.afAccount = accountFeatures.afAccount;

        Map<Integer,CG_AccountFeature> currentFeatureMap = accountFeatures.getCurrentFeatureMap();
        Map<Integer,CG_AccountFeature> generatedFeatureMap = accountFeatures.getGeneratedFeatureMap();
        Map<Integer, CG_AccountFeature> spFeatureMap = getServiceProviderFeatureMap(afAccount);
        accountFeatureComparisonMap = new Map<Integer,AccountFeatureComparision>();

        // go through each feature to populate account feature comparison map
        for (Integer i : generatedFeatureMap.keySet()) {
            accountFeatureComparisonMap.put(i, 
                new AccountFeatureComparision(currentFeatureMap.get(i), generatedFeatureMap.get(i), 
                    spFeatureMap.get(i), afAccount.BillingCountryCode)
            );
        }
    }

    // get a map of cg features for the account, drawing from the first active service provider
    static Map<Integer,CG_AccountFeature> getServiceProviderFeatureMap(Account a) {

        Map<Integer,Map<Integer,CG_AccountFeature>> relSPFeatureMap = 
            CG_FeatureIntegrationHelper.getCGFeaturesForAccountId(a.Id);
        
        if (!relSPFeatureMap.isEmpty()) {
            return relSPFeatureMap.values()[0];
        }

        return new Map<Integer,CG_AccountFeature>();
    }

    // return list of all feature data (generated vs. overridden), sorted by feature id
    public List<AccountFeatureComparision> getSortedFeatureComparisonList() {
        List<AccountFeatureComparision> sortedFeatureComparisions = new List<AccountFeatureComparision>();

        List<Integer> featureIdList = new List<Integer>(accountFeatureComparisonMap.keySet());
        featureIdList.sort();

        for (Integer featureId : featureIdList) {
            sortedFeatureComparisions.add(accountFeatureComparisonMap.get(featureId));
        }

        return sortedFeatureComparisions;
    }

    public List<CG_AccountFeature> getCurrentFeatureList() {
        return accountFeatures.getSortedCurrentFeatureList();
    }

    public List<CG_AccountFeature> getGeneratedFeatureList() {
        return accountFeatures.getSortedGeneratedFeatureList();
    }

    // save any configured feature overrides (status and / or metadata)
    public Pagereference saveOverrides() {

        List<CG_Account_Feature__c> overridesToSave = new List<CG_Account_Feature__c>();
        List<CG_Account_Feature__c> overridesToDelete = new List<CG_Account_Feature__c>();
        
        for (Integer i : accountFeatureComparisonMap.keySet()) {
            AccountFeatureComparision afc = accountFeatureComparisonMap.get(i);
            CG_AccountFeature currentFeature = afc.currentFeature;
            Id overrideRecordId = currentFeature.overrideRecordId;

            // set up account feature record with existing id or null id (for upsert)
            CG_Account_Feature__c cgaf = new CG_Account_Feature__c(
                Id = overrideRecordId,
                Account__c = accountId,
                CG_Feature__c = currentFeature.sfFeatureId,
                Name = currentFeature.featureName
            );
            
            // if this feature is not overridden, skip, adding any existing record id for removal
            if(!currentFeature.statusOverride && !currentFeature.metadataOverride) {
                if(overrideRecordId != null) {
                    overridesToDelete.add(cgaf);  
                }        
                continue;
            }

            CG_AccountFeature generatedFeature = afc.generatedFeature;
            
            System.debug(overrideRecordId+'----'+currentFeature.cgFeatureId+'---'+
                currentFeature.statusOverride+'---'+currentFeature.metadataOverride);
        
            cgaf.Metadata_Override__c = currentFeature.metadataOverride;
            cgaf.Status_Override__c = currentFeature.statusOverride;

            // if metadata is overridden, save override value, else save generated value
            if (currentFeature.metadataOverride) {
                cgaf.Metadata__c = JSON.serialize(afc.overrideableMetadataMap);  
            } else if (overrideRecordId != null) {
                cgaf.Metadata__c = generatedFeature.featureMetadataString;
            }

            // if status is overridden, save override value, else save generated value
            if (currentFeature.statusOverride && 
                    (currentFeature.featureStatus != generatedFeature.featureStatus)) {
                cgaf.Status__c = currentFeature.featureStatus;
            } else if (overrideRecordId != null) {
                cgaf.Status__c = generatedFeature.featureStatus;
            }

            // add record to upsert list
            overridesToSave.add(cgaf);          
        }

        if (!overridesToSave.isEmpty()) {
            upsert overridesToSave;
        }

        if (!overridesToDelete.isEmpty()) {
            delete overridesToDelete;
        }

        // set page reference to reload after update
        PageReference fcPage = new Pagereference('/apex/CG_ManageAccountFeatures?id='+accountId);        
        fcPage.setRedirect(true);
        return fcPage;
    }

    // for save and send button, first update override data, then push to cg
    public Pagereference saveAndSend() {
        saveOverrides();
        CG_AccountFeatureMessageHelper.generateAccountFeatureMessages(accountId);

        return new Pagereference('/'+accountId);
    }
}
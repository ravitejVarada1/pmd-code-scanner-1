// https://cargurus.atlassian.net/browse/CRM-4804
// class to create an instance of a collection of account features data
// test coverage in CG_FeatureFramework_Test
public class CG_AccountFeatureMap {

    // map of cg feature id to cg feature salesforce record id
    static final Map<Integer,Id> FEATURE_CGSFID_MAP = CG_FeatureHelper.getFeatureCGIdSFIdMap();
    static final String FEATURE_STATUS_ACTIVE = CG_FeatureHelper.FEATURE_STATUS_ACTIVE;
    static final String FEATURE_STATUS_INACTIVE = CG_FeatureHelper.FEATURE_STATUS_INACTIVE;

    public Account afAccount { get; private set; }

    //  map of features for this account based on product activation status
    Map<Integer,CG_AccountFeature> statusFeatureMap = new Map<Integer,CG_AccountFeature>();

    // map of features for this account based on active and pending (for metadata) cpq subscriptions
    Map<Integer,CG_AccountFeature> productFeatureMap = new Map<Integer,CG_AccountFeature>();

    // map of overridden features for this account
    Map<Integer,CG_AccountFeature> overrideFeatureMap = new Map<Integer,CG_AccountFeature>();

    // constructor takes an account and sets up maps for overridden and generated features
    public CG_AccountFeatureMap(Account a) {
        this.afAccount = a;
        updateFeatureMaps();
    }

    // instance method recalculates maps for status-based, generated (from cpq subs), and overridden features
    public void updateFeatureMaps() {

        // get all status features for this account
        statusFeatureMap.putAll(CG_AccountFeatureMapHelper.getAccountFeatureForStatusMap(afAccount));

        // get all overridden features for this account
        overrideFeatureMap.putAll(setupCGAccountFeatureInstanceMap(afAccount.CG_Account_Features__r));

        // get all features tied to active or pending (for metadata) cpq subscriptions for this account
        for (SBQQ__Subscription__c cpqSub : afAccount.CPQ_Subscriptions_Fulfillment__r) {
            // pass the features already generated based on processed cpq subs
            // subs are sorted based on status and amount, generate metadata based on the first in order
            // passing the existing features allows us to skip if already set
            productFeatureMap.putAll(
                CG_AccountFeatureMapHelper.getAccountFeaturesForCPQSubMap(afAccount, cpqSub, 
                    productFeatureMap.keySet())
            );
        }
    }

    // returns map of overridden features for this account
    public Map<Integer,CG_AccountFeature> getOverrideFeatureMap() {
        return overrideFeatureMap;
    }

    // returns map of generated (from cpq subs) plus default features for this account
    public Map<Integer,CG_AccountFeature> getGeneratedFeatureMap() {
        return getAccountFeatureMap(false);
    }

    // returns a map of current features for this account, based on combination of overridden, default, and generated
    public Map<Integer,CG_AccountFeature> getCurrentFeatureMap() {
        return getAccountFeatureMap(true);
    }

    // get a list of current features, sorted by cg feature id
    public List<CG_AccountFeature> getSortedGeneratedFeatureList() {
        return getSortedFeatureList(getGeneratedFeatureMap());
    }

    // get a list of current features, sorted by cg feature id
    public List<CG_AccountFeature> getSortedCurrentFeatureList() {
        return getSortedFeatureList(getCurrentFeatureMap());
    }

    // get a set of current active feature cg ids
    public Set<Integer> getCurrentActiveFeatureCGIds() {
        Set<Integer> returnSet = new Set<Integer>();

        Map<Integer,CG_AccountFeature> currentFeatureMap = getCurrentFeatureMap();

        for (Integer cgFeatureId : getCurrentFeatureMap().keySet()) {
            if (currentFeatureMap.get(cgFeatureId).featureStatus == FEATURE_STATUS_ACTIVE) {
                returnSet.add(cgFeatureId);
            }
        }

        return returnSet;
    }

    // return features from supplied map, sorted by cg feature id
    static List<CG_AccountFeature> getSortedFeatureList(Map<Integer,CG_AccountFeature> featureMap) {
        List<CG_AccountFeature> sortedFeatures = new List<CG_AccountFeature>();

        List<Integer> featureIdList = new List<Integer>(featureMap.keySet());
        featureIdList.sort();

        for (Integer featureId : featureIdList) {
            sortedFeatures.add(featureMap.get(featureId));
        }

        return sortedFeatures;
    }

    // returns map of features for this account, including or excluding overridden based on passed boolean
    Map<Integer,CG_AccountFeature> getAccountFeatureMap(Boolean includeOverrides) {
        Map<Integer,CG_AccountFeature> accountFeatureMap = new Map<Integer,CG_AccountFeature>();

        for (Integer cgFeatureId : FEATURE_CGSFID_MAP.keySet()) {
            accountFeatureMap.put(cgFeatureId, getAccountFeature(includeOverrides, cgFeatureId));
        }

        return accountFeatureMap;
    }

    // get the status for the current account feature, optionally from override if there is one
    CG_AccountFeature getAccountFeature(Boolean includeOverrides, Integer cgFeatureId) {
        CG_AccountFeature af;

        // if we want the override and there is one, return that
        if (includeOverrides && overrideFeatureMap.containsKey(cgFeatureId)) {
            af = overrideFeatureMap.get(cgFeatureId);

            // the override could be for the status or metadata or both
            // if the status or metadata are not overridden, pull the value from the generated feature
            CG_AccountFeature generatedAccountFeature = getAccountFeature(false, cgFeatureId);
            if (!af.statusOverride) {
                af.setFeatureStatus(generatedAccountFeature.featureStatus);
            }
            if (!af.metadataOverride) {
                af.setFeatureMetadataString(generatedAccountFeature.featureMetadataString);
            }
        }   // if no override, or skipping overrides, check for feature derived from cpq subscriptions
        else if (productFeatureMap.containsKey(cgFeatureId)) {
            af = productFeatureMap.get(cgFeatureId);

            // we could be looking at a subscription feature evaluated for metadata on a pending account
            // if so, get the feature status from the product activation status feature
            if (statusFeatureMap.containsKey(cgFeatureId)) {
                af.setFeatureStatus(statusFeatureMap.get(cgFeatureId).featureStatus);
            }
        }   // if no override and no cpq sub for this feature, check for product activation status feature
        else if (statusFeatureMap.containsKey(cgFeatureId)) {
            af = statusFeatureMap.get(cgFeatureId);
        } else { // if none of the above, generate a default inactive feature, including default metadata
            af = new CG_AccountFeature(FEATURE_CGSFID_MAP.get(cgFeatureId), afAccount, FEATURE_STATUS_INACTIVE);
        }

        return af;
    }

    // handy static method to take a list of feature instances and arrange them in a map by cg feature id
    static Map<Integer,CG_AccountFeature> setupCGAccountFeatureInstanceMap(List<CG_Account_Feature__c> cgafList) {
        Map<Integer,CG_AccountFeature> afReturnMap = new Map<Integer,CG_AccountFeature>();

        Map<Id,CG_Feature__c> featureSFIdMap = CG_FeatureHelper.getFeatureSFIdMap();

        for (CG_Account_Feature__c cgaf : cgafList) {
            CG_AccountFeature af = new CG_AccountFeature(cgaf);
            afReturnMap.put(af.cgFeatureId, af);
        }

        return afReturnMap;
    }
    
}
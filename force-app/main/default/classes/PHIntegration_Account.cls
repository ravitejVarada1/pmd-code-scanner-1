/**
 * @author  Adam LaPlante
 * @date    12/23/21
 * @module  BR-3884
 */

public class PHIntegration_Account {

    /**
     * Global Vars
     */

    // variable to JSON body map
    static final Map<String,String> JSONKEYREPLACEMAP = new Map<String,String>{
        'useAdvertLimit' => 'UseAdvertLimit',
        'advertLimit' => 'AdvertLimit',
        'name' => 'BusinessName',
        'spid' => 'SPID',
        'isFeatured' => 'IsFeatured',
        'isFranchise' => 'IsFranchise',
        'address' => 'Address',
        'city' => 'City',
        'postCode' => 'Postcode',
        'countryCode' => 'CountryCode',
        'website' => 'WebsiteAddress',
        'phone' => 'PhoneNumber',
        'dealerId' => 'DealerId',
        'accountStatus' => 'AccountStatus',
        'expiryDate' => 'ExpiryDate',
        'contactEmailAddress' => 'ContactEmailAddress',
        'productId' => 'ProductId'
    };

    // variables to construct JSON body, cast all as string for simplicity
    String useAdvertLimit;
    String advertLimit;
    String name;
    String spid;
    String isFeatured;
    String isFranchise;
    String address;
    String city;
    String postCode;
    String countryCode;
    String website;
    String phone;
    String dealerId;
    String accountStatus;
    String expiryDate;
    String contactEmailAddress;
    String productId;

    /**
     * Constructor for PHIntegration_Account message w/ quote
     */

    public PHIntegration_Account(Account a, SBQQ__Quote__c q, Set<String> phProductCodes) {
        this.advertLimit = String.valueOf(getAdvertLimit(q));
        // if an advertLimit is set, then true, else false
        this.useAdvertLimit = String.valueOf(advertLimit != '' ? 'true' : 'false');
        this.name = String.ValueOf(a.Name);
        // if a service provider is found, then grab spid, else null
        this.spid = String.ValueOf(
            !a.Service_Provider__r.isEmpty() ? String.ValueOf(a.Service_Provider__r[0].Service_Provider_Id__c) : ''
        );
        this.isFeatured = String.ValueOf(isFeatured(q, phProductCodes));
        this.productId = String.ValueOf(getProductId(q, phProductCodes));
        this.isFranchise = String.ValueOf(isFranchise(a));
        this.address = String.ValueOf(a.BillingStreet);
        this.city = String.ValueOf(a.BillingCity);
        this.postCode = String.ValueOf(a.BillingPostalCode) ;
        this.countryCode = String.ValueOf(a.BillingCountryCode);
        this.website = String.ValueOf(a.Website);
        this.phone = String.ValueOf(a.Phone);
        this.contactEmailAddress = q.SBQQ__PrimaryContact__r.Email;
    }

    /**
     * Constructor for PHIntegration_Account message w/ activateAccount boolean
     */
     
    public PHIntegration_Account(Account a, Boolean activateAccount, Boolean isFeatured) {
        this.dealerId = String.valueOf(a.PH_Admin_Centre_Id__c);
        this.accountStatus = String.valueOf(activateAccount == true ? 'Open' : 'Expired');
        this.expiryDate = String.valueOf(activateAccount == true ? null : '');
        this.isFeatured = String.valueOf(isFeatured);
    }

    /**
     * For supplied quote ids,  create PH account messages for accounts that need creating in PH
     */

    public static String serializeJSON(Account a, SBQQ__Quote__c q, Set<String> phProductCodes) {
        // initialize new PHIntegration_Account instance with Account a
        PHIntegration_Account phia = new PHIntegration_Account(a, q, phProductCodes);

        // serialize JSON using PH account
        String jsonString = JSON.serializePretty(phia, true);

        // loop through JSON key replacing keys via the JSONKEYREPLACEMAP
        for (String replaceKey : JSONKEYREPLACEMAP.keySet()) {
            jsonString = jsonString.replaceAll('"'+replaceKey+'"', '"'+JSONKEYREPLACEMAP.get(replaceKey)+'"');
        }
        return jsonString;
    }

    /**
     * For supplied account ids, create PH account messages for accounts that need creating in PH
     */

    public static String serializeJSON(Account a, Boolean activateAccount, Boolean isFeatured) {
        // initialize new PHIntegration_Account instance with Account a
        PHIntegration_Account phia = new PHIntegration_Account(a, activateAccount, isFeatured);

        // serialize JSON using PH account
        String jsonString = JSON.serializePretty(phia, true);

        // loop through JSON key replacing keys via the JSONKEYREPLACEMAP
        for (String replaceKey : JSONKEYREPLACEMAP.keySet()) {
            jsonString = jsonString.replaceAll('"'+replaceKey+'"', '"'+JSONKEYREPLACEMAP.get(replaceKey)+'"');
        }
        return jsonString;
    }

    /**
     * Checks if account category contains franchise
     */

    public static Boolean isFranchise(Account a) {
        return a.Account_Category_Formula__c.contains('Franchise') ? true : false;
    }

    /**
     * Checks if product contains featured
     */

    public static Boolean isFeatured(SBQQ__Quote__c q, Set<String> phProductCodes) {   
        // if quote lines are present
        if (!q.SBQQ__LineItems__r.isEmpty()){
            // loop through quote lines
            for (SBQQ__QuoteLine__c ql : q.SBQQ__LineItems__r) {
                // check against constant containing PH featured product codes
                if (phProductCodes.contains(ql.SBQQ__ProductCode__c) && ql.SBQQ__ProductCode__c.contains('FEAT')) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Gets advert limit based on used inventory cap
     */

    public static String getAdvertLimit(SBQQ__Quote__c q) {   
        // if quote lines are present
        if (!q.SBQQ__LineItems__r.isEmpty()){
            // loop through quote lines
            for (SBQQ__QuoteLine__c ql : q.SBQQ__LineItems__r) {
                // check against constant containing PH featured product codes
                if (ql.Used_Inventory_Cap__c != null && ql.Used_Inventory_Cap__c > 0) {
                    return String.valueOf(ql.Used_Inventory_Cap__c);
                }

            }
        }
        return '';
    }

    /**
     * Checks if product contains featured
     */

    public static Id getProductId(SBQQ__Quote__c q, Set<String> phProductCodes) {   
        // if quote lines are present
        if (!q.SBQQ__LineItems__r.isEmpty()){
            // loop through quote lines
            for (SBQQ__QuoteLine__c ql : q.SBQQ__LineItems__r) {
                // check against constant containing PH featured product codes
                if (phProductCodes.contains(ql.SBQQ__ProductCode__c)) {
                    return ql.SBQQ__Product__c;
                }
            }
        }
        return null;
    }

}

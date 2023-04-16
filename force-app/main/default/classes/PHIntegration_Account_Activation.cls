/**
 * @author  Adam LaPlante
 * @date    06/15/22
 * @module  BR-8928
 */

public class PHIntegration_Account_Activation {

    /**
     * Global Vars
     */

    // variable to JSON body map
    static final Map<String,String> JSONKEYREPLACEMAP = new Map<String,String>{
        'isFeatured' => 'IsFeatured',
        'dealerId' => 'DealerId',
        'accountStatus' => 'AccountStatus',
        'expiryDate' => 'ExpiryDate',
        'productId' => 'ProductId'
    };

    // variables to construct JSON body, cast all as string for simplicity
    String isFeatured;
    String dealerId;
    String accountStatus;
    String expiryDate;
    String productId;

    /**
     * Constructor for PHIntegration_Account message w/ activateAccount boolean
     */
    public PHIntegration_Account_Activation(Account a, Id productId, Boolean activateAccount, Boolean isFeatured) {
        this.dealerId = String.valueOf(a.PH_Admin_Centre_Id__c);
        this.accountStatus = String.valueOf(activateAccount == true ? 'Open' : 'Expired');
        this.expiryDate = activateAccount ? null : date.today().format();
        this.isFeatured = String.valueOf(isFeatured);
        this.productId = String.valueOf(productId);
    }

    /**
     * For supplied account ids, create PH account messages for accounts that need creating in PH
     */

    public static String serializeJSON(Account a, Id productId, Boolean activateAccount, Boolean isFeatured) {
        // initialize new PHIntegration_Account instance with Account a
        PHIntegration_Account_Activation phia = new PHIntegration_Account_Activation(a, productId, activateAccount, isFeatured);

        // serialize JSON using PH account
        String jsonString = JSON.serializePretty(phia, false);

        // loop through JSON key replacing keys via the JSONKEYREPLACEMAP
        for (String replaceKey : JSONKEYREPLACEMAP.keySet()) {
            jsonString = jsonString.replaceAll('"'+replaceKey+'"', '"'+JSONKEYREPLACEMAP.get(replaceKey)+'"');
        }

        return jsonString;
    }

}

// https://cargurus.atlassian.net/browse/BR-1144
// this class represents the zuora account json structure used in the integration message that creates the account
public class ZuoraIntegration_Account {

    // some zuora keys can't be set as variable names, so map them for post-serialization replacement
    static final Map<String,String> JSONKEYREPLACEMAP = new Map<String,String>{
        'zuoraId' => 'account-key',
        'xcurrencyx' => 'currency',
        'accountCategory' => 'Account_Category_Formula__c',
        'billToCountry' => 'SalesforceBillToCountry__c',
        'billToState' => 'SalesforceBillToState__c',
        'vatId' => 'VAT_Id__c',
        'preferredLanguage' => 'PreferredLanguage__c',
        'parentZuoraId' => 'parentId',
        'dealerId' => 'DealerID__c',
        'serviceProviderId' => 'ServiceProviderID__c',
        'accountOwner' => 'AccountOwner__c',
        'accountOwnerEmail' => 'AccountOwnerEmail__c',
        'fieldGroupType' => 'Field_Group_Type__c',
        'enrollmentDate' => 'Enrollment_Date__c',
        'externalDealerID' => 'External_Dealer_ID__c',
        'division' => 'Division__c',
        'iMRFunds' => 'iMR_funds__c',
        'coOpProgramOptIn' => 'Co_Op_Program_Opt_In__c'

    };

    String name;
    String crmId;
    String xcurrencyx;
    String hpmCreditCardPaymentMethodId;
    ZContact billToContact;
    ZContact soldToContact;

    // default values
    Boolean invoiceDeliveryPrefsPrint = false;
    Boolean invoiceDeliveryPrefsEmail = false;
    Integer billCycleDay = 1;
    Boolean autoPay = false;

    // custom fields
    String accountCategory;
    String billToCountry;
    String billToState;
    String vatId;
    String preferredLanguage;
    String zuoraId;
    String parentZuoraId;
    String dealerId;
    String serviceProviderId;
    String accountOwner;
    String accountOwnerEmail;
    String fieldGroupType;

    //UK Specific Invoice templates
    String invoiceTemplateId;
    String debitMemoTemplateId;
    String creditMemoTemplateId;

    //OEM Billing Related Fields
    Date enrollmentDate;
    String externalDealerID;
    String division;
    String iMRFunds;
    String coOpProgramOptIn;

    // constuctor takes account and quote
    public ZuoraIntegration_Account(Account a, SBQQ__Quote__c q) {
        this.name = a.Name;
        this.crmId = a.Id;
        this.xcurrencyx = a.CurrencyISOCode;
        this.accountCategory = a.Account_Category_Formula__c;
        this.billToCountry = a.BillingCountryCode;
        this.billToState = a.BillingStateCode;
        this.vatId = a.VAT_Id__c;
        this.preferredLanguage = a.Preferred_Language__c != null ? mapLanguage(a.Preferred_Language__c) : a.Preferred_Language__c;
        this.accountOwner = a.Owner.Name;
        this.accountOwnerEmail = a.Owner.Email;
        this.fieldGroupType = a.Field_Group_Type__c;

        //OEM Billing Related mapping
        this.enrollmentDate = a.Enrollment_Date__c;
        this.externalDealerID = a.External_Dealer_ID__c;
        this.division = a.Division__c;
        this.iMRFunds = a.iMR_funds__c;
        this.coOpProgramOptIn = a.Co_Op_Program_Opt_In__c;

        // zuora payment method ids are stored in custom metadata
        this.hpmCreditCardPaymentMethodId = getZuoraPaymentMethodId(q.Payment_Method__c);

        // bill to contact uses contact info on account in billing contact fields
        this.billToContact = new ZContact(a);

        // sold to contact uses primary contact on quote for contact info
        this.soldToContact = new ZContact(a, q);

        //invoice, debit, credit memo template ids
        this.invoiceTemplateId = getZuoraTemplateId('invoiceTemplateId', a.BillingCountryCode);
        this.debitMemoTemplateId = getZuoraTemplateId('debitMemoTemplateId', a.BillingCountryCode);
        this.creditMemoTemplateId = getZuoraTemplateId('creditMemoTemplateId', a.BillingCountryCode);
    }

    // consrtuctor takes account - BR-1492
    public ZuoraIntegration_Account(Account a) {
        this.name = a.Name;
        this.crmId = a.Id;
        this.accountCategory = a.Account_Category_Formula__c;
        this.billToCountry = a.BillingCountryCode;
        this.billToState = a.BillingStateCode;
        this.vatId = a.VAT_Id__c;
        this.preferredLanguage = a.Preferred_Language__c != null ? mapLanguage(a.Preferred_Language__c) : a.Preferred_Language__c;
        this.zuoraId =  a.Billing_Account_Zuora__r.Zuora__Zuora_Id__c;
        this.parentZuoraId = a.Parent.Billing_Account_Zuora__r.Zuora__Zuora_Id__c;
        this.dealerId = a.Dealer_ID__c;
        this.serviceProviderId = a.Service_Provider__r.size() > 0 ? String.valueOf(a.Service_Provider__r[0].Service_Provider_Id__c) : null;
        this.accountOwner = a.Owner.Name;
        this.accountOwnerEmail = a.Owner.Email;
        this.fieldGroupType = a.Field_Group_Type__c;

        //OEM Billing Related mapping
        this.enrollmentDate = a.Enrollment_Date__c;
        this.externalDealerID = a.External_Dealer_ID__c;
        this.division = a.Division__c;
        this.iMRFunds = a.iMR_funds__c;
        this.coOpProgramOptIn = a.Co_Op_Program_Opt_In__c;

        // bill to contact uses contact info on account in billing contact fields
        this.billToContact = new ZContact(a);
    }

    // inner class represents contact object structure for serialization within account object
    class ZContact {
        String firstName;
        String lastName;
        String workEmail;
        String address1;
        String city;
        String state;
        String zipCode;
        String country;

        // constuctor for bill to contact takes account only
        public ZContact(Account a) {
            this.firstName = a.System_BillingContactFirst__c;
            this.lastName = a.System_BillingContactLast__c;
            this.workEmail = a.System_BillingContactEmail__c;
            this.address1 = a.BillingStreet == null ? null : a.BillingStreet.left(30);
            this.city = a.BillingCity;
            this.state = a.BillingStateCode;
            this.zipCode = a.BillingPostalCode;
            this.country = a.BillingCountryCode; 
        }

        // constructor for sold to account takes account and quote
        public ZContact(Account a, SBQQ__Quote__c q) {
            this.firstName = q.SBQQ__PrimaryContact__r.FirstName;
            this.lastName = q.SBQQ__PrimaryContact__r.LastName;
            this.workEmail = q.SBQQ__PrimaryContact__r.Email;
            this.address1 = a.BillingStreet == null ? null : a.BillingStreet.left(30);
            this.city = a.BillingCity;
            this.state = a.BillingStateCode;
            this.zipCode = a.BillingPostalCode;
            this.country = a.BillingCountryCode;
        }
    }

    // serialize zuora account based on supplied account and quote, replacing keys according to map at top of class
    public static String serializeJSON(Account a, SBQQ__Quote__c q) {
        String jsonString = JSON.serializePretty(new ZuoraIntegration_Account(a, q), true);

        for (String replaceKey : JSONKEYREPLACEMAP.keySet()) {
            jsonString = jsonString.replaceAll('"'+replaceKey+'"', '"'+JSONKEYREPLACEMAP.get(replaceKey)+'"');
        }
        return jsonString;
    }


    // serialize zuora account based on supplied account and quote, replacing keys according to map at top of class
    public static String serializeJSON(Account a) {
        ZuoraIntegration_Account zia = new ZuoraIntegration_Account(a);

        // null out certain parameters so they don't get sent along in update messages
        zia.billCycleDay = null;
        zia.autoPay = null; 
        zia.invoiceDeliveryPrefsEmail = null;
        zia.invoiceDeliveryPrefsEmail = null;
        zia.accountCategory = null;

        
        String jsonString = JSON.serializePretty(zia, true);

        for (String replaceKey : JSONKEYREPLACEMAP.keySet()) {
            jsonString = jsonString.replaceAll('"'+replaceKey+'"', '"'+JSONKEYREPLACEMAP.get(replaceKey)+'"');
        }
        return jsonString;
    }

    // pull payment method ids from custom metadata
    static final Map<String,String> ZUORA_PAYMENTMETHODIDMAP = new Map<String,String>{
        'ACH' => Integrations.INTEGRATION_CONTROLS.Zuora_Payment_Method_Id_ACH__c,
        'Bank Transfer' => Integrations.INTEGRATION_CONTROLS.Zuora_Payment_Method_Id_Bank_Transfer__c,
        'Check' => Integrations.INTEGRATION_CONTROLS.Zuora_Payment_Method_Id_Check__c,
        'Credit Card' => Integrations.INTEGRATION_CONTROLS.Zuora_Payment_Method_Id_Credit_Card__c
    };

    // pull template ids from custom metadata, at this time applies only to GB
    static final Map<String, Map<String,String>> ZUORA_TEMPLATEIDS = new Map<String, Map<String,String>>{
        'GB' => new Map<String, String>{
            'invoiceTemplateId' => Integrations.INTEGRATION_CONTROLS.GB_Invoice_Template_Id__c,
            'debitMemoTemplateId' => Integrations.INTEGRATION_CONTROLS.GB_Debit_Memo_Template_Id__c,
            'creditMemoTemplateId' => Integrations.INTEGRATION_CONTROLS.GB_Credit_Memo_Template_Id__c
        }
    };

    //return template ids for supplied template type and billing country code
    //At present applies only to UK, extend if this ever applies to other geographies
    static String getZuoraTemplateId(String templateType, String billingCountryCode) {
        if (ZUORA_TEMPLATEIDS.containsKey(billingCountryCode)) {
            if(ZUORA_TEMPLATEIDS.get(billingCountryCode).containsKey(templateType)) {
                return ZUORA_TEMPLATEIDS.get(billingCountryCode).get(templateType);
            }
        }
        return null;
    }

    // return payment method id for supplied payment method
    static String getZuoraPaymentMethodId(String quotePaymentMethod) {
        if (ZUORA_PAYMENTMETHODIDMAP.containsKey(quotePaymentMethod)) {
            return ZUORA_PAYMENTMETHODIDMAP.get(quotePaymentMethod);
        }
        return ZUORA_PAYMENTMETHODIDMAP.get('Check');
    }

    // maps Salesforce language values to Zuora language values
    private static String mapLanguage(String preferredLanguage) {
        return preferredLanguage == 'English' ? 'EN' : 'FR'; 
    }

}

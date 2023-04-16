  
public class ConstantsUtil {
    
    // General Constants
    public static final Set<String> COUNTRIES_SOLD = new Set<String>{'US','CA','GB'};
        
    //cpq quote constants
    public static final Date STANDARD_QUOTE_EXPIRATION = System.today().toStartOfMonth().addMonths(1).addDays(9);
    
    // record type developer names
    public static final String RT_ACCOUNT_DEALER = 'Dealer_Account';
    public static final String RT_CASE_DATACORRECTION = 'Data_Correction';
    
    // account constants
    public static final String ACCOUNT_PRODUCTACTIVATIONSTATUS_ACTIVE = 'Active';
    public static final String ACCOUNT_PRODUCTACTIVATIONSTATUS_CANCELING57DAYS = 'Canceling – 57 days';
    public static final String ACCOUNT_PRODUCTACTIVATIONSTATUS_RESTRICTEDACTIVATED = 'Restricted – Activated';
    public static final String ACCOUNT_PRODUCTACTIVATIONSTATUS_BLOCKED = 'Blocked';
    public static final String ACCOUNT_PRODUCTACTIVATIONSTATUS_TRIAL = 'Trial';
    public static final String ACCOUNT_STATUS_ACTIVE = 'Active';
    public static final String ACCOUNT_STATUS_INACTIVE = 'Inactive';
    public static final String ACCOUNT_STATUS_PENDING = 'Pending';
    
    // cpq subscription constants
    public static final String SUBSCRIPTION_BILLINGSTATUS_PAYING = 'Paying';
    public static final String SUBSCRIPTION_BILLINGSTATUS_NONPAYING = 'Non Paying';
    public static final String SUBSCRIPTION_PROVISIONINGSTATUS_ACTIVE = 'Activated';
    public static final String SUBSCRIPTION_PROVISIONINGSTATUS_INACTIVE = 'De-activated';
    public static final String SUBSCRIPTION_PROVISIONINGSTATUS_PENDING = 'Pending Activation';
    public static final String SUBSCRIPTION_PROVISIONINGSTATUS_DELINQUENT = 'Delinquent';
    
    // service provider constants
    public static final String SP_APPROVED = 'APPROVED';
    public static final String SP_SUBMITTED = 'SUBMITTED';

    // contract status constants
    public static final String CONTRACT_STATUS_ACTIVE = 'Activated';
    public static final String CONTRACT_STATUS_PENDING = 'Pending Activation';
    public static final String CONTRACT_STATUS_CANCELLED = 'Cancelled';
    
    // cpq quote constants
    public static final String QUOTE_STATUS_APPROVED = 'Approved';
    public static final String QUOTE_STATUS_ORDER_GENERATED = 'Order Generated';
    public static final String QUOTE_APPROVALSTATUS_APPROVED = 'Approved';
    public static final String QUOTE_TYPE_AMENDMENT = 'Amendment';
    public static final String QUOTE_TYPE_RENEWAL = 'Renewal';
    public static final String QUOTE_TYPE_CANCELLATION = 'Cancellation';
    public static final String QUOTE_TYPE_TRIAL = 'Trial';
    
    // opportunity constants
    public static final String OPP_STATUS_CLOSED_WON = 'Closed Won';
    public static final String OPP_STATUS_CLOSED_SAVED = 'Closed Saved';
    public static final String OPP_STATUS_CLOSED_LOST = 'Closed Lost';
    
    // activation status constants
    public static final String ACTIVATION_STATUS_PENDING = 'Pending';
    public static final String ACTIVATION_STATUS_COMPLETE = 'Complete';
    public static final String ACTIVATION_STATUS_ERROR = 'Error';
    public static final String ACTIVATION_STATUS_NA = 'N/A';

    // product constants
    public static final String PRODUCT_FAMILY_LISTINGS = 'Listings';
    public static final String PRODUCT_FAMILY_WEBSITE_AND_INVENTORY = 'Website & Inventory';
    public static final String PRODUCT_FAMILY_DATA = 'Data';
    public static final String PRODUCT_DIGITAL_ADVERTISING = 'Digital Advertising';
    public static final String PRODUCT_DIGITAL_RETAIL = 'Digital Retail';
    public static final String PRODUCT_PISTONHEADS = 'PistonHeads';
    public static final String PRODUCT_CATEGORY_CORE = 'Core Products';
    public static final String PRODUCT_CATEGORY_ADDON = 'Add on Services';
    public static final String PRODUCT_SUBCATEGORY_DISPLAY = 'Display_Focus';
    public static final String PRODUCT_PRODUCTCODE_CGBASE = 'CG-BASE';
  
    // profile constants
    public static final String SALES_OPS = 'Sales Ops';
    public static final String SYSTEM_ADMIN = 'System Administrator';
    public static final String ACCOUNTING = 'Accounting';


    // invoice constants
    public static final Integer INVOICE_DAYS_UNTIL_DELINQUENCY = 30;
    public static final Integer INVOICE_DAYS_UNTIL_PRE_DELINQUENCY = 25;

    //User Role constants
    public static final String CA_SALES = 'CA_Dealer_Account_Executives';
    public static final String CA_SALES_MANAGER = 'CA_Manager_Sales_Acquisitions';
    public static final String US_ROLE_INDEP_SMALL_MANAGER = 'US_Independent_Small_Manager';
    public static final String US_ROLE_INDEP_SMALL_REP = 'US_Independent_Small_Rep';
    public static final String GB_ROLE_FIELD_SDR = 'UK Field SDR';
    public static final String GB_ROLE_OUTBOUND_SDR = 'UK Outbound SDR';
        
    // Error email constants
    public static final List<String> ERROR_EMAILS = new List<String>{'crm@cargurus.com'};

    // Docusign Constants
    public static final String DOCUSIGN_COMPLETE = 'DocuSign Complete';

    // PH Product Codes
    public static final Set<String> PH_PRODUCT_CODES = new Set<String>{'PH-ENH', 'PH-FEAT', 'PH-FEAT-PRI', 'PH-ROAD', 'PH-TACT', 'ENH-BUND', 'FEAT-BUND', 'FEAT-PRI-BUND'};

    // PH Featured Product Codes
    public static final Set<String> PH_FEATURED_PRODUCT_CODES = new Set<String>{'PH-FEAT', 'PH-FEAT-PRI', 'FEAT-BUND', 'FEAT-PRI-BUND'};

    //OEM Billing Related Static values
    public static final String EXTERNAL_BILL_ACC_ACTIVE_STATUS = 'Active';
    public static final String OEM_QL_BILLING_TYPE = 'Arrears';
    
}
// https://cargurus.atlassian.net/browse/BR-1499
// this class represents the zuora 'generate billing message' structure used in integration messages to create invoices
public class ZuoraIntegration_Invoice {
    
    String id;
    Date effectiveDate;
    Date targetDate;

    // default values
    Boolean autoPost = true;
    Boolean autoRenew = true;
    List<String> chargeTypeToExclude = new List<String>{'usage'};

    public ZuoraIntegration_Invoice(String zAccountId, Date effectiveDate, Date targetDate) {
        this.id = zAccountId;
        this.effectiveDate = effectiveDate;
        this.targetDate = targetDate;
    }

    public static String serializeJSON(String zAccountId, Date effectiveDate, Date targetDate) {
        return JSON.serializePretty(new ZuoraIntegration_Invoice(zAccountId, effectiveDate, targetDate), true);
    }

}

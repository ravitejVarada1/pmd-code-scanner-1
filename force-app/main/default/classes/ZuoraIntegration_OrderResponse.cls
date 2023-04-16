// https://cargurus.atlassian.net/browse/BR-894
// represents order response from zuora, allowing us to parse out the created / updated subscription number and order number
public class ZuoraIntegration_OrderResponse {

    public Boolean success;
    public String orderNumber;
    public String accountNumber;
    public String status;
    public List<String> subscriptionNumbers;

    // error fields
    public String processId;
    public List<ErrorReason> reasons;

    class ErrorReason {
        Double code;
        String message;
    }

}

// https://cargurus.atlassian.net/browse/BR-1613
public class ZuoraIntegration_RevproResponse {

    public String Message;
    public Result Result;
    public String Status;

    class Result {
      String client_id;
      String id;
      String message;
      String status;
    }

    // error fields: TO BE CHANGED
    public String processId;
    public List<ErrorReason> reasons;

    class ErrorReason {
        Double code;
        String message;
    }

}
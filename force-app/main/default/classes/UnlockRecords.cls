public class UnlockRecords {
    @InvocableMethod(label='unlockRecord')
    public static void unlockRecords(List<Id> recordsToLock){
        List<Approval.UnlockResult> results = Approval.unlock(recordsToLock, false);
    }
}
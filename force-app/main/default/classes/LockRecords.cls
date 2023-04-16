global class LockRecords {
    @InvocableMethod(label='lockRecord')
    global static void lockRecords(List<Id> recordsToLock){
        List<Approval.LockResult> results = Approval.lock(recordsToLock, false);
    }
}
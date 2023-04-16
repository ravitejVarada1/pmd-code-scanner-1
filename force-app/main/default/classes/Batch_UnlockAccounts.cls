public class Batch_UnlockAccounts implements Database.Batchable<sObject> {

    private Set<Id> preFilledIds;

    public Batch_UnlockAccounts() {}

    public Batch_UnlockAccounts(Set<Id> acctIds) {
        preFilledIds = acctIds;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT ID From Account';

        if (preFilledIds != null) {
            query += ' WHERE ID IN: preFilledIds';
        }

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Account> accounts) {
        List<Approval.UnlockResult> ulrList = Approval.unlock(accounts, false);
    }

    public void finish(Database.BatchableContext BC) {}

}
public class ExecuteBatchPanelController {
    @AuraEnabled
    public static String executeBatchJob(String className, Integer batchSize) {
        try {
            Type batchInstance = Type.forName(className);
            Id batchJobId = Database.executeBatch((Database.Batchable<sObject>)batchInstance.newInstance(), batchSize);
            return batchJobId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<AsyncApexJob> getBatchJobStatus(String jobId) {
        try {
            List<AsyncApexJob> asyncJobList = [SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, ExtendedStatus
                                               FROM AsyncApexJob WHERE Id = :jobId];
            return asyncJobList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
/**
 * Couple of web service methods to help:
 * 1. Fire off the cancellation batch
 * 2. Query the batch job for it's status
 */

global class CancellationBatchSkuidHelper {
    
    webservice static Id executeCancellationBatch(Id caseId) {
        Id asyncJobId = Database.executeBatch(new CancellationCasesProcessor(caseId));
        return asyncJobId;
    }

    webservice static String getBatchStatus(Id asyncJobId) {
        List<AsyncApexJob> aajs = [SELECT Id, Status, ExtendedStatus, NumberOfErrors FROM AsyncApexJob WHERE Id = :asyncJobId];
        String myStatus = aajs.get(0).Status;
        String extStatus = aajs.get(0).ExtendedStatus;
        if( ( myStatus == 'Completed' && !String.isBlank(extStatus) ) 
            || ( myStatus == 'Failed' && !String.isBlank(extStatus) ) )
        {
            myStatus = extStatus;
        } 
        return myStatus;
    }

}